import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
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

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  static const _minimumSignals = 10;
  bool _visible = false;
  bool _showHistory = false;

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

  PredictionChoice _primaryChoice() {
    if (widget.insight.choiceDistribution.isEmpty) {
      return PredictionChoice.stable;
    }

    return widget.insight.choiceDistribution.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    ).key;
  }

  List<MotivationKey> _topMotivations() {
    if (widget.insight.motivationDistribution.isEmpty) return const [];

    final ordered = widget.insight.motivationDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ordered.take(2).map((entry) => entry.key).toList(growable: false);
  }

  String _headline() {
    if (!_hasSignals) {
      return 'Le percezioni stanno emergendo';
    }

    final choice = _primaryChoice();
    final percentage = widget.insight.percentageForChoice(choice).clamp(0, 100).round();
    final verb = switch (choice) {
      PredictionChoice.improve => 'la situazione migliorerà',
      PredictionChoice.stable => 'la situazione resterà simile nelle prossime settimane',
      PredictionChoice.worsen => 'la situazione potrebbe peggiorare se nulla cambia',
    };
    return 'Il $percentage% delle persone pensa che $verb';
  }

  String _motivationLine() {
    if (!_hasSignals) {
      return 'Stiamo raccogliendo altri segnali condivisi da Fanta Comune.';
    }

    final motivations = _topMotivations();
    if (motivations.isEmpty) {
      return 'Per ora le percezioni si distribuiscono in modo vario.';
    }

    final labels = motivations.map((m) => m.label.toLowerCase()).join(', ');
    return 'Motivazioni più comuni: $labels';
  }

  PredictionChoice _historyLeadingChoice() {
    final history = widget.history;
    if (history == null || history.snapshots.isEmpty) return _primaryChoice();

    return history.snapshots.last.choiceDistribution.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    ).key;
  }

  List<double> _historyValuesFor(PredictionChoice choice) {
    final history = widget.history;
    if (history == null) return const [];

    return history.snapshots
        .map((snapshot) => snapshot.pct(choice).clamp(0, 100))
        .toList(growable: false);
  }

  String _trendCopy(PredictionChoice choice, List<double> values) {
    if (values.length < 2) return 'Trend in formazione: stiamo accumulando segnali.';
    final delta = values.last - values.first;
    if (delta.abs() < 2.5) {
      return switch (choice) {
        PredictionChoice.improve => 'Percezione di miglioramento stabile.',
        PredictionChoice.stable => 'Sensazione di stabilità confermata nel tempo.',
        PredictionChoice.worsen => 'Timore di peggioramento stabile.',
      };
    }
    if (delta > 0) {
      return switch (choice) {
        PredictionChoice.improve => 'Tendenza: più persone vedono un miglioramento.',
        PredictionChoice.stable => 'Tendenza: cresce la percezione di stabilità.',
        PredictionChoice.worsen => 'Tendenza: più persone temono un peggioramento.',
      };
    }
    return switch (choice) {
      PredictionChoice.improve => 'Tendenza: fiducia in calo rispetto al miglioramento.',
      PredictionChoice.stable => 'Tendenza: meno persone pensano resti stabile.',
      PredictionChoice.worsen => 'Tendenza: timore di peggioramento in calo.',
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
    final historyChoice = _historyLeadingChoice();
    final historyValues = _historyValuesFor(historyChoice);
    final trendCopy = _trendCopy(historyChoice, historyValues);
    final historyColor = _colorForChoice(colorScheme, historyChoice);

    if (!_visible) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: 'Percezione collettiva per ${widget.problemTitle}: ${_headline()}',
      child: AnimatedSwitcherX(
        duration: AppMotion.normal,
        switchInCurve: const Interval(0.18, 1, curve: AppMotion.standard),
        child: Container(
          key: ValueKey('insight-surface-${widget.insight.totalPredictions}-${widget.userChoice?.name ?? 'none'}'),
          padding: const EdgeInsets.all(AppTokens.s12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTokens.radius),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (_hasSignals) ...[
                const SizedBox(height: AppTokens.s12),
                _ChoiceDistribution(
                  insight: widget.insight,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _toggleHistory,
                    icon: Icon(_showHistory ? Icons.expand_less : Icons.show_chart),
                    label: Text(_showHistory ? 'Nascondi andamento' : 'Vedi andamento'),
                  ),
                ),
                AnimatedSize(
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
              ],
            ],
          ),
        ),
      ),
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
    final heading = 'Andamento (ultimi ${snapshotCount == 0 ? 6 : snapshotCount} turni)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              heading,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
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
                  'Trend in formazione',
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
                'Carichiamo i segnali recenti...',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          )
        else if (history == null)
          Text(
            'Apri per vedere come stanno cambiando le percezioni.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          )
        else ...[
          TrendSparkline(
            values: values,
            color: color,
            dimmed: dimmed,
          ),
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
              'Servono ancora alcuni segnali per consolidare il trend.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
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
      children: PredictionChoice.values.map((choice) {
        final percentage = insight.percentageForChoice(choice).clamp(0, 100);
        final (label, color) = switch (choice) {
          PredictionChoice.improve => ('Situazione in miglioramento', colorScheme.primary),
          PredictionChoice.stable => ('Situazione stabile', colorScheme.tertiary),
          PredictionChoice.worsen => ('Possibile peggioramento', colorScheme.error),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: AppTokens.s8),
          child: _ChoiceBar(
            label: label,
            percentage: percentage,
            color: color,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        );
      }).toList(growable: false),
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
            final barWidth = constraints.maxWidth * (percentage / 100).clamp(0, 1);
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
