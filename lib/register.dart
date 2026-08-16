import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'home.dart';
import 'verification.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _emailController =
  TextEditingController();

  final TextEditingController _cellController =
  TextEditingController();

  final TextEditingController _passwordController =
  TextEditingController();

  final TextEditingController _confirmPasswordController =
  TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  static const Color primaryPurple = Color(0xFF6B3A82);
  static const Color fieldPurple = Color(0xFF9156A1);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cellController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // REGISTER USER
  // ============================================================

  Future<void> _handleRegister() async {
    // Run all validators
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Extra password confirmation check
    if (_passwordController.text !=
        _confirmPasswordController.text) {
      _showMessage('Passwords do not match.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final String name = _nameController.text.trim();

      final String email = _emailController.text.trim();

      final String password = _passwordController.text;

      // ----------------------------------------------------------
      // CREATE FIREBASE ACCOUNT
      // ----------------------------------------------------------

      final UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user == null) {
        _showMessage(
          'Account could not be created. Please try again.',
        );
        return;
      }

      // ----------------------------------------------------------
      // SAVE DISPLAY NAME
      // ----------------------------------------------------------

      await user.updateDisplayName(name);

      // ----------------------------------------------------------
      // SEND EMAIL VERIFICATION
      // ----------------------------------------------------------

      await user.sendEmailVerification();

      if (!mounted) return;

      // ----------------------------------------------------------
      // GO TO EMAIL VERIFICATION SCREEN
      // ----------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationScreen(
            email: email,
            type: VerificationType.emailVerification,
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'weak-password':
          message =
          'The password is too weak. Please use a stronger password.';
          break;

        case 'email-already-in-use':
          message =
          'An account already exists with this email address.';
          break;

        case 'invalid-email':
          message =
          'Please enter a valid email address.';
          break;

        case 'operation-not-allowed':
          message =
          'Email/password registration is not enabled in Firebase.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        case 'too-many-requests':
          message =
          'Too many requests. Please wait and try again later.';
          break;

        default:
          message =
              e.message ??
                  'Registration failed. Please try again.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage(
        'An unexpected error occurred. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // GOOGLE SIGN UP
  // ============================================================

  Future<void> _handleGoogleSignUp() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignIn googleSignIn =
      GoogleSignIn.standard();

      final GoogleSignInAccount? googleUser =
      await googleSignIn.signIn();

      // User cancelled Google sign-in.
      if (googleUser == null) {
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final OAuthCredential credential =
      GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(
        e.message ?? 'Google sign-in failed.',
      );
    } catch (e) {
      _showMessage(
        'Google sign-in failed. Please try again.',
      );
    } finally {
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
          // ------------------------------------------------------
          // BACKGROUND
          // ------------------------------------------------------

          Positioned.fill(
            child: Image.asset(
              'assets/images/kottonkandy_background.jpeg',
              fit: BoxFit.cover,
              errorBuilder:
                  (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFFD9D6DE),
                );
              },
            ),
          ),

          // ------------------------------------------------------
          // LIGHT OVERLAY
          // ------------------------------------------------------

          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(
                alpha: 0.05,
              ),
            ),
          ),

          // ------------------------------------------------------
          // PAGE
          // ------------------------------------------------------

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 35,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 15),

                    // ------------------------------------------------
                    // LOGO
                    // ------------------------------------------------

                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.15,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/kottonkandy_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (
                              context,
                              error,
                              stackTrace,
                              ) {
                            return const Icon(
                              Icons.medical_services_outlined,
                              size: 60,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ------------------------------------------------
                    // TITLE
                    // ------------------------------------------------

                    const Text(
                      'CREATE ACCOUNT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 25),

                    // ------------------------------------------------
                    // NAME
                    // ------------------------------------------------

                    _RoundedTextField(
                      controller: _nameController,
                      hintText: 'Name:',
                      fillColor: fieldPurple,
                      keyboardType: TextInputType.name,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-ZÀ-ÿ\s'-]"),
                        ),
                        LengthLimitingTextInputFormatter(50),
                      ],
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Colors.white70,
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter your name';
                        }

                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }

                        if (!RegExp(
                          r"^[a-zA-ZÀ-ÿ\s'-]+$",
                        ).hasMatch(value.trim())) {
                          return 'Name contains invalid characters';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------------
                    // EMAIL
                    // ------------------------------------------------

                    _RoundedTextField(
                      controller: _emailController,
                      hintText: 'Email:',
                      fillColor: fieldPurple,
                      keyboardType:
                      TextInputType.emailAddress,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(254),
                        FilteringTextInputFormatter.deny(
                          RegExp(r'\s'),
                        ),
                      ],
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.white70,
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter your email';
                        }

                        final RegExp emailRegex = RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                        );

                        if (!emailRegex.hasMatch(
                          value.trim(),
                        )) {
                          return 'Enter a valid email address';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------------
                    // CELL NUMBER
                    // ------------------------------------------------

                    _RoundedTextField(
                      controller: _cellController,
                      hintText: 'Cell no.:',
                      fillColor: fieldPurple,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: Colors.white70,
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Please enter your cell number';
                        }

                        if (value.length != 10) {
                          return 'Cell number must contain 10 digits';
                        }

                        if (!value.startsWith('0')) {
                          return 'Cell number must start with 0';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------------
                    // PASSWORD
                    // ------------------------------------------------

                    _RoundedTextField(
                      controller: _passwordController,
                      hintText: 'Password:',
                      fillColor: fieldPurple,
                      obscureText: _obscurePassword,
                      keyboardType: TextInputType.visiblePassword,

                      // Maximum password length
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(30),
                        FilteringTextInputFormatter.deny(
                          RegExp(r'\s'),
                        ),
                      ],

                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.white70,
                      ),

                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                            !_obscurePassword;
                          });
                        },
                      ),

                      // STRONG PASSWORD VALIDATOR
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Please enter a password';
                        }

                        if (value.length < 8) {
                          return 'Password must be at least 8 characters';
                        }

                        if (value.length > 30) {
                          return 'Password cannot exceed 30 characters';
                        }

                        if (value.contains(' ')) {
                          return 'Password cannot contain spaces';
                        }

                        if (!RegExp(r'[A-Z]').hasMatch(value)) {
                          return 'Password needs an uppercase letter';
                        }

                        if (!RegExp(r'[a-z]').hasMatch(value)) {
                          return 'Password needs a lowercase letter';
                        }

                        if (!RegExp(r'[0-9]').hasMatch(value)) {
                          return 'Password needs a number';
                        }

                        if (!RegExp(
                          r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\\/~`]',
                        ).hasMatch(value)) {
                          return 'Password needs a special character';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // ------------------------------------------------
                    // CONFIRM PASSWORD
                    // ------------------------------------------------

                    _RoundedTextField(
                      controller:
                      _confirmPasswordController,
                      hintText: 'Confirm Password:',
                      fillColor: fieldPurple,
                      obscureText:
                      _obscureConfirmPassword,
                      keyboardType:
                      TextInputType.visiblePassword,

                      inputFormatters: [
                        LengthLimitingTextInputFormatter(30),
                        FilteringTextInputFormatter.deny(
                          RegExp(r'\s'),
                        ),
                      ],

                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Colors.white70,
                      ),

                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                          });
                        },
                      ),

                      validator: (value) {
                        if (value == null ||
                            value.isEmpty) {
                          return 'Please confirm your password';
                        }

                        if (value !=
                            _passwordController.text) {
                          return 'Passwords do not match';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 28),

                    // ------------------------------------------------
                    // CREATE ACCOUNT BUTTON
                    // ------------------------------------------------

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _handleRegister,
                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          primaryPurple,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                          primaryPurple.withValues(
                            alpha: 0.6,
                          ),
                          elevation: 3,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 22,
                          width: 22,
                          child:
                          CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontWeight:
                            FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ------------------------------------------------
                    // OR
                    // ------------------------------------------------

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ------------------------------------------------
                    // GOOGLE
                    // ------------------------------------------------

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _handleGoogleSignUp,
                        style:
                        ElevatedButton.styleFrom(
                          backgroundColor:
                          Colors.white,
                          foregroundColor:
                          Colors.black87,
                          elevation: 2,
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              width: 20,
                              height: 20,
                              errorBuilder: (
                                  context,
                                  error,
                                  stackTrace,
                                  ) {
                                return const Icon(
                                  Icons.account_circle,
                                  color: Colors.red,
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign up with Google',
                              style: TextStyle(
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ------------------------------------------------
                    // LOGIN
                    // ------------------------------------------------

                    Container(
                      padding:
                      const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.90,
                        ),
                        borderRadius:
                        BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(
                              color: Colors.black87,
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pop(context),
                            child: const Text(
                              'LOGIN',
                              style: TextStyle(
                                color: primaryPurple,
                                fontWeight:
                                FontWeight.bold,
                                decoration:
                                TextDecoration.underline,
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
          ),
        ],
      ),
    );
  }
}

// ================================================================
// REUSABLE ROUNDED TEXT FIELD
// ================================================================

class _RoundedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Color fillColor;

  final bool obscureText;

  final TextInputType keyboardType;

  final Widget? prefixIcon;
  final Widget? suffixIcon;

  final String? Function(String?)? validator;

  final List<TextInputFormatter>? inputFormatters;

  const _RoundedTextField({
    required this.controller,
    required this.hintText,
    required this.fillColor,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,

      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
      ),

      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
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

        errorStyle: const TextStyle(
          color: Colors.amber,
          fontWeight: FontWeight.bold,
        ),

        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: Colors.white,
            width: 2,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: Colors.amber,
            width: 2,
          ),
        ),

        focusedErrorBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(30),
          borderSide: const BorderSide(
            color: Colors.amber,
            width: 2,
          ),
        ),
      ),
    );
  }
}