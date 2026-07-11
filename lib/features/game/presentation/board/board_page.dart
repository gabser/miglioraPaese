import 'package:flutter/material.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
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

class _BoardPageState extends State<BoardPage> {
  Future<_BoardSnapshot>? _snapshotFuture;
  String? _loadedMunicipalityId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prefs = context.read<AppPrefs>();
    final municipalityId = prefs.municipalityId ?? 'demo';
    if (_snapshotFuture != null && _loadedMunicipalityId == municipalityId) {
      return;
    }

    _loadedMunicipalityId = municipalityId;
    _snapshotFuture = _loadSnapshot(
      repository: context.read<GameRepository>(),
      prefs: prefs,
      municipalityId: municipalityId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              context.go('/play');
            }
          },
        ),
        title: const Text(VenialCopy.boardTitle),
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          child: Padding(
            padding: EdgeInsets.all(isCompact ? AppTokens.s12 : AppTokens.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  VenialCopy.boardSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
                Expanded(
                  child: FutureBuilder<_BoardSnapshot>(
                    future: _snapshotFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            snapshot.error.toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      }
                      final data = snapshot.data;
                      final items = data?.problems ?? const <Problem>[];
                      if (items.isEmpty) {
                        return const SingleChildScrollView(
                          child: _BoardActivationEmpty(),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 1000;
                          final gridCrossAxisCount = isWide
                              ? 3
                              : constraints.maxWidth < 430
                              ? 1
                              : 2;
                          final tileExtent = isWide ? 216.0 : 208.0;
                          final rows = (items.length / gridCrossAxisCount)
                              .ceil();
                          final boardFrameHeight =
                              (rows * tileExtent) +
                              ((rows - 1) * AppTokens.s16) +
                              (AppTokens.s16 * 2) +
                              (AppTokens.s8 * 2);

                          final mainContent = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _BoardNewsSection(snapshot: data),
                              const SizedBox(height: AppTokens.s16),
                              _BoardTokensSection(snapshot: data),
                              const SizedBox(height: AppTokens.s16),
                              if (isWide)
                                Expanded(
                                  child: _BoardFrame(
                                    child: GridView.builder(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: gridCrossAxisCount,
                                            crossAxisSpacing: AppTokens.s16,
                                            mainAxisSpacing: AppTokens.s16,
                                            mainAxisExtent: tileExtent,
                                          ),
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        return _BoardTile(
                                          problem: items[index],
                                          prediction:
                                              data?.predictionsByProblem[items[index]
                                                  .id],
                                        );
                                      },
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  height: boardFrameHeight,
                                  child: _BoardFrame(
                                    child: GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: gridCrossAxisCount,
                                            crossAxisSpacing: AppTokens.s16,
                                            mainAxisSpacing: AppTokens.s16,
                                            mainAxisExtent: tileExtent,
                                          ),
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        return _BoardTile(
                                          problem: items[index],
                                          prediction:
                                              data?.predictionsByProblem[items[index]
                                                  .id],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              const SizedBox(height: AppTokens.s12),
                              _BoardLegend(),
                            ],
                          );

                          if (!isWide) {
                            return SingleChildScrollView(
                              child: Column(
                                children: [
                                  mainContent,
                                  const SizedBox(height: AppTokens.s16),
                                  _BoardSideCard(
                                    title: VenialCopy.boardCardOfDayTitle,
                                    body: VenialCopy.boardCardOfDayBody,
                                    icon: Icons.auto_awesome_outlined,
                                    onTap: () => context.go('/play'),
                                  ),
                                  const SizedBox(height: AppTokens.s16),
                                  _BoardSideCard(
                                    title: VenialCopy.boardShowcaseTitle,
                                    body: VenialCopy.boardShowcaseBody,
                                    icon: Icons.style_outlined,
                                    onTap: () => context.go('/next-problems'),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: mainContent),
                              const SizedBox(width: AppTokens.s16),
                              SizedBox(
                                width: 280,
                                child: Column(
                                  children: [
                                    _BoardSideCard(
                                      title: VenialCopy.boardCardOfDayTitle,
                                      body: VenialCopy.boardCardOfDayBody,
                                      icon: Icons.auto_awesome_outlined,
                                      onTap: () => context.go('/play'),
                                    ),
                                    const SizedBox(height: AppTokens.s16),
                                    _BoardSideCard(
                                      title: VenialCopy.boardShowcaseTitle,
                                      body: VenialCopy.boardShowcaseBody,
                                      icon: Icons.style_outlined,
                                      onTap: () => context.go('/next-problems'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          Wrap(
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
          ),
        ],
      ),
    );
  }
}

class _BoardTile extends StatefulWidget {
  const _BoardTile({required this.problem, required this.prediction});

  final Problem problem;
  final Prediction? prediction;

  @override
  State<_BoardTile> createState() => _BoardTileState();
}

class _BoardTileState extends State<_BoardTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _setHovered(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
  }

  void _setPressed(bool value) {
    if (_isPressed == value) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = switch (widget.problem.status) {
      ProblemStatus.improving => colorScheme.primary,
      ProblemStatus.stable => colorScheme.tertiary,
      ProblemStatus.worsening => colorScheme.error,
    };
    final statusIcon = switch (widget.problem.status) {
      ProblemStatus.improving => Icons.trending_up,
      ProblemStatus.stable => Icons.drag_handle,
      ProblemStatus.worsening => Icons.trending_down,
    };

    final tokenColor = _tokenColor(colorScheme, widget.prediction?.choice);

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: FcPanel(
          padding: const EdgeInsets.all(AppTokens.s12),
          elevated: true,
          child: Stack(
            children: [
              Positioned(
                right: -8,
                top: -10,
                child: _TileGlint(isVisible: _isHovered || _isPressed),
              ),
              if (tokenColor != null)
                Positioned(
                  top: AppTokens.s8,
                  right: AppTokens.s8,
                  child: _TokenChip(color: tokenColor),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(
                        AppTokens.radiusSmall,
                      ),
                    ),
                    child: Icon(
                      AppIcons.forProblemKey(widget.problem.key),
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppTokens.s8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppTokens.radius),
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 20),
                      ),
                      const SizedBox(width: AppTokens.s8),
                      Expanded(
                        child: Text(
                          widget.problem.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.s8),
                  Row(
                    children: [
                      Icon(
                        AppIcons.forProblemKey(widget.problem.key),
                        size: 18,
                      ),
                      const SizedBox(width: AppTokens.s8),
                      Expanded(
                        child: Text(
                          widget.problem.zoneName ??
                              AppIcons.labelForProblemKey(widget.problem.key),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Wrap(
                    spacing: AppTokens.s8,
                    runSpacing: AppTokens.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s8,
                          vertical: AppTokens.s8 / 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppTokens.radius),
                        ),
                        child: Text(
                          VenialCopy.boardTileLabel,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: Text(
                          '${VenialCopy.boardZoneLabel}: ${widget.problem.zoneName ?? AppIcons.labelForProblemKey(widget.problem.key)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _tokenColor(ColorScheme colorScheme, PredictionChoice? choice) {
    if (choice == null) return null;
    return switch (choice) {
      PredictionChoice.improve => colorScheme.primary,
      PredictionChoice.stable => colorScheme.tertiary,
      PredictionChoice.worsen => colorScheme.error,
    };
  }
}

class _TileGlint extends StatelessWidget {
  const _TileGlint({required this.isVisible});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: isVisible ? 1 : 0,
      child: Transform.rotate(
        angle: -0.2,
        child: Container(
          width: 32,
          height: 10,
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
          ),
        ),
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
              _TokenChip(color: colorScheme.primary),
              _TokenChip(color: colorScheme.tertiary),
              _TokenChip(color: colorScheme.error),
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

          if (constraints.maxWidth < 360) {
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

class _BoardFrame extends StatelessWidget {
  const _BoardFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLarge),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withOpacity(0.22),
                borderRadius: BorderRadius.circular(AppTokens.radius),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTokens.radius - 4),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
            ),
          ),
          Positioned(
            left: -10,
            top: -10,
            child: _CornerChip(color: colorScheme.primary.withOpacity(0.15)),
          ),
          Positioned(
            right: -12,
            bottom: -12,
            child: _CornerChip(color: colorScheme.tertiary.withOpacity(0.12)),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(AppTokens.s8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerChip extends StatelessWidget {
  const _CornerChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
            Text(label!, style: textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}

class _BoardSideCard extends StatelessWidget {
  const _BoardSideCard({
    required this.title,
    required this.body,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final note = FcPanel(
      padding: const EdgeInsets.all(AppTokens.s12),
      tint: AppTokens.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BoardIconBadge(icon: icon, color: colorScheme.primary),
          const SizedBox(height: AppTokens.s12),
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
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
    );

    if (onTap == null) return note;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: note,
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
