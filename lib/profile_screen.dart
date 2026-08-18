import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color fieldPurple = Color(0xFF9156A1);
  static const Color lightPurple = Color(0xFFF3EAF6);
  static const Color actionPink = Color(0xFFE91E63); // Cohesive pink for actions

  User? get _currentUser => _auth.currentUser;

  String get _userName {
    final String? displayName = _currentUser?.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.split(' ').first;
    }
    final String? email = _currentUser?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'User';
  }

  // ============================================================
  // PENDING BOOKINGS STREAM
  // ============================================================

  Stream<int> _getPendingBookingsCount() {
    final user = _currentUser;
    if (user == null) return Stream.value(0);

    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ============================================================
  // SHOW MESSAGE HELPER
  // ============================================================

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  // ============================================================
  // DIALOGS & ACTIONS
  // ============================================================

  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline, color: primaryPurple),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: Icon(Icons.lock_clock_outlined, color: primaryPurple),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                _showMessage('Passwords do not match.');
                return;
              }
              if (newPasswordController.text.length < 6) {
                _showMessage('Password must be at least 6 characters.');
                return;
              }
              try {
                await _currentUser?.updatePassword(newPasswordController.text.trim());
                if (!mounted) return;
                Navigator.pop(context);
                _showMessage('Password updated successfully!', isError: false);
              } catch (e) {
                _showMessage('Re-authentication required. Please log in again.');
              }
            },
            child: const Text('UPDATE'),
          ),
        ],
      ),
    );
  }

  void _showEditPhoneDialog(String currentPhone) {
    final phoneController = TextEditingController(text: currentPhone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Update Mobile Number', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Mobile Phone Number',
            prefixIcon: Icon(Icons.phone, color: primaryPurple),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: actionPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final user = _currentUser;
              if (user != null) {
                await _firestore.collection('users').doc(user.uid).set({
                  'phoneNumber': phoneController.text.trim(),
                }, SetOptions(merge: true));
                if (!mounted) return;
                Navigator.pop(context);
                setState(() {});
                _showMessage('Phone number updated successfully.', isError: false);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showPaymentHistory() {
    final user = _currentUser;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment History',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('appointments')
                    .where('userId', isEqualTo: user?.uid ?? '')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: primaryPurple));
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text('No payment records found.', style: TextStyle(color: Colors.grey[600])),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const Divider(height: 30),
                    itemBuilder: (context, index) {
                      final item = docs[index].data() as Map<String, dynamic>;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: lightPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.receipt_long, color: primaryPurple),
                        ),
                        title: Text(item['serviceName'] ?? 'Service Payment', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item['status']?.toString().toUpperCase() ?? 'COMPLETED', style: const TextStyle(fontSize: 12)),
                        trailing: Text(
                          'R${(item['price'] as num?)?.toStringAsFixed(2) ?? "0.00"}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryPurple,
                            fontSize: 16,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: actionPink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('LOGOUT'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  // ============================================================
  // BUILD METHOD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final User? user = _currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FA),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: user != null
            ? _firestore.collection('users').doc(user.uid).snapshots()
            : null,
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>?;
          final String phone = userData?['phoneNumber'] ?? 'Not added';
          final String? photoUrl = userData?['photoUrl'] ?? user?.photoURL;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ---------------- PROFILE HEADER ----------------
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryPurple, fieldPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primaryPurple.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundColor: lightPurple,
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null
                                ? Text(
                              _userName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                fontSize: 40,
                                color: primaryPurple,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              _showMessage('Connect Firebase Storage to upload avatar images.', isError: false);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: actionPink,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? 'No email',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ---------------- BOOKINGS & ACTIVITY ----------------
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text('Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),

              StreamBuilder<int>(
                stream: _getPendingBookingsCount(),
                builder: (context, pendingSnapshot) {
                  final pendingCount = pendingSnapshot.data ?? 0;
                  return _profileOption(
                    icon: Icons.calendar_today_rounded,
                    title: 'Pending Bookings',
                    badgeCount: pendingCount,
                    onTap: () => _showMessage('Navigate to bookings tab', isError: false),
                  );
                },
              ),

              _profileOption(
                icon: Icons.payment_rounded,
                title: 'Payment History',
                onTap: _showPaymentHistory,
              ),

              const SizedBox(height: 10),

              // ---------------- PERSONAL INFO & SECURITY ----------------
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text('Account Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),

              _profileOption(
                icon: Icons.phone_rounded,
                title: 'Mobile Phone',
                subtitle: phone,
                onTap: () => _showEditPhoneDialog(phone == 'Not added' ? '' : phone),
              ),

              _profileOption(
                icon: Icons.lock_rounded,
                title: 'Change Password',
                onTap: _showChangePasswordDialog,
              ),

              const SizedBox(height: 30),

              // ---------------- LOGOUT ----------------
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: actionPink),
                  label: const Text(
                    'LOGOUT',
                    style: TextStyle(color: actionPink, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: actionPink, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // REUSABLE PROFILE OPTION WIDGET
  // ============================================================

  Widget _profileOption({
    required IconData icon,
    required String title,
    String? subtitle,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: lightPurple,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryPurple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: actionPink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}