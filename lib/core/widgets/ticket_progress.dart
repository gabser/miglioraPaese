import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/widgets/paper_texture.dart';

/// Indicatori di step in stile biglietto timbrato.
class TicketProgress extends StatelessWidget {
  const TicketProgress({
    super.key,
    required this.label,
    required this.currentStep,
    required this.totalSteps,
  });

  final String label;
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stampColor = VintagePaper.inkStamp(scheme);

    return Container(
      decoration: VintagePaper.surfaceDecoration(
        scheme,
        radius: AppTokens.radius,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: PaperTexture(
                color: VintagePaper.inkSoft(scheme).withOpacity(0.08),
                variant: PaperTextureVariant.dotted,
                intensity: 0.4,
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _TicketPerforationPainter(
                color: VintagePaper.paperEdge(scheme).withOpacity(0.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s12,
              vertical: AppTokens.s8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: VintagePaper.inkSoft(scheme),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                ),
                const SizedBox(width: AppTokens.s12),
                ...List.generate(totalSteps, (index) {
                  final isActive = index < currentStep;
                  return Container(
                    margin: const EdgeInsets.only(right: AppTokens.s4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isActive ? stampColor : scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive ? stampColor : scheme.outlineVariant,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketPerforationPainter extends CustomPainter {
  _TicketPerforationPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const spacing = 10.0;
    final y = size.height * 0.5;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      canvas.drawCircle(Offset(x, y), 1.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPerforationPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
