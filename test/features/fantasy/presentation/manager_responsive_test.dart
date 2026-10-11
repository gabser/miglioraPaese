import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import '../fantasy_test_support.dart';
import '../../../helpers/test_app.dart';

void main() {
  for (final width in [320.0, 390.0, 720.0, 899.0, 900.0, 1120.0, 1440.0]) {
    testWidgets(
      'Manager areas remain actionable at width $width and200% text',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = await createHarness();
        await h.prefs.setMunicipalityId('comune:Tuglie');
        await tester.pumpWidget(
          buildTestApp(
            h.prefs,
            config: AppConfig.fromValues(fantasyModeEnabled: true),
            fantasyManager: h.manager,
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(
          tester.element(find.text('Crea la tua rosa')),
        );
        for (final route in ['/squad', '/matchday', '/market', '/leagues']) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: route);
        }
        router.go('/squad');
        await tester.pumpAndSettle();
        final confirm = find.widgetWithText(
          FilledButton,
          'Conferma formazione',
        );
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(h.manager.confirmed, isTrue);
        await h.at(day.locksAt);
        router.go('/matchday');
        await tester.pumpAndSettle();
        expect(find.text('Giornata bloccata'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
