const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
const { notify, notifyOptedInClients } = require('./notify');

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

// 1. The salon (admin app) replies to a client in chat.
// Matches client_chat_system.dart: chats/{clientId_salonId}/messages with senderType 'salon'.
exports.onChatMessage = onDocumentCreated('chats/{chatId}/messages/{msgId}', async (event) => {
  const m = event.data.data();
  if (m.senderType !== 'salon') return; // only notify the client, not the salon

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