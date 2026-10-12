import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/features/civic_loop/domain/civic_loop_summary.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
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

  String _countdownLabel(PlayState state) {
    final turn = state.currentTurn;
    if (turn == null) return '';
    final remaining = turn.endAt.difference(DateTime.now());
    final days = remaining.inDays;
    if (days > 0) {
      return VenialCopy.playCountdownDaysTemplate.replaceAll('{days}', '$days');
    }
    final hours = remaining.inHours;
    if (hours > 0) {
      return VenialCopy.playCountdownHoursTemplate.replaceAll(
        '{hours}',
        '$hours',
      );
    }
    return VenialCopy.playCountdownSoon;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final pagePadding = isCompact ? AppTokens.s12 : AppTokens.s16;

    return MaxWidthContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= 900 &&
              MediaQuery.textScalerOf(context).scale(14) <= 20;
          return BlocBuilder<PlayCubit, PlayState>(
            builder: (context, state) {
              final cubit = context.read<PlayCubit>();
              final sectionGap = isCompact ? AppTokens.s8 : AppTokens.s12;
              final problems = state.problems;
              final hasProblems = problems.isNotEmpty;
              final completed = problems
                  .where(
                    (problem) => state.myPredictions.containsKey(problem.id),
                  )
                  .length;
              final spacing = isCompact ? AppTokens.s8 : AppTokens.s12;

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
                    : CustomScrollView(
                        key: const PageStorageKey('play-scroll'),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.all(pagePadding),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _BoardHeader(
                                  onOpenBoard: () => context.go('/board'),
                                  hasNewCards:
                                      state.hasPendingInsights ||
                                      state.hasChangedPerception,
                                ),
                                SizedBox(
                                  height: isCompact
                                      ? AppTokens.s8
                                      : AppTokens.s12,
                                ),
                                SizedBox(height: sectionGap),
                                if (hasProblems) ...[
                                  Semantics(
                                    liveRegion: true,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$completed di ${problems.length} carte giocate',
                                          key: const ValueKey('play-progress'),
                                        ),
                                        const SizedBox(height: AppTokens.s8),
                                        LinearProgressIndicator(
                                          value: completed / problems.length,
                                          semanticsLabel:
                                              'Carte giocate: $completed di ${problems.length}',
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppTokens.s12),
                                  _TurnActionStrip(
                                    countdownLabel: _countdownLabel(state),
                                    predictionCount: completed,
                                    enabled: completed > 0,
                                    onResolveTurn: cubit.resolveTurn,
                                  ),
                                ],
                                if (state.civicSummary != null) ...[
                                  SizedBox(height: sectionGap),
                                  FcDisclosure(
                                    storageId:
                                        'play-summary-${state.civicSummary!.municipalityName}',
                                    title: 'Riepilogo del Comune',
                                    children: [
                                      _CivicLoopSummaryCard(
                                        summary: state.civicSummary!,
                                      ),
                                    ],
                                  ),
                                ],
                                if (state.hasPendingInsights ||
                                    state.hasChangedPerception) ...[
                                  SizedBox(height: sectionGap),
                                  AnimatedSwitcherX(
                                    duration: AppMotion.fast,
                                    child: _RetentionHintCard(
                                      key: ValueKey(
                                        'retention-${state.hasChangedPerception}',
                                      ),
                                      isChanged: state.hasChangedPerception,
                                      onTap: cubit.markRetentionSeen,
                                    ),
                                  ),
                                ],
                                SizedBox(
                                  height: isCompact
                                      ? AppTokens.s12
                                      : AppTokens.s16,
                                ),
                                _CardsSectionHeader(count: problems.length),
                                if (!hasProblems)
                                  const _ActivationEmptyTurn()
                                else
                                  SizedBox(
                                    height: isCompact
                                        ? AppTokens.s12
                                        : AppTokens.s16,
                                  ),
                              ]),
                            ),
                          ),
                          if (hasProblems)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                pagePadding,
                                0,
                                pagePadding,
                                pagePadding,
                              ),
                              sliver: isWide
                                  ? SliverList(
                                      delegate: SliverChildBuilderDelegate((
                                        context,
                                        index,
                                      ) {
                                        final leftIndex = index * 2;
                                        final rightIndex = leftIndex + 1;
                                        final leftProblem = problems[leftIndex];
                                        final rightProblem =
                                            rightIndex < problems.length
                                            ? problems[rightIndex]
                                            : null;
                                        final bottomPadding =
                                            index ==
                                                ((problems.length - 1) ~/ 2)
                                            ? 0.0
                                            : spacing;

                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: bottomPadding,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: _ProblemTile(
                                                  problem: leftProblem,
                                                  position: leftIndex + 1,
                                                  total: problems.length,
                                                  state: state,
                                                  onSelect:
                                                      (problemId, choice) =>
                                                          cubit
                                                              .selectPrediction(
                                                                problemId:
                                                                    problemId,
                                                                choice: choice,
                                                              ),
                                                  onSelectMotivations:
                                                      (
                                                        problemId,
                                                        motivations,
                                                      ) => cubit.setMotivations(
                                                        problemId: problemId,
                                                        motivations:
                                                            motivations,
                                                      ),
                                                  onSelectConfidence:
                                                      (
                                                        problemId,
                                                        confidence,
                                                      ) => cubit.setConfidence(
                                                        problemId: problemId,
                                                        confidence: confidence,
                                                      ),
                                                  onSelectReflectionAnswer:
                                                      (
                                                        problemId,
                                                        selectedIndex,
                                                      ) => cubit
                                                          .setReflectionAnswer(
                                                            problemId:
                                                                problemId,
                                                            selectedOptionIndex:
                                                                selectedIndex,
                                                          ),
                                                  onRefreshProblem:
                                                      cubit.refreshProblem,
                                                  onLoadHistory:
                                                      cubit.loadProblemHistory,
                                                  onLoadCriticalInsights: cubit
                                                      .loadCriticalInsights,
                                                ),
                                              ),
                                              SizedBox(width: spacing),
                                              Expanded(
                                                child: rightProblem == null
                                                    ? const SizedBox.shrink()
                                                    : _ProblemTile(
                                                        problem: rightProblem,
                                                        position:
                                                            rightIndex + 1,
                                                        total: problems.length,
                                                        state: state,
                                                        onSelect:
                                                            (
                                                              problemId,
                                                              choice,
                                                            ) => cubit
                                                                .selectPrediction(
                                                                  problemId:
                                                                      problemId,
                                                                  choice:
                                                                      choice,
                                                                ),
                                                        onSelectMotivations:
                                                            (
                                                              problemId,
                                                              motivations,
                                                            ) => cubit
                                                                .setMotivations(
                                                                  problemId:
                                                                      problemId,
                                                                  motivations:
                                                                      motivations,
                                                                ),
                                                        onSelectConfidence:
                                                            (
                                                              problemId,
                                                              confidence,
                                                            ) => cubit
                                                                .setConfidence(
                                                                  problemId:
                                                                      problemId,
                                                                  confidence:
                                                                      confidence,
                                                                ),
                                                        onSelectReflectionAnswer:
                                                            (
                                                              problemId,
                                                              selectedIndex,
                                                            ) => cubit.setReflectionAnswer(
                                                              problemId:
                                                                  problemId,
                                                              selectedOptionIndex:
                                                                  selectedIndex,
                                                            ),
                                                        onRefreshProblem: cubit
                                                            .refreshProblem,
                                                        onLoadHistory: cubit
                                                            .loadProblemHistory,
                                                        onLoadCriticalInsights:
                                                            cubit
                                                                .loadCriticalInsights,
                                                      ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }, childCount: (problems.length / 2).ceil()),
                                    )
                                  : SliverList(
                                      delegate: SliverChildBuilderDelegate((
                                        context,
                                        index,
                                      ) {
                                        final bottomPadding =
                                            index == problems.length - 1
                                            ? 0.0
                                            : spacing;
                                        final problem = problems[index];

                                        return Padding(
                                          padding: EdgeInsets.only(
                                            bottom: bottomPadding,
                                          ),
                                          child: _ProblemTile(
                                            problem: problem,
                                            position: index + 1,
                                            total: problems.length,
                                            state: state,
                                            onSelect: (problemId, choice) =>
                                                cubit.selectPrediction(
                                                  problemId: problemId,
                                                  choice: choice,
                                                ),
                                            onSelectMotivations:
                                                (problemId, motivations) =>
                                                    cubit.setMotivations(
                                                      problemId: problemId,
                                                      motivations: motivations,
                                                    ),
                                            onSelectConfidence:
                                                (problemId, confidence) =>
                                                    cubit.setConfidence(
                                                      problemId: problemId,
                                                      confidence: confidence,
                                                    ),
                                            onSelectReflectionAnswer:
                                                (problemId, selectedIndex) =>
                                                    cubit.setReflectionAnswer(
                                                      problemId: problemId,
                                                      selectedOptionIndex:
                                                          selectedIndex,
                                                    ),
                                            onRefreshProblem:
                                                cubit.refreshProblem,
                                            onLoadHistory:
                                                cubit.loadProblemHistory,
                                            onLoadCriticalInsights:
                                                cubit.loadCriticalInsights,
                                          ),
                                        );
                                      }, childCount: problems.length),
                                    ),
                            ),
                          if (state.error != null)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                pagePadding,
                                0,
                                pagePadding,
                                pagePadding,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: Text(
                                  state.error!,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ActivationEmptyTurn extends StatelessWidget {
  const _ActivationEmptyTurn();

  static const _missions = [
    (Icons.car_repair, VenialCopy.activationMissionPotholes),
    (Icons.lightbulb_outline, VenialCopy.activationMissionLighting),
    (Icons.delete_outline, VenialCopy.activationMissionWaste),
    (Icons.park_outlined, VenialCopy.activationMissionGreen),
    (Icons.shield_outlined, VenialCopy.activationMissionSafety),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.s12),
      child: FcPanel(
        tint: AppTokens.blue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              VenialCopy.activationTitle,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppTokens.s8),
            Text(
              VenialCopy.activationSubtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTokens.s12),
            Wrap(
              spacing: AppTokens.s8,
              runSpacing: AppTokens.s8,
              children: _missions
                  .map(
                    (mission) => FcStatusChip(
                      label: mission.$2,
                      icon: mission.$1,
                      color: AppTokens.blue,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppTokens.s16),
            Wrap(
              spacing: AppTokens.s12,
              runSpacing: AppTokens.s8,
              children: [
                FilledButton(
                  onPressed: () => context.push('/suggest-problem'),
                  child: const Text(VenialCopy.activationPrimaryCta),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/next-problems'),
                  child: const Text(VenialCopy.activationSecondaryCta),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({required this.onOpenBoard, required this.hasNewCards});
  final VoidCallback onOpenBoard;
  final bool hasNewCards;

  @override
  Widget build(BuildContext context) {
    final municipality = context.watch<AppPrefs>().municipalityId ?? 'demo';
    return FcSectionHeader(
      title:
          'Il turno di ${MunicipalityCatalog.displayNameFromId(municipality)}',
      subtitle: hasNewCards
          ? 'Gioco delle previsioni · nuovi esiti disponibili'
          : 'Gioco delle previsioni · nessuna segnalazione ufficiale',
      action: OutlinedButton(
        onPressed: onOpenBoard,
        child: const Text(VenialCopy.playBoardCta),
      ),
    );
  }
}

class _ProblemTile extends StatelessWidget {
  const _ProblemTile({
    required this.problem,
    required this.position,
    required this.total,
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
  final int position;
  final int total;
  final PlayState state;
  final void Function(String problemId, PredictionChoice choice) onSelect;
  final void Function(String problemId, List<MotivationKey> motivations)
  onSelectMotivations;
  final void Function(String problemId, HypothesisConfidence confidence)
  onSelectConfidence;
  final void Function(String problemId, int selectedIndex)
  onSelectReflectionAnswer;
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
    final isCriticalLoading = state.loadingCriticalInsights.contains(
      problem.id,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Problema $position di $total',
            key: ValueKey('play-position-${problem.id}'),
          ),
        ),
        const SizedBox(height: AppTokens.s8),
        ProblemCard(
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
          onSelectMotivations: (motivations) =>
              onSelectMotivations(problem.id, motivations),
          onSelectConfidence: (confidence) =>
              onSelectConfidence(problem.id, confidence),
          onSelectReflectionAnswer: (selectedIndex) =>
              onSelectReflectionAnswer(problem.id, selectedIndex),
          onRefresh: () => onRefreshProblem(problem.id),
          onLoadCriticalInsights: () => onLoadCriticalInsights(problem.id),
          result: result,
          insight: insight,
          history: history,
          isHistoryLoading: isHistoryLoading,
          onLoadHistory: () => onLoadHistory(problem.id),
        ),
      ],
    );
  }
}

class _TurnActionStrip extends StatelessWidget {
  const _TurnActionStrip({
    required this.countdownLabel,
    required this.predictionCount,
    required this.enabled,
    required this.onResolveTurn,
  });

  final String countdownLabel;
  final int predictionCount;
  final bool enabled;
  final VoidCallback onResolveTurn;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return FcPanel(
      padding: const EdgeInsets.all(AppTokens.s14),
      tint: AppTokens.blue,
      child: Wrap(
        spacing: AppTokens.s12,
        runSpacing: AppTokens.s12,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  VenialCopy.playHeader,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppTokens.s4),
                Text(
                  predictionCount == 0
                      ? VenialCopy.playResolveDisabledHint
                      : '$predictionCount carte giocate. Puoi scoprire gli esiti mock.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (countdownLabel.isNotEmpty) ...[
                  const SizedBox(height: AppTokens.s4),
                  Text(
                    countdownLabel,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          FilledButton(
            onPressed: enabled ? onResolveTurn : null,
            child: const Text(VenialCopy.playResolveCta),
          ),
        ],
      ),
    );
  }
}

class _CivicLoopSummaryCard extends StatelessWidget {
  const _CivicLoopSummaryCard({required this.summary});

  final CivicLoopSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final items = [
      (
        Icons.add_circle_outline,
        'Proposte',
        summary.proposedThemes.toString(),
        AppTokens.blue,
      ),
      (
        Icons.how_to_vote_outlined,
        'Confermate',
        summary.confirmedThemes.toString(),
        AppTokens.success,
      ),
      (
        AppIcons.board,
        'Carte',
        summary.cardsInTurn.toString(),
        AppTokens.warning,
      ),
      (
        Icons.psychology_alt_outlined,
        'Previsioni',
        summary.predictions.toString(),
        AppTokens.blue,
      ),
      (
        Icons.fact_check_outlined,
        'Esiti',
        summary.outcomes.toString(),
        AppTokens.success,
      ),
      (
        Icons.emoji_events_outlined,
        'Reputazione',
        '${summary.reputationPoints} pt',
        AppTokens.navy,
      ),
    ];
    final body = summary.topThemeTitle == null
        ? 'Nessun tema promosso nel turno: proponi o conferma una priorita\'.'
        : 'Tema piu\' votato tra le carte: ${summary.topThemeTitle}. Il turno puo\' contenere piu\' carte civiche.';

    return FcPanel(
      padding: const EdgeInsets.all(AppTokens.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FcSectionHeader(title: 'Riepilogo ${summary.municipalityName}'),
          const SizedBox(height: AppTokens.s8),
          FcStatusChip(
            label: summary.hasCompleteLoop ? 'Loop completo' : 'In corso',
            color: summary.hasCompleteLoop ? AppTokens.success : AppTokens.blue,
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            body,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppTokens.s12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth < 600 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20
                  ? 1
                  : 3;
              final width =
                  (constraints.maxWidth - AppTokens.s8 * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppTokens.s8,
                runSpacing: AppTokens.s8,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      child: _CivicMetric(
                        icon: item.$1,
                        label: item.$2,
                        value: item.$3,
                        color: item.$4,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CivicMetric extends StatelessWidget {
  const _CivicMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.s8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppTokens.s8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardsSectionHeader extends StatelessWidget {
  const _CardsSectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          VenialCopy.playCardsTitle,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppTokens.s4),
        Text(
          count == 0
              ? VenialCopy.playEmpty
              : VenialCopy.playCardsSubtitle.replaceAll('{count}', '$count'),
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
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

    return FcPanel(
      tint: isChanged ? AppTokens.success : AppTokens.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FcStatusChip(
            label: isChanged
                ? VenialCopy.retentionStickerChanged
                : VenialCopy.retentionStickerPending,
            color: isChanged ? AppTokens.success : AppTokens.blue,
            icon: isChanged ? Icons.bolt_outlined : Icons.style_outlined,
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
