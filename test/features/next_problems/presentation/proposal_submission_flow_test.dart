import '../../../helpers/submission_test_provider.dart';
import 'package:fanta_comune/features/info/presentation/privacy_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import 'package:fanta_comune/features/next_problems/presentation/suggest_problem_page.dart';
import '../../../helpers/proposal_form_actions.dart';
import '../../../helpers/test_app.dart';
import '../data/proposal_session_store_test.dart' as fixture;

final config = AppConfig.fromValues(nextProblemsDataSource: 'api');

class Transport {
  bool malformed = false;
  bool lookupMissing = false;
  Completer<http.Response>? pending;
  Map<String, Object?>? receipt;
  final requests = <http.Request>[];
  int get submits => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/next-problems'))
      .length;
  int get bootstraps => requests
      .where(
        (r) => r.method == 'POST' && r.url.path.endsWith('/proposal-session'),
      )
      .length;
  late final client = MockClient((request) async {
    requests.add(request);
    if (request.url.path.endsWith('/revoke'))
      return http.Response('{"revoked":true}', 200);
    if (request.url.path.endsWith('/proposal-session'))
      return http.Response(
        jsonEncode(fixture.response(bootstrap: request.method == 'POST')),
        request.method == 'POST' ? 201 : 200,
      );
    if (request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      receipt = {
        'id': 'persistent-api-id',
        'title': body['title'],
        'shortDescription': body['description'],
        'location': body['location'],
        'category': body['category'],
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
      return pending?.future ??
          http.Response(
            malformed ? '{"id":"persistent-api-id"}' : jsonEncode(receipt),
            201,
          );
    }
    return lookupMissing
        ? http.Response('{"error":"submission_not_found"}', 404)
        : http.Response(jsonEncode(receipt), 200);
  });
}

ProposalScope scope(AppPrefs prefs) => ProposalScope.fromConfig(
  municipalityId: 'bologna',
  config: config,
  namespace: prefs.localData.namespace,
);
Future<GoRouter> host(
  WidgetTester tester,
  AppPrefs prefs,
  Transport transport,
) async {
  final router = GoRouter(
    initialLocation: '/suggest-problem',
    routes: [
      receiptTestRoute(prefs),
      GoRoute(
        path: '/suggest-problem',
        builder: (_, _) => const SuggestProblemPage(),
      ),
      GoRoute(
        path: '/next-problems',
        builder: (_, _) => const Scaffold(body: Text('Lista')),
      ),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyPage()),
      GoRoute(
        path: '/boot',
        builder: (_, _) => const Scaffold(body: Text('Ripartito')),
      ),
      GoRoute(
        path: '/elsewhere',
        builder: (_, _) => const Scaffold(body: Text('Altrove')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppDependencies(
      appPrefs: prefs,
      config: config,
      httpClient: transport.client,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> fill(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('proposal-title')),
    'Alberi al parco',
  );
  await tester.enterText(
    find.byKey(const ValueKey('proposal-description')),
    'I rami coprono il passaggio.',
  );
  final category = find.byKey(const ValueKey('proposal-category'));
  await tester.ensureVisible(category);
  await tester.pumpAndSettle();
  await tester.tap(category);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Verde pubblico').last);
  await tester.pumpAndSettle();
  await chooseProposalLocation(tester);
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'unreadable API session offers informed local-only reset after failed normal reset',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final transport = Transport();
      addTearDown(transport.client.close);
      final router = await host(tester, prefs, transport);
      final oldNamespace = prefs.localData.namespace;
      await prefs.localData.mutate(
        'api-session:${ProposalScope.environmentFor(config)}',
        (_) => const LocalDataMutation({
          'token': 'unreadable',
          'submissionScope': fixture.scope,
        }, null),
      );
      router.go('/privacy');
      await tester.pumpAndSettle();
      await tap(tester, find.text('Azzera dati locali e riparti'));
      expect(prefs.sessionUnrecoverable, isTrue);
      final requestsBefore = transport.requests.length;
      await tap(
        tester,
        find.text('Sessione non recuperabile: riparti localmente'),
      );
      expect(
        find.text('Ripartire solo su questo dispositivo?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(prefs.localData.namespace, oldNamespace);
      await tap(
        tester,
        find.text('Sessione non recuperabile: riparti localmente'),
      );
      await tester.tap(find.text('Cancella solo i dati locali'));
      await tester.pumpAndSettle();
      expect(find.text('Ripartito'), findsOneWidget);
      expect(prefs.localData.namespace, isNot(oldNamespace));
      expect(prefs.municipalityId, isNull);
      expect(prefs.sessionUnrecoverable, isFalse);
      expect(transport.requests.length, requestsBefore);
      expect(tester.takeException(), isNull);
    },
  );

  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });
  testWidgets(
    'real API providers restore uncertain intent after recreation and lookup without another POST',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final transport = Transport()..malformed = true;
      addTearDown(transport.client.close);
      await host(tester, prefs, transport);
      await fill(tester);
      await sendReviewedProposal(tester);
      expect(transport.submits, 1);
      expect(transport.bootstraps, 1);
      expect(find.text('Verifica invio'), findsOneWidget);
      final key = ProposalSubmissionStore(
        prefs.localData,
      ).pending(scope(prefs))!.idempotencyKey;
      await tester.pumpWidget(const SizedBox());
      final shared = await SharedPreferences.getInstance();
      await shared.reload();
      final recreated = AppPrefs(shared);
      await host(tester, recreated, transport);
      expect(transport.submits, 1);
      expect(transport.bootstraps, 1);
      final context = tester.element(find.byType(SuggestProblemPage));
      expect(
        context
            .read<ProposalSubmissionCoordinator>()
            .current(scope(recreated))
            .status,
        SubmissionStatus.outcomeUnknown,
      );
      await tap(tester, find.text('Verifica invio'));
      expect(find.text('Invio ricevuto'), findsOneWidget);
      expect(transport.submits, 1);
      expect(transport.bootstraps, 1);
      final stored = ProposalSubmissionStore(
        recreated.localData,
      ).history(scope(recreated)).single;
      expect(stored.idempotencyKey, key);
      expect(stored.receipt!.id, 'persistent-api-id');
      expect(stored.phase, SubmissionPhase.succeeded);
      expect(
        ProposalDraftStore(recreated.localData).load(scope(recreated)),
        isNull,
      );
      expect(
        transport.requests.last.url.path,
        '/v1/municipalities/bologna/submissions/$key',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'leaving during POST retains result and newer draft without late route navigation',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final transport = Transport()..pending = Completer<http.Response>();
      addTearDown(transport.client.close);
      final router = await host(tester, prefs, transport);
      await fill(tester);
      await sendReviewedProposal(tester, settleAfter: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(transport.submits, 1);
      await tester.enterText(
        find.byKey(const ValueKey('proposal-title')),
        'Bozza successiva',
      );
      await tester.pump();
      await prefs.localData.flush();
      router.go('/elsewhere');
      await tester.pumpAndSettle();
      expect(find.text('Altrove'), findsOneWidget);
      transport.pending!.complete(
        http.Response(jsonEncode(transport.receipt), 201),
      );
      await tester.pumpAndSettle();
      expect(find.text('Altrove'), findsOneWidget);
      final record = ProposalSubmissionStore(
        prefs.localData,
      ).history(scope(prefs)).single;
      expect(record.receipt!.id, 'persistent-api-id');
      expect(
        ProposalDraftStore(prefs.localData).load(scope(prefs))!.title,
        'Bozza successiva',
      );
      router.go('/suggest-problem');
      await tester.pumpAndSettle();
      expect(find.text('Ultimo invio ricevuto'), findsOneWidget);
      expect(find.text('ID: persistent-api-id'), findsOneWidget);
      expect(transport.submits, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'review announces its state, editing invalidates it without sending or losing values',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final transport = Transport();
      addTearDown(transport.client.close);
      await host(tester, prefs, transport);
      await fill(tester);
      await tap(tester, find.byKey(const ValueKey('proposal-submit')));
      final announcement = find.bySemanticsLabel(
        'Riepilogo pronto. Controlla la proposta prima di inviare.',
      );
      expect(announcement, findsOneWidget);
      expect(
        tester
            .getSemantics(announcement)
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      expect(transport.submits, 0);
      await tap(tester, find.text('Modifica titolo'));
      expect(announcement, findsNothing);
      expect(transport.submits, 0);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('proposal-title')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller!.text, 'Alberi al parco');
      expect(field.focusNode!.hasFocus, isTrue);
      await tap(tester, find.byKey(const ValueKey('proposal-submit')));
      expect(announcement, findsOneWidget);
      expect(transport.submits, 0);
      semantics.dispose();
    },
  );
  testWidgets(
    'abandonment is explicit, preserves history and never starts another proposal automatically',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final transport = Transport()..malformed = true;
      addTearDown(transport.client.close);
      await host(tester, prefs, transport);
      await fill(tester);
      await sendReviewedProposal(tester);
      await tap(tester, find.text('Abbandona verifica'));
      expect(find.text('Abbandonare la verifica?'), findsOneWidget);
      await tester.tap(find.text('Continua a verificare'));
      await tester.pumpAndSettle();
      expect(
        ProposalSubmissionStore(prefs.localData).pending(scope(prefs)),
        isNotNull,
      );
      await tap(tester, find.text('Abbandona verifica'));
      await tester.tap(find.text('Abbandona verifica').last);
      await tester.pumpAndSettle();
      expect(
        ProposalSubmissionStore(
          prefs.localData,
        ).history(scope(prefs)).single.phase,
        SubmissionPhase.abandoned,
      );
      expect(transport.submits, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
