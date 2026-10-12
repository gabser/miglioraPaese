import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> chooseProposalLocation(
  WidgetTester tester, {
  String label = 'Intero Comune',
}) async {
  final field = find.byKey(const ValueKey('proposal-location-kind'));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> sendReviewedProposal(
  WidgetTester tester, {
  bool settleAfter = true,
}) async {
  final button = find.byKey(const ValueKey('proposal-submit'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  if (find.text('Controlla la proposta').evaluate().isNotEmpty) {
    await tester.tap(button);
    await tester.pumpAndSettle();
    if (find.text('Riepilogo della proposta').evaluate().isEmpty) return;
    final continueComparison = find.byKey(
      const ValueKey('proposal-similarity-continue'),
    );
    if (continueComparison.evaluate().isNotEmpty) {
      await tester.ensureVisible(continueComparison);
      await tester.pumpAndSettle();
      await tester.tap(continueComparison);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
  }
  await tester.tap(button);
  if (settleAfter) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }
}
