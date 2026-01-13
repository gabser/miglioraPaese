import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';

/// Badge in stile timbro con doppio bordo e lieve "ink bleed".
class StampBadge extends StatelessWidget {
  const StampBadge({
    super.key,
    required this.label,
    this.icon,
    this.caption,
    this.angle = -0.06,
  });

  final String label;
  final IconData? icon;
  final String? caption;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VintagePaper.inkStamp(scheme);
    final textTheme = Theme.of(context).textTheme;

    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s12,
          vertical: AppTokens.s8 / 2,
        ),
        decoration: VintagePaper.stampStyle(scheme),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: ink),
                  const SizedBox(width: AppTokens.s8),
                ],
                Text(
                  label.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: AppTokens.s4 / 2),
              Text(
                caption!,
                style: textTheme.labelSmall?.copyWith(
                  color: ink.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
