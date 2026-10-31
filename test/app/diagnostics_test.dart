import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/app/router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/info/presentation/diagnostics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final digest = List.filled(64, 'a').join();
  test('candidate identity is explicit, optional and rejects unsafe input', () {
    expect(AppConfig.fromValues().candidateId, isNull);
    expect(AppConfig.fromValues(candidateId: '').candidateId, isNull);
    expect(AppConfig.fromValues(candidateId: digest).candidateId, digest);
    for (final invalid in [
      'abc',
      '${digest}a',
      digest.toUpperCase(),
      ' $digest',
      '/private/token',
    ]) {
      expect(
        () => AppConfig.fromValues(candidateId: invalid),
        throwsArgumentError,
      );
    }
  });

  final profiles = <String, AppConfig>{
    'Demo locale': AppConfig.fromValues(),
    'API configurata': AppConfig.fromValues(
      gameDataSource: 'api',
      nextProblemsDataSource: 'api',
    ),
    'Laboratorio sintetico configurato': AppConfig.fromValues(
      candidateId: digest,
      apiBaseUrl:
          'http://private-user:private-password@127.0.0.1:8787/private-path',
      gameDataSource: 'api',
      nextProblemsDataSource: 'api',
      fantasyModeEnabled: true,
      fantasyDataSource: 'api',
      accountModeEnabled: true,
      missionsModeEnabled: true,
      reviewModeEnabled: true,
      measurementsModeEnabled: true,
      leagueContinuityModeEnabled: true,
      cooperationModeEnabled: true,
    ),
  };
  for (final profile in profiles.entries) {
    for (final width in [390.0, 1024.0, 1440.0]) {
      testWidgets(
        'real diagnostics route ${profile.key} $width at 200% is read only',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          SharedPreferences.setMockInitialValues({});
          final storage = await SharedPreferences.getInstance();
          final prefs = AppPrefs(storage);
          addTearDown(prefs.dispose);
          final before = {
            for (final key in storage.getKeys()) key: storage.get(key),
          };
          var requests = 0;
          final client = MockClient((_) async {
            requests++;
            return http.Response('{}', 500);
          });
          addTearDown(client.close);
          final config = profile.value;
          final router = buildRouter(prefs, config)..go('/diagnostics');
          addTearDown(router.dispose);
          final routes = router.configuration.routes;
          expect(
            routes.whereType<GoRoute>().where((r) => r.path == '/diagnostics'),
            hasLength(1),
          );
          final shell = routes.whereType<StatefulShellRoute>().single;
          expect(
            shell.branches
                .expand((b) => b.routes)
                .whereType<GoRoute>()
                .where((r) => r.path == '/diagnostics'),
            isEmpty,
          );
          await tester.pumpWidget(
            AppDependencies(
              appPrefs: prefs,
              config: config,
              httpClient: client,
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(DiagnosticsPage), findsOneWidget);
          expect(find.text(profile.key), findsOneWidget);
          expect(
            find.text(config.candidateId ?? 'Non identificato'),
            findsOneWidget,
          );
          for (final text in tester.widgetList<Text>(find.byType(Text))) {
            expect(text.data ?? '', isNot(contains('private-')));
            expect(text.data ?? '', isNot(contains('http://')));
          }
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, -1600),
          );
          await tester.pumpAndSettle();
          expect(find.textContaining('NO-GO operativo'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(requests, 0);
          expect({
            for (final key in storage.getKeys()) key: storage.get(key),
          }, before);
          expect(find.byType(FilledButton), findsNothing);
          expect(
            router.routeInformationProvider.value.uri.path,
            '/diagnostics',
          );
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'profile information opens actual top level diagnostics and returns',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPrefs(await SharedPreferences.getInstance());
      addTearDown(prefs.dispose);
      final config = AppConfig.fromValues();
      final router = buildRouter(prefs, config)..go('/profile');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        AppDependencies(
          appPrefs: prefs,
          config: config,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Informazioni ambiente'));
      await tester.pumpAndSettle();
      expect(find.byType(DiagnosticsPage), findsOneWidget);
      expect(router.canPop(), isTrue);
      expect(find.byType(NavigationBar), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
