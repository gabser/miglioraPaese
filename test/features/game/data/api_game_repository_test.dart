import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/game/data/api_game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';

void main() {
  test('loads municipality game resources with canonical paths', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      return switch (request.url.pathSegments.last) {
        'activation' => _json({'municipalityId': 'bologna', 'state': 'active'}),
        'summary' => _json(_summaryPayload),
        'turn' => _json(_turnPayload),
        'problems' => _json({
          'items': [_problemPayload],
        }),
        'leaderboard' => _json({
          'items': [_leaderboardPayload],
        }),
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
    });

    final activation = await repository.getMunicipalityActivationState(
      'comune:Bologna',
    );
    final summary = await repository.getCivicLoopSummary('comune:Bologna');
    final turn = await repository.getCurrentTurn('comune:Bologna');
    final problems = await repository.listProblems('comune:Bologna');
    final leaderboard = await repository.getLeaderboard(
      municipalityId: 'comune:Bologna',
      leagueId: 'centro',
    );

    expect(activation.name, 'active');
    expect(summary.reputationPoints, 10);
    expect(turn.id, 'turn-1');
    expect(problems.single.id, 'problem-1');
    expect(leaderboard.single.userId, 'user:test');
    expect(repository.currentUserId, 'user:test');
    expect(
      requests.every((request) => request.url.pathSegments.contains('bologna')),
      isTrue,
    );
    expect(requests[1].url.queryParameters, {'userId': 'user:test'});
    expect(requests.last.url.queryParameters, {'leagueId': 'centro'});
  });

  test('writes, reloads metadata and resolves the saved prediction', () async {
    final requests = <http.Request>[];
    final repository = _repository((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        return _json({
          'items': [_predictionPayload],
        });
      }
      if (request.method == 'PUT') return _json(_predictionPayload);
      if (request.method == 'POST') {
        return _json({
          'turnId': 'turn-1',
          'problemId': 'problem-1',
          'userId': 'user:test',
          'choice': 'stable',
          'winningChoice': 'improve',
          'result': 'partial',
          'correct': false,
          'pointsDelta': 4,
          'resolvedAt': '2026-08-21T09:00:00.000Z',
        });
      }
      throw StateError('Unexpected request: ${request.method} ${request.url}');
    });

    await repository.upsertPrediction(
      turnId: 'turn-1',
      problemId: 'problem-1',
      choice: PredictionChoice.stable,
      motivations: const [MotivationKey.seasonality],
      confidence: HypothesisConfidence.considered,
    );
    await repository.updatePredictionMotivations(
      turnId: 'turn-1',
      problemId: 'problem-1',
      motivations: const [MotivationKey.visibleActions],
    );
    final result = await repository.resolvePrediction(
      problemId: 'problem-1',
      choice: PredictionChoice.stable,
    );

    final firstWrite = jsonDecode(requests.first.body) as Map<String, dynamic>;
    final metadataWrite = jsonDecode(requests[2].body) as Map<String, dynamic>;
    final resolution = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(requests.first.method, 'PUT');
    expect(firstWrite, {
      'choice': 'stable',
      'motivations': ['seasonality'],
      'confidence': 'considered',
      'userId': 'user:test',
    });
    expect(requests[1].url.queryParameters, {'userId': 'user:test'});
    expect(metadataWrite['motivations'], ['visibleActions']);
    expect(metadataWrite['choice'], 'stable');
    expect(resolution, {'choice': 'stable', 'userId': 'user:test'});
    expect(result, PredictionResult.partial);
  });

  test('loads results, reputation and all insight projections', () async {
    final requestedPaths = <String>[];
    final repository = _repository((request) async {
      requestedPaths.add(request.url.path);
      return switch (request.url.pathSegments.last) {
        'prediction-results' => _json({
          'items': [
            {'problemId': 'problem-1', 'result': 'correct'},
          ],
        }),
        'reputation' => _json(_reputationPayload),
        'reputation-history' => _json({
          'items': [_reputationPayload],
        }),
        'insight' => _json(_aggregatePayload),
        'insight-history' => _json({
          'problemId': 'problem-1',
          'snapshots': [
            {
              'turnId': 'turn-1',
              'at': '2026-08-21T09:00:00.000Z',
              'totalPredictions': 1,
              'choiceDistribution': _choiceDistribution,
              'motivationTop': ['visibleActions'],
            },
          ],
        }),
        'critical-insights' => _json({
          'items': [
            {
              'headline': 'Percezione prevalente',
              'supporting': 'Il tema migliora.',
              'note': null,
            },
          ],
        }),
        _ => throw StateError('Unexpected request: ${request.url}'),
      };
    });

    final results = await repository.getPredictionResults('turn-1');
    final reputation = await repository.getReputationScore('turn-1');
    final reputationHistory = await repository.getReputationHistory(
      municipalityId: 'comune:Bologna',
    );
    final insight = await repository.getAggregatedInsight('problem-1');
    final history = await repository.getInsightHistory('problem-1');
    final critical = await repository.getCriticalInsights(
      problemId: 'problem-1',
      userChoice: PredictionChoice.improve,
      userConfidence: HypothesisConfidence.convinced,
      userReflectionIndex: 2,
    );

    expect(results, {'problem-1': PredictionResult.correct});
    expect(reputation.totalPoints, 10);
    expect(reputationHistory.single.accuracy, 1);
    expect(insight.totalPredictions, 1);
    expect(history.snapshots.single.turnId, 'turn-1');
    expect(critical.single.headline, 'Percezione prevalente');
    expect(requestedPaths, hasLength(6));
  });

  test('keeps unsupported progressive capabilities explicit', () async {
    var requestCount = 0;
    final repository = _repository((request) async {
      requestCount += 1;
      return _json({
        'items': [_problemPayload],
      });
    });

    await expectLater(
      repository.getCurrentTurn('comune:Milano'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'unsupported_municipality',
        ),
      ),
    );
    await expectLater(
      repository.getProblemById('problem-1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'problem_not_loaded',
        ),
      ),
    );
    await expectLater(
      repository.tapSignal(problemId: 'problem-1', resolved: true),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'unsupported_remote_capability',
        ),
      ),
    );
    expect(requestCount, 0);

    await repository.listProblems('comune:Bologna');
    final cached = await repository.getProblemById('problem-1');
    expect(cached.title, 'Verde pubblico');
    expect(requestCount, 1);
  });
}

ApiGameRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiGameRepository(
    client: ApiClient(
      baseUrl: Uri.parse('https://example.test/root'),
      client: MockClient(handler),
    ),
    userId: 'user:test',
    localFallback: MockGameRepository(),
  );
}

http.Response _json(Object payload, [int status = 200]) {
  return http.Response(jsonEncode(payload), status);
}

const _summaryPayload = <String, Object?>{
  'municipalityName': 'Bologna',
  'proposedThemes': 2,
  'confirmedThemes': 1,
  'cardsInTurn': 1,
  'predictions': 1,
  'outcomes': 1,
  'reputationPoints': 10,
  'topThemeTitle': 'Verde pubblico',
};

const _turnPayload = <String, Object?>{
  'id': 'turn-1',
  'municipalityId': 'bologna',
  'state': 'open',
  'startAt': '2026-08-20T09:00:00.000Z',
  'endAt': '2026-08-27T09:00:00.000Z',
};

const _problemPayload = <String, Object?>{
  'id': 'problem-1',
  'key': 'green',
  'title': 'Verde pubblico',
  'zoneName': 'Centro',
  'status': 'improving',
  'trendPercent': 8,
  'updatedAt': '2026-08-21T09:00:00.000Z',
};

const _leaderboardPayload = <String, Object?>{
  'userId': 'user:test',
  'displayName': 'Tu',
  'points': 10,
  'rank': 1,
};

const _predictionPayload = <String, Object?>{
  'id': 'prediction-1',
  'turnId': 'turn-1',
  'problemId': 'problem-1',
  'userId': 'user:test',
  'choice': 'stable',
  'motivations': ['seasonality'],
  'confidence': 'considered',
  'createdAt': '2026-08-21T09:00:00.000Z',
  'updatedAt': '2026-08-21T09:00:00.000Z',
};

const _reputationPayload = <String, Object?>{
  'totalPoints': 10,
  'accuracy': 1,
  'predictionsCount': 1,
};

const _choiceDistribution = <String, Object?>{
  'improve': 1,
  'stable': 0,
  'worsen': 0,
};

const _motivationDistribution = <String, Object?>{
  'visibleActions': 1,
  'recentDecline': 0,
  'seasonality': 0,
  'unmetPromises': 0,
  'personalExperience': 0,
};

const _aggregatePayload = <String, Object?>{
  'problemId': 'problem-1',
  'totalPredictions': 1,
  'choiceDistribution': _choiceDistribution,
  'motivationDistribution': _motivationDistribution,
};
