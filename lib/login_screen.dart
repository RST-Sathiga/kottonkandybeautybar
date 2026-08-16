import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'register.dart';
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
          duration:
          const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
        ),
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

      final UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user == null) {
        _showMessage(
          'Login failed. Please try again.',
        );
        return;
      }

      // --------------------------------------------------------
      // REFRESH USER
      // --------------------------------------------------------

      await user.reload();

      user = _auth.currentUser;

      if (user == null) {
        _showMessage(
          'Unable to load your account.',
        );
        return;
      }

      // --------------------------------------------------------
      // CHECK EMAIL VERIFICATION
      // --------------------------------------------------------

      if (!user.emailVerified) {
        _showMessage(
          'Please verify your email before logging in.',
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                VerificationScreen(
                  email: user?.email ?? email,
                  type: VerificationType
                      .emailVerification,
                ),
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // LOGIN SUCCESSFUL
      // REDIRECT TO MARKETPLACE
      // --------------------------------------------------------

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) =>
          const MarketplaceScreen(),
        ),
            (route) => false,
      );
    }

    // ----------------------------------------------------------
    // FIREBASE ERRORS
    // ----------------------------------------------------------

    on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message =
          'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message =
          'No account was found with this email address.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message =
          'Incorrect email or password.';
          break;

        case 'user-disabled':
          message =
          'This account has been disabled.';
          break;

        case 'too-many-requests':
          message =
          'Too many login attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        case 'operation-not-allowed':
          message =
          'Email/password authentication is not enabled in Firebase.';
          break;

        default:
          message =
              e.message ??
                  'Authentication failed. Please try again.';
      }

      _showMessage(message);
    }

    // ----------------------------------------------------------
    // GENERAL ERROR
    // ----------------------------------------------------------

    catch (e) {
      _showMessage(
        'An unexpected error occurred. Please try again.',
      );
    }

    // ----------------------------------------------------------
    // STOP LOADING
    // ----------------------------------------------------------

    finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ======================================================
          // BACKGROUND
          // ======================================================

          Positioned.fill(
            child: Image.asset(
              'assets/images/kottonkandy_background.jpeg',
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) {
                return Container(
                  color:
                  const Color(0xFFD9D6DE),
                );
              },
            ),
          ),

          // ======================================================
          // LIGHT OVERLAY
          // ======================================================

          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(
                alpha: 0.05,
              ),
            ),
          ),

          // ======================================================
          // PAGE
          // ======================================================

          SafeArea(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 40,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.center,
                children: [

                  const SizedBox(height: 20),

                  // =================================================
                  // LOGO
                  // =================================================

                  Container(
                    width: 160,
                    height: 160,
                    decoration:
                    BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(
                            alpha: 0.15,
                          ),
                          blurRadius: 8,
                          offset:
                          const Offset(
                            0,
                            4,
                          ),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/kottonkandy_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder:
                            (
                            context,
                            error,
                            stackTrace,
                            ) {
                          return const Icon(
                            Icons
                                .medical_services_outlined,
                            size: 60,
                            color:
                            Colors.grey,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // =================================================
                  // EMAIL
                  // =================================================

                  _RoundedTextField(
                    controller:
                    _emailController,
                    hintText: 'Email:',
                    fillColor: fieldColor,
                    keyboardType:
                    TextInputType
                        .emailAddress,
                    prefixIcon:
                    const Icon(
                      Icons.email_outlined,
                      color:
                      Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 18),

                  // =================================================
                  // PASSWORD
                  // =================================================

                  _RoundedTextField(
                    controller:
                    _passwordController,
                    hintText: 'Password:',
                    fillColor: fieldColor,
                    obscureText:
                    _obscurePassword,
                    prefixIcon:
                    const Icon(
                      Icons.lock_outline,
                      color:
                      Colors.white70,
                    ),
                    suffixIcon:
                    IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons
                            .visibility_off
                            : Icons.visibility,
                        color:
                        Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword =
                          !_obscurePassword;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // =================================================
                  // FORGOT PASSWORD
                  // =================================================

                  Align(
                    alignment:
                    Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                Reset(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                          FontWeight.w600,
                          fontSize: 14,
                          decoration:
                          TextDecoration
                              .underline,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // =================================================
                  // LOGIN BUTTON
                  // =================================================

                  SizedBox(
                    width:
                    double.infinity,
                    height: 55,
                    child:
                    ElevatedButton(
                      onPressed:
                      _isLoading
                          ? null
                          : _handleLogin,
                      style:
                      ElevatedButton
                          .styleFrom(
                        backgroundColor:
                        primaryPurple,
                        foregroundColor:
                        Colors.white,
                        disabledBackgroundColor:
                        primaryPurple
                            .withValues(
                          alpha: 0.6,
                        ),
                        elevation: 3,
                        shape:
                        RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius
                              .circular(
                            20,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 22,
                        width: 22,
                        child:
                        CircularProgressIndicator(
                          color:
                          Colors.white,
                          strokeWidth:
                          2,
                        ),
                      )
                          : const Text(
                        'LOGIN',
                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                          fontSize: 14,
                          letterSpacing:
                          0.8,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // =================================================
                  // REGISTER
                  // =================================================

                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.white
                          .withValues(
                        alpha: 0.90,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        20,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(
                            alpha: 0.08,
                          ),
                          blurRadius: 6,
                          offset:
                          const Offset(
                            0,
                            3,
                          ),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style:
                          TextStyle(
                            color:
                            Colors.grey[
                            800],
                            fontSize: 14,
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                const Register(),
                              ),
                            );
                          },
                          child:
                          const Text(
                            'REGISTER',
                            style:
                            TextStyle(
                              color:
                              primaryPurple,
                              fontWeight:
                              FontWeight
                                  .bold,
                              fontSize: 14,
                              decoration:
                              TextDecoration
                                  .underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REUSABLE ROUNDED TEXT FIELD
// ================================================================

class _RoundedTextField
    extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color fillColor;

  final bool obscureText;
  final TextInputType keyboardType;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const _RoundedTextField({
    required this.controller,
    required this.hintText,
    required this.fillColor,
    this.obscureText = false,
    this.keyboardType =
        TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,

      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),

      decoration:
      InputDecoration(
        hintText: hintText,

        hintStyle:
        const TextStyle(
          color: Colors.white70,
          fontSize: 16,
        ),

        filled: true,

        fillColor: fillColor,

        prefixIcon: prefixIcon,

        suffixIcon: suffixIcon,

        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),

        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            30,
          ),
          borderSide:
          BorderSide.none,
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            30,
          ),
          borderSide:
          BorderSide.none,
        ),

        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            30,
          ),
          borderSide:
          const BorderSide(
            color: Colors.white,
            width: 2,
          ),
        ),
      ),
    );
  }
}