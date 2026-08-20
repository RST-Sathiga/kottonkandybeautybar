import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'legal_pages.dart'; // Import the newly created legal pages

class SettingsScreen extends StatefulWidget {
  final ValueNotifier<ThemeMode>? themeNotifier;

  const SettingsScreen({super.key, this.themeNotifier});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color primaryPurple = Color(0xFF6B3A82);

  // Toggle state variables
  bool darkMode = false;
  bool pushNotifications = true;
  bool emailNotifications = true;
  bool promoAlerts = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool('isDarkMode') ?? false;
      pushNotifications = prefs.getBool('pushNotifications') ?? true;
      emailNotifications = prefs.getBool('emailNotifications') ?? true;
      promoAlerts = prefs.getBool('promoAlerts') ?? false;
    });
  }

  Future<void> _toggleDarkMode(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', val);

    setState(() => darkMode = val);

    if (widget.themeNotifier != null) {
      widget.themeNotifier!.value = val ? ThemeMode.dark : ThemeMode.light;
    }
  }

  Future<void> _savePreference(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

  Future<void> _deleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
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
          // APP PREFERENCES
          _buildSectionHeader("App Preferences"),
          SwitchListTile(
            activeThumbColor: primaryPurple,
            title: const Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Switch between light and dark theme"),
            value: darkMode,
            onChanged: _toggleDarkMode,
          ),
          const Divider(),

          // NOTIFICATIONS
          _buildSectionHeader("Notifications"),
          SwitchListTile(
            activeThumbColor: primaryPurple,
            title: const Text("Push Notifications", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Receive updates on appointments and orders"),
            value: pushNotifications,
            onChanged: (val) {
              setState(() => pushNotifications = val);
              _savePreference('pushNotifications', val);
            },
          ),
          SwitchListTile(
            activeThumbColor: primaryPurple,
            title: const Text("Email Receipts & Updates", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Receive booking confirmations via email"),
            value: emailNotifications,
            onChanged: (val) {
              setState(() => emailNotifications = val);
              _savePreference('emailNotifications', val);
            },
          ),
          SwitchListTile(
            activeThumbColor: primaryPurple,
            title: const Text("Promotional Alerts", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Get special discounts and loyalty offers"),
            value: promoAlerts,
            onChanged: (val) {
              setState(() => promoAlerts = val);
              _savePreference('promoAlerts', val);
            },
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
                    "This action cannot be undone. All your profile data and loyalty points will be removed.",
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