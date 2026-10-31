import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/config/app_config.dart';

import '../../helpers/test_app.dart';
import '../fantasy/fantasy_test_support.dart';

void main() {
  testWidgets('map route is disabled by default', (tester) async {
    final prefs = await createTestPrefs({'municipality_id': 'comune:Tuglie'});
    await tester.pumpWidget(buildTestApp(prefs));
    await tester.pump();
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
            as GoRouter;
    router.go('/map?municipality=tuglie');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 1));
    expect(router.routeInformationProvider.value.uri.path, '/home');
    for (final route in ['/home', '/board', '/next-problems']) {
      router.go(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('Mappa / Elenco'), findsNothing);
    }
    router.go('/privacy');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('map route keeps selected municipality and rejects mismatch', (
    tester,
  ) async {
    final prefs = await createTestPrefs({'municipality_id': 'comune:Tuglie'});
    await tester.pumpWidget(
      buildTestApp(
        prefs,
        config: AppConfig.fromValues(
          tuglieMapEnabled: true,
          mapTileUrl: 'http://127.0.0.1:1/test.png',
        ),
      ),
    );
    await tester.pump();
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
            as GoRouter;
    router.go('/map?municipality=bologna');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.textContaining('non corrisponde al Comune selezionato'),
      findsOneWidget,
    );
    router.go('/map?municipality=tuglie');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Luoghi reali · 9'), findsOneWidget);
    router.go('/map?municipality=tuglie&municipality=bologna');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.text('Seleziona un Comune per aprire la mappa.'),
      findsOneWidget,
    );
    expect(find.text('Luoghi reali · 9'), findsNothing);
    router.go('/map?municipality=nonvalido');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.text('Seleziona un Comune per aprire la mappa.'),
      findsOneWidget,
    );
  });

  testWidgets('pilot deep link and back fallback use Tuglie', (tester) async {
    final prefs = await createTestPrefs({'municipality_id': 'tuglie'});
    await tester.pumpWidget(
      buildTestApp(
        prefs,
        config: AppConfig.fromValues(
          tuglieMapEnabled: true,
          pilotMunicipalityId: 'tuglie',
          mapTileUrl: 'http://127.0.0.1:1/test.png',
        ),
      ),
    );
    await tester.pump();
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
            as GoRouter;
    router.go('/map?municipality=tuglie');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Mappa · Tuglie'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/map');
    await tester.tap(find.byTooltip('Indietro'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.routeInformationProvider.value.uri.path, '/home');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  });

  for (final viewport in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('fantasy hides map when flag is off at $viewport', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await createHarness();
      await tester.pumpWidget(
        buildTestApp(
          harness.prefs,
          config: AppConfig.fromValues(fantasyModeEnabled: true),
          fantasyManager: harness.manager,
        ),
      );
      await tester.pump();
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      router.go('/squad');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.textContaining('Mappa / Elenco'), findsNothing);
      router.go('/map?municipality=tuglie');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(router.routeInformationProvider.value.uri.path, '/squad');
    });
  }
}
