import 'package:flutter/material.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

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

/// Slot riutilizzabile per icone e placeholder visuali delle card.
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
    final accent = accentColor ?? colorScheme.primary;
    final icon = leadingIcon ?? fallbackIcon;

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            width ??
            (constraints.maxWidth.isFinite ? constraints.maxWidth : height);

        return SizedBox(
          width: resolvedWidth,
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                border: Border.all(color: accent.withOpacity(0.12)),
                borderRadius: BorderRadius.circular(AppTokens.radius),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: compact ? -10 : -18,
                    bottom: compact ? -12 : -22,
                    child: Icon(
                      icon,
                      size: compact ? 66 : 116,
                      color: accent.withOpacity(0.1),
                    ),
                  ),
                  Positioned.fill(
                    child:
                        image ??
                        Center(
                          child: Container(
                            width: compact ? 42 : 56,
                            height: compact ? 42 : 56,
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(
                                AppTokens.radiusSmall,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.shadow.withOpacity(0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Icon(
                              icon,
                              size: compact ? 23 : 30,
                              color: accent,
                            ),
                          ),
                        ),
                  ),
                  if (labelRibbon != null)
                    Positioned(
                      left: AppTokens.s8,
                      top: AppTokens.s8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s8,
                          vertical: AppTokens.s4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Text(
                          labelRibbon!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
