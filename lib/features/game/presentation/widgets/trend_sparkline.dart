import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Micro-chart a barre verticali per mostrare rapidamente un trend percentuale.
class TrendSparkline extends StatelessWidget {
  /// Crea una sparkline leggera basata su valori percentuali [values].
  const TrendSparkline({
    required this.values,
    required this.color,
    this.maxHeight = 44,
    this.dimmed = false,
    super.key,
  });

  /// Valori percentuali (0-100) da mostrare in sequenza cronologica.
  final List<num> values;

  /// Colore principale usato per le barre animate.
  final Color color;

  /// Altezza massima della colonna più alta.
  final double maxHeight;

  /// Se true riduce l'opacità per indicare dati in formazione.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final entries = values
        .map((value) => value.toDouble())
        .toList(growable: false);
    final maxValue = entries.isEmpty
        ? 1.0
        : entries.reduce((a, b) => a > b ? a : b).clamp(1, 100);

    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: dimmed ? 0.45 : 1,
      curve: AppMotion.standard,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            _SparkBar(
              value: entries[i],
              maxValue: maxValue.toDouble(),
              color: color,
              maxHeight: maxHeight,
            ),
            if (i != entries.length - 1) const SizedBox(width: AppTokens.s8),
          ],
        ],
      ),
    );
  }
}

class _SparkBar extends StatelessWidget {
  const _SparkBar({
    required this.value,
    required this.maxValue,
    required this.color,
    required this.maxHeight,
  });

  final double value;
  final double maxValue;
  final Color color;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final normalized = (value / maxValue).clamp(0.12, 1);

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            height: max(6, maxHeight * normalized),
            decoration: BoxDecoration(
              color: color.withOpacity(0.8),
              borderRadius: BorderRadius.circular(AppTokens.radius),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          SizedBox(height: AppTokens.s8 / 2),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
          ),
        ],
      ),
    );
  }
}
