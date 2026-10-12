import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'register.dart'; // Make sure this matches your register file class name
import 'reset.dart';
import 'verification.dart';
import 'marketplace.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
// ============================================================
// CONTROLLERS
// ============================================================

  final TextEditingController _emailController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

// ============================================================
// FIREBASE
// ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;

// ============================================================
// VARIABLES
// ============================================================

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;

// ============================================================
// COLOURS
// ============================================================

  static const Color primaryPurple =
  Color(0xFF6B3A82);

  static const Color fieldColor =
  Color(0xFF9156A1);

// ============================================================
// DISPOSE
// ============================================================

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

// ============================================================
// SHOW MESSAGE
// ============================================================

  void _showMessage(
      String message, {
        bool isError = true,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

// ============================================================
// SAVE REMEMBER ME PREFERENCE
// ============================================================

  Future<void> _saveRememberMePreference() async {
    final SharedPreferences prefs =
    await SharedPreferences.getInstance();

    await prefs.setBool(
      'remember_me',
      _rememberMe,
    );
  }

// ============================================================
// LOGIN
// ============================================================

  Future<void> _handleLogin() async {
    final String email =
    _emailController.text.trim();

    final String password =
        _passwordController.text;

    // ----------------------------------------------------------
    // VALIDATE EMAIL
    // ----------------------------------------------------------

    if (email.isEmpty) {
      _showMessage(
        'Please enter your email address.',
      );
      return;
    }

    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      _showMessage(
        'Please enter a valid email address.',
      );
      return;
    }

    // ----------------------------------------------------------
    // VALIDATE PASSWORD
    // ----------------------------------------------------------

    if (password.isEmpty) {
      _showMessage(
        'Please enter your password.',
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // FIREBASE LOGIN
      // --------------------------------------------------------

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _saveRememberMePreference();

      if (!mounted) return;

      // Navigate to Marketplace screen upon success
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MarketplaceScreen()),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'An error occurred during login.');
    } catch (e) {
      _showMessage('An unexpected error occurred.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

// ============================================================
// BUILD METHOD
// ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryPurple,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    filled: true,
                    fillColor: fieldColor.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    filled: true,
                    fillColor: fieldColor.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: fieldColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      activeColor: primaryPurple,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? true;
                        });
                      },
                    ),
                    const Text('Remember Me'),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Login',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: () {
                        // Note: Change 'RegisterScreen' if your class name in register.dart is different
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Register(),
                          ),
                        );
                      },
                      child: Text(
                        'Register',
                        style: TextStyle(color: primaryPurple),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}