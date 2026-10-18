const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { notify, notifyOptedInClients, notifyAdmins } = require('./notify');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// Loyalty: QR scan, 500-point reward, order points
Object.assign(exports, require('./loyalty'));

// Day-before appointment reminders + "send your face photo" action
Object.assign(exports, require('./reminders'));

// Turns a Firestore Timestamp or a "YYYY-MM-DD" string into "YYYY-MM-DD".
function dateText(v) {
  if (!v) return '';
  if (typeof v.toDate === 'function') return v.toDate().toISOString().slice(0, 10);
  return String(v);
}

// "Out for delivery", "out-for-delivery", "OUT_FOR_DELIVERY" -> "out_for_delivery"
function norm(s) {
  return String(s || '').toLowerCase().trim().replace(/[\s-]+/g, '_');
}

// Best available display name for a client.
async function clientName(uid) {
  try {
    const u = (await db.doc(`users/${uid}`).get()).data() || {};
    return (
      u.fullName || u.name || u.displayName ||
      [u.firstName, u.lastName].filter(Boolean).join(' ') || u.email || 'A client'
    );
  } catch (_) {
    return 'A client';
  }
}

// 1. Chat. The salon replies -> notify the client. A client writes -> notify the owner.
// The salon (admin app) replies to a client in chat.
// Matches client_chat_system.dart: chats/{clientId_salonId}/messages with senderType 'salon'.
exports.onChatMessage = onDocumentCreated('chats/{chatId}/messages/{msgId}', async (event) => {
  const m = event.data.data();

  // A client wrote: tell the owner (only when a human is needed, not while the chatbot is handling it).
  if (m.senderType === 'client') {
    const chatSnap = await db.doc(`chats/${event.params.chatId}`).get();
    const c = chatSnap.exists ? chatSnap.data() : {};
    if (c.awaitingSalon === true || c.isBotSession === false) {
      await notifyAdmins({
        title: `New message from ${c.clientName || 'a client'}`,
        body: m.text ? String(m.text).slice(0, 100) : '📷 Sent a photo',
        data: { route: '/notifications' },
      });
    }
    return;
  }

  if (m.senderType !== 'salon') return; // below: only notify the client

  const chat = await db.doc(`chats/${event.params.chatId}`).get();
  const clientId = chat.exists ? chat.data().clientId : null;
  if (!clientId) return;

  await notify(clientId, {
    type: 'message_reply',
    title: 'New reply from Kotton Kandy',
    body: m.text ? String(m.text).slice(0, 100) : '📷 Sent you a photo',
    data: { route: '/chat' },
  });
});

// 1b. Test push: the app's "send a test notification" button calls this.
// It checks every step of the push chain and returns exactly what is wrong.
exports.sendTestPush = onCall(async (req) => {
  if (!req.auth) throw new HttpsError('unauthenticated', 'Please sign in first.');
  const uid = req.auth.uid;
  const delay = Math.min(Math.max(Number((req.data || {}).delaySeconds) || 0, 0), 20);

  const user = ((await db.doc(`users/${uid}`).get()).data()) || {};
  const tokens = user.fcmTokens || [];
  const prefs = { push: true, email: true, promotions: false, ...(user.prefs || {}) };

  if (!tokens.length) {
    return {
      ok: false,
      reason:
        'No push token is saved for your account, so the server has nowhere to send to. ' +
        'Allow notifications for the app in your phone settings, fully close and reopen the app, ' +
        'then try again. (Check the Run console for "Could not save push token".)',
    };
  }
  if (!prefs.push) {
    return { ok: false, reason: 'Push Notifications are switched OFF in your app Settings. Switch them on and try again.' };
  }

  if (delay) await new Promise((r) => setTimeout(r, delay * 1000));

  const res = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title: 'Test notification', body: 'It works! This arrived from the server.' },
    data: { route: '/notifications' },
    android: { priority: 'high', notification: { channelId: 'high_importance_channel' } },
  });

  const errors = res.responses.filter((r) => !r.success).map((r) => (r.error && r.error.code) || 'unknown');
  if (res.successCount > 0) return { ok: true, sent: res.successCount, failed: res.failureCount };

  return {
    ok: false,
    reason:
      'Firebase refused to deliver the push (' + errors.join(', ') + '). ' +
      (errors.some((e) => /not-registered|invalid-registration/.test(e))
        ? 'The saved token is out of date: sign out, sign in again and retry.'
        : 'Check that the Firebase Cloud Messaging API is enabled for the project and look at the function logs.'),
  };
});

// 2. Product orders (marketplace checkout creates orders/{id} after Paystack is verified).
exports.onOrderCreated = onDocumentCreated('orders/{orderId}', async (event) => {
  const o = event.data.data();
  if (!o.userId) return;
  const total = Number(o.totalAmount || o.price || 0).toFixed(2);
  await notify(o.userId, {
    type: 'payment',
    title: 'Order confirmed',
    body: `We received your payment of R${total}. Delivery: ${o.shippingMethod || 'Standard'}.`,
    data: { route: '/orders' },
  });
});

// 3. Delivery status changes on an order (set by the admin app).
exports.onOrderUpdate = onDocumentUpdated('orders/{orderId}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!after.userId || norm(before.status) === norm(after.status)) return;

  const text = {
    shipped: 'Your order has been shipped.',
    out_for_delivery: 'Your order is out for delivery.',
    ready_for_collection: 'Your order is ready for collection.',
    delivered: 'Your order has been delivered.',
    cancelled: 'Your order was cancelled.',
    canceled: 'Your order was cancelled.',
  }[norm(after.status)];
  if (!text) return;

  await notify(after.userId, {
    type: 'delivery',
    title: 'Order update',
    body: text,
    data: { route: '/orders' },
  });
});

// 4. Appointments: payment received, rescheduled, cancelled.
exports.onAppointmentUpdate = onDocumentUpdated('appointments/{id}', async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  if (!after.userId) return;

  // The client sent (or replaced) their face photo -> tell the owner.
  if (after.facePhotoUrl && before.facePhotoUrl !== after.facePhotoUrl) {
    const who = await clientName(after.userId);
    await notifyAdmins({
      title: 'Face photo received',
      body: `${who} sent a verification photo for ${after.serviceName || 'an appointment'} on ${dateText(after.date)} ${after.timeSlot || ''}. Open the admin page to check it.`.trim(),
      data: { route: '/notifications' },
    });
  }

  const what = `${after.serviceName || 'Appointment'} on ${dateText(after.date)} at ${after.timeSlot || ''}`.trim();

  // Payment went through -> booking confirmed.
  if (norm(before.paymentStatus) !== 'paid' && norm(after.paymentStatus) === 'paid') {
    await notify(after.userId, {
      type: 'booking',
      title: 'Booking confirmed',
      body: `${what}. Payment received.`,
      data: { route: '/orders' },
      // The app already saves its own "Booking Confirmed" item in `notifications`
      // when the booking is paid, so send only the push (no second inbox item).
      skipInbox: true,
    });
    return;
  }

  // Date or time changed on an already paid booking -> rescheduled.
  const moved =
    dateText(before.date) !== dateText(after.date) || before.timeSlot !== after.timeSlot;
  if (moved && norm(after.paymentStatus) === 'paid') {
    await notify(after.userId, {
      type: 'booking',
      title: 'Appointment rescheduled',
      body: `Your appointment is now ${what}.`,
      data: { route: '/orders' },
    });
    return;
  }

  // Cancelled (for example by the salon).
  const was = norm(before.status);
  const now = norm(after.status);
  if (was !== now && (now === 'cancelled' || now === 'canceled')) {
    await notify(after.userId, {
      type: 'booking',
      title: 'Appointment cancelled',
      body: `${what} was cancelled.`,
      data: { route: '/orders' },
    });
  }
});

// 5. Loyalty points: fires when users/{uid}.points goes UP.
// Works with loyalty.dart, which writes `points` on the user document.
const REWARD_EVERY = 500; // matches the "pts until your next reward" bar in loyalty.dart
exports.onLoyaltyPoints = onDocumentUpdated('users/{uid}', async (event) => {
  const before = event.data.before.data() || {};
  const after = event.data.after.data() || {};
  const oldPts = Number(before.points || 0);
  const newPts = Number(after.points || 0);
  if (newPts <= oldPts) return; // ignore token/pref updates and point decreases

  const earned = newPts - oldPts;
  const unlockedReward = Math.floor(newPts / REWARD_EVERY) > Math.floor(oldPts / REWARD_EVERY);
  const toNext = REWARD_EVERY - (newPts % REWARD_EVERY);

  await notify(event.params.uid, {
    type: 'loyalty',
    title: unlockedReward ? 'Reward unlocked! 🎉' : `You earned ${earned} loyalty points`,
    body: unlockedReward
      ? `You now have ${newPts} points. Open Loyalty and tap Redeem for R100 credit.`
      : `You now have ${newPts} points. ${toNext} pts until your next reward.`,
    data: { route: '/loyalty' },
  });
});

// 6. New product or service added by the owner.
// Your marketplace reads BOTH from the `products` collection: documents with
// isProduct == true are products, the rest are services.
// Only clients with Promotional Alerts ON receive this.
exports.onNewCatalogItem = onDocumentCreated('products/{id}', async (event) => {
  const item = event.data.data();
  const isProduct = item.isProduct === true;
  await notifyOptedInClients({
    type: 'new_item',
    title: isProduct ? 'New product available' : 'New service available',
    body: item.name || 'Check it out in the app',
    data: { route: '/notifications' },
  });
});

// 7. Promotions: the admin app creates a document in `promotions` with { title, body }.
exports.onPromotion = onDocumentCreated('promotions/{id}', async (event) => {
  const promo = event.data.data();
  const reached = await notifyOptedInClients({
    type: 'promotion',
    title: promo.title || 'Special offer',
    body: promo.body || '',
    data: { route: '/notifications' },
  });
  await event.data.ref.update({ sentTo: reached, sentAt: new Date() });
});