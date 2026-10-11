import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import '../../../helpers/memory_local_backend.dart';

const token = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const scope = '12345678-1234-4234-8234-123456789abc';
Map<String, Object?> response({bool bootstrap = false}) => {
  if (bootstrap) 'token': token,
  'submissionScope': scope,
  'capabilities': {
    for (final name in [
      'proposalLocation',
      'publicDetail',
      'privateSubmissionLookup',
      'scopedIdempotency',
      'revocation',
      'sessionRequiredForRecovery',
    ])
      name: true,
  },
};
ApiClient client(FutureOr<http.Response> Function(http.Request) send) =>
    ApiClient(
      baseUrl: Uri.parse('http://localhost:8787/api-root'),
      client: MockClient((request) async => await send(request)),
    );

void main() {
  test(
    'explicit lost-scope abandonment preserves active session and forgets only unusable reference',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      var lost = false, bootstrapCount = 0;
      final api = client((req) {
        if (req.method == 'POST') bootstrapCount++;
        if (lost && req.method == 'GET')
          return http.Response('{"error":"proposal_session_revoked"}', 401);
        return http.Response(
          jsonEncode(response(bootstrap: req.method == 'POST')),
          200,
        );
      });
      final sessions = ProposalSessionStore(
        client: api,
        data: data,
        environment: 'api:abandon',
      );
      await sessions.active(allowCreate: true);
      await sessions.abandonLostScope(scope);
      expect((data.read('api-session:api:abandon') as Map)['token'], token);
      expect(bootstrapCount, 1);
      lost = true;
      await sessions.abandonLostScope(scope);
      expect(data.read('api-session:api:abandon'), isNull);
      expect(bootstrapCount, 1);
      await expectLater(
        sessions.active(expectedScope: scope),
        throwsA(isA<ApiException>()),
      );
      expect(bootstrapCount, 1);
      lost = false;
      await sessions.active(allowCreate: true);
      expect(bootstrapCount, 2);
      data.dispose();
    },
  );
  test(
    'corrupt token cannot be silently replaced; explicit abandonment does not claim remote revocation',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      var requests = 0;
      final sessions = ProposalSessionStore(
        client: client((req) {
          requests++;
          return http.Response(
            jsonEncode(response(bootstrap: req.method == 'POST')),
            200,
          );
        }),
        data: data,
        environment: 'api:corrupt',
      );
      await data.mutate(
        'api-session:api:corrupt',
        (_) => const LocalDataMutation({
          'token': 'unreadable',
          'submissionScope': scope,
        }, null),
      );
      await expectLater(
        sessions.active(allowCreate: true),
        throwsA(isA<LocalDataCorruptException>()),
      );
      expect(requests, 0);
      await sessions.abandonLostScope(scope);
      expect(data.read('api-session:api:corrupt'), isNull);
      expect(requests, 0);
      await sessions.active(allowCreate: true);
      expect(requests, 1);
      data.dispose();
    },
  );

  test(
    'persists bootstrap before granting lease, then verifies the same scope after recreation',
    () async {
      final backend = MemoryLocalBackend();
      var data = LocalDataStore(backend: backend);
      final calls = <http.Request>[];
      final api = client((req) {
        calls.add(req);
        if (req.method == 'GET')
          expect(req.headers['Authorization'], 'Bearer $token');
        return http.Response(
          jsonEncode(response(bootstrap: req.method == 'POST')),
          200,
        );
      });
      var sessions = ProposalSessionStore(
        client: api,
        data: data,
        environment: 'api:A',
      );
      final lease = await sessions.active(allowCreate: true);
      expect(lease.submissionScope, scope);
      expect(backend.writeCalls, 1);
      expect(calls.single.url.path, '/api-root/v1/proposal-session');
      data.dispose();
      data = LocalDataStore(backend: backend);
      sessions = ProposalSessionStore(
        client: api,
        data: data,
        environment: 'api:A',
      );
      final restored = await sessions.active(expectedScope: scope);
      expect(restored.token, token);
      expect(calls.map((r) => r.method), ['POST', 'GET']);
      data.dispose();
    },
  );

  test(
    'missing recovery scope never bootstraps, including another API environment',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      var calls = 0;
      final api = client((_) {
        calls++;
        return http.Response(jsonEncode(response(bootstrap: true)), 201);
      });
      final sessions = ProposalSessionStore(
        client: api,
        data: data,
        environment: 'api:A',
      );
      await expectLater(
        sessions.active(allowCreate: true, expectedScope: scope),
        throwsA(isA<ApiException>()),
      );
      expect(calls, 0);
      await sessions.active(allowCreate: true);
      final other = ProposalSessionStore(
        client: api,
        data: data,
        environment: 'api:B',
      );
      await expectLater(other.active(), throwsA(isA<ApiException>()));
      expect(calls, 1);
      data.dispose();
    },
  );

  test(
    'expired persisted session fails without creating a replacement',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      await data.mutate<void>(
        'api-session:api:A',
        (_) => const LocalDataMutation({
          'token': token,
          'submissionScope': scope,
        }, null),
      );
      final calls = <http.Request>[];
      final sessions = ProposalSessionStore(
        client: client((req) {
          calls.add(req);
          return http.Response(
            jsonEncode({
              'error': 'proposal_session_revoked',
              'message': 'Revoked',
            }),
            401,
          );
        }),
        data: data,
        environment: 'api:A',
      );
      await expectLater(
        sessions.active(allowCreate: true),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(calls.single.method, 'GET');
      data.dispose();
    },
  );

  test(
    'capability failure and failed persistence never grant a lease',
    () async {
      for (final missingCapability in [true, false]) {
        final backend = MemoryLocalBackend();
        if (!missingCapability) backend.onWrite = (_, __) async => false;
        final data = LocalDataStore(backend: backend);
        var revoked = 0;
        final sessions = ProposalSessionStore(
          client: client((req) {
            if (req.url.path.endsWith('/revoke')) {
              revoked++;
              return http.Response('{"revoked":true}', 200);
            }
            final payload = response(bootstrap: true);
            if (missingCapability)
              (payload['capabilities'] as Map)['scopedIdempotency'] = false;
            return http.Response(jsonEncode(payload), 201);
          }),
          data: data,
          environment: 'api:A',
        );
        await expectLater(
          sessions.active(allowCreate: true),
          throwsA(
            missingCapability
                ? isA<ApiException>()
                : isA<LocalDataWriteException>(),
          ),
        );
        expect(data.read('api-session:api:A'), isNull);
        expect(revoked, 1);
        data.dispose();
      }
    },
  );

  test(
    'two concurrent new submissions share one persisted bootstrap',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final completing = Completer<http.Response>();
      var calls = 0;
      final sessions = ProposalSessionStore(
        client: client((_) {
          calls++;
          return completing.future;
        }),
        data: data,
        environment: 'api:A',
      );
      final first = sessions.active(allowCreate: true);
      final second = sessions.active(allowCreate: true);
      completing.complete(
        http.Response(jsonEncode(response(bootstrap: true)), 201),
      );
      final results = await Future.wait([first, second]);
      expect(results.map((r) => r.submissionScope), [scope, scope]);
      expect(calls, 1);
      data.dispose();
    },
  );

  test(
    'late bootstrap after reset is revoked and cannot repopulate storage',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final completing = Completer<http.Response>();
      var revocations = 0;
      final sessions = ProposalSessionStore(
        client: client((req) {
          if (req.url.path.endsWith('/revoke')) {
            revocations++;
            return http.Response('{"revoked":true}', 200);
          }
          return completing.future;
        }),
        data: data,
        environment: 'api:A',
      );
      final pending = sessions.active(allowCreate: true);
      final check = expectLater(
        pending,
        throwsA(isA<LocalDataResetException>()),
      );
      await data.reset();
      completing.complete(
        http.Response(jsonEncode(response(bootstrap: true)), 201),
      );
      await check;
      expect(data.read('api-session:api:A'), isNull);
      expect(revocations, 1);
      data.dispose();
    },
  );

  test(
    'failed revocation retains token and blocks operations until successful retry and local reset',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      var fail = true;
      final sessions = ProposalSessionStore(
        client: client((req) {
          if (req.url.path.endsWith('/revoke')) {
            return http.Response(
              fail ? '{"error":"unavailable"}' : '{"revoked":true}',
              fail ? 503 : 200,
            );
          }
          return http.Response(
            jsonEncode(response(bootstrap: req.method == 'POST')),
            200,
          );
        }),
        data: data,
        environment: 'api:A',
      );
      final lease = await sessions.active(allowCreate: true);
      await expectLater(
        sessions.revokeBeforeReset(),
        throwsA(isA<ApiException>()),
      );
      expect((data.read('api-session:api:A') as Map)['token'], token);
      await expectLater(
        sessions.active(allowCreate: true),
        throwsA(isA<LocalDataResetException>()),
      );
      fail = false;
      await sessions.revokeBeforeReset();
      expect(
        () => sessions.checkLease(lease),
        throwsA(isA<LocalDataResetException>()),
      );
      await data.reset();
      final renewed = await sessions.active(allowCreate: true);
      expect(renewed.epoch, isNot(lease.epoch));
      data.dispose();
    },
  );
}
