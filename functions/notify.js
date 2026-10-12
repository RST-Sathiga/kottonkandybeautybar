const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// Marketing types are blocked unless the client turned Promotional Alerts on.
const MARKETING = new Set(['promotion', 'new_item']);
// Types that may also be emailed (when the client's Email toggle is on).
const EMAIL_TYPES = new Set(['payment', 'delivery', 'booking', 'promotion']);

function allowed(user, type, channel) {
  const p = user.prefs || { push: true, email: true, promotions: false };
  if (MARKETING.has(type) && !p.promotions) return false;
  if (channel === 'push') return !!p.push && (user.fcmTokens || []).length > 0;
  if (channel === 'email') return !!p.email && !!user.email && EMAIL_TYPES.has(type);
  return false;
}

/**
 * The ONE place every notification goes through.
 * It checks the client's preferences before anything is sent.
 */
async function notify(uid, { type, title, body, data = {}, skipInbox = false }) {
  const ref = db.doc(`users/${uid}`);
  const snap = await ref.get();
  if (!snap.exists) return;
  const user = snap.data();
  // Fall back to the sign-in email if the profile document has no email field.
  if (!user.email) {
    try {
      user.email = (await admin.auth().getUser(uid)).email;
    } catch (_) {}
  }
  const prefs = user.prefs || { push: true, email: true, promotions: false };

  // Opted out of marketing: send nothing, store nothing.
  if (MARKETING.has(type) && !prefs.promotions) return;

  // In-app inbox entry, saved in the app's existing top-level `notifications`
  // collection (same shape the app already writes: userId, title, message, type, read, createdAt).
  if (!skipInbox) {
    await db.collection('notifications').add({
      userId: uid,
      type,
      title,
      message: body,
      data,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  if (allowed(user, type, 'push')) {
    const stringData = Object.fromEntries(
      Object.entries({ type, ...data }).map(([k, v]) => [k, String(v)])
    );
    const res = await admin.messaging().sendEachForMulticast({
      tokens: user.fcmTokens,
      notification: { title, body },
      data: stringData,
      android: { priority: 'high', notification: { channelId: 'high_importance_channel' } },
    });

    const dead = [];
    res.responses.forEach((r, i) => {
      const code = r.error && r.error.code;
      if (
        !r.success &&
        (code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token')
      ) {
        dead.push(user.fcmTokens[i]);
      }
    });
    if (dead.length) {
      await ref.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...dead) });
    }
  }

  if (allowed(user, type, 'email')) {
    // Works with the Firebase "Trigger Email from Firestore" extension.
    // Or replace with a SendGrid / Resend / Postmark call.
    await db.collection('mail').add({
      to: user.email,
      message: { subject: title, text: body },
    });
  }
}

/** Send to every client who has Promotional Alerts on, in batches. */
async function notifyOptedInClients(payload, batchSize = 200) {
  const snap = await db.collection('users').where('prefs.promotions', '==', true).get();
  const ids = snap.docs.map((d) => d.id);
  for (let i = 0; i < ids.length; i += batchSize) {
    await Promise.all(ids.slice(i, i + batchSize).map((uid) => notify(uid, payload)));
  }
  return ids.length;
}

module.exports = { notify, notifyOptedInClients };