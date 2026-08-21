import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/next_problems/data/api_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';

void main() {
  test(
    'lists problems with canonical municipality, query and status',
    () async {
      late http.Request captured;
      final repository = _repository((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'items': [_payload()],
          }),
          200,
        );
      });

      final items = await repository.listNextProblems(
        municipalityId: 'comune:Bologna',
        query: '  parco nord  ',
        status: SuggestedProblemStatus.pending,
      );

      expect(items, hasLength(1));
      expect(captured.url.pathSegments, [
        'root',
        'v1',
        'municipalities',
        'bologna',
        'next-problems',
      ]);
      expect(captured.url.queryParameters, {
        'query': 'parco nord',
        'status': 'pending',
      });
    },
  );

  test('submits a problem with transport enum names', () async {
    late http.Request captured;
    final repository = _repository((request) async {
      captured = request;
      return http.Response(jsonEncode(_payload()), 201);
    });

    await repository.submitSuggestedProblem(
      municipalityId: 'castel-bolognese',
      title: 'Lampioni spenti',
      description: 'Via Roma resta buia.',
      category: ProblemKey.lighting,
    );

    expect(captured.method, 'POST');
    expect(jsonDecode(captured.body), {
      'title': 'Lampioni spenti',
      'description': 'Via Roma resta buia.',
      'category': 'lighting',
    });
  });

  test('votes with an encoded problem path', () async {
    late http.Request captured;
    final repository = _repository((request) async {
      captured = request;
      return http.Response(jsonEncode(_payload()..['myVote'] = 'up'), 200);
    });

    final updated = await repository.voteSuggestedProblem(
      municipalityId: 'comune:Bologna',
      problemId: 'problem/with space',
      vote: VoteChoice.up,
    );

    expect(captured.url.pathSegments, [
      'root',
      'v1',
      'municipalities',
      'bologna',
      'next-problems',
      'problem/with space',
      'votes',
    ]);
    expect(jsonDecode(captured.body), {'vote': 'up'});
    expect(updated.myVote, VoteChoice.up);
  });

  test('rejects unsupported municipalities before sending a request', () {
    final repository = _repository(
      (_) async => fail('The HTTP client must not be called.'),
    );

    expect(
      () => repository.listNextProblems(municipalityId: 'comune:Milano'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'unsupported_municipality',
        ),
      ),
    );
  });

  test('rejects VoteChoice.none because it is not a request enum', () {
    final repository = _repository(
      (_) async => fail('The HTTP client must not be called.'),
    );

    expect(
      () => repository.voteSuggestedProblem(
        municipalityId: 'comune:Bologna',
        problemId: 'suggested-1',
        vote: VoteChoice.none,
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.code,
          'code',
          'invalid_vote',
        ),
      ),
    );
  });
}

ApiNextProblemsRepository _repository(
  Future<http.Response> Function(http.Request) handler,
) {
  return ApiNextProblemsRepository(
    client: ApiClient(
      baseUrl: Uri.parse('https://example.test/root'),
      client: MockClient(handler),
    ),
  );
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
