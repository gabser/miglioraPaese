import 'package:flutter/material.dart';

/// Helper tipografico per piccoli aggiustamenti su schermi compatti.
class TypographyX {
  const TypographyX._();

  static TextStyle? headlineSmall(BuildContext context) {
    final base = Theme.of(context).textTheme.headlineSmall;
    return _compact(base, context, delta: -2);
  }

  static TextStyle? titleLarge(BuildContext context) {
    final base = Theme.of(context).textTheme.titleLarge;
    return _compact(base, context, delta: -1);
  }

  static TextStyle? titleMedium(BuildContext context) {
    final base = Theme.of(context).textTheme.titleMedium;
    return _compact(base, context, delta: -1);
  }

  static TextStyle? _compact(
    TextStyle? base,
    BuildContext context, {
    required double delta,
  }) {
    if (base == null) return null;
    final width = MediaQuery.of(context).size.width;
    if (width >= 420) return base;
    final size = base.fontSize;
    if (size == null) return base;
    return base.copyWith(fontSize: size + delta);
  }
}
