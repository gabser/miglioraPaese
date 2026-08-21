import 'dart:math';

import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/civic_loop/domain/civic_loop_summary.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/domain/aggregated_insight.dart';
import 'package:fanta_comune/features/game/domain/critical_insight.dart';
import 'package:fanta_comune/features/game/domain/insight_history.dart';
import 'package:fanta_comune/features/game/domain/insight_snapshot.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:fanta_comune/features/game/domain/motivation_key.dart';
import 'package:fanta_comune/features/game/domain/prediction.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_result.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/domain/reputation_score.dart';
import 'package:fanta_comune/features/game/domain/reflection_question.dart';
import 'package:fanta_comune/features/game/domain/turn.dart';
import 'package:fanta_comune/features/game/domain/turn_state.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

/// Implementazione mock in-memory del [GameRepository] per testare la UI senza backend.
class MockGameRepository implements GameRepository {
  /// Crea un repository mock con dati fittizi.
  MockGameRepository({CivicLoopStore? civicLoopStore})
    : _civicLoopStore =
          civicLoopStore ?? CivicLoopStore(currentUserId: _currentUserId);

  static const _latency = Duration(milliseconds: 250);
  static const _currentUserId = 'user:self';
  final CivicLoopStore _civicLoopStore;
  final Turn _currentTurn = Turn(
    id: 'turn-2024-09',
    startAt: DateTime.now().subtract(const Duration(days: 5)),
    endAt: DateTime.now().add(const Duration(days: 2)),
    state: TurnState.open,
  );
  final Turn _activationTurn = Turn(
    id: 'turn-activation',
    startAt: DateTime.now(),
    endAt: DateTime.now().add(const Duration(days: 7)),
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

  final Map<String, Prediction> _predictions = {};

  final Map<String, PredictionResult> _results = {};
  ReputationScore _reputation = const ReputationScore(
    totalPoints: 0,
    accuracy: 0,
    predictionsCount: 0,
  );
  final Map<String, AggregatedInsight> _insightCache = {};
  final Map<String, InsightHistory> _insightHistoryCache = {};
  final Map<String, ReflectionQuestion> _reflectionQuestionCache = {};
  final Map<String, List<CriticalInsight>> _criticalInsightsCache = {};
  List<ReputationScore>? _reputationHistoryCache;

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

  PredictionResult _evaluatePrediction(
    ProblemStatus status,
    PredictionChoice choice,
  ) {
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
    final correctCount = _results.values
        .where((r) => r == PredictionResult.correct)
        .length;
    final partialCount = _results.values
        .where((r) => r == PredictionResult.partial)
        .length;
    final accuracyScore = (correctCount + (partialCount * 0.5)) / totalResolved;

    return ReputationScore(
      totalPoints: totalPoints,
      accuracy: accuracyScore.clamp(0, 1).toDouble(),
      predictionsCount: totalResolved,
    );
  }

  Map<PredictionChoice, int> _weightedChoiceDistribution(
    int total,
    Map<PredictionChoice, double> weights,
    Random random,
  ) {
    final distribution = <PredictionChoice, int>{};
    var allocated = 0;

    for (final entry in weights.entries) {
      final value = (total * entry.value).floor();
      distribution[entry.key] = value;
      allocated += value;
    }

    var remainder = total - allocated;
    final orderedChoices = weights.keys.toList()
      ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
    var index = orderedChoices.isEmpty
        ? 0
        : random.nextInt(orderedChoices.length);
    while (remainder > 0) {
      final choice = orderedChoices[index % orderedChoices.length];
      distribution[choice] = (distribution[choice] ?? 0) + 1;
      remainder--;
      index++;
    }

    return distribution;
  }

  ReflectionQuestion _buildReflectionQuestion(String problemId) {
    final random = Random(problemId.hashCode);
    final templates =
        <({String prompt, List<String> options, String followUp})>[
          (
            prompt: 'Quando pensi a questo problema, cosa pesa di piu\'?',
            options: [
              'Esperienze recenti',
              'Segnali contrastanti',
              'Poca visibilita\' dei cambiamenti',
            ],
            followUp: 'Ok, segnato. Non e\' un test.',
          ),
          (
            prompt: 'Quale segnale ti farebbe cambiare idea piu\' in fretta?',
            options: [
              'Nuove segnalazioni in zona',
              'Interventi visibili',
              'Dati o report pubblici',
            ],
            followUp: 'Grazie, ci aiuta a capire il tuo punto di vista.',
          ),
          (
            prompt:
                'Se dovessi spiegare la tua previsione, da cosa partiresti?',
            options: [
              'Da una storia personale',
              'Da un confronto con altri quartieri',
              'Da un trend che noto spesso',
            ],
            followUp: 'Perfetto, qui non c\'e\' una risposta giusta.',
          ),
        ];
    final template = templates[random.nextInt(templates.length)];
    return ReflectionQuestion(
      id: 'rq_${problemId}_${random.nextInt(9999)}',
      prompt: template.prompt,
      options: List<String>.unmodifiable(template.options),
      followUpCopy: template.followUp,
    );
  }

  Map<HypothesisConfidence, int> _mockConfidenceDistribution(String problemId) {
    final random = Random(problemId.hashCode);
    final total = 24 + random.nextInt(30);
    final weights = <HypothesisConfidence, double>{
      HypothesisConfidence.gutFeeling: 0.35 + random.nextDouble() * 0.2,
      HypothesisConfidence.considered: 0.25 + random.nextDouble() * 0.2,
      HypothesisConfidence.convinced: 0.2 + random.nextDouble() * 0.2,
    };

    final distribution = <HypothesisConfidence, int>{};
    var allocated = 0;
    for (final entry in weights.entries) {
      final value = (total * entry.value).floor();
      distribution[entry.key] = value;
      allocated += value;
    }
    var remainder = total - allocated;
    final ordered = weights.keys.toList()
      ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
    var index = ordered.isEmpty ? 0 : random.nextInt(ordered.length);
    while (remainder > 0) {
      final key = ordered[index % ordered.length];
      distribution[key] = (distribution[key] ?? 0) + 1;
      remainder--;
      index++;
    }
    return distribution;
  }

  Map<int, int> _mockReflectionDistribution(String problemId) {
    final random = Random(problemId.hashCode + 42);
    final total = 18 + random.nextInt(24);
    final weights = <int, double>{
      0: 0.34 + random.nextDouble() * 0.15,
      1: 0.28 + random.nextDouble() * 0.15,
      2: 0.24 + random.nextDouble() * 0.15,
    };
    final distribution = <int, int>{};
    var allocated = 0;
    for (final entry in weights.entries) {
      final value = (total * entry.value).floor();
      distribution[entry.key] = value;
      allocated += value;
    }
    var remainder = total - allocated;
    final ordered = weights.keys.toList()
      ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
    var index = ordered.isEmpty ? 0 : random.nextInt(ordered.length);
    while (remainder > 0) {
      final key = ordered[index % ordered.length];
      distribution[key] = (distribution[key] ?? 0) + 1;
      remainder--;
      index++;
    }
    return distribution;
  }

  String _choiceLabel(PredictionChoice choice) {
    switch (choice) {
      case PredictionChoice.improve:
        return 'migliora';
      case PredictionChoice.stable:
        return 'stabile';
      case PredictionChoice.worsen:
        return 'peggiora';
    }
  }

  List<CriticalInsight> _buildCriticalInsights({
    required String problemId,
    required PredictionChoice? userChoice,
    required HypothesisConfidence? userConfidence,
    required int? userReflectionIndex,
  }) {
    final insight = _buildAggregatedInsight(problemId);
    final sortedChoices = insight.choiceDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final primary = sortedChoices.isNotEmpty ? sortedChoices.first : null;
    final secondary = sortedChoices.length > 1 ? sortedChoices[1] : null;
    final diff = primary != null && secondary != null
        ? (primary.value - secondary.value).abs()
        : 0;

    final insights = <CriticalInsight>[];

    if (primary != null && secondary != null && diff < 4) {
      insights.add(
        CriticalInsight(
          headline: 'Qui le opinioni erano divise.',
          supporting:
              'Molti hanno visto "${_choiceLabel(primary.key)}", ma una fetta ha detto "${_choiceLabel(secondary.key)}".',
          note: 'Opinioni vicine.',
        ),
      );
    } else if (primary != null) {
      insights.add(
        CriticalInsight(
          headline: 'Letture diverse, stesso problema.',
          supporting:
              'La maggioranza ha scelto "${_choiceLabel(primary.key)}", ma restano sfumature.',
        ),
      );
    }

    if (userConfidence == HypothesisConfidence.convinced) {
      insights.add(
        const CriticalInsight(
          headline: 'La sicurezza non sempre coincide con l\'esito.',
          supporting:
              'Interessante: convinzione e accuratezza non vanno sempre insieme.',
          note: 'Niente giudizi.',
        ),
      );
    } else {
      final confidenceDist = _mockConfidenceDistribution(problemId);
      final topConfidence = confidenceDist.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      if (topConfidence == HypothesisConfidence.gutFeeling) {
        insights.add(
          const CriticalInsight(
            headline: 'Molti hanno scelto a pelle.',
            supporting: 'Quando i segnali sono misti, il colpo d\'occhio pesa.',
          ),
        );
      } else {
        insights.add(
          const CriticalInsight(
            headline: 'Qui si e\' ragionato un po\'.',
            supporting:
                'Le persone hanno cercato coerenza nei segnali disponibili.',
          ),
        );
      }
    }

    final reflectionDist = _mockReflectionDistribution(problemId);
    final topReflection = reflectionDist.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
    final reflectionIndex = userReflectionIndex ?? topReflection;
    if (reflectionIndex == 0) {
      insights.add(
        const CriticalInsight(
          headline: 'Chi pensa alle persone vede le cose diversamente.',
          supporting: 'L\'impatto quotidiano cambia la lettura del problema.',
        ),
      );
    } else if (reflectionIndex == 1) {
      insights.add(
        const CriticalInsight(
          headline: 'C\'e\' chi guarda il potenziale.',
          supporting: 'Il focus e\' su segnali di miglioramento possibili.',
        ),
      );
    } else {
      insights.add(
        const CriticalInsight(
          headline: 'C\'e\' chi guarda tempi e processo.',
          supporting: 'La lettura passa da priorita\' e coordinamento.',
        ),
      );
    }

    return insights.take(3).toList(growable: false);
  }

  Map<MotivationKey, int> _weightedMotivationDistribution(
    int total,
    Map<MotivationKey, double> weights,
  ) {
    final distribution = <MotivationKey, int>{};
    var allocated = 0;

    for (final entry in weights.entries) {
      final value = (total * entry.value).floor();
      distribution[entry.key] = value;
      allocated += value;
    }

    var remainder = total - allocated;
    final orderedKeys = weights.keys.toList()
      ..sort((a, b) => weights[b]!.compareTo(weights[a]!));
    var index = 0;
    while (remainder > 0) {
      final key = orderedKeys[index % orderedKeys.length];
      distribution[key] = (distribution[key] ?? 0) + 1;
      remainder--;
      index++;
    }

    return distribution;
  }

  List<InsightSnapshot> _buildSnapshotsForProblem(Problem problem) {
    final baseInsight = _syntheticInsight(problem.id);
    final random = Random(problem.id.hashCode ^ 73);
    final snapshots = <InsightSnapshot>[];
    var totalPredictions = max(baseInsight.totalPredictions - 4, 6);
    var weightShift = 0.06;

    final choiceWeights = switch (problem.status) {
      ProblemStatus.improving => {
        PredictionChoice.improve: 0.52,
        PredictionChoice.stable: 0.32,
        PredictionChoice.worsen: 0.16,
      },
      ProblemStatus.stable => {
        PredictionChoice.improve: 0.36,
        PredictionChoice.stable: 0.4,
        PredictionChoice.worsen: 0.24,
      },
      ProblemStatus.worsening => {
        PredictionChoice.improve: 0.2,
        PredictionChoice.stable: 0.32,
        PredictionChoice.worsen: 0.48,
      },
    };

    final motivationWeights = switch (problem.status) {
      ProblemStatus.improving => {
        MotivationKey.visibleActions: 0.36,
        MotivationKey.seasonality: 0.22,
        MotivationKey.personalExperience: 0.18,
        MotivationKey.unmetPromises: 0.12,
        MotivationKey.recentDecline: 0.12,
      },
      ProblemStatus.stable => {
        MotivationKey.seasonality: 0.26,
        MotivationKey.personalExperience: 0.2,
        MotivationKey.visibleActions: 0.18,
        MotivationKey.unmetPromises: 0.18,
        MotivationKey.recentDecline: 0.18,
      },
      ProblemStatus.worsening => {
        MotivationKey.recentDecline: 0.34,
        MotivationKey.unmetPromises: 0.22,
        MotivationKey.personalExperience: 0.18,
        MotivationKey.seasonality: 0.14,
        MotivationKey.visibleActions: 0.12,
      },
    };

    for (var i = 0; i < 6; i++) {
      totalPredictions += 3 + random.nextInt(6);
      final variation = (random.nextDouble() * weightShift) - (weightShift / 2);
      final normalizedWeights = <PredictionChoice, double>{};
      for (final entry in choiceWeights.entries) {
        final noise = (random.nextDouble() * 0.04) - 0.02;
        final trendFactor =
            entry.key == PredictionChoice.improve &&
                problem.status == ProblemStatus.improving
            ? variation.abs()
            : variation;
        normalizedWeights[entry.key] = (entry.value + trendFactor + noise)
            .clamp(0.14, 0.7);
      }
      final totalWeight = normalizedWeights.values.fold<double>(
        0,
        (sum, value) => sum + value,
      );
      final weights = normalizedWeights.map(
        (key, value) => MapEntry(key, value / totalWeight),
      );
      final choiceDistribution = _weightedChoiceDistribution(
        totalPredictions,
        weights,
        Random(problem.id.hashCode ^ i),
      );
      final motivationDistribution = _weightedMotivationDistribution(
        max(totalPredictions - 2, 6),
        motivationWeights,
      );
      final orderedMotivations = motivationDistribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topMotivations = orderedMotivations
          .take(2)
          .map((entry) => entry.key)
          .toList(growable: false);

      snapshots.add(
        InsightSnapshot(
          turnId: 'turn-${i + 1}',
          at: DateTime.now().subtract(Duration(days: (5 - i))),
          totalPredictions: totalPredictions,
          choiceDistribution: Map.unmodifiable(choiceDistribution),
          motivationTop: List<MotivationKey>.unmodifiable(topMotivations),
        ),
      );

      weightShift = (weightShift * 0.75).clamp(0.02, 0.08);
    }

    return snapshots;
  }

  InsightHistory _buildInsightHistory(String problemId) {
    final problem = _problemById(problemId);
    final snapshots = _buildSnapshotsForProblem(problem);
    return InsightHistory(
      problemId: problemId,
      snapshots: List<InsightSnapshot>.unmodifiable(snapshots),
    );
  }

  List<ReputationScore> _buildReputationHistory(String municipalityId) {
    final random = Random(municipalityId.hashCode ^ 99);
    final baselinePoints = 540 + random.nextInt(120);
    final baselineAccuracy = 0.48 + (random.nextDouble() * 0.18);
    final history = <ReputationScore>[];
    var accumulatedPoints = baselinePoints;
    var accuracy = baselineAccuracy;
    var predictions = 8 + random.nextInt(4);

    for (var i = 0; i < 7; i++) {
      accumulatedPoints += 12 + random.nextInt(24);
      final drift = (random.nextDouble() * 0.12) - 0.06;
      accuracy = (accuracy + drift).clamp(0.4, 0.95);
      predictions += random.nextInt(3);

      history.add(
        ReputationScore(
          totalPoints: accumulatedPoints,
          accuracy: accuracy,
          predictionsCount: predictions,
        ),
      );
    }

    if (_reputation.totalPoints > 0 || _reputation.predictionsCount > 0) {
      history[history.length - 1] = _reputation;
    }

    return List<ReputationScore>.unmodifiable(history);
  }

  bool _hasActiveTurn(String municipalityId) {
    return MunicipalityCatalog.isActiveMunicipality(municipalityId) ||
        _civicLoopStore.hasPromotedCards(municipalityId);
  }

  List<Problem> _turnProblems(String municipalityId) {
    if (!_hasActiveTurn(municipalityId)) {
      return const <Problem>[];
    }
    final promoted = _civicLoopStore.promotedProblems(municipalityId);
    final seeded = MunicipalityCatalog.isActiveMunicipality(municipalityId)
        ? _problems
        : const <Problem>[];
    return List<Problem>.unmodifiable([...promoted, ...seeded]);
  }

  Problem _problemById(String problemId) {
    for (final problem in _problems) {
      if (problem.id == problemId) {
        return problem;
      }
    }
    final promoted = _civicLoopStore.problemByCardId(problemId);
    if (promoted != null) {
      return promoted;
    }
    throw StateError('Problem not found.');
  }

  AggregatedInsight _syntheticInsight(String problemId) {
    final problem = _problemById(problemId);
    final random = Random(problemId.hashCode ^ 42);
    final baseTotal = 6 + random.nextInt(12);
    final choiceWeights = switch (problem.status) {
      ProblemStatus.improving => {
        PredictionChoice.improve: 0.52,
        PredictionChoice.stable: 0.32,
        PredictionChoice.worsen: 0.16,
      },
      ProblemStatus.stable => {
        PredictionChoice.improve: 0.36,
        PredictionChoice.stable: 0.4,
        PredictionChoice.worsen: 0.24,
      },
      ProblemStatus.worsening => {
        PredictionChoice.improve: 0.2,
        PredictionChoice.stable: 0.32,
        PredictionChoice.worsen: 0.48,
      },
    };

    final motivationWeights = switch (problem.status) {
      ProblemStatus.improving => {
        MotivationKey.visibleActions: 0.38,
        MotivationKey.seasonality: 0.22,
        MotivationKey.personalExperience: 0.16,
        MotivationKey.unmetPromises: 0.12,
        MotivationKey.recentDecline: 0.12,
      },
      ProblemStatus.stable => {
        MotivationKey.seasonality: 0.24,
        MotivationKey.personalExperience: 0.2,
        MotivationKey.visibleActions: 0.18,
        MotivationKey.unmetPromises: 0.18,
        MotivationKey.recentDecline: 0.2,
      },
      ProblemStatus.worsening => {
        MotivationKey.recentDecline: 0.34,
        MotivationKey.unmetPromises: 0.22,
        MotivationKey.personalExperience: 0.16,
        MotivationKey.seasonality: 0.14,
        MotivationKey.visibleActions: 0.14,
      },
    };

    final choiceDistribution = _weightedChoiceDistribution(
      baseTotal,
      choiceWeights,
      random,
    );
    final motivationDistribution = _weightedMotivationDistribution(
      max(baseTotal - 1, 6),
      motivationWeights,
    );

    return AggregatedInsight(
      problemId: problemId,
      totalPredictions: baseTotal,
      choiceDistribution: Map.unmodifiable(choiceDistribution),
      motivationDistribution: Map.unmodifiable(motivationDistribution),
    );
  }

  AggregatedInsight _buildAggregatedInsight(String problemId) {
    final baseInsight = _syntheticInsight(problemId);
    final choiceDistribution = Map<PredictionChoice, int>.from(
      baseInsight.choiceDistribution,
    );
    final motivationDistribution = Map<MotivationKey, int>.from(
      baseInsight.motivationDistribution,
    );

    final existing = _predictions[problemId];
    if (existing != null) {
      choiceDistribution[existing.choice] =
          (choiceDistribution[existing.choice] ?? 0) + 1;
      for (final motivation in existing.motivations) {
        motivationDistribution[motivation] =
            (motivationDistribution[motivation] ?? 0) + 1;
      }
    }

    final totalPredictions = choiceDistribution.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );

    return AggregatedInsight(
      problemId: problemId,
      totalPredictions: totalPredictions,
      choiceDistribution: Map.unmodifiable(choiceDistribution),
      motivationDistribution: Map.unmodifiable(motivationDistribution),
    );
  }

  void _invalidateInsight(String problemId) {
    _insightCache.remove(problemId);
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
    return _withDelay(() {
      if (_hasActiveTurn(municipalityId)) {
        return _currentTurn;
      }
      return _activationTurn;
    });
  }

  @override
  Future<MunicipalityActivationState> getMunicipalityActivationState(
    String municipalityId,
  ) {
    return _withDelay(() {
      if (_hasActiveTurn(municipalityId)) {
        return MunicipalityActivationState.active;
      }
      return MunicipalityCatalog.activationStateFor(municipalityId);
    });
  }

  @override
  Future<CivicLoopSummary> getCivicLoopSummary(String municipalityId) {
    return _withDelay(() {
      return CivicLoopSummary(
        municipalityName: MunicipalityCatalog.displayNameFromId(municipalityId),
        proposedThemes: _civicLoopStore.proposedCount(municipalityId),
        confirmedThemes: _civicLoopStore.confirmedThemes(municipalityId).length,
        cardsInTurn: _civicLoopStore.promotedProblems(municipalityId).length,
        predictions: _predictions.length,
        outcomes: _results.length,
        reputationPoints: _reputation.totalPoints,
        topThemeTitle: _civicLoopStore.topThemeTitle(municipalityId),
      );
    });
  }

  @override
  Future<List<Problem>> listProblems(String municipalityId) {
    return _withDelay(() => _turnProblems(municipalityId));
  }

  @override
  Future<Map<String, Prediction>> getMyPredictions(String turnId) {
    return _withDelay(() {
      if (turnId == _activationTurn.id) {
        return const <String, Prediction>{};
      }
      return Map<String, Prediction>.unmodifiable(_predictions);
    });
  }

  @override
  Future<void> upsertPrediction({
    required String turnId,
    required String problemId,
    required PredictionChoice choice,
    List<MotivationKey> motivations = const [],
    HypothesisConfidence? confidence,
  }) {
    return _withDelay(() {
      final existing = _predictions[problemId];
      if (existing != null && existing.choice != choice) {
        throw StateError('Prediction already cast for this turn.');
      }
      _predictions[problemId] = Prediction(
        turnId: turnId,
        problemId: problemId,
        choice: choice,
        createdAt: DateTime.now(),
        motivations: List<MotivationKey>.unmodifiable(motivations.take(2)),
        confidence: confidence,
      );
      _results.remove(problemId);
      _reputation = _calculateReputation();
      _reputationHistoryCache = null;
      _invalidateInsight(problemId);
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
        confidence: existing.confidence,
      );
      _invalidateInsight(problemId);
    });
  }

  @override
  Future<PredictionResult> resolvePrediction({
    required String problemId,
    required PredictionChoice choice,
  }) {
    return _withDelay(() {
      final problem = _problemById(problemId);
      final result = _evaluatePrediction(problem.status, choice);
      _results[problemId] = result;
      _reputation = _calculateReputation();
      _reputationHistoryCache = null;
      return result;
    });
  }

  @override
  Future<void> tapSignal({required String problemId, required bool resolved}) {
    return _withDelay(() {
      _updateProblem(problemId, (problem) {
        final nextStatus = _nextStatus(problem.status, resolved);
        return problem.copyWith(
          status: nextStatus,
          trendPercent: _trendForStatus(nextStatus),
          updatedAt: DateTime.now(),
        );
      });
    });
  }

  @override
  Future<AggregatedInsight> getAggregatedInsight(String problemId) {
    return _withDelay(() {
      final cached = _insightCache[problemId];
      if (cached != null) return cached;

      final insight = _buildAggregatedInsight(problemId);
      _insightCache[problemId] = insight;
      return insight;
    });
  }

  @override
  Future<Problem> getProblemById(String problemId) {
    return _withDelay(() {
      return _problemById(problemId);
    });
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({
    required String municipalityId,
    String? leagueId,
  }) {
    return _withDelay(() {
      if (!_hasActiveTurn(municipalityId)) {
        return const <LeaderboardEntry>[];
      }
      final selfEntry = LeaderboardEntry(
        userId: _currentUserId,
        displayName: 'Tu',
        points: 900 + _reputation.totalPoints,
        rank: 0,
      );
      final combined = <LeaderboardEntry>[..._leaderboardBase, selfEntry];
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
    return _withDelay(
      () => Map<String, PredictionResult>.unmodifiable(_results),
    );
  }

  @override
  Future<ReputationScore> getReputationScore(String turnId) {
    return _withDelay(() {
      if (turnId == _activationTurn.id) {
        return const ReputationScore(
          totalPoints: 0,
          accuracy: 0,
          predictionsCount: 0,
        );
      }
      return _reputation;
    });
  }

  @override
  Future<ReflectionQuestion> getReflectionQuestion(String problemId) {
    return _withDelay(() {
      final cached = _reflectionQuestionCache[problemId];
      if (cached != null) return cached;

      final question = _buildReflectionQuestion(problemId);
      _reflectionQuestionCache[problemId] = question;
      return question;
    });
  }

  @override
  Future<List<CriticalInsight>> getCriticalInsights({
    required String problemId,
    required PredictionChoice? userChoice,
    required HypothesisConfidence? userConfidence,
    required int? userReflectionIndex,
  }) {
    return _withDelay(() {
      final cached = _criticalInsightsCache[problemId];
      if (cached != null) return cached;

      final insights = _buildCriticalInsights(
        problemId: problemId,
        userChoice: userChoice,
        userConfidence: userConfidence,
        userReflectionIndex: userReflectionIndex,
      );
      _criticalInsightsCache[problemId] = insights;
      return insights;
    });
  }

  @override
  Future<InsightHistory> getInsightHistory(String problemId) {
    return _withDelay(() {
      final cached = _insightHistoryCache[problemId];
      if (cached != null) return cached;

      final history = _buildInsightHistory(problemId);
      _insightHistoryCache[problemId] = history;
      return history;
    });
  }

  @override
  Future<List<ReputationScore>> getReputationHistory({
    required String municipalityId,
  }) {
    return _withDelay(() {
      if (!_hasActiveTurn(municipalityId)) {
        return const <ReputationScore>[];
      }
      final cached = _reputationHistoryCache;
      if (cached != null) return cached;

      final history = _buildReputationHistory(municipalityId);
      _reputationHistoryCache = history;
      return history;
    });
  }
}
