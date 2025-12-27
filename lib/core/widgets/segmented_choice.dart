import 'package:flutter/material.dart';
import 'package:fanta_comune/core/a11y/a11y.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';

/// Scelta segmentata generica per enum, con fallback accessibile.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    required this.value,
    required this.options,
    required this.labelBuilder,
    required this.onChanged,
    super.key,
  });

  /// Valore attualmente selezionato.
  final T value;

  /// Lista di opzioni selezionabili.
  final List<T> options;

  /// Builder del testo visibile per ogni opzione.
  final String Function(T) labelBuilder;

  /// Callback chiamata al cambio di selezione.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (Theme.of(context).useMaterial3) {
      return SegmentedButton<T>(
        segments: options
            .map(
              (option) => ButtonSegment<T>(
                value: option,
                label: Text(labelBuilder(option)),
              ),
            )
            .toList(),
        selected: {value},
        onSelectionChanged: (newSelection) {
          if (newSelection.isNotEmpty) {
            onChanged(newSelection.first);
          }
        },
      );
    }

    return focusGroup(
      child: Wrap(
        spacing: AppTokens.s8,
        runSpacing: AppTokens.s8,
        children: options.map((option) {
          final isSelected = option == value;
          final label = labelBuilder(option);

          return Semantics(
            button: true,
            label: 'Seleziona $label',
            child: ChoiceChip(
              label: AnimatedSwitcherX(
                duration: AppMotion.normal,
                child: Text(
                  label,
                  key: ValueKey(label + isSelected.toString()),
                ),
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(option),
              backgroundColor: colorScheme.surface,
              selectedColor: colorScheme.primaryContainer,
              side: BorderSide(
                color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
