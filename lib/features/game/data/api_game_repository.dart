import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/civic_loop/domain/civic_loop_summary.dart';
import 'package:fanta_comune/features/game/data/game_mapper.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
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

/// HTTP game data. Unsupported capabilities fail explicitly; local data is
/// never substituted for a remote operation. Server identity comes from the
/// bearer proposal session, independently of the local user identifier.
class ApiGameRepository implements GameRepository, GameRepositoryCapabilities {
  ApiGameRepository({
    required ApiClient client,
    required String userId,
    this.sessions,
  }) : _client = client,
       _userId = userId;

  @override
  bool get supportsReflection => false;
  @override
  bool get supportsSignals => false;
  final SessionLeaseSource? sessions;
  Future<Map<String, String>> _headers() async => sessions == null
      ? const {}
      : (await sessions!.active(allowCreate: true)).headers;
  final ApiClient _client;
  final String _userId;
  final Map<String, Problem> _problemCache = {};

  @override
  String get currentUserId => _userId;

  @override
  Future<Turn> getCurrentTurn(String municipalityId) async {
    final payload = await _client.getJson(
      _municipalityPath(municipalityId, 'turn'),
      headers: await _headers(),
    );
    return GameMapper.turnFromResponse(payload);
  }

  @override
  Future<MunicipalityActivationState> getMunicipalityActivationState(
    String municipalityId,
  ) async {
    final payload = await _client.getJson(
      _municipalityPath(municipalityId, 'activation'),
      headers: await _headers(),
    );
    return GameMapper.activationFromResponse(payload);
  }

  @override
  Future<CivicLoopSummary> getCivicLoopSummary(String municipalityId) async {
    final payload = await _client.getJson(
      _municipalityPath(municipalityId, 'summary'),
      headers: await _headers(),
    );
    return GameMapper.civicSummaryFromResponse(payload);
  }

  @override
  Future<List<Problem>> listProblems(String municipalityId) async {
    final payload = await _client.getJson(
      _municipalityPath(municipalityId, 'problems'),
      headers: await _headers(),
    );
    final problems = GameMapper.problemsFromResponse(payload);
    for (final problem in problems) {
      _problemCache[problem.id] = problem;
    }
    return problems;
  }

  @override
  Future<Map<String, Prediction>> getMyPredictions(String turnId) async {
    final payload = await _client.getJson([
      'v1',
      'turns',
      turnId,
      'predictions',
    ], headers: await _headers());
    return GameMapper.predictionsFromResponse(payload);
  }

  @override
  Future<void> upsertPrediction({
    required String turnId,
    required String problemId,
    required PredictionChoice choice,
    List<MotivationKey> motivations = const [],
    HypothesisConfidence? confidence,
  }) async {
    await _putPrediction(
      turnId: turnId,
      problemId: problemId,
      choice: choice,
      motivations: motivations,
      confidence: confidence,
    );
  }

  @override
  Future<void> updatePredictionMotivations({
    required String turnId,
    required String problemId,
    required List<MotivationKey> motivations,
  }) async {
    final prediction = (await getMyPredictions(turnId))[problemId];
    if (prediction == null) {
      throw const ApiException(
        kind: ApiExceptionKind.response,
        code: 'prediction_not_found',
        message: 'La previsione da aggiornare non esiste.',
        statusCode: 404,
      );
    }
    await _putPrediction(
      turnId: turnId,
      problemId: problemId,
      choice: prediction.choice,
      motivations: motivations,
      confidence: prediction.confidence,
    );
  }

  Future<void> _putPrediction({
    required String turnId,
    required String problemId,
    required PredictionChoice choice,
    required List<MotivationKey> motivations,
    required HypothesisConfidence? confidence,
  }) async {
    await _client.putJson(
      ['v1', 'turns', turnId, 'predictions', problemId],
      body: {
        'choice': choice.name,
        'motivations': motivations.map((value) => value.name).toList(),
        'confidence': confidence?.name,
      },
      headers: await _headers(),
    );
  }

  @override
  Future<ReflectionQuestion> getReflectionQuestion(String problemId) {
    throw ApiException.configuration(
      code: 'unsupported_remote_capability',
      message: 'Il backend non supporta ancora le domande di riflessione.',
    );
  }

  @override
  Future<PredictionResult> resolvePrediction({
    required String problemId,
    required PredictionChoice choice,
  }) async {
    final payload = await _client.postJson(
      ['v1', 'problems', problemId, 'resolve'],
      body: {'choice': choice.name},
      headers: await _headers(),
    );
    return GameMapper.predictionResultFromResolution(payload);
  }

  @override
  Future<void> tapSignal({
    required String problemId,
    required bool resolved,
  }) async {
    throw ApiException.configuration(
      code: 'unsupported_remote_capability',
      message: 'Il backend non supporta ancora i segnali sul problema.',
    );
  }

  @override
  Future<AggregatedInsight> getAggregatedInsight(String problemId) async {
    final payload = await _client.getJson([
      'v1',
      'problems',
      problemId,
      'insight',
    ], headers: await _headers());
    return GameMapper.aggregatedInsightFromResponse(payload);
  }

  @override
  Future<Problem> getProblemById(String problemId) async {
    final cached = _problemCache[problemId];
    if (cached != null) return cached;
    throw ApiException.configuration(
      code: 'problem_not_loaded',
      message: 'Il problema deve essere caricato dal Comune prima del refresh.',
    );
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String municipalityId,
    String? leagueId,
  }) async {
    final payload = await _client.getJson(
      _municipalityPath(municipalityId, 'leaderboard'),
      queryParameters: {'leagueId': leagueId},
      headers: await _headers(),
    );
    return GameMapper.leaderboardFromResponse(payload);
  }

  @override
  Future<Map<String, PredictionResult>> getPredictionResults(
    String turnId,
  ) async {
    final payload = await _client.getJson([
      'v1',
      'turns',
      turnId,
      'prediction-results',
    ], headers: await _headers());
    return GameMapper.resultsFromResponse(payload);
  }

  @override
  Future<ReputationScore> getReputationScore(String turnId) async {
    final payload = await _client.getJson([
      'v1',
      'turns',
      turnId,
      'reputation',
    ], headers: await _headers());
    return GameMapper.reputationFromResponse(payload);
  }

  @override
  Future<InsightHistory> getInsightHistory(String problemId) async {
    final payload = await _client.getJson([
      'v1',
      'problems',
      problemId,
      'insight-history',
    ], headers: await _headers());
    return GameMapper.insightHistoryFromResponse(payload);
  }

  @override
  Future<List<ReputationScore>> getReputationHistory({
    required String municipalityId,
  }) async {
    final payload = await _client.getJson(
      _municipalityPath(municipalityId, 'reputation-history'),
      headers: await _headers(),
    );
    return GameMapper.reputationHistoryFromResponse(payload);
  }

  @override
  Future<List<CriticalInsight>> getCriticalInsights({
    required String problemId,
    required PredictionChoice? userChoice,
    required HypothesisConfidence? userConfidence,
    required int? userReflectionIndex,
  }) async {
    final payload = await _client.getJson(
      ['v1', 'problems', problemId, 'critical-insights'],
      queryParameters: {
        'userChoice': userChoice?.name,
        'userConfidence': userConfidence?.name,
        'userReflectionIndex': userReflectionIndex?.toString(),
      },
      headers: await _headers(),
    );
    return GameMapper.criticalInsightsFromResponse(payload);
  }

  List<String> _municipalityPath(String municipalityId, String resource) {
    final apiId = MunicipalityCatalog.apiIdFor(municipalityId);
    if (apiId == null) {
      throw ApiException.configuration(
        code: 'unsupported_municipality',
        message: 'Il Comune selezionato non e\' ancora disponibile via API.',
      );
    }
    return ['v1', 'municipalities', apiId, resource];
  }
}
