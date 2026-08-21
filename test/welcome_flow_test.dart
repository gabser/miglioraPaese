import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/config/app_config.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('municipality onboarding is optional and returns home', (
    tester,
  ) async {
    final prefs = await createTestPrefs({});

    await tester.pumpWidget(buildTestApp(prefs));
    await pumpRoutingFrame(tester);

    expect(find.text(VenialCopy.welcomeEnterTitle), findsOneWidget);
    await tester.tap(find.text(VenialCopy.welcomeEnterTitle));
    await pumpRoutingFrame(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Gioca il turno'), findsOneWidget);
    expect(find.text(VenialCopy.welcomeStep1Title), findsNothing);

    final context = tester.element(find.text('Gioca il turno'));
    GoRouter.of(context).go('/onboarding');
    await pumpRoutingFrame(tester);

    expect(find.text('Milano'), findsOneWidget);

    await tester.tap(find.text('Milano'));
    await pumpRoutingFrame(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(prefs.municipalityId, 'comune:Milano');
    expect(find.text('Gioca il turno'), findsOneWidget);
  });

  testWidgets('profile can reopen municipality selection after onboarding', (
    tester,
  ) async {
    final prefs = await createTestPrefs({'municipality_id': 'comune:Milano'});

    await tester.pumpWidget(buildTestApp(prefs));
    await pumpRoutingFrame(tester);

    await tester.tap(find.text(VenialCopy.welcomeEnterTitle));
    await pumpRoutingFrame(tester);
    await tester.pump(const Duration(seconds: 2));

    final context = tester.element(find.text('Gioca il turno'));
    final router = GoRouter.of(context);
    router.go('/profile');
    await pumpRoutingFrame(tester);

    expect(find.text('Cambia Comune'), findsOneWidget);

    await tester.tap(find.text('Cambia Comune'));
    await pumpRoutingFrame(tester);

    expect(find.text('Milano'), findsOneWidget);
    expect(find.text('Roma'), findsOneWidget);
  });

  testWidgets('pilot profile keeps the configured municipality locked', (
    tester,
  ) async {
    final prefs = await createTestPrefs({
      'municipality_id': 'castel-bolognese',
    });
    final config = AppConfig.fromValues(
      pilotMunicipalityId: 'castel-bolognese',
    );

    await tester.pumpWidget(buildTestApp(prefs, config: config));
    await pumpRoutingFrame(tester);

    await tester.tap(find.text(VenialCopy.welcomeEnterTitle));
    await pumpRoutingFrame(tester);
    await tester.pump(const Duration(seconds: 2));

    final context = tester.element(find.text('Gioca il turno'));
    final router = GoRouter.of(context);
    router.go('/profile');
    await pumpRoutingFrame(tester);

    expect(find.text('Castel Bolognese'), findsOneWidget);
    expect(
      find.text('Questo ambiente è riservato al Comune del pilot.'),
      findsOneWidget,
    );
    expect(find.text('Cambia Comune'), findsNothing);

    router.go('/change-municipality');
    await pumpRoutingFrame(tester);
    expect(find.text(VenialCopy.onboardingTitle), findsNothing);
  });
}
