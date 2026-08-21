import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/critical_insight.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/reflection_question.dart';
import 'package:fanta_comune/features/game/logic/play_state.dart';
import 'package:fanta_comune/features/profile/domain/perspective_role.dart';
import 'package:fanta_comune/features/game/domain/turn_state.dart';

/// Gestisce il flusso di gioco "Gioca": carica turno, problemi e previsioni.
class PlayCubit extends Cubit<PlayState> {
  /// Crea il cubit con le dipendenze necessarie.
  PlayCubit({required this.repository, required this.prefs})
    : super(const PlayState(isLoading: true));

  final GameRepository repository;
  final AppPrefs prefs;

  Future<Map<String, AggregatedInsight>> _loadInsightsForProblems(
    Iterable<String> problemIds,
  ) async {
    final targets = problemIds.toSet();
    final preserved = Map<String, AggregatedInsight>.fromEntries(
      state.insights.entries.where((entry) => targets.contains(entry.key)),
    );

    for (final id in targets) {
      if (preserved.containsKey(id)) continue;
      final insight = await repository.getAggregatedInsight(id);
      preserved[id] = insight;
    }
    return preserved;
  }

  Future<Map<String, ReflectionQuestion>> _loadReflectionQuestionsForProblems(
    Iterable<String> problemIds,
  ) async {
    final targets = problemIds.toSet();
    final preserved = Map<String, ReflectionQuestion>.fromEntries(
      state.reflectionQuestions.entries.where(
        (entry) => targets.contains(entry.key),
      ),
    );

    for (final id in targets) {
      if (preserved.containsKey(id)) continue;
      final question = await repository.getReflectionQuestion(id);
      preserved[id] = question;
    }
    return preserved;
  }

  PerspectiveRole _suggestPerspectiveRole({
    Map<String, HypothesisConfidence>? confidences,
    Map<String, List<MotivationKey>>? motivations,
    Map<String, int>? reflectionAnswers,
  }) {
    return suggestPerspectiveRole(
      confidences: confidences ?? state.confidences,
      motivations: motivations ?? state.motivations,
      reflectionAnswers: reflectionAnswers ?? state.reflectionAnswers,
    );
  }

  String _insightSignature(AggregatedInsight insight) {
    if (insight.totalPredictions == 0) return 'none';
    final primary = insight.choiceDistribution.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final percentage = insight
        .percentageForChoice(primary)
        .clamp(0, 100)
        .round();
    return '${primary.name}:$percentage:${insight.totalPredictions}';
  }

  Map<String, String> _buildInsightSignatures(
    Map<String, AggregatedInsight> insights,
  ) {
    return {
      for (final entry in insights.entries)
        entry.key: _insightSignature(entry.value),
    };
  }

  bool _hasInsightChanges(
    Map<String, AggregatedInsight> current,
    Map<String, String> stored,
  ) {
    if (stored.isEmpty) return false;
    for (final entry in current.entries) {
      final signature = _insightSignature(entry.value);
      if (stored[entry.key] != signature) {
        return true;
      }
    }
    return false;
  }

  /// Carica e cache l'andamento storico per il problema richiesto.
  Future<void> loadProblemHistory(String problemId) async {
    if (state.insightHistories.containsKey(problemId) ||
        state.loadingInsightHistories.contains(problemId)) {
      return;
    }
    final loading = Set<String>.from(state.loadingInsightHistories)
      ..add(problemId);
    emit(state.copyWith(loadingInsightHistories: loading, error: null));

    try {
      final history = await repository.getInsightHistory(problemId);
      final updatedHistories = Map<String, InsightHistory>.from(
        state.insightHistories,
      )..[problemId] = history;
      loading.remove(problemId);
      emit(
        state.copyWith(
          insightHistories: updatedHistories,
          loadingInsightHistories: loading,
          error: null,
        ),
      );
    } catch (e) {
      loading.remove(problemId);
      emit(
        state.copyWith(loadingInsightHistories: loading, error: e.toString()),
      );
    }
  }

  /// Recupera lo storico reputazione e lo mantiene in cache locale.
  Future<void> loadReputationHistory() async {
    if (state.reputationHistory.isNotEmpty ||
        state.isReputationHistoryLoading) {
      return;
    }

    emit(state.copyWith(isReputationHistoryLoading: true, error: null));
    try {
      final municipalityId = prefs.municipalityId ?? 'demo';
      final history = await repository.getReputationHistory(
        municipalityId: municipalityId,
      );
      emit(
        state.copyWith(
          reputationHistory: history,
          isReputationHistoryLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(isReputationHistoryLoading: false, error: e.toString()),
      );
    }
  }

  /// Carica turno, problemi e previsioni utente riusando il repository mock.
  Future<void> load() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final municipalityId = prefs.municipalityId ?? 'demo';
      final turn = await repository.getCurrentTurn(municipalityId);
      final problems = await repository.listProblems(municipalityId);
      final predictions = await repository.getMyPredictions(turn.id);
      final results = await repository.getPredictionResults(turn.id);
      final reputation = await repository.getReputationScore(turn.id);
      final civicSummary = await repository.getCivicLoopSummary(municipalityId);
      final insights = results.isNotEmpty
          ? await _loadInsightsForProblems(results.keys)
          : const <String, AggregatedInsight>{};
      final reflectionQuestions = await _loadReflectionQuestionsForProblems(
        problems.map((problem) => problem.id),
      );
      final suggestedPerspective = _suggestPerspectiveRole(
        confidences: {
          for (final entry in predictions.entries)
            if (entry.value.confidence != null)
              entry.key: entry.value.confidence!,
        },
        motivations: predictions.map(
          (key, value) => MapEntry(key, value.motivations),
        ),
      );
      final lastSeenTurnId = prefs.getLastSeenTurnId();
      final storedSignatures = prefs.getInsightSignatures();
      final hasPendingInsights =
          results.isNotEmpty && lastSeenTurnId != turn.id;
      final hasChangedPerception =
          results.isNotEmpty && _hasInsightChanges(insights, storedSignatures);
      final hasUnresolvedTurn =
          turn.state == TurnState.open &&
          results.isEmpty &&
          predictions.isNotEmpty;

      emit(
        state.copyWith(
          isLoading: false,
          currentTurn: turn,
          civicSummary: civicSummary,
          problems: problems,
          myPredictions: predictions.map(
            (key, value) => MapEntry(key, value.choice),
          ),
          motivations: predictions.map(
            (key, value) => MapEntry(key, value.motivations),
          ),
          confidences: {
            for (final entry in predictions.entries)
              if (entry.value.confidence != null)
                entry.key: entry.value.confidence!,
          },
          results: results,
          insights: insights,
          reflectionQuestions: reflectionQuestions,
          suggestedPerspective: suggestedPerspective,
          hasPendingInsights: hasPendingInsights,
          hasChangedPerception: hasChangedPerception,
          hasUnresolvedTurn: hasUnresolvedTurn,
          reputation: reputation,
          loadingInsightHistories: const {},
          loadingCriticalInsights: const {},
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Aggiorna in modo ottimistico la previsione per il problema indicato.
  Future<void> selectPrediction({
    required String problemId,
    required PredictionChoice choice,
  }) async {
    final turnId = state.currentTurn?.id;
    if (turnId == null) return;
    final previousChoice = state.myPredictions[problemId];
    if (previousChoice != null) {
      emit(state.copyWith(error: 'Questa carta e\' gia\' stata giocata.'));
      return;
    }

    final updatedPredictions = Map<String, PredictionChoice>.from(
      state.myPredictions,
    )..[problemId] = choice;
    final updatedMotivations = Map<String, List<MotivationKey>>.from(
      state.motivations,
    );
    final updatedConfidences = Map<String, HypothesisConfidence>.from(
      state.confidences,
    );
    final updatedResults = Map<String, PredictionResult>.from(state.results)
      ..remove(problemId);
    final hasUnresolvedTurn =
        state.currentTurn?.state == TurnState.open &&
        updatedResults.isEmpty &&
        updatedPredictions.isNotEmpty;
    final civicSummary = state.civicSummary?.copyWith(
      predictions: updatedPredictions.length,
      outcomes: updatedResults.length,
    );
    emit(
      state.copyWith(
        myPredictions: updatedPredictions,
        motivations: updatedMotivations,
        confidences: updatedConfidences,
        suggestedPerspective: _suggestPerspectiveRole(
          confidences: updatedConfidences,
          motivations: updatedMotivations,
        ),
        hasUnresolvedTurn: hasUnresolvedTurn,
        error: null,
        results: updatedResults,
        civicSummary: civicSummary,
      ),
    );

    try {
      await repository.upsertPrediction(
        turnId: turnId,
        problemId: problemId,
        choice: choice,
        motivations: updatedMotivations[problemId] ?? const [],
        confidence: updatedConfidences[problemId],
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Imposta o aggiorna le motivazioni per una previsione già selezionata.
  Future<void> setMotivations({
    required String problemId,
    required List<MotivationKey> motivations,
  }) async {
    final turnId = state.currentTurn?.id;
    final prediction = state.myPredictions[problemId];
    if (turnId == null || prediction == null) return;

    final limited = motivations.take(2).toList(growable: false);
    final updatedMotivations = Map<String, List<MotivationKey>>.from(
      state.motivations,
    )..[problemId] = limited;
    emit(
      state.copyWith(
        motivations: updatedMotivations,
        suggestedPerspective: _suggestPerspectiveRole(
          motivations: updatedMotivations,
        ),
        error: null,
      ),
    );

    try {
      await repository.updatePredictionMotivations(
        turnId: turnId,
        problemId: problemId,
        motivations: limited,
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Imposta il livello di convinzione per una previsione gia' selezionata.
  Future<void> setConfidence({
    required String problemId,
    required HypothesisConfidence confidence,
  }) async {
    final turnId = state.currentTurn?.id;
    final prediction = state.myPredictions[problemId];
    if (turnId == null || prediction == null) return;

    final updated = Map<String, HypothesisConfidence>.from(state.confidences)
      ..[problemId] = confidence;
    emit(
      state.copyWith(
        confidences: updated,
        suggestedPerspective: _suggestPerspectiveRole(confidences: updated),
        error: null,
      ),
    );

    try {
      await repository.upsertPrediction(
        turnId: turnId,
        problemId: problemId,
        choice: prediction,
        motivations: state.motivations[problemId] ?? const [],
        confidence: confidence,
      );
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Salva la risposta selezionata alla domanda di riflessione.
  void setReflectionAnswer({
    required String problemId,
    required int selectedOptionIndex,
  }) {
    final updated = Map<String, int>.from(state.reflectionAnswers)
      ..[problemId] = selectedOptionIndex;
    emit(
      state.copyWith(
        reflectionAnswers: updated,
        suggestedPerspective: _suggestPerspectiveRole(),
        error: null,
      ),
    );
  }

  /// Ricarica un singolo problema per aggiornare stato e trend in UI.
  Future<void> refreshProblem(String problemId) async {
    try {
      final problem = await repository.getProblemById(problemId);
      final updatedProblems = state.problems
          .map((p) => p.id == problemId ? problem : p)
          .toList(growable: false);
      emit(state.copyWith(problems: updatedProblems, error: null));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Risolve tutte le previsioni correnti, aggiornando esiti e reputazione mock.
  Future<void> resolveTurn() async {
    final turnId = state.currentTurn?.id;
    if (turnId == null || state.myPredictions.isEmpty) return;

    emit(state.copyWith(isLoading: true, error: null));
    try {
      for (final entry in state.myPredictions.entries) {
        await repository.resolvePrediction(
          problemId: entry.key,
          choice: entry.value,
        );
      }

      final resolved = await repository.getPredictionResults(turnId);
      final reputation = await repository.getReputationScore(turnId);
      final municipalityId = prefs.municipalityId ?? 'demo';
      final civicSummary = await repository.getCivicLoopSummary(municipalityId);
      final insights = await _loadInsightsForProblems(resolved.keys);
      List<ReputationScore>? reputationHistory;
      if (state.reputationHistory.isNotEmpty) {
        reputationHistory = await repository.getReputationHistory(
          municipalityId: municipalityId,
        );
      }
      final suggestedPerspective = _suggestPerspectiveRole();
      final lastSeenTurnId = prefs.getLastSeenTurnId();
      final storedSignatures = prefs.getInsightSignatures();
      final hasPendingInsights =
          resolved.isNotEmpty && lastSeenTurnId != turnId;
      final hasChangedPerception =
          resolved.isNotEmpty && _hasInsightChanges(insights, storedSignatures);

      emit(
        state.copyWith(
          isLoading: false,
          results: resolved,
          civicSummary: civicSummary,
          insights: insights,
          suggestedPerspective: suggestedPerspective,
          hasPendingInsights: hasPendingInsights,
          hasChangedPerception: hasChangedPerception,
          hasUnresolvedTurn: false,
          reputation: reputation,
          reputationHistory: reputationHistory ?? state.reputationHistory,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Carica insight critici aggregati solo dopo la risoluzione.
  Future<void> loadCriticalInsights(String problemId) async {
    if (state.criticalInsights.containsKey(problemId) ||
        state.loadingCriticalInsights.contains(problemId)) {
      return;
    }

    final loading = Set<String>.from(state.loadingCriticalInsights)
      ..add(problemId);
    emit(state.copyWith(loadingCriticalInsights: loading, error: null));

    try {
      final insights = await repository.getCriticalInsights(
        problemId: problemId,
        userChoice: state.myPredictions[problemId],
        userConfidence: state.confidences[problemId],
        userReflectionIndex: state.reflectionAnswers[problemId],
      );
      final updated = Map<String, List<CriticalInsight>>.from(
        state.criticalInsights,
      )..[problemId] = insights;
      loading.remove(problemId);
      emit(
        state.copyWith(
          criticalInsights: updated,
          loadingCriticalInsights: loading,
          error: null,
        ),
      );
    } catch (e) {
      loading.remove(problemId);
      emit(
        state.copyWith(loadingCriticalInsights: loading, error: e.toString()),
      );
    }
  }

  /// Segna come rivisitati gli insight correnti e aggiorna i segnali soft.
  Future<void> markRetentionSeen() async {
    final turnId = state.currentTurn?.id;
    if (turnId == null || state.results.isEmpty) return;
    final signatures = _buildInsightSignatures(state.insights);
    await prefs.setLastSeenTurnId(turnId);
    await prefs.setInsightSignatures(signatures);
    emit(
      state.copyWith(hasPendingInsights: false, hasChangedPerception: false),
    );
  }
}
