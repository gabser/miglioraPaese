import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Card primaria riutilizzabile con padding e raggio coerenti al tema.
class PrimaryCard extends StatelessWidget {
  const PrimaryCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppTokens.s16),
    this.onTap,
    this.textured = false,
    this.elevated = false,
    super.key,
  });

  /// Contenuto interno della card.
  final Widget child;

  /// Padding personalizzabile, di default AppTokens.s16.
  final EdgeInsetsGeometry padding;

  /// Callback opzionale per interazione tap.
  final VoidCallback? onTap;

  /// Attiva una texture carta leggera in background.
  final bool textured;

  /// Applica un'ombra piu' presente.
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ink = colorScheme.primary.withOpacity(0.08);
    final radius = BorderRadius.circular(AppTokens.radius);
    final content = Padding(padding: padding, child: child);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: radius,
        border: Border.all(color: colorScheme.outlineVariant),
        gradient: textured
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.surface,
                  colorScheme.primaryContainer.withOpacity(0.34),
                ],
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(elevated ? 0.11 : 0.06),
            blurRadius: elevated ? 24 : 14,
            offset: Offset(0, elevated ? 14 : 8),
          ),
        ],
      ),
      child: content,
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        hoverColor: ink,
        focusColor: ink,
        highlightColor: ink.withOpacity(0.12),
        child: card,
      ),
    );
  }
}
