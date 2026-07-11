import 'dart:math';

import 'package:flutter/material.dart';

enum PaperTextureVariant { plain, dotted, fiber, hatch }

/// Painter leggero per texture carta (puntini, fibre, tratteggi).
class PaperTexture extends CustomPainter {
  PaperTexture({
    required this.color,
    this.intensity = 0.4,
    this.seed = 1,
    this.variant = PaperTextureVariant.plain,
  });

  final Color color;
  final double intensity;
  final int seed;
  final PaperTextureVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final dots = (40 + (intensity * 60)).toInt();
    final fibers = (10 + (intensity * 20)).toInt();

    var rand = seed;
    double next() {
      rand = (rand * 1103515245 + 12345) & 0x7fffffff;
      return rand / 0x7fffffff;
    }

    if (variant == PaperTextureVariant.hatch) {
      const spacing = 24.0;
      for (double x = -size.height; x < size.width; x += spacing) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x + size.height, size.height),
          paint,
        );
      }
    }

    for (var i = 0; i < dots; i++) {
      final dx = next() * size.width;
      final dy = next() * size.height;
      final radius = 0.6 + next() * 0.8;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }

    if (variant == PaperTextureVariant.fiber) {
      for (var i = 0; i < fibers; i++) {
        final dx = next() * size.width;
        final dy = next() * size.height;
        final length = 6 + next() * 10;
        final angle = next() * 3.14;
        final offset = Offset(length * cos(angle), length * sin(angle));
        canvas.drawLine(Offset(dx, dy), Offset(dx, dy) + offset, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PaperTexture oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.intensity != intensity ||
        oldDelegate.seed != seed ||
        oldDelegate.variant != variant;
  }
}
