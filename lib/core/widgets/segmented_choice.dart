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
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return focusGroup(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useColumns = constraints.maxWidth >= 360 && options.length <= 3;
          final itemWidth = useColumns
              ? (constraints.maxWidth - AppTokens.s8 * (options.length - 1)) /
                    options.length
              : null;

          return Wrap(
            spacing: AppTokens.s8,
            runSpacing: AppTokens.s8,
            children: options.map((option) {
              final isSelected = value != null && option == value;
              final isEnabled = onChanged != null;
              final label = labelBuilder(option);
              final labelKey = '$label$isSelected';
              final content = AnimatedSwitcherX(
                duration: AppMotion.normal,
                child: optionBuilder != null
                    ? KeyedSubtree(
                        key: ValueKey(labelKey),
                        child: optionBuilder!(option, isSelected),
                      )
                    : Text(
                        label,
                        key: ValueKey(labelKey),
                        overflow: TextOverflow.visible,
                      ),
              );

              return SizedBox(
                width: itemWidth,
                child: Semantics(
                  button: true,
                  selected: isSelected,
                  enabled: isEnabled,
                  label: 'Seleziona $label',
                  child: Material(
                    color: isSelected
                        ? colorScheme.primaryContainer
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                    child: InkWell(
                      onTap: isEnabled ? () => onChanged!(option) : null,
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                      child: AnimatedContainer(
                        duration: AppMotion.fast,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s12,
                          vertical: AppTokens.s8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTokens.radius),
                          border: Border.all(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outlineVariant,
                          ),
                        ),
                        child: Opacity(
                          opacity: isEnabled || isSelected ? 1 : 0.55,
                          child: Align(
                            alignment: Alignment.center,
                            child: content,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
