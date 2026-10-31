import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/civic_loop/domain/civic_loop_summary.dart';
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
import 'package:fanta_comune/features/game/domain/turn.dart';
import 'package:fanta_comune/features/game/domain/turn_state.dart';
import 'package:fanta_comune/features/leaderboard/domain/leaderboard_entry.dart';

class GameMapper {
  const GameMapper._();

  static MunicipalityActivationState activationFromResponse(Object? payload) {
    final json = _requireMap(payload, 'response');
    return _enumValue(MunicipalityActivationState.values, json, 'state');
  }

  static CivicLoopSummary civicSummaryFromResponse(Object? payload) {
    final json = _requireMap(payload, 'response');
    return CivicLoopSummary(
      municipalityName: _requireString(json, 'municipalityName'),
      proposedThemes: _requireInt(json, 'proposedThemes'),
      confirmedThemes: _requireInt(json, 'confirmedThemes'),
      cardsInTurn: _requireInt(json, 'cardsInTurn'),
      predictions: _requireInt(json, 'predictions'),
      outcomes: _requireInt(json, 'outcomes'),
      reputationPoints: _requireInt(json, 'reputationPoints'),
      topThemeTitle: _nullableString(json, 'topThemeTitle'),
    );
  }

  static Turn turnFromResponse(Object? payload) {
    final json = _requireMap(payload, 'response');
    return Turn(
      id: _requireString(json, 'id'),
      startAt: _requireDateTime(json, 'startAt'),
      endAt: _requireDateTime(json, 'endAt'),
      state: _enumValue(TurnState.values, json, 'state'),
    );
  }

  static List<Problem> problemsFromResponse(Object? payload) {
    return List<Problem>.unmodifiable(
      _items(payload).indexed.map((entry) {
        final json = _requireMap(entry.$2, 'items[${entry.$1}]');
        return Problem(
          id: _requireString(json, 'id'),
          key: _enumValue(ProblemKey.values, json, 'key'),
          title: _requireString(json, 'title'),
          zoneName: _nullableString(json, 'zoneName'),
          status: _enumValue(ProblemStatus.values, json, 'status'),
          trendPercent: _requireInt(json, 'trendPercent'),
          updatedAt: _requireDateTime(json, 'updatedAt'),
        );
      }),
    );
  }

  static Map<String, Prediction> predictionsFromResponse(Object? payload) {
    final predictions = <String, Prediction>{};
    for (final entry in _items(payload).indexed) {
      final json = _requireMap(entry.$2, 'items[${entry.$1}]');
      final problemId = _requireString(json, 'problemId');
      if (predictions.containsKey(problemId)) {
        throw ApiException.invalidPayload(
          'items contiene problemId duplicati.',
        );
      }
      predictions[problemId] = Prediction(
        turnId: _requireString(json, 'turnId'),
        problemId: problemId,
        choice: _enumValue(PredictionChoice.values, json, 'choice'),
        createdAt: _requireDateTime(json, 'createdAt'),
        motivations: _enumList(MotivationKey.values, json, 'motivations'),
        confidence: _nullableEnum(
          HypothesisConfidence.values,
          json,
          'confidence',
        ),
      );
    }
    return Map<String, Prediction>.unmodifiable(predictions);
  }

  static PredictionResult predictionResultFromResolution(Object? payload) {
    final json = _requireMap(payload, 'response');
    return _enumValue(PredictionResult.values, json, 'result');
  }

  static Map<String, PredictionResult> resultsFromResponse(Object? payload) {
    final results = <String, PredictionResult>{};
    for (final entry in _items(payload).indexed) {
      final json = _requireMap(entry.$2, 'items[${entry.$1}]');
      final problemId = _requireString(json, 'problemId');
      if (results.containsKey(problemId)) {
        throw ApiException.invalidPayload(
          'items contiene problemId duplicati.',
        );
      }
      results[problemId] = _enumValue(PredictionResult.values, json, 'result');
    }
    return Map<String, PredictionResult>.unmodifiable(results);
  }

  static ReputationScore reputationFromResponse(Object? payload) {
    return _reputationFromJson(_requireMap(payload, 'response'));
  }

  static List<ReputationScore> reputationHistoryFromResponse(Object? payload) {
    return List<ReputationScore>.unmodifiable(
      _items(payload).indexed.map(
        (entry) =>
            _reputationFromJson(_requireMap(entry.$2, 'items[${entry.$1}]')),
      ),
    );
  }

  static AggregatedInsight aggregatedInsightFromResponse(Object? payload) {
    final json = _requireMap(payload, 'response');
    return AggregatedInsight(
      problemId: _requireString(json, 'problemId'),
      totalPredictions: _requireInt(json, 'totalPredictions'),
      choiceDistribution: _enumIntMap(
        PredictionChoice.values,
        json,
        'choiceDistribution',
      ),
      motivationDistribution: _enumIntMap(
        MotivationKey.values,
        json,
        'motivationDistribution',
      ),
    );
  }

  static InsightHistory insightHistoryFromResponse(Object? payload) {
    final json = _requireMap(payload, 'response');
    final rawSnapshots = json['snapshots'];
    if (rawSnapshots is! List<dynamic>) {
      throw ApiException.invalidPayload('snapshots deve essere una lista.');
    }
    return InsightHistory(
      problemId: _requireString(json, 'problemId'),
      snapshots: List<InsightSnapshot>.unmodifiable(
        rawSnapshots.indexed.map((entry) {
          final snapshot = _requireMap(entry.$2, 'snapshots[${entry.$1}]');
          return InsightSnapshot(
            turnId: _requireString(snapshot, 'turnId'),
            at: _requireDateTime(snapshot, 'at'),
            totalPredictions: _requireInt(snapshot, 'totalPredictions'),
            choiceDistribution: _enumIntMap(
              PredictionChoice.values,
              snapshot,
              'choiceDistribution',
            ),
            motivationTop: _enumList(
              MotivationKey.values,
              snapshot,
              'motivationTop',
            ),
          );
        }),
      ),
    );
  }

  static List<CriticalInsight> criticalInsightsFromResponse(Object? payload) {
    return List<CriticalInsight>.unmodifiable(
      _items(payload).indexed.map((entry) {
        final json = _requireMap(entry.$2, 'items[${entry.$1}]');
        return CriticalInsight(
          headline: _requireString(json, 'headline'),
          supporting: _requireString(json, 'supporting'),
          note: _nullableString(json, 'note'),
        );
      }),
    );
  }

  static List<LeaderboardEntry> leaderboardFromResponse(Object? payload) {
    return List<LeaderboardEntry>.unmodifiable(
      _items(payload).indexed.map((entry) {
        final json = _requireMap(entry.$2, 'items[${entry.$1}]');
        return LeaderboardEntry(
          userId: _requireString(json, 'userId'),
          displayName: _requireString(json, 'displayName'),
          points: _requireInt(json, 'points'),
          rank: _requireInt(json, 'rank'),
        );
      }),
    );
  }

  static ReputationScore _reputationFromJson(Map<String, Object?> json) {
    return ReputationScore(
      totalPoints: _requireInt(json, 'totalPoints'),
      accuracy: _requireNumber(json, 'accuracy').toDouble(),
      predictionsCount: _requireInt(json, 'predictionsCount'),
    );
  }

  static List<dynamic> _items(Object? payload) {
    final root = _requireMap(payload, 'response');
    final items = root['items'];
    if (items is! List<dynamic>) {
      throw ApiException.invalidPayload('items deve essere una lista.');
    }
    return items;
  }

  static Map<String, Object?> _requireMap(Object? value, String field) {
    if (value is! Map<String, dynamic>) {
      throw ApiException.invalidPayload('$field deve essere un oggetto.');
    }
    return Map<String, Object?>.from(value);
  }

  static String _requireString(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! String || value.isEmpty) {
      throw ApiException.invalidPayload('$field deve essere una stringa.');
    }
    return value;
  }

  static String? _nullableString(Map<String, Object?> json, String field) {
    if (!json.containsKey(field)) {
      throw ApiException.invalidPayload('$field e\' obbligatorio.');
    }
    final value = json[field];
    if (value == null) return null;
    if (value is! String) {
      throw ApiException.invalidPayload('$field deve essere una stringa.');
    }
    return value;
  }

  static int _requireInt(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! int) {
      throw ApiException.invalidPayload('$field deve essere un intero.');
    }
    return value;
  }

  static num _requireNumber(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! num) {
      throw ApiException.invalidPayload('$field deve essere un numero.');
    }
    return value;
  }

  static DateTime _requireDateTime(Map<String, Object?> json, String field) {
    final value = DateTime.tryParse(_requireString(json, field));
    if (value == null) {
      throw ApiException.invalidPayload(
        '$field deve essere una data ISO 8601.',
      );
    }
    return value;
  }

  static T _enumValue<T extends Enum>(
    List<T> values,
    Map<String, Object?> json,
    String field,
  ) {
    return _enumFromRaw(values, json[field], field);
  }

  static T? _nullableEnum<T extends Enum>(
    List<T> values,
    Map<String, Object?> json,
    String field,
  ) {
    if (!json.containsKey(field)) {
      throw ApiException.invalidPayload('$field e\' obbligatorio.');
    }
    final value = json[field];
    return value == null ? null : _enumFromRaw(values, value, field);
  }

  static T _enumFromRaw<T extends Enum>(
    List<T> values,
    Object? raw,
    String field,
  ) {
    if (raw is String) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
    }
    throw ApiException.invalidPayload('$field contiene un valore sconosciuto.');
  }

  static List<T> _enumList<T extends Enum>(
    List<T> values,
    Map<String, Object?> json,
    String field,
  ) {
    final raw = json[field];
    if (raw is! List<dynamic>) {
      throw ApiException.invalidPayload('$field deve essere una lista.');
    }
    return List<T>.unmodifiable(
      raw.indexed.map(
        (entry) => _enumFromRaw(values, entry.$2, '$field[${entry.$1}]'),
      ),
    );
  }

  static Map<T, int> _enumIntMap<T extends Enum>(
    List<T> values,
    Map<String, Object?> json,
    String field,
  ) {
    final raw = _requireMap(json[field], field);
    if (raw.length != values.length ||
        raw.keys.any((key) => values.every((value) => value.name != key))) {
      throw ApiException.invalidPayload(
        '$field deve contenere tutte e sole le enum note.',
      );
    }
    return Map<T, int>.unmodifiable({
      for (final value in values) value: _requireInt(raw, value.name),
    });
  }
}
