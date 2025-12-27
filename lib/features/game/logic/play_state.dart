import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';

/// Stato del flusso di gioco "Gioca", con dati del turno e previsioni correnti.
class PlayState extends Equatable {
  /// Crea uno stato iniziale o aggiornato del cubit di gioco.
  const PlayState({
    this.isLoading = false,
    this.currentTurn,
    this.problems = const [],
    this.myPredictions = const {},
    this.error,
  });

  /// Indica se i dati sono in caricamento.
  final bool isLoading;

  /// Turno corrente recuperato dal repository.
  final Turn? currentTurn;

  /// Lista di problemi attivi per il turno.
  final List<Problem> problems;

  /// Mappa delle previsioni effettuate dall'utente, indicizzata per problema.
  final Map<String, PredictionChoice> myPredictions;

  /// Messaggio di errore opzionale per comunicazioni leggere alla UI.
  final String? error;

  /// Restituisce una copia immutabile con eventuali campi aggiornati.
  PlayState copyWith({
    bool? isLoading,
    Turn? currentTurn,
    List<Problem>? problems,
    Map<String, PredictionChoice>? myPredictions,
    String? error,
  }) {
    return PlayState(
      isLoading: isLoading ?? this.isLoading,
      currentTurn: currentTurn ?? this.currentTurn,
      problems: problems ?? this.problems,
      myPredictions: myPredictions ?? this.myPredictions,
      error: error,
    );
  }

  @override
  List<Object?> get props => [isLoading, currentTurn, problems, myPredictions, error];
}
