import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/widgets/animated_size_x.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/critical_insight.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/presentation/widgets/trend_sparkline.dart';

/// Card sobria che mostra un insight aggregato sulle percezioni collettive.
class InsightCard extends StatefulWidget {
  /// Crea una card di contesto per il [problemTitle] risolto, con i dati di [insight].
  const InsightCard({
    required this.insight,
    this.userChoice,
    required this.problemTitle,
    this.history,
    this.isHistoryLoading = false,
    this.onLoadHistory,
    this.criticalInsights = const [],
    this.isCriticalInsightsLoading = false,
    this.onLoadCriticalInsights,
    super.key,
  });

  /// Insight aggregato da visualizzare.
  final AggregatedInsight insight;

  /// Scelta effettuata dall'utente, usata solo per dare contesto testuale.
  final PredictionChoice? userChoice;

  /// Titolo del problema, utile per le etichette di accessibilità.
  final String problemTitle;

  /// Storico sintetico delle percezioni, popolato su richiesta.
  final InsightHistory? history;

  /// Indica se il recupero dello storico è in corso.
  final bool isHistoryLoading;

  /// Callback per richiedere il recupero dello storico al primo tap.
  final VoidCallback? onLoadHistory;

  /// Insight critici aggregati caricati su richiesta.
  final List<CriticalInsight> criticalInsights;

  /// Indica se il caricamento degli insight critici e' in corso.
  final bool isCriticalInsightsLoading;

  /// Callback per richiedere insight critici al primo tap.
  final VoidCallback? onLoadCriticalInsights;

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  static const _minimumSignals = 10;
  bool _visible = false;
  bool _showHistory = false;
  bool _showCritical = false;

  bool get _hasSignals => widget.insight.totalPredictions >= _minimumSignals;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() {
        _visible = true;
      });
    });
  }

  void _toggleHistory() {
    setState(() {
      _showHistory = !_showHistory;
    });
    if (_showHistory && widget.history == null && !widget.isHistoryLoading) {
      widget.onLoadHistory?.call();
    }
  }

  void _toggleCriticalInsights() {
    setState(() {
      _showCritical = !_showCritical;
    });
    if (_showCritical &&
        widget.criticalInsights.isEmpty &&
        !widget.isCriticalInsightsLoading) {
      widget.onLoadCriticalInsights?.call();
    }
  }

  PredictionChoice _primaryChoice() {
    if (widget.insight.choiceDistribution.isEmpty) {
      return PredictionChoice.stable;
    }

    return widget.insight.choiceDistribution.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  List<MotivationKey> _topMotivations() {
    if (widget.insight.motivationDistribution.isEmpty) return const [];

    final ordered = widget.insight.motivationDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ordered.take(2).map((entry) => entry.key).toList(growable: false);
  }

  String _headline() {
    if (!_hasSignals) {
      return VenialCopy.insightLowSignalHeadline;
    }

    final choice = _primaryChoice();
    final percentage = widget.insight
        .percentageForChoice(choice)
        .clamp(0, 100)
        .round();
    final verb = switch (choice) {
      PredictionChoice.improve => 'la situazione migliorera\'',
      PredictionChoice.stable => 'la situazione restera\' piu\' o meno uguale',
      PredictionChoice.worsen => 'la situazione potrebbe peggiorare',
    };
    return VenialCopy.insightHeadlineTemplate
        .replaceAll('{percentage}', '$percentage')
        .replaceAll('{verb}', verb);
  }

  String _motivationLine() {
    if (!_hasSignals) {
      return VenialCopy.insightLowSignalDetail;
    }

    final motivations = _topMotivations();
    if (motivations.isEmpty) {
      return VenialCopy.insightNoMotivation;
    }

    final labels = motivations.map((m) => m.label.toLowerCase()).join(', ');
    return VenialCopy.insightMotivationPrefix.replaceAll('{labels}', labels);
  }

  PredictionChoice _historyLeadingChoice() {
    final history = widget.history;
    if (history == null || history.snapshots.isEmpty) return _primaryChoice();

    return history.snapshots.last.choiceDistribution.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  List<double>? _historyValuesFor(PredictionChoice choice) {
    final history = widget.history;
    if (history == null) return const [];

    return history.snapshots
        .map((snapshot) {
          final v = snapshot.pct(choice).toDouble();
          return v.clamp(0.0, 100.0).toDouble();
        })
        .toList(growable: false);
  }

  String _trendCopy(PredictionChoice choice, List<double> values) {
    if (values.length < 2) return VenialCopy.trendLowDataQuick;
    final delta = values.last - values.first;
    if (delta.abs() < 2.5) {
      return switch (choice) {
        PredictionChoice.improve => VenialCopy.trendFlatImprove,
        PredictionChoice.stable => VenialCopy.trendFlatStable,
        PredictionChoice.worsen => VenialCopy.trendFlatWorsen,
      };
    }
    if (delta > 0) {
      return switch (choice) {
        PredictionChoice.improve => VenialCopy.trendUpImprove,
        PredictionChoice.stable => VenialCopy.trendUpStable,
        PredictionChoice.worsen => VenialCopy.trendUpWorsen,
      };
    }
    return switch (choice) {
      PredictionChoice.improve => VenialCopy.trendDownImprove,
      PredictionChoice.stable => VenialCopy.trendDownStable,
      PredictionChoice.worsen => VenialCopy.trendDownWorsen,
    };
  }

  bool get _historyDimmed {
    final history = widget.history;
    if (history == null || history.snapshots.isEmpty) return true;
    return history.snapshots.last.totalPredictions < _minimumSignals;
  }

  Color _colorForChoice(ColorScheme colorScheme, PredictionChoice choice) {
    return switch (choice) {
      PredictionChoice.improve => colorScheme.primary,
      PredictionChoice.stable => colorScheme.tertiary,
      PredictionChoice.worsen => colorScheme.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final sectionGap = isCompact ? AppTokens.s8 : AppTokens.s12;
    final historyChoice = _historyLeadingChoice();
    final historyValues = _historyValuesFor(historyChoice);
    final trendCopy = _trendCopy(historyChoice, historyValues!);
    final historyColor = _colorForChoice(colorScheme, historyChoice);

    if (!_visible) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Percezione collettiva per ${widget.problemTitle}: ${_headline()}',
      child: AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: const Interval(0.18, 1, curve: AppMotion.standard),
        switchOutCurve: AppMotion.standard,
        transitionBuilder: (child, animation) {
          final slide = animation.drive(
            Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero),
          );
          final scale = Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          );
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
        child: FcPanel(
          key: ValueKey(
            'insight-surface-${widget.insight.totalPredictions}-${widget.userChoice?.name ?? 'none'}',
          ),
          padding: const EdgeInsets.all(AppTokens.s16),
          tint: AppTokens.blue,
          elevated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTokens.s8),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                    ),
                    child: Icon(
                      Icons.style_outlined,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppTokens.s8),
                  Expanded(
                    child: Text(
                      VenialCopy.insightCardTitle,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: sectionGap),
              Text(
                _headline(),
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              Text(
                _motivationLine(),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.s8),
              Text(
                VenialCopy.insightDisclaimer,
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_hasSignals) ...[
                SizedBox(height: sectionGap),
                _ChoiceDistribution(
                  insight: widget.insight,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _HistoryTab(
                    isOpen: _showHistory,
                    onTap: _toggleHistory,
                  ),
                ),
                AnimatedSizeX(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  child: _showHistory
                      ? Padding(
                          padding: const EdgeInsets.only(top: AppTokens.s8),
                          child: _HistoryTrend(
                            history: widget.history,
                            values: historyValues,
                            color: historyColor,
                            trendCopy: trendCopy,
                            isLoading: widget.isHistoryLoading,
                            dimmed: _historyDimmed,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: AppTokens.s8),
              ],
              _CriticalInsightsSection(
                isOpen: _showCritical,
                onToggle: _toggleCriticalInsights,
                insights: widget.criticalInsights,
                isLoading: widget.isCriticalInsightsLoading,
              ),
              SizedBox(height: sectionGap),
              Align(
                alignment: Alignment.centerRight,
                child: FcStatusChip(
                  label: VenialCopy.stampPerceptionsLabel,
                  color: AppTokens.blue,
                  icon: Icons.visibility_outlined,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CriticalInsightsSection extends StatelessWidget {
  const _CriticalInsightsSection({
    required this.isOpen,
    required this.onToggle,
    required this.insights,
    required this.isLoading,
  });

  final bool isOpen;
  final VoidCallback onToggle;
  final List<CriticalInsight> insights;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTokens.s8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    VenialCopy.criticalInsightsTitle,
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  isOpen ? Icons.expand_less : Icons.expand_more,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        AnimatedSizeX(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          child: isOpen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      VenialCopy.criticalInsightsDisclaimer,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    AnimatedSwitcherX(
                      duration: AppMotion.normal,
                      child: isLoading
                          ? Row(
                              key: const ValueKey('critical-insights-loading'),
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: AppTokens.s8),
                                Text(
                                  VenialCopy.criticalInsightsLoading,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          : _CriticalInsightsList(
                              key: const ValueKey('critical-insights-list'),
                              insights: insights,
                            ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.isOpen, required this.onTap});

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = isOpen
        ? VenialCopy.insightHistoryHide
        : VenialCopy.insightHistoryShow;
    final icon = isOpen ? Icons.expand_less : Icons.show_chart;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s12,
          vertical: AppTokens.s8 / 2,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: AppTokens.s8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CriticalInsightsList extends StatelessWidget {
  const _CriticalInsightsList({required this.insights, super.key});

  final List<CriticalInsight> insights;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (insights.isEmpty) {
      return Text(
        VenialCopy.criticalInsightsLowSignal,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: insights
          .map((insight) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.headline,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s4),
                  Text(
                    insight.supporting,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (insight.note != null && insight.note!.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.s4),
                    Text(
                      insight.note!,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _HistoryTrend extends StatelessWidget {
  const _HistoryTrend({
    required this.history,
    required this.values,
    required this.color,
    required this.trendCopy,
    required this.isLoading,
    required this.dimmed,
  });

  final InsightHistory? history;
  final List<double> values;
  final Color color;
  final String trendCopy;
  final bool isLoading;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final snapshotCount = history?.snapshots.length ?? 6;
    final turns = snapshotCount == 0 ? 6 : snapshotCount;
    final heading = VenialCopy.trendHeadingTemplate.replaceAll(
      '{turns}',
      '$turns',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              heading,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (dimmed)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.s12,
                  vertical: AppTokens.s8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTokens.radius),
                ),
                child: Text(
                  VenialCopy.trendLowDataLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.s8),
        if (isLoading)
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppTokens.s8),
              Text(
                VenialCopy.insightHistoryLoading,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else if (history == null)
          Text(
            VenialCopy.insightHistoryPrompt,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else ...[
          TrendSparkline(values: values, color: color, dimmed: dimmed),
          const SizedBox(height: AppTokens.s8),
          Text(
            trendCopy,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (dimmed) ...[
            const SizedBox(height: AppTokens.s8 / 2),
            Text(
              VenialCopy.trendLowDataHelper,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ChoiceDistribution extends StatelessWidget {
  const _ChoiceDistribution({
    required this.insight,
    required this.colorScheme,
    required this.textTheme,
  });

  final AggregatedInsight insight;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: PredictionChoice.values
          .map((choice) {
            final percentage = insight
                .percentageForChoice(choice)
                .clamp(0, 100);
            final (label, color) = switch (choice) {
              PredictionChoice.improve => (
                'Situazione in miglioramento',
                colorScheme.primary,
              ),
              PredictionChoice.stable => (
                'Situazione stabile',
                colorScheme.tertiary,
              ),
              PredictionChoice.worsen => (
                'Possibile peggioramento',
                colorScheme.error,
              ),
            };

            return Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s8),
              child: _ChoiceBar(
                label: label,
                percentage: percentage.toDouble(),
                color: color,
                textTheme: textTheme,
                colorScheme: colorScheme,
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ChoiceBar extends StatelessWidget {
  const _ChoiceBar({
    required this.label,
    required this.percentage,
    required this.color,
    required this.textTheme,
    required this.colorScheme,
  });

  final String label;
  final double percentage;
  final Color color;
  final TextTheme textTheme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.s8 / 2),
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth =
                constraints.maxWidth * (percentage / 100).clamp(0, 1);
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                  ),
                ),
                AnimatedContainer(
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  width: barWidth,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(AppTokens.radius),
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
