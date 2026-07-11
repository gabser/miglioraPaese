import 'package:flutter/material.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/theme/app_assets.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/segmented_choice.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/critical_insight.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/reflection_question.dart';
import 'package:fanta_comune/features/game/presentation/widgets/motivation_chips.dart';

/// Card problema leggera, ricostruita sul mockup moderno.
class ProblemCard extends StatelessWidget {
  const ProblemCard({
    required this.problem,
    required this.selectedChoice,
    required this.selectedMotivations,
    required this.selectedConfidence,
    required this.reflectionQuestion,
    required this.selectedReflectionAnswer,
    required this.criticalInsights,
    required this.isCriticalInsightsLoading,
    required this.onSelectChoice,
    required this.onSelectMotivations,
    required this.onSelectConfidence,
    required this.onSelectReflectionAnswer,
    required this.onLoadCriticalInsights,
    this.onTap,
    this.onRefresh,
    this.result,
    this.insight,
    this.history,
    this.isHistoryLoading = false,
    this.onLoadHistory,
    super.key,
  });

  final Problem problem;
  final PredictionChoice? selectedChoice;
  final List<MotivationKey> selectedMotivations;
  final HypothesisConfidence? selectedConfidence;
  final ReflectionQuestion? reflectionQuestion;
  final int? selectedReflectionAnswer;
  final List<CriticalInsight> criticalInsights;
  final bool isCriticalInsightsLoading;
  final ValueChanged<PredictionChoice> onSelectChoice;
  final ValueChanged<List<MotivationKey>> onSelectMotivations;
  final ValueChanged<HypothesisConfidence> onSelectConfidence;
  final ValueChanged<int> onSelectReflectionAnswer;
  final VoidCallback onLoadCriticalInsights;
  final VoidCallback? onTap;
  final VoidCallback? onRefresh;
  final PredictionResult? result;
  final AggregatedInsight? insight;
  final InsightHistory? history;
  final bool isHistoryLoading;
  final VoidCallback? onLoadHistory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.of(context).size.width < 560;
    final status = _statusMeta(problem.status);
    final updatedHours = DateTime.now().difference(problem.updatedAt).inHours;
    final trendLabel =
        '${problem.trendPercent >= 0 ? '+' : ''}${problem.trendPercent}%';
    final isPredictionLocked = selectedChoice != null;

    return RepaintBoundary(
      child: FcPanel(
        onTap: onTap,
        elevated: selectedChoice != null || result != null,
        padding: EdgeInsets.all(isCompact ? AppTokens.s14 : AppTokens.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isCompact ? 46 : 52,
                  height: isCompact ? 46 : 52,
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  ),
                  child: AppSvg(
                    AppAssets.forProblemKey(problem.key),
                    color: status.color,
                  ),
                ),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppTokens.s8,
                        runSpacing: AppTokens.s8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FcStatusChip(
                            label: AppIcons.labelForProblemKey(problem.key),
                            color: AppTokens.blue,
                          ),
                          FcStatusChip(
                            label: status.label,
                            color: status.color,
                            icon: status.icon,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.s8),
                      Text(
                        problem.title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s4),
                      Text(
                        '${problem.zoneName ?? 'Comune'} · ${updatedHours <= 0 ? 'aggiornato ora' : 'aggiornato ${updatedHours}h fa'}',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    onPressed: onRefresh,
                    tooltip: VenialCopy.problemRefreshTooltip,
                    icon: const Icon(Icons.refresh),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.s16),
            FcPredictionBar(
              improve:
                  insight?.choiceDistribution[PredictionChoice.improve]
                      ?.toDouble() ??
                  (problem.status == ProblemStatus.improving ? 64 : 28),
              stable:
                  insight?.choiceDistribution[PredictionChoice.stable]
                      ?.toDouble() ??
                  (problem.status == ProblemStatus.stable ? 52 : 24),
              worsen:
                  insight?.choiceDistribution[PredictionChoice.worsen]
                      ?.toDouble() ??
                  (problem.status == ProblemStatus.worsening ? 56 : 18),
            ),
            const SizedBox(height: AppTokens.s8),
            Row(
              children: [
                Text(
                  'Trend $trendLabel',
                  style: textTheme.labelMedium?.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (insight != null)
                  Text(
                    '${insight!.totalPredictions} previsioni',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: AppTokens.s12),
              _ResultBanner(result: result!),
            ],
            const SizedBox(height: AppTokens.s16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isPredictionLocked
                        ? VenialCopy.predictionLockedTitle
                        : VenialCopy.predictionPrompt,
                    style: textTheme.titleSmall,
                  ),
                ),
                if (isPredictionLocked)
                  FcStatusChip(
                    label: _choiceLabel(selectedChoice!),
                    color: _choiceColor(selectedChoice!),
                    icon: Icons.how_to_vote_outlined,
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.s8),
            SegmentedChoice<PredictionChoice>(
              value: selectedChoice,
              options: const [
                PredictionChoice.improve,
                PredictionChoice.stable,
                PredictionChoice.worsen,
              ],
              labelBuilder: _choiceLabel,
              optionBuilder: (choice, isSelected) {
                final color = _choiceColor(choice);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppSvg(
                      AppAssets.forPredictionChoice(choice),
                      size: 18,
                      color: isSelected ? color : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTokens.s8),
                    Flexible(child: Text(_choiceLabel(choice))),
                  ],
                );
              },
              onChanged: isPredictionLocked ? null : onSelectChoice,
            ),
            if (isPredictionLocked) ...[
              const SizedBox(height: AppTokens.s8),
              Text(
                VenialCopy.predictionLockedBody,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (selectedChoice != null) ...[
              const SizedBox(height: AppTokens.s16),
              Text(
                _motivationPrompt(selectedChoice!),
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: AppTokens.s8),
              MotivationChips(
                selected: selectedMotivations,
                choice: selectedChoice!,
                onChanged: onSelectMotivations,
              ),
              const SizedBox(height: AppTokens.s16),
              Text(VenialCopy.confidenceTitle, style: textTheme.titleSmall),
              const SizedBox(height: AppTokens.s8),
              SegmentedChoice<HypothesisConfidence>(
                value: selectedConfidence,
                options: HypothesisConfidence.values,
                labelBuilder: _confidenceLabel,
                onChanged: onSelectConfidence,
              ),
            ],
            if (reflectionQuestion != null) ...[
              const SizedBox(height: AppTokens.s16),
              _ReflectionBlock(
                question: reflectionQuestion!,
                selectedIndex: selectedReflectionAnswer,
                onSelected: onSelectReflectionAnswer,
              ),
            ],
            if (insight != null) ...[
              const SizedBox(height: AppTokens.s16),
              _InsightBlock(
                insight: insight!,
                history: history,
                isHistoryLoading: isHistoryLoading,
                onLoadHistory: onLoadHistory,
              ),
            ],
            if (result != null) ...[
              const SizedBox(height: AppTokens.s16),
              _CriticalInsightsBlock(
                insights: criticalInsights,
                isLoading: isCriticalInsightsLoading,
                onLoad: onLoadCriticalInsights,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReflectionBlock extends StatelessWidget {
  const _ReflectionBlock({
    required this.question,
    required this.selectedIndex,
    required this.onSelected,
  });

  final ReflectionQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return FcPanel(
      tint: AppTokens.blue,
      padding: const EdgeInsets.all(AppTokens.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.prompt, style: textTheme.titleSmall),
          const SizedBox(height: AppTokens.s8),
          Wrap(
            spacing: AppTokens.s8,
            runSpacing: AppTokens.s8,
            children: question.options.indexed
                .map((entry) {
                  final index = entry.$1;
                  final option = entry.$2;
                  final selected = selectedIndex == index;
                  return ChoiceChip(
                    label: Text(option),
                    selected: selected,
                    onSelected: (_) => onSelected(index),
                  );
                })
                .toList(growable: false),
          ),
          if (selectedIndex != null) ...[
            const SizedBox(height: AppTokens.s8),
            Text(
              question.followUpCopy,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightBlock extends StatelessWidget {
  const _InsightBlock({
    required this.insight,
    required this.history,
    required this.isHistoryLoading,
    required this.onLoadHistory,
  });

  final AggregatedInsight insight;
  final InsightHistory? history;
  final bool isHistoryLoading;
  final VoidCallback? onLoadHistory;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final topChoice = insight.choiceDistribution.entries.isEmpty
        ? PredictionChoice.stable
        : insight.choiceDistribution.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

    return FcPanel(
      padding: const EdgeInsets.all(AppTokens.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FcSectionHeader(
            title: VenialCopy.insightCardTitle,
            subtitle:
                '${insight.percentageForChoice(topChoice).round()}% vede "${_choiceLabel(topChoice).toLowerCase()}".',
          ),
          const SizedBox(height: AppTokens.s12),
          FcPredictionBar(
            improve:
                insight.choiceDistribution[PredictionChoice.improve]
                    ?.toDouble() ??
                0,
            stable:
                insight.choiceDistribution[PredictionChoice.stable]
                    ?.toDouble() ??
                0,
            worsen:
                insight.choiceDistribution[PredictionChoice.worsen]
                    ?.toDouble() ??
                0,
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            VenialCopy.insightDisclaimer,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (onLoadHistory != null) ...[
            const SizedBox(height: AppTokens.s8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isHistoryLoading ? null : onLoadHistory,
                icon: isHistoryLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.query_stats),
                label: Text(
                  history == null
                      ? VenialCopy.insightHistoryShow
                      : '${VenialCopy.insightHistoryHide} · ${history!.snapshots.length} turni',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CriticalInsightsBlock extends StatelessWidget {
  const _CriticalInsightsBlock({
    required this.insights,
    required this.isLoading,
    required this.onLoad,
  });

  final List<CriticalInsight> insights;
  final bool isLoading;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (insights.isEmpty) {
      return OutlinedButton.icon(
        onPressed: isLoading ? null : onLoad,
        icon: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.psychology_alt_outlined),
        label: const Text(VenialCopy.criticalInsightsTitle),
      );
    }

    return FcPanel(
      tint: AppTokens.success,
      padding: const EdgeInsets.all(AppTokens.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(VenialCopy.criticalInsightsTitle, style: textTheme.titleSmall),
          const SizedBox(height: AppTokens.s8),
          ...insights.map(
            (insight) => Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.headline,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s4),
                  Text(
                    insight.supporting,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (result) {
      PredictionResult.correct => (
        VenialCopy.resultCorrect,
        AppTokens.success,
        Icons.check_circle_outline,
      ),
      PredictionResult.partial => (
        VenialCopy.resultPartial,
        AppTokens.warning,
        Icons.adjust,
      ),
      PredictionResult.wrong => (
        VenialCopy.resultWrong,
        AppTokens.danger,
        Icons.cancel_outlined,
      ),
      PredictionResult.pending => (
        VenialCopy.resultPending,
        AppTokens.blue,
        Icons.hourglass_empty,
      ),
    };

    return FcStatusChip(label: label, color: color, icon: icon);
  }
}

class _StatusMeta {
  const _StatusMeta({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

_StatusMeta _statusMeta(ProblemStatus status) {
  return switch (status) {
    ProblemStatus.improving => const _StatusMeta(
      label: VenialCopy.choiceImproveLabel,
      color: AppTokens.success,
      icon: Icons.trending_up,
    ),
    ProblemStatus.stable => const _StatusMeta(
      label: VenialCopy.choiceStableLabel,
      color: AppTokens.warning,
      icon: Icons.drag_handle,
    ),
    ProblemStatus.worsening => const _StatusMeta(
      label: VenialCopy.choiceWorsenLabel,
      color: AppTokens.danger,
      icon: Icons.trending_down,
    ),
  };
}

String _choiceLabel(PredictionChoice choice) {
  return switch (choice) {
    PredictionChoice.improve => VenialCopy.choiceImproveLabel,
    PredictionChoice.stable => VenialCopy.choiceStableLabel,
    PredictionChoice.worsen => VenialCopy.choiceWorsenLabel,
  };
}

String _motivationPrompt(PredictionChoice choice) {
  return switch (choice) {
    PredictionChoice.improve => 'Perche pensi che migliori?',
    PredictionChoice.stable => 'Perche pensi che resti stabile?',
    PredictionChoice.worsen => 'Perche pensi che peggiori?',
  };
}

Color _choiceColor(PredictionChoice choice) {
  return switch (choice) {
    PredictionChoice.improve => AppTokens.success,
    PredictionChoice.stable => AppTokens.warning,
    PredictionChoice.worsen => AppTokens.danger,
  };
}

String _confidenceLabel(HypothesisConfidence confidence) {
  return switch (confidence) {
    HypothesisConfidence.gutFeeling => VenialCopy.confidenceGutFeeling,
    HypothesisConfidence.considered => VenialCopy.confidenceConsidered,
    HypothesisConfidence.convinced => VenialCopy.confidenceConvinced,
  };
}
