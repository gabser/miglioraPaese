import 'package:equatable/equatable.dart';

import 'hypothesis_confidence.dart';
import 'motivation_key.dart';
import 'prediction_choice.dart';

class Prediction extends Equatable {
  final String turnId;
  final String problemId;
  final PredictionChoice choice;
  final DateTime createdAt;

  /// Motivazioni opzionali (max 2). Non influenzano punteggio.
  final List<MotivationKey> motivations;

  /// Livello di convinzione associato alla previsione.
  final HypothesisConfidence? confidence;

  const Prediction({
    required this.turnId,
    required this.problemId,
    required this.choice,
    required this.createdAt,
    this.motivations = const [],
    this.confidence,
  });

  Prediction copyWith({
    PredictionChoice? choice,
    DateTime? createdAt,
    List<MotivationKey>? motivations,
    HypothesisConfidence? confidence,
  }) {
    return Prediction(
      turnId: turnId,
      problemId: problemId,
      choice: choice ?? this.choice,
      createdAt: createdAt ?? this.createdAt,
      motivations: motivations ?? this.motivations,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  List<Object?> get props => [
    turnId,
    problemId,
    choice,
    createdAt,
    motivations,
    confidence,
  ];
}
