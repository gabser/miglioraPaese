import 'package:flutter/material.dart';

/// Evidenziazione soft tipo ceralacca dietro un token.
class WaxSealHighlight extends StatelessWidget {
  const WaxSealHighlight({super.key, required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _WaxSealPainter(color: color)),
    );
  }
}

class _WaxSealPainter extends CustomPainter {
  _WaxSealPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final mid = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.45,
      base,
    );
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.4),
      size.width * 0.28,
      mid,
    );
  }

  @override
  bool shouldRepaint(covariant _WaxSealPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
