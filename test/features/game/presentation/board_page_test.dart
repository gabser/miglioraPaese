import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/game/domain/problem.dart';
import 'package:fanta_comune/features/game/domain/problem_status.dart';
import 'package:fanta_comune/features/game/presentation/board/board_page.dart';
import '../../../helpers/test_app.dart';

final _problems = [
  Problem(
    id: 'green',
    key: ProblemKey.green,
    title:
        'Alberi con rami che coprono il percorso pedonale e rendono difficile il passaggio',
    zoneName: 'Parco con un nome molto lungo vicino alla scuola',
    status: ProblemStatus.improving,
    trendPercent: 10,
    updatedAt: DateTime.utc(2026, 10, 9),
  ),
  Problem(
    id: 'light',
    key: ProblemKey.lighting,
    title: 'Lampioni spenti',
    zoneName: 'Via Roma',
    status: ProblemStatus.worsening,
    trendPercent: -25,
    updatedAt: DateTime.utc(2026, 10, 10),
  ),
];

void main() {
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('long board cards and controls fit at $width with 200% text', (
      tester,
    ) async {
      await _pump(tester, width: width, scale: 2);
      expect(find.text('Bologna'), findsOneWidget);
      expect(find.text(_problems.first.title), findsOneWidget);
      expect(find.text('Zona: ${_problems.first.zoneName}'), findsOneWidget);
      expect(find.text('-25% andamento del tema'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'real empty board gives observable categories and proposal navigation at $width',
      (tester) async {
        await _pump(tester, width: width, scale: 2, empty: true);
        expect(find.text('Cosa puoi osservare'), findsOneWidget);
        final cta = find.widgetWithText(FilledButton, 'Proponi il primo tema');
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
    'search empty resets, category filters, and title sorting changes order',
    (tester) async {
      await _pump(tester, width: 390);
      final search = find.byKey(const ValueKey('board-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'inesistente');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nessun problema corrisponde'),
        findsOneWidget,
      );
      expect(find.text('Cosa puoi osservare'), findsNothing);
      final reset = find.byKey(const ValueKey('board-clear-filters'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(search).controller!.text, isEmpty);
      final green = find.byKey(const ValueKey('board-problem-green'));
      final light = find.byKey(const ValueKey('board-problem-light'));
      expect(
        tester.getTopLeft(light).dy,
        lessThan(tester.getTopLeft(green).dy),
      );
      final sort = find.byKey(const ValueKey('board-sort'));
      await tester.ensureVisible(sort);
      await tester.tap(sort);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Titolo A–Z').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(green).dy,
        lessThan(tester.getTopLeft(light).dy),
      );
      final category = find.byKey(const ValueKey('board-category-null'));
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verde pubblico').last);
      await tester.pumpAndSettle();
      expect(green, findsOneWidget);
      expect(light, findsNothing);
      expect(find.text('1 di 2 problemi'), findsOneWidget);
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
    initialLocation: '/board',
    routes: [
      GoRoute(path: '/board', builder: (_, _) => const BoardPage()),
      GoRoute(
        path: '/suggest-problem',
        builder: (_, _) => const Scaffold(body: Text('Form proposte')),
      ),
      GoRoute(
        path: '/play',
        builder: (_, _) => const Scaffold(body: Text('Turno')),
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
        Provider<GameRepository>.value(value: _Repository(empty: empty)),
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

class _Repository extends MockGameRepository {
  _Repository({required this.empty});
  final bool empty;
  @override
  Future<List<Problem>> listProblems(String municipalityId) async =>
      empty ? [] : _problems;
}
