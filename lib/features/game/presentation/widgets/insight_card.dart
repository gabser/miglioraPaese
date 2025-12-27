import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';

/// Card sobria che mostra un insight aggregato sulle percezioni collettive.
class InsightCard extends StatefulWidget {
  /// Crea una card di contesto per il [problemTitle] risolto, con i dati di [insight].
  const InsightCard({
    required this.insight,
    this.userChoice,
    required this.problemTitle,
    super.key,
  });

  /// Insight aggregato da visualizzare.
  final AggregatedInsight insight;

  /// Scelta effettuata dall'utente, usata solo per dare contesto testuale.
  final PredictionChoice? userChoice;

  /// Titolo del problema, utile per le etichette di accessibilità.
  final String problemTitle;

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  static const _minimumSignals = 10;
  bool _visible = false;

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

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
              ],
            ],
          ),
        ),
      ),
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
