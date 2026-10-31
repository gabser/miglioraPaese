import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/app/router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final fantasy in [false, true]) {
    final paths = fantasy
        ? ['/squad', '/matchday', '/market', '/leagues', '/profile']
        : ['/home', '/play', '/leaderboard', '/profile'];
    test(
      'real route graph retains branch defaults (fantasy=$fantasy)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = AppPrefs(await SharedPreferences.getInstance());
        addTearDown(prefs.dispose);
        final config = AppConfig.fromValues(
          fantasyModeEnabled: fantasy,
          fantasyDataSource: 'api',
          accountModeEnabled: true,
          missionsModeEnabled: true,
          reviewModeEnabled: true,
          measurementsModeEnabled: fantasy,
          cooperationModeEnabled: fantasy,
        );
        final router = buildRouter(prefs, config);
        addTearDown(router.dispose);
        final routes = router.configuration.routes;
        final shell = routes.whereType<StatefulShellRoute>().single;
        expect(shell.branches.map((b) => b.defaultRoute!.path), paths);
        for (final path in ['/cooperation', '/inbox', '/followed-places']) {
          expect(
            routes.whereType<GoRoute>().where((r) => r.path == path),
            hasLength(1),
          );
          expect(
            shell.branches
                .expand((b) => b.routes)
                .whereType<GoRoute>()
                .where((r) => r.path == path),
            isEmpty,
          );
          expect(
            router.configuration.findMatch(Uri.parse(path)).isError,
            isFalse,
          );
        }
      },
    );
    for (final municipality in [null, 'tuglie']) {
      testWidgets(
        'real shell tabs and defaults fantasy=$fantasy municipality=$municipality',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            if (municipality != null) 'municipality_id': municipality,
          });
          final prefs = AppPrefs(await SharedPreferences.getInstance());
          addTearDown(prefs.dispose);
          final config = AppConfig.fromValues(fantasyModeEnabled: fantasy);
          final router = buildRouter(prefs, config)..go(paths.first);
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
          for (var i = 0; i < paths.length; i++) {
            final bar = tester.widget<NavigationBar>(
              find.byType(NavigationBar),
            );
            bar.onDestinationSelected!(i);
            await tester.pumpAndSettle();
            expect(router.routeInformationProvider.value.uri.path, paths[i]);
            expect(
              tester
                  .widget<NavigationBar>(find.byType(NavigationBar))
                  .selectedIndex,
              i,
            );
            // Reselecting the current tab must also resolve its original default.
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .onDestinationSelected!(i);
            await tester.pumpAndSettle();
            expect(router.routeInformationProvider.value.uri.path, paths[i]);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
}
