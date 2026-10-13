import 'package:fanta_comune/features/next_problems/logic/next_problems_cubit.dart';
import 'package:fanta_comune/features/next_problems/logic/next_problems_state.dart';
import '../../../helpers/submission_test_provider.dart';
import '../../../helpers/proposal_form_actions.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/app/router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import '../../../helpers/test_app.dart';

final _title = find.byKey(const ValueKey('proposal-title'));
final _description = find.byKey(const ValueKey('proposal-description'));
final _category = find.byKey(const ValueKey('proposal-category'));
final _submit = find.byKey(const ValueKey('proposal-submit'));

void main() {
  for (final fantasy in [false, true]) {
    testWidgets(
      'filters and originating page survive cancel and receipt in fantasy=$fantasy',
      (tester) async {
        final prefs = await createTestPrefs({
          'municipality_id': 'comune:Bologna',
        });
        final config = AppConfig.fromValues(fantasyModeEnabled: fantasy);
        final origin = fantasy ? '/market' : '/board';
        final repository = _RecordingRepository();
        final router = await _host(
          tester,
          prefs,
          repository,
          origin,
          config: config,
        );
        router.push('/next-problems?municipality=bologna');
        await tester.pumpAndSettle();
        final listContext = tester.element(find.text('Proposte del Comune'));
        final cubit = listContext.read<NextProblemsCubit>();
        await tester.enterText(find.byType(TextField).first, 'parco');
        await tester.tap(find.widgetWithText(ChoiceChip, 'Nel gioco'));
        await tester.tap(find.text('Più recenti'));
        await tester.pumpAndSettle();
        expect(cubit.state.query, 'parco');
        expect(cubit.state.filterStatus, SuggestedProblemStatus.approved);
        expect(cubit.state.sortMode, NextProblemsSortMode.newest);
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Torna alle proposte'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'parco',
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Nel gioco'))
              .selected,
          isTrue,
        );
        expect(cubit.state.sortMode, NextProblemsSortMode.newest);
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        final listReadsBeforeSend = repository.listMunicipalities.length;
        await tester.enterText(_title, 'Alberi al parco');
        await _completeForm(tester);
        await sendReviewedProposal(tester);
        expect(find.text('Invio ricevuto'), findsOneWidget);
        await tester.ensureVisible(find.text('Torna indietro'));
        await tester.tap(find.text('Torna indietro'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          'parco',
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Nel gioco'))
              .selected,
          isTrue,
        );
        expect(cubit.state.sortMode, NextProblemsSortMode.newest);
        expect(
          find.byKey(const ValueKey('last-proposal-receipt')),
          findsOneWidget,
        );
        expect(
          repository.listMunicipalities.length,
          greaterThan(listReadsBeforeSend),
        );
        await tester.tap(find.byTooltip('Torna indietro'));
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, origin);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'invalid scope notice remains usable on a short 320px viewport at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 350);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final router = await _host(
        tester,
        prefs,
        _RecordingRepository(),
        '/suggest-problem?municipality=',
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Scegli il Comune'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Scegli il Comune'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/change-municipality',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'URL municipality stays visible through prefs changes, submit and list/form navigation',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final repository = _RecordingRepository();
      final router = await _host(
        tester,
        prefs,
        repository,
        '/suggest-problem?municipality=castel-bolognese',
      );
      expect(find.text('Comune: Castel Bolognese'), findsOneWidget);
      await tester.enterText(_title, 'Alberi al parco');
      await prefs.setMunicipalityId('comune:Pincara');
      await tester.pumpAndSettle();
      expect(find.text('Comune: Castel Bolognese'), findsOneWidget);
      expect(_fieldText(tester, _title), 'Alberi al parco');
      await _completeForm(tester);
      await tester.ensureVisible(_submit);
      await tester.pumpAndSettle();
      await sendReviewedProposal(tester);
      expect(repository.submittedMunicipalities, ['castel-bolognese']);
      expect(
        router.routeInformationProvider.value.uri.path,
        startsWith('/proposal-receipt/'),
      );
      expect(find.text('Invio ricevuto'), findsOneWidget);
      await tester.ensureVisible(find.text('Torna alle proposte'));
      await tester.tap(find.text('Torna alle proposte'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/next-problems');
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['municipality'],
        'castel-bolognese',
      );
      expect(repository.listMunicipalities, [
        'castel-bolognese',
        'castel-bolognese',
      ]);
      expect(
        find.text('Comune: Castel Bolognese · Demo locale'),
        findsOneWidget,
      );
      expect(prefs.municipalityId, 'comune:Pincara');
      await tester.tap(find.byTooltip('Proponi un problema'));
      await tester.pumpAndSettle();
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['municipality'],
        'castel-bolognese',
      );
      expect(find.text('Comune: Castel Bolognese'), findsOneWidget);
    },
  );

  testWidgets(
    'deep link with no selected preference can submit to its explicit municipality',
    (tester) async {
      final prefs = await createTestPrefs({});
      final repository = _RecordingRepository();
      await _host(
        tester,
        prefs,
        repository,
        '/suggest-problem?municipality=bologna',
      );
      expect(prefs.municipalityId, isNull);
      await tester.enterText(_title, 'Alberi al parco');
      await _completeForm(tester);
      await tester.ensureVisible(_submit);
      await tester.pumpAndSettle();
      await sendReviewedProposal(tester);
      expect(repository.submittedMunicipalities, ['bologna']);
      expect(prefs.municipalityId, isNull);
    },
  );

  testWidgets(
    'query changes restore only their own draft and never overwrite prefs',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Pincara',
      });
      final router = await _host(
        tester,
        prefs,
        _RecordingRepository(),
        '/suggest-problem?municipality=bologna',
      );
      await tester.enterText(_title, '  Bozza Bologna  ');
      await _completeForm(tester);
      router.go('/suggest-problem?municipality=castel-bolognese');
      await tester.pumpAndSettle();
      expect(_fieldText(tester, _title), isEmpty);
      expect(
        tester
            .widget<DropdownButtonFormField<ProblemKey>>(_category)
            .initialValue,
        isNull,
      );
      await tester.enterText(_title, 'Bozza Castel');
      await tester.pumpAndSettle();
      router.go('/suggest-problem?municipality=unknown');
      await tester.pumpAndSettle();
      expect(
        find.text('Il Comune nel collegamento non è valido.'),
        findsOneWidget,
      );
      router.go('/suggest-problem?municipality=comune%3ABologna');
      await tester.pumpAndSettle();
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['municipality'],
        'bologna',
      );
      expect(_fieldText(tester, _title), '  Bozza Bologna  ');
      expect(
        tester
            .widget<DropdownButtonFormField<ProblemKey>>(_category)
            .initialValue,
        ProblemKey.green,
      );
      router.go('/suggest-problem?municipality=castel-bolognese');
      await tester.pumpAndSettle();
      expect(_fieldText(tester, _title), 'Bozza Castel');
      expect(prefs.municipalityId, 'comune:Pincara');
    },
  );

  testWidgets(
    'invalid URLs have no fallback, repository call or draft mutation',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final repository = _RecordingRepository();
      final router = await _host(
        tester,
        prefs,
        repository,
        '/suggest-problem?municipality=',
      );
      for (final path in ['/suggest-problem', '/next-problems']) {
        for (final query in [
          'municipality=',
          'municipality=unknown',
          'municipality=bologna&municipality=castel-bolognese',
          'municipality=comune%3A..%2FRoma',
        ]) {
          router.go('$path?$query');
          await tester.pumpAndSettle();
          expect(
            find.text('Il Comune nel collegamento non è valido.'),
            findsOneWidget,
          );
          expect(_title, findsNothing);
          expect(tester.takeException(), isNull);
        }
      }
      expect(repository.listMunicipalities, isEmpty);
      expect(repository.submittedMunicipalities, isEmpty);
      expect(prefs.localData.revision, 0);
      expect(prefs.municipalityId, 'comune:Bologna');
      await tester.tap(find.text('Scegli il Comune'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/change-municipality',
      );
      await tester.tap(find.text('Bologna'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/next-problems');
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['municipality'],
        'bologna',
      );
      expect(repository.listMunicipalities, ['bologna']);
    },
  );

  testWidgets(
    'legacy entry freezes prefs into the URL and survives reconstruction with different prefs',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Bologna',
      });
      final router = await _host(
        tester,
        prefs,
        _RecordingRepository(),
        '/suggest-problem',
      );
      final uri = router.routeInformationProvider.value.uri;
      expect(uri.queryParameters['municipality'], 'bologna');
      await tester.enterText(_title, 'Bozza del collegamento');
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await prefs.setMunicipalityId('comune:Pincara');
      await _host(tester, prefs, _RecordingRepository(), uri.toString());
      expect(find.text('Comune: Bologna'), findsOneWidget);
      expect(_fieldText(tester, _title), 'Bozza del collegamento');
      expect(prefs.municipalityId, 'comune:Pincara');
    },
  );

  testWidgets(
    'missing municipality list offers selection without loading demo data',
    (tester) async {
      final prefs = await createTestPrefs({});
      final repository = _RecordingRepository();
      final router = await _host(tester, prefs, repository, '/next-problems');
      expect(
        find.text('Scegli un Comune per vedere le proposte.'),
        findsOneWidget,
      );
      expect(repository.listMunicipalities, isEmpty);
      await tester.tap(find.text('Scegli il Comune'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bologna'));
      await tester.pumpAndSettle();
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['municipality'],
        'bologna',
      );
      expect(repository.listMunicipalities, ['bologna']);
    },
  );

  testWidgets(
    'late list results cannot replace a newer route even when IDs match',
    (tester) async {
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Pincara',
      });
      final repository = _RecordingRepository()..deferLists = true;
      final router = await _host(
        tester,
        prefs,
        repository,
        '/next-problems?municipality=bologna',
        settle: false,
      );
      expect(repository.listMunicipalities, ['bologna']);
      router.go('/next-problems?municipality=castel-bolognese');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      final example =
          await MockNextProblemsRepository(
            currentUserId: 'user:test',
          ).submitSuggestedProblem(
            municipalityId: 'bologna',
            title: 'Esempio',
            description: 'Descrizione',
            category: ProblemKey.green,
          );
      repository.pendingLists['castel-bolognese']!.complete([
        example.copyWith(id: 'same-id', title: 'Titolo Castel'),
      ]);
      await tester.pumpAndSettle();
      repository.pendingLists['bologna']!.complete([
        example.copyWith(id: 'same-id', title: 'Titolo Bologna'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Titolo Castel'), findsOneWidget);
      expect(find.text('Titolo Bologna'), findsNothing);
      expect(
        find.text('Comune: Castel Bolognese · Demo locale'),
        findsOneWidget,
      );
      expect(prefs.municipalityId, 'comune:Pincara');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<GoRouter> _host(
  WidgetTester tester,
  AppPrefs prefs,
  NextProblemsRepository repository,
  String location, {
  bool settle = true,
  AppConfig? config,
}) async {
  final appConfig = config ?? AppConfig.fromValues();
  final router = buildRouter(prefs, appConfig)..go(location);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppDependencies(
      appPrefs: prefs,
      config: appConfig,
      child: Provider<NextProblemsRepository>.value(
        value: repository,
        child: recordingSubmissionHost(
          prefs: prefs,
          repository: repository,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  if (settle) await tester.pumpAndSettle();
  return router;
}

Future<void> _completeForm(WidgetTester tester) async {
  await tester.enterText(_description, 'I rami coprono il passaggio.');
  await tester.ensureVisible(_category);
  await tester.pumpAndSettle();
  await tester.tap(_category);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Verde pubblico').last);
  await tester.pumpAndSettle();
  await chooseProposalLocation(tester);
}

String _fieldText(WidgetTester tester, Finder field) => tester
    .widget<TextField>(
      find.descendant(of: field, matching: find.byType(TextField)),
    )
    .controller!
    .text;

class _RecordingRepository extends MockNextProblemsRepository {
  _RecordingRepository() : super(currentUserId: 'user:test');
  final listMunicipalities = <String>[];
  final submittedMunicipalities = <String>[];
  bool deferLists = false;
  final pendingLists = <String, Completer<List<SuggestedProblem>>>{};

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) {
    listMunicipalities.add(municipalityId);
    if (deferLists)
      return pendingLists
          .putIfAbsent(municipalityId, Completer<List<SuggestedProblem>>.new)
          .future;
    return super.listNextProblems(
      municipalityId: municipalityId,
      query: query,
      status: status,
    );
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) {
    submittedMunicipalities.add(municipalityId);
    return super.submitSuggestedProblem(
      municipalityId: municipalityId,
      title: title,
      description: description,
      category: category,
      location: location,
    );
  }
}
