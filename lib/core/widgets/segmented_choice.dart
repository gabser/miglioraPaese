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
    this.optionBuilder,
    super.key,
  });

  /// Valore attualmente selezionato (può essere null per nessuna scelta).
  final T? value;

  /// Lista di opzioni selezionabili.
  final List<T> options;

  /// Builder del testo visibile per ogni opzione.
  final String Function(T) labelBuilder;

  /// Builder opzionale per personalizzare il contenuto visuale di ogni opzione.
  final Widget Function(T option, bool isSelected)? optionBuilder;

  /// Callback chiamata al cambio di selezione.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (Theme.of(context).useMaterial3) {
      return SegmentedButton<T>(
        emptySelectionAllowed: true,
        segments: options
            .map(
              (option) => ButtonSegment<T>(
                value: option,
                label: optionBuilder?.call(option, option == value) ??
                    Text(labelBuilder(option)),
              ),
            )
            .toList(),
        selected: value == null ? <T>{} : {value!},
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
          final isSelected = value != null && option == value;
          final label = labelBuilder(option);
          final labelKey = '$label$isSelected';

          return Semantics(
            button: true,
            label: 'Seleziona $label',
            child: ChoiceChip(
              label: AnimatedSwitcherX(
                duration: AppMotion.normal,
                child: optionBuilder != null
                    ? KeyedSubtree(
                        key: ValueKey(labelKey),
                        child: optionBuilder!(option, isSelected),
                      )
                    : Text(
                        label,
                        key: ValueKey(labelKey),
                      ),
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(option),
              backgroundColor: colorScheme.surface,
              selectedColor: colorScheme.primaryContainer,
              side: BorderSide(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
