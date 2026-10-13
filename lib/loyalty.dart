import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  static const Color primaryPurple = Color(0xFF6B3A82);
  static const int rewardCost = 500;

  bool _redeeming = false;

  // South Africa is UTC+2 all year. Must match the QR page and the Firestore rules.
  static String _sastToday() =>
      DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String().split('T')[0];

  static String _dateOf(dynamic v) {
    if (v is Timestamp) {
      return v.toDate().toUtc().add(const Duration(hours: 2)).toIso8601String().split('T')[0];
    }
    return (v ?? '').toString().trim();
  }

  static const String _generalError = 'Something went wrong. Please try again.';

  /// +50 points for scanning today's salon QR. The Firestore rules check the code
  /// and the paid booking, so no Cloud Function is needed.
  Future<String> _claimQr(String raw) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Please log in first.';

    final parts = raw.trim().split('|');
    if (parts.length != 3 || parts[0] != 'KK1') {
      return 'That is not a Kotton Kandy QR code.';
    }
    final today = _sastToday();
    if (parts[1] != today) {
      return "This QR code has expired. Please scan today's code at the salon.";
    }

    final db = FirebaseFirestore.instance;
    try {
      final bookings =
      await db.collection('appointments').where('userId', isEqualTo: user.uid).get();
      final todays = bookings.docs.where((d) {
        final data = d.data();
        return _dateOf(data['date']) == today && data['paymentStatus'] == 'paid';
      }).toList();

      if (todays.isEmpty) return 'You need a paid booking today to earn points.';

      final userRef = db.collection('users').doc(user.uid);
      for (final booking in todays) {
        final claimId = 'qr_${booking.id}';
        final claimRef = userRef.collection('claims').doc(claimId);
        if ((await claimRef.get()).exists) continue; // already earned for this booking

        final batch = db.batch();
        batch.set(claimRef, {
          'type': 'qr',
          'refId': booking.id,
          'code': parts[2],
          'createdAt': FieldValue.serverTimestamp(),
        });
        batch.update(userRef, {
          'points': FieldValue.increment(50),
          'lastClaimId': claimId,
        });
        await batch.commit();
        return 'You earned 50 points!';
      }
      return "You have already earned points for today's booking.";
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'This QR code is not valid. Please scan the code shown at the salon today.';
      }
      return _generalError;
    } catch (_) {
      return _generalError;
    }
  }

  /// 500 points -> R100 credit. The Firestore rules only allow exactly this change.
  Future<String> _redeemPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Please log in first.';

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      final snap = await ref.get();
      final points = ((snap.data()?['points'] ?? 0) as num).toInt();
      if (points < rewardCost) return 'You need $rewardCost points to redeem.';

      await ref.update({
        'points': FieldValue.increment(-rewardCost),
        'credit': FieldValue.increment(100),
      });
      return 'Done! R100 credit has been added to your account.';
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return 'You do not have enough points yet.';
      return _generalError;
    } catch (_) {
      return _generalError;
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: primaryPurple),
    );
  }

  Future<void> _redeem() async {
    setState(() => _redeeming = true);
    final msg = await _redeemPoints();
    if (!mounted) return;
    setState(() => _redeeming = false);
    _toast(msg);
  }

  Future<void> _scan() async {
    final String? raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanPage()),
    );
    if (raw == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: primaryPurple)),
    );
    final msg = await _claimQr(raw);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close spinner
    _toast(msg);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Loyalty Card',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: user == null
          ? const Center(child: Text('Please log in to see your rewards.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: primaryPurple));
          }
          final d = snap.data!.data() ?? {};
          final int points = (d['points'] ?? 0).toInt();
          final num credit = d['credit'] ?? 0;
          final bool canRedeem = points >= rewardCost;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6B3A82), Color(0xFF9156A1)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text('Kotton Kandy Rewards',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text('$points Pts',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (points.clamp(0, rewardCost)) / rewardCost,
                      backgroundColor: Colors.white24,
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canRedeem
                          ? 'You can redeem R100 credit now!'
                          : '${rewardCost - points} pts until R100 off',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (credit > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Credit: R${credit.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Salon QR Code',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _scan,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryPurple,
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: primaryPurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: _redeeming
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.card_giftcard),
                label: const Text('Redeem 500 pts for R100',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: (canRedeem && !_redeeming) ? _redeem : null,
              ),
              const SizedBox(height: 24),
              const Text('How it works',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const _Rule(Icons.shopping_bag_outlined, 'Place an order in the app: +25 points'),
              const _Rule(Icons.event_available,
                  'Finish a paid booking, then scan the QR code at the salon: +50 points'),
              const _Rule(Icons.card_giftcard, '500 points = R100 credit'),
            ],
          );
        },
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Rule(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6B3A82)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black87))),
      ],
    ),
  );
}

/// Opens the camera, returns the first QR text it reads.
class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Salon QR'),
        backgroundColor: const Color(0xFF6B3A82),
        foregroundColor: Colors.white,
      ),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return; // the scanner fires many times per second
          final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
          if (raw == null || raw.isEmpty) return;
          _done = true;
          Navigator.pop(context, raw);
        },
      ),
    );
  }
}