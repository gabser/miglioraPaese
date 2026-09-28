import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Widget riusabile che abbina un'icona a un testo con semantica accessibile.
class IconLabel extends StatelessWidget {
  const IconLabel({
    required this.icon,
    required this.text,
    this.iconSize,
    super.key,
  });

  /// Icona da mostrare.
  final IconData icon;

  /// Testo associato all'icona.
  final String text;

  /// Dimensione opzionale dell'icona.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: text,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Text(text, style: textTheme.bodyMedium);
          return Row(
            mainAxisSize: constraints.hasBoundedWidth
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize),
              const SizedBox(width: AppTokens.s8),
              if (constraints.hasBoundedWidth)
                Expanded(child: label)
              else
                label,
            ],
          );
        },
      ),
    );
  }
}
