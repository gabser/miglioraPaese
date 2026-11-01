import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/api_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import '../../../helpers/memory_local_backend.dart';
import '../../../support/fantasy_backend.dart';

class _LostReplyClient extends http.BaseClient {
  final CookieClient cookies = CookieClient();
  bool failReply = true;
  bool malformed = false;
  int posts = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    expect(request.headers.containsKey('Authorization'), isFalse);
    final response = await cookies.send(request);
    if (request.method == 'POST' &&
        request.url.path.endsWith('/next-problems')) {
      posts++;
      final body = jsonDecode((request as http.Request).body) as Map;
      expect(body.containsKey('userId'), isFalse);
      expect(body['idempotencyKey'], 'persisted-recovery-key');
      expect(body['expectedSubmissionScope'], isNotEmpty);
      if (failReply) {
        failReply = false;
        await response.stream.drain<void>();
        if (malformed)
          return http.StreamedResponse(
            Stream.value(utf8.encode('{"id":"incomplete"}')),
            201,
          );
        throw http.ClientException('reply lost after committed proposal');
      }
    }
    return response;
  }

  @override
  void close() => cookies.close();
}

void main() {
  for (final malformed in [false, true]) {
    test(
      'SQLite commit with ${malformed ? 'malformed201' : 'lost reply'} refresh restart lookup preserves one immutable receipt',
      () async {
        final backend = BackendFixture();
        await backend.start();
        final transport = _LostReplyClient()..malformed = malformed;
        final localBackend = MemoryLocalBackend();
        LocalDataStore data = LocalDataStore(backend: localBackend);
        final config = AppConfig.fromValues(
          nextProblemsDataSource: 'api',
          apiBaseUrl: backend.url,
        );
        ApiClient api() =>
            ApiClient(baseUrl: Uri.parse(backend.url), client: transport);
        ProposalSubmissionCoordinator coordinator() =>
            ProposalSubmissionCoordinator(
              store: ProposalSubmissionStore(data),
              drafts: ProposalDraftStore(data),
              gateway: ApiNextProblemsRepository(client: api(), data: data),
              isMock: false,
              keyFactory: () => 'persisted-recovery-key',
            );
        var controller = coordinator();
        try {
          final scope = ProposalScope.fromConfig(
            municipalityId: 'tuglie',
            config: config,
            namespace: data.namespace,
          );
          final result = await controller.start(
            scope: scope,
            draftRevision: 0,
            title: 'Alberi in via Roma',
            description: 'Serve ombra vicino al passaggio.',
            category: ProblemKey.green,
            location: ProposalLocation.specific(
              coordinates: ProposalCoordinates(
                latitude: 40.0736,
                longitude: 18.0986,
              ),
            ),
          );
          expect(result.status, SubmissionStatus.outcomeUnknown);
          expect(transport.posts, 1);
          final initial =
              await api().getJson(
                    ['v1', 'municipalities', 'tuglie', 'next-problems'],
                    queryParameters: {'own': 'true'},
                  )
                  as Map;
          expect(initial['items'], hasLength(1));
          final id = (initial['items'] as List).single['id'];
          controller.dispose();
          data.dispose();
          await backend.command('restart');
          data = LocalDataStore(backend: localBackend);
          controller = coordinator();
          expect(
            controller.current(scope).status,
            SubmissionStatus.outcomeUnknown,
          );
          final recovered = await controller.reconcile(scope);
          expect(recovered.status, SubmissionStatus.succeeded);
          expect(recovered.intent!.receipt!.id, id);
          final receipt = recovered.intent!.receipt!;
          expect(receipt.location!.label, isNull);
          expect(
            receipt.location!.coordinates,
            ProposalCoordinates(latitude: 40.0736, longitude: 18.0986),
          );
          expect(transport.posts, 1);
          final lookup =
              await api().getJson([
                    'v1',
                    'municipalities',
                    'tuglie',
                    'next-problem-submissions',
                    'persisted-recovery-key',
                  ])
                  as Map;
          expect((lookup['receipt'] as Map)['id'], id);
          final own =
              await api().getJson(
                    ['v1', 'municipalities', 'tuglie', 'next-problems'],
                    queryParameters: {'own': 'true'},
                  )
                  as Map;
          expect(own['items'], hasLength(1));
          expect(
            controller.savedReceipt(scope).intent!.receipt!.createdAt,
            receipt.createdAt,
          );
        } finally {
          controller.dispose();
          data.dispose();
          transport.close();
          await backend.stop();
        }
      },
    );
  }
}
