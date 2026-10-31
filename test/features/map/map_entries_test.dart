import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fanta_comune/core/config/app_config.dart';

import '../../helpers/test_app.dart';
import '../fantasy/fantasy_test_support.dart';

GoRouter _router(WidgetTester tester) =>
    tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
        as GoRouter;

void main() {
  testWidgets('civic entrances open the Tuglie map', (tester) async {
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
    final router = _router(tester);

    router.go('/home');
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    final homeEntry = find.text('Mappa / Elenco di Tuglie');
    expect(homeEntry, findsOneWidget);
    await tester.ensureVisible(homeEntry);
    await tester.tap(homeEntry);
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/map');

    router.go('/board');
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text('Mappa / Elenco'));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/map');

    router.go('/next-problems?municipality=tuglie');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.byTooltip('Mappa / Elenco'));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/map');
    expect(
      router.routeInformationProvider.value.uri.queryParameters['municipality'],
      'tuglie',
    );
  });

  for (final (viewport, entry) in [
    (const Size(390, 844), 'Mappa / Elenco di Tuglie'),
    (const Size(1280, 800), 'Mappa / Elenco'),
  ]) {
    testWidgets('fantasy entry $entry opens the map at $viewport', (
      tester,
    ) async {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final harness = await createHarness();
      await harness.prefs.setMunicipalityId('comune:Tuglie');
      await tester.pumpWidget(
        buildTestApp(
          harness.prefs,
          config: AppConfig.fromValues(
            tuglieMapEnabled: true,
            fantasyModeEnabled: true,
            mapTileUrl: 'http://127.0.0.1:1/test.png',
          ),
          fantasyManager: harness.manager,
        ),
      );
      await tester.pump();
      final router = _router(tester);
      router.go('/squad');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final link = find.text(entry);
      expect(link, findsOneWidget);
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/map');
      expect(
        router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['municipality'],
        'tuglie',
      );
    });
  }
}
