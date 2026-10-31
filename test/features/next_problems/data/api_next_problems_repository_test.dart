import 'dart:convert';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';

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
    'reads exact municipality and opaque ID with place and no idempotency header',
    () async {
      late http.Request captured;
      const id = 'suggested/1?x#à';
      final repository = _repository((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            ..._payload(),
            'id': id,
            'location': {
              'kind': 'specific',
              'label': 'Via Milano',
              'civic': '12/A',
            },
          }),
          200,
        );
      });
      final problem = await repository.getSuggestedProblem(
        municipalityId: 'comune:Castel Bolognese',
        problemId: id,
      );
      expect(captured.method, 'GET');
      expect(captured.url.pathSegments, [
        'root',
        'v1',
        'municipalities',
        'castel-bolognese',
        'next-problems',
        id,
      ]);
      expect(captured.url.queryParameters, {'userId': 'user:test'});
      expect(captured.headers.containsKey('idempotency-key'), false);
      expect(problem.id, id);
      expect(
        problem.location,
        ProposalLocation.specific(label: 'Via Milano', civic: '12/A'),
      );
    },
  );

  test(
    'rejects a mismatched or nonpublic detail and malformed location',
    () async {
      for (final payload in [
        {..._payload(), 'id': 'other-id'},
        {..._payload(), 'status': 'rejected'},
        {
          ..._payload(),
          'location': {'kind': 'specific'},
        },
      ]) {
        final repository = _repository(
          (_) async => http.Response(jsonEncode(payload), 200),
        );
        await expectLater(
          repository.getSuggestedProblem(
            municipalityId: 'bologna',
            problemId: 'suggested-1',
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.kind,
              'kind',
              ApiExceptionKind.invalidPayload,
            ),
          ),
        );
      }
    },
  );

  test('keeps the uniform detail not-found response typed', () async {
    final repository = _repository(
      (_) async => http.Response(
        jsonEncode({
          'error': 'suggested_problem_not_found',
          'message': 'Suggested problem not found.',
        }),
        404,
      ),
    );
    await expectLater(
      repository.getSuggestedProblem(
        municipalityId: 'bologna',
        problemId: 'missing',
      ),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 404)
            .having((e) => e.code, 'code', 'suggested_problem_not_found'),
      ),
    );
  });

  test('invalid detail context never reaches the HTTP client', () async {
    var calls = 0;
    final repository = _repository((_) async {
      calls++;
      return http.Response(jsonEncode(_payload()), 200);
    });
    await expectLater(
      repository.getSuggestedProblem(municipalityId: 'bologna', problemId: ''),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_problem_id'),
      ),
    );
    await expectLater(
      repository.getSuggestedProblem(
        municipalityId: 'comune:Pincara',
        problemId: 'suggested-1',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'unsupported_municipality',
        ),
      ),
    );
    expect(calls, 0);
  });

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
        'userId': 'user:test',
      });
    },
  );

  test('submits a problem with transport enum names and user ID', () async {
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
      'userId': 'user:test',
    });
    expect(captured.headers['idempotency-key'], 'flutter-test-key');
  });

  test('normalizes Unicode text and transports a structured place', () async {
    late http.Request captured;
    final place = ProposalLocation.specific(label: 'Via Milano', civic: '12/A');
    final repository = _repository((request) async {
      captured = request;
      return http.Response(
        jsonEncode(_payload()..['location'] = place.toJson()),
        201,
      );
    });
    final title = List.filled(120, '😀').join();
    final description = List.filled(1000, '😀').join();
    final created = await repository.submitSuggestedProblem(
      municipalityId: 'bologna',
      title: '  $title  ',
      description: ' $description ',
      category: ProblemKey.green,
      location: place,
    );
    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(payload['title'], title);
    expect(payload['description'], description);
    expect(payload['location'], place.toJson());
    expect(created.location, place);
  });

  test(
    'invalid text is rejected before transport without truncation',
    () async {
      var calls = 0;
      final repository = _repository((request) async {
        calls++;
        return http.Response(jsonEncode(_payload()), 201);
      });
      await expectLater(
        repository.submitSuggestedProblem(
          municipalityId: 'bologna',
          title: List.filled(121, '😀').join(),
          description: 'Testo',
          category: ProblemKey.green,
        ),
        throwsFormatException,
      );
      expect(calls, 0);
    },
  );

  test('votes with an encoded problem path and user ID', () async {
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
    expect(jsonDecode(captured.body), {'vote': 'up', 'userId': 'user:test'});
    expect(captured.headers['idempotency-key'], 'flutter-test-key');
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
    userId: 'user:test',
    idempotencyKeyFactory: () => 'flutter-test-key',
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
