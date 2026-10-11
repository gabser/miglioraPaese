import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/home/presentation/home_page.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  for (final city in ['Pincara', 'Bologna']) {
    for (final size in [
      const Size(320, 640),
      const Size(390, 844),
      const Size(1440, 900),
    ]) {
      testWidgets(
        '$city home uses real local state without overflow at ${size.width}',
        (tester) async {
          await _pumpHome(tester, city: city, size: size, scale: 2);
          expect(
            find.text('Comune: $city · Gioco delle previsioni'),
            findsOneWidget,
          );
          if (city == 'Pincara') {
            expect(find.text('Gioca il turno'), findsNothing);
            expect(find.text('Proponi il primo tema'), findsOneWidget);
          } else {
            expect(find.text('Gioca il turno'), findsOneWidget);
            expect(find.textContaining('andamento del tema'), findsWidgets);
            expect(
              find.text('Punti maturati nel gioco delle previsioni'),
              findsOneWidget,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('town with a pending proposal explains collected signals', (
    tester,
  ) async {
    await _pumpHome(tester, city: 'Pincara', pending: true);
    expect(find.text('Primi segnali raccolti'), findsOneWidget);
    expect(find.textContaining('1 proposta locale'), findsOneWidget);
    expect(find.text('Gioca il turno'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required String city,
  Size size = const Size(390, 844),
  double scale = 1,
  bool pending = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final prefs = await createTestPrefs({
    'municipality_id': 'comune:$city',
    'user_id': 'user:test',
  });
  final store = CivicLoopStore(currentUserId: prefs.userId);
  if (pending) {
    await MockNextProblemsRepository(
      currentUserId: prefs.userId,
      store: store,
    ).submitSuggestedProblem(
      municipalityId: 'comune:$city',
      title: 'Alberi da potare',
      description: 'Rami sul percorso',
      category: ProblemKey.green,
    );
  }
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppPrefs>.value(value: prefs),
        Provider<GameRepository>.value(
          value: MockGameRepository(civicLoopStore: store),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: HomePage()),
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
