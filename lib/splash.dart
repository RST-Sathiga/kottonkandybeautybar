import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with TickerProviderStateMixin {
  late AnimationController _bgAnimationController;
  late AnimationController _logoSloganController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Timer? _navigationTimer;

  static const Color primaryPurple = Color(0xFF6B3A82);

  @override
  void initState() {
    super.initState();

    // 1. Endless background horizontal scrolling controller
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // 2. Entrance animation controller for slogan floating effect
    _logoSloganController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _logoSloganController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoSloganController,
      curve: Curves.easeOutCubic,
    ));

    // Trigger floating slogan entrance
    _logoSloganController.forward();

    // 3. Navigate to LoginScreen after 15 seconds delay
    _navigationTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _bgAnimationController.dispose();
    _logoSloganController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Continuous Sliding Background Image
          AnimatedBuilder(
            animation: _bgAnimationController,
            builder: (context, child) {
              return FractionalTranslation(
                translation: Offset(-_bgAnimationController.value * 0.5, 0),
                child: OverflowBox(
                  maxWidth: screenSize.width * 2.5,
                  maxHeight: screenSize.height,
                  child: Image.asset(
                    'assets/images/kottonkandy_background.jpeg',
                    fit: BoxFit.cover,
                    repeat: ImageRepeat.repeatX,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFFD9D6DE),
                    ),
                  ),
                ),
              );
            },
          ),

          // Dark overlay tint for readability
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.15),
            ),
          ),

          // 2. Centered Content: Large Logo + Floating Slogan
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Large Centered Circular Logo
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/kottonkandy_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(
                            Icons.medical_services_outlined,
                            size: 80,
                            color: primaryPurple,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Floating Slogan Text
                    SlideTransition(
                      position: _slideAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Text(
                            'Creating Confidence, One Look At A Time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: primaryPurple,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ),
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