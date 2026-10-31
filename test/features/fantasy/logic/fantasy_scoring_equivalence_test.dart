import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/fantasy_scoring.json').readAsStringSync())
          as List;
  for (final fixture in fixtures) {
    final input = fixture['input'] as Map;
    final expected = fixture['expected'] as Map;
    test('shared Node/Dart scoring: $input', () {
      final score = scoreFantasyOutcome(
        cardId: 'fixture',
        observed: CivicTrend.values.byName(input['observed'] as String),
        prediction: input['prediction'] == null
            ? null
            : CivicTrend.values.byName(input['prediction'] as String),
        reflection: input['reflection'] as bool,
        captain: input['captain'] as bool,
      );
      expect(score.observationPoints, expected['observationPoints']);
      expect(score.predictionPoints, expected['predictionPoints']);
      expect(score.reflectionPoints, expected['reflectionPoints']);
      expect(score.captainMultiplier, expected['captainMultiplier']);
      expect(score.frozenTotal, expected['frozenTotal']);
      expect(score.total, expected['total']);
      expect(score.reflectionBonus, expected['reflectionBonus']);
    });
  }
}
