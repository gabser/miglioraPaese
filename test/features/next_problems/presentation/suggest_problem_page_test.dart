import '../../../helpers/submission_test_provider.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import '../../../helpers/proposal_form_actions.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/promotion_rule.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/presentation/suggest_problem_page.dart';
import '../../../helpers/test_app.dart';

final _title = find.byKey(const ValueKey('proposal-title'));
final _description = find.byKey(const ValueKey('proposal-description'));
final _submit = find.byKey(const ValueKey('proposal-submit'));

Future<_RecordingRepository> _pump(
  WidgetTester tester, {
  String? municipality = 'comune:Bologna',
  Size size = const Size(390, 844),
  double scale = 1,
  double keyboard = 0,
  AppConfig? config,
  Future<void>? preparation,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = await createTestPrefs({
    if (municipality != null) 'municipality_id': municipality,
    'user_id': 'user:test',
  });
  final repository = _RecordingRepository()..preparation = preparation;
  final router = GoRouter(
    initialLocation: '/suggest-problem',
    routes: [
      receiptTestRoute(prefs),
      GoRoute(
        path: '/suggest-problem',
        builder: (_, _) =>
            SuggestProblemPage(tileProvider: LocalProposalTiles()),
      ),
      GoRoute(
        path: '/next-problems',
        builder: (_, _) => const Scaffold(body: Text('Lista proposte')),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, _) => const Scaffold(body: Text('Selezione Comune')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<TileProvider>.value(value: LocalProposalTiles()),
        Provider<AppConfig>.value(value: config ?? AppConfig.fromValues()),
        ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        Provider<NextProblemsRepository>.value(value: repository),
      ],
      child: recordingSubmissionHost(
        prefs: prefs,
        repository: repository,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> _send(WidgetTester tester) => sendReviewedProposal(tester);

void main() {
  testWidgets('API capability gate retains answers and supports retry', (
    tester,
  ) async {
    final preparing = Completer<void>();
    final repository = await _pump(
      tester,
      config: AppConfig.fromValues(nextProblemsDataSource: 'api'),
      preparation: preparing.future,
    );
    await chooseProposalCase(tester);
    expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
    preparing.completeError(StateError('Unavailable'));
    await tester.pumpAndSettle();
    repository.preparation = Future.value();
    await tapProposal(tester, find.text('Riprova la verifica'));
    expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('proposal-category-green-choice')),
          )
          .selected,
      isTrue,
    );
    expect(repository.submissions, isEmpty);
  });

  testWidgets('category, scenario and custom description are explicit', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await nextProposalStep(tester);
    expect(find.text('Scegli una categoria.'), findsOneWidget);
    await tapProposal(
      tester,
      find.byKey(const ValueKey('proposal-category-green-choice')),
    );
    await nextProposalStep(tester);
    expect(find.text('Scegli il tuo caso.'), findsOneWidget);
    await tapProposal(tester, find.text('Il mio caso è diverso'));
    await nextProposalStep(tester);
    expect(find.text('Descrizione obbligatoria.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('proposal-custom-description')),
      'Una radice solleva il percorso.',
    );
    await nextProposalStep(tester);
    await chooseProposalLocation(tester);
    await nextProposalStep(tester);
    expect(_fieldText(tester, _title), 'Verde pubblico');
    expect(
      _fieldText(tester, _description),
      contains('Una radice solleva il percorso.'),
    );
    expect(repository.submissions, isEmpty);
  });

  testWidgets('no-keyboard journey: preset, pin, summary, receipt', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await chooseProposalCase(
      tester,
      category: 'lighting',
      scenario: 'Lampione spento',
    );
    await tapProposal(tester, find.text('2'));
    await nextProposalStep(tester);
    await chooseProposalLocation(tester, label: 'Luogo specifico');
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Seleziona il centro'),
          )
          .onPressed,
      isNotNull,
    );
    await tapProposal(tester, find.text('Seleziona il centro'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Usa questo punto'),
          )
          .onPressed,
      isNotNull,
    );
    await tapProposal(tester, find.text('Usa questo punto'));
    expect(find.text('Rimuovi pin'), findsOneWidget);
    await nextProposalStep(tester);
    expect(
      _fieldText(tester, _description),
      contains('Numero di lampioni: 2.'),
    );
    expect(_fieldText(tester, _description), contains('Punto sulla mappa'));
    expect(repository.submissions, isEmpty);
    await _send(tester);
    final place = repository.submissions.single['location'] as ProposalLocation;
    expect(place.label, isNull);
    expect(place.coordinates, isNotNull);
    expect(find.text('Invio ricevuto'), findsOneWidget);
  });

  testWidgets(
    'text-only place, back navigation and explicit regeneration preserve manual text',
    (tester) async {
      final repository = await _pump(tester);
      await chooseProposalCase(tester);
      await nextProposalStep(tester);
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      final label = find.byKey(const ValueKey('proposal-location-label'));
      await tester.enterText(label, ' Via Milano ');
      await nextProposalStep(tester);
      await tester.enterText(_title, 'Titolo personalizzato');
      await tester.enterText(_description, 'Descrizione personalizzata.');
      await tapProposal(tester, find.text('Modifica luogo'));
      await tester.enterText(label, 'Parco delle Rose');
      await nextProposalStep(tester);
      expect(_fieldText(tester, _title), 'Titolo personalizzato');
      expect(_fieldText(tester, _description), 'Descrizione personalizzata.');
      await tapProposal(tester, find.text('Rigenera testo dalle scelte'));
      expect(_fieldText(tester, _title), 'Ramo sul passaggio');
      expect(_fieldText(tester, _description), contains('Parco delle Rose'));
      await _send(tester);
      expect(
        repository.submissions.single['location'],
        ProposalLocation.specific(label: 'Parco delle Rose'),
      );
    },
  );

  testWidgets(
    'switching kinds retains raw references but removes pin for Intero Comune',
    (tester) async {
      final repository = await _pump(tester);
      await chooseProposalCase(tester);
      await nextProposalStep(tester);
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      await tapProposal(tester, find.text('Seleziona il centro'));
      await tapProposal(tester, find.text('Usa questo punto'));
      await tapProposal(tester, find.text('Aggiungi dettagli del luogo'));
      final civic = find.byKey(const ValueKey('proposal-location-civic'));
      await tester.enterText(civic, ' 12/A ');
      await chooseProposalLocation(tester);
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      expect(find.textContaining('Punto confermato:'), findsNothing);
      if (civic.evaluate().isEmpty)
        await tapProposal(tester, find.text('Aggiungi dettagli del luogo'));
      expect(_fieldText(tester, civic), ' 12/A ');
      await chooseProposalLocation(tester);
      await _send(tester);
      expect(
        (repository.submissions.single['location'] as ProposalLocation)
            .toJson(),
        {'kind': 'municipality'},
      );
    },
  );

  testWidgets(
    'place and optional Unicode limits block the next step without losing input',
    (tester) async {
      final repository = await _pump(tester);
      await chooseProposalCase(tester);
      await nextProposalStep(tester);
      await nextProposalStep(tester);
      expect(find.text('Scegli il tipo di luogo.'), findsOneWidget);
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      await nextProposalStep(tester);
      expect(find.text('Luogo obbligatorio.'), findsOneWidget);
      final label = find.byKey(const ValueKey('proposal-location-label'));
      await tester.enterText(label, '😀' * 121);
      await nextProposalStep(tester);
      expect(find.text('Usa al massimo 120 caratteri.'), findsOneWidget);
      await tester.enterText(label, 'Via Milano');
      await tapProposal(tester, find.text('Aggiungi dettagli del luogo'));
      for (final entry in [
        ('proposal-location-civic', 20),
        ('proposal-location-reference', 200),
      ]) {
        final field = find.byKey(ValueKey(entry.$1));
        await tester.enterText(field, '😀' * (entry.$2 + 1));
        await nextProposalStep(tester);
        expect(
          find.text('Usa al massimo ${entry.$2} caratteri.'),
          findsOneWidget,
        );
        expect(_fieldText(tester, field), '😀' * (entry.$2 + 1));
        await tester.enterText(field, '😀' * entry.$2);
      }
      expect(repository.submissions, isEmpty);
      await _send(tester);
      expect(repository.submissions, hasLength(1));
    },
  );

  for (final entry in [
    (ProposalLimits.title, _title),
    (ProposalLimits.description, _description),
  ]) {
    testWidgets('summary Unicode limit ${entry.$1} preserves over-limit text', (
      tester,
    ) async {
      final repository = await _pump(tester);
      await openProposalReview(tester);
      for (final length in [entry.$1 - 1, entry.$1, entry.$1 + 1]) {
        final text = '  👩\u200d🌳${List.filled(length - 3, '😀').join()}  ';
        await tester.enterText(entry.$2, text);
        await tester.pump();
        expect(find.text('$length/${entry.$1}'), findsOneWidget);
        await nextProposalStep(tester); // comparison only for valid text
        expect(repository.submissions, isEmpty);
        expect(
          find.text('Usa al massimo ${entry.$1} caratteri.'),
          length > entry.$1 ? findsOneWidget : findsNothing,
        );
        expect(_fieldText(tester, entry.$2), text);
      }
    });
  }

  testWidgets('demo keeps the textual alternative', (tester) async {
    final repository = await _pump(tester, municipality: 'demo');
    await chooseProposalCase(tester);
    await nextProposalStep(tester);
    await chooseProposalLocation(tester, label: 'Luogo specifico');
    expect(find.text('Seleziona il centro'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('proposal-location-label')),
      'Parco',
    );
    await _send(tester);
    expect(repository.submissions, hasLength(1));
  });

  testWidgets('missing municipality disables submit and offers selection', (
    tester,
  ) async {
    await _pump(tester, municipality: null);
    expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
    await tapProposal(tester, find.text('Scegli il Comune'));
    expect(find.text('Selezione Comune'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'guided flow and summary fit 200% text with keyboard at ${size.width}',
      (tester) async {
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        final repository = await _pump(
          tester,
          size: size,
          scale: 2,
          keyboard: 240,
        );
        await openProposalReview(tester);
        await tester.enterText(_title, 'T' * 110);
        await tester.enterText(_description, 'D' * 950);
        await _send(tester);
        expect(repository.submissions, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

String _fieldText(WidgetTester tester, Finder finder) => tester
    .widget<TextField>(
      find.descendant(of: finder, matching: find.byType(TextField)),
    )
    .controller!
    .text;

class _RecordingRepository
    implements NextProblemsRepository, ProposalFormCapabilities {
  Future<void>? preparation;
  @override
  Future<void> prepareProposalForm() => preparation ?? Future.value();
  @override
  Future<SuggestedProblem> getSuggestedProblem({
    required String municipalityId,
    required String problemId,
  }) => Future.error(StateError('Detail is not part of this test fixture.'));

  final submissions = <Map<String, Object>>[];

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) async {
    submissions.add({
      'municipality': municipalityId,
      'title': title,
      'description': description,
      'category': category,
      if (location != null) 'location': location,
    });
    return SuggestedProblem(
      id: 'saved-proposal',
      title: title,
      shortDescription: description,
      location: location,
      category: category,
      createdAt: DateTime.utc(2026, 10, 10),
      status: SuggestedProblemStatus.pending,
      votesUp: 0,
      votesDown: 0,
      myVote: VoteChoice.none,
      submittedByDisplayName: 'Tu',
      promotionRule: const PromotionRule(
        threshold: 1,
        scopeLabel: 'Bologna',
        reason: 'Demo',
      ),
    );
  }

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async => [];

  @override
  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) => throw UnimplementedError();
}
