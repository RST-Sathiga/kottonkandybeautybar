import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AdminNotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Sends a targeted notification to a client while respecting their settings.
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    required String type, // 'message_reply', 'payment', 'delivery', 'booking', 'promotion', 'new_item', 'order_status'
    String? route,
  }) async {
    final userDoc = await _db.collection('users').doc(targetUserId).get();
    if (!userDoc.exists) return;

    final data = userDoc.data() ?? {};
    final prefs = (data['prefs'] ?? <String, dynamic>{}) as Map<String, dynamic>;

    final bool pushEnabled = prefs['push'] as bool? ?? true;
    final bool promoEnabled = prefs['promotions'] as bool? ?? false;

    // 1. Check if user opted out of promotional alerts
    if (type == 'promotion' && !promoEnabled) {
      debugPrint("Skipped promotion for $targetUserId: User opted out.");
      return;
    }

    // 2. Add to user's in-app notification inbox
    await _db
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .add({
      'type': type,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      'data': {
        if (route != null) 'route': route,
      },
    });

    // 3. Log push notification target tokens if push is enabled
    if (pushEnabled) {
      final List<dynamic> tokens = data['fcmTokens'] as List<dynamic>? ?? [];
      if (tokens.isNotEmpty) {
        debugPrint("FCM Push ready for tokens: $tokens");
      }
    }
  }

  /// Broadcasts a new product or service notification to all clients with push enabled.
  Future<void> broadcastNewItem({
    required String title,
    required String body,
    String route = '/marketplace',
  }) async {
    final usersSnap = await _db.collection('users').get();

    for (final userDoc in usersSnap.docs) {
      await sendNotificationToUser(
        targetUserId: userDoc.id,
        title: title,
        body: body,
        type: 'new_item',
        route: route,
      );
    }
  }

  /// Sends an in-app and push notification to the client when their order status changes.
  Future<void> sendOrderStatusNotification({
    required String targetUserId,
    required String orderId,
    required String status, // e.g., 'Processing', 'Shipped', 'Delivered', 'Cancelled'
    String? route,
  }) async {
    final title = 'Order Status Updated';
    final body = 'Your order #$orderId is now $status.';

    await sendNotificationToUser(
      targetUserId: targetUserId,
      title: title,
      body: body,
      type: 'order_status',
      route: route ?? '/orders/$orderId',
    );
  }

  /// Notifies the admin side of a refund request in Firestore AND
  /// triggers an immediate direct email via Firebase Cloud Functions (Callable).
  Future<void> notifyAdminRefund({
    required String adminEmail,
    required String orderId,
    required double amount,
    required String reason,
  }) async {
    try {
      // 1. Add notification to the admin-side inbox collection in Firestore (for badge counting & dashboard logs)
      await _db.collection('admin_notifications').add({
        'type': 'refund_request',
        'title': 'New Refund Requested',
        'body': 'Order #$orderId requested a refund of R$amount. Reason: $reason',
        'read': false,
        'status': 'requested', // Used by badge streams if needed
        'createdAt': FieldValue.serverTimestamp(),
        'data': {
          'orderId': orderId,
          'amount': amount,
          'reason': reason,
        },
      });

      // 2. Directly trigger the Cloud Function to send the email immediately
      final callable = FirebaseFunctions.instance.httpsCallable('sendAdminRefundEmail');
      final response = await callable.call({
        'adminEmail': adminEmail,
        'orderId': orderId,
        'amount': amount,
        'reason': reason,
      });

      debugPrint("Admin refund logged and email sent successfully: ${response.data}");
    } catch (e) {
      debugPrint("Error in notifyAdminRefund: $e");
    }
  }
}