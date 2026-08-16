import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'verification.dart';

class Reset extends StatefulWidget {
  const Reset({super.key});

  @override
  State<Reset> createState() => _ResetState();
}

class _ResetState extends State<Reset> {
  final TextEditingController _emailController =
  TextEditingController();

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  bool _isLoading = false;

  static const Color primaryPurple =
  Color(0xFF6B3A82);

  static const Color fieldPurple =
  Color(0xFF9156A1);

  @override
  void dispose() {
    _emailController.dispose();
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
          backgroundColor:
          isError
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(12),
          ),
        ),
      );
  }

  // ============================================================
  // SEND PASSWORD RESET EMAIL
  // ============================================================

  Future<void> _sendPasswordResetEmail() async {
    FocusScope.of(context).unfocus();

    final String email =
    _emailController.text.trim();

    // ----------------------------------------------------------
    // EMPTY EMAIL
    // ----------------------------------------------------------

    if (email.isEmpty) {
      _showMessage(
        'Please enter your email address.',
      );
      return;
    }

    // ----------------------------------------------------------
    // VALIDATE EMAIL
    // ----------------------------------------------------------

    final RegExp emailRegex =
    RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      _showMessage(
        'Please enter a valid email address.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // FIREBASE PASSWORD RESET
      // --------------------------------------------------------

      await _auth.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      // --------------------------------------------------------
      // OPEN CHECK EMAIL SCREEN
      // --------------------------------------------------------

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              VerificationScreen(
                email: email,
                type:
                VerificationType
                    .passwordReset,
              ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'invalid-email':
          message =
          'The email address is not valid.';
          break;

        case 'user-not-found':
          message =
          'No account was found with this email address.';
          break;

        case 'too-many-requests':
          message =
          'Too many requests. Please wait and try again later.';
          break;

        case 'network-request-failed':
          message =
          'Network error. Please check your internet connection.';
          break;

        case 'operation-not-allowed':
          message =
          'Password reset is not enabled for this Firebase project.';
          break;

        default:
          message =
              e.message ??
                  'Unable to send password reset email.';
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
                  color:
                  const Color(0xFFD9D6DE),
                );
              },
            ),
          ),

          // ------------------------------------------------------
          // OVERLAY
          // ------------------------------------------------------

          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(
                alpha: 0.05,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 30,
              ),
              child: Column(
                children: [
                  // ------------------------------------------------
                  // BACK BUTTON
                  // ------------------------------------------------

                  Align(
                    alignment:
                    Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () =>
                          Navigator.pop(
                            context,
                          ),
                      icon:
                      const Icon(
                        Icons
                            .arrow_back_ios_new,
                        color:
                        Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  // ------------------------------------------------
                  // LOGO
                  // ------------------------------------------------

                  Container(
                    width: 160,
                    height: 160,
                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,
                      color:
                      Colors.white,
                      border:
                      Border.all(
                        color:
                        Colors.white,
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
                                .lock_reset,
                            size: 60,
                            color:
                            primaryPurple,
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 32,
                  ),

                  // ------------------------------------------------
                  // TITLE
                  // ------------------------------------------------

                  const Text(
                    'FORGOT PASSWORD',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 26,
                      fontWeight:
                      FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(
                    height: 12,
                  ),

                  // ------------------------------------------------
                  // DESCRIPTION
                  // ------------------------------------------------

                  const Text(
                    'Enter the email address associated '
                        'with your Kotton Kandy account. '
                        'We will send you a secure password '
                        'reset link.',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      color:
                      Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  // ------------------------------------------------
                  // EMAIL FIELD
                  // ------------------------------------------------

                  TextField(
                    controller:
                    _emailController,
                    keyboardType:
                    TextInputType
                        .emailAddress,
                    textInputAction:
                    TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isLoading) {
                        _sendPasswordResetEmail();
                      }
                    },
                    style:
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration:
                    InputDecoration(
                      hintText:
                      'Email:',
                      hintStyle:
                      const TextStyle(
                        color:
                        Colors.white70,
                        fontSize: 16,
                      ),
                      prefixIcon:
                      const Icon(
                        Icons
                            .email_outlined,
                        color:
                        Colors.white70,
                      ),
                      filled: true,
                      fillColor:
                      fieldPurple,
                      contentPadding:
                      const EdgeInsets
                          .symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      border:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          30,
                        ),
                        borderSide:
                        BorderSide.none,
                      ),
                      enabledBorder:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          30,
                        ),
                        borderSide:
                        BorderSide.none,
                      ),
                      focusedBorder:
                      OutlineInputBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          30,
                        ),
                        borderSide:
                        const BorderSide(
                          color:
                          Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  // ------------------------------------------------
                  // SEND RESET LINK
                  // ------------------------------------------------

                  SizedBox(
                    width:
                    double.infinity,
                    height: 55,
                    child:
                    ElevatedButton(
                      onPressed:
                      _isLoading
                          ? null
                          : _sendPasswordResetEmail,
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
                          BorderRadius.circular(
                            20,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                        CircularProgressIndicator(
                          color:
                          Colors.white,
                          strokeWidth:
                          2,
                        ),
                      )
                          : const Text(
                        'SEND RESET LINK',
                        style:
                        TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize:
                          14,
                          letterSpacing:
                          0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // ------------------------------------------------
                  // INFORMATION CARD
                  // ------------------------------------------------

                  Container(
                    width:
                    double.infinity,
                    padding:
                    const EdgeInsets.all(
                      20,
                    ),
                    decoration:
                    BoxDecoration(
                      color: Colors.white
                          .withValues(
                        alpha: 0.92,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons
                              .mark_email_read_outlined,
                          color:
                          primaryPurple,
                          size: 38,
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        const Text(
                          'Check your inbox',
                          textAlign:
                          TextAlign.center,
                          style:
                          TextStyle(
                            color:
                            Colors.black,
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 6,
                        ),
                        const Text(
                          'If your email is registered, '
                              'Firebase will send a secure '
                              'password reset link to your inbox.',
                          textAlign:
                          TextAlign.center,
                          style:
                          TextStyle(
                            color:
                            Colors.black87,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 25,
                  ),

                  // ------------------------------------------------
                  // BACK TO LOGIN
                  // ------------------------------------------------

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
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        const Text(
                          'Remember your password? ',
                          style:
                          TextStyle(
                            color:
                            Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              Navigator.pop(
                                context,
                              ),
                          child:
                          const Text(
                            'LOGIN',
                            style:
                            TextStyle(
                              color:
                              primaryPurple,
                              fontWeight:
                              FontWeight.bold,
                              decoration:
                              TextDecoration
                                  .underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 30,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}