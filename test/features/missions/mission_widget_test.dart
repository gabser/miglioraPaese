import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/features/missions/logic/mission_controller.dart';
import 'package:fanta_comune/features/missions/presentation/mission_page.dart';
import 'mission_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontDir = Platform.environment['SENTINELLE_VISUAL_FONT_DIR'];
    if (fontDir == null) return;
    final loader = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final file = File('$fontDir/$name');
      if (file.existsSync())
        loader.addFont(file.readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
    final iconFile = File('$fontDir/MaterialIcons-Regular.otf');
    if (iconFile.existsSync()) {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(iconFile.readAsBytes().then(ByteData.sublistView));
      await icons.load();
    }
  });
  for (final width in [390.0, 1024.0, 1440.0]) {
    testWidgets(
      'mission confirmation cancel and accessibility states at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        var observationRequests = 0;
        var offline = false;
        late MissionHarness h;
        await tester.runAsync(() async {
          h = MissionHarness((request) async {
            if (offline) throw http.ClientException('synthetic offline');
            if (request.url.path.endsWith('/observations')) {
              observationRequests++;
              return reply({
                'id': 'receipt',
                'bookingId': bookingId,
                'missionId': missionId,
                'municipalityId': 'tuglie',
                'windowId': 'synthetic-week-1',
                'protocolVersion': 1,
                'status': 'pendingReview',
                'answer': 'nonObservable',
                'submittedAt': '2026-10-14T10:00:00Z',
                'xpAwarded': 0,
                'proofIds': <String>[],
                'proofs': <Object>[],
              });
            }
            if (observationRequests > 0 &&
                request.url.path.endsWith('/$bookingId')) {
              return reply({
                ...bookingJson(),
                'status': 'submitted',
                'revision': 2,
              });
            }
            return defaultReply(request);
          });
          await h.login();
        });
        addTearDown(h.dispose);
        final picker = SyntheticPicker()..denied = true;
        final c = MissionController(repository: h.repository, picker: picker);
        addTearDown(c.dispose);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: c,
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                home: const MissionPage(missionId: missionId),
              ),
            ),
          ),
        );
        await tester.runAsync(() => c.open(missionId));
        await tester.pumpAndSettle();
        await tester.runAsync(c.reserve);
        await tester.pumpAndSettle();
        await tester.runAsync(() => c.saveAnswer(MissionAnswer.nonObservable));
        await tester.pumpAndSettle();
        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('/tmp/sentinelle-mission-visuals');
            await folder.create(recursive: true);
            await File(
              '${folder.path}/$name-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await capture('no-gps');
        final notes = find.byKey(const ValueKey('mission-notes'));
        await tester.ensureVisible(notes);
        await tester.tap(notes);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.enterText(notes, 'Nota sintetica da confermare');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        expect(FocusManager.instance.primaryFocus, isNotNull);
        await capture('keyboard');
        tester.view.viewInsets = const FakeViewPadding();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final send = find.text('Invia per revisione umana');
        await tester.ensureVisible(send);
        await tester.runAsync(() async {
          await tester.tap(send);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        expect(find.text('Riepilogo osservazione'), findsOneWidget);
        expect(find.textContaining('0 prove private'), findsOneWidget);
        expect(observationRequests, 0);
        await capture('confirmation');
        await tester.tap(find.text('Annulla'));
        await tester.pumpAndSettle();
        expect(c.draft!.submitBody, isNull);
        expect(c.draft!.notes, 'Nota sintetica da confermare');
        expect(observationRequests, 0);
        await tester.runAsync(() => c.addPhoto(camera: true));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('mission-error')));
        await capture('permission-denied');
        offline = true;
        await tester.runAsync(c.release);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('mission-error')));
        await capture('offline');
        expect(c.draft!.notes, 'Nota sintetica da confermare');
        offline = false;
        await tester.ensureVisible(send);
        await tester.runAsync(() async {
          await tester.tap(send);
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('Conferma'));
        });
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        expect(observationRequests, 1);
        expect(c.receipt!.xpAwarded, 0);
        expect(c.receipt!.proofs, isEmpty);
        expect(h.repository.restore(mission())!.receipt, c.receipt!.snapshot);
        await tester.ensureVisible(find.text('Ricevuta server'));
        await capture('receipt');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
