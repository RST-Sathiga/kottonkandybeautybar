import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_notification.dart';

const Color _purple = Color(0xFF6B3A82);

/// The signed-in user's notifications, from your existing top-level
/// `notifications` collection (documents have a `userId`).
Query<Map<String, dynamic>>? _myNotifications() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid);
}

/// In-app notification inbox.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _icon(NotificationType t) {
    switch (t) {
      case NotificationType.messageReply:
        return Icons.chat_bubble_outline;
      case NotificationType.payment:
        return Icons.payments_outlined;
      case NotificationType.delivery:
        return Icons.local_shipping_outlined;
      case NotificationType.booking:
        return Icons.event_available_outlined;
      case NotificationType.loyalty:
        return Icons.card_giftcard_outlined;
      case NotificationType.promotion:
        return Icons.local_offer_outlined;
      case NotificationType.newItem:
        return Icons.new_releases_outlined;
      case NotificationType.other:
        return Icons.notifications_none;
    }
  }

  String _when(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _markAllRead() async {
    final q = _myNotifications();
    if (q == null) return;
    final unread = await q.where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final query = _myNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read', style: TextStyle(color: _purple)),
          ),
        ],
      ),
      body: query == null
          ? const Center(child: Text('Please log in to see your notifications.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Could not load notifications'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _purple));
          }

          final items = snap.data!.docs.map(AppNotification.fromDoc).toList();
          // Newest first (done here so no Firestore index is needed).
          items.sort((a, b) {
            final now = DateTime.now();
            return (b.createdAt ?? now).compareTo(a.createdAt ?? now);
          });

          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF3EAF6),
                  child: Icon(_icon(n.type), color: _purple),
                ),
                title: Text(
                  n.title,
                  style: TextStyle(fontWeight: n.read ? FontWeight.normal : FontWeight.bold),
                ),
                subtitle: Text(
                  n.body.isEmpty ? _when(n.createdAt) : '${n.body}\n${_when(n.createdAt)}',
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: n.body.isNotEmpty,
                trailing: n.read
                    ? null
                    : const Icon(Icons.circle, size: 10, color: _purple),
                onTap: () async {
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(n.id)
                      .update({'read': true});
                  if (n.route != null && context.mounted) {
                    Navigator.of(context).pushNamed(n.route!);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Bell icon with an unread count. Used in the marketplace header.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final query = _myNotifications();

    Widget bell(int count) {
      return IconButton(
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text(count > 99 ? '99+' : '$count'),
          child: const Icon(Icons.notifications_none, color: Colors.black87),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      );
    }

    if (query == null) return bell(0);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.where('read', isEqualTo: false).snapshots(),
      builder: (context, snap) => bell(snap.data?.docs.length ?? 0),
    );
  }
}