import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/game/data/game_mapper.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/turn_state.dart';

void main() {
  test('maps activation, summary, turn and problem responses', () {
    final activation = GameMapper.activationFromResponse({
      'municipalityId': 'bologna',
      'state': 'active',
    });
    final summary = GameMapper.civicSummaryFromResponse({
      'municipalityName': 'Bologna',
      'proposedThemes': 4,
      'confirmedThemes': 2,
      'cardsInTurn': 3,
      'predictions': 2,
      'outcomes': 1,
      'reputationPoints': 10,
      'topThemeTitle': null,
    });
    final turn = GameMapper.turnFromResponse({
      'id': 'turn-1',
      'municipalityId': 'bologna',
      'state': 'open',
      'startAt': '2026-08-20T08:00:00.000Z',
      'endAt': '2026-08-27T08:00:00.000Z',
    });
    final problems = GameMapper.problemsFromResponse({
      'items': [
        {
          'id': 'problem-1',
          'key': 'green',
          'title': 'Verde pubblico',
          'zoneName': null,
          'status': 'improving',
          'trendPercent': 8,
          'updatedAt': '2026-08-21T08:00:00.000Z',
        },
      ],
    });

    expect(activation, MunicipalityActivationState.active);
    expect(summary.outcomes, 1);
    expect(summary.topThemeTitle, isNull);
    expect(turn.state, TurnState.open);
    expect(turn.startAt.isUtc, isTrue);
    expect(problems.single.key, ProblemKey.green);
    expect(problems.single.status, ProblemStatus.improving);
    expect(problems.single.zoneName, isNull);
  });

  test('maps predictions, results and reputation responses', () {
    final predictions = GameMapper.predictionsFromResponse({
      'items': [
        {
          'id': 'prediction-1',
          'turnId': 'turn-1',
          'problemId': 'problem-1',
          'userId': 'user:test',
          'choice': 'stable',
          'motivations': ['seasonality'],
          'confidence': 'considered',
          'createdAt': '2026-08-21T08:00:00.000Z',
          'updatedAt': '2026-08-21T08:00:00.000Z',
        },
      ],
    });
    final results = GameMapper.resultsFromResponse({
      'items': [
        {'problemId': 'problem-1', 'result': 'partial'},
      ],
    });
    final score = GameMapper.reputationFromResponse({
      'totalPoints': 4,
      'accuracy': 0.5,
      'predictionsCount': 1,
    });
    final history = GameMapper.reputationHistoryFromResponse({
      'items': [
        {'totalPoints': 0, 'accuracy': 0, 'predictionsCount': 0},
        {'totalPoints': 4, 'accuracy': 0.5, 'predictionsCount': 1},
      ],
    });

    expect(predictions['problem-1']?.choice, PredictionChoice.stable);
    expect(predictions['problem-1']?.motivations, [MotivationKey.seasonality]);
    expect(
      predictions['problem-1']?.confidence,
      HypothesisConfidence.considered,
    );
    expect(results, {'problem-1': PredictionResult.partial});
    expect(score.totalPoints, 4);
    expect(score.accuracy, 0.5);
    expect(history, hasLength(2));
  });

  test(
    'maps aggregate, history, critical insight and leaderboard responses',
    () {
      final aggregate = GameMapper.aggregatedInsightFromResponse({
        'problemId': 'problem-1',
        'totalPredictions': 3,
        'choiceDistribution': _choiceDistribution,
        'motivationDistribution': _motivationDistribution,
      });
      final history = GameMapper.insightHistoryFromResponse({
        'problemId': 'problem-1',
        'snapshots': [
          {
            'turnId': 'turn-1',
            'at': '2026-08-21T08:00:00.000Z',
            'totalPredictions': 3,
            'choiceDistribution': _choiceDistribution,
            'motivationTop': ['visibleActions', 'seasonality'],
          },
        ],
      });
      final critical = GameMapper.criticalInsightsFromResponse({
        'items': [
          {
            'headline': 'Percezione prevalente',
            'supporting': 'Il 67% prevede un miglioramento.',
            'note': null,
          },
        ],
      });
      final leaderboard = GameMapper.leaderboardFromResponse({
        'items': [
          {
            'userId': 'user:test',
            'displayName': 'Tu',
            'points': 100,
            'rank': 1,
          },
        ],
      });

      expect(aggregate.choiceDistribution[PredictionChoice.improve], 2);
      expect(aggregate.motivationDistribution[MotivationKey.visibleActions], 2);
      expect(history.snapshots.single.motivationTop, [
        MotivationKey.visibleActions,
        MotivationKey.seasonality,
      ]);
      expect(critical.single.note, isNull);
      expect(leaderboard.single.rank, 1);
    },
  );

  test('rejects unknown enums, duplicate results and incomplete maps', () {
    expect(
      () => GameMapper.turnFromResponse({
        'id': 'turn-1',
        'state': 'paused',
        'startAt': '2026-08-20T08:00:00.000Z',
        'endAt': '2026-08-27T08:00:00.000Z',
      }),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => GameMapper.resultsFromResponse({
        'items': [
          {'problemId': 'problem-1', 'result': 'correct'},
          {'problemId': 'problem-1', 'result': 'wrong'},
        ],
      }),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => GameMapper.aggregatedInsightFromResponse({
        'problemId': 'problem-1',
        'totalPredictions': 1,
        'choiceDistribution': {'improve': 1},
        'motivationDistribution': _motivationDistribution,
      }),
      throwsA(isA<ApiException>()),
    );
  });
}

const _choiceDistribution = <String, Object?>{
  'improve': 2,
  'stable': 1,
  'worsen': 0,
};

const _motivationDistribution = <String, Object?>{
  'visibleActions': 2,
  'recentDecline': 0,
  'seasonality': 1,
  'unmetPromises': 0,
  'personalExperience': 0,
};
