import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Contenitore che limita la larghezza e centra il contenuto su schermi ampi.
class MaxWidthContainer extends StatelessWidget {
  const MaxWidthContainer({
    required this.child,
    this.maxWidth = AppTokens.maxContentWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppTokens.pagePadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
