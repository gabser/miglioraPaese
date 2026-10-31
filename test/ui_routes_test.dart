import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'helpers/test_app.dart';

Future<void> _finishLoads(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var index = 0; index < 4; index++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final scenario in [
    (320.0, 2.0),
    (390.0, 2.0),
    (720.0, 1.0),
    (899.0, 1.0),
    (900.0, 1.0),
    (1120.0, 1.0),
    (1440.0, 2.0),
    (320.0, 4.0),
  ]) {
    final width = scenario.$1;
    final scale = scenario.$2;
    testWidgets('actual routes fit at $width with ${scale * 100}% text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final prefs = await createTestPrefs({
        'municipality_id': 'comune:Pincara',
      });
      await tester.pumpWidget(buildTestApp(prefs));
      await _finishLoads(tester);
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      for (final path in [
        '/home',
        '/play',
        '/board',
        '/profile',
        '/leaderboard',
        '/welcome',
        '/cynic-onboarding',
        '/change-municipality',
        '/boot',
        '/how-it-works',
        '/privacy',
        '/next-problems',
        '/suggest-problem',
      ]) {
        router.go(path);
        await _finishLoads(tester);
        expect(router.routeInformationProvider.value.uri.path, path);
        expect(tester.takeException(), isNull, reason: '$path at $width');
      }
    });
  }

  testWidgets(
    'choosing a missing municipality returns to proposals with Italian controls and stable router',
    (tester) async {
      final prefs = await createTestPrefs({});
      await tester.pumpWidget(buildTestApp(prefs));
      await _finishLoads(tester);
      final router =
          tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
              as GoRouter;
      router.go('/suggest-problem');
      await _finishLoads(tester);
      await tester.tap(find.text('Scegli il Comune'));
      await _finishLoads(tester);
      expect(
        router.routeInformationProvider.value.uri.queryParameters['returnTo'],
        '/suggest-problem',
      );
      await tester.tap(find.text('BOLOGNA'));
      await _finishLoads(tester);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/suggest-problem',
      );
      expect(find.text('Comune: Bologna'), findsOneWidget);
      final context = tester.element(find.text('Proponi un problema'));
      expect(Localizations.localeOf(context).languageCode, 'it');
      expect(MaterialLocalizations.of(context).backButtonTooltip, 'Indietro');
      await prefs.setMotionDemoEnabled(true);
      await _finishLoads(tester);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig,
        same(router),
      );
      expect(
        router.routeInformationProvider.value.uri.path,
        '/suggest-problem',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('optional tutorial supports next, previous and skip', (
    tester,
  ) async {
    final prefs = await createTestPrefs({});
    await tester.pumpWidget(buildTestApp(prefs));
    await _finishLoads(tester);
    await tester.tap(find.text(VenialCopy.welcomeTutorialTitle));
    await _finishLoads(tester);
    expect(find.text(VenialCopy.welcomeStep1Title), findsOneWidget);
    final next = find.text(VenialCopy.welcomeStep1Cta);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await _finishLoads(tester);
    expect(find.text(VenialCopy.welcomeStep2Title), findsOneWidget);
    await tester.ensureVisible(find.text('Indietro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Indietro'));
    await _finishLoads(tester);
    expect(find.text(VenialCopy.welcomeStep1Title), findsOneWidget);
    await tester.ensureVisible(find.text(VenialCopy.welcomeSkip));
    await tester.pumpAndSettle();
    await tester.tap(find.text(VenialCopy.welcomeSkip));
    await _finishLoads(tester);
    expect(prefs.hasSeenWarmWelcome, isTrue);
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig!
            as GoRouter;
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(tester.takeException(), isNull);
  });
}
