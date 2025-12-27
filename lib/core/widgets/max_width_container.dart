import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Contenitore che limita la larghezza e centra il contenuto su schermi ampi.
class MaxWidthContainer extends StatelessWidget {
  const MaxWidthContainer({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppTokens.pagePadding,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppTokens.maxContentWidth,
          ),
          child: child,
        ),
      ),
    );
  }
}
