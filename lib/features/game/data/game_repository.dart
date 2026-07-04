import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/features/civic_loop/domain/civic_loop_summary.dart';
import 'package:fanta_comune/features/game/domain/critical_insight.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/reflection_question.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

/// Contratto astratto per recuperare dati di gioco e classifica.
abstract class GameRepository {
  /// Identificativo dell'utente corrente utilizzato per evidenziare la classifica.
  String get currentUserId;

  /// Restituisce il turno corrente per il [municipalityId].
  Future<Turn> getCurrentTurn(String municipalityId);

  /// Indica se il Comune ha gia' dati di gioco o va attivato.
  Future<MunicipalityActivationState> getMunicipalityActivationState(
    String municipalityId,
  );

  /// Restituisce il riepilogo del loop civico reale per il Comune.
  Future<CivicLoopSummary> getCivicLoopSummary(String municipalityId);

  /// Elenca i problemi attivi per il [municipalityId].
  Future<List<Problem>> listProblems(String municipalityId);

  /// Recupera le previsioni dell'utente corrente per il turno [turnId].
  ///
  /// La mappa ha chiave [Problem.id] e valore [Prediction].
  Future<Map<String, Prediction>> getMyPredictions(String turnId);

  /// Inserisce o aggiorna una previsione per un problema specifico.
  Future<void> upsertPrediction({
    required String turnId,
    required String problemId,
    required PredictionChoice choice,
    List<MotivationKey> motivations = const [],
    HypothesisConfidence? confidence,
  });

  /// Aggiorna le motivazioni associate a una previsione esistente.
  Future<void> updatePredictionMotivations({
    required String turnId,
    required String problemId,
    required List<MotivationKey> motivations,
  });

  /// Restituisce una domanda di riflessione associata al problema.
  Future<ReflectionQuestion> getReflectionQuestion(String problemId);

  /// Risolve una previsione e restituisce l'esito deterministico basato sullo stato finale.
  Future<PredictionResult> resolvePrediction({
    required String problemId,
    required PredictionChoice choice,
  });

  /// Segnala se il problema è stato risolto o peggiorato, aggiornandone lo stato.
  Future<void> tapSignal({required String problemId, required bool resolved});

  /// Restituisce l'insight aggregato (mock) per il problema indicato.
  Future<AggregatedInsight> getAggregatedInsight(String problemId);

  /// Restituisce il problema associato all'[problemId] richiesto.
  Future<Problem> getProblemById(String problemId);

  /// Restituisce la classifica locale per il [municipalityId] e, opzionalmente, la [leagueId].
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String municipalityId,
    String? leagueId,
  });

  /// Restituisce gli esiti salvati delle previsioni dell'utente per il turno.
  Future<Map<String, PredictionResult>> getPredictionResults(String turnId);

  /// Restituisce il punteggio di reputazione corrente per il turno.
  Future<ReputationScore> getReputationScore(String turnId);

  /// Restituisce lo storico sintetico delle percezioni per il [problemId] richiesto.
  Future<InsightHistory> getInsightHistory(String problemId);

  /// Restituisce lo storico delle reputazioni per il comune indicato.
  Future<List<ReputationScore>> getReputationHistory({
    required String municipalityId,
  });

  /// Restituisce un set di insight critici aggregati post-risoluzione.
  Future<List<CriticalInsight>> getCriticalInsights({
    required String problemId,
    required PredictionChoice? userChoice,
    required HypothesisConfidence? userConfidence,
    required int? userReflectionIndex,
  });
}
