import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/copy/venial_copy.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('renders the welcome entry on first launch', (tester) async {
    final prefs = await createTestPrefs({});

    await tester.pumpWidget(buildTestApp(prefs));
    await pumpRoutingFrame(tester);

    expect(find.text(VenialCopy.welcomeEnterTitle), findsOneWidget);
    expect(find.text(VenialCopy.welcomeTutorialTitle), findsOneWidget);
    expect(find.text(VenialCopy.welcomeProfileTitle), findsOneWidget);
    expect(find.text(VenialCopy.onboardingTitle), findsNothing);
  });
}
