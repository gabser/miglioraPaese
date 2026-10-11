import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/next_problems/data/api_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import '../../../helpers/memory_local_backend.dart';
import 'proposal_session_store_test.dart' as fixture;

Map<String, Object?> dto({String status = 'pending'}) => {
  'id': 'suggested-actual-id',
  'title': 'Alberi',
  'shortDescription': 'Serve ombra',
  'category': 'green',
  'createdAt': '2026-10-10T10:00:00Z',
  'status': status,
  'location': {'kind': 'municipality'},
  'votesUp': 0,
  'votesDown': 0,
  'myVote': 'none',
  'submittedByDisplayName': 'Cittadino',
  'promotionRule': {
    'threshold': 1,
    'scopeLabel': 'Bologna',
    'reason': 'Regola demo',
  },
};

void main() {
  test(
    'fixed key and persisted authoritative scope are reused for submit and lookup, not bootstrapped during recovery',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final requests = <http.Request>[];
      final transport = MockClient((req) async {
        requests.add(req);
        if (req.url.path.endsWith('/proposal-session')) {
          return http.Response(
            jsonEncode(fixture.response(bootstrap: req.method == 'POST')),
            200,
          );
        }
        expect(req.headers['Authorization'], 'Bearer ${fixture.token}');
        return http.Response(
          jsonEncode(
            dto(status: req.url.path.endsWith('/own') ? 'rejected' : 'pending'),
          ),
          200,
        );
      });
      final api = ApiClient(
        baseUrl: Uri.parse('http://localhost:8787/root'),
        client: transport,
      );
      final sessions = ProposalSessionStore(
        client: api,
        data: data,
        environment: 'api:test',
      );
      final repo = ApiNextProblemsRepository(
        client: api,
        userId: 'client-id',
        sessions: sessions,
      );
      final scope = await repo.prepareSubmissionScope();
      for (var retry = 0; retry < 2; retry++) {
        final result = await repo.submitWithIdempotencyKey(
          municipalityId: 'comune:Bologna',
          title: 'Alberi',
          description: 'Serve ombra',
          category: ProblemKey.green,
          idempotencyKey: 'persisted-intent-key',
          submissionScope: scope,
        );
        expect(result.id, 'suggested-actual-id');
      }
      final submits = requests
          .where(
            (r) => r.method == 'POST' && r.url.path.endsWith('/next-problems'),
          )
          .toList();
      expect(submits.map((r) => r.headers['Idempotency-Key']), [
        'persisted-intent-key',
        'persisted-intent-key',
      ]);
      expect(submits.map((r) => r.body).toSet(), hasLength(1));
      expect(
        jsonDecode(submits.first.body)['userId'],
        'session:${fixture.scope}',
      );
      expect(
        (await repo.lookupSubmission(
          municipalityId: 'bologna',
          idempotencyKey: 'persisted-intent-key',
          submissionScope: scope,
        )).id,
        'suggested-actual-id',
      );
      expect(
        requests.last.url.path,
        '/root/v1/municipalities/bologna/submissions/persisted-intent-key',
      );
      expect(
        (await repo.getOwnSuggestedProblem(
          municipalityId: 'bologna',
          problemId: 'suggested-actual-id',
          submissionScope: scope,
        )).status.name,
        'rejected',
      );
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/proposal-session'),
        ),
        hasLength(1),
      );
      final before = requests.length;
      await expectLater(
        repo.submitWithIdempotencyKey(
          municipalityId: 'bologna',
          title: 'Alberi',
          description: 'Serve ombra',
          category: ProblemKey.green,
          idempotencyKey: 'persisted-intent-key',
          submissionScope: 'another-scope',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(requests.length, before);
      data.dispose();
      transport.close();
    },
  );

  testWidgets(
    'real API providers revoke before preferences reset and retain token/preferences on failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final prefs = AppPrefs(preferences);
      final data = prefs.localData;
      await prefs.setMunicipalityId('comune:Bologna');
      final config = AppConfig.fromValues(nextProblemsDataSource: 'api');
      var failRevoke = true;
      final transport = MockClient((req) async {
        if (req.url.path.endsWith('/revoke')) {
          return http.Response(
            failRevoke ? '{"error":"unavailable"}' : '{"revoked":true}',
            failRevoke ? 503 : 200,
          );
        }
        return http.Response(
          jsonEncode(fixture.response(bootstrap: req.method == 'POST')),
          200,
        );
      });
      late BuildContext context;
      await tester.pumpWidget(
        AppDependencies(
          appPrefs: prefs,
          config: config,
          httpClient: transport,
          child: MaterialApp(
            home: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      final sessions = context.read<ProposalSessionStore?>()!;
      expect(
        context.read<NextProblemsRepository>(),
        isA<ApiNextProblemsRepository>(),
      );
      await sessions.active(allowCreate: true);
      await expectLater(prefs.clearAll(), throwsA(isA<ApiException>()));
      expect(prefs.sessionUnrecoverable, isFalse);
      await expectLater(
        prefs.clearUnrecoverableLocalData(),
        throwsA(isA<StateError>()),
      );
      expect(prefs.municipalityId, 'comune:Bologna');
      expect(
        (data.read('api-session:${ProposalScope.environmentFor(config)}')
            as Map)['token'],
        fixture.token,
      );
      await expectLater(
        sessions.active(allowCreate: true),
        throwsA(isA<LocalDataResetException>()),
      );
      failRevoke = false;
      await prefs.clearAll();
      expect(prefs.municipalityId, isNull);
      expect(
        data.read('api-session:${ProposalScope.environmentFor(config)}'),
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      expect(prefs.beforeClearAll, isNull);
      prefs.dispose();
      transport.close();
    },
  );

  test(
    'a response arriving after revocation cannot be returned as a successful submit',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final sending = Completer<void>();
      final response = Completer<http.Response>();
      final api = ApiClient(
        baseUrl: Uri.parse('http://localhost'),
        client: MockClient((req) async {
          if (req.url.path.endsWith('/revoke')) {
            return http.Response('{"revoked":true}', 200);
          }
          if (req.url.path.endsWith('/proposal-session')) {
            return http.Response(
              jsonEncode(fixture.response(bootstrap: req.method == 'POST')),
              200,
            );
          }
          sending.complete();
          return response.future;
        }),
      );
      final sessions = ProposalSessionStore(
        client: api,
        data: data,
        environment: 'api:test',
      );
      final repo = ApiNextProblemsRepository(
        client: api,
        userId: 'client-id',
        sessions: sessions,
      );
      final submit = repo.submitSuggestedProblem(
        municipalityId: 'bologna',
        title: 'Alberi',
        description: 'Serve ombra',
        category: ProblemKey.green,
      );
      final verify = expectLater(
        submit,
        throwsA(isA<LocalDataResetException>()),
      );
      await sending.future;
      await sessions.revokeBeforeReset();
      await data.reset();
      response.complete(http.Response(jsonEncode(dto()), 201));
      await verify;
      expect(data.read('api-session:api:test'), isNull);
      data.dispose();
    },
  );
}
