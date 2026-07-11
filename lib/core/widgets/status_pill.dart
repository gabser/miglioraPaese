import 'package:flutter/material.dart';
import 'package:fanta_comune/core/models/problem_status.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Pillola di stato che evidenzia l'andamento di un problema.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, super.key});

  /// Stato sintetico da rappresentare.
  final ProblemStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, emoji, background, border, foreground) = switch (status) {
      ProblemStatus.improving => (
        'Migliora',
        '🟢',
        colorScheme.primaryContainer.withOpacity(0.25),
        colorScheme.primary.withOpacity(0.4),
        colorScheme.primary,
      ),
      ProblemStatus.stable => (
        'Stabile',
        '🟡',
        colorScheme.tertiaryContainer.withOpacity(0.25),
        colorScheme.tertiary.withOpacity(0.4),
        colorScheme.tertiary,
      ),
      ProblemStatus.worsening => (
        'Peggiora',
        '🔴',
        colorScheme.errorContainer.withOpacity(0.25),
        colorScheme.error.withOpacity(0.4),
        colorScheme.error,
      ),
    };

    return Semantics(
      label: 'Stato: $label',
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s12,
          vertical: AppTokens.s8,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: AppTokens.s8),
            Text(
              label,
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
