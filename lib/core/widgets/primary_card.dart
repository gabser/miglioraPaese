import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Card primaria riutilizzabile con padding e raggio coerenti al tema.
class PrimaryCard extends StatelessWidget {
  const PrimaryCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.s16),
    this.onTap,
    super.key,
  });

  /// Contenuto interno della card.
  final Widget child;

  /// Padding personalizzabile, di default AppTokens.s16.
  final EdgeInsetsGeometry padding;

  /// Callback opzionale per interazione tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final card = Card(
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      child: card,
    );
  }
}
