import 'package:flutter/material.dart';

/// Custom painter for drawing connecting lines between messages and replies
class ConnectingLinePainter extends CustomPainter {
  final bool isLast;
  final Color color;

  ConnectingLinePainter({
    required this.isLast,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();

    // Start from the top center
    path.moveTo(size.width * 0.7, 0);

    // Draw a curved line to the right
    if (isLast) {
      // For the last reply, draw a straight line to the bottom
      path.lineTo(size.width * 0.7, size.height);
    } else {
      // For intermediate replies, draw a curved line
      path.quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.3,
        size.width * 0.7,
        size.height,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(ConnectingLinePainter oldDelegate) {
    return oldDelegate.isLast != isLast || oldDelegate.color != color;
  }
}
