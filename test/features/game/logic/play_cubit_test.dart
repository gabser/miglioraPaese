import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/civic_loop/domain/civic_loop_summary.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/critical_insight.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/insight_snapshot.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/reflection_question.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';
import 'package:fanta_comune/features/game/domain/turn_state.dart';
import 'package:fanta_comune/features/game/logic/play_cubit.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

import '../../../helpers/test_app.dart';

void main() {
  test('load hydrates predictions, outcomes and retention signals', () async {
    final repository = _FakeGameRepository()
      ..predictions['problem-1'] = _prediction(
        choice: PredictionChoice.improve,
        confidence: HypothesisConfidence.considered,
      )
      ..results['problem-1'] = PredictionResult.correct;
    final cubit = PlayCubit(repository: repository, prefs: await _prefs());
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.currentTurn, _turn);
    expect(cubit.state.problems, [_problem]);
    expect(cubit.state.myPredictions, {'problem-1': PredictionChoice.improve});
    expect(cubit.state.confidences, {
      'problem-1': HypothesisConfidence.considered,
    });
    expect(cubit.state.results, {'problem-1': PredictionResult.correct});
    expect(cubit.state.insights['problem-1']?.totalPredictions, 3);
    expect(cubit.state.reflectionQuestions, contains('problem-1'));
    expect(cubit.state.reputation.totalPoints, 10);
    expect(cubit.state.hasPendingInsights, isTrue);
    expect(cubit.state.hasUnresolvedTurn, isFalse);
    expect(cubit.state.error, isNull);
  });

  test('prediction is optimistic, locked and enriched with metadata', () async {
    final repository = _FakeGameRepository();
    final cubit = PlayCubit(repository: repository, prefs: await _prefs());
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.selectPrediction(
      problemId: 'problem-1',
      choice: PredictionChoice.stable,
    );

    expect(cubit.state.myPredictions['problem-1'], PredictionChoice.stable);
    expect(cubit.state.hasUnresolvedTurn, isTrue);
    expect(cubit.state.civicSummary?.predictions, 1);
    expect(repository.upsertCalls, 1);

    await cubit.selectPrediction(
      problemId: 'problem-1',
      choice: PredictionChoice.worsen,
    );
    expect(repository.upsertCalls, 1);
    expect(cubit.state.error, contains('gia\' stata giocata'));

    await cubit.setMotivations(
      problemId: 'problem-1',
      motivations: const [
        MotivationKey.visibleActions,
        MotivationKey.seasonality,
        MotivationKey.personalExperience,
      ],
    );
    await cubit.setConfidence(
      problemId: 'problem-1',
      confidence: HypothesisConfidence.convinced,
    );

    expect(cubit.state.motivations['problem-1'], [
      MotivationKey.visibleActions,
      MotivationKey.seasonality,
    ]);
    expect(
      cubit.state.confidences['problem-1'],
      HypothesisConfidence.convinced,
    );
    expect(repository.motivationUpdateCalls, 1);
    expect(repository.upsertCalls, 2);
    expect(cubit.state.error, isNull);
  });

  test(
    'resolveTurn refreshes reputation and lazy insight projections',
    () async {
      final repository = _FakeGameRepository();
      final prefs = await _prefs();
      final cubit = PlayCubit(repository: repository, prefs: prefs);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.selectPrediction(
        problemId: 'problem-1',
        choice: PredictionChoice.improve,
      );
      await cubit.loadReputationHistory();

      await cubit.resolveTurn();

      expect(cubit.state.results['problem-1'], PredictionResult.correct);
      expect(cubit.state.reputation.totalPoints, 10);
      expect(cubit.state.reputationHistory.single.totalPoints, 10);
      expect(cubit.state.insights, contains('problem-1'));
      expect(cubit.state.hasPendingInsights, isTrue);
      expect(cubit.state.hasUnresolvedTurn, isFalse);
      expect(repository.resolveCalls, 1);

      await cubit.loadProblemHistory('problem-1');
      await cubit.loadProblemHistory('problem-1');
      await cubit.loadCriticalInsights('problem-1');
      await cubit.loadCriticalInsights('problem-1');

      expect(cubit.state.insightHistories, contains('problem-1'));
      expect(cubit.state.criticalInsights, contains('problem-1'));
      expect(repository.insightHistoryCalls, 1);
      expect(repository.criticalInsightCalls, 1);

      await cubit.markRetentionSeen();
      expect(cubit.state.hasPendingInsights, isFalse);
      expect(prefs.getLastSeenTurnId(), 'turn-1');
      expect(prefs.getInsightSignatures(), contains('problem-1'));
    },
  );

  test('load and lazy projection failures leave recoverable state', () async {
    final loadFailure = _FakeGameRepository()..failLoad = true;
    final loadCubit = PlayCubit(repository: loadFailure, prefs: await _prefs());
    addTearDown(loadCubit.close);

    await loadCubit.load();

    expect(loadCubit.state.isLoading, isFalse);
    expect(loadCubit.state.error, contains('turn unavailable'));

    final historyFailure = _FakeGameRepository()..failInsightHistory = true;
    final historyCubit = PlayCubit(
      repository: historyFailure,
      prefs: await _prefs(),
    );
    addTearDown(historyCubit.close);
    await historyCubit.load();

    await historyCubit.loadProblemHistory('problem-1');

    expect(historyCubit.state.loadingInsightHistories, isEmpty);
    expect(historyCubit.state.insightHistories, isEmpty);
    expect(historyCubit.state.error, contains('history unavailable'));
  });
}

Future<AppPrefs> _prefs() {
  return createTestPrefs({
    'municipality_id': 'comune:Bologna',
    'user_id': 'user:test',
  });
}

Prediction _prediction({
  required PredictionChoice choice,
  HypothesisConfidence? confidence,
  List<MotivationKey> motivations = const [],
}) {
  return Prediction(
    turnId: _turn.id,
    problemId: _problem.id,
    choice: choice,
    createdAt: DateTime.utc(2026, 8, 21, 8),
    motivations: motivations,
    confidence: confidence,
  );
}

final _turn = Turn(
  id: 'turn-1',
  startAt: DateTime.utc(2026, 8, 20),
  endAt: DateTime.utc(2026, 8, 27),
  state: TurnState.open,
);

final _problem = Problem(
  id: 'problem-1',
  key: ProblemKey.green,
  title: 'Verde pubblico',
  zoneName: 'Centro',
  status: ProblemStatus.improving,
  trendPercent: 8,
  updatedAt: DateTime.utc(2026, 8, 21, 8),
);

class _FakeGameRepository implements GameRepository {
  final Map<String, Prediction> predictions = {};
  final Map<String, PredictionResult> results = {};
  bool failLoad = false;
  bool failInsightHistory = false;
  int upsertCalls = 0;
  int motivationUpdateCalls = 0;
  int resolveCalls = 0;
  int insightHistoryCalls = 0;
  int criticalInsightCalls = 0;

  @override
  String get currentUserId => 'user:test';

  @override
  Future<Turn> getCurrentTurn(String municipalityId) async {
    if (failLoad) throw StateError('turn unavailable');
    return _turn;
  }

  @override
  Future<MunicipalityActivationState> getMunicipalityActivationState(
    String municipalityId,
  ) async {
    return MunicipalityActivationState.active;
  }

  @override
  Future<CivicLoopSummary> getCivicLoopSummary(String municipalityId) async {
    return CivicLoopSummary(
      municipalityName: 'Bologna',
      proposedThemes: 2,
      confirmedThemes: 1,
      cardsInTurn: 1,
      predictions: predictions.length,
      outcomes: results.length,
      reputationPoints: _reputation.totalPoints,
      topThemeTitle: 'Verde pubblico',
    );
  }

  @override
  Future<List<Problem>> listProblems(String municipalityId) async {
    return [_problem];
  }

  @override
  Future<Map<String, Prediction>> getMyPredictions(String turnId) async {
    return Map.unmodifiable(predictions);
  }

  @override
  Future<void> upsertPrediction({
    required String turnId,
    required String problemId,
    required PredictionChoice choice,
    List<MotivationKey> motivations = const [],
    HypothesisConfidence? confidence,
  }) async {
    upsertCalls += 1;
    final existing = predictions[problemId];
    predictions[problemId] = Prediction(
      turnId: turnId,
      problemId: problemId,
      choice: choice,
      createdAt: existing?.createdAt ?? DateTime.utc(2026, 8, 21, 8),
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
    motivationUpdateCalls += 1;
    final existing = predictions[problemId];
    if (existing == null) return;
    predictions[problemId] = existing.copyWith(motivations: motivations);
  }

  @override
  Future<ReflectionQuestion> getReflectionQuestion(String problemId) async {
    return const ReflectionQuestion(
      id: 'reflection-1',
      prompt: 'Cosa osservi?',
      options: ['A', 'B', 'C'],
      followUpCopy: 'Grazie.',
    );
  }

  @override
  Future<PredictionResult> resolvePrediction({
    required String problemId,
    required PredictionChoice choice,
  }) async {
    resolveCalls += 1;
    final result = switch (choice) {
      PredictionChoice.improve => PredictionResult.correct,
      PredictionChoice.stable => PredictionResult.partial,
      PredictionChoice.worsen => PredictionResult.wrong,
    };
    results[problemId] = result;
    return result;
  }

  @override
  Future<void> tapSignal({
    required String problemId,
    required bool resolved,
  }) async {}

  @override
  Future<AggregatedInsight> getAggregatedInsight(String problemId) async {
    return AggregatedInsight(
      problemId: problemId,
      totalPredictions: 3,
      choiceDistribution: const {
        PredictionChoice.improve: 2,
        PredictionChoice.stable: 1,
        PredictionChoice.worsen: 0,
      },
      motivationDistribution: const {
        MotivationKey.visibleActions: 2,
        MotivationKey.recentDecline: 0,
        MotivationKey.seasonality: 1,
        MotivationKey.unmetPromises: 0,
        MotivationKey.personalExperience: 0,
      },
    );
  }

  @override
  Future<Problem> getProblemById(String problemId) async => _problem;

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String municipalityId,
    String? leagueId,
  }) async {
    return const [
      LeaderboardEntry(
        userId: 'user:test',
        displayName: 'Tu',
        points: 10,
        rank: 1,
      ),
    ];
  }

  @override
  Future<Map<String, PredictionResult>> getPredictionResults(
    String turnId,
  ) async {
    return Map.unmodifiable(results);
  }

  ReputationScore get _reputation {
    final values = results.values;
    final points = values.fold<int>(0, (total, result) {
      return total +
          switch (result) {
            PredictionResult.correct => 10,
            PredictionResult.partial => 4,
            PredictionResult.wrong || PredictionResult.pending => 0,
          };
    });
    final accuracyUnits = values.fold<double>(0, (total, result) {
      return total +
          switch (result) {
            PredictionResult.correct => 1,
            PredictionResult.partial => 0.5,
            PredictionResult.wrong || PredictionResult.pending => 0,
          };
    });
    return ReputationScore(
      totalPoints: points,
      accuracy: values.isEmpty ? 0 : accuracyUnits / values.length,
      predictionsCount: values.length,
    );
  }

  @override
  Future<ReputationScore> getReputationScore(String turnId) async {
    return _reputation;
  }

  @override
  Future<InsightHistory> getInsightHistory(String problemId) async {
    insightHistoryCalls += 1;
    if (failInsightHistory) throw StateError('history unavailable');
    return InsightHistory(
      problemId: problemId,
      snapshots: [
        InsightSnapshot(
          turnId: _turn.id,
          at: DateTime.utc(2026, 8, 21, 9),
          totalPredictions: 3,
          choiceDistribution: const {
            PredictionChoice.improve: 2,
            PredictionChoice.stable: 1,
            PredictionChoice.worsen: 0,
          },
          motivationTop: const [MotivationKey.visibleActions],
        ),
      ],
    );
  }

  @override
  Future<List<ReputationScore>> getReputationHistory({
    required String municipalityId,
  }) async {
    return [_reputation];
  }

  @override
  Future<List<CriticalInsight>> getCriticalInsights({
    required String problemId,
    required PredictionChoice? userChoice,
    required HypothesisConfidence? userConfidence,
    required int? userReflectionIndex,
  }) async {
    criticalInsightCalls += 1;
    return const [
      CriticalInsight(
        headline: 'Percezione prevalente',
        supporting: 'Due persone su tre vedono un miglioramento.',
      ),
    ];
  }
}
