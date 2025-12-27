import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';

/// Stato del flusso di gioco "Gioca", con dati del turno e previsioni correnti.
class PlayState extends Equatable {
  /// Crea uno stato iniziale o aggiornato del cubit di gioco.
  const PlayState({
    this.isLoading = false,
    this.currentTurn,
    this.problems = const <Problem>[],
    this.myPredictions = const <String, PredictionChoice>{},
    this.motivations = const <String, List<MotivationKey>>{},
    this.results = const <String, PredictionResult>{},
    this.insights = const <String, AggregatedInsight>{},
    this.insightHistories = const <String, InsightHistory>{},
    this.loadingInsightHistories = const <String>{},
    this.reputation = const ReputationScore(
      totalPoints: 0,
      accuracy: 0,
      predictionsCount: 0,
    ),
    this.reputationHistory = const <ReputationScore>[],
    this.isReputationHistoryLoading = false,
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

  /// Motivazioni selezionate per le previsioni, indicizzate per problema.
  final Map<String, List<MotivationKey>> motivations;

  /// Esiti delle previsioni già risolte.
  final Map<String, PredictionResult> results;

  /// Insight aggregati sui problemi già risolti, indicizzati per [Problem.id].
  final Map<String, AggregatedInsight> insights;

  /// Storico sintetico degli insight per ogni problema risolto.
  final Map<String, InsightHistory> insightHistories;

  /// Identifica i problemi per cui è in corso il caricamento dello storico.
  final Set<String> loadingInsightHistories;

  /// Punteggio aggregato derivato dalle previsioni concluse.
  final ReputationScore reputation;

  /// Storico reputazione calcolato in base ai turni precedenti.
  final List<ReputationScore> reputationHistory;

  /// Indica se è in corso il caricamento dello storico reputazione.
  final bool isReputationHistoryLoading;

  /// Messaggio di errore opzionale per comunicazioni leggere alla UI.
  final String? error;

  /// Restituisce una copia immutabile con eventuali campi aggiornati.
  PlayState copyWith({
    bool? isLoading,
    Turn? currentTurn,
    List<Problem>? problems,
    Map<String, PredictionChoice>? myPredictions,
    Map<String, List<MotivationKey>>? motivations,
    Map<String, PredictionResult>? results,
    Map<String, AggregatedInsight>? insights,
    Map<String, InsightHistory>? insightHistories,
    Set<String>? loadingInsightHistories,
    ReputationScore? reputation,
    List<ReputationScore>? reputationHistory,
    bool? isReputationHistoryLoading,
    String? error,
  }) {
    return PlayState(
      isLoading: isLoading ?? this.isLoading,
      currentTurn: currentTurn ?? this.currentTurn,
      problems: problems ?? this.problems,
      myPredictions: myPredictions ?? this.myPredictions,
      motivations: motivations ?? this.motivations,
      results: results ?? this.results,
      insights: insights ?? this.insights,
      insightHistories: insightHistories ?? this.insightHistories,
      loadingInsightHistories: loadingInsightHistories ?? this.loadingInsightHistories,
      reputation: reputation ?? this.reputation,
      reputationHistory: reputationHistory ?? this.reputationHistory,
      isReputationHistoryLoading: isReputationHistoryLoading ?? this.isReputationHistoryLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        currentTurn,
        problems,
        myPredictions,
        motivations,
        results,
        insights,
        insightHistories,
        loadingInsightHistories,
        reputation,
        reputationHistory,
        isReputationHistoryLoading,
        error,
      ];
}
