import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';

/// Insight aggregato (mock) che sintetizza percezioni collettive su un problema.
class AggregatedInsight extends Equatable {
  /// Crea un insight aggregato per [problemId] con distribuzioni di scelte e motivazioni.
  const AggregatedInsight({
    required this.problemId,
    required this.totalPredictions,
    required this.choiceDistribution,
    required this.motivationDistribution,
  });

  /// Identificativo del problema a cui si riferisce l'insight.
  final String problemId;

  /// Numero totale di previsioni considerate nella distribuzione.
  final int totalPredictions;

  /// Distribuzione delle scelte raccolte, indicizzata per [PredictionChoice].
  final Map<PredictionChoice, int> choiceDistribution;

  /// Distribuzione delle motivazioni più ricorrenti, indicizzata per [MotivationKey].
  final Map<MotivationKey, int> motivationDistribution;

  /// Restituisce la percentuale (0-100) associata alla [choice] richiesta.
  double percentageForChoice(PredictionChoice choice) {
    if (totalPredictions == 0) return 0;
    final count = choiceDistribution[choice] ?? 0;
    return (count / totalPredictions) * 100;
  }

  /// Restituisce la percentuale (0-100) associata alla [key] richiesta.
  double percentageForMotivation(MotivationKey key) {
    if (totalPredictions == 0) return 0;
    final count = motivationDistribution[key] ?? 0;
    return (count / totalPredictions) * 100;
  }

  @override
  List<Object?> get props => [
    problemId,
    totalPredictions,
    choiceDistribution,
    motivationDistribution,
  ];
}
