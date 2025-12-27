import 'package:equatable/equatable.dart';

/// Esito di una previsione confrontata con l'andamento reale del problema.
enum PredictionResult with EquatableMixin {
  /// Previsione corretta rispetto allo stato finale.
  correct,

  /// Previsione parzialmente allineata (stabilità o miglioramento/peggioramento vicino).
  partial,

  /// Previsione errata rispetto allo stato finale.
  wrong,

  /// Previsione non ancora valutata.
  pending;

  @override
  List<Object?> get props => [name];
}
