import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A small floating assistant: a friendly egg-shaped robot with glowing eyes that
/// hovers gently and blinks. Tap it to open the chat.
/// Drawn entirely in code, so there are no image files to add.
class FloatingBotButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String semanticLabel;

  const FloatingBotButton({
    super.key,
    required this.onPressed,
    this.semanticLabel = 'Chat with our assistant',
  });

  @override
  State<FloatingBotButton> createState() => _FloatingBotButtonState();
}

class _FloatingBotButtonState extends State<FloatingBotButton>
    with SingleTickerProviderStateMixin {
  static const Color _purple = Color(0xFF6B3A82);
  static const Color _visor = Color(0xFF1B1035);
  static const Color _glow = Color(0xFF5CF2FF);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the phone's "reduce motion" setting: keep the bot still.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _eye(double blink) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(1, blink, 1),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _glow,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: _glow.withOpacity(0.8), blurRadius: 8),
          ],
        ),
      ),
    );
  }

  Widget _head(double blink) {
    return SizedBox(
      width: 62,
      height: 70,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 62,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, Color(0xFFD9CCF0)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.elliptical(31, 38),
                topRight: Radius.elliptical(31, 38),
                bottomLeft: Radius.elliptical(31, 32),
                bottomRight: Radius.elliptical(31, 32),
              ),
              boxShadow: [
                BoxShadow(
                  color: _purple.withOpacity(0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 46,
                height: 28,
                decoration: BoxDecoration(
                  color: _visor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [_eye(blink), _eye(blink)],
                ),
              ),
            ),
          ),
          // Small green dot: the assistant is online.
          Positioned(
            right: 0,
            top: 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFF43A047),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: Tooltip(
        message: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: SizedBox(
            width: 84,
            height: 96,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final double t = _controller.value;
                final double bob = math.sin(2 * math.pi * t);
                // Quick blink once per cycle.
                final double d = (t - 0.92).abs();
                final double blink = d < 0.03 ? 0.1 + 0.9 * (d / 0.03) : 1.0;
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Shadow on the "floor": shrinks as the bot floats up.
                    Positioned(
                      bottom: 4,
                      child: Transform.scale(
                        scale: 1 - 0.12 * bob,
                        child: Container(
                          width: 46,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _purple.withOpacity(0.25),
                            borderRadius: const BorderRadius.all(Radius.elliptical(46, 10)),
                            boxShadow: [
                              BoxShadow(color: _purple.withOpacity(0.25), blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10 - bob * 5,
                      child: _head(blink),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
