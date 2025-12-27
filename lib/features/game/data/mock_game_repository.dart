import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';
import 'package:fanta_comune/features/game/domain/turn_state.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

/// Implementazione mock in-memory del [GameRepository] per testare la UI senza backend.
class MockGameRepository implements GameRepository {
  /// Crea un repository mock con dati fittizi.
  MockGameRepository();

  static const _latency = Duration(milliseconds: 250);
  static const _currentUserId = 'user:self';
  final Turn _currentTurn = Turn(
    id: 'turn-2024-09',
    startAt: DateTime.now().subtract(const Duration(days: 5)),
    endAt: DateTime.now().add(const Duration(days: 2)),
    state: TurnState.open,
  );

  final List<Problem> _problems = [
    Problem(
      id: 'problem-1',
      key: ProblemKey.potholes,
      title: 'Buche in strada',
      zoneName: 'Centro',
      status: ProblemStatus.worsening,
      trendPercent: -18,
      updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    Problem(
      id: 'problem-2',
      key: ProblemKey.lighting,
      title: 'Illuminazione scarsa',
      zoneName: 'Quartiere Nord',
      status: ProblemStatus.stable,
      trendPercent: 2,
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Problem(
      id: 'problem-3',
      key: ProblemKey.cleanliness,
      title: 'Cassonetti pieni',
      zoneName: 'Zona Mercato',
      status: ProblemStatus.improving,
      trendPercent: 12,
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Problem(
      id: 'problem-4',
      key: ProblemKey.green,
      title: 'Aiuole trascurate',
      zoneName: 'Parco Sud',
      status: ProblemStatus.stable,
      trendPercent: -3,
      updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
    ),
    Problem(
      id: 'problem-5',
      key: ProblemKey.signage,
      title: 'Segnaletica scolorita',
      zoneName: 'Tangenziale',
      status: ProblemStatus.improving,
      trendPercent: 6,
      updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    Problem(
      id: 'problem-6',
      key: ProblemKey.waste,
      title: 'Rifiuti abbandonati',
      zoneName: 'Stazione',
      status: ProblemStatus.worsening,
      trendPercent: -10,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
  ];

  final Map<String, Prediction> _predictions = {
    'problem-2': Prediction(
      turnId: 'turn-2024-09',
      problemId: 'problem-2',
      choice: PredictionChoice.stable,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      motivations: const [],
    ),
    'problem-3': Prediction(
      turnId: 'turn-2024-09',
      problemId: 'problem-3',
      choice: PredictionChoice.improve,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      motivations: const [],
    ),
  };

  final Map<String, PredictionResult> _results = {};
  ReputationScore _reputation = const ReputationScore(
    totalPoints: 0,
    accuracy: 0,
    predictionsCount: 0,
  );

  final List<LeaderboardEntry> _leaderboardBase = List.generate(
    9,
    (index) => LeaderboardEntry(
      userId: 'user:${index + 1}',
      displayName: 'Cittadino ${index + 1}',
      points: 1200 - (index * 80),
      rank: index + 1,
    ),
  );

  Future<T> _withDelay<T>(T Function() body) async {
    await Future.delayed(_latency);
    return body();
  }

  @override
  String get currentUserId => _currentUserId;

  ProblemStatus _nextStatus(ProblemStatus status, bool resolved) {
    if (resolved) {
      return switch (status) {
        ProblemStatus.worsening => ProblemStatus.stable,
        ProblemStatus.stable => ProblemStatus.improving,
        ProblemStatus.improving => ProblemStatus.improving,
      };
    }
    return switch (status) {
      ProblemStatus.improving => ProblemStatus.stable,
      ProblemStatus.stable => ProblemStatus.worsening,
      ProblemStatus.worsening => ProblemStatus.worsening,
    };
  }

  int _trendForStatus(ProblemStatus status) {
    switch (status) {
      case ProblemStatus.improving:
        return 14;
      case ProblemStatus.stable:
        return 0;
      case ProblemStatus.worsening:
        return -16;
    }
  }

  PredictionResult _evaluatePrediction(ProblemStatus status, PredictionChoice choice) {
    switch (status) {
      case ProblemStatus.improving:
        return switch (choice) {
          PredictionChoice.improve => PredictionResult.correct,
          PredictionChoice.stable => PredictionResult.partial,
          PredictionChoice.worsen => PredictionResult.wrong,
        };
      case ProblemStatus.stable:
        if (choice == PredictionChoice.stable) {
          return PredictionResult.correct;
        }
        return PredictionResult.partial;
      case ProblemStatus.worsening:
        return switch (choice) {
          PredictionChoice.worsen => PredictionResult.correct,
          PredictionChoice.stable => PredictionResult.partial,
          PredictionChoice.improve => PredictionResult.wrong,
        };
    }
  }

  int _pointsForResult(PredictionResult result) {
    switch (result) {
      case PredictionResult.correct:
        return 10;
      case PredictionResult.partial:
        return 4;
      case PredictionResult.wrong:
      case PredictionResult.pending:
        return 0;
    }
  }

  ReputationScore _calculateReputation() {
    if (_results.isEmpty) {
      return const ReputationScore(
        totalPoints: 0,
        accuracy: 0,
        predictionsCount: 0,
      );
    }

    final totalPoints = _results.values.fold<int>(
      0,
      (sum, result) => sum + _pointsForResult(result),
    );
    final totalResolved = _results.length;
    final correctCount = _results.values.where((r) => r == PredictionResult.correct).length;
    final partialCount = _results.values.where((r) => r == PredictionResult.partial).length;
    final accuracyScore = (correctCount + (partialCount * 0.5)) / totalResolved;

    return ReputationScore(
      totalPoints: totalPoints,
      accuracy: accuracyScore.clamp(0, 1).toDouble(),
      predictionsCount: totalResolved,
    );
  }

  void _updateProblem(String problemId, Problem Function(Problem) updater) {
    final index = _problems.indexWhere((problem) => problem.id == problemId);
    if (index == -1) {
      return;
    }
    final updated = updater(_problems[index]);
    _problems[index] = updated;
  }

  @override
  Future<Turn> getCurrentTurn(String municipalityId) {
    return _withDelay(() => _currentTurn);
  }

  @override
  Future<List<Problem>> listProblems(String municipalityId) {
    return _withDelay(() => List<Problem>.unmodifiable(_problems));
  }

  @override
  Future<Map<String, Prediction>> getMyPredictions(String turnId) {
    return _withDelay(() => Map<String, Prediction>.unmodifiable(_predictions));
  }

  @override
  Future<void> upsertPrediction({
    required String turnId,
    required String problemId,
    required PredictionChoice choice,
    List<MotivationKey> motivations = const [],
  }) {
    return _withDelay(() {
      _predictions[problemId] = Prediction(
        turnId: turnId,
        problemId: problemId,
        choice: choice,
        createdAt: DateTime.now(),
        motivations: List<MotivationKey>.unmodifiable(motivations.take(2)),
      );
      _results.remove(problemId);
      _reputation = _calculateReputation();
    });
  }

  @override
  Future<void> updatePredictionMotivations({
    required String turnId,
    required String problemId,
    required List<MotivationKey> motivations,
  }) {
    return _withDelay(() {
      final existing = _predictions[problemId];
      if (existing == null) return;

      _predictions[problemId] = existing.copyWith(
        motivations: List<MotivationKey>.unmodifiable(motivations.take(2)),
      );
    });
  }

  @override
  Future<PredictionResult> resolvePrediction({
    required String problemId,
    required PredictionChoice choice,
  }) {
    return _withDelay(() {
      final problem = _problems.firstWhere((problem) => problem.id == problemId);
      final result = _evaluatePrediction(problem.status, choice);
      _results[problemId] = result;
      _reputation = _calculateReputation();
      return result;
    });
  }

  @override
  Future<void> tapSignal({
    required String problemId,
    required bool resolved,
  }) {
    return _withDelay(() {
      _updateProblem(
        problemId,
        (problem) {
          final nextStatus = _nextStatus(problem.status, resolved);
          return problem.copyWith(
            status: nextStatus,
            trendPercent: _trendForStatus(nextStatus),
            updatedAt: DateTime.now(),
          );
        },
      );
    });
  }

  @override
  Future<Problem> getProblemById(String problemId) {
    return _withDelay(() {
      return _problems.firstWhere((problem) => problem.id == problemId);
    });
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String municipalityId,
    String? leagueId,
  }) {
    return _withDelay(() {
      final selfEntry = LeaderboardEntry(
        userId: _currentUserId,
        displayName: 'Tu',
        points: 900 + _reputation.totalPoints,
        rank: 0,
      );
      final combined = <LeaderboardEntry>[
        ..._leaderboardBase,
        selfEntry,
      ];
      combined.sort((a, b) => b.points.compareTo(a.points));

      final ranked = <LeaderboardEntry>[];
      for (var i = 0; i < combined.length && i < 10; i++) {
        ranked.add(combined[i].copyWith(rank: i + 1));
      }

      return List<LeaderboardEntry>.unmodifiable(ranked);
    });
  }

  @override
  Future<Map<String, PredictionResult>> getPredictionResults(String turnId) {
    return _withDelay(() => Map<String, PredictionResult>.unmodifiable(_results));
  }

  @override
  Future<ReputationScore> getReputationScore(String turnId) {
    return _withDelay(() => _reputation);
  }
}
