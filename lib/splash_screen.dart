// splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _textController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _textAnimation;

  String _displayedText = "";
  final String _fullText = "Developed with ❤️ By Ruhban Abdullah";
  Timer? _textTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    // Initialize animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _textAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    _startAnimationSequence();
  }

  void _startAnimationSequence() {
    // Start logo animations
    _fadeController.forward();
    _scaleController.forward();

    // Start text animation after logo appears
    Timer(const Duration(milliseconds: 800), () {
      _startTypingAnimation();
    });

    // Navigate to next screen after all animations
    Timer(const Duration(milliseconds: 4500), () {
      _navigateToNextScreen();
    });
  }

  void _startTypingAnimation() {
    _textController.forward();
    _textTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_currentIndex < _fullText.length) {
        setState(() {
          _currentIndex++;
          _displayedText = _fullText.substring(0, _currentIndex);
        });
      } else {
        _textTimer?.cancel();
      }
    });
  }

  void _navigateToNextScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _textController.dispose();
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [Color(0xFF1a1a1a), Colors.black],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Animated Logo
              AnimatedBuilder(
                animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.indigo.shade400,
                              Colors.purple.shade600,
                              Colors.pink.shade400,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: Image.asset(
                            'assets/logo.png', // Replace with your logo path
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback to school icon if image not found
                              return const Icon(
                                Icons.school_rounded,
                                size: 60,
                                color: Colors.white,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 60),

              // App Title (optional)
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnimation.value,
                    child: const Text(
                      'Attendance Register',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2.0,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 80),

              // Animated typing text
              AnimatedBuilder(
                animation: _textAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textAnimation.value,
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: _displayedText,
                                style: const TextStyle(
                                  fontFamily:
                                      'Cursive', // You can use a custom font
                                  fontSize: 18,
                                  color: Colors.white70,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 1.2,
                                  height: 1.5,
                                ),
                              ),
                              // Blinking cursor
                              if (_currentIndex < _fullText.length)
                                TextSpan(
                                  text: '|',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.indigo.shade300,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Loading indicator
              AnimatedBuilder(
                animation: _textAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textAnimation.value * 0.7,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.indigo.shade300,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
