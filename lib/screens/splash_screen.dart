import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/splash_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(),
              _LogoWidget(),
              SizedBox(height: 24),
              _AppNameWidget(),
              SizedBox(height: 80),
              _ProgressIndicatorWidget(),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoWidget extends StatelessWidget {
  const _LogoWidget();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: 140,
    )
        .animate()
        .scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 800.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 800.ms);
  }
}

class _AppNameWidget extends StatelessWidget {
  const _AppNameWidget();

  @override
  Widget build(BuildContext context) {
    return Text(
      'SquadSync',
      style: GoogleFonts.robotoMono(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
}

class _ProgressIndicatorWidget extends StatelessWidget {
  const _ProgressIndicatorWidget();

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        ScaleEffect(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.1, 1.1),
          duration: 1000.ms,
        ),
      ],
      onPlay: (controller) => controller.repeat(reverse: true),
      child: CircularProgressIndicator(
        color: const Color(0xFF007AFF),
      ),
    );
  }
}
