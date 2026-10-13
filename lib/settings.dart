import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'legal_pages.dart'; // Import the newly created legal pages
import 'notification_prefs_service.dart';
import 'notification_settings_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color primaryPurple = Color(0xFF6B3A82);

  // Notification preferences are now stored in Firestore (users/{uid}.prefs)
  // instead of SharedPreferences, so the server and the admin can see them
  // and never send a message the client turned off.
  final NotificationPrefsService _notificationPrefs = NotificationPrefsService();

  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Remove this device's push token and the notification inbox first.
        await _notificationPrefs.clearNotificationData();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        await user.delete();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please re-authenticate and try deleting again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // NOTIFICATIONS
          _buildSectionHeader("Notifications"),
          NotificationSettingsSection(
            service: _notificationPrefs,
            activeColor: primaryPurple,
          ),
          const Divider(),

          // LEGAL & ABOUT
          _buildSectionHeader("About & Legal"),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: primaryPurple),
            title: const Text("Privacy Policy", style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: primaryPurple),
            title: const Text("Terms of Service", style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline, color: primaryPurple),
            title: Text("App Version", style: TextStyle(fontWeight: FontWeight.w600)),
            trailing: Text("1.0.0", style: TextStyle(color: Colors.grey)),
          ),
          const Divider(),

          // ACCOUNT
          _buildSectionHeader("Account Management"),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text(
              "Deactivate / Delete Account",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Permanently delete your profile and account data"),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete Account?"),
                  content: const Text(
                    "This action cannot be undone. All your profile data, stored balances (R), and loyalty points will be removed.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteAccount();
                      },
                      child: const Text("Delete", style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}