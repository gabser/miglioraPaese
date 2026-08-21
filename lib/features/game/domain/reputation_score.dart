import 'package:equatable/equatable.dart';

/// Punteggio di reputazione derivato dalle previsioni concluse.
class ReputationScore extends Equatable {
  /// Crea un punteggio aggregato con punti totali, accuratezza e numero di previsioni.
  const ReputationScore({
    required this.totalPoints,
    required this.accuracy,
    required this.predictionsCount,
  });

  /// Totale dei punti accumulati.
  final int totalPoints;

  /// Accuratezza media (0-1) delle previsioni risolte.
  final double accuracy;

  /// Numero di previsioni valutate.
  final int predictionsCount;

  /// Restituisce una copia immutabile con eventuali modifiche.
  ReputationScore copyWith({
    int? totalPoints,
    double? accuracy,
    int? predictionsCount,
  }) {
    return ReputationScore(
      totalPoints: totalPoints ?? this.totalPoints,
      accuracy: accuracy ?? this.accuracy,
      predictionsCount: predictionsCount ?? this.predictionsCount,
    );
  }

  @override
  List<Object?> get props => [totalPoints, accuracy, predictionsCount];
}
