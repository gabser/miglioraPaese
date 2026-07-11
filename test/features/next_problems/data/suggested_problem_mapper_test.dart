import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/next_problems/data/suggested_problem_mapper.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

void main() {
  test('maps a complete suggested problem payload', () {
    final problem = SuggestedProblemMapper.fromResponse(_payload());

    expect(problem.id, 'suggested-1');
    expect(problem.category, ProblemKey.lighting);
    expect(problem.status, SuggestedProblemStatus.pending);
    expect(problem.myVote, VoteChoice.none);
    expect(problem.createdAt, DateTime.parse('2026-07-04T08:00:00.000Z'));
    expect(problem.promotionRule.threshold, 1);
  });

  test('maps an items response into an immutable list', () {
    final problems = SuggestedProblemMapper.listFromResponse({
      'items': [_payload()],
    });

    expect(problems, hasLength(1));
    expect(() => problems.add(problems.single), throwsUnsupportedError);
  });

  test('rejects missing required fields', () {
    final payload = _payload()..remove('shortDescription');

    expect(
      () => SuggestedProblemMapper.fromResponse(payload),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'invalid_payload',
        ),
      ),
    );
  });

  test('rejects unknown enum values', () {
    final payload = _payload()..['status'] = 'archived';

    expect(
      () => SuggestedProblemMapper.fromResponse(payload),
      throwsA(isA<ApiException>()),
    );
  });

  test('rejects invalid timestamps and numeric coercion', () {
    expect(
      () => SuggestedProblemMapper.fromResponse(
        _payload()..['createdAt'] = 'not-a-date',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => SuggestedProblemMapper.fromResponse(_payload()..['votesUp'] = 1.0),
      throwsA(isA<ApiException>()),
    );
  });
}

Map<String, Object?> _payload() {
  return <String, Object?>{
    'id': 'suggested-1',
    'title': 'Illuminazione al parco',
    'shortDescription': 'Percorsi poco leggibili la sera.',
    'category': 'lighting',
    'createdAt': '2026-07-04T08:00:00.000Z',
    'status': 'pending',
    'votesUp': 0,
    'votesDown': 0,
    'myVote': 'none',
    'submittedByDisplayName': 'Tu',
    'promotionRule': <String, Object?>{
      'threshold': 1,
      'scopeLabel': 'Castel Bolognese · illuminazione',
      'reason': 'Una approvazione netta promuove il tema.',
    },
  };
}
