import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Indicatore compatto per flussi a step.
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

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s12,
        vertical: AppTokens.s8,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppTokens.s12),
          ...List.generate(totalSteps, (index) {
            final isActive = index < currentStep;
            return Container(
              margin: EdgeInsets.only(
                right: index == totalSteps - 1 ? 0 : AppTokens.s4,
              ),
              width: 18,
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? scheme.primary : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
