import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';

/// Rappresenta un singolo scatto storico delle percezioni su un problema.
class InsightSnapshot extends Equatable {
  /// Crea uno snapshot con distribuzione scelte e motivazioni principali.
  const InsightSnapshot({
    required this.turnId,
    required this.at,
    required this.totalPredictions,
    required this.choiceDistribution,
    required this.motivationTop,
  });

  /// Identificativo del turno o finestra temporale di riferimento.
  final String turnId;

  /// Data e ora in cui lo snapshot è stato rilevato.
  final DateTime at;

  /// Numero totale di previsioni raccolte in questo snapshot.
  final int totalPredictions;

  /// Distribuzione delle scelte per questo momento storico.
  final Map<PredictionChoice, int> choiceDistribution;

  /// Motivazioni più citate (massimo due) per contestualizzare il trend.
  final List<MotivationKey> motivationTop;

  /// Restituisce la percentuale per la [choice] rispetto al totale dello snapshot.
  double pct(PredictionChoice choice) {
    if (totalPredictions == 0) return 0;
    final value = choiceDistribution[choice] ?? 0;
    return (value / totalPredictions) * 100;
  }

  @override
  List<Object?> get props => [
    turnId,
    at,
    totalPredictions,
    choiceDistribution,
    motivationTop,
  ];
}
