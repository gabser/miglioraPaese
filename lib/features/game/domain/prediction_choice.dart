import 'package:equatable/equatable.dart';

/// Opzioni disponibili per una previsione civica su un problema.
enum PredictionChoice with EquatableMixin {
  /// L'utente prevede un miglioramento della situazione.
  improve,

  /// L'utente prevede stabilità senza grandi cambiamenti.
  stable,

  /// L'utente prevede un peggioramento nel prossimo turno.
  worsen;

  @override
  List<Object?> get props => [index];
}
