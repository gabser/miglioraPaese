import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/prediction.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';
import 'package:fanta_comune/features/game/domain/turn_state.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

/// Implementazione mock in-memory del [GameRepository] per testare la UI senza backend.
class MockGameRepository implements GameRepository {
  /// Crea un repository mock con dati fittizi.
  MockGameRepository();

  static const _latency = Duration(milliseconds: 250);
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
    ),
    'problem-3': Prediction(
      turnId: 'turn-2024-09',
      problemId: 'problem-3',
      choice: PredictionChoice.improve,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  };

  final List<LeaderboardEntry> _leaderboard = List.generate(
    10,
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
  }) {
    return _withDelay(() {
      _predictions[problemId] = Prediction(
        turnId: turnId,
        problemId: problemId,
        choice: choice,
        createdAt: DateTime.now(),
      );
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
    return _withDelay(() => List<LeaderboardEntry>.unmodifiable(_leaderboard));
  }
}
