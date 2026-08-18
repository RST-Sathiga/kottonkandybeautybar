import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'splash.dart';
import 'login_screen.dart';
import 'marketplace.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Kotton Kandy',

      theme: ThemeData(
        fontFamily: 'Poppins',

        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63),
        ),

        scaffoldBackgroundColor:
        Colors.white,

        appBarTheme:
        const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),

        inputDecorationTheme:
        InputDecorationTheme(
          filled: true,

          fillColor:
          const Color(0xFFF8F8F8),

          border:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
            borderSide:
            BorderSide.none,
          ),

          enabledBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
            borderSide:
            BorderSide.none,
          ),

          focusedBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
            borderSide:
            const BorderSide(
              color: Color(0xFFE91E63),
              width: 2,
            ),
          ),

          errorBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
            borderSide:
            const BorderSide(
              color: Colors.red,
            ),
          ),

          focusedErrorBorder:
          OutlineInputBorder(
            borderRadius:
            BorderRadius.circular(14),
            borderSide:
            const BorderSide(
              color: Colors.red,
              width: 2,
            ),
          ),

          labelStyle:
          const TextStyle(
            color: Colors.black,
          ),

          hintStyle:
          const TextStyle(
            color: Colors.black54,
          ),
        ),

        elevatedButtonTheme:
        ElevatedButtonThemeData(
          style:
          ElevatedButton.styleFrom(
            backgroundColor:
            const Color(0xFFE91E63),

            foregroundColor:
            Colors.white,

            minimumSize:
            const Size(
              double.infinity,
              55,
            ),

            elevation: 0,

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(14),
            ),

            textStyle:
            const TextStyle(
              fontFamily: 'Poppins',
              fontWeight:
              FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),

      home: const AuthGate(),
    );
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState
    extends State<AuthGate> {

  bool _loading = true;

  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();

    _checkLogin();
  }

  // ==========================================================
  // CHECK LOGIN
  // ==========================================================

  Future<void> _checkLogin() async {
    try {
      final SharedPreferences prefs =
      await SharedPreferences
          .getInstance();

      _rememberMe =
          prefs.getBool('remember_me') ??
              false;

      final User? user =
          FirebaseAuth.instance.currentUser;

      // --------------------------------------------------------
      // USER IS LOGGED IN AND REMEMBER ME IS ON
      // --------------------------------------------------------

      if (user != null &&
          _rememberMe) {

        await user.reload();

        final User? refreshedUser =
            FirebaseAuth
                .instance
                .currentUser;

        if (refreshedUser != null &&
            refreshedUser.emailVerified) {

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
              const MarketplaceScreen(),
            ),
          );

          return;
        }
      }

      // --------------------------------------------------------
      // OTHERWISE SHOW LOGIN
      // --------------------------------------------------------

      await FirebaseAuth
          .instance
          .signOut();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
          const LoginScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
          const LoginScreen(),
        ),
      );
    }
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return const Splash();
  }
}