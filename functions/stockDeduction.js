// Firebase Cloud Function (v2): subtracts stock when an order is paid, so it works
// even when the admin page is closed. Uses the SAME order flags as the admin page
// (stockDeducted / stockTaken / stockUnmatched), so the two never double-count.
//   exports.stockDeduction = require('./stockDeduction').stockDeduction;
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

exports.stockDeduction = onDocumentWritten('orders/{orderId}', async (event) => {
  const after = event.data && event.data.after && event.data.after.data();
  if (!after) return;
  if (after.paymentStatus !== 'paid' || after.stockDeducted) return;
  const ref = event.data.after.ref;

  await db.runTransaction(async (tx) => {
    const o = await tx.get(ref);
    const d = o.data();
    if (!d || d.paymentStatus !== 'paid' || d.stockDeducted) return;

    const items = Array.isArray(d.items) ? d.items : [];
    const taken = {};
    let unmatched = false;
    const prods = [];
    for (const it of items) {
      const pid = it.productId || it.product_id || it.id;
      if (!pid) { unmatched = true; continue; }
      const pref = db.collection('products').doc(String(pid));
      const snap = await tx.get(pref);
      prods.push({ it, pref, snap });
    }
    for (const { it, pref, snap } of prods) {
      if (!snap.exists) { unmatched = true; continue; }
      const p = snap.data();
      if (typeof p.stock !== 'number') continue; // stock not tracked
      // Orders placed before stock tracking began are not deducted retroactively.
      const base = p.stockBaseAt && p.stockBaseAt.toMillis ? p.stockBaseAt.toMillis() : 0;
      const created = d.createdAt && d.createdAt.toMillis ? d.createdAt.toMillis() : Date.now();
      if (created < base) continue;
      const qty = Number(it.quantity) || 1;
      const take = Math.min(qty, Math.max(p.stock, 0));
      taken[pref.id] = (taken[pref.id] || 0) + take;
      tx.update(pref, {
        stock: admin.firestore.FieldValue.increment(-take),
        stockUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    tx.update(ref, {
      stockDeducted: true,
      stockTaken: taken,
      stockUnmatched: unmatched,
      stockDeductedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
});
