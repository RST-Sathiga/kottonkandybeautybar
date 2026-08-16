import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VerificationScreen extends StatefulWidget {
  final String email;
  final VerificationType type;

  const VerificationScreen({
    super.key,
    required this.email,
    this.type = VerificationType.emailVerification,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

enum VerificationType {
  emailVerification,
  passwordReset,
}

class _VerificationScreenState extends State<VerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Timer? _timer;

  int _secondsRemaining = 60;

  bool _isSending = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();

    if (widget.type == VerificationType.emailVerification) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ----------------------------------------------------------
  // TIMER
  // ----------------------------------------------------------

  void _startTimer() {
    _timer?.cancel();

    setState(() {
      _secondsRemaining = 60;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (_secondsRemaining <= 1) {
          timer.cancel();

          if (mounted) {
            setState(() {
              _secondsRemaining = 0;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _secondsRemaining--;
            });
          }
        }
      },
    );
  }

  // ----------------------------------------------------------
  // RESEND EMAIL VERIFICATION
  // ----------------------------------------------------------

  Future<void> _resendVerificationEmail() async {
    if (_secondsRemaining > 0 || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        _showMessage(
          'Your session has expired. Please log in again.',
          isError: true,
        );
        return;
      }

      await user.sendEmailVerification();

      _startTimer();

      _showMessage(
        'A new verification email has been sent.',
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'too-many-requests':
          message =
          'Too many requests. Please wait before trying again.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        default:
          message =
              e.message ?? 'Unable to send the verification email.';
      }

      _showMessage(
        message,
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Something went wrong. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // CHECK EMAIL VERIFICATION
  // ----------------------------------------------------------

  Future<void> _checkEmailVerification() async {
    if (_isChecking) {
      return;
    }

    setState(() {
      _isChecking = true;
    });

    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        _showMessage(
          'Your session has expired. Please log in again.',
          isError: true,
        );
        return;
      }

      await user.reload();

      final User? updatedUser = _auth.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        if (!mounted) return;

        _showSuccessDialog();
      } else {
        _showMessage(
          'Your email has not been verified yet. '
              'Please check your inbox and click the verification link.',
          isError: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(
        e.message ?? 'Unable to check verification status.',
        isError: true,
      );
    } catch (e) {
      _showMessage(
        'Unable to check verification status.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // SUCCESS DIALOG
  // ----------------------------------------------------------

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Email Verified',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: const Text(
            'Your email address has been successfully verified. '
                'You can now log in to your Kotton Kandy account.',
            style: TextStyle(
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();

                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                      (route) => false,
                );
              },
              child: const Text(
                'CONTINUE TO LOGIN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE91E63),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------------
  // GENERAL MESSAGE
  // ----------------------------------------------------------

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor:
          isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ----------------------------------------------------------
  // BACK TO LOGIN
  // ----------------------------------------------------------

  void _backToLogin() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (route) => false,
    );
  }

  // ----------------------------------------------------------
  // BUILD
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isPasswordReset =
        widget.type == VerificationType.passwordReset;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: _backToLogin,
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // ------------------------------------------------
              // LOGO / ICON
              // ------------------------------------------------

              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4EF),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: Color(0xFFE91E63),
                ),
              ),

              const SizedBox(height: 28),

              // ------------------------------------------------
              // TITLE
              // ------------------------------------------------

              Text(
                isPasswordReset
                    ? 'Check Your Email'
                    : 'Verify Your Email',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------
              // DESCRIPTION
              // ------------------------------------------------

              Text(
                isPasswordReset
                    ? 'We sent a password reset link to the email address below.'
                    : 'We sent a verification link to the email address below.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 20),

              // ------------------------------------------------
              // EMAIL
              // ------------------------------------------------

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE5E5E5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.email_outlined,
                      color: Color(0xFFE91E63),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        widget.email,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ------------------------------------------------
              // EMAIL VERIFICATION
              // ------------------------------------------------

              if (!isPasswordReset) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFE91E63),
                        size: 28,
                      ),

                      SizedBox(height: 10),

                      Text(
                        'Open the email we sent you and click '
                            'the verification link to verify your account.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // CHECK VERIFICATION BUTTON

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed:
                    _isChecking ? null : _checkEmailVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                      const Color(0xFFFFB5D0),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'I HAVE VERIFIED MY EMAIL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // RESEND

                Text(
                  _secondsRemaining > 0
                      ? 'Resend verification email in $_secondsRemaining s'
                      : 'Didn\'t receive the email?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed:
                  _secondsRemaining == 0 && !_isSending
                      ? _resendVerificationEmail
                      : null,
                  child: _isSending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE91E63),
                    ),
                  )
                      : Text(
                    'RESEND EMAIL',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondsRemaining == 0
                          ? const Color(0xFFE91E63)
                          : Colors.grey,
                    ),
                  ),
                ),
              ]

              // ------------------------------------------------
              // PASSWORD RESET
              // ------------------------------------------------
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.lock_reset_outlined,
                        color: Color(0xFFE91E63),
                        size: 32,
                      ),

                      SizedBox(height: 10),

                      Text(
                        'Open the password reset email and '
                            'follow the link to create a new password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _backToLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'BACK TO LOGIN',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'USE A DIFFERENT EMAIL',
                    style: TextStyle(
                      color: Color(0xFFE91E63),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // ------------------------------------------------
              // FOOTER
              // ------------------------------------------------

              const Text(
                'Kotton Kandy Beauty Bar',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your beauty. Your confidence.',
                style: TextStyle(
                  color: Colors.black38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}