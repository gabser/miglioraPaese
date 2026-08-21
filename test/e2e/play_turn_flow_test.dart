import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fanta_comune/core/copy/venial_copy.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('user enters, predicts and resolves a complete mock turn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final prefs = await createTestPrefs({
      'municipality_id': 'comune:Bologna',
      'user_id': 'user:e2e',
    });

    await tester.pumpWidget(buildTestApp(prefs));
    await pumpRoutingFrame(tester);

    await tester.tap(find.text(VenialCopy.welcomeEnterTitle));
    await pumpRoutingFrame(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Gioca il turno'), findsOneWidget);
    await tester.tap(find.text('Gioca il turno'));
    await pumpRoutingFrame(tester);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final problemCard = find.byKey(const ValueKey('problem-1'));
    final playScroll = find
        .descendant(
          of: find.byType(CustomScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(playScroll, findsOneWidget);
    await tester.scrollUntilVisible(problemCard, 500, scrollable: playScroll);
    await tester.pumpAndSettle();
    expect(problemCard, findsOneWidget);

    final worsenChoice = find
        .descendant(
          of: problemCard,
          matching: find.text(VenialCopy.choiceWorsenLabel),
        )
        .last;
    expect(worsenChoice, findsOneWidget);
    await tester.tap(worsenChoice);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.descendant(
        of: problemCard,
        matching: find.text(VenialCopy.predictionLockedTitle),
      ),
      findsOneWidget,
    );

    final resolveButton = find.text(VenialCopy.playResolveCta);
    await tester.scrollUntilVisible(
      resolveButton,
      -500,
      scrollable: playScroll,
    );
    await tester.pumpAndSettle();
    expect(resolveButton, findsOneWidget);
    await tester.tap(resolveButton);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(problemCard, 500, scrollable: playScroll);
    await tester.pumpAndSettle();
    expect(find.text(VenialCopy.resultCorrect), findsOneWidget);

    tester.state<ScrollableState>(playScroll).position.jumpTo(650);
    await tester.pumpAndSettle();
    expect(find.text(VenialCopy.retentionPendingTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
