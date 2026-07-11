import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/game_banner.dart';
import 'package:fanta_comune/features/civic_loop/domain/civic_loop_summary.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/prediction.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

/// Dashboard principale ispirata al mockup Fanta Comune.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<GameRepository>();
    final prefs = context.read<AppPrefs>();
    final municipalityId = prefs.municipalityId ?? 'demo';

    return FutureBuilder<_HomeSnapshot>(
      future: _loadHomeSnapshot(repository, municipalityId),
      builder: (context, snapshot) {
        final data = snapshot.data;

        return SingleChildScrollView(
          child: FcPageShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GameBanner(
                  title: 'Fanta Comune',
                  subtitle:
                      'Prevedi come si muovono i problemi della citta\', confronta le percezioni e scala la classifica locale.',
                  stickerLabel: data == null
                      ? 'Turno in caricamento'
                      : _turnLabel(data.turn),
                  shimmer: data?.predictions.isNotEmpty ?? false,
                  cta: FilledButton.icon(
                    onPressed: () => context.go('/play'),
                    icon: const Icon(AppIcons.play),
                    label: const Text('Gioca il turno'),
                  ),
                ),
                const SizedBox(height: AppTokens.s20),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    data == null)
                  const _HomeLoading()
                else if (snapshot.hasError)
                  FcPanel(
                    tint: AppTokens.danger,
                    child: Text(
                      'Impossibile caricare la dashboard: ${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  )
                else if (data != null)
                  _HomeDashboard(data: data),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({required this.data});

  final _HomeSnapshot data;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= AppTokens.wideBreakpoint;
    if (data.activationState != MunicipalityActivationState.active ||
        data.problems.isEmpty) {
      return _MunicipalityActivationDashboard(data: data);
    }

    final topProblems = data.problems.take(5).toList(growable: false);
    final myRank = data.leaderboard.where(
      (entry) => entry.userId == data.currentUserId,
    );
    final rankLabel = myRank.isEmpty ? 'n/d' : '#${myRank.first.rank}';
    final accuracy = data.reputation.predictionsCount == 0
        ? '0%'
        : '${(data.reputation.accuracy * 100).round()}%';

    final metrics = [
      FcMetricCard(
        label: 'Problemi attivi',
        value: data.problems.length.toString(),
        icon: AppIcons.board,
        color: AppTokens.blue,
        caption: 'Turno aperto',
      ),
      FcMetricCard(
        label: 'Tue previsioni',
        value: data.predictions.length.toString(),
        icon: Icons.how_to_vote_outlined,
        color: AppTokens.success,
        caption: 'Su questo turno',
      ),
      FcMetricCard(
        label: 'Accuratezza',
        value: accuracy,
        icon: Icons.adjust,
        color: AppTokens.warning,
        caption: 'Mock locale',
      ),
      FcMetricCard(
        label: 'Classifica',
        value: rankLabel,
        icon: AppIcons.leaderboard,
        color: AppTokens.navy,
        caption: '${data.reputation.totalPoints} pt',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: AppTokens.s12,
                mainAxisSpacing: AppTokens.s12,
                childAspectRatio: columns == 4 ? 1.42 : 1.12,
              ),
              itemBuilder: (context, index) => metrics[index],
            );
          },
        ),
        const SizedBox(height: AppTokens.s20),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _ProblemsPanel(problems: topProblems)),
              const SizedBox(width: AppTokens.s16),
              SizedBox(width: 330, child: _RightRail(data: data)),
            ],
          )
        else ...[
          _ProblemsPanel(problems: topProblems),
          const SizedBox(height: AppTokens.s16),
          _RightRail(data: data),
        ],
      ],
    );
  }
}

class _MunicipalityActivationDashboard extends StatelessWidget {
  const _MunicipalityActivationDashboard({required this.data});

  final _HomeSnapshot data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= AppTokens.wideBreakpoint;

    final actions = Wrap(
      spacing: AppTokens.s12,
      runSpacing: AppTokens.s8,
      children: [
        FilledButton.icon(
          onPressed: () => context.go('/suggest-problem'),
          icon: const Icon(AppIcons.play),
          label: const Text(VenialCopy.activationPrimaryCta),
        ),
        OutlinedButton.icon(
          onPressed: () => context.go('/next-problems'),
          icon: const Icon(AppIcons.board),
          label: const Text(VenialCopy.activationSecondaryCta),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FcPanel(
          tint: AppTokens.blue,
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FcStatusChip(
                label: data.municipalityName,
                color: AppTokens.blue,
                icon: AppIcons.home,
              ),
              const SizedBox(height: AppTokens.s12),
              Text(
                VenialCopy.activationTitle,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              Text(
                VenialCopy.activationSubtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: AppTokens.s12),
              Text(
                VenialCopy.activationGoal,
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppTokens.s16),
              actions,
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s16),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(child: _ActivationMissionsPanel()),
              SizedBox(width: AppTokens.s16),
              SizedBox(width: 330, child: _ActivationTrustPanel()),
            ],
          )
        else ...[
          const _ActivationMissionsPanel(),
          const SizedBox(height: AppTokens.s16),
          const _ActivationTrustPanel(),
        ],
      ],
    );
  }
}

class _ActivationMissionsPanel extends StatelessWidget {
  const _ActivationMissionsPanel();

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

    return FcPanel(
      padding: const EdgeInsets.all(AppTokens.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FcSectionHeader(
            title: VenialCopy.activationMissionsTitle,
            subtitle:
                'Scegli un tema reale, anche piccolo: serve solo per iniziare.',
          ),
          const SizedBox(height: AppTokens.s16),
          ..._missions.map(
            (mission) => Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusSmall,
                      ),
                    ),
                    child: Icon(mission.$1, color: scheme.primary, size: 20),
                  ),
                  const SizedBox(width: AppTokens.s12),
                  Expanded(
                    child: Text(
                      mission.$2,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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

class _ActivationTrustPanel extends StatelessWidget {
  const _ActivationTrustPanel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return FcPanel(
      tint: AppTokens.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cosa succede dopo',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            'La proposta entra nella lista dei temi. Altri cittadini possono votarla e, quando ci sono abbastanza segnali, diventa una carta del turno.',
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.42,
            ),
          ),
          const SizedBox(height: AppTokens.s12),
          Text(
            VenialCopy.activationOfficialHint,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemsPanel extends StatelessWidget {
  const _ProblemsPanel({required this.problems});

  final List<Problem> problems;

  @override
  Widget build(BuildContext context) {
    return FcPanel(
      padding: const EdgeInsets.all(AppTokens.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FcSectionHeader(
            title: 'Problemi prioritari',
            subtitle: 'Le situazioni su cui il turno sta raccogliendo segnali.',
            action: TextButton.icon(
              onPressed: () => context.go('/board'),
              icon: const Icon(AppIcons.board),
              label: const Text('Tabellone'),
            ),
          ),
          const SizedBox(height: AppTokens.s16),
          ...problems.map(
            (problem) => Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s12),
              child: _ProblemRow(problem: problem),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProblemRow extends StatelessWidget {
  const _ProblemRow({required this.problem});

  final Problem problem;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final status = _statusMeta(problem.status);
    final trend = problem.trendPercent;
    final improve = problem.status == ProblemStatus.improving ? 64.0 : 34.0;
    final stable = problem.status == ProblemStatus.stable ? 44.0 : 24.0;
    final worsen = problem.status == ProblemStatus.worsening ? 46.0 : 12.0;

    return Container(
      padding: const EdgeInsets.all(AppTokens.s14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: status.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
            ),
            child: Icon(
              AppIcons.forProblemKey(problem.key),
              color: status.color,
            ),
          ),
          const SizedBox(width: AppTokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(problem.title, style: textTheme.titleMedium),
                    ),
                    FcStatusChip(
                      label: status.label,
                      color: status.color,
                      icon: status.icon,
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.s4),
                Text(
                  problem.zoneName ?? AppIcons.labelForProblemKey(problem.key),
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.s12),
                FcPredictionBar(
                  improve: improve,
                  stable: stable,
                  worsen: worsen,
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  '${trend >= 0 ? '+' : ''}$trend% ultimi segnali',
                  style: textTheme.labelSmall?.copyWith(
                    color: status.color,
                    fontWeight: FontWeight.w800,
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

class _RightRail extends StatelessWidget {
  const _RightRail({required this.data});

  final _HomeSnapshot data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final accuracy = data.reputation.predictionsCount == 0
        ? '0%'
        : '${(data.reputation.accuracy * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppTokens.s20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTokens.navy, AppTokens.navyDark],
            ),
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'La tua reputazione',
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              Text(
                data.reputation.totalPoints.toString(),
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppTokens.s4),
              Text(
                '$accuracy accuratezza · ${data.reputation.predictionsCount} previsioni',
                style: textTheme.bodySmall?.copyWith(
                  color: AppTokens.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTokens.s16),
              LinearProgressIndicator(
                value: (data.reputation.totalPoints % 500) / 500,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Colors.white.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTokens.success,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s16),
        FcPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FcSectionHeader(
                title: 'Classifica',
                action: TextButton(
                  onPressed: () => context.go('/leaderboard'),
                  child: const Text('Vedi'),
                ),
              ),
              const SizedBox(height: AppTokens.s12),
              ...data.leaderboard
                  .take(4)
                  .map(
                    (entry) => _LeaderboardLine(
                      entry: entry,
                      isMe: entry.userId == data.currentUserId,
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s16),
        FcPanel(
          tint: AppTokens.blue,
          child: Text(
            _summaryLine(data.civicSummary),
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface,
              height: 1.42,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeaderboardLine extends StatelessWidget {
  const _LeaderboardLine({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.s8),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s8,
        vertical: AppTokens.s8,
      ),
      decoration: BoxDecoration(
        color: isMe ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              entry.rank.toString(),
              style: textTheme.labelLarge?.copyWith(
                color: isMe ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: isMe ? AppTokens.blue : scheme.surfaceVariant,
            foregroundColor: isMe ? Colors.white : scheme.onSurfaceVariant,
            child: Text(entry.displayName.characters.first),
          ),
          const SizedBox(width: AppTokens.s12),
          Expanded(
            child: Text(
              isMe ? 'Tu' : entry.displayName,
              style: textTheme.labelLarge?.copyWith(
                fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            entry.points.toString(),
            style: textTheme.labelLarge?.copyWith(
              color: isMe ? scheme.primary : scheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return const FcPanel(
      child: Padding(
        padding: EdgeInsets.all(AppTokens.s24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
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
      label: 'Migliora',
      color: AppTokens.success,
      icon: Icons.trending_up,
    ),
    ProblemStatus.stable => const _StatusMeta(
      label: 'Stabile',
      color: AppTokens.warning,
      icon: Icons.drag_handle,
    ),
    ProblemStatus.worsening => const _StatusMeta(
      label: 'Peggiora',
      color: AppTokens.danger,
      icon: Icons.trending_down,
    ),
  };
}

String _turnLabel(Turn turn) {
  final remaining = turn.endAt.difference(DateTime.now());
  if (remaining.inHours <= 0) return 'Turno in chiusura';
  if (remaining.inDays > 0) {
    return 'Turno di oggi · ${remaining.inDays}g rimasti';
  }
  return 'Turno di oggi · ${remaining.inHours}h rimaste';
}

class _HomeSnapshot {
  const _HomeSnapshot({
    required this.turn,
    required this.activationState,
    required this.municipalityName,
    required this.problems,
    required this.predictions,
    required this.reputation,
    required this.leaderboard,
    required this.currentUserId,
    required this.civicSummary,
  });

  final Turn turn;
  final MunicipalityActivationState activationState;
  final String municipalityName;
  final List<Problem> problems;
  final Map<String, Prediction> predictions;
  final ReputationScore reputation;
  final List<LeaderboardEntry> leaderboard;
  final String currentUserId;
  final CivicLoopSummary civicSummary;
}

Future<_HomeSnapshot> _loadHomeSnapshot(
  GameRepository repository,
  String municipalityId,
) async {
  final turn = await repository.getCurrentTurn(municipalityId);
  final activationState = await repository.getMunicipalityActivationState(
    municipalityId,
  );
  final problems = await repository.listProblems(municipalityId);
  final predictions = await repository.getMyPredictions(turn.id);
  final reputation = await repository.getReputationScore(turn.id);
  final civicSummary = await repository.getCivicLoopSummary(municipalityId);
  final leaderboard = await repository.getLeaderboard(
    municipalityId: municipalityId,
  );

  return _HomeSnapshot(
    turn: turn,
    activationState: activationState,
    municipalityName: MunicipalityCatalog.displayNameFromId(municipalityId),
    problems: problems,
    predictions: predictions,
    reputation: reputation,
    leaderboard: leaderboard,
    currentUserId: repository.currentUserId,
    civicSummary: civicSummary,
  );
}

String _summaryLine(CivicLoopSummary summary) {
  final topTheme = summary.topThemeTitle ?? 'nessuna carta promossa';
  return 'Riepilogo Comune: ${summary.proposedThemes} proposte, '
      '${summary.confirmedThemes} confermate, ${summary.cardsInTurn} carte del turno. '
      'Tema principale: $topTheme. Reputazione: ${summary.reputationPoints} pt.';
}
