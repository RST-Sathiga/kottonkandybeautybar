import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { messageReply, payment, delivery, booking, loyalty, promotion, newItem, other }

NotificationType _typeFrom(String? s) {
  switch (s) {
    case 'message_reply':
      return NotificationType.messageReply;
    case 'payment':
      return NotificationType.payment;
    case 'delivery':
      return NotificationType.delivery;
    case 'booking':
      return NotificationType.booking;
    case 'loyalty':
      return NotificationType.loyalty;
    case 'promotion':
      return NotificationType.promotion;
    case 'new_item':
      return NotificationType.newItem;
    default:
      return NotificationType.other;
  }
}

/// Where tapping a notification goes, when the document does not say.
String? _routeFor(NotificationType t) {
  switch (t) {
    case NotificationType.messageReply:
      return '/chat';
    case NotificationType.payment:
    case NotificationType.booking:
    case NotificationType.delivery:
      return '/orders';
    case NotificationType.loyalty:
      return '/loyalty';
    case NotificationType.promotion:
    case NotificationType.newItem:
    case NotificationType.other:
      return null;
  }
}

/// One document of your top-level `notifications` collection.
/// Works with the documents your app already writes
/// (userId, title, message, type, read, createdAt) and the ones
/// the Cloud Functions write.
class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.route,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String? route;
  final bool read;
  final DateTime? createdAt;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final Map<String, dynamic> data =
    d['data'] is Map ? Map<String, dynamic>.from(d['data'] as Map) : <String, dynamic>{};
    final type = _typeFrom(d['type']?.toString());

    return AppNotification(
      id: doc.id,
      type: type,
      title: (d['title'] ?? '').toString(),
      body: (d['message'] ?? d['body'] ?? '').toString(),
      route: (data['route'] ?? d['route'])?.toString() ?? _routeFor(type),
      read: d['read'] == true,
      createdAt: d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : null,
    );
  }
}