import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Loyalty credit (R100 per 500 points) can be used on a shop order OR a booking.
///
/// 1) askToUseCredit(): shows "Use your R100 credit?" and returns the rand amount
///    to take off (0 if the client has none or says no).
/// 2) Pay only the reduced amount with Paystack.
/// 3) spendCredit(): after the payment is verified, take the credit off the account.
class CreditHelper {
  CreditHelper._();

  /// At least this much must always be paid by card (Paystack has a minimum).
  static const double minCardPayment = 5;

  static Future<double> availableCredit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      return ((snap.data()?['credit'] ?? 0) as num).toDouble();
    } catch (_) {
      return 0;
    }
  }

  static Future<double> askToUseCredit(BuildContext context, {required double total}) async {
    final double credit = await availableCredit();
    final double usable = credit.clamp(0, (total - minCardPayment).clamp(0, double.infinity)).toDouble();
    if (usable <= 0 || !context.mounted) return 0;

    final bool? use = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.card_giftcard, color: Color(0xFF6B3A82)),
          SizedBox(width: 8),
          Expanded(child: Text('Use your credit?')),
        ]),
        content: Text(
          'You have R${credit.toStringAsFixed(0)} loyalty credit.\n\n'
          'Use R${usable.toStringAsFixed(0)} now and pay R${(total - usable).toStringAsFixed(2)} '
          'instead of R${total.toStringAsFixed(2)}?\n\n'
          'Any credit left over stays on your account for next time.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('NO, KEEP IT')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B3A82), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('USE CREDIT'),
          ),
        ],
      ),
    );
    return use == true ? usable : 0;
  }

  /// Takes [amount] off the client's credit. Never throws: the payment already
  /// went through, so a problem here must not break the order or booking.
  static Future<void> spendCredit({required double amount, required String refId}) async {
    if (amount <= 0) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final db = FirebaseFirestore.instance;
      final userRef = db.collection('users').doc(user.uid);
      final claimId = 'credit_$refId';
      final batch = db.batch();
      batch.set(userRef.collection('claims').doc(claimId), {
        'type': 'credit',
        'refId': refId,
        'amount': amount,
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(userRef, {
        'credit': FieldValue.increment(-amount),
        'lastClaimId': claimId,
      });
      await batch.commit();
    } catch (e) {
      debugPrint('spendCredit failed: $e');
    }
  }
}
