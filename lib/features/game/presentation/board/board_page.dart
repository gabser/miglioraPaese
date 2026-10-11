import 'package:flutter/material.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/prediction.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class BoardPage extends StatefulWidget {
  const BoardPage({super.key});

  @override
  State<BoardPage> createState() => _BoardPageState();
}

enum _BoardSort { updated, title, trend }

class _BoardPageState extends State<BoardPage> {
  Future<_BoardSnapshot>? _snapshotFuture;
  String? _loadedMunicipalityId;
  ProblemKey? _category;
  ProblemStatus? _status;
  _BoardSort _sort = _BoardSort.updated;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    setState(() {
      _category = null;
      _status = null;
      _search.clear();
    });
  }

  List<Problem> _visibleProblems(List<Problem> problems) {
    final query = _search.text.trim().toLowerCase();
    final items = problems
        .where(
          (problem) =>
              (_category == null || problem.key == _category) &&
              (_status == null || problem.status == _status) &&
              (query.isEmpty ||
                  '${problem.title} ${problem.zoneName ?? ''}'
                      .toLowerCase()
                      .contains(query)),
        )
        .toList();
    items.sort(
      (a, b) => switch (_sort) {
        _BoardSort.updated => b.updatedAt.compareTo(a.updatedAt),
        _BoardSort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        _BoardSort.trend => b.trendPercent.abs().compareTo(
          a.trendPercent.abs(),
        ),
      },
    );
    return items;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefs = context.watch<AppPrefs>();
    final municipalityId = prefs.municipalityId ?? 'demo';
    if (_snapshotFuture != null && _loadedMunicipalityId == municipalityId) {
      return;
    }

    _category = null;
    _status = null;
    _search.clear();
    _loadedMunicipalityId = municipalityId;
    _snapshotFuture = _loadSnapshot(
      repository: context.read<GameRepository>(),
      prefs: prefs,
      municipalityId: municipalityId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/play'),
        ),
        title: const Text(VenialCopy.boardTitle),
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          child: FutureBuilder<_BoardSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return SingleChildScrollView(
                  child: FcPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Il tabellone non è disponibile. Riprova tra poco.',
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _snapshotFuture = _loadSnapshot(
                              repository: context.read<GameRepository>(),
                              prefs: context.read<AppPrefs>(),
                              municipalityId: _loadedMunicipalityId!,
                            );
                          }),
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final data = snapshot.data!;
              final visible = _visibleProblems(data.problems);
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FcSectionHeader(
                        title:
                            'Comune: ${MunicipalityCatalog.displayNameFromId(_loadedMunicipalityId!)}',
                        subtitle:
                            '${VenialCopy.boardSubtitle} · Gioco demo locale',
                      ),
                      const SizedBox(height: AppTokens.s16),
                      if (data.problems.isEmpty)
                        const _BoardActivationEmpty()
                      else ...[
                        _BoardNewsSection(snapshot: data),
                        const SizedBox(height: AppTokens.s16),
                        _BoardTokensSection(snapshot: data),
                        const SizedBox(height: AppTokens.s16),
                        TextField(
                          key: const ValueKey('board-search'),
                          controller: _search,
                          decoration: const InputDecoration(
                            labelText: 'Cerca problema o zona',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppTokens.s12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fieldWidth = constraints.maxWidth < 700
                                ? constraints.maxWidth
                                : (constraints.maxWidth - AppTokens.s24) / 3;
                            return Wrap(
                              spacing: AppTokens.s12,
                              runSpacing: AppTokens.s12,
                              children: [
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<ProblemKey>(
                                    key: ValueKey(
                                      'board-category-${_category?.name}',
                                    ),
                                    initialValue: _category,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Categoria',
                                    ),
                                    hint: const Text('Tutte le categorie'),
                                    items: [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('Tutte le categorie'),
                                      ),
                                      ...ProblemKey.values.map(
                                        (key) => DropdownMenuItem(
                                          value: key,
                                          child: Text(
                                            AppIcons.labelForProblemKey(key),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _category = value),
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<ProblemStatus>(
                                    key: ValueKey(
                                      'board-status-${_status?.name}',
                                    ),
                                    initialValue: _status,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Andamento',
                                    ),
                                    hint: const Text('Tutti gli andamenti'),
                                    items: [
                                      const DropdownMenuItem(
                                        value: null,
                                        child: Text('Tutti gli andamenti'),
                                      ),
                                      ...ProblemStatus.values.map(
                                        (status) => DropdownMenuItem(
                                          value: status,
                                          child: Text(_statusLabel(status)),
                                        ),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _status = value),
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<_BoardSort>(
                                    key: const ValueKey('board-sort'),
                                    initialValue: _sort,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Ordina per',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: _BoardSort.updated,
                                        child: Text('Ultimo aggiornamento'),
                                      ),
                                      DropdownMenuItem(
                                        value: _BoardSort.title,
                                        child: Text('Titolo A–Z'),
                                      ),
                                      DropdownMenuItem(
                                        value: _BoardSort.trend,
                                        child: Text('Variazione maggiore'),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _sort = value!),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppTokens.s16),
                        Text(
                          '${visible.length} di ${data.problems.length} problemi',
                        ),
                        const SizedBox(height: AppTokens.s12),
                        if (visible.isEmpty)
                          FcPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nessun problema corrisponde a ricerca e filtri.',
                                ),
                                TextButton(
                                  key: const ValueKey('board-clear-filters'),
                                  onPressed: _clearFilters,
                                  child: const Text('Azzera ricerca e filtri'),
                                ),
                              ],
                            ),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final largeText =
                                  MediaQuery.textScalerOf(context).scale(14) >
                                  20;
                              final columns =
                                  largeText || constraints.maxWidth < 650
                                  ? 1
                                  : constraints.maxWidth >= 1000
                                  ? 3
                                  : 2;
                              final width =
                                  (constraints.maxWidth -
                                      AppTokens.s16 * (columns - 1)) /
                                  columns;
                              return Wrap(
                                spacing: AppTokens.s16,
                                runSpacing: AppTokens.s16,
                                children: [
                                  for (final problem in visible)
                                    SizedBox(
                                      width: width,
                                      child: _BoardTile(
                                        problem: problem,
                                        prediction: data
                                            .predictionsByProblem[problem.id],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        const SizedBox(height: AppTokens.s16),
                        _BoardLegend(),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _statusLabel(ProblemStatus status) => switch (status) {
  ProblemStatus.improving => 'Migliora',
  ProblemStatus.stable => 'Stabile',
  ProblemStatus.worsening => 'Peggiora',
};

class _BoardActivationEmpty extends StatelessWidget {
  const _BoardActivationEmpty();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return FcPanel(
      padding: const EdgeInsets.all(AppTokens.s20),
      elevated: true,
      tint: AppTokens.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FcStatusChip(
            label: VenialCopy.activationTitle,
            color: AppTokens.blue,
            icon: AppIcons.board,
          ),
          const SizedBox(height: AppTokens.s12),
          Text(
            VenialCopy.boardActivationEmpty,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppTokens.s8),
          Text(
            VenialCopy.activationOfficialHint,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTokens.s16),
          const FcSectionHeader(
            title: 'Cosa puoi osservare',
            subtitle:
                'Indica la zona o il percorso che conosci; non serve una mappa.',
          ),
          const SizedBox(height: AppTokens.s12),
          const Text(
            'Buche e marciapiedi · illuminazione · rifiuti · verde pubblico · sicurezza dei percorsi',
          ),
          const SizedBox(height: AppTokens.s16),
          Wrap(
            spacing: AppTokens.s12,
            runSpacing: AppTokens.s8,
            children: [
              FilledButton(
                onPressed: () => context.go('/suggest-problem'),
                child: const Text(VenialCopy.activationPrimaryCta),
              ),
              OutlinedButton(
                onPressed: () => context.go('/next-problems'),
                child: const Text(VenialCopy.activationSecondaryCta),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BoardTile extends StatelessWidget {
  const _BoardTile({required this.problem, required this.prediction});
  final Problem problem;
  final Prediction? prediction;

  @override
  Widget build(BuildContext context) {
    final color = switch (problem.status) {
      ProblemStatus.improving => AppTokens.success,
      ProblemStatus.stable => AppTokens.warning,
      ProblemStatus.worsening => AppTokens.danger,
    };
    return FcPanel(
      key: ValueKey('board-problem-${problem.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FcStatusChip(
            label: _statusLabel(problem.status),
            color: color,
            icon: switch (problem.status) {
              ProblemStatus.improving => Icons.trending_up,
              ProblemStatus.stable => Icons.drag_handle,
              ProblemStatus.worsening => Icons.trending_down,
            },
          ),
          const SizedBox(height: AppTokens.s12),
          Text(problem.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.s8),
          Text('Zona: ${problem.zoneName ?? 'non specificata'}'),
          Text('Categoria: ${AppIcons.labelForProblemKey(problem.key)}'),
          const SizedBox(height: AppTokens.s8),
          Text(
            '${problem.trendPercent >= 0 ? '+' : ''}${problem.trendPercent}% andamento nella demo',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTokens.foregroundFor(color),
            ),
          ),
          if (prediction != null) ...[
            const SizedBox(height: AppTokens.s8),
            Text('La tua previsione: ${_choiceLabel(prediction!.choice)}'),
          ],
          const SizedBox(height: AppTokens.s12),
          TextButton(
            onPressed: () => context.go('/play'),
            child: const Text('Vai al turno'),
          ),
        ],
      ),
    );
  }
}

class _BoardSnapshot {
  const _BoardSnapshot({
    required this.problems,
    required this.predictionsByProblem,
    required this.hasPendingTurn,
    required this.hasChangedPerception,
  });

  final List<Problem> problems;
  final Map<String, Prediction> predictionsByProblem;
  final bool hasPendingTurn;
  final bool hasChangedPerception;
}

Future<_BoardSnapshot> _loadSnapshot({
  required GameRepository repository,
  required AppPrefs prefs,
  required String municipalityId,
}) async {
  final turn = await repository.getCurrentTurn(municipalityId);
  final problems = await repository.listProblems(municipalityId);
  final predictions = await repository.getMyPredictions(turn.id);
  final results = await repository.getPredictionResults(turn.id);

  final storedSignatures = prefs.getInsightSignatures();
  var hasChangedPerception = false;
  if (results.isNotEmpty) {
    final sampleIds = results.keys.take(3);
    for (final id in sampleIds) {
      final insight = await repository.getAggregatedInsight(id);
      final signature = _insightSignature(insight);
      if (storedSignatures[id] != null && storedSignatures[id] != signature) {
        hasChangedPerception = true;
        break;
      }
    }
  }

  final lastSeenTurnId = prefs.getLastSeenTurnId();
  final hasPendingTurn = results.isNotEmpty && lastSeenTurnId != turn.id;

  return _BoardSnapshot(
    problems: problems,
    predictionsByProblem: predictions,
    hasPendingTurn: hasPendingTurn,
    hasChangedPerception: hasChangedPerception,
  );
}

String _insightSignature(AggregatedInsight insight) {
  if (insight.totalPredictions == 0) return 'none';
  final primary = insight.choiceDistribution.entries
      .reduce((a, b) => a.value >= b.value ? a : b)
      .key;
  final percentage = insight.percentageForChoice(primary).clamp(0, 100).round();
  return '${primary.name}:$percentage:${insight.totalPredictions}';
}

class _BoardNewsSection extends StatelessWidget {
  const _BoardNewsSection({required this.snapshot});

  final _BoardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final items = <Widget>[];

    if (snapshot?.hasPendingTurn ?? false) {
      items.add(
        _BoardNewsCard(
          icon: Icons.style_outlined,
          title: VenialCopy.boardNewsPendingTurn,
          body: VenialCopy.boardNewsPendingTurnBody,
          onTap: () => context.go('/play'),
        ),
      );
    }
    if (snapshot?.hasChangedPerception ?? false) {
      items.add(
        _BoardNewsCard(
          icon: Icons.bolt_outlined,
          title: VenialCopy.boardNewsShifted,
          body: VenialCopy.boardNewsShiftedBody,
          onTap: () => context.go('/play'),
        ),
      );
    }
    items.add(
      _BoardNewsCard(
        icon: Icons.add_circle_outline,
        title: VenialCopy.boardNewsProposals,
        body: VenialCopy.boardNewsProposalsBody,
        onTap: () => context.go('/next-problems'),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          VenialCopy.boardNewsTitle,
          style: TypographyX.titleMedium(
            context,
          )?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTokens.s8),
        if (items.isEmpty)
          Text(
            VenialCopy.boardNewsEmpty,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppTokens.s12,
            runSpacing: AppTokens.s12,
            children: items,
          ),
      ],
    );
  }
}

class _BoardNewsCard extends StatelessWidget {
  const _BoardNewsCard({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 240,
      child: FcPanel(
        padding: const EdgeInsets.all(AppTokens.s12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(height: AppTokens.s8),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTokens.s4),
            Text(
              body,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardTokensSection extends StatelessWidget {
  const _BoardTokensSection({required this.snapshot});

  final _BoardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final predictions =
        snapshot?.predictionsByProblem.values.toList() ?? const <Prediction>[];
    predictions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final tokens = predictions.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          VenialCopy.boardTokensTitle,
          style: TypographyX.titleMedium(
            context,
          )?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTokens.s8),
        if (tokens.isEmpty)
          Text(
            VenialCopy.boardTokensEmpty,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: AppTokens.s12,
            runSpacing: AppTokens.s8,
            children: tokens
                .map((prediction) {
                  final color = _tokenColor(colorScheme, prediction.choice);
                  return _TokenChip(
                    color: color,
                    label: _choiceLabel(prediction.choice),
                  );
                })
                .toList(growable: false),
          ),
        const SizedBox(height: AppTokens.s8),
        Text(
          VenialCopy.boardTokensCaption,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BoardLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return FcPanel(
      padding: const EdgeInsets.all(AppTokens.s12),
      tint: AppTokens.blue,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tokens = Wrap(
            spacing: AppTokens.s4,
            runSpacing: AppTokens.s4,
            children: [
              _TokenChip(
                color: colorScheme.primary,
                label: VenialCopy.choiceImproveLabel,
              ),
              _TokenChip(
                color: colorScheme.tertiary,
                label: VenialCopy.choiceStableLabel,
              ),
              _TokenChip(
                color: colorScheme.error,
                label: VenialCopy.choiceWorsenLabel,
              ),
            ],
          );
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                VenialCopy.boardLegendLabel,
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTokens.s4),
              Text(
                VenialCopy.boardLegendBody,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 700) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BoardIconBadge(
                      icon: AppIcons.board,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: AppTokens.s12),
                    Expanded(child: copy),
                  ],
                ),
                const SizedBox(height: AppTokens.s8),
                tokens,
              ],
            );
          }

          return Row(
            children: [
              _BoardIconBadge(icon: AppIcons.board, color: colorScheme.primary),
              const SizedBox(width: AppTokens.s12),
              Expanded(child: copy),
              const SizedBox(width: AppTokens.s8),
              tokens,
            ],
          );
        },
      ),
    );
  }
}

class _TokenChip extends StatelessWidget {
  const _TokenChip({required this.color, this.label});

  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s12,
        vertical: AppTokens.s8 / 2,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          if (label != null) ...[
            const SizedBox(width: AppTokens.s8),
            Flexible(child: Text(label!, style: textTheme.labelSmall)),
          ],
        ],
      ),
    );
  }
}

class _BoardIconBadge extends StatelessWidget {
  const _BoardIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      ),
      child: Icon(icon, color: color),
    );
  }
}

Color _tokenColor(ColorScheme colorScheme, PredictionChoice choice) {
  return switch (choice) {
    PredictionChoice.improve => colorScheme.primary,
    PredictionChoice.stable => colorScheme.tertiary,
    PredictionChoice.worsen => colorScheme.error,
  };
}

String _choiceLabel(PredictionChoice choice) {
  return switch (choice) {
    PredictionChoice.improve => VenialCopy.choiceImproveLabel,
    PredictionChoice.stable => VenialCopy.choiceStableLabel,
    PredictionChoice.worsen => VenialCopy.choiceWorsenLabel,
  };
}
