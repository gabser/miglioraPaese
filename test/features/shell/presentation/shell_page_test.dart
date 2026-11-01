import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/shell/presentation/shell_page.dart';
import '../../../helpers/test_app.dart';

void main() {
  for (final width in [320.0, 390.0, 720.0, 899.0, 900.0, 1120.0, 1440.0]) {
    testWidgets(
      'shell preserves four branches at $width with short viewport and large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = await createTestPrefs({
          'municipality_id': 'comune:Castel Bolognese',
        });
        final router = GoRouter(
          initialLocation: '/home',
          routes: [
            StatefulShellRoute.indexedStack(
              builder: (_, _, shell) => ShellPage(navigationShell: shell),
              branches: [
                for (final route in ['home', 'play', 'leaderboard', 'profile'])
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/$route',
                        builder: (_, _) =>
                            Center(child: Text('Contenuto $route')),
                      ),
                    ],
                  ),
              ],
            ),
            GoRoute(
              path: '/board',
              builder: (_, _) => const Scaffold(body: Text('Tabellone aperto')),
            ),
          ],
        );
        addTearDown(router.dispose);
        final baseTheme = AppTheme.light();
        final theme = baseTheme.copyWith(
          navigationRailTheme: baseTheme.navigationRailTheme.copyWith(
            selectedLabelTextStyle: baseTheme.textTheme.titleSmall!.copyWith(
              fontSize: 19,
            ),
            unselectedLabelTextStyle: baseTheme.textTheme.titleSmall!.copyWith(
              fontSize: 17,
            ),
          ),
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<AppPrefs>.value(
            value: prefs,
            child: MaterialApp.router(
              theme: theme,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(NavigationBar),
          width < 900 ? findsOneWidget : findsNothing,
        );
        if (width >= 900) {
          final profile = find.text('Profilo');
          expect(tester.widget<Text>(profile).style!.fontSize, 17);
          await tester.scrollUntilVisible(
            profile,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(profile);
        } else {
          await tester.tap(find.text('Profilo'));
        }
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.path, '/profile');
        expect(find.text('Contenuto profile'), findsOneWidget);
        if (width >= 900) {
          expect(tester.widget<Text>(find.text('Profilo')).style!.fontSize, 19);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
