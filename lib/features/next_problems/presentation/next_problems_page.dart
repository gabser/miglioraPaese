import 'package:flutter/material.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_size_x.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/segmented_choice.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_cubit.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_state.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_scope_notice.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';

class NextProblemsPage extends StatelessWidget {
  const NextProblemsPage({this.routeContext, super.key});

  final ProposalRouteContext? routeContext;

  @override
  Widget build(BuildContext context) {
    final scope =
        routeContext ??
        ProposalRouteContext.fromPreference(
          context.watch<AppPrefs>().municipalityId,
        );
    if (scope.municipalityId == null) {
      return ProposalScopeNotice(
        invalid: scope.invalid,
        returnTo: '/next-problems',
      );
    }
    return BlocProvider(
      key: ValueKey(scope.key),
      create: (context) => NextProblemsCubit(
        repository: context.read<NextProblemsRepository>(),
        prefs: context.read<AppPrefs>(),
        municipalityId: scope.municipalityId,
      )..load(),
      child: _NextProblemsView(routeContext: scope),
    );
  }
}

Future<void> _openProposalForm(
  BuildContext context,
  String? municipality,
) async {
  final list = context.read<NextProblemsCubit>();
  await context.push(
    ProposalRouteContext.location('/suggest-problem', municipality),
  );
  if (context.mounted && !list.isClosed) {
    await list.load();
  }
}

class _NextProblemsView extends StatelessWidget {
  const _NextProblemsView({required this.routeContext});
  final ProposalRouteContext routeContext;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          tooltip: (GoRouter.maybeOf(context)?.canPop() ?? false)
              ? 'Torna indietro'
              : 'Torna alla home',
          icon: const Icon(AppIcons.back),
        ),
        title: const Text(VenialCopy.appTitle),
        actions: [
          IconButton(
            onPressed: () =>
                _openProposalForm(context, routeContext.municipalityId),
            tooltip: VenialCopy.playSuggestCta,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          child: Padding(
            padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        VenialCopy.nextProblemsHeader,
                        style: TypographyX.titleLarge(context),
                      ),
                      const SizedBox(height: AppTokens.s8),
                      Text(
                        'Comune: ${MunicipalityCatalog.displayNameFromId(routeContext.municipalityId!)} · ${context.read<AppConfig?>()?.nextProblemsDataSource == NextProblemsDataSource.api ? 'Proposte online' : 'Demo locale'}',
                      ),
                      const SizedBox(height: AppTokens.s8),
                      Text(
                        VenialCopy.nextProblemsIntro,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(
                        height: isCompact ? AppTokens.s12 : AppTokens.s16,
                      ),
                      const _Controls(),
                      _LastReceipt(
                        municipalityId: routeContext.municipalityId!,
                      ),
                      SizedBox(
                        height: isCompact ? AppTokens.s12 : AppTokens.s16,
                      ),
                    ],
                  ),
                ),
                const _Content(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LastReceipt extends StatelessWidget {
  const _LastReceipt({required this.municipalityId});
  final String municipalityId;

  @override
  Widget build(BuildContext context) {
    final coordinator = context.watch<ProposalSubmissionCoordinator?>();
    if (coordinator == null) return const SizedBox.shrink();
    final prefs = context.watch<AppPrefs>();
    final scope = ProposalScope.fromConfig(
      municipalityId: municipalityId,
      config: context.read<AppConfig>(),
      namespace: prefs.localData.namespace,
    );
    final view = coordinator.savedReceipt(scope);
    if (view.status == SubmissionStatus.storageFailed) {
      return const Padding(
        padding: EdgeInsets.only(top: AppTokens.s12),
        child: Text(
          'Le ricevute locali non sono leggibili. Non inviare di nuovo per recuperarle.',
        ),
      );
    }
    final receipt = view.intent?.receipt;
    if (receipt == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppTokens.s12),
      child: OutlinedButton(
        key: const ValueKey('last-proposal-receipt'),
        onPressed: () => context.push(
          ProposalRouteContext.receiptLocation(receipt.id, municipalityId),
        ),
        child: const Text('Ultimo invio · Leggi la ricevuta'),
      ),
    );
  }
}

class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NextProblemsCubit>();
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return BlocListener<NextProblemsCubit, NextProblemsState>(
      listenWhen: (previous, next) => previous.query != next.query,
      listener: (_, state) {
        if (_searchController.text != state.query) {
          _searchController.value = TextEditingValue(
            text: state.query,
            selection: TextSelection.collapsed(offset: state.query.length),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('next-problems-search'),
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: VenialCopy.nextProblemsSearchHint,
            ),
            onChanged: cubit.setQuery,
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          BlocBuilder<NextProblemsCubit, NextProblemsState>(
            buildWhen: (prev, next) =>
                prev.filterStatus != next.filterStatus ||
                prev.sortMode != next.sortMode,
            builder: (context, state) {
              return Wrap(
                spacing: AppTokens.s8,
                runSpacing: AppTokens.s8,
                children: [
                  ChoiceChip(
                    label: const Text(VenialCopy.nextProblemsFilterAll),
                    selected: state.filterStatus == null,
                    onSelected: (_) => cubit.setFilterStatus(null),
                  ),
                  ChoiceChip(
                    label: const Text(VenialCopy.nextProblemsStatusPending),
                    selected:
                        state.filterStatus == SuggestedProblemStatus.pending,
                    onSelected: (_) =>
                        cubit.setFilterStatus(SuggestedProblemStatus.pending),
                  ),
                  ChoiceChip(
                    label: const Text(VenialCopy.nextProblemsStatusApproved),
                    selected:
                        state.filterStatus == SuggestedProblemStatus.approved,
                    onSelected: (_) =>
                        cubit.setFilterStatus(SuggestedProblemStatus.approved),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          BlocBuilder<NextProblemsCubit, NextProblemsState>(
            buildWhen: (prev, next) => prev.sortMode != next.sortMode,
            builder: (context, state) {
              return SegmentedChoice<NextProblemsSortMode>(
                value: state.sortMode,
                options: const [
                  NextProblemsSortMode.hot,
                  NextProblemsSortMode.newest,
                  NextProblemsSortMode.controversial,
                ],
                labelBuilder: (mode) => switch (mode) {
                  NextProblemsSortMode.hot => VenialCopy.nextProblemsSortHot,
                  NextProblemsSortMode.newest => VenialCopy.nextProblemsSortNew,
                  NextProblemsSortMode.controversial =>
                    VenialCopy.nextProblemsSortSplit,
                },
                optionBuilder: (mode, isSelected) {
                  final icon = switch (mode) {
                    NextProblemsSortMode.hot =>
                      Icons.local_fire_department_outlined,
                    NextProblemsSortMode.newest => Icons.schedule_outlined,
                    NextProblemsSortMode.controversial =>
                      Icons.whatshot_outlined,
                  };
                  return Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTokens.s8),
                      Text(switch (mode) {
                        NextProblemsSortMode.hot =>
                          VenialCopy.nextProblemsSortHot,
                        NextProblemsSortMode.newest =>
                          VenialCopy.nextProblemsSortNew,
                        NextProblemsSortMode.controversial =>
                          VenialCopy.nextProblemsSortSplit,
                      }),
                    ],
                  );
                },
                onChanged: cubit.setSortMode,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NextProblemsCubit, NextProblemsState>(
      builder: (context, state) {
        Widget child;
        if (state.isLoading) {
          child = const Center(
            key: ValueKey('next-problems-loading'),
            child: CircularProgressIndicator(),
          );
        } else if (state.error != null) {
          child = _NextProblemsError(
            key: const ValueKey('next-problems-error'),
            message: state.error!,
            onRetry: context.read<NextProblemsCubit>().refresh,
          );
        } else if (state.items.isEmpty) {
          child = _NextProblemsEmpty(
            key: const ValueKey('next-problems-empty'),
            isFiltered:
                state.query.trim().isNotEmpty || state.filterStatus != null,
          );
        } else {
          return SliverList.separated(
            key: ValueKey('next-problems-${state.items.length}'),
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s12),
            itemBuilder: (context, index) {
              return _ProblemCard(problem: state.items[index]);
            },
          );
        }

        return SliverFillRemaining(hasScrollBody: false, child: child);
      },
    );
  }
}

class _NextProblemsError extends StatelessWidget {
  const _NextProblemsError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        child: FcPanel(
          tint: AppTokens.danger,
          padding: const EdgeInsets.all(AppTokens.s20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                color: colorScheme.error,
                size: 32,
              ),
              const SizedBox(height: AppTokens.s12),
              Text(
                'Temi non disponibili',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.s16),
              FilledButton.icon(
                key: const ValueKey('next-problems-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextProblemsEmpty extends StatelessWidget {
  const _NextProblemsEmpty({super.key, required this.isFiltered});

  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final body = isFiltered
        ? VenialCopy.nextProblemsEmpty
        : VenialCopy.nextProblemsActivationEmpty;

    return Center(
      child: SingleChildScrollView(
        child: FcPanel(
          padding: const EdgeInsets.all(AppTokens.s20),
          tint: AppTokens.blue,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isFiltered)
                const FcStatusChip(
                  label: 'Nessuna proposta',
                  color: AppTokens.blue,
                  icon: AppIcons.play,
                ),
              const SizedBox(height: AppTokens.s12),
              Text(
                body,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (!isFiltered) ...[
                const SizedBox(height: AppTokens.s12),
                Text(
                  VenialCopy.activationGoal,
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const SizedBox(height: AppTokens.s16),
              if (isFiltered)
                FilledButton(
                  key: const ValueKey('next-problems-clear-filters'),
                  onPressed: context.read<NextProblemsCubit>().clearFilters,
                  child: const Text('Azzera ricerca e filtri'),
                )
              else ...[
                const Text(
                  'Puoi proporre, per esempio, un percorso poco illuminato o rami che ostacolano il passaggio.',
                ),
                const SizedBox(height: AppTokens.s12),
                FilledButton(
                  onPressed: () => _openProposalForm(
                    context,
                    context.read<NextProblemsCubit>().state.municipalityId,
                  ),
                  child: const Text(VenialCopy.activationPrimaryCta),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.problem});

  final SuggestedProblem problem;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final cubit = context.read<NextProblemsCubit>();
    final isCompact = MediaQuery.of(context).size.width < 600;
    final isVoting = context.select<NextProblemsCubit, bool>(
      (cubit) => cubit.state.votingProblemIds.contains(problem.id),
    );

    return FcPanel(
      padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
      elevated: problem.myVote != VoteChoice.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                ),
                child: Icon(
                  AppIcons.forProblemKey(problem.category),
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(problem.title, style: textTheme.titleMedium),
                    const SizedBox(height: AppTokens.s4),
                    Text(
                      problem.location?.displayLabel ?? 'Luogo non specificato',
                    ),
                    if (problem.location?.reference != null)
                      Text(problem.location!.reference!),
                    const SizedBox(height: AppTokens.s4),
                    Text(
                      problem.shortDescription,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          Wrap(
            spacing: AppTokens.s8,
            runSpacing: AppTokens.s8,
            children: [
              _StatusPill(status: problem.status),
              _CategoryChip(category: problem.category),
              Text(
                '${VenialCopy.nextProblemsProposedBy} ${problem.submittedByDisplayName}',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          TextButton(
            key: ValueKey('proposal-detail-${problem.id}'),
            onPressed: () => context.push(
              ProposalRouteContext.detailLocation(
                problem.id,
                cubit.state.municipalityId!,
              ),
            ),
            child: const Text('Apri il dettaglio'),
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          AnimatedSizeX(
            duration: AppMotion.fast,
            child: problem.status == SuggestedProblemStatus.pending
                ? Text(
                    VenialCopy.nextProblemsPendingHelper,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          _PromotionRuleBlock(problem: problem),
          SizedBox(height: isCompact ? AppTokens.s8 : AppTokens.s12),
          Wrap(
            spacing: AppTokens.s12,
            runSpacing: AppTokens.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _StampVoteButton(
                problemTitle: problem.title,
                label: VenialCopy.nextProblemsVoteUpLabel,
                count: problem.votesUp,
                selected: problem.myVote == VoteChoice.up,
                onPressed: isVoting
                    ? null
                    : () async {
                        final outcome = await cubit.vote(
                          problem.id,
                          VoteChoice.up,
                        );
                        if (!context.mounted ||
                            outcome == VoteOutcome.ignored) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              outcome == VoteOutcome.succeeded
                                  ? VenialCopy.nextProblemsVotedSnack
                                  : cubit.state.voteError ??
                                        'Voto non registrato.',
                            ),
                          ),
                        );
                      },
              ),
              _StampVoteButton(
                problemTitle: problem.title,
                label: VenialCopy.nextProblemsVoteDownLabel,
                count: problem.votesDown,
                selected: problem.myVote == VoteChoice.down,
                onPressed: isVoting
                    ? null
                    : () async {
                        final outcome = await cubit.vote(
                          problem.id,
                          VoteChoice.down,
                        );
                        if (!context.mounted ||
                            outcome == VoteOutcome.ignored) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              outcome == VoteOutcome.succeeded
                                  ? VenialCopy.nextProblemsVotedSnack
                                  : cubit.state.voteError ??
                                        'Voto non registrato.',
                            ),
                          ),
                        );
                      },
              ),

              if (problem.myVote != VoteChoice.none)
                Text(
                  VenialCopy.nextProblemsVoteHint,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromotionRuleBlock extends StatelessWidget {
  const _PromotionRuleBlock({required this.problem});

  final SuggestedProblem problem;

  String _progressText() {
    if (problem.approvalsNeeded == 0) {
      return VenialCopy.nextProblemsPromotionComplete;
    }
    if (problem.approvalsNeeded == 1) {
      return VenialCopy.nextProblemsPromotionMissingSingular;
    }
    return VenialCopy.nextProblemsPromotionMissingPlural.replaceAll(
      '{count}',
      '${problem.approvalsNeeded}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.s12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withOpacity(0.55),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_outlined, size: 18),
              const SizedBox(width: AppTokens.s8),
              Expanded(
                child: Text(
                  VenialCopy.nextProblemsPromotionTitle,
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${problem.score.clamp(0, problem.promotionRule.threshold)} / ${problem.promotionRule.threshold}',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          LinearProgressIndicator(
            value: problem.promotionProgress,
            minHeight: 7,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            _progressText(),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.s4),
          Text(
            '${problem.promotionRule.scopeLabel}. ${problem.promotionRule.reason}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StampVoteButton extends StatelessWidget {
  const _StampVoteButton({
    required this.label,
    required this.problemTitle,
    required this.count,
    required this.onPressed,
    required this.selected,
  });

  final String label;
  final String problemTitle;
  final int count;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onPressed != null,
      label: '$label per $problemTitle, $count voti',
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(80, 48),
          foregroundColor: selected
              ? AppTokens.blueForeground
              : scheme.onSurface,
          backgroundColor: selected ? scheme.primaryContainer : scheme.surface,
          side: BorderSide(color: selected ? scheme.primary : scheme.outline),
        ),
        child: Wrap(
          spacing: AppTokens.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (selected) const Icon(Icons.check_circle_outline, size: 18),
            Text(label),
            Text('$count'),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final ProblemKey category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s12,
        vertical: AppTokens.s8 / 2,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Text(
        AppIcons.labelForProblemKey(category),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final SuggestedProblemStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      SuggestedProblemStatus.pending => (
        VenialCopy.nextProblemsStatusPending,
        colorScheme.surfaceContainerHigh,
      ),
      SuggestedProblemStatus.approved => (
        VenialCopy.nextProblemsStatusApproved,
        colorScheme.primaryContainer,
      ),
      SuggestedProblemStatus.rejected => (
        VenialCopy.nextProblemsStatusRejected,
        colorScheme.errorContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s12,
        vertical: AppTokens.s8 / 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
