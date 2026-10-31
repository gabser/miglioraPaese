import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import '../../../helpers/test_app.dart';
import '../fantasy_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontDir = Platform.environment['SENTINELLE_VISUAL_FONT_DIR'];
    if (fontDir == null) return;
    final text = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      text.addFont(
        File(
          '$fontDir/$name',
        ).readAsBytes().then((v) => ByteData.sublistView(v)),
      );
    }
    await text.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(
      File(
        '$fontDir/MaterialIcons-Regular.otf',
      ).readAsBytes().then((v) => ByteData.sublistView(v)),
    );
    await icons.load();
  });
  for (final width in [390.0, 1024.0, 1440.0]) {
    testWidgets('fantasy visual review at $width and keyboard focus', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final h = await createHarness();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: buildTestApp(
            h.prefs,
            config: AppConfig.fromValues(fantasyModeEnabled: true),
            fantasyManager: h.manager,
          ),
        ),
      );
      await pumpRoutingFrame(tester);
      await tester.tap(find.text('Crea la tua rosa'));
      await pumpRoutingFrame(tester);
      expect(find.text('La mia squadra'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Future<void> capture(String name) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final folder = Directory(
            '/tmp/sentinelle-baseline-20261013/flutter-visuals',
          );
          await folder.create(recursive: true);
          await File(
            '${folder.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('squad-${width.toInt()}');
      await tester.tap(find.text('Giornata').last);
      await pumpRoutingFrame(tester);
      final expand = find.text('Aggiungi una motivazione facoltativa').first;
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      final field = find.byKey(
        const ValueKey('motivation-matchday-2-buche-centro'),
      );
      await tester.ensureVisible(field);
      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.enterText(field, 'Osservazione sintetica del quartiere');
      await tester.pumpAndSettle();
      expect(
        h.manager.motivations['buche-centro'],
        'Osservazione sintetica del quartiere',
      );
      expect(tester.takeException(), isNull);
      await capture('keyboard-${width.toInt()}');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
