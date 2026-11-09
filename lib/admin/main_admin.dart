// Admin entry point (lib/admin/main_admin.dart).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import 'admin_loyalty_qr_screen.dart';
import 'admin_orders_page.dart';
import 'admin_refunds_page.dart';
// Import other admin pages as needed (e.g., booking_page, etc.)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KottonKandy Admin',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.purple,
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        canvasColor: const Color(0xFF2D2D44),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snap.data == null) return const _AdminLoginPage();

          return const AdminDashboardShell();
        },
      ),
    );
  }
}

/// The Main Dashboard Layout with Sidebar Navigation and Real-Time Badges
class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _selectedIndex = 0;

  // List of screens corresponding to sidebar indexes
  final List<Widget> _adminPages = [
    const Center(child: Text('Dashboard Overview', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Bookings Management', style: TextStyle(fontSize: 24))),
    const AdminOrdersPage(), // Your existing orders page
    const Center(child: Text('Lockers Management', style: TextStyle(fontSize: 24))),
    const AdminRefundsPage(), // Your existing refunds page
    const Center(child: Text('Products & Services', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Customers / Users', style: TextStyle(fontSize: 24))),
    const Center(child: Text('Messages Inbox', style: TextStyle(fontSize: 24))),
    const AdminLoyaltyQrScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // SIDEBAR NAVIGATION
          Container(
            width: 260,
            color: const Color(0xFF251F34),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'Kotton Kandy Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView(
                    children: [
                      _buildNavItem(icon: Icons.dashboard, title: 'Dashboard', index: 0),

                      // Bookings with Live Count Badge
                      _buildStreamBadgeNavItem(
                        icon: Icons.calendar_today,
                        title: 'Bookings',
                        index: 1,
                        collection: 'bookings',
                        statusField: 'status',
                        statusValue: 'pending',
                      ),

                      // Orders with Live Count Badge
                      _buildStreamBadgeNavItem(
                        icon: Icons.shopping_bag,
                        title: 'Orders',
                        index: 2,
                        collection: 'orders',
                        statusField: 'status',
                        statusValue: 'processing',
                      ),

                      _buildNavItem(icon: Icons.lock, title: 'Lockers', index: 3),

                      // Refunds with Live Count Badge
                      _buildStreamBadgeNavItem(
                        icon: Icons.money_off,
                        title: 'Refunds',
                        index: 4,
                        collection: 'refunds',
                        statusField: 'status',
                        statusValue: 'requested',
                      ),

                      _buildNavItem(icon: Icons.inventory, title: 'Products', index: 5),
                      _buildNavItem(icon: Icons.people, title: 'Users', index: 6),

                      // Messages with Live Count Badge
                      _buildStreamBadgeNavItem(
                        icon: Icons.message,
                        title: 'Messages',
                        index: 7,
                        collection: 'chats',
                        statusField: 'adminUnread',
                        statusValue: true,
                      ),

                      _buildNavItem(icon: Icons.qr_code, title: 'Loyalty QR', index: 8),
                    ],
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            ),
          ),

          // MAIN CONTENT AREA
          Expanded(
            child: Container(
              color: const Color(0xFF161622),
              child: _adminPages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  // Standard Nav Item
  Widget _buildNavItem({required IconData icon, required String title, required int index}) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.amber : Colors.white70),
      title: Text(
        title,
        style: TextStyle(color: isSelected ? Colors.amber : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white10,
      onTap: () => setState(() => _selectedIndex = index),
    );
  }

  // Nav Item with a real-time Firestore badge counter
  Widget _buildStreamBadgeNavItem({
    required IconData icon,
    required String title,
    required int index,
    required String collection,
    required String statusField,
    required dynamic statusValue,
  }) {
    bool isSelected = _selectedIndex == index;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(statusField, isEqualTo: statusValue)
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return ListTile(
          leading: Icon(icon, color: isSelected ? Colors.amber : Colors.white70),
          title: Text(
            title,
            style: TextStyle(color: isSelected ? Colors.amber : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
          ),
          trailing: count > 0
              ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          )
              : null,
          selected: isSelected,
          selectedTileColor: Colors.white10,
          onTap: () => setState(() => _selectedIndex = index),
        );
      },
    );
  }
}

class _AdminLoginPage extends StatefulWidget {
  const _AdminLoginPage();

  @override
  State<_AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<_AdminLoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Could not sign in.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('KottonKandy Admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Admin email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  onSubmitted: (_) => _busy ? null : _signIn(),
                  decoration: const InputDecoration(
                      labelText: 'Password', border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _busy ? null : _signIn,
                  child: _busy
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}