import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/copy/venial_copy.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets(
      'welcome sends users without a municipality to municipality onboarding',
      (tester) async {
    final prefs = await createTestPrefs({});

    await tester.pumpWidget(buildTestApp(prefs));
    await pumpRoutingFrame(tester);

    await tester.tap(find.text(VenialCopy.bootPrimaryCta.toUpperCase()));
    await pumpRoutingFrame(tester);
    expect(find.text(VenialCopy.welcomeStep1Title), findsOneWidget);

    await tester.tap(find.text(VenialCopy.welcomeStep1Cta));
    await pumpRoutingFrame(tester);
    await tester.tap(find.text(VenialCopy.welcomeStep2Cta));
    await pumpRoutingFrame(tester);

    expect(find.text(VenialCopy.welcomeStep3Municipality), findsOneWidget);
    expect(find.text(VenialCopy.welcomeStep3Play), findsNothing);

    await tester.tap(find.text(VenialCopy.welcomeStep3Municipality));
    await pumpRoutingFrame(tester);

    expect(find.text('Milano'), findsOneWidget);
  });
}
