import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/widgets/paper_texture.dart';
import 'package:fanta_comune/core/widgets/sticker_badge.dart';

/// Banner hero per la schermata di gioco con spazio immagine.
class GameBanner extends StatelessWidget {
  const GameBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.cta,
    this.image,
    this.stickerLabel,
    this.shimmer = false,
  });

  final String title;
  final String subtitle;
  final Widget cta;
  final Widget? image;
  final String? stickerLabel;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AspectRatio(
      aspectRatio: 16 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: Container(
          decoration: VintagePaper.surfaceDecoration(
            colorScheme,
            radius: AppTokens.radius,
            elevated: true,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PaperTexture(
                    color: VintagePaper.inkSoft(colorScheme).withOpacity(0.08),
                    variant: PaperTextureVariant.fiber,
                    intensity: 0.5,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer.withOpacity(0.5),
                        colorScheme.tertiaryContainer.withOpacity(0.4),
                      ],
                    ),
                  ),
                ),
              ),
            if (shimmer)
              Positioned.fill(
                child: _ShimmerOverlay(),
              ),
            Positioned(
              left: -20,
              top: -20,
              child: _CornerDecor(
                color: VintagePaper.inkSoft(colorScheme).withOpacity(0.12),
                size: 70,
              ),
            ),
            Positioned(
              right: -24,
              bottom: -24,
              child: _CornerDecor(
                color: VintagePaper.inkSoft(colorScheme).withOpacity(0.1),
                size: 90,
              ),
            ),
            Positioned(
              right: 24,
              top: 20,
              child: _CornerDecor(
                color: VintagePaper.inkSoft(colorScheme).withOpacity(0.08),
                size: 36,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _InkFlourishPainter(
                  color: VintagePaper.inkSoft(colorScheme).withOpacity(0.1),
                ),
              ),
            ),
            if (image == null)
              const Positioned.fill(
                child: _BannerPlaceholder(),
              )
            else
              Positioned.fill(
                child: Opacity(
                  opacity: 0.85,
                  child: image!,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppTokens.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Text(
                      title,
                      style: textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppTokens.s12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: cta,
                    ),
                  ],
                ),
              ),
              if (stickerLabel != null)
                Positioned(
                  right: AppTokens.s12,
                  top: AppTokens.s12,
                  child: AnimatedScale(
                    duration: AppMotion.fast,
                    curve: AppMotion.emphasize,
                    scale: 1,
                    child: StickerBadge(
                      label: stickerLabel!,
                      animate: true,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InkFlourishPainter extends CustomPainter {
  _InkFlourishPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.2,
        size.height * 0.05,
        size.width * 0.32,
        size.height * 0.2,
      )
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.32,
        size.width * 0.52,
        size.height * 0.18,
      );

    canvas.drawPath(path, paint);

    final path2 = Path()
      ..moveTo(size.width * 0.7, size.height * 0.85)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.78,
        size.width * 0.9,
        size.height * 0.9,
      );
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant _InkFlourishPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CornerDecor extends StatelessWidget {
  const _CornerDecor({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VintagePaper.inkSoft(scheme).withOpacity(0.35);
    final accent = scheme.primary.withOpacity(0.5);

    return RepaintBoundary(
      child: Stack(
        children: [
          Positioned(
            left: 18,
            top: 18,
            child: _Block(size: 28, color: ink.withOpacity(0.2)),
          ),
          Positioned(
            left: 60,
            top: 36,
            child: _Block(size: 20, color: ink.withOpacity(0.2)),
          ),
          Positioned(
            right: 32,
            bottom: 24,
            child: _Block(size: 24, color: ink.withOpacity(0.2)),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _BannerRoadPainter(
                color: ink,
                accent: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _BannerRoadPainter extends CustomPainter {
  _BannerRoadPainter({required this.color, required this.accent});

  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    final center = Offset(size.width * 0.32, size.height * 0.55);
    canvas.drawLine(Offset(center.dx - 32, center.dy + 14), center, paint);
    canvas.drawLine(center, Offset(center.dx + 40, center.dy - 10), paint);
    canvas.drawLine(center, Offset(center.dx + 14, center.dy - 34), paint);

    final dotPaint = Paint()..color = accent;
    canvas.drawCircle(Offset(center.dx - 34, center.dy + 16), 4, dotPaint);

    final ringPaint = Paint()
      ..color = accent.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.62, size.height * 0.28), 12, ringPaint);
    canvas.drawLine(
      Offset(size.width * 0.69, size.height * 0.36),
      Offset(size.width * 0.74, size.height * 0.42),
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BannerRoadPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.accent != accent;
  }
}

class _ShimmerOverlay extends StatefulWidget {
  const _ShimmerOverlay();

  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;

    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final dx = (constraints.maxWidth + 200) * _controller.value - 200;
            return Transform.translate(
              offset: Offset(dx, 0),
              child: child,
            );
          },
          child: IgnorePointer(
            child: Container(
              width: 160,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.0),
                    color.withOpacity(0.08),
                    color.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
