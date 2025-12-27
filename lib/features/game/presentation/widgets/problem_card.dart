import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/core/widgets/segmented_choice.dart';
import 'package:fanta_comune/core/widgets/status_pill.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/presentation/widgets/insight_card.dart';
import 'package:fanta_comune/features/game/presentation/widgets/motivation_chips.dart';

/// Card premium per mostrare un problema con stato e azione di previsione.
class ProblemCard extends StatelessWidget {
  /// Crea una card tappabile e accessibile per il problema indicato.
  const ProblemCard({
    required this.problem,
    required this.selectedChoice,
    required this.selectedMotivations,
    required this.onSelectChoice,
    required this.onSelectMotivations,
    this.onTap,
    this.onRefresh,
    this.result,
    this.insight,
    this.history,
    this.isHistoryLoading = false,
    this.onLoadHistory,
    super.key,
  });

  /// Problema da visualizzare.
  final Problem problem;

  /// Scelta corrente dell'utente su questo problema.
  final PredictionChoice? selectedChoice;

  /// Motivazioni attualmente selezionate.
  final List<MotivationKey> selectedMotivations;

  /// Callback al cambio di previsione.
  final ValueChanged<PredictionChoice> onSelectChoice;

  /// Callback al cambio motivazioni.
  final ValueChanged<List<MotivationKey>> onSelectMotivations;

  /// Callback opzionale al tap della card.
  final VoidCallback? onTap;

  /// Callback opzionale per aggiornare i dati del problema.
  final VoidCallback? onRefresh;

  /// Esito della previsione dopo la risoluzione del turno.
  final PredictionResult? result;

  /// Insight aggregato di riferimento, mostrato solo dopo il responso.
  final AggregatedInsight? insight;

  /// Storico sintetico degli insight per il problema, opzionale.
  final InsightHistory? history;

  /// Indica se il caricamento dello storico è in corso.
  final bool isHistoryLoading;

  /// Callback per avviare il recupero dello storico su richiesta.
  final VoidCallback? onLoadHistory;

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
    final hasResult = result != null;

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
            AnimatedSwitcherX(
              duration: AppMotion.fast,
              child: hasResult
                  ? _ResultBadge(result: result!)
                  : _ChoiceSection(
                      key: ValueKey('choice-${problem.id}-primary'),
                      selectedChoice: selectedChoice,
                      colorScheme: colorScheme,
                      hasResult: false,
                      onSelectChoice: onSelectChoice,
                    ),
            ),
            if (hasResult) ...[
              const SizedBox(height: AppTokens.s12),
              AnimatedSwitcherX(
                duration: AppMotion.normal,
                switchInCurve: const Interval(0.2, 1, curve: AppMotion.standard),
                child: insight != null
                    ? InsightCard(
                        key: ValueKey('insight-${problem.id}-${insight?.totalPredictions}'),
                        insight: insight!,
                        userChoice: selectedChoice,
                        problemTitle: problem.title,
                        history: history,
                        isHistoryLoading: isHistoryLoading,
                        onLoadHistory: onLoadHistory,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
            if (!hasResult) ...[
              const SizedBox(height: AppTokens.s12),
              AnimatedSwitcherX(
                duration: AppMotion.fast,
                child: selectedChoice != null
                    ? _MotivationSection(
                        key: ValueKey('motivation-${problem.id}-${selectedChoice?.name}'),
                        selectedMotivations: selectedMotivations,
                        onSelectMotivations: onSelectMotivations,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
            const SizedBox(height: AppTokens.s12),
            AnimatedSwitcherX(
              duration: AppMotion.fast,
              child: hasResult
                  ? _ChoiceSection(
                      key: ValueKey('choice-${problem.id}-resolved'),
                      selectedChoice: selectedChoice,
                      colorScheme: colorScheme,
                      hasResult: true,
                      onSelectChoice: onSelectChoice,
                    )
                  : _StatusRow(
                      status: problem.status,
                      trendText: trendText,
                      trendColor: trendColor,
                      updatedHours: updatedHours,
                    ),
            ),
            const SizedBox(height: AppTokens.s12),
            AnimatedSwitcherX(
              duration: AppMotion.fast,
              child: hasResult
                  ? _StatusRow(
                      status: problem.status,
                      trendText: trendText,
                      trendColor: trendColor,
                      updatedHours: updatedHours,
                      subdued: true,
                    )
                  : _SelectionHint(selectedChoice: selectedChoice),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.trendText,
    required this.trendColor,
    required this.updatedHours,
    this.subdued = false,
  });

  final ProblemStatus status;
  final String trendText;
  final Color trendColor;
  final int updatedHours;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        StatusPill(status: status),
        const SizedBox(width: AppTokens.s12),
        AnimatedSwitcherX(
          duration: AppMotion.fast,
          child: Text(
            trendText,
            key: ValueKey(trendText),
            style: textTheme.titleMedium?.copyWith(
              color: subdued ? colorScheme.onSurfaceVariant : trendColor,
              fontWeight: subdued ? FontWeight.w600 : textTheme.titleMedium?.fontWeight,
            ),
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
    );
  }
}

class _MotivationSection extends StatelessWidget {
  const _MotivationSection({
    required this.selectedMotivations,
    required this.onSelectMotivations,
    super.key,
  });

  final List<MotivationKey> selectedMotivations;
  final ValueChanged<List<MotivationKey>> onSelectMotivations;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perché lo pensi?',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        Text(
          'Scegline al massimo due',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        MotivationChips(
          selected: selectedMotivations,
          onChanged: onSelectMotivations,
        ),
      ],
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.selectedChoice,
    required this.colorScheme,
    required this.hasResult,
    required this.onSelectChoice,
    super.key,
  });

  final PredictionChoice? selectedChoice;
  final ColorScheme colorScheme;
  final bool hasResult;
  final ValueChanged<PredictionChoice> onSelectChoice;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: hasResult ? 0.7 : 1,
      child: SegmentedChoice<PredictionChoice>(
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
    );
  }
}

class _SelectionHint extends StatelessWidget {
  const _SelectionHint({required this.selectedChoice});

  final PredictionChoice? selectedChoice;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedOpacity(
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
                  'Scelta registrata',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            : const SizedBox.shrink(),
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
      PredictionResult.correct => ('Hai letto bene la situazione', colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      PredictionResult.partial => ('Ci eri quasi', colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
      PredictionResult.wrong => ('Qui la situazione è andata diversamente', colorScheme.errorContainer, colorScheme.onErrorContainer),
      PredictionResult.pending => ('In attesa di verifica', colorScheme.surfaceContainerHigh, colorScheme.onSurfaceVariant),
    };

    return AnimatedSwitcher(
      duration: AppMotion.fast,
      switchInCurve: const Interval(0.12, 1, curve: AppMotion.standard),
      switchOutCurve: AppMotion.standard,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.12, 1, curve: AppMotion.standard),
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1).animate(curved),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(result),
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
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
