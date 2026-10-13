import 'package:flutter/material.dart';

import 'notification_prefs_service.dart';

/// Drop this into your existing Settings page in place of the three
/// notification toggles. It reads and writes the preferences in Firestore.
class NotificationSettingsSection extends StatelessWidget {
  NotificationSettingsSection({
    super.key,
    NotificationPrefsService? service,
    this.activeColor,
  }) : service = service ?? NotificationPrefsService();

  final NotificationPrefsService service;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, bool>>(
      stream: service.watchPrefs(),
      builder: (context, snap) {
        final prefs = snap.data;
        final loading = prefs == null;

        Future<void> change(String key, bool value) async {
          final ok = await service.setPref(key, value);
          if (!ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications are blocked. Enable them in your phone settings.'),
              ),
            );
          }
        }

        return Column(
          children: [
            SwitchListTile(
              activeThumbColor: activeColor,
              title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Receive updates on appointments and orders'),
              value: prefs?[NotificationPrefsService.keyPush] ?? true,
              onChanged: loading ? null : (v) => change(NotificationPrefsService.keyPush, v),
            ),
            SwitchListTile(
              activeThumbColor: activeColor,
              title: const Text('Email Receipts & Updates', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Receive booking confirmations via email'),
              value: prefs?[NotificationPrefsService.keyEmail] ?? true,
              onChanged: loading ? null : (v) => change(NotificationPrefsService.keyEmail, v),
            ),
            SwitchListTile(
              activeThumbColor: activeColor,
              title: const Text('Promotional Alerts', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Get special Rand discounts (R) and loyalty offers'),
              value: prefs?[NotificationPrefsService.keyPromotions] ?? false,
              onChanged: loading ? null : (v) => change(NotificationPrefsService.keyPromotions, v),
            ),
          ],
        );
      },
    );
  }
}