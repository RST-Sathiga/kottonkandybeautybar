import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'splash.dart';
import 'booking_page.dart';
import 'loyalty.dart';
import 'orders.dart';
import 'client_chat_system.dart';
import 'notifications_screen.dart';
import 'notification_prefs_service.dart';
import 'notification_service.dart';
import 'appointment_verification.dart';
import 'salon_info.dart';
import 'settings.dart'; // Ensure settings is imported
import 'user_sync.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  FirebaseAuth.instance.authStateChanges().listen((user) async {
    if (user == null) return;
    await syncUserProfile(user);
    // Each step has its own try/catch so one failure can never stop the others.
    // The phone's push token is saved FIRST: without it the server cannot send
    // notifications when the app is closed.
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
    try {
      await NotificationPrefsService().registerToken();
    } catch (e) {
      debugPrint('Could not save push token: $e');
    }
    try {
      await NotificationService.instance.init(
        navigatorKey,
        knownRoutes: {'/loyalty', '/booking', '/orders', '/chat', '/notifications', '/settings', '/verification', '/salon'},
      );
    } catch (e) {
      debugPrint('Notification setup error: $e');
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Kotton Kandy',
      themeMode: ThemeMode.light,
      theme: ThemeData(
        fontFamily: 'Poppins',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63),
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const Splash(),
      routes: {
        '/booking': (context) => const BookingPage(),
        '/loyalty': (context) => const LoyaltyScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/orders': (context) => const OrdersScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/verification': (context) => const AppointmentVerificationScreen(),
        '/salon': (context) => const SalonLocationScreen(),
        '/chat': (context) => const ChatScreen(
          salonId: 'kotton_kandy',
          salonName: 'Kotton Kandy',
        ),
      },
    );
  }
}