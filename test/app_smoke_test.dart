import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/copy/venial_copy.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('renders the boot screen on first launch', (tester) async {
    final prefs = await createTestPrefs({});

    await tester.pumpWidget(buildTestApp(prefs));
    await pumpRoutingFrame(tester);

    expect(find.text(VenialCopy.bootHeroNote), findsOneWidget);
    expect(find.text(VenialCopy.bootPrimaryCta.toUpperCase()), findsOneWidget);
  });
}
