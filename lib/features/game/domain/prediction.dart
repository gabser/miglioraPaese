import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';

/// Previsione effettuata dall'utente su un problema durante un turno.
class Prediction extends Equatable {
  /// Crea una previsione per [problemId] nel turno [turnId].
  const Prediction({
    required this.turnId,
    required this.problemId,
    required this.choice,
    required this.createdAt,
    this.motivations = const [],
  });

  /// Identificativo del turno in cui è stata fatta la previsione.
  final String turnId;

  /// Identificativo del problema associato.
  final String problemId;

  /// Scelta effettuata dall'utente.
  final PredictionChoice choice;

  /// Timestamp di creazione della previsione.
  final DateTime createdAt;

  /// Motivazioni opzionali che spiegano la scelta effettuata.
  final List<MotivationKey> motivations;

  /// Restituisce una copia immutabile con eventuali aggiornamenti.
  Prediction copyWith({
    String? turnId,
    String? problemId,
    PredictionChoice? choice,
    DateTime? createdAt,
    List<MotivationKey>? motivations,
  }) {
    return Prediction(
      turnId: turnId ?? this.turnId,
      problemId: problemId ?? this.problemId,
      choice: choice ?? this.choice,
      createdAt: createdAt ?? this.createdAt,
      motivations: motivations ?? this.motivations,
    );
  }

  @override
  List<Object?> get props => [turnId, problemId, choice, createdAt, motivations];
}
