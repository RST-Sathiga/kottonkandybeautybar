// Loyalty system (server side). Points and credit are ONLY changed here, so
// clients cannot give themselves points from the app.
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

const POINTS_PER_ORDER = 50;
const POINTS_PER_BOOKING = 50;
const REWARD_COST = 500;   // points
const REWARD_VALUE = 100;  // rand of credit

// Today's date in South Africa (UTC+2, no daylight saving) as YYYY-MM-DD.
function sastToday() {
  return new Date(Date.now() + 2 * 3600 * 1000).toISOString().slice(0, 10);
}
const norm = (s) => String(s || '').toLowerCase().trim();

// ---------------------------------------------------------------------------
// Client scans the salon QR after their appointment.
// QR text looks like:  KK1|2026-10-10|<random code>
// ---------------------------------------------------------------------------
exports.redeemSalonQr = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please log in first.');

  const parts = String((request.data && request.data.payload) || '').split('|');
  if (parts.length !== 3 || parts[0] !== 'KK1') {
    throw new HttpsError('invalid-argument', 'This is not a Kotton Kandy QR code.');
  }
  const [, qrDate, qrCode] = parts;
  const today = sastToday();

  if (qrDate !== today) {
    throw new HttpsError('failed-precondition', 'This QR code has expired. Please scan today\'s code at the salon.');
  }
  const codeSnap = await db.collection('loyalty_codes').doc(today).get();
  if (!codeSnap.exists || codeSnap.data().code !== qrCode) {
    throw new HttpsError('failed-precondition', 'This QR code is no longer valid. Please scan the current code at the salon.');
  }

  // Which of the client's bookings today are paid and not yet rewarded?
  const snap = await db.collection('appointments')
    .where('userId', '==', uid)
    .where('date', '==', today)
    .get();

  const eligible = snap.docs.filter((d) => {
    const a = d.data();
    const paid = ['paid', 'success'].includes(norm(a.paymentStatus));
    const dead = ['cancelled', 'canceled', 'failed', 'refunded'].includes(norm(a.status));
    return paid && !dead && a.loyaltyAwarded !== true;
  });

  if (eligible.length === 0) {
    throw new HttpsError('failed-precondition',
      'No paid booking found for you today, or its points were already claimed.');
  }

  let awarded = 0;
  for (const doc of eligible) {
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(doc.ref);
      if (!fresh.exists || fresh.data().loyaltyAwarded === true) return;
      tx.update(doc.ref, { loyaltyAwarded: true, loyaltyAwardedAt: FieldValue.serverTimestamp() });
      tx.set(db.collection('users').doc(uid), { points: FieldValue.increment(POINTS_PER_BOOKING) }, { merge: true });
      awarded += POINTS_PER_BOOKING;
    });
  }
  return { awarded, message: `You earned ${awarded} loyalty points!` };
});

// ---------------------------------------------------------------------------
// Client trades 500 points for R100 credit.
// ---------------------------------------------------------------------------
exports.redeemReward = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Please log in first.');

  const ref = db.collection('users').doc(uid);
  return db.runTransaction(async (tx) => {
    const u = (await tx.get(ref)).data() || {};
    const points = Number(u.points || 0);
    if (points < REWARD_COST) {
      throw new HttpsError('failed-precondition', `You need ${REWARD_COST} points to redeem. You have ${points}.`);
    }
    tx.update(ref, {
      points: points - REWARD_COST,
      credit: Number(u.credit || 0) + REWARD_VALUE,
    });
    return { credit: Number(u.credit || 0) + REWARD_VALUE, points: points - REWARD_COST,
             message: `R${REWARD_VALUE} credit added to your account!` };
  });
});

// ---------------------------------------------------------------------------
// 50 points when a shop order is paid. The pointsAwarded flag on the order
// makes sure an order can only ever give points once.
// ---------------------------------------------------------------------------
exports.onOrderPoints = onDocumentWritten('orders/{orderId}', async (event) => {
  const after = event.data.after;
  if (!after.exists) return;
  const o = after.data();
  if (!o.userId || o.pointsAwarded === true) return;
  if (!['paid', 'success'].includes(norm(o.paymentStatus))) return;

  await db.runTransaction(async (tx) => {
    const fresh = await tx.get(after.ref);
    if (fresh.data().pointsAwarded === true) return;
    tx.update(after.ref, { pointsAwarded: true });
    tx.set(db.collection('users').doc(o.userId), { points: FieldValue.increment(POINTS_PER_ORDER) }, { merge: true });
  });
});
