import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

/// Actual decoded local tile, with no network and normal tile completion events.
class LocalProposalTiles extends TileProvider {
  static final bytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP49P3XfwAJpQPjiokzCAAAAABJRU5ErkJggg==',
    ),
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(bytes);
}

Future<void> tapProposal(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> chooseProposalCase(
  WidgetTester tester, {
  String category = 'green',
  String scenario = 'Ramo sul passaggio',
}) async {
  await tapProposal(
    tester,
    find.byKey(ValueKey('proposal-category-$category-choice')),
  );
  await tapProposal(tester, find.text(scenario));
}

Future<void> nextProposalStep(WidgetTester tester) =>
    tapProposal(tester, find.byKey(const ValueKey('proposal-submit')));

Future<void> openProposalReview(WidgetTester tester) async {
  if (find.byKey(const ValueKey('proposal-title')).evaluate().isNotEmpty) {
    return;
  }
  await chooseProposalCase(tester);
  await nextProposalStep(tester);
  await chooseProposalLocation(tester);
  await nextProposalStep(tester);
}

Future<void> chooseProposalLocation(
  WidgetTester tester, {
  String label = 'Intero Comune',
}) async {
  // Used by route/recovery tests already editing a summary.
  if (find.text('Riepilogo della proposta').evaluate().isNotEmpty) {
    await tapProposal(tester, find.text('Modifica luogo'));
  }
  final field = find.byKey(const ValueKey('proposal-location-kind'));
  await tapProposal(tester, field);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
  if (label == 'Luogo specifico') {
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(LocalProposalTiles.bytes),
        tester.element(field),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> confirmProposalCenter(WidgetTester tester) async {
  final center = find.widgetWithText(OutlinedButton, 'Seleziona il centro');
  for (var attempt = 0; attempt < 20; attempt++) {
    if (tester.widget<OutlinedButton>(center).onPressed != null) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    tester.widget<OutlinedButton>(center).onPressed,
    isNotNull,
    reason:
        'The local center tile must finish loading before selecting a point.',
  );
  await tapProposal(tester, find.text('Seleziona il centro'));
  await tapProposal(tester, find.text('Usa questo punto'));
}

Future<void> sendReviewedProposal(
  WidgetTester tester, {
  bool settleAfter = true,
}) async {
  final button = find.byKey(const ValueKey('proposal-submit'));
  if (find.text('Riepilogo della proposta').evaluate().isEmpty) {
    await nextProposalStep(tester);
    if (find.text('Riepilogo della proposta').evaluate().isEmpty) return;
  }
  if (find.text('Controlla la proposta').evaluate().isNotEmpty) {
    await tapProposal(tester, button);
  }
  final comparison = find.byKey(const ValueKey('proposal-similarity-continue'));
  if (comparison.evaluate().isNotEmpty) await tapProposal(tester, comparison);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  if (settleAfter) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }
}
