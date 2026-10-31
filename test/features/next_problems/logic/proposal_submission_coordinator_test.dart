import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/next_problems/data/api_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_gateway.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_draft.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:fanta_comune/features/next_problems/domain/promotion_rule.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import '../../../helpers/memory_local_backend.dart';
import '../data/proposal_session_store_test.dart' as fixture;

SuggestedProblem accepted(ProposalSubmissionIntent intent, {String? title}) =>
    SuggestedProblem(
      id: 'actual-server-id',
      title: title ?? intent.title,
      shortDescription: intent.description,
      category: intent.category,
      location: intent.location,
      createdAt: DateTime.utc(2026, 10, 10),
      status: SuggestedProblemStatus.pending,
      votesUp: 0,
      votesDown: 0,
      myVote: VoteChoice.none,
      submittedByDisplayName: 'Cittadino',
      promotionRule: const PromotionRule(
        threshold: 1,
        scopeLabel: 'Comune',
        reason: 'Prototipo',
      ),
    );

class Gateway implements ProposalSubmissionGateway {
  String serverScope = 'scope-original';
  int prepares = 0, submissions = 0, lookups = 0;
  final sent = <ProposalSubmissionIntent>[];
  final committed = <String, SuggestedProblem>{};
  Future<SuggestedProblem> Function(ProposalSubmissionIntent)? onSubmit;
  Object? lookupError;
  @override
  Future<String> prepareSubmissionScope({String? expectedScope}) async {
    prepares++;
    if (expectedScope != null && expectedScope != serverScope)
      throw ApiException.configuration(
        code: 'proposal_scope_changed',
        message: 'Scope cambiato',
      );
    return serverScope;
  }

  @override
  Future<SuggestedProblem> submitIntent(ProposalSubmissionIntent intent) async {
    await prepareSubmissionScope(expectedScope: intent.submissionScope);
    submissions++;
    sent.add(intent);
    if (onSubmit != null) return onSubmit!(intent);
    return committed.putIfAbsent(intent.idempotencyKey, () => accepted(intent));
  }

  @override
  Future<SuggestedProblem> lookupIntent(ProposalSubmissionIntent intent) async {
    await prepareSubmissionScope(expectedScope: intent.submissionScope);
    lookups++;
    if (lookupError != null) throw lookupError!;
    return committed[intent.idempotencyKey] ??
        (throw const ApiException(
          kind: ApiExceptionKind.response,
          statusCode: 404,
          code: 'submission_not_found',
          message: 'Assente',
        ));
  }
}

class Harness {
  Harness({
    MemoryLocalBackend? backend,
    ProposalSubmissionGateway? gateway,
    bool mock = false,
  }) : backend = backend ?? MemoryLocalBackend(),
       gateway = gateway ?? Gateway() {
    data = LocalDataStore(backend: this.backend);
    store = ProposalSubmissionStore(data);
    drafts = ProposalDraftStore(data);
    coordinator = create(mock: mock);
  }
  final MemoryLocalBackend backend;
  final ProposalSubmissionGateway gateway;
  late LocalDataStore data;
  late ProposalSubmissionStore store;
  late ProposalDraftStore drafts;
  late ProposalSubmissionCoordinator coordinator;
  int sequence = 0;
  ProposalScope scope([
    String municipality = 'pincara',
    String environment = 'mock:test',
  ]) => ProposalScope(
    municipalityId: municipality,
    environment: environment,
    namespace: data.namespace,
  );
  ProposalSubmissionCoordinator create({bool mock = false}) =>
      ProposalSubmissionCoordinator(
        store: store,
        drafts: drafts,
        gateway: gateway,
        isMock: mock,
        clock: () => DateTime.utc(2026, 10, 10, 10),
        keyFactory: () => 'intent-key-${++sequence}',
      );
  Future<SubmissionView> start({ProposalScope? scope, int revision = 0}) =>
      coordinator.start(
        scope: scope ?? this.scope(),
        draftRevision: revision,
        title: '  Alberi  ',
        description: ' Serve ombra ',
        category: ProblemKey.green,
        location: ProposalLocation.specific(label: 'Via Milano', civic: '12/A'),
      );
  void dispose() {
    coordinator.dispose();
    data.dispose();
  }
}

void main() {
  test(
    '422 and 429 preserve intent without recovery POST and explain server policy',
    () async {
      for (final status in [422, 429]) {
        final gateway = Gateway()
          ..onSubmit = (_) async => throw ApiException(
            kind: ApiExceptionKind.response,
            code: status == 422
                ? 'content_rejected'
                : 'submission_rate_limited',
            message: 'private server text',
            statusCode: status,
            retryAfterSeconds: status == 429 ? 61 : null,
          );
        final h = Harness(gateway: gateway);
        addTearDown(h.dispose);
        final result = await h.start();
        expect(result.status, SubmissionStatus.rejected);
        expect(
          result.message,
          contains(status == 422 ? 'Rivedi il testo' : '61 secondi'),
        );
        expect(result.message, isNot(contains('private server text')));
        expect(h.store.history(h.scope()).single.title, 'Alberi');
        expect(gateway.submissions, 1);
        expect(gateway.lookups, 0);
        expect(h.coordinator.current(h.scope()).blocksNew, isFalse);
      }
    },
  );
  test(
    'mock cooldown is readable before submit and isolated from API and other municipality',
    () async {
      final h = Harness(mock: true);
      addTearDown(h.dispose);
      expect(h.coordinator.mockCooldownRemaining(h.scope()), isNull);
      await h.start();
      expect(
        h.coordinator.mockCooldownRemaining(h.scope()),
        const Duration(minutes: 5),
      );
      expect(h.coordinator.mockCooldownRemaining(h.scope('bologna')), isNull);
      final api = h.create();
      addTearDown(api.dispose);
      expect(api.mockCooldownRemaining(h.scope()), isNull);
    },
  );

  test(
    'old mock schema upgrades on atomic write; reset rejects old namespace replay',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend());
      await data.mutate(
        'mock:legacy',
        (_) => const LocalDataMutation({
          'version': 1,
          'municipalities': {},
          'votes': {},
        }, null),
      );
      final loop = CivicLoopStore(
        currentUserId: 'user:test',
        localData: data,
        storageKey: () => 'mock:legacy',
      );
      final repo = MockNextProblemsRepository(
        currentUserId: 'user:test',
        store: loop,
      );
      final scope = ProposalScope(
        municipalityId: 'pincara',
        environment: 'mock:test',
        namespace: data.namespace,
      );
      final intent = ProposalSubmissionIntent(
        scope: scope,
        idempotencyKey: 'legacy-upgrade-key',
        submissionScope: await repo.prepareSubmissionScope(),
        draftRevision: 0,
        createdAt: DateTime.utc(2026),
        title: 'Alberi',
        description: 'Serve ombra',
        category: ProblemKey.green,
        location: const ProposalLocation.municipality(),
      );
      await repo.submitIntent(intent);
      expect((data.read('mock:legacy') as Map)['version'], 2);
      await data.reset();
      await expectLater(
        repo.submitIntent(intent),
        throwsA(isA<LocalDataResetException>()),
      );
      await expectLater(
        repo.lookupIntent(intent),
        throwsA(isA<LocalDataResetException>()),
      );
      expect(await repo.listNextProblems(municipalityId: 'pincara'), isEmpty);
      loop.dispose();
      data.dispose();
    },
  );
  test(
    'two coordinators sharing storage cannot create two pending intents for one scope',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final other = h.create();
      addTearDown(other.dispose);
      final g = h.gateway as Gateway,
          pending = Completer<SuggestedProblem>(),
          entered = Completer<void>();
      g.onSubmit = (intent) {
        entered.complete();
        return pending.future;
      };
      final sending = h.start();
      await entered.future;
      final second = await other.start(
        scope: h.scope(),
        draftRevision: 0,
        title: 'Other title',
        description: 'Other description',
        category: ProblemKey.green,
        location: const ProposalLocation.municipality(),
      );
      expect(second.status, SubmissionStatus.outcomeUnknown);
      expect(g.submissions, 1);
      pending.complete(accepted(g.sent.single));
      await sending;
      expect(h.store.history(h.scope()), hasLength(1));
    },
  );

  test(
    'a failed marker write sends zero proposals and can retry after storage recovers',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      h.backend.onWrite = (_, _) async => false;
      expect((await h.start()).status, SubmissionStatus.storageFailed);
      expect((h.gateway as Gateway).submissions, 0);
      expect(h.store.history(h.scope()), isEmpty);
      h.backend.onWrite = null;
      expect((await h.start()).status, SubmissionStatus.succeeded);
      expect((h.gateway as Gateway).submissions, 1);
    },
  );
  test(
    'double submit is guarded before await, marker precedes POST and dispose retains receipt',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final g = h.gateway as Gateway;
      final pending = Completer<SuggestedProblem>();
      final entered = Completer<void>();
      g.onSubmit = (intent) async {
        expect(
          h.store.pending(h.scope())!.idempotencyKey,
          intent.idempotencyKey,
        );
        entered.complete();
        return pending.future;
      };
      final sending = h.start();
      expect((await h.start()).busy, isTrue);
      await entered.future;
      h.coordinator.dispose();
      pending.complete(accepted(g.sent.single));
      expect((await sending).status, SubmissionStatus.succeeded);
      h.coordinator = h.create();
      expect(
        h.coordinator.current(h.scope()).intent!.receipt!.id,
        'actual-server-id',
      );
      expect(g.submissions, 1);
    },
  );
  test(
    'a lost response restores unknown after reload, lookup alone recovers one accepted object',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final g = h.gateway as Gateway;
      g.onSubmit = (intent) async {
        g.committed[intent.idempotencyKey] = accepted(intent);
        throw const ApiException(
          kind: ApiExceptionKind.timeout,
          code: 'timeout',
          message: 'Persa',
        );
      };
      expect((await h.start()).status, SubmissionStatus.outcomeUnknown);
      final key = h.store.pending(h.scope())!.idempotencyKey;
      h.coordinator.dispose();
      h.data.dispose();
      h.data = LocalDataStore(backend: h.backend);
      h.store = ProposalSubmissionStore(h.data);
      h.drafts = ProposalDraftStore(h.data);
      h.coordinator = h.create();
      expect(
        h.coordinator.current(h.scope()).status,
        SubmissionStatus.outcomeUnknown,
      );
      expect(g.submissions, 1);
      expect(g.lookups, 0);
      final result = await h.coordinator.reconcile(h.scope());
      expect(result.status, SubmissionStatus.succeeded);
      expect(result.intent!.idempotencyKey, key);
      expect(g.submissions, 1);
      expect(g.committed, hasLength(1));
    },
  );
  test(
    'lookup 404 preserves uncertainty and explicit retry reuses exact immutable payload and key',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final g = h.gateway as Gateway;
      g.onSubmit = (_) async => throw const ApiException(
        kind: ApiExceptionKind.response,
        statusCode: 503,
        code: 'unavailable',
        message: 'Unavailable',
      );
      await h.start();
      final first = g.sent.single;
      expect(
        (await h.coordinator.reconcile(h.scope())).status,
        SubmissionStatus.outcomeUnknown,
      );
      expect(g.submissions, 1);
      g.onSubmit = null;
      final result = await h.coordinator.retry(h.scope());
      expect(result.status, SubmissionStatus.succeeded);
      expect(g.sent.last.fingerprint, first.fingerprint);
      expect(g.sent.last.payload, first.payload);
      expect(h.store.history(h.scope()), hasLength(1));
    },
  );
  test(
    'malformed successful response is unknown, never an accepted receipt',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final g = h.gateway as Gateway;
      g.onSubmit = (intent) async =>
          accepted(intent, title: 'Another proposal');
      expect((await h.start()).status, SubmissionStatus.outcomeUnknown);
      expect(h.store.pending(h.scope())!.receipt, isNull);
    },
  );
  test(
    'receipt storage failure keeps marker and draft, saving retry performs no POST',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      const draft = ProposalDraft(
        title: 'Alberi',
        description: 'Serve ombra',
        category: ProblemKey.green,
        locationKind: ProposalLocationKind.specific,
        locationLabel: 'Via Milano',
        revision: 7,
      );
      await h.drafts.save(h.scope(), draft, epoch: h.data.epoch);
      final initialWrites = h.backend.writeCalls;
      h.backend.onWrite = (_, _) async =>
          h.backend.writeCalls != initialWrites + 2;
      expect(
        (await h.start(revision: 7)).status,
        SubmissionStatus.receiptUnsaved,
      );
      expect(h.store.pending(h.scope()), isNotNull);
      expect(h.drafts.load(h.scope()), isNotNull);
      h.backend.onWrite = null;
      expect(
        (await h.coordinator.persistReceipt(h.scope())).status,
        SubmissionStatus.succeeded,
      );
      expect((h.gateway as Gateway).submissions, 1);
      expect(h.drafts.load(h.scope()), isNull);
    },
  );
  test('receipt persistence cannot delete a newer draft revision', () async {
    final h = Harness();
    addTearDown(h.dispose);
    final g = h.gateway as Gateway;
    final entered = Completer<void>(), pending = Completer<SuggestedProblem>();
    g.onSubmit = (intent) {
      entered.complete();
      return pending.future;
    };
    await h.drafts.save(
      h.scope(),
      const ProposalDraft(title: 'Alberi', revision: 1),
      epoch: h.data.epoch,
    );
    final sending = h.start(revision: 1);
    await entered.future;
    await h.drafts.save(
      h.scope(),
      const ProposalDraft(title: 'Nuova bozza', revision: 2),
      epoch: h.data.epoch,
    );
    pending.complete(accepted(g.sent.single));
    await sending;
    expect(h.drafts.load(h.scope())!.title, 'Nuova bozza');
  });
  test(
    'reset during POST invalidates result and cannot resurrect intent, receipt or old draft',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final g = h.gateway as Gateway;
      final entered = Completer<void>(),
          pending = Completer<SuggestedProblem>();
      g.onSubmit = (intent) {
        entered.complete();
        return pending.future;
      };
      final old = h.scope();
      final sending = h.start(scope: old);
      await entered.future;
      await h.data.reset();
      pending.complete(accepted(g.sent.single));
      expect((await sending).status, SubmissionStatus.reset);
      expect(h.store.history(h.scope()), isEmpty);
      expect(h.coordinator.current(old).status, SubmissionStatus.reset);
      final encoded = jsonDecode(
        h.backend.values[h.data.key] ?? '{"entries":{}}',
      );
      expect(encoded['entries'], isEmpty);
    },
  );
  test(
    'changed server scope blocks POST retry and form bootstrap, abandonment preserves history',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final g = h.gateway as Gateway;
      g.onSubmit = (_) async => throw const ApiException(
        kind: ApiExceptionKind.network,
        code: 'network',
        message: 'Offline',
      );
      await h.start();
      g.serverScope = 'new-server-scope';
      await expectLater(
        h.coordinator.prepareForm(h.scope()),
        throwsA(isA<ApiException>()),
      );
      expect(
        h.coordinator.current(h.scope()).status,
        SubmissionStatus.scopeLost,
      );
      await h.coordinator.retry(h.scope());
      expect(g.submissions, 1);
      await h.coordinator.abandon(h.scope());
      expect(
        h.store.history(h.scope()).single.phase,
        SubmissionPhase.abandoned,
      );
      g.onSubmit = null;
      expect((await h.start()).status, SubmissionStatus.succeeded);
      expect(h.store.history(h.scope()), hasLength(2));
    },
  );
  test(
    'definitive 422 rejection keeps draft and does not become an unknown commit',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      final g = h.gateway as Gateway;
      g.onSubmit = (_) async => throw const ApiException(
        kind: ApiExceptionKind.response,
        statusCode: 422,
        code: 'rejected_content',
        message: 'internal reason never public',
      );
      final result = await h.start();
      expect(result.status, SubmissionStatus.rejected);
      expect(result.message, isNot(contains('internal reason')));
      expect(h.store.pending(h.scope()), isNull);
    },
  );
  test(
    'mock cooldown is per municipality and environment; API does not use it',
    () async {
      final h = Harness(mock: true);
      addTearDown(h.dispose);
      expect((await h.start()).status, SubmissionStatus.succeeded);
      expect((await h.start()).status, SubmissionStatus.cooldown);
      expect(
        (await h.start(scope: h.scope('bologna'))).status,
        SubmissionStatus.succeeded,
      );
      expect(
        (await h.start(scope: h.scope('pincara', 'other:mock'))).status,
        SubmissionStatus.succeeded,
      );
      h.coordinator.dispose();
      h.coordinator = h.create(mock: false);
      expect((await h.start()).status, SubmissionStatus.succeeded);
    },
  );
  test(
    'store forbids payload mutation and a slower failure cannot overwrite receipt',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      await h.start();
      final receipt = h.store.history(h.scope()).single;
      final mutation = ProposalSubmissionIntent(
        scope: receipt.scope,
        idempotencyKey: receipt.idempotencyKey,
        submissionScope: receipt.submissionScope,
        draftRevision: receipt.draftRevision,
        createdAt: receipt.createdAt,
        title: 'Changed',
        description: receipt.description,
        category: receipt.category,
        location: receipt.location,
      );
      await expectLater(
        h.store.save(mutation, epoch: h.data.epoch),
        throwsA(isA<LocalDataWriteException>()),
      );
      final saved = await h.store.save(
        receipt.withOutcome(SubmissionPhase.outcomeUnknown),
        epoch: h.data.epoch,
      );
      expect(saved.phase, SubmissionPhase.succeeded);
    },
  );
  test(
    'real mock ledger commits entity and replay snapshot together, survives reconstruction and later votes',
    () async {
      final backend = MemoryLocalBackend();
      final data = LocalDataStore(backend: backend);
      final loop = CivicLoopStore(
        currentUserId: 'user:test',
        localData: data,
        storageKey: () => 'mock:test',
      );
      final repo = MockNextProblemsRepository(
        currentUserId: 'user:test',
        store: loop,
      );
      final scope = ProposalScope(
        municipalityId: 'pincara',
        environment: 'mock:test',
        namespace: data.namespace,
      );
      final intent = ProposalSubmissionIntent(
        scope: scope,
        idempotencyKey: 'same-mock-key',
        submissionScope: await repo.prepareSubmissionScope(),
        draftRevision: 0,
        createdAt: DateTime.utc(2026),
        title: 'Alberi',
        description: 'Serve ombra',
        category: ProblemKey.green,
        location: const ProposalLocation.municipality(),
      );
      final first = await repo.submitIntent(intent);
      await repo.submitIntent(intent);
      expect(
        await repo.listNextProblems(municipalityId: 'pincara'),
        hasLength(1),
      );
      await repo.voteSuggestedProblem(
        municipalityId: 'pincara',
        problemId: first.id,
        vote: VoteChoice.up,
      );
      loop.dispose();
      data.dispose();
      final recreated = LocalDataStore(backend: backend);
      final nextLoop = CivicLoopStore(
        currentUserId: 'user:test',
        localData: recreated,
        storageKey: () => 'mock:test',
      );
      final nextRepo = MockNextProblemsRepository(
        currentUserId: 'user:test',
        store: nextLoop,
      );
      final replay = await nextRepo.submitIntent(intent);
      expect(replay.id, first.id);
      expect(replay.votesUp, 0);
      expect(replay.status, SuggestedProblemStatus.pending);
      expect(
        (await nextRepo.getSuggestedProblem(
          municipalityId: 'pincara',
          problemId: first.id,
        )).votesUp,
        1,
      );
      expect((await nextRepo.lookupIntent(intent)).id, first.id);
      await recreated.reset();
      expect(
        await nextRepo.listNextProblems(municipalityId: 'pincara'),
        isEmpty,
      );
      nextLoop.dispose();
      recreated.dispose();
    },
  );
  test(
    'real API mapper/session/repository recover committed but malformed 201 without second POST or bootstrap',
    () async {
      final backend = MemoryLocalBackend();
      final requests = <http.Request>[];
      Map<String, Object?>? committed;
      final transport = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/proposal-session'))
          return http.Response(
            jsonEncode(fixture.response(bootstrap: request.method == 'POST')),
            request.method == 'POST' ? 201 : 200,
          );
        expect(request.headers['Authorization'], 'Bearer ${fixture.token}');
        if (request.method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          committed = {
            'id': 'actual-api-id',
            'title': body['title'],
            'shortDescription': body['description'],
            'category': body['category'],
            'location': body['location'],
            'createdAt': '2026-10-10T10:00:00Z',
            'status': 'pending',
            'votesUp': 0,
            'votesDown': 0,
            'myVote': 'none',
            'submittedByDisplayName': 'Cittadino',
            'promotionRule': {
              'threshold': 1,
              'scopeLabel': 'Comune',
              'reason': 'Prototipo',
            },
          };
          return http.Response('{"id":"actual-api-id"}', 201);
        }
        return http.Response(jsonEncode(committed), 200);
      });
      final config = AppConfig.fromValues(nextProblemsDataSource: 'api');
      final data = LocalDataStore(backend: backend);
      ApiNextProblemsRepository repository(LocalDataStore d) {
        final client = ApiClient(
          baseUrl: Uri.parse('http://localhost:8787'),
          client: transport,
        );
        return ApiNextProblemsRepository(
          client: client,
          userId: 'untrusted',
          sessions: ProposalSessionStore(
            client: client,
            data: d,
            environment: ProposalScope.environmentFor(config),
          ),
        );
      }

      ProposalSubmissionCoordinator coordinator(LocalDataStore d) =>
          ProposalSubmissionCoordinator(
            store: ProposalSubmissionStore(d),
            drafts: ProposalDraftStore(d),
            gateway: repository(d),
            isMock: false,
            keyFactory: () => 'persisted-api-key',
          );
      final first = coordinator(data);
      final scope = ProposalScope.fromConfig(
        municipalityId: 'comune:Bologna',
        config: config,
        namespace: data.namespace,
      );
      expect(
        (await first.start(
          scope: scope,
          draftRevision: 0,
          title: 'Alberi',
          description: 'Serve ombra',
          category: ProblemKey.green,
          location: const ProposalLocation.municipality(),
        )).status,
        SubmissionStatus.outcomeUnknown,
      );
      first.dispose();
      data.dispose();
      final next = coordinator(LocalDataStore(backend: backend));
      expect(next.current(scope).status, SubmissionStatus.outcomeUnknown);
      final before = requests.length;
      expect(before, 3); // bootstrap, lease verification, POST
      expect(
        (await next.reconcile(scope)).intent!.receipt!.id,
        'actual-api-id',
      );
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/next-problems'),
        ),
        hasLength(1),
      );
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('/proposal-session'),
        ),
        hasLength(1),
      );
      expect(
        requests.last.url.path,
        '/v1/municipalities/bologna/submissions/persisted-api-key',
      );
      expect(
        next.current(scope).intent!.receipt!.createdAt,
        DateTime.parse(committed!['createdAt'] as String),
      );
      expect(
        next.current(scope).intent!.receipt!.location,
        const ProposalLocation.municipality(),
      );
      next.dispose();
      next.store.data.dispose();
      transport.close();
    },
  );
}
