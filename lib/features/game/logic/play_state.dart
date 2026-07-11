import 'package:equatable/equatable.dart';
import 'package:fanta_comune/features/civic_loop/domain/civic_loop_summary.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/critical_insight.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/reflection_question.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';
import 'package:fanta_comune/features/profile/domain/perspective_role.dart';

/// Stato del flusso di gioco "Gioca", con dati del turno e previsioni correnti.
class PlayState extends Equatable {
  /// Crea uno stato iniziale o aggiornato del cubit di gioco.
  const PlayState({
    this.isLoading = false,
    this.currentTurn,
    this.civicSummary,
    this.problems = const <Problem>[],
    this.myPredictions = const <String, PredictionChoice>{},
    this.motivations = const <String, List<MotivationKey>>{},
    this.confidences = const <String, HypothesisConfidence>{},
    this.results = const <String, PredictionResult>{},
    this.insights = const <String, AggregatedInsight>{},
    this.insightHistories = const <String, InsightHistory>{},
    this.loadingInsightHistories = const <String>{},
    this.reflectionQuestions = const <String, ReflectionQuestion>{},
    this.reflectionAnswers = const <String, int>{},
    this.criticalInsights = const <String, List<CriticalInsight>>{},
    this.loadingCriticalInsights = const <String>{},
    this.suggestedPerspective,
    this.hasPendingInsights = false,
    this.hasChangedPerception = false,
    this.hasUnresolvedTurn = false,
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

  /// Riepilogo del ciclo civico reale per il Comune selezionato.
  final CivicLoopSummary? civicSummary;

  /// Lista di problemi attivi per il turno.
  final List<Problem> problems;

  /// Mappa delle previsioni effettuate dall'utente, indicizzata per problema.
  final Map<String, PredictionChoice> myPredictions;

  /// Motivazioni selezionate per le previsioni, indicizzate per problema.
  final Map<String, List<MotivationKey>> motivations;

  /// Livello di convinzione per le previsioni, indicizzato per problema.
  final Map<String, HypothesisConfidence> confidences;

  /// Esiti delle previsioni già risolte.
  final Map<String, PredictionResult> results;

  /// Insight aggregati sui problemi già risolti, indicizzati per [Problem.id].
  final Map<String, AggregatedInsight> insights;

  /// Storico sintetico degli insight per ogni problema risolto.
  final Map<String, InsightHistory> insightHistories;

  /// Identifica i problemi per cui è in corso il caricamento dello storico.
  final Set<String> loadingInsightHistories;

  /// Domande di riflessione disponibili per i problemi attivi.
  final Map<String, ReflectionQuestion> reflectionQuestions;

  /// Risposte selezionate alle domande di riflessione (indice opzione).
  final Map<String, int> reflectionAnswers;

  /// Insight critici aggregati caricati on-demand.
  final Map<String, List<CriticalInsight>> criticalInsights;

  /// Identifica i problemi per cui e' in corso il caricamento degli insight critici.
  final Set<String> loadingCriticalInsights;

  /// Suggerimento di lente in base al comportamento recente.
  final PerspectiveRole? suggestedPerspective;

  /// Indica se ci sono insight risolti non ancora rivisitati.
  final bool hasPendingInsights;

  /// Indica se le percezioni aggregate sono cambiate dall'ultima visita.
  final bool hasChangedPerception;

  /// Indica se c'e' un turno aperto non ancora risolto.
  final bool hasUnresolvedTurn;

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
    CivicLoopSummary? civicSummary,
    List<Problem>? problems,
    Map<String, PredictionChoice>? myPredictions,
    Map<String, List<MotivationKey>>? motivations,
    Map<String, HypothesisConfidence>? confidences,
    Map<String, PredictionResult>? results,
    Map<String, AggregatedInsight>? insights,
    Map<String, InsightHistory>? insightHistories,
    Set<String>? loadingInsightHistories,
    Map<String, ReflectionQuestion>? reflectionQuestions,
    Map<String, int>? reflectionAnswers,
    Map<String, List<CriticalInsight>>? criticalInsights,
    Set<String>? loadingCriticalInsights,
    PerspectiveRole? suggestedPerspective,
    bool? hasPendingInsights,
    bool? hasChangedPerception,
    bool? hasUnresolvedTurn,
    ReputationScore? reputation,
    List<ReputationScore>? reputationHistory,
    bool? isReputationHistoryLoading,
    String? error,
  }) {
    return PlayState(
      isLoading: isLoading ?? this.isLoading,
      currentTurn: currentTurn ?? this.currentTurn,
      civicSummary: civicSummary ?? this.civicSummary,
      problems: problems ?? this.problems,
      myPredictions: myPredictions ?? this.myPredictions,
      motivations: motivations ?? this.motivations,
      confidences: confidences ?? this.confidences,
      results: results ?? this.results,
      insights: insights ?? this.insights,
      insightHistories: insightHistories ?? this.insightHistories,
      loadingInsightHistories:
          loadingInsightHistories ?? this.loadingInsightHistories,
      reflectionQuestions: reflectionQuestions ?? this.reflectionQuestions,
      reflectionAnswers: reflectionAnswers ?? this.reflectionAnswers,
      criticalInsights: criticalInsights ?? this.criticalInsights,
      loadingCriticalInsights:
          loadingCriticalInsights ?? this.loadingCriticalInsights,
      suggestedPerspective: suggestedPerspective ?? this.suggestedPerspective,
      hasPendingInsights: hasPendingInsights ?? this.hasPendingInsights,
      hasChangedPerception: hasChangedPerception ?? this.hasChangedPerception,
      hasUnresolvedTurn: hasUnresolvedTurn ?? this.hasUnresolvedTurn,
      reputation: reputation ?? this.reputation,
      reputationHistory: reputationHistory ?? this.reputationHistory,
      isReputationHistoryLoading:
          isReputationHistoryLoading ?? this.isReputationHistoryLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    currentTurn,
    civicSummary,
    problems,
    myPredictions,
    motivations,
    confidences,
    results,
    insights,
    insightHistories,
    loadingInsightHistories,
    reflectionQuestions,
    reflectionAnswers,
    criticalInsights,
    loadingCriticalInsights,
    suggestedPerspective,
    hasPendingInsights,
    hasChangedPerception,
    hasUnresolvedTurn,
    reputation,
    reputationHistory,
    isReputationHistoryLoading,
    error,
  ];
}
