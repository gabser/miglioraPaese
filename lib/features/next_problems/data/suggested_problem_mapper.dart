import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/next_problems/domain/promotion_rule.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

class SuggestedProblemMapper {
  const SuggestedProblemMapper._();

  static List<SuggestedProblem> listFromResponse(Object? payload) {
    final root = _requireMap(payload, 'response');
    final items = root['items'];
    if (items is! List<dynamic>) {
      throw ApiException.invalidPayload('items deve essere una lista.');
    }
    return List<SuggestedProblem>.unmodifiable(
      items.indexed.map(
        (entry) => fromJson(_requireMap(entry.$2, 'items[${entry.$1}]')),
      ),
    );
  }

  static SuggestedProblem fromResponse(Object? payload) {
    return fromJson(_requireMap(payload, 'response'));
  }

  static SuggestedProblem fromJson(Map<String, Object?> json) {
    final promotionRule = _requireMap(json['promotionRule'], 'promotionRule');
    return SuggestedProblem(
      id: _requireString(json, 'id'),
      title: _requireString(json, 'title'),
      shortDescription: _requireString(json, 'shortDescription'),
      category: _enumValue(ProblemKey.values, json, 'category'),
      createdAt: _requireDateTime(json, 'createdAt'),
      status: _enumValue(SuggestedProblemStatus.values, json, 'status'),
      votesUp: _requireInt(json, 'votesUp'),
      votesDown: _requireInt(json, 'votesDown'),
      myVote: _enumValue(VoteChoice.values, json, 'myVote'),
      submittedByDisplayName: _requireString(json, 'submittedByDisplayName'),
      promotionRule: PromotionRule(
        threshold: _requireInt(promotionRule, 'threshold'),
        scopeLabel: _requireString(promotionRule, 'scopeLabel'),
        reason: _requireString(promotionRule, 'reason'),
      ),
    );
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

  static int _requireInt(Map<String, Object?> json, String field) {
    final value = json[field];
    if (value is! int) {
      throw ApiException.invalidPayload('$field deve essere un intero.');
    }
    return value;
  }

  static DateTime _requireDateTime(Map<String, Object?> json, String field) {
    final raw = _requireString(json, field);
    final value = DateTime.tryParse(raw);
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
    final raw = _requireString(json, field);
    for (final value in values) {
      if (value.name == raw) return value;
    }
    throw ApiException.invalidPayload(
      '$field contiene il valore sconosciuto "$raw".',
    );
  }
}
