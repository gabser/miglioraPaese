import 'package:fanta_comune/features/next_problems/domain/proposal_location.dart';
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/domain/promotion_rule.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem.dart';
import 'package:fanta_comune/features/next_problems/domain/suggested_problem_status.dart';
import 'package:fanta_comune/features/next_problems/domain/vote_choice.dart';
import 'package:fanta_comune/features/next_problems/presentation/next_problems_page.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'failed vote preserves card and never announces success at $width',
      (tester) async {
        final repository = _RetryRepository()..calls = 1;
        await _pumpList(tester, repository, width: width);
        final vote = find.widgetWithText(
          OutlinedButton,
          VenialCopy.nextProblemsVoteUpLabel,
        );
        await tester.ensureVisible(vote);
        await tester.pumpAndSettle();
        await tester.tap(vote);
        await tester.pumpAndSettle();
        expect(find.text('Segnato.'), findsNothing);
        expect(
          find.textContaining('Il voto non è stato registrato'),
          findsOneWidget,
        );
        expect(find.text('Illuminazione al parco'), findsOneWidget);
        expect(find.text('Temi non disponibili'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'filtered empty resets the search and has no activation badge at $width',
      (tester) async {
        final repository = _RetryRepository()..calls = 1;
        await _pumpList(tester, repository, width: width, scale: 2);
        final search = find.byKey(const ValueKey('next-problems-search'));
        await tester.enterText(search, 'inesistente');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(find.text(VenialCopy.activationTitle), findsNothing);
        final reset = find.byKey(const ValueKey('next-problems-clear-filters'));
        await tester.scrollUntilVisible(
          reset,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(search).controller!.text, isEmpty);
        expect(find.text('Illuminazione al parco'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty proposals do not imply municipality activation', (
    tester,
  ) async {
    final repository = _RetryRepository()
      ..calls = 1
      ..forceEmpty = true;
    await _pumpList(tester, repository, width: 390, scale: 2);
    expect(find.text('Nessuna proposta'), findsOneWidget);
    expect(find.text(VenialCopy.activationTitle), findsNothing);
    expect(find.text(VenialCopy.nextProblemsActivationEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'successful vote announces success, updates count and selected semantics',
    (tester) async {
      final repository = _RetryRepository()
        ..calls = 1
        ..failVote = false;
      await _pumpList(tester, repository, width: 390);
      final semantics = tester.ensureSemantics();
      final vote = find.widgetWithText(
        OutlinedButton,
        VenialCopy.nextProblemsVoteUpLabel,
      );
      await tester.ensureVisible(vote);
      await tester.pumpAndSettle();
      expect(tester.getSize(vote).height, greaterThanOrEqualTo(48));
      await tester.tap(vote);
      await tester.pumpAndSettle();
      expect(find.text('Segnato.'), findsOneWidget);
      final selected = find.bySemanticsLabel(
        '${VenialCopy.nextProblemsVoteUpLabel} per Illuminazione al parco, 1 voti',
      );
      expect(selected, findsOneWidget);
      expect(
        tester.getSemantics(selected).flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('shows a human error and retries successfully on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'municipality_id': 'comune:Bologna',
      'user_id': 'user:test',
    });
    final prefs = await AppPrefs.init();
    final repository = _RetryRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppPrefs>.value(value: prefs),
          Provider<NextProblemsRepository>.value(value: repository),
        ],
        child: const MaterialApp(home: NextProblemsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temi non disponibili'), findsOneWidget);
    expect(find.textContaining('Controlla la connessione'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final retryButton = find.byKey(const ValueKey('next-problems-retry'));
    await tester.ensureVisible(retryButton);
    await tester.pumpAndSettle();
    await tester.tap(retryButton);
    await tester.pumpAndSettle();

    expect(repository.calls, 2);
    expect(find.text('Illuminazione al parco'), findsOneWidget);
    expect(find.text('Temi non disponibili'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpList(
  WidgetTester tester,
  NextProblemsRepository repository, {
  required double width,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    'municipality_id': 'comune:Bologna',
    'user_id': 'user:test',
  });
  final prefs = await AppPrefs.init();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        Provider<NextProblemsRepository>.value(value: repository),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const NextProblemsPage(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _RetryRepository implements NextProblemsRepository {
  @override
  Future<SuggestedProblem> getSuggestedProblem({
    required String municipalityId,
    required String problemId,
  }) => Future.error(StateError('Detail is not part of this test fixture.'));

  int calls = 0;
  bool failVote = true;
  bool forceEmpty = false;

  @override
  Future<List<SuggestedProblem>> listNextProblems({
    required String municipalityId,
    String? query,
    SuggestedProblemStatus? status,
  }) async {
    calls++;
    if (calls == 1) {
      throw const ApiException(
        kind: ApiExceptionKind.network,
        code: 'network_error',
        message: 'socket failed',
      );
    }
    return !forceEmpty && query == null ? [_problem()] : [];
  }

  @override
  Future<SuggestedProblem> submitSuggestedProblem({
    required String municipalityId,
    required String title,
    required String description,
    required ProblemKey category,
    ProposalLocation? location,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SuggestedProblem> voteSuggestedProblem({
    required String municipalityId,
    required String problemId,
    required VoteChoice vote,
  }) async {
    if (failVote) throw StateError('Vote unavailable');
    return _problem().copyWith(
      votesUp: 1,
      myVote: vote,
      status: SuggestedProblemStatus.approved,
    );
  }
}

SuggestedProblem _problem() {
  return SuggestedProblem(
    id: 'suggested-1',
    title: 'Illuminazione al parco',
    shortDescription: 'Percorsi poco leggibili la sera.',
    category: ProblemKey.lighting,
    createdAt: DateTime.utc(2026, 7, 4),
    status: SuggestedProblemStatus.pending,
    votesUp: 0,
    votesDown: 0,
    myVote: VoteChoice.none,
    submittedByDisplayName: 'Tu',
    promotionRule: const PromotionRule(
      threshold: 1,
      scopeLabel: 'Bologna · illuminazione',
      reason: 'Una approvazione netta promuove il tema.',
    ),
  );
}
