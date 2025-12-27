import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';

/// Set di chip selezionabili che permette di scegliere fino a due motivazioni.
class MotivationChips extends StatefulWidget {
  /// Crea un gruppo di chip coerente con il design di Fanta Comune.
  const MotivationChips({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// Motivazioni attualmente selezionate.
  final List<MotivationKey> selected;

  /// Callback invocata quando la selezione cambia.
  final ValueChanged<List<MotivationKey>> onChanged;

  @override
  State<MotivationChips> createState() => _MotivationChipsState();
}

class _MotivationChipsState extends State<MotivationChips> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.fast,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerLimitFeedback() {
    _controller
      ..reset()
      ..forward();
  }

  void _onToggle(MotivationKey key) {
    final current = List<MotivationKey>.from(widget.selected);
    if (current.contains(key)) {
      current.remove(key);
      widget.onChanged(current);
      return;
    }

    if (current.length >= 2) {
      _triggerLimitFeedback();
      return;
    }

    widget.onChanged([...current, key]);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = math.sin(_controller.value * math.pi) * 4;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: Wrap(
        spacing: AppTokens.s8,
        runSpacing: AppTokens.s8,
        children: MotivationKey.values.map((motivation) {
          final isSelected = widget.selected.contains(motivation);
          final background = isSelected ? colorScheme.surfaceContainerHighest : colorScheme.surfaceContainerLow;
          final borderColor = isSelected ? colorScheme.primary.withOpacity(0.4) : colorScheme.outlineVariant;

          return Semantics(
            label: 'Motivazione: ${motivation.label}',
            button: true,
            selected: isSelected,
            child: FocusableActionDetector(
              mouseCursor: SystemMouseCursors.click,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radius),
                onTap: () => _onToggle(motivation),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s12,
                    vertical: AppTokens.s8,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        motivation.icon,
                        size: 18,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppTokens.s8),
                      Text(
                        motivation.label,
                        style: textTheme.bodyMedium?.copyWith(
                          color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                          fontWeight: isSelected ? FontWeight.w600 : textTheme.bodyMedium?.fontWeight,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: AppTokens.s8),
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
