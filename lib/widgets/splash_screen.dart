import 'package:flutter/material.dart';

/// Splash screen shown during app initialization
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full screen splash image
          Center(
            child: Image.asset(
              'assets/images/splash.png',
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // Loading indicator at bottom
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.cyanAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
