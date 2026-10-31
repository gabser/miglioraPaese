import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/measurements/domain/measurement_models.dart';
import 'package:fanta_comune/features/measurements/logic/measurement_controller.dart';
import 'package:fanta_comune/features/measurements/presentation/measurement_page.dart';
import 'package:fanta_comune/features/measurements/presentation/measurement_editor.dart';
import '../missions/mission_test_support.dart';
import 'measurement_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['SENTINELLE_VISUAL_FONT_DIR'];
    if (root == null) return;
    final fonts = FontLoader('Roboto');
    for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
      final f = File('$root/$name');
      if (f.existsSync())
        fonts.addFont(f.readAsBytes().then(ByteData.sublistView));
    }
    await fonts.load();
    final icon = File('$root/MaterialIcons-Regular.otf');
    if (icon.existsSync()) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(icon.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final width in [390.0, 1024.0, 1440.0])
    testWidgets(
      'measurement coverage, undeterminable history, correction keyboard and uncertain recovery at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        var offline = false;
        late MissionHarness h;
        await tester.runAsync(() async {
          h = MissionHarness((r) async {
            if (offline &&
                r.method == 'POST' &&
                r.url.path.contains('/measurements/'))
              throw http.ClientException('offline');
            if (r.url.path.endsWith('/measurements'))
              return reply(overviewJson());
            if (r.url.path.endsWith('/history'))
              return reply({
                'items': [
                  evaluationJson(),
                  evaluationJson(version: 2, disposition: 'undeterminable'),
                ],
              });
            if (r.url.path.endsWith('/evaluations/evaluation'))
              return reply(
                evaluationJson(version: 2, disposition: 'undeterminable'),
              );
            return defaultReply(r);
          });
          await h.login();
        });
        addTearDown(h.dispose);
        final repo = measurements(h),
            c = MeasurementController(measurements(h));
        addTearDown(repo.dispose);
        addTearDown(c.repository.dispose);
        addTearDown(c.dispose);
        final key = GlobalKey();
        Future<void> show(Widget page) async {
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: c,
              child: RepaintBoundary(
                key: key,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light(),
                  home: page,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          final folder = Platform.environment['SENTINELLE_MEASUREMENT_VISUALS'];
          if (folder == null) return;
          await tester.runAsync(() async {
            Directory(folder).createSync(recursive: true);
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final img = await boundary.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '$folder/$name-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            img.dispose();
          });
        }

        await show(const MeasurementPage());
        expect(find.text('Non determinabile'), findsOneWidget);
        expect(find.textContaining('0/8 carte valutabili'), findsOneWidget);
        await capture('coverage-undeterminable');
        await show(const MeasurementPage(evaluationId: 'evaluation'));
        expect(find.text('Storico delle pubblicazioni'), findsOneWidget);
        expect(find.textContaining('Rettifica della versione 1'), findsWidgets);
        await capture('evaluation-history');
        c.workspace = MeasurementWorkspace.fromJson({
          'scope': {
            'municipalityId': 'tuglie',
            'seasonId': 'season',
            'matchdayId': 'day',
          },
          'revision': 2,
          'problems': <Object>[],
          'protocols': <Object>[],
          'interventions': <Object>[],
          'evaluationDrafts': <Object>[],
          'appeals': <Object>[],
          'sources': <Object>[],
          'approvedObservations': <Object>[],
        });
        await show(
          MeasurementEditor(
            action: 'correction',
            entity: evaluationJson(version: 2, disposition: 'undeterminable'),
          ),
        );
        final rationale = find.widgetWithText(
          TextFormField,
          'Motivazione pubblicabile',
        );
        await tester.ensureVisible(rationale);
        await tester.tap(rationale);
        await tester.enterText(
          rationale,
          'Verifica sintetica della comparabilità e delle prove discordanti.',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pumpAndSettle();
        await capture('correction-keyboard');
        tester.view.viewInsets = const FakeViewPadding();
        offline = true;
        final button = find.widgetWithText(
          FilledButton,
          'Rettifica pubblicata',
        );
        await tester.ensureVisible(button);
        await tester.runAsync(() async {
          await tester.tap(button);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(c.error, isNotNull);
        await capture('offline-uncertain');
        expect(find.text('Recupera richiesta originale'), findsOneWidget);
      },
    );
}
