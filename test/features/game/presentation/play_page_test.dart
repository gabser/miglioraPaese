import 'package:flutter/material.dart';
import 'package:fanta_comune/core/widgets/segmented_choice.dart';
import 'package:fanta_comune/features/game/domain/prediction_choice.dart';
import 'package:fanta_comune/features/game/domain/hypothesis_confidence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/presentation/play/play_page.dart';
import '../../../helpers/test_app.dart';

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'Play shows real progress and optional summary at $width with large text',
      (tester) async {
        await _pump(tester, width: width, scale: 2);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('play-progress')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('0 di 2'), findsOneWidget);
        final summary = find.text('Riepilogo del Comune');
        await tester.scrollUntilVisible(
          summary,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(summary);
        await tester.pumpAndSettle();
        await tester.tap(summary);
        await tester.pumpAndSettle();
        expect(find.text('Riepilogo Bologna'), findsOneWidget);
        final card = find.text('Problema 1 di 2');
        await tester.scrollUntilVisible(
          card,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(card, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Play without cards offers a proposal rather than fabricated progress at $width',
      (tester) async {
        await _pump(tester, width: width, scale: 2, empty: true);
        expect(find.byKey(const ValueKey('play-progress')), findsNothing);
        final cta = find.widgetWithText(FilledButton, 'Proponi il primo tema');
        await tester.scrollUntilVisible(
          cta,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(cta);
        await tester.pumpAndSettle();
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(find.text('Form proposte'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'prediction updates progress and stays immutable while confidence remains editable',
    (tester) async {
      await _pump(tester, width: 390);
      await tester.scrollUntilVisible(
        find.text('Problema 1 di 2'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final improve = find
          .descendant(
            of: find.byType(SegmentedChoice<PredictionChoice>),
            matching: find.text('Migliora'),
          )
          .first;
      await tester.scrollUntilVisible(
        improve,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(improve);
      await tester.pumpAndSettle();
      await tester.tap(improve);
      await tester.pumpAndSettle();
      expect(find.text('Carta giocata'), findsOneWidget);
      expect(find.text('Quanto ci credi?'), findsOneWidget);
      final stable = find
          .descendant(
            of: find.byType(SegmentedChoice<PredictionChoice>),
            matching: find.text('Stabile'),
          )
          .first;
      await tester.ensureVisible(stable);
      await tester.tap(stable);
      await tester.pumpAndSettle();
      expect(find.text('Carta giocata'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedChoice<PredictionChoice>>(
              find.byType(SegmentedChoice<PredictionChoice>).first,
            )
            .value,
        PredictionChoice.improve,
      );
      final confident = find.descendant(
        of: find.byType(SegmentedChoice<HypothesisConfidence>).first,
        matching: find.text('Abbastanza convinto'),
      );
      await tester.scrollUntilVisible(
        confident,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(confident);
      await tester.pumpAndSettle();
      await tester.tap(confident);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SegmentedChoice<HypothesisConfidence>>(
              find.byType(SegmentedChoice<HypothesisConfidence>).first,
            )
            .value,
        HypothesisConfidence.convinced,
      );
      final progress = find.byKey(const ValueKey('play-progress'));
      await tester.scrollUntilVisible(
        progress,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('1 di 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double scale = 1,
  bool empty = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = await createTestPrefs({
    'municipality_id': empty ? 'comune:Pincara' : 'comune:Bologna',
    'user_id': 'user:test',
  });
  final router = GoRouter(
    initialLocation: '/play',
    routes: [
      GoRoute(
        path: '/play',
        builder: (_, _) => const Scaffold(body: PlayPage()),
      ),
      GoRoute(
        path: '/suggest-problem',
        builder: (_, _) => const Scaffold(body: Text('Form proposte')),
      ),
      GoRoute(
        path: '/board',
        builder: (_, _) => const Scaffold(body: Text('Tabellone')),
      ),
      GoRoute(
        path: '/next-problems',
        builder: (_, _) => const Scaffold(body: Text('Lista proposte')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        Provider<GameRepository>.value(value: _TwoProblemsRepository()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
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

class _TwoProblemsRepository extends MockGameRepository {
  @override
  Future<List<Problem>> listProblems(String municipalityId) async =>
      (await super.listProblems(municipalityId)).take(2).toList();
}
