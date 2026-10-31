import '../../../helpers/submission_test_provider.dart';
import 'dart:async';
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
final _category = find.byKey(const ValueKey('proposal-category'));
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
        builder: (_, _) => const SuggestProblemPage(),
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
  testWidgets(
    'API capability gate blocks new fields and submit, preserves draft and supports retry',
    (tester) async {
      final preparing = Completer<void>();
      final repository = await _pump(
        tester,
        config: AppConfig.fromValues(nextProblemsDataSource: 'api'),
        preparation: preparing.future,
      );
      await tester.enterText(_title, 'Bozza da conservare');
      await tester.pump();
      expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
      expect(
        tester
            .widget<DropdownButtonFormField<ProposalLocationKind>>(
              find.byKey(const ValueKey('proposal-location-kind')),
            )
            .onChanged,
        isNull,
      );
      preparing.completeError(StateError('Capabilities unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Riprova la verifica'), findsOneWidget);
      repository.preparation = Future.value();
      await tester.ensureVisible(find.text('Riprova la verifica'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riprova la verifica'));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(_submit).onPressed, isNotNull);
      expect(
        tester
            .widget<DropdownButtonFormField<ProposalLocationKind>>(
              find.byKey(const ValueKey('proposal-location-kind')),
            )
            .onChanged,
        isNotNull,
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: _title, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        'Bozza da conservare',
      );
      expect(repository.submissions, isEmpty);
    },
  );
  testWidgets(
    'specific place without civic is reviewed, editable and submitted explicitly',
    (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(_title, 'Potatura');
      await tester.enterText(_description, 'I rami coprono il passaggio.');
      await tester.ensureVisible(_category);
      await tester.pumpAndSettle();
      await tester.tap(_category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verde pubblico').last);
      await tester.pumpAndSettle();
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      final label = find.byKey(const ValueKey('proposal-location-label'));
      await tester.enterText(label, '  Via Milano  ');
      await tester.ensureVisible(_submit);
      await tester.pumpAndSettle();
      await tester.ensureVisible(_submit);
      await tester.pumpAndSettle();
      await tester.tap(_submit);
      await tester.pumpAndSettle();
      expect(repository.submissions, isEmpty);
      expect(find.text('Riepilogo della proposta'), findsOneWidget);
      expect(find.text('Via Milano'), findsOneWidget);
      await tester.ensureVisible(find.text('Modifica nome del luogo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Modifica nome del luogo'));
      await tester.pumpAndSettle();
      expect(find.text('Riepilogo della proposta'), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: label, matching: find.byType(TextField)),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(label, 'Parco delle Rose, ingresso nord');
      await _send(tester);
      expect(
        repository.submissions.single['location'],
        ProposalLocation.specific(label: 'Parco delle Rose, ingresso nord'),
      );
      expect(find.text('Invio ricevuto'), findsOneWidget);
    },
  );

  testWidgets(
    'switching kinds retains optional raw references but municipality payload omits them',
    (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(_title, 'Alberi');
      await tester.enterText(_description, 'Serve ombra.');
      await tester.ensureVisible(_category);
      await tester.pumpAndSettle();
      await tester.tap(_category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verde pubblico').last);
      await tester.pumpAndSettle();
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      await tester.enterText(
        find.byKey(const ValueKey('proposal-location-label')),
        'Via 8 Marzo',
      );
      final optional = find.text('Riferimenti facoltativi');
      await tester.ensureVisible(optional);
      await tester.pumpAndSettle();
      await tester.tap(optional);
      await tester.pumpAndSettle();
      final civic = find.byKey(const ValueKey('proposal-location-civic'));
      final reference = find.byKey(
        const ValueKey('proposal-location-reference'),
      );
      await tester.enterText(civic, ' 12/A ');
      await tester.enterText(reference, ' Tra il parco e l’incrocio ');
      await chooseProposalLocation(tester);
      expect(civic, findsNothing);
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      if (civic.evaluate().isEmpty) {
        await tester.ensureVisible(optional);
        await tester.pumpAndSettle();
        await tester.tap(optional);
        await tester.pumpAndSettle();
      }
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: civic, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        ' 12/A ',
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: reference, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        ' Tra il parco e l’incrocio ',
      );
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
    'required kind, label and optional Unicode limits preserve input and block review',
    (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(_title, 'Alberi');
      await tester.enterText(_description, 'Serve ombra.');
      await tester.ensureVisible(_category);
      await tester.pumpAndSettle();
      await tester.tap(_category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verde pubblico').last);
      await tester.pumpAndSettle();
      await _send(tester);
      expect(find.text('Scegli il tipo di luogo.'), findsOneWidget);
      await chooseProposalLocation(tester, label: 'Luogo specifico');
      await _send(tester);
      expect(find.text('Luogo obbligatorio.'), findsOneWidget);
      final label = find.byKey(const ValueKey('proposal-location-label'));
      await tester.enterText(label, '😀' * 121);
      await _send(tester);
      expect(find.text('Usa al massimo 120 caratteri.'), findsOneWidget);
      await tester.enterText(label, 'Via Milano');
      final optional = find.text('Riferimenti facoltativi');
      await tester.ensureVisible(optional);
      await tester.pumpAndSettle();
      await tester.tap(optional);
      await tester.pumpAndSettle();
      final civic = find.byKey(const ValueKey('proposal-location-civic'));
      await tester.enterText(civic, '😀' * 21);
      await _send(tester);
      expect(find.text('Usa al massimo 20 caratteri.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: civic, matching: find.byType(TextField)),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(repository.submissions, isEmpty);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: civic, matching: find.byType(TextField)),
            )
            .controller!
            .text,
        '😀' * 21,
      );
      await tester.enterText(civic, '12/A');
      final reference = find.byKey(
        const ValueKey('proposal-location-reference'),
      );
      await tester.enterText(reference, '😀' * 201);
      await _send(tester);
      expect(find.text('Usa al massimo 200 caratteri.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: reference, matching: find.byType(TextField)),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(repository.submissions, isEmpty);
      await tester.enterText(reference, '😀' * 200);
      await _send(tester);
      final location =
          repository.submissions.single['location'] as ProposalLocation;
      expect(location.civic, '12/A');
      expect(location.reference!.runes.length, 200);
    },
  );

  for (final entry in [
    (ProposalLimits.title, _title, 'Titolo'),
    (ProposalLimits.description, _description, 'Descrizione'),
  ]) {
    testWidgets(
      '${entry.$3} preserves over-limit Unicode input and shows consistent counters',
      (tester) async {
        final repository = await _pump(tester);
        for (final length in [entry.$1 - 1, entry.$1, entry.$1 + 1]) {
          final text = '  👩\u200d🌳${List.filled(length - 3, '😀').join()}  ';
          await tester.enterText(entry.$2, text);
          await tester.pump();
          expect(find.text('$length/${entry.$1}'), findsOneWidget);
          await _send(tester);
          expect(repository.submissions, isEmpty);
          expect(
            find.text('Usa al massimo ${entry.$1} caratteri.'),
            length > entry.$1 ? findsOneWidget : findsNothing,
          );
          final field = tester.widget<TextField>(
            find.descendant(of: entry.$2, matching: find.byType(TextField)),
          );
          expect(field.controller!.text, text);
          // Material counts graphemes without trim; only our validator/counter
          // enforce the shared code-point contract.
          expect(field.maxLength, isNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'required errors preserve text and focus the first invalid field',
    (tester) async {
      final repository = await _pump(tester);
      expect(find.text('Comune: Bologna'), findsOneWidget);
      final category = tester.widget<DropdownButtonFormField<ProblemKey>>(
        _category,
      );
      expect(category.initialValue, isNull);
      await _send(tester);
      expect(repository.submissions, isEmpty);
      expect(find.text('Titolo obbligatorio.'), findsOneWidget);
      expect(find.text('Descrizione obbligatoria.'), findsOneWidget);
      expect(find.text('Scegli una categoria.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: _title, matching: find.byType(TextField)),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(_title, 'Alberi da potare');
      await _send(tester);
      expect(find.text('Alberi da potare'), findsOneWidget);
      expect(find.text('Titolo obbligatorio.'), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: _description,
                matching: find.byType(TextField),
              ),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'category must be explicit and the chosen enum is submitted with municipality',
    (tester) async {
      final repository = await _pump(tester);
      await tester.enterText(_title, 'Alberi da potare');
      await tester.enterText(
        _description,
        'I rami coprono il passaggio pedonale.',
      );
      await _send(tester);
      expect(repository.submissions, isEmpty);
      await tester.ensureVisible(_category);
      await tester.tap(_category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verde pubblico').last);
      await tester.pumpAndSettle();
      await chooseProposalLocation(tester);
      await _send(tester);
      expect(repository.submissions.single, {
        'municipality': 'bologna',
        'title': 'Alberi da potare',
        'description': 'I rami coprono il passaggio pedonale.',
        'category': ProblemKey.green,
        'location': const ProposalLocation.municipality(),
      });
      expect(find.text('Invio ricevuto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing municipality disables submit and offers selection', (
    tester,
  ) async {
    final repository = await _pump(tester, municipality: null);
    expect(tester.widget<FilledButton>(_submit).onPressed, isNull);
    expect(repository.submissions, isEmpty);
    await tester.tap(find.text('Scegli il Comune'));
    await tester.pumpAndSettle();
    expect(find.text('Selezione Comune'), findsOneWidget);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1440, 900),
  ]) {
    testWidgets(
      'place and full review submit with long content, keyboard and 200% text at ${size.width}',
      (tester) async {
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        final repository = await _pump(
          tester,
          size: size,
          scale: 2,
          keyboard: 240,
        );
        await tester.enterText(_title, 'T' * 110);
        await tester.enterText(_description, 'D' * 950);
        await tester.ensureVisible(_category);
        await tester.pumpAndSettle();
        await tester.tap(_category);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Verde pubblico').last);
        await tester.pumpAndSettle();
        await chooseProposalLocation(tester, label: 'Luogo specifico');
        await tester.enterText(
          find.byKey(const ValueKey('proposal-location-label')),
          'Parco ${'L' * 110}',
        );
        final details = find.text('Riferimenti facoltativi');
        await tester.ensureVisible(details);
        await tester.pumpAndSettle();
        await tester.ensureVisible(details);
        await tester.pumpAndSettle();
        await tester.tap(details);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('proposal-location-civic')),
          '12/A',
        );
        await tester.enterText(
          find.byKey(const ValueKey('proposal-location-reference')),
          'R' * 190,
        );
        await _send(tester);
        expect(repository.submissions, hasLength(1));
        final place =
            repository.submissions.single['location'] as ProposalLocation;
        expect(place.civic, '12/A');
        expect(place.reference, 'R' * 190);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'form scrolls to submit with keyboard and large text at ${size.width}',
      (tester) async {
        await _pump(tester, size: size, scale: 2, keyboard: 240);
        await tester.enterText(_title, 'Problema visibile');
        await _send(tester);
        expect(find.text('Descrizione obbligatoria.'), findsOneWidget);
        expect(find.text('Problema visibile'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

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
