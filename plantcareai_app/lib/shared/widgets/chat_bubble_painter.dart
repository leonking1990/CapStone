import 'package:flutter/material.dart';

// Reusable painter for the chat bubble tail
class ChatBubblePainter extends CustomPainter {
  final Color color;
  final double tailBaseWidth;
  final double tailHeight;
  final double borderRadius;
  final double tailCenterX; // Relative X position for the tail center

  ChatBubblePainter({
    required this.color,
    this.tailBaseWidth = 20.0,
    this.tailHeight = 10.0,
    this.borderRadius = 12.0,
    required this.tailCenterX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();

    // Draw rounded rectangle
    path.moveTo(borderRadius, 0);
    path.lineTo(size.width - borderRadius, 0);
    path.arcToPoint(Offset(size.width, borderRadius), radius: Radius.circular(borderRadius));
    path.lineTo(size.width, size.height - borderRadius);
    path.arcToPoint(Offset(size.width - borderRadius, size.height), radius: Radius.circular(borderRadius));

    // Draw tail centered relative to input position
    path.lineTo(tailCenterX + (tailBaseWidth / 2), size.height);
    path.lineTo(tailCenterX, size.height + tailHeight); // Point of the tail
    path.lineTo(tailCenterX - (tailBaseWidth / 2), size.height);

    // Finish rounded rectangle
    path.lineTo(borderRadius, size.height);
    path.arcToPoint(Offset(0, size.height - borderRadius), radius: Radius.circular(borderRadius));
    path.lineTo(0, borderRadius);
    path.arcToPoint(Offset(borderRadius, 0), radius: Radius.circular(borderRadius));
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ChatBubblePainter oldDelegate) {
    // Repaint if color or tail position changes
    return oldDelegate.color != color || oldDelegate.tailCenterX != tailCenterX;
  }
}