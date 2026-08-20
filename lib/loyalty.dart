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

  int points = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          points = doc.data()?['points'] ?? 0;
        });
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _addPoints(int pointsToAdd) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final newPoints = points + pointsToAdd;
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'points': newPoints,
      }, SetOptions(merge: true));

      setState(() => points = newPoints);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          "Loyalty Card",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primaryPurple))
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6B3A82), Color(0xFF9156A1)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text(
                    "Kotton Kandy Rewards",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "$points Pts",
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: (points % 500) / 500,
                    backgroundColor: Colors.white24,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${500 - (points % 500)} pts until your next reward!",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPurple,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text("Scan Salon QR Code", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(
                        title: const Text("Scan Salon QR"),
                        backgroundColor: primaryPurple,
                      ),
                      body: MobileScanner(
                        onDetect: (capture) {
                          if (capture.barcodes.isNotEmpty) {
                            Navigator.pop(context);
                            _addPoints(50);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("50 Loyalty Points Added!"),
                                backgroundColor: primaryPurple,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}