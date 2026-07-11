import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Helper per superfici "paper + ink" in stile vintage.
class VintagePaper {
  const VintagePaper._();

  static Color paperBase(ColorScheme scheme) => scheme.surfaceContainerLowest;
  static Color paperWarm(ColorScheme scheme) =>
      scheme.secondaryContainer.withOpacity(0.7);
  static Color paperHigh(ColorScheme scheme) => scheme.surface;
  static Color paperEdge(ColorScheme scheme) => scheme.outlineVariant;

  static Color inkMain(ColorScheme scheme) => scheme.onSurface;
  static Color inkSoft(ColorScheme scheme) => scheme.onSurfaceVariant;
  static Color inkStamp(ColorScheme scheme) => scheme.primary.withOpacity(0.7);
  static Color accentWax(ColorScheme scheme) =>
      scheme.tertiary.withOpacity(0.6);

  static List<BoxShadow> paperShadowSoft(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.shadow.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> paperShadowLifted(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.shadow.withOpacity(0.14),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> pinShadow(ColorScheme scheme) => [
    BoxShadow(
      color: scheme.shadow.withOpacity(0.2),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static BoxDecoration surfaceDecoration(
    ColorScheme scheme, {
    double radius = AppTokens.radius,
    bool elevated = false,
  }) {
    return BoxDecoration(
      color: paperBase(scheme),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: paperEdge(scheme), width: 2),
      boxShadow: elevated ? paperShadowLifted(scheme) : paperShadowSoft(scheme),
    );
  }

  static BoxDecoration doubleBorder(
    ColorScheme scheme, {
    double radius = AppTokens.radius,
    Color? outer,
    Color? inner,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: outer ?? paperEdge(scheme), width: 2),
    );
  }

  static BoxDecoration stampStyle(
    ColorScheme scheme, {
    double radius = AppTokens.radius,
  }) {
    return BoxDecoration(
      color: paperWarm(scheme),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: inkStamp(scheme), width: 2),
      boxShadow: paperShadowSoft(scheme),
    );
  }

  static BoxDecoration tapeDecoration(
    ColorScheme scheme, {
    double radius = AppTokens.radius,
  }) {
    return BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: paperEdge(scheme), width: 1),
      boxShadow: paperShadowSoft(scheme),
    );
  }

  static BoxDecoration pinDecoration(ColorScheme scheme) {
    return BoxDecoration(
      color: scheme.primary.withOpacity(0.6),
      shape: BoxShape.circle,
      border: Border.all(color: scheme.onPrimaryContainer, width: 1),
      boxShadow: pinShadow(scheme),
    );
  }

  static double noteTiltSmall = -0.02;
  static double noteTiltMedium = 0.03;
  static double noteTiltLarge = -0.04;
}
