import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/widgets/paper_texture.dart';

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
    final ink = VintagePaper.inkSoft(colorScheme).withOpacity(0.08);
    final content = Stack(
      children: [
        if (textured)
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: PaperTexture(
                  color: VintagePaper.inkSoft(colorScheme).withOpacity(0.08),
                  variant: PaperTextureVariant.fiber,
                  intensity: 0.35,
                ),
              ),
            ),
          ),
        Padding(
          padding: padding,
          child: child,
        ),
      ],
    );

    final card = Container(
      decoration: VintagePaper.surfaceDecoration(
        colorScheme,
        radius: AppTokens.radius,
        elevated: elevated,
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
        borderRadius: BorderRadius.circular(AppTokens.radius),
        hoverColor: ink,
        focusColor: ink,
        highlightColor: ink.withOpacity(0.12),
        child: card,
      ),
    );
  }
}
