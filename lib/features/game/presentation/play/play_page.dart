import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
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
                          onRefreshProblem: cubit.refreshProblem,
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
    required this.onRefreshProblem,
    super.key,
  });

  final PlayState state;
  final void Function(String problemId, PredictionChoice choice) onSelect;
  final void Function(String problemId) onRefreshProblem;

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
            'Nessun problema attivo per questo Comune',
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
          'Scegli come evolverà ogni problema in Fanta Comune.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppTokens.s16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.problems.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s12),
          itemBuilder: (context, index) {
            final problem = state.problems[index];
            final selectedChoice = state.myPredictions[problem.id];

            return ProblemCard(
              key: ValueKey(problem.id),
              problem: problem,
              selectedChoice: selectedChoice,
              onSelectChoice: (choice) => onSelect(problem.id, choice),
              onRefresh: () => onRefreshProblem(problem.id),
            );
          },
        ),
      ],
    );
  }
}
