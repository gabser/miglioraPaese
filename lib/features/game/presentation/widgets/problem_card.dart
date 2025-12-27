import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/core/widgets/segmented_choice.dart';
import 'package:fanta_comune/core/widgets/status_pill.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';

/// Card premium per mostrare un problema con stato e azione di previsione.
class ProblemCard extends StatelessWidget {
  /// Crea una card tappabile e accessibile per il problema indicato.
  const ProblemCard({
    required this.problem,
    required this.selectedChoice,
    required this.onSelectChoice,
    this.onTap,
    this.onRefresh,
    this.result,
    super.key,
  });

  /// Problema da visualizzare.
  final Problem problem;

  /// Scelta corrente dell'utente su questo problema.
  final PredictionChoice? selectedChoice;

  /// Callback al cambio di previsione.
  final ValueChanged<PredictionChoice> onSelectChoice;

  /// Callback opzionale al tap della card.
  final VoidCallback? onTap;

  /// Callback opzionale per aggiornare i dati del problema.
  final VoidCallback? onRefresh;

  /// Esito della previsione dopo la risoluzione del turno.
  final PredictionResult? result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final trend = problem.trendPercent;
    final isPositive = trend >= 0;
    final trendPrefix = isPositive ? '↑' : '↓';
    final trendColor = isPositive ? colorScheme.primary : colorScheme.error;
    final trendText = '$trendPrefix${trend.abs()}%';
    final updatedHours = DateTime.now().difference(problem.updatedAt).inHours;
    final statusLabel = switch (problem.status) {
      ProblemStatus.improving => 'migliora',
      ProblemStatus.stable => 'stabile',
      ProblemStatus.worsening => 'peggiora',
    };

    return Semantics(
      label: 'Problema ${problem.title}, stato $statusLabel',
      child: PrimaryCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppTokens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(AppIcons.forProblemKey(problem.key)),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        problem.title,
                        style: textTheme.titleMedium,
                      ),
                      if (problem.zoneName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTokens.s8),
                          child: Text(
                            problem.zoneName!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    tooltip: 'Aggiorna problema',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.s12),
            Row(
              children: [
                StatusPill(status: problem.status),
                const SizedBox(width: AppTokens.s12),
                AnimatedSwitcherX(
                  duration: AppMotion.fast,
                  child: Text(
                    trendText,
                    key: ValueKey(trendText),
                    style: textTheme.titleMedium?.copyWith(color: trendColor),
                  ),
                ),
                const Spacer(),
                Text(
                  'Aggiornato ${updatedHours}h fa',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s16),
            SegmentedChoice<PredictionChoice>(
              value: selectedChoice,
              options: const [
                PredictionChoice.improve,
                PredictionChoice.stable,
                PredictionChoice.worsen,
              ],
              labelBuilder: (choice) => switch (choice) {
                PredictionChoice.improve => 'Migliora',
                PredictionChoice.stable => 'Stabile',
                PredictionChoice.worsen => 'Peggiora',
              },
              optionBuilder: (choice, isSelected) {
                final (icon, color) = switch (choice) {
                  PredictionChoice.improve => (AppIcons.spark, colorScheme.primary),
                  PredictionChoice.stable => (Icons.remove, colorScheme.tertiary),
                  PredictionChoice.worsen => (AppIcons.trendingDown, colorScheme.error),
                };

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? color : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTokens.s8),
                    Text(
                      switch (choice) {
                        PredictionChoice.improve => 'Migliora',
                        PredictionChoice.stable => 'Stabile',
                        PredictionChoice.worsen => 'Peggiora',
                      },
                    ),
                  ],
                );
              },
              onChanged: onSelectChoice,
            ),
            const SizedBox(height: AppTokens.s12),
            if (result == null)
              AnimatedSwitcherX(
                duration: AppMotion.fast,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedOpacity(
                    key: ValueKey(selectedChoice),
                    duration: AppMotion.fast,
                    curve: AppMotion.standard,
                    opacity: selectedChoice != null ? 1 : 0,
                    child: selectedChoice != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTokens.s12,
                              vertical: AppTokens.s8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(AppTokens.radius),
                            ),
                            child: Text(
                              'Previsione registrata',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              )
            else
              _ResultBadge(result: result!),
          ],
        ),
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.result});

  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final (text, color, textColor) = switch (result) {
      PredictionResult.correct => ('✅ Previsione corretta', colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      PredictionResult.partial => ('🟡 Quasi corretta', colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
      PredictionResult.wrong => ('❌ Sbagliata', colorScheme.errorContainer, colorScheme.onErrorContainer),
      PredictionResult.pending => ('In attesa di risultato', colorScheme.surfaceContainerHigh, colorScheme.onSurfaceVariant),
    };

    return AnimatedSwitcherX(
      duration: AppMotion.fast,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(result),
        tween: Tween<double>(begin: 0.9, end: 1),
        duration: AppMotion.fast,
        curve: AppMotion.emphasized,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12,
            vertical: AppTokens.s8,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(
              scale: value,
              child: child,
            ),
          );
        },
      ),
    );
  }
}
