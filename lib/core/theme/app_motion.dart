import 'package:flutter/material.dart';

/// Token di motion centralizzati per durate e curve coerenti.
class AppMotion {
  const AppMotion._();

  /// Durata rapida per micro-transizioni e feedback immediati.
  static const Duration fast = Duration(milliseconds: 150);

  /// Durata standard per cambi di stato principali.
  static const Duration normal = Duration(milliseconds: 250);

  /// Durata più morbida per transizioni lievemente dilatate.
  static const Duration slow = Duration(milliseconds: 350);

  /// Curva standard per ingressi naturali con leggero rallentamento finale.
  static const Curve standard = Curves.easeOutCubic;

  /// Curva enfatizzata per transizioni più percepibili ma sempre morbide.
  static const Curve emphasize = Curves.easeInOutCubic;
}
