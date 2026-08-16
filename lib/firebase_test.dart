import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String firebaseStatus = 'Checking...';
  String authStatus = 'Not tested';
  String databaseStatus = 'Not tested';

  @override
  void initState() {
    super.initState();
    testFirebaseCore();
  }

  void testFirebaseCore() {
    try {
      if (Firebase.apps.isNotEmpty) {
        setState(() {
          firebaseStatus = 'CONNECTED';
        });
      } else {
        setState(() {
          firebaseStatus = 'NOT CONNECTED';
        });
      }
    } catch (e) {
      setState(() {
        firebaseStatus = 'ERROR: $e';
      });
    }
  }

  Future<void> testAuthentication() async {
    try {
      final auth = FirebaseAuth.instance;

      await auth.signInAnonymously();

      setState(() {
        authStatus = 'CONNECTED';
      });

      await auth.signOut();
    } catch (e) {
      setState(() {
        authStatus = 'ERROR: $e';
      });
    }
  }

  Future<void> testDatabase() async {
    try {
      final database = FirebaseDatabase.instance;

      final reference = database.ref('firebase_test');

      await reference.set({
        'status': 'connected',
        'message': 'Kotton Kandy Firebase test successful',
        'timestamp': DateTime.now().toIso8601String(),
      });

      setState(() {
        databaseStatus = 'CONNECTED - DATA WRITTEN';
      });
    } catch (e) {
      setState(() {
        databaseStatus = 'ERROR: $e';
      });
    }
  }

  Widget statusCard(
      String title,
      String status,
      VoidCallback? onPressed,
      ) {
    final connected =
        status == 'CONNECTED' || status == 'CONNECTED - DATA WRITTEN';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: connected ? Colors.green : Colors.red,
              ),
            ),
            if (onPressed != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onPressed,
                child: const Text('TEST'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Test'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            statusCard(
              'Firebase Core',
              firebaseStatus,
              null,
            ),
            statusCard(
              'Firebase Authentication',
              authStatus,
              testAuthentication,
            ),
            statusCard(
              'Realtime Database',
              databaseStatus,
              testDatabase,
            ),
          ],
        ),
      ),
    );
  }
}