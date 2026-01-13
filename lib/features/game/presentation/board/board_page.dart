import 'package:flutter/material.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/widgets/card_illustration_slot.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/paper_texture.dart';
import 'package:fanta_comune/core/widgets/pinned_note.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/prediction.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:provider/provider.dart';

class BoardPage extends StatelessWidget {
  const BoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<GameRepository>();
    final prefs = context.read<AppPrefs>();
    final municipalityId = prefs.municipalityId ?? 'demo';
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
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
                    future: _loadSnapshot(
                      repository: repository,
                      prefs: prefs,
                      municipalityId: municipalityId,
                    ),
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
                        return Center(
                          child: Text(
                            VenialCopy.boardEmpty,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 1000;
                          final gridCrossAxisCount = isWide ? 3 : 2;
                          final boardFrameHeight = () {
                            if (isWide) return null;
                            final frameWidth = constraints.maxWidth;
                            final gridWidth = frameWidth - (AppTokens.s16 * 2) - (AppTokens.s8 * 2);
                            final tileWidth = (gridWidth -
                                    (gridCrossAxisCount - 1) * AppTokens.s16) /
                                gridCrossAxisCount;
                            final tileHeight = tileWidth / 1.08;
                            final rows = (items.length / gridCrossAxisCount).ceil();
                            final gridHeight =
                                (rows * tileHeight) + ((rows - 1) * AppTokens.s16);
                            return gridHeight + (AppTokens.s16 * 2) + (AppTokens.s8 * 2);
                          }();

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
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridCrossAxisCount,
                                        crossAxisSpacing: AppTokens.s16,
                                        mainAxisSpacing: AppTokens.s16,
                                        childAspectRatio: 1.08,
                                      ),
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        return _BoardTile(
                                          problem: items[index],
                                          prediction: data?.predictionsByProblem[items[index].id],
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
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridCrossAxisCount,
                                        crossAxisSpacing: AppTokens.s16,
                                        mainAxisSpacing: AppTokens.s16,
                                        childAspectRatio: 1.08,
                                      ),
                                      itemCount: items.length,
                                      itemBuilder: (context, index) {
                                        return _BoardTile(
                                          problem: items[index],
                                          prediction: data?.predictionsByProblem[items[index].id],
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
                                  const _BoardSideCard(
                                    title: VenialCopy.boardCardOfDayTitle,
                                    body: VenialCopy.boardCardOfDayBody,
                                    icon: Icons.auto_awesome_outlined,
                                  ),
                                  const SizedBox(height: AppTokens.s16),
                                  const _BoardSideCard(
                                    title: VenialCopy.boardShowcaseTitle,
                                    body: VenialCopy.boardShowcaseBody,
                                    icon: Icons.style_outlined,
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
                                  children: const [
                                    _BoardSideCard(
                                      title: VenialCopy.boardCardOfDayTitle,
                                      body: VenialCopy.boardCardOfDayBody,
                                      icon: Icons.auto_awesome_outlined,
                                    ),
                                    SizedBox(height: AppTokens.s16),
                                    _BoardSideCard(
                                      title: VenialCopy.boardShowcaseTitle,
                                      body: VenialCopy.boardShowcaseBody,
                                      icon: Icons.style_outlined,
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

class _BoardTile extends StatefulWidget {
  const _BoardTile({
    required this.problem,
    required this.prediction,
  });

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
        child: PrimaryCard(
          padding: const EdgeInsets.all(AppTokens.s12),
          textured: true,
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
                  CardIllustrationSlot(
                    fallbackIcon: AppIcons.forProblemKey(widget.problem.key),
                    height: 56,
                    compact: true,
                    problemKey: widget.problem.key,
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
                        child: Icon(statusIcon, color: statusColor),
                      ),
                      const SizedBox(width: AppTokens.s8),
                      Expanded(
                        child: Text(
                          widget.problem.title,
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTokens.s8),
                  Row(
                    children: [
                      Icon(AppIcons.forProblemKey(widget.problem.key), size: 18),
                      const SizedBox(width: AppTokens.s8),
                      Expanded(
                        child: Text(
                          widget.problem.zoneName ?? AppIcons.labelForProblemKey(widget.problem.key),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s12,
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
                      const SizedBox(width: AppTokens.s8),
                      Text(
                        '${VenialCopy.boardZoneLabel}: ${widget.problem.zoneName ?? AppIcons.labelForProblemKey(widget.problem.key)}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
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
  final primary = insight.choiceDistribution.entries.reduce(
    (a, b) => a.value >= b.value ? a : b,
  ).key;
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
        ),
      );
    }
    if (snapshot?.hasChangedPerception ?? false) {
      items.add(
        _BoardNewsCard(
          icon: Icons.bolt_outlined,
          title: VenialCopy.boardNewsShifted,
          body: VenialCopy.boardNewsShiftedBody,
        ),
      );
    }
    items.add(
      _BoardNewsCard(
        icon: Icons.add_circle_outline,
        title: VenialCopy.boardNewsProposals,
        body: VenialCopy.boardNewsProposalsBody,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Text(
            VenialCopy.boardNewsTitle,
            style: TypographyX.titleMedium(context)?.copyWith(fontWeight: FontWeight.w700),
          ),
        const SizedBox(height: AppTokens.s8),
        if (items.isEmpty)
          Text(
            VenialCopy.boardNewsEmpty,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 240,
      padding: const EdgeInsets.all(AppTokens.s12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: AppTokens.s8),
          Text(
            title,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
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
  }
}

class _BoardTokensSection extends StatelessWidget {
  const _BoardTokensSection({required this.snapshot});

  final _BoardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final predictions = snapshot?.predictionsByProblem.values.toList() ?? const <Prediction>[];
    predictions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final tokens = predictions.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          VenialCopy.boardTokensTitle,
          style: TypographyX.titleMedium(context)?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppTokens.s8),
        if (tokens.isEmpty)
          Text(
            VenialCopy.boardTokensEmpty,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          )
        else
          Wrap(
            spacing: AppTokens.s12,
            runSpacing: AppTokens.s8,
            children: tokens.map((prediction) {
              final color = _tokenColor(colorScheme, prediction.choice);
              return _TokenChip(color: color, label: _choiceLabel(prediction.choice));
            }).toList(growable: false),
          ),
        const SizedBox(height: AppTokens.s8),
        Text(
          VenialCopy.boardTokensCaption,
          style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
    return PinnedNote(
      angle: VintagePaper.noteTiltMedium,
      child: Row(
        children: [
          CardIllustrationSlot(
            fallbackIcon: AppIcons.board,
            height: 46,
            compact: true,
          ),
          const SizedBox(width: AppTokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  VenialCopy.boardLegendLabel,
                  style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppTokens.s4),
                Text(
                  VenialCopy.boardLegendBody,
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.s8),
          _TokenChip(color: colorScheme.primary),
          const SizedBox(width: AppTokens.s4),
          _TokenChip(color: colorScheme.tertiary),
          const SizedBox(width: AppTokens.s4),
          _TokenChip(color: colorScheme.error),
        ],
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
      decoration: VintagePaper.surfaceDecoration(
        colorScheme,
        radius: AppTokens.radius,
        elevated: true,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: PaperTexture(
                color: VintagePaper.inkSoft(colorScheme).withOpacity(0.08),
                variant: PaperTextureVariant.hatch,
                intensity: 0.5,
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: VintagePaper.doubleBorder(
                colorScheme,
                radius: AppTokens.radius - 4,
                outer: VintagePaper.paperEdge(colorScheme).withOpacity(0.6),
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
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
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
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12, vertical: AppTokens.s8 / 2),
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
            Text(
              label!,
              style: textTheme.labelSmall,
            ),
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
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return PinnedNote(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardIllustrationSlot(
            fallbackIcon: icon,
            height: 64,
            compact: true,
          ),
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
