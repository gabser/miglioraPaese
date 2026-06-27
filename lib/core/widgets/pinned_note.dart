import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Callout informativo compatibile con la vecchia API delle note appuntate.
class PinnedNote extends StatelessWidget {
  const PinnedNote({
    super.key,
    required this.child,
    this.tape = true,
    this.angle,
  });

  final Widget child;
  final bool tape;
  final double? angle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.48),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: scheme.primary.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s12),
        child: child,
      ),
    );
  }
}
