import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

/// Must be a top-level function. Register it in main():
///   FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Messages with a "notification" payload are shown by the system automatically.
}

/// Handles showing notifications while the app is open, and routing when tapped.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  static const _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'Salon notifications',
    description: 'Messages, payments, delivery updates and offers',
    importance: Importance.high,
  );

  bool _initialized = false;
  Set<String> _knownRoutes = {'/loyalty', '/booking', '/notifications'};

  /// Safe to call more than once. Pass the same navigatorKey you give to MaterialApp,
  /// and the named routes that exist in your MaterialApp `routes:` map.
  /// Notifications pointing to any other route open the notifications inbox instead.
  Future<void> init(
      GlobalKey<NavigatorState> navigatorKey, {
        Set<String>? knownRoutes,
      }) async {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;
    if (knownRoutes != null) _knownRoutes = knownRoutes;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (resp) => _go(resp.payload),
    );

    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Show banners while the app is in the foreground on iOS.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // App open: FCM does not show a banner on Android, so we do.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Tapped while app was in background.
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _go(m.data['route'] as String?));

    // Tapped while app was closed.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _go(initial.data['route'] as String?);
  }

  Future<void> _showForeground(RemoteMessage m) async {
    final n = m.notification;
    if (n == null) return;
    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: m.data['route'] as String?,
    );
  }

  void _go(String? route) {
    if (route == null || route.isEmpty) return;
    final target = _knownRoutes.contains(route) ? route : '/notifications';
    _navigatorKey?.currentState?.pushNamed(target);
  }
}