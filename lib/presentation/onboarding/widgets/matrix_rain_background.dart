import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Subtle animated gradient background that matches the app's dark theme
class MatrixRainBackground extends StatefulWidget {
  const MatrixRainBackground({super.key});

  @override
  State<MatrixRainBackground> createState() => _MatrixRainBackgroundState();
}

class _MatrixRainBackgroundState extends State<MatrixRainBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: SubtleGradientPainter(
            progress: _controller.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class SubtleGradientPainter extends CustomPainter {
  final double progress;

  SubtleGradientPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Base dark background matching app theme
    final basePaint = Paint()..color = const Color(0xFF0B0E14);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), basePaint);

    // Subtle animated gradient overlay
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF14181F).withOpacity(0.8),
          Color.lerp(
            const Color(0xFF1A1F29),
            const Color(0xFF00F5FF).withOpacity(0.05),
            math.sin(progress * math.pi * 2) * 0.5 + 0.5,
          )!,
          const Color(0xFF0B0E14).withOpacity(0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);

    // Subtle floating particles for depth
    final particlePaint = Paint()..style = PaintingStyle.fill;
    final particleCount = 8;

    for (int i = 0; i < particleCount; i++) {
      final offset = (progress + i / particleCount) % 1.0;
      final x =
          (math.sin(i * 2.3 + progress * 2 * math.pi) * 0.4 + 0.5) * size.width;
      final y = offset * size.height;

      particlePaint.color = const Color(0xFF00F5FF).withOpacity(0.03);
      canvas.drawCircle(
        Offset(x, y),
        1.5,
        particlePaint,
      );
    }
  }

  @override
  bool shouldRepaint(SubtleGradientPainter oldDelegate) => true;
}
