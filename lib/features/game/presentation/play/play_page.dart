import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
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
                    padding: const EdgeInsets.all(AppTokens.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const IconLabel(icon: AppIcons.play, text: 'Gioca'),
                        const SizedBox(height: AppTokens.s16),
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
                          onRefreshProblem: cubit.refreshProblem,
                          onResolveTurn: cubit.resolveTurn,
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

class _PlayContent extends StatelessWidget {
  const _PlayContent({
    required this.state,
    required this.onSelect,
    required this.onSelectMotivations,
    required this.onRefreshProblem,
    required this.onResolveTurn,
    super.key,
  });

  final PlayState state;
  final void Function(String problemId, PredictionChoice choice) onSelect;
  final void Function(String problemId, List<MotivationKey> motivations) onSelectMotivations;
  final void Function(String problemId) onRefreshProblem;
  final VoidCallback onResolveTurn;

  String _countdownLabel() {
    final turn = state.currentTurn;
    if (turn == null) return '';
    final remaining = turn.endAt.difference(DateTime.now());
    final days = remaining.inDays;
    if (days > 0) {
      return 'Chiude tra $days giorni';
    }
    final hours = remaining.inHours;
    if (hours > 0) {
      return 'Chiude tra $hours ore';
    }
    return 'In chiusura';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (state.problems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Text(
            'Non ci sono situazioni aperte ora. Torna presto per una nuova sfida di Fanta Comune.',
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
              'Gioca',
              style: textTheme.titleLarge,
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
        const SizedBox(height: AppTokens.s12),
        Text(
          'Scegli come pensi evolverà ogni situazione, poi scopri il feedback di Fanta Comune.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        _ReputationCard(reputation: state.reputation),
        const SizedBox(height: AppTokens.s12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: state.myPredictions.isEmpty ? null : onResolveTurn,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Scopri com’è andata'),
          ),
        ),
        if (state.myPredictions.isEmpty) ...[
          const SizedBox(height: AppTokens.s8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Scegli almeno una situazione per vedere il responso.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppTokens.s16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.problems.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s12),
          itemBuilder: (context, index) {
            final problem = state.problems[index];
            final selectedChoice = state.myPredictions[problem.id];
            final result = state.results[problem.id];
            final selectedMotivations = state.motivations[problem.id] ?? const [];

            return ProblemCard(
              key: ValueKey(problem.id),
              problem: problem,
              selectedChoice: selectedChoice,
              selectedMotivations: selectedMotivations,
              onSelectChoice: (choice) => onSelect(problem.id, choice),
              onSelectMotivations: (motivations) => onSelectMotivations(problem.id, motivations),
              onRefresh: () => onRefreshProblem(problem.id),
              result: result,
            );
          },
        ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reputazione',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.s8),
          Row(
            children: [
              _Metric(
                label: 'Punti',
                value: reputation.totalPoints.toString(),
                icon: AppIcons.spark,
                color: colorScheme.primary,
              ),
              const SizedBox(width: AppTokens.s12),
              _Metric(
                label: 'Accuratezza',
                value: _accuracyLabel(),
                icon: Icons.adjust,
                color: colorScheme.tertiary,
              ),
              const SizedBox(width: AppTokens.s12),
              _Metric(
                label: 'Previsioni',
                value: reputation.predictionsCount.toString(),
                icon: Icons.query_stats,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            'Ogni esito aggiorna punti e affidabilità: scopri come cambia la tua reputazione dopo il responso.',
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
