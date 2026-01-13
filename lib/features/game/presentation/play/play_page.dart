import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/game_banner.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/core/widgets/pinned_note.dart';
import 'package:fanta_comune/core/widgets/stamp_action_button.dart';
import 'package:fanta_comune/core/widgets/sticker_badge.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/logic/play_cubit.dart';
import 'package:fanta_comune/features/game/logic/play_state.dart';
import 'package:fanta_comune/features/game/presentation/widgets/problem_card.dart';

/// Pagina della sezione di gioco che gestisce il loop \"vedo → prevedo → feedback\".
class PlayPage extends StatelessWidget {
  const PlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PlayCubit(
        repository: context.read<GameRepository>(),
        prefs: context.read<AppPrefs>(),
      )..load(),
      child: const _PlayView(),
    );
  }
}

class _PlayView extends StatelessWidget {
  const _PlayView();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final pagePadding = isCompact ? AppTokens.s12 : AppTokens.s16;

    return MaxWidthContainer(
      child: BlocBuilder<PlayCubit, PlayState>(
        builder: (context, state) {
          final cubit = context.read<PlayCubit>();

          return AnimatedSwitcherX(
            duration: AppMotion.normal,
            child: state.isLoading
                ? const Center(
                    key: ValueKey('play-loading'),
                    child: Padding(
                      padding: EdgeInsets.all(AppTokens.s24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : SingleChildScrollView(
                    key: const ValueKey('play-content'),
                    padding: EdgeInsets.all(pagePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BoardHeader(
                          onOpenBoard: () => context.go('/board'),
                          hasNewCards: state.hasPendingInsights || state.hasChangedPerception,
                        ),
                        SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
                        const IconLabel(icon: AppIcons.play, text: VenialCopy.playTabLabel),
                        SizedBox(height: isCompact ? AppTokens.s12 : AppTokens.s16),
                        _PlayContent(
                          key: ValueKey('has-problems-${state.problems.isNotEmpty}'),
                          state: state,
                          onSelect: (problemId, choice) => cubit.selectPrediction(
                            problemId: problemId,
                            choice: choice,
                          ),
                          onSelectMotivations: (problemId, motivations) => cubit.setMotivations(
                            problemId: problemId,
                            motivations: motivations,
                          ),
                          onSelectConfidence: (problemId, confidence) => cubit.setConfidence(
                            problemId: problemId,
                            confidence: confidence,
                          ),
                          onSelectReflectionAnswer: (problemId, selectedIndex) => cubit.setReflectionAnswer(
                            problemId: problemId,
                            selectedOptionIndex: selectedIndex,
                          ),
                          onRefreshProblem: cubit.refreshProblem,
                          onResolveTurn: cubit.resolveTurn,
                          onLoadHistory: cubit.loadProblemHistory,
                          onLoadCriticalInsights: cubit.loadCriticalInsights,
                          onMarkRetentionSeen: cubit.markRetentionSeen,
                        ),
                        if (state.error != null) ...[
                          const SizedBox(height: AppTokens.s12),
                          Text(
                            state.error!,
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({
    required this.onOpenBoard,
    required this.hasNewCards,
  });

  final VoidCallback onOpenBoard;
  final bool hasNewCards;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GameBanner(
      title: VenialCopy.playBoardHeaderTitle,
      subtitle: VenialCopy.playBoardHeaderSubtitle,
      stickerLabel: hasNewCards
          ? VenialCopy.bannerNewsLabel
          : VenialCopy.bannerTurnOpenLabel,
      cta: TextButton.icon(
        onPressed: onOpenBoard,
        icon: const Icon(AppIcons.board),
        label: const Text(VenialCopy.playBoardCta),
      ),
      image: Align(
        alignment: Alignment.centerRight,
        child: Icon(
          AppIcons.board,
          size: 96,
          color: colorScheme.onPrimaryContainer.withOpacity(0.2),
        ),
      ),
      shimmer: hasNewCards,
    );
  }
}

class _PlayContent extends StatelessWidget {
  const _PlayContent({
    required this.state,
    required this.onSelect,
    required this.onSelectMotivations,
    required this.onSelectConfidence,
    required this.onSelectReflectionAnswer,
    required this.onRefreshProblem,
    required this.onResolveTurn,
    required this.onLoadHistory,
    required this.onLoadCriticalInsights,
    required this.onMarkRetentionSeen,
    super.key,
  });

  final PlayState state;
  final void Function(String problemId, PredictionChoice choice) onSelect;
  final void Function(String problemId, List<MotivationKey> motivations) onSelectMotivations;
  final void Function(String problemId, HypothesisConfidence confidence) onSelectConfidence;
  final void Function(String problemId, int selectedIndex) onSelectReflectionAnswer;
  final void Function(String problemId) onRefreshProblem;
  final void Function(String problemId) onLoadHistory;
  final void Function(String problemId) onLoadCriticalInsights;
  final VoidCallback onResolveTurn;
  final VoidCallback onMarkRetentionSeen;

  String _countdownLabel() {
    final turn = state.currentTurn;
    if (turn == null) return '';
    final remaining = turn.endAt.difference(DateTime.now());
    final days = remaining.inDays;
    if (days > 0) {
      return VenialCopy.playCountdownDaysTemplate.replaceAll('{days}', '$days');
    }
    final hours = remaining.inHours;
    if (hours > 0) {
      return VenialCopy.playCountdownHoursTemplate.replaceAll('{hours}', '$hours');
    }
    return VenialCopy.playCountdownSoon;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final sectionGap = isCompact ? AppTokens.s8 : AppTokens.s12;

    if (state.problems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Text(
            VenialCopy.playEmpty,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              VenialCopy.playHeader,
              style: TypographyX.titleLarge(context),
            ),
            if (state.currentTurn != null)
              Text(
                _countdownLabel(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        SizedBox(height: sectionGap),
        Text(
          VenialCopy.playIntro,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (state.hasPendingInsights || state.hasChangedPerception) ...[
          SizedBox(height: sectionGap),
          AnimatedSwitcherX(
            duration: AppMotion.fast,
            child: _RetentionHintCard(
              key: ValueKey('retention-${state.hasChangedPerception}'),
              isChanged: state.hasChangedPerception,
              onTap: onMarkRetentionSeen,
            ),
          ),
        ],
        SizedBox(height: sectionGap),
        _ReputationCard(reputation: state.reputation),
        SizedBox(height: sectionGap),
        _ResolveTurnCard(
          enabled: state.myPredictions.isNotEmpty,
          onResolveTurn: onResolveTurn,
        ),
        if (state.myPredictions.isEmpty) ...[
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              VenialCopy.playResolveDisabledHint,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        SizedBox(height: isCompact ? AppTokens.s12 : AppTokens.s16),
        PrimaryCard(
          padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
          textured: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                VenialCopy.playNextProblemsTitle,
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.s8),
              Text(
                VenialCopy.playNextProblemsBody,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
              Wrap(
                spacing: AppTokens.s12,
                runSpacing: AppTokens.s8,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go('/suggest-problem'),
                    child: const Text(VenialCopy.playSuggestCta),
                  ),
                  FilledButton(
                    onPressed: () => context.go('/next-problems'),
                    child: const Text(VenialCopy.playVoteCta),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? AppTokens.s12 : AppTokens.s16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            final spacing = isCompact ? AppTokens.s8 : AppTokens.s12;
            final tileWidth = isWide
                ? (constraints.maxWidth - spacing) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final problem in state.problems)
                  SizedBox(
                    width: tileWidth,
                    child: _ProblemTile(
                      problem: problem,
                      state: state,
                      onSelect: onSelect,
                      onSelectMotivations: onSelectMotivations,
                      onSelectConfidence: onSelectConfidence,
                      onSelectReflectionAnswer: onSelectReflectionAnswer,
                      onRefreshProblem: onRefreshProblem,
                      onLoadCriticalInsights: onLoadCriticalInsights,
                      onLoadHistory: onLoadHistory,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProblemTile extends StatelessWidget {
  const _ProblemTile({
    required this.problem,
    required this.state,
    required this.onSelect,
    required this.onSelectMotivations,
    required this.onSelectConfidence,
    required this.onSelectReflectionAnswer,
    required this.onRefreshProblem,
    required this.onLoadCriticalInsights,
    required this.onLoadHistory,
  });

  final Problem problem;
  final PlayState state;
  final void Function(String problemId, PredictionChoice choice) onSelect;
  final void Function(String problemId, List<MotivationKey> motivations) onSelectMotivations;
  final void Function(String problemId, HypothesisConfidence confidence) onSelectConfidence;
  final void Function(String problemId, int selectedIndex) onSelectReflectionAnswer;
  final void Function(String problemId) onRefreshProblem;
  final void Function(String problemId) onLoadCriticalInsights;
  final void Function(String problemId) onLoadHistory;

  @override
  Widget build(BuildContext context) {
    final selectedChoice = state.myPredictions[problem.id];
    final result = state.results[problem.id];
    final insight = state.insights[problem.id];
    final history = state.insightHistories[problem.id];
    final isHistoryLoading = state.loadingInsightHistories.contains(problem.id);
    final selectedMotivations = state.motivations[problem.id] ?? const [];
    final selectedConfidence = state.confidences[problem.id];
    final reflectionQuestion = state.reflectionQuestions[problem.id];
    final reflectionAnswer = state.reflectionAnswers[problem.id];
    final criticalInsights = state.criticalInsights[problem.id] ?? const [];
    final isCriticalLoading = state.loadingCriticalInsights.contains(problem.id);

    return ProblemCard(
      key: ValueKey(problem.id),
      problem: problem,
      selectedChoice: selectedChoice,
      selectedMotivations: selectedMotivations,
      selectedConfidence: selectedConfidence,
      reflectionQuestion: reflectionQuestion,
      selectedReflectionAnswer: reflectionAnswer,
      criticalInsights: criticalInsights,
      isCriticalInsightsLoading: isCriticalLoading,
      onSelectChoice: (choice) => onSelect(problem.id, choice),
      onSelectMotivations: (motivations) => onSelectMotivations(problem.id, motivations),
      onSelectConfidence: (confidence) => onSelectConfidence(problem.id, confidence),
      onSelectReflectionAnswer: (selectedIndex) =>
          onSelectReflectionAnswer(problem.id, selectedIndex),
      onRefresh: () => onRefreshProblem(problem.id),
      onLoadCriticalInsights: () => onLoadCriticalInsights(problem.id),
      result: result,
      insight: insight,
      history: history,
      isHistoryLoading: isHistoryLoading,
      onLoadHistory: () => onLoadHistory(problem.id),
    );
  }
}

class _RetentionHintCard extends StatelessWidget {
  const _RetentionHintCard({
    required this.isChanged,
    required this.onTap,
    super.key,
  });

  final bool isChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final title = isChanged
        ? VenialCopy.retentionChangedTitle
        : VenialCopy.retentionPendingTitle;
    final body = isChanged
        ? VenialCopy.retentionChangedBody
        : VenialCopy.retentionPendingBody;

    return PinnedNote(
      angle: -0.02,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StickerBadge(
            label: isChanged ? VenialCopy.retentionStickerChanged : VenialCopy.retentionStickerPending,
            animate: true,
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            body,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTokens.s12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onTap,
              child: const Text(VenialCopy.retentionCta),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolveTurnCard extends StatelessWidget {
  const _ResolveTurnCard({
    required this.enabled,
    required this.onResolveTurn,
  });

  final bool enabled;
  final VoidCallback onResolveTurn;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PrimaryCard(
      padding: const EdgeInsets.all(AppTokens.s16),
      textured: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.s8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Icon(
              AppIcons.play,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: AppTokens.s12),
          Expanded(
            child: Text(
              VenialCopy.playResolveCardTitle,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: AppTokens.s12),
          StampActionButton(
            label: VenialCopy.playResolveCta,
            icon: AppIcons.play,
            onPressed: enabled ? onResolveTurn : null,
          ),
        ],
      ),
    );
  }
}

class _ReputationCard extends StatelessWidget {
  const _ReputationCard({required this.reputation});

  final ReputationScore reputation;

  String _accuracyLabel() {
    if (reputation.predictionsCount == 0) return '0%';
    return '${(reputation.accuracy * 100).clamp(0, 100).toStringAsFixed(0)}%';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PrimaryCard(
      padding: const EdgeInsets.all(AppTokens.s16),
      textured: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            VenialCopy.reputationTitle,
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.s8),
          Row(
            children: [
              _Metric(
                label: VenialCopy.reputationPointsLabel,
                value: reputation.totalPoints.toString(),
                icon: AppIcons.spark,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppTokens.s12),
              _Metric(
                label: VenialCopy.reputationAccuracyLabel,
                value: _accuracyLabel(),
                icon: Icons.adjust,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: AppTokens.s12),
              _Metric(
                label: VenialCopy.reputationPredictionsLabel,
                value: reputation.predictionsCount.toString(),
                icon: Icons.query_stats,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            VenialCopy.reputationHelper,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.s8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppTokens.s8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall,
              ),
              AnimatedSwitcherX(
                duration: AppMotion.fast,
                child: Text(
                  value,
                  key: ValueKey(value),
                  style: textTheme.titleMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
