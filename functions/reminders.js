const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');
const { notify } = require('./notify');

if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// "YYYY-MM-DD" for tomorrow in South Africa (UTC+2).
function tomorrowSAST() {
  const d = new Date(Date.now() + 2 * 3600 * 1000 + 24 * 3600 * 1000);
  return d.toISOString().slice(0, 10);
}

function norm(s) {
  return String(s || '').toLowerCase().trim().replace(/[\s-]+/g, '_');
}

/**
 * Every day at 09:00 (South Africa): find paid appointments for TOMORROW and
 *  - if the client has not sent their face photo yet -> "Action needed" notification
 *    that opens the Appointment Verification screen;
 *  - otherwise -> a normal "see you tomorrow" reminder that opens the salon location.
 * Each appointment is reminded once (reminderSentAt).
 */
exports.appointmentReminders = onSchedule(
  { schedule: 'every day 09:00', timeZone: 'Africa/Johannesburg' },
  async () => {
    const day = tomorrowSAST();
    const snap = await db.collection('appointments').where('date', '==', day).get();

    for (const doc of snap.docs) {
      const a = doc.data();
      if (!a.userId || a.reminderSentAt) continue;
      if (norm(a.paymentStatus) !== 'paid') continue;
      if (['cancelled', 'canceled', 'failed', 'completed'].includes(norm(a.status))) continue;

      const what = `${a.serviceName || 'Your appointment'} at ${a.timeSlot || 'your booked time'}`;
      try {
        if (!a.facePhotoUrl) {
          await notify(a.userId, {
            type: 'booking',
            title: 'Action needed: send your face photo',
            body: `${what} is tomorrow. Please send a clear photo of your face so the salon can verify you when you arrive.`,
            data: { route: '/verification' },
          });
        } else {
          await notify(a.userId, {
            type: 'booking',
            title: 'See you tomorrow!',
            body: `${what}. Tap to see the salon address and directions.`,
            data: { route: '/salon' },
          });
        }
        await doc.ref.update({ reminderSentAt: admin.firestore.FieldValue.serverTimestamp() });
      } catch (e) {
        console.error('Reminder failed for appointment', doc.id, e);
      }
    }
  }
);
