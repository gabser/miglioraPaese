import '../../../helpers/submission_test_provider.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import '../../../helpers/proposal_form_actions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/boot/boot_screen.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/info/presentation/privacy_page.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/presentation/suggest_problem_page.dart';
import '../../../helpers/test_app.dart';

final title = find.byKey(const ValueKey('proposal-title'));
final description = find.byKey(const ValueKey('proposal-description'));
final category = find.byKey(const ValueKey('proposal-category'));
final submit = find.byKey(const ValueKey('proposal-submit'));

void main() {
  testWidgets(
    'manual place survives reconstruction and reaches mock list, detail and promoted card',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Castel Bolognese',
        'user_id': 'user:test',
      });
      await pumpHost(tester, prefs);
      await fill(tester, 'Potatura');
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      final label = find.byKey(const ValueKey('proposal-location-label'));
      final civic = find.byKey(const ValueKey('proposal-location-civic'));
      final reference = find.byKey(
        const ValueKey('proposal-location-reference'),
      );
      await tester.enterText(label, '  Via Milano  ');
      final details = find.text('Riferimenti facoltativi');
      await tester.ensureVisible(details);
      await tester.pumpAndSettle();
      await tester.tap(details);
      await tester.pumpAndSettle();
      await tester.enterText(civic, ' 12/A ');
      await tester.enterText(reference, ' Ingresso del parco ');
      await prefs.localData.flush();
      await tester.pumpWidget(const SizedBox());
      await pumpHost(tester, prefs);
      expect(text(tester, label), '  Via Milano  ');
      if (civic.evaluate().isEmpty) {
        await tester.ensureVisible(details);
        await tester.pumpAndSettle();
        await tester.tap(details);
        await tester.pumpAndSettle();
      }
      expect(text(tester, civic), ' 12/A ');
      expect(text(tester, reference), ' Ingresso del parco ');
      await sendReviewedProposal(tester);
      final context = tester.element(find.text('Invio ricevuto'));
      final repository = context.read<NextProblemsRepository>();
      final list = await repository.listNextProblems(
        municipalityId: 'castel-bolognese',
      );
      final created = list.singleWhere((item) => item.title == 'Potatura');
      final place = ProposalLocation.specific(
        label: 'Via Milano',
        civic: '12/A',
        reference: 'Ingresso del parco',
      );
      expect(created.location, place);
      expect(
        (await repository.getSuggestedProblem(
          municipalityId: 'castel-bolognese',
          problemId: created.id,
        )).location,
        place,
      );
      await repository.voteSuggestedProblem(
        municipalityId: 'castel-bolognese',
        problemId: created.id,
        vote: VoteChoice.up,
      );
      final game = context.read<GameRepository>();
      final readingCards = game.listProblems('castel-bolognese');
      await tester.pump(const Duration(milliseconds: 300));
      final cards = await readingCards;
      expect(
        cards.singleWhere((item) => item.title == 'Potatura').zoneName,
        place.displayLabel,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'focus and selection do not create a draft or advance its revision',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      await pumpHost(tester, prefs);
      final titleController = tester
          .widget<TextField>(
            find.descendant(of: title, matching: find.byType(TextField)),
          )
          .controller!;
      titleController.selection = const TextSelection.collapsed(offset: 0);
      await tester.pumpAndSettle();
      expect(prefs.localData.revision, 0);
      await fill(tester, 'Bozza da conservare');
      final before = prefs.localData.revision;
      titleController.selection = const TextSelection.collapsed(offset: 2);
      await tester.pumpAndSettle();
      expect(prefs.localData.revision, before);
      expect(text(tester, title), 'Bozza da conservare');
      await tester.enterText(title, 'Bozza modificata');
      await tester.pumpAndSettle();
      expect(prefs.localData.revision, greaterThan(before));
    },
  );

  testWidgets(
    'raw fields and category recover after controlled exit and app/prefs reconstruction',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
        'user_id': 'user:test',
      });
      final router = await pumpHost(tester, prefs);
      await fill(tester, '  Alberi da potare  ');
      expect(find.text('Bozza salvata su questo dispositivo.'), findsOneWidget);
      await tester.tap(find.byTooltip('Torna ai temi'));
      await tester.pumpAndSettle();
      expect(find.text('Lista'), findsOneWidget);
      router.go('/suggest-problem');
      await tester.pumpAndSettle();
      expect(text(tester, title), '  Alberi da potare  ');
      expect(
        tester
            .widget<DropdownButtonFormField<ProblemKey>>(category)
            .initialValue,
        ProblemKey.green,
      );
      expect(
        find.text('Bozza recuperata da questo dispositivo.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      final shared = await SharedPreferences.getInstance();
      await shared.reload();
      final recreated = AppPrefs(shared);
      await pumpHost(tester, recreated);
      expect(text(tester, title), '  Alberi da potare  ');
      expect(text(tester, description), 'I rami coprono il passaggio.');
      expect(
        find.text('Bozza recuperata da questo dispositivo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'municipality and data source/origin changes recover only their own draft',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
        'user_id': 'user:test',
      });
      await pumpHost(tester, prefs);
      await fill(tester, 'Bozza Bologna');
      await prefs.setMunicipalityId('comune:Pincara');
      await tester.pumpAndSettle();
      expect(text(tester, title), isEmpty);
      await tester.enterText(title, 'Bozza Pincara');
      await tester.pumpAndSettle();
      await prefs.setMunicipalityId('comune:Bologna');
      await tester.pumpAndSettle();
      expect(text(tester, title), 'Bozza Bologna');
      await tester.pumpWidget(const SizedBox());
      await pumpHost(
        tester,
        prefs,
        config: AppConfig.fromValues(
          nextProblemsDataSource: 'api',
          apiBaseUrl: 'https://example.test/root',
        ),
      );
      expect(text(tester, title), isEmpty);
      await tester.enterText(title, 'Bozza API');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await pumpHost(tester, prefs);
      expect(text(tester, title), 'Bozza Bologna');
    },
  );

  testWidgets('old successful submission preserves a newer edited draft', (
    tester,
  ) async {
    final prefs = await createTestPrefs({
      'municipality_id': 'comune:Bologna',
      'user_id': 'user:test',
    });
    final repo = RecordingRepository()..pending = Completer<SuggestedProblem>();
    final router = await pumpHost(tester, prefs, repository: repo);
    await fill(tester, 'Titolo inviato');
    await send(tester);
    await tester.ensureVisible(submit);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(repo.calls, 1);
    await tester.enterText(title, 'Nuova bozza durante invio');
    await tester.pump();
    await prefs.localData.flush();
    repo.pending!.complete(await accepted());
    await tester.pumpAndSettle();
    router.go('/suggest-problem');
    await tester.pumpAndSettle();
    expect(text(tester, title), 'Nuova bozza durante invio');
    expect(
      find.text('Bozza recuperata da questo dispositivo.'),
      findsOneWidget,
    );
  });

  testWidgets('successful unchanged submission removes only its sent draft', (
    tester,
  ) async {
    final prefs = await createTestPrefs({
      'municipality_id': 'comune:Bologna',
      'user_id': 'user:test',
    });
    final repo = RecordingRepository();
    final router = await pumpHost(tester, prefs, repository: repo);
    await fill(tester, 'Titolo inviato');
    await send(tester);
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    router.go('/suggest-problem');
    await tester.pumpAndSettle();
    expect(text(tester, title), isEmpty);
    expect(
      tester.widget<DropdownButtonFormField<ProblemKey>>(category).initialValue,
      isNull,
    );
  });

  testWidgets(
    'failed storage blocks submit and controlled exit, then retry saves the intact fields',
    (tester) async {
      await createTestPrefs({
        'municipality_id': 'comune:Bologna',
        'user_id': 'user:test',
      });
      final shared = await SharedPreferences.getInstance();
      final backend = FailingBackend(shared)..failWrite = true;
      final prefs = AppPrefs(
        shared,
        dataStore: LocalDataStore(backend: backend),
      );
      final repo = RecordingRepository();
      await pumpHost(tester, prefs, repository: repo);
      await fill(tester, 'Testo da conservare');
      expect(find.text('Bozza salvata su questo dispositivo.'), findsNothing);
      expect(find.text('Riprova il salvataggio'), findsOneWidget);
      await send(tester);
      await tester.pumpAndSettle();
      expect(repo.calls, 0);
      await tester.tap(find.byTooltip('Torna ai temi'));
      await tester.pumpAndSettle();
      expect(find.byType(SuggestProblemPage), findsOneWidget);
      expect(text(tester, title), 'Testo da conservare');
      backend.failWrite = false;
      final retry = find.text('Riprova il salvataggio');
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Bozza salvata su questo dispositivo.'), findsOneWidget);
    },
  );

  testWidgets(
    'privacy reset clears persistent drafts/proposals and providers, preserves other app namespaces and rotates identity',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Pincara',
        'user_id': 'old-user',
        'proposal_local_data_v1:foreign': 'other-app-data',
      });
      final router = await pumpHost(tester, prefs);
      await fill(tester, 'Bozza da cancellare');
      final store = tester
          .element(find.byType(SuggestProblemPage))
          .read<CivicLoopStore>();
      await store.submitSuggestedProblem(
        municipalityId: 'comune:Pincara',
        title: 'Proposta salvata',
        description: 'Testo',
        category: ProblemKey.green,
      );
      final priorNamespace = prefs.localData.namespace;
      router.go('/privacy');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azzera preferenze e riparti'));
      await tester.pumpAndSettle();
      expect(find.byType(BootScreen), findsOneWidget);
      expect(prefs.municipalityId, isNull);
      expect(prefs.userId, isNot('old-user'));
      expect(prefs.localData.namespace, isNot(priorNamespace));
      expect(store.listNextProblems(municipalityId: 'comune:Pincara'), isEmpty);
      final shared = await SharedPreferences.getInstance();
      await shared.reload();
      expect(
        shared.getString('proposal_local_data_v1:foreign'),
        'other-app-data',
      );
      final scoped = ProposalScope.fromConfig(
        municipalityId: 'comune:Pincara',
        config: AppConfig.fromValues(),
        namespace: prefs.localData.namespace,
      );
      expect(ProposalDraftStore(prefs.localData).load(scoped), isNull);
    },
  );

  testWidgets(
    'failed privacy clear reports failure and stays on the page until retry succeeds',
    (tester) async {
      await createTestPrefs({
        'municipality_id': 'comune:Bologna',
        'user_id': 'old-user',
      });
      final shared = await SharedPreferences.getInstance();
      final backend = FailingBackend(shared)..failClear = true;
      final prefs = AppPrefs(
        shared,
        dataStore: LocalDataStore(backend: backend),
      );
      final router = await pumpHost(tester, prefs);
      await fill(tester, 'Da cancellare');
      router.go('/privacy');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azzera preferenze e riparti'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Cancellazione non completata: Riprova la cancellazione. Riprova.',
        ),
        findsOneWidget,
      );
      expect(find.byType(PrivacyPage), findsOneWidget);
      backend.failClear = false;
      await tester.ensureVisible(find.text('Azzera preferenze e riparti'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Azzera preferenze e riparti'));
      await tester.pumpAndSettle();
      expect(find.byType(BootScreen), findsOneWidget);
    },
  );
}

Future<GoRouter> pumpHost(
  WidgetTester tester,
  AppPrefs prefs, {
  NextProblemsRepository? repository,
  AppConfig? config,
}) async {
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
      GoRoute(path: '/boot', builder: (_, _) => const BootScreen()),
    ],
  );
  addTearDown(router.dispose);
  final app = MaterialApp.router(theme: AppTheme.light(), routerConfig: router);
  await tester.pumpWidget(
    AppDependencies(
      appPrefs: prefs,
      config: config ?? AppConfig.fromValues(),
      child: repository == null
          ? app
          : Provider<NextProblemsRepository>.value(
              value: repository,
              child: recordingSubmissionHost(
                prefs: prefs,
                repository: repository,
                child: app,
              ),
            ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> fill(WidgetTester tester, String value) async {
  await tester.enterText(title, value);
  await tester.enterText(description, 'I rami coprono il passaggio.');
  await tester.ensureVisible(category);
  await tester.pumpAndSettle();
  await tester.tap(category);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Verde pubblico').last);
  await tester.pumpAndSettle();
  await chooseProposalLocation(tester);
}

Future<void> send(WidgetTester tester) =>
    sendReviewedProposal(tester, settleAfter: false);

String text(WidgetTester tester, Finder field) => tester
    .widget<TextField>(
      find.descendant(of: field, matching: find.byType(TextField)),
    )
    .controller!
    .text;

class FailingBackend extends SharedPreferencesLocalBackend {
  FailingBackend(super.prefs);
  bool failWrite = false;
  bool failClear = false;
  @override
  Future<bool> writeString(String key, String value) =>
      failWrite ? Future.value(false) : super.writeString(key, value);
  @override
  Future<bool> clear() => failClear ? Future.value(false) : super.clear();
}

class RecordingRepository extends MockNextProblemsRepository {
  RecordingRepository() : super(currentUserId: 'user:test');
  int calls = 0;
  Completer<SuggestedProblem>? pending;
  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) {
    calls++;
    return pending?.future ??
        super.submitSuggestedProblem(
          municipalityId: municipalityId,
          title: title,
          description: description,
          category: category,
          location: location,
        );
  }
}

Future<SuggestedProblem> accepted() =>
    MockNextProblemsRepository(
      currentUserId: 'user:test',
    ).submitSuggestedProblem(
      municipalityId: 'comune:Bologna',
      title: 'Titolo inviato',
      description: 'I rami coprono il passaggio.',
      location: const ProposalLocation.municipality(),
      category: ProblemKey.green,
    );
