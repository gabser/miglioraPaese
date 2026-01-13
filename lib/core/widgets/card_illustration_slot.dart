import 'package:flutter/material.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/widgets/paper_texture.dart';

enum CardIllustrationVariant {
  generic,
  analysis,
  roads,
  waste,
  lighting,
  transport,
  safety,
  green,
  noise,
  water,
}

/// Slot riutilizzabile per illustrazioni o placeholder su card di gioco.
class CardIllustrationSlot extends StatelessWidget {
  const CardIllustrationSlot({
    super.key,
    this.image,
    required this.fallbackIcon,
    this.labelRibbon,
    this.height = 90,
    this.width,
    this.compact = false,
    this.variant = CardIllustrationVariant.generic,
    this.problemKey,
    this.leadingIcon,
    this.accentColor,
    this.showMapMotif = true,
  });

  final Widget? image;
  final IconData fallbackIcon;
  final String? labelRibbon;
  final double height;
  final double? width;
  final bool compact;
  final CardIllustrationVariant variant;
  final ProblemKey? problemKey;
  final IconData? leadingIcon;
  final Color? accentColor;
  final bool showMapMotif;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedVariant = variant != CardIllustrationVariant.generic
        ? variant
        : (problemKey != null ? variantForProblemKey(problemKey!) : variant);
    final accent = accentColor ?? colorScheme.primary;
    final icon = leadingIcon ?? fallbackIcon;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            width ?? (constraints.maxWidth.isFinite ? constraints.maxWidth : height);
        return SizedBox(
          width: resolvedWidth,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: VintagePaper.surfaceDecoration(
                      colorScheme,
                      radius: AppTokens.radius,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: PaperTexture(
                      color: VintagePaper.inkSoft(colorScheme).withOpacity(0.08),
                      variant: PaperTextureVariant.dotted,
                      intensity: 0.5,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTokens.radius - 3),
                      border: Border.all(
                        color: VintagePaper.paperEdge(colorScheme).withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: image ??
                      RepaintBoundary(
                        child: Stack(
                          children: [
                            if (showMapMotif)
                              Positioned.fill(
                                child: _MapMotif(
                                  accent: accent,
                                  ink: VintagePaper.inkSoft(colorScheme).withOpacity(0.55),
                                  variant: resolvedVariant,
                                ),
                              ),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _IllustrationPainter(
                                  color: VintagePaper.inkSoft(colorScheme).withOpacity(0.45),
                                  variant: resolvedVariant,
                                ),
                              ),
                            ),
                            Center(
                              child: Icon(
                                icon,
                                size: compact ? 24 : 36,
                                color: VintagePaper.inkSoft(colorScheme).withOpacity(0.6),
                              ),
                            ),
                            Positioned(
                              right: AppTokens.s8,
                              bottom: AppTokens.s8,
                              child: _TokenDot(color: accent),
                            ),
                          ],
                        ),
                      ),
                ),
                if (labelRibbon != null)
                  Positioned(
                    left: AppTokens.s8,
                    top: AppTokens.s8,
                    child: Transform.rotate(
                      angle: -0.08,
                      child: Container(
                        decoration: VintagePaper.tapeDecoration(colorScheme),
                        child: CustomPaint(
                          foregroundPainter: _RibbonStitchPainter(
                            color: VintagePaper.inkSoft(colorScheme).withOpacity(0.5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.s8,
                              vertical: AppTokens.s8 / 2,
                            ),
                            child: Text(
                              labelRibbon!,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: VintagePaper.inkSoft(colorScheme),
                                    letterSpacing: 0.4,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IllustrationPainter extends CustomPainter {
  _IllustrationPainter({required this.color, required this.variant});

  final Color color;
  final CardIllustrationVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    switch (variant) {
      case CardIllustrationVariant.analysis:
        _drawAnalysis(canvas, size, paint);
        break;
      case CardIllustrationVariant.roads:
        _drawRoads(canvas, size, paint);
        break;
      case CardIllustrationVariant.waste:
        _drawWaste(canvas, size, paint);
        break;
      case CardIllustrationVariant.lighting:
        _drawLight(canvas, size, paint);
        break;
      case CardIllustrationVariant.transport:
        _drawTransport(canvas, size, paint);
        break;
      case CardIllustrationVariant.safety:
        _drawSafety(canvas, size, paint);
        break;
      case CardIllustrationVariant.green:
        _drawGreen(canvas, size, paint);
        break;
      case CardIllustrationVariant.noise:
        _drawNoise(canvas, size, paint);
        break;
      case CardIllustrationVariant.water:
        _drawWater(canvas, size, paint);
        break;
      case CardIllustrationVariant.generic:
        _drawGeneric(canvas, size, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _IllustrationPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.variant != variant;
  }

  void _drawGeneric(Canvas canvas, Size size, Paint paint) {
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.5),
        width: size.width * 0.6,
        height: size.height * 0.4,
      ),
      paint,
    );
  }

  void _drawAnalysis(Canvas canvas, Size size, Paint paint) {
    final ringCenter = Offset(size.width * 0.65, size.height * 0.35);
    canvas.drawCircle(ringCenter, 14, paint);
    canvas.drawLine(
      Offset(ringCenter.dx + 10, ringCenter.dy + 10),
      Offset(ringCenter.dx + 22, ringCenter.dy + 22),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.2, size.height * 0.55, 32, 18),
      paint,
    );
  }

  void _drawRoads(Canvas canvas, Size size, Paint paint) {
    final midY = size.height * 0.65;
    canvas.drawLine(Offset(size.width * 0.15, midY), Offset(size.width * 0.85, midY), paint);
    for (double x = size.width * 0.2; x < size.width * 0.8; x += 12) {
      canvas.drawLine(Offset(x, midY - 6), Offset(x + 6, midY - 6), paint);
    }
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.6, size.height * 0.25, 18, 18),
      paint,
    );
  }

  void _drawWaste(Canvas canvas, Size size, Paint paint) {
    final bin = Rect.fromLTWH(size.width * 0.35, size.height * 0.25, 30, 40);
    canvas.drawRect(bin, paint);
    canvas.drawLine(Offset(bin.left, bin.top), Offset(bin.right, bin.top), paint);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.7), 6, paint);
    canvas.drawCircle(Offset(size.width * 0.6, size.height * 0.65), 4, paint);
  }

  void _drawLight(Canvas canvas, Size size, Paint paint) {
    final base = Offset(size.width * 0.5, size.height * 0.25);
    canvas.drawCircle(base, 12, paint);
    canvas.drawLine(base, Offset(size.width * 0.5, size.height * 0.65), paint);
    canvas.drawLine(
      Offset(size.width * 0.35, size.height * 0.32),
      Offset(size.width * 0.65, size.height * 0.32),
      paint,
    );
  }

  void _drawTransport(Canvas canvas, Size size, Paint paint) {
    final route = Path()
      ..moveTo(size.width * 0.2, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.1,
        size.width * 0.8,
        size.height * 0.35,
      );
    canvas.drawPath(route, paint);
    canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 4, paint);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.35), 4, paint);
  }

  void _drawSafety(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.5, size.height * 0.5);
    canvas.drawCircle(center, 16, paint);
    canvas.drawLine(Offset(center.dx, center.dy - 16), Offset(center.dx, center.dy + 16), paint);
    canvas.drawLine(Offset(center.dx - 16, center.dy), Offset(center.dx + 16, center.dy), paint);
  }

  void _drawGreen(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.5, size.height * 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 30, height: 40),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy + 20),
      Offset(center.dx, center.dy + 40),
      paint,
    );
  }

  void _drawNoise(Canvas canvas, Size size, Paint paint) {
    final baseY = size.height * 0.6;
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.2 + i * 0.12);
      final height = 6.0 + i * 4;
      canvas.drawLine(Offset(x, baseY), Offset(x, baseY - height), paint);
    }
  }

  void _drawWater(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.5, size.height * 0.45);
    final drop = Path()
      ..moveTo(center.dx, center.dy - 14)
      ..quadraticBezierTo(
        center.dx + 14,
        center.dy,
        center.dx,
        center.dy + 18,
      )
      ..quadraticBezierTo(
        center.dx - 14,
        center.dy,
        center.dx,
        center.dy - 14,
      );
    canvas.drawPath(drop, paint);
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.7),
      Offset(size.width * 0.8, size.height * 0.7),
      paint,
    );
  }
}

class _RibbonStitchPainter extends CustomPainter {
  _RibbonStitchPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashWidth = 6.0;
    const dashSpace = 4.0;

    double x = dashSpace;
    while (x < size.width - dashSpace) {
      canvas.drawLine(
        Offset(x, 2),
        Offset(x + dashWidth, 2),
        paint,
      );
      canvas.drawLine(
        Offset(x, size.height - 2),
        Offset(x + dashWidth, size.height - 2),
        paint,
      );
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _RibbonStitchPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MapMotif extends StatelessWidget {
  const _MapMotif({
    required this.accent,
    required this.ink,
    required this.variant,
  });

  final Color accent;
  final Color ink;
  final CardIllustrationVariant variant;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 10,
          top: 10,
          child: _CityBlock(color: ink.withOpacity(0.2), size: 18),
        ),
        Positioned(
          right: 12,
          top: 18,
          child: _CityBlock(color: ink.withOpacity(0.2), size: 14),
        ),
        Positioned(
          left: 22,
          bottom: 12,
          child: _CityBlock(color: ink.withOpacity(0.18), size: 20),
        ),
        Positioned(
          right: 26,
          bottom: 14,
          child: _CityBlock(color: ink.withOpacity(0.18), size: 12),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _RoadSplitPainter(
              color: ink.withOpacity(0.45),
              accent: accent.withOpacity(0.6),
              showMagnifier: variant == CardIllustrationVariant.generic ||
                  variant == CardIllustrationVariant.analysis,
            ),
          ),
        ),
      ],
    );
  }
}

class _CityBlock extends StatelessWidget {
  const _CityBlock({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _RoadSplitPainter extends CustomPainter {
  _RoadSplitPainter({
    required this.color,
    required this.accent,
    required this.showMagnifier,
  });

  final Color color;
  final Color accent;
  final bool showMagnifier;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = Offset(size.width * 0.45, size.height * 0.55);
    canvas.drawLine(Offset(center.dx - 18, center.dy + 8), center, paint);
    canvas.drawLine(center, Offset(center.dx + 26, center.dy - 10), paint);
    canvas.drawLine(center, Offset(center.dx + 8, center.dy - 28), paint);

    final dash = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx - 14, center.dy + 2),
      Offset(center.dx - 2, center.dy - 2),
      dash,
    );

    if (showMagnifier) {
      final ringPaint = Paint()
        ..color = accent.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.32), 10, ringPaint);
      canvas.drawLine(
        Offset(size.width * 0.78, size.height * 0.4),
        Offset(size.width * 0.84, size.height * 0.46),
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RoadSplitPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.accent != accent ||
        oldDelegate.showMagnifier != showMagnifier;
  }
}

class _TokenDot extends StatelessWidget {
  const _TokenDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color.withOpacity(0.7),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
      ),
    );
  }
}

CardIllustrationVariant variantForProblemKey(ProblemKey key) {
  switch (key) {
    case ProblemKey.potholes:
    case ProblemKey.queues:
    case ProblemKey.parking:
    case ProblemKey.construction:
      return CardIllustrationVariant.roads;
    case ProblemKey.transport:
      return CardIllustrationVariant.transport;
    case ProblemKey.waste:
    case ProblemKey.cleanliness:
    case ProblemKey.decor:
      return CardIllustrationVariant.waste;
    case ProblemKey.lighting:
      return CardIllustrationVariant.lighting;
    case ProblemKey.signage:
      return CardIllustrationVariant.analysis;
    case ProblemKey.safety:
      return CardIllustrationVariant.safety;
    case ProblemKey.noise:
      return CardIllustrationVariant.noise;
    case ProblemKey.green:
      return CardIllustrationVariant.green;
  }
}
