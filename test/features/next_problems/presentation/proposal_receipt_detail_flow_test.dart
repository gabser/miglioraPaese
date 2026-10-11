import 'package:fanta_comune/core/persistence/local_data_store.dart';
import '../../../helpers/proposal_form_actions.dart';
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
import 'package:fanta_comune/app/router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_submission_intent.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_cubit.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_detail_cubit.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import 'package:fanta_comune/features/next_problems/presentation/next_problems_page.dart';
import '../../../helpers/test_app.dart';
import '../data/proposal_session_store_test.dart' as session;

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

final apiConfig = AppConfig.fromValues(nextProblemsDataSource: 'api');

class ReadServer {
  final requests = <http.Request>[];
  Map<String, Object?>? receipt;
  String liveStatus = 'pending';
  String receiptId = 'receipt-id';
  List<Map<String, Object?>> publicItems = [];
  int readStatus = 200;
  Map<String, String>? rejectionFields;
  Completer<http.Response>? pendingRead;
  int get submits => requests
      .where((r) => r.method == 'POST' && r.url.path.endsWith('/next-problems'))
      .length;
  late final client = MockClient((r) async {
    requests.add(r);
    if (r.url.path.endsWith('/revoke'))
      return jsonResponse('{"revoked":true}', 200);
    if (r.url.path.endsWith('/proposal-session')) {
      return jsonResponse(
        jsonEncode(session.response(bootstrap: r.method == 'POST')),
        r.method == 'POST' ? 201 : 200,
      );
    }
    if (r.method == 'POST') {
      if (rejectionFields != null)
        return jsonResponse(
          jsonEncode({
            'error': 'invalid_field',
            'message': 'Untrusted English validation',
            'fieldErrors': rejectionFields,
          }),
          400,
        );
      final body = jsonDecode(r.body) as Map;
      receipt = {
        'id': submits > 1 ? '$receiptId-$submits' : receiptId,
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
          'reason': 'Demo',
        },
      };
      return jsonResponse(jsonEncode(receipt), 201);
    }
    if (r.url.path.endsWith('/next-problems'))
      return jsonResponse(jsonEncode({'items': publicItems}), 200);
    if (pendingRead != null) return pendingRead!.future;
    if (readStatus != 200)
      return jsonResponse(
        '{"error":"suggested_problem_not_found"}',
        readStatus,
      );
    final visible = publicItems.where(
      (p) => p['id'] == r.url.pathSegments.last,
    );
    return jsonResponse(
      jsonEncode(
        visible.isNotEmpty
            ? visible.first
            : {...receipt!, 'status': liveStatus},
      ),
      200,
    );
  });
}

class Host {
  Host(this.router, this.context);
  final GoRouter router;
  final BuildContext context;
}

Future<Host> host(
  WidgetTester tester,
  AppPrefs prefs,
  ReadServer server, {
  String? uri,
}) async {
  final router = buildRouter(prefs);
  addTearDown(router.dispose);
  late BuildContext dependencyContext;
  await tester.pumpWidget(
    AppDependencies(
      appPrefs: prefs,
      config: apiConfig,
      httpClient: server.client,
      child: Builder(
        builder: (context) {
          dependencyContext = context;
          return MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (uri != null) {
    router.go(uri);
    await tester.pumpAndSettle();
  }
  return Host(router, dependencyContext);
}

ProposalScope scope(
  AppPrefs prefs, {
  String municipality = 'bologna',
  AppConfig? config,
}) => ProposalScope.fromConfig(
  municipalityId: municipality,
  config: config ?? apiConfig,
  namespace: prefs.localData.namespace,
);

Future<ProposalSubmissionIntent> submit(Host h, AppPrefs prefs) async {
  final result = await h.context.read<ProposalSubmissionCoordinator>().start(
    scope: scope(prefs),
    draftRevision: 0,
    title: 'Rami al parco',
    description: 'Il passaggio è coperto dai rami.',
    category: ProblemKey.green,
    location: ProposalLocation.specific(
      label: 'Via Milano',
      civic: '12/A',
      reference: 'Ingresso nord',
    ),
  );
  expect(result.status, SubmissionStatus.succeeded);
  return result.intent!;
}

Future<void> press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'API field error stays on its field with focus, raw draft preserved and no implicit retry',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer()..rejectionFields = {'title': 'too_long'};
      final h = await host(
        tester,
        prefs,
        server,
        uri: '/suggest-problem?municipality=bologna',
      );
      final title = find.byKey(const ValueKey('proposal-title'));
      final description = find.byKey(const ValueKey('proposal-description'));
      await tester.enterText(title, '  Rami al parco  ');
      await tester.enterText(description, 'Passaggio coperto.');
      await press(tester, find.byKey(const ValueKey('proposal-category')));
      await tester.tap(find.text('Verde pubblico').last);
      await tester.pumpAndSettle();
      await chooseProposalLocation(tester, label: 'Intero Comune');
      await sendReviewedProposal(tester);
      expect(server.submits, 1);
      expect(
        find.text('Il servizio richiede un testo più breve per questo campo.'),
        findsOneWidget,
      );
      expect(find.text('Untrusted English validation'), findsNothing);
      expect(
        tester.widget<TextFormField>(title).controller!.text,
        '  Rami al parco  ',
      );
      expect(
        tester.widget<TextFormField>(description).controller!.text,
        'Passaggio coperto.',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: title, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(find.text('Invio ricevuto'), findsNothing);
      server.rejectionFields = null;
      await tester.enterText(title, 'Rami');
      await tester.pumpAndSettle();
      expect(
        find.text('Il servizio richiede un testo più breve per questo campo.'),
        findsNothing,
      );
      expect(server.submits, 1);
      await sendReviewedProposal(tester);
      expect(server.submits, 2);
      expect(find.text('Invio ricevuto'), findsOneWidget);
      expect(
        h.router.routeInformationProvider.value.uri.path,
        startsWith('/proposal-receipt/'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'advisory comparison opens same-title different-place detail, returns with draft and permits explicit new submission',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer();
      final h = await host(tester, prefs, server);
      final prior = await submit(h, prefs);
      server.publicItems = [
        {
          ...server.receipt!,
          'id': 'other-place',
          'location': {'kind': 'specific', 'label': 'Via Roma'},
        },
      ];
      h.router.go('/suggest-problem?municipality=bologna');
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('proposal-title')),
        'Rami al parco',
      );
      await tester.enterText(
        find.byKey(const ValueKey('proposal-description')),
        'Un problema diverso, in un’altra via.',
      );
      await press(tester, find.byKey(const ValueKey('proposal-category')));
      await tester.tap(find.text('Verde pubblico').last);
      await tester.pumpAndSettle();
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      await tester.enterText(
        find.byKey(const ValueKey('proposal-location-label')),
        'Via Milano',
      );
      await press(tester, find.text('Controlla la proposta'));
      expect(server.submits, 1);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('proposal-submit')))
            .onPressed,
        isNull,
      );
      await press(
        tester,
        find.byKey(const ValueKey('similar-proposal-other-place')),
      );
      expect(find.text('Luogo: Via Roma'), findsOneWidget);
      await press(tester, find.byTooltip('Torna indietro'));
      expect(find.text('Riepilogo della proposta'), findsOneWidget);
      expect(find.text('Un problema diverso, in un’altra via.'), findsWidgets);
      await press(
        tester,
        find.byKey(const ValueKey('proposal-similarity-continue')),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('proposal-submit')))
            .onPressed,
        isNotNull,
      );
      await press(tester, find.byKey(const ValueKey('proposal-submit')));
      expect(server.submits, 2);
      final current = h.context.read<ProposalSubmissionCoordinator>().current(
        scope(prefs),
      );
      expect(current.status, SubmissionStatus.succeeded);
      expect(find.text('Invio ricevuto'), findsOneWidget);
      expect(server.submits, 2);
      final keys = server.requests
          .where(
            (r) => r.method == 'POST' && r.url.path.endsWith('/next-problems'),
          )
          .map((r) => r.headers['idempotency-key'])
          .toSet();
      expect(keys.length, 2);
      expect(
        ProposalSubmissionStore(
          prefs.localData,
        ).history(scope(prefs)).first.idempotencyKey,
        prior.idempotencyKey,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'corrupt receipt cannot display success; missing ID cannot choose latest receipt implicitly',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer();
      final h = await host(tester, prefs, server);
      final intent = await submit(h, prefs);
      h.router.go('/proposal-receipt?municipality=bologna');
      await tester.pumpAndSettle();
      expect(find.text('Invio ricevuto'), findsNothing);
      final before = server.requests.length;
      await prefs.localData.mutate(
        'submissions:${scope(prefs).key}',
        (_) => const LocalDataMutation({'version': 99, 'items': []}, null),
      );
      h.router.go(
        ProposalRouteContext.receiptLocation(intent.receipt!.id, 'bologna'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invio ricevuto'), findsNothing);
      expect(
        find.textContaining('ricevuta locale non è leggibile'),
        findsOneWidget,
      );
      expect(server.requests.length, before);
    },
  );

  testWidgets(
    'last accepted receipt survives a later explicitly abandoned attempt',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer();
      final h = await host(tester, prefs, server);
      final accepted = await submit(h, prefs);
      final store = ProposalSubmissionStore(prefs.localData);
      final another = ProposalSubmissionIntent(
        scope: scope(prefs),
        idempotencyKey: 'another-attempt-key',
        submissionScope: accepted.submissionScope,
        draftRevision: 1,
        createdAt: DateTime.now(),
        title: 'Altra proposta',
        description: 'Tentativo successivo.',
        category: ProblemKey.green,
        location: const ProposalLocation.municipality(),
      );
      await store.create(another, epoch: prefs.localData.epoch);
      await store.save(
        another.withOutcome(SubmissionPhase.abandoned),
        epoch: prefs.localData.epoch,
      );
      expect(
        h.context
            .read<ProposalSubmissionCoordinator>()
            .savedReceipt(scope(prefs))
            .intent!
            .idempotencyKey,
        accepted.idempotencyKey,
      );
      expect(server.submits, 1);
    },
  );

  testWidgets(
    'opaque ID with reserved URL characters round trips through receipt and own detail',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer()..receiptId = 'opaque/12:A?#spazio';
      final h = await host(tester, prefs, server);
      final intent = await submit(h, prefs);
      h.router.go(
        ProposalRouteContext.receiptLocation(intent.receipt!.id, 'bologna'),
      );
      await tester.pumpAndSettle();
      expect(find.text('ID: opaque/12:A?#spazio'), findsOneWidget);
      await press(tester, find.text('Apri il dettaglio aggiornato'));
      expect(find.text('Stato aggiornato: In valutazione'), findsOneWidget);
      expect(server.requests.last.url.pathSegments[4], 'opaque/12:A?#spazio');
      expect(server.requests.last.url.pathSegments.last, 'own');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'receipt survives reconstruction offline without any HTTP and cannot cross municipality or environment',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer();
      final h = await host(tester, prefs, server);
      final intent = await submit(h, prefs);
      final uri = ProposalRouteContext.receiptLocation(
        intent.receipt!.id,
        'bologna',
      );
      h.router.go(uri);
      await tester.pumpAndSettle();
      expect(find.text('Invio ricevuto'), findsOneWidget);
      expect(find.text('Luogo: Via Milano, 12/A'), findsOneWidget);
      expect(find.text('Riferimento: Ingresso nord'), findsOneWidget);
      expect(find.text('Stato all’invio: In valutazione'), findsOneWidget);
      expect(find.textContaining('Ricevuta salvata il'), findsOneWidget);
      final before = server.requests.length;
      await tester.pumpWidget(const SizedBox());
      SharedPreferences.resetStatic();
      final reloaded = await AppPrefs.init();
      final restored = await host(tester, reloaded, server, uri: uri);
      expect(find.text('Invio ricevuto'), findsOneWidget);
      expect(server.requests.length, before);
      final coordinator = restored.context
          .read<ProposalSubmissionCoordinator>();
      expect(
        coordinator
            .savedReceipt(scope(reloaded, municipality: 'castel-bolognese'))
            .intent,
        isNull,
      );
      expect(
        coordinator
            .savedReceipt(scope(reloaded, config: AppConfig.fromValues()))
            .intent,
        isNull,
      );
      restored.router.go(
        ProposalRouteContext.receiptLocation(
          intent.receipt!.id,
          'castel-bolognese',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invio ricevuto'), findsNothing);
      expect(
        find.textContaining('non è disponibile su questo dispositivo'),
        findsOneWidget,
      );
      expect(server.requests.length, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'last receipt ignores list filters and pop preserves the existing list cubit and search',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer();
      final h = await host(tester, prefs, server);
      await submit(h, prefs);
      h.router.go('/next-problems?municipality=bologna');
      await tester.pumpAndSettle();
      final listContext = tester.element(find.byType(NextProblemsPage));
      // The Cubit lives below NextProblemsPage, so read it from a rendered control.
      final search = find.byType(TextField).first;
      final cubit = tester.element(search).read<NextProblemsCubit>();
      await tester.enterText(search, 'un testo che non trova nulla');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(cubit.state.query, 'un testo che non trova nulla');
      final posts = server.submits;
      await press(tester, find.byKey(const ValueKey('last-proposal-receipt')));
      expect(find.text('Invio ricevuto'), findsOneWidget);
      await press(tester, find.byTooltip('Torna indietro'));
      expect(
        tester.element(find.byType(TextField).first).read<NextProblemsCubit>(),
        same(cubit),
      );
      expect(cubit.state.query, 'un testo che non trova nulla');
      expect(server.submits, posts);
      expect(listContext.mounted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'own detail rereads authoritative status, never changes accepted snapshot and uses no new POST',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer();
      final h = await host(tester, prefs, server);
      final intent = await submit(h, prefs);
      server.liveStatus = 'rejected';
      h.router.go(
        ProposalRouteContext.detailLocation(intent.receipt!.id, 'bologna'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Stato aggiornato: Non accolta'), findsOneWidget);
      expect(
        server.requests.last.url.path,
        '/v1/municipalities/bologna/next-problems/receipt-id/own',
      );
      expect(
        server.requests.last.headers['authorization'],
        startsWith('Bearer '),
      );
      final snapshot = ProposalSubmissionStore(
        prefs.localData,
      ).history(scope(prefs)).single;
      expect(snapshot.receipt!.status.name, 'pending');
      await press(tester, find.text('Leggi la ricevuta salvata'));
      expect(find.text('Stato all’invio: In valutazione'), findsOneWidget);
      expect(server.submits, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'own 401 keeps receipt, retries GET only, and never bootstraps a replacement',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer();
      final h = await host(tester, prefs, server);
      final intent = await submit(h, prefs);
      server.readStatus = 401;
      h.router.go(
        ProposalRouteContext.detailLocation(intent.receipt!.id, 'bologna'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('sessione originale'), findsOneWidget);
      await press(tester, find.text('Riprova'));
      await press(tester, find.text('Leggi la ricevuta salvata'));
      expect(find.text('Invio ricevuto'), findsOneWidget);
      expect(
        server.requests
            .where(
              (r) =>
                  r.method == 'POST' &&
                  r.url.path.endsWith('/proposal-session'),
            )
            .length,
        1,
      );
      expect(server.submits, 1);
    },
  );

  testWidgets(
    'public deep link has no session bootstrap, 404 uniform and connection failure retry',
    (tester) async {
      final prefs = await createTestPrefs({});
      final server = ReadServer()..readStatus = 404;
      final h = await host(
        tester,
        prefs,
        server,
        uri: '/next-problems/not-found?municipality=bologna',
      );
      expect(
        find.text('Proposta non disponibile per questo Comune.'),
        findsOneWidget,
      );
      expect(server.requests.length, 1);
      expect(server.requests.single.method, 'GET');
      expect(server.requests.single.headers['authorization'], isNull);
      expect(prefs.municipalityId, isNull);
      server.readStatus = 503;
      h.router.go('/next-problems/offline?municipality=bologna');
      await tester.pumpAndSettle();
      expect(find.textContaining('connessione'), findsOneWidget);
      expect(find.text('Riprova'), findsOneWidget);
      expect(server.requests.every((r) => r.method == 'GET'), isTrue);
      for (final uri in [
        '/proposal-receipt',
        '/proposal-receipt/not-found?municipality=bologna',
        '/next-problems/not-found?municipality=bologna&municipality=castel-bolognese',
      ]) {
        final before = server.requests.length;
        h.router.go(uri);
        await tester.pumpAndSettle();
        expect(server.requests.length, before);
        expect(find.text('Invio ricevuto'), findsNothing);
      }
    },
  );

  testWidgets(
    'reset invalidates receipt and stale detail result; a disposed page does not navigate',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final server = ReadServer();
      final h = await host(tester, prefs, server);
      final intent = await submit(h, prefs);
      server.pendingRead = Completer<http.Response>();
      h.router.go(
        ProposalRouteContext.detailLocation(intent.receipt!.id, 'bologna'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final cubit = tester
          .element(find.byType(CircularProgressIndicator))
          .read<ProposalDetailCubit>();
      await prefs.clearAll();
      await tester.pump();
      expect(cubit.state.problem, isNull);
      server.pendingRead!.complete(
        http.Response(jsonEncode(server.receipt), 200),
      );
      await tester.pumpAndSettle();
      h.router.go(
        ProposalRouteContext.receiptLocation(intent.receipt!.id, 'bologna'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Invio ricevuto'), findsNothing);
      expect(server.submits, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'receipt and detail scroll without overflow at $width and 200% text',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final prefs = await createTestPrefs({
          'municipality_id': 'comune:Bologna',
        });
        final server = ReadServer();
        final h = await host(tester, prefs, server);
        final intent = await submit(h, prefs);
        h.router.go(
          ProposalRouteContext.receiptLocation(intent.receipt!.id, 'bologna'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await press(tester, find.text('Apri il dettaglio aggiornato'));
        expect(find.text('Stato aggiornato: In valutazione'), findsOneWidget);
        await press(tester, find.text('Aggiorna il dettaglio'));
        expect(tester.takeException(), isNull);
        expect(server.submits, 1);
      },
    );
  }
}
