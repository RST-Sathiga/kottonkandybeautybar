import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_refunds_page.dart';

/// ADMIN: shows today's salon QR code. Display it on a tablet at reception.
/// A new code is created automatically each day (South African time).
/// Clients scan it after their appointment to earn 50 points.
class AdminLoyaltyQrScreen extends StatefulWidget {
  const AdminLoyaltyQrScreen({super.key});

  @override
  State<AdminLoyaltyQrScreen> createState() => _AdminLoyaltyQrScreenState();
}

class _AdminLoyaltyQrScreenState extends State<AdminLoyaltyQrScreen> {
  static const Color primaryPurple = Color(0xFF6B3A82);

  final _codes = FirebaseFirestore.instance.collection('loyalty_codes');
  String? _payload;
  String? _error;
  late String _today;

  // South Africa is UTC+2 all year. Must match the Cloud Function.
  static String _sastToday() =>
      DateTime.now().toUtc().add(const Duration(hours: 2)).toIso8601String().split('T')[0];

  static String _randomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(16, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceNew = false}) async {
    setState(() => _error = null);
    try {
      _today = _sastToday();
      final ref = _codes.doc(_today);
      final snap = await ref.get();
      String code;
      if (!snap.exists || forceNew) {
        code = _randomCode();
        await ref.set({'code': code, 'date': _today, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        code = snap.data()!['code'] as String;
      }
      if (mounted) setState(() => _payload = 'KK1|$_today|$code');
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the code. Are you logged in as admin?\n$e');
    }
  }

  Future<void> _confirmRegenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Generate a new code?'),
        content: const Text(
            'The current QR code will stop working immediately. Do this only if you think it was shared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Generate')),
        ],
      ),
    );
    if (ok == true) _load(forceNew: true);
  }

  /// First tab: today's loyalty QR code.
  Widget _buildQrTab() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _error != null
            ? Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))
            : _payload == null
            ? const CircularProgressIndicator(color: primaryPurple)
            : Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scan to earn 50 loyalty points',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Valid today only ($_today)',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryPurple, width: 2),
              ),
              child: QrImageView(data: _payload!, size: 260),
            ),
            const SizedBox(height: 20),
            const Text(
              'A new code is created automatically every day.\nClients must have a paid booking today to earn points.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _confirmRegenerate,
              icon: const Icon(Icons.refresh),
              label: const Text('Generate a new code now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('KottonKandy Admin'),
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.qr_code_2), text: 'Loyalty QR'),
              Tab(icon: Icon(Icons.currency_exchange), text: 'Refunds'),
            ],
          ),
        ),
        // Swiping is off so it does not clash with the tabs inside the Refunds page.
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildQrTab(),
            const AdminRefundsPage(showAppBar: false),
          ],
        ),
      ),
    );
  }
}