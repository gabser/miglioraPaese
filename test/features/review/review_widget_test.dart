import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/review/logic/review_controller.dart';
import 'package:fanta_comune/features/review/presentation/review_page.dart';
import '../missions/mission_test_support.dart';
import 'review_test_support.dart';

File? _materialIconsFont() {
  var directory = File(Platform.resolvedExecutable).parent;
  while (true) {
    final font = File(
      '${directory.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (font.existsSync()) {
      return font;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      return null;
    }
    directory = parent;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = Platform.environment['SENTINELLE_VISUAL_FONT_DIR'];
    if (fonts != null) {
      final loader = FontLoader('Roboto');
      for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
        final file = File('$fonts/$name');
        if (file.existsSync())
          loader.addFont(file.readAsBytes().then(ByteData.sublistView));
      }
      await loader.load();
    }
    final icons = _materialIconsFont();
    if (icons != null) {
      final loader = FontLoader('MaterialIcons');
      loader.addFont(icons.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
  });
  for (final width in [390.0, 1024.0, 1440.0])
    testWidgets(
      'review reason keyboard integration offline and server current XP at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        var current = liveJson(status: 'screened', revision: 2),
            offline = false,
            loseSupplement = false,
            posts = 0;
        late MissionHarness h;
        await tester.runAsync(() async {
          h = MissionHarness((r) async {
            if (offline) throw http.ClientException('synthetic offline');
            final p = r.url.path;
            if (p.endsWith('/capabilities'))
              return reply({
                'roles': ['verifier'],
                'synthetic': true,
              });
            if (p.endsWith('/observations'))
              return reply({
                'items': [current],
              });
            if (p.endsWith('/observation')) return reply(current);
            if (p.endsWith('/xp'))
              return reply(ledgerJson(balance: current['xpAwarded'] as int));
            if (p.endsWith('/supplements')) {
              current = {
                ...liveJson(status: 'screened', revision: 4, integration: true),
                'integrationRequest': {
                  ...(liveJson(integration: true)['integrationRequest'] as Map),
                  'status': 'answered',
                },
              };
              if (loseSupplement) {
                loseSupplement = false;
                throw http.ClientException('lost supplement after commit');
              }
              return reply(current);
            }
            if (p.endsWith('/integration-requests')) {
              posts++;
              current = liveJson(
                status: 'needsIntegration',
                revision: 3,
                integration: true,
              );
              return reply(current);
            }
            return defaultReply(r);
          });
          await h.login();
        });
        addTearDown(h.dispose);

        final repo = reviewRepository(h);
        addTearDown(repo.dispose);
        final c = ReviewController(repository: repo);
        addTearDown(c.dispose);
        final boundaryKey = GlobalKey();
        Future<void> show(bool author) async {
          await tester.runAsync(() => c.open('observation', author: author));
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: c,
              child: RepaintBoundary(
                key: boundaryKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light(),
                  home: ReviewPage(
                    observationId: 'observation',
                    author: author,
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pumpAndSettle();
        }

        Future<void> capture(String name) async {
          expect(tester.takeException(), isNull);
          if (Platform.environment['SENTINELLE_REVIEW_RENDER'] != 'true')
            return;
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('/tmp/sentinelle-review-visuals');
            await folder.create(recursive: true);
            await File(
              '${folder.path}/$name-${width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }

        await show(false);
        await capture('case');
        final integration = find.text('Richiedi integrazione');
        await tester.ensureVisible(integration);
        await tester.tap(integration);
        await tester.pumpAndSettle();
        expect(find.text('Inserisci una motivazione.'), findsOneWidget);
        expect(posts, 0);
        final reason = find.byType(TextFormField);
        await tester.ensureVisible(reason);
        await tester.tap(reason);
        await tester.enterText(reason, 'Aggiungere un’inquadratura sintetica');
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        await tester.pumpAndSettle();
        await capture('reason-keyboard');
        tester.view.viewInsets = const FakeViewPadding();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.ensureVisible(integration);
        await tester.runAsync(() async {
          await tester.tap(integration);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        expect(posts, 1);
        expect(find.text('Valida osservazione'), findsNothing);
        await tester.ensureVisible(find.text('Richiesta di integrazione'));
        await capture('integration');
        await show(true);
        final notes = find.widgetWithText(TextField, 'Note aggiuntive');
        await tester.ensureVisible(notes);
        await tester.enterText(notes, 'Supplemento sintetico offline');
        offline = true;
        final send = find.text('Invia integrazione');
        await tester.ensureVisible(send);
        await tester.runAsync(() async {
          await tester.tap(send);
          await Future<void>.delayed(const Duration(milliseconds: 30));
        });
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('review-error')));
        await capture('offline');
        expect(c.error, isNotNull);
        offline = false;
        await tester.runAsync(() async {
          final original = c.observation!;
          await repo.saveSupplement(
            original,
            'Risposta sintetica da recuperare',
            [],
          );
          loseSupplement = true;
          await expectLater(
            repo.submitSupplement(original),
            throwsA(isA<ApiException>()),
          );
          await c.open('observation', author: true);
        });
        await tester.pumpAndSettle();
        expect(find.text('Recupera invio integrazione'), findsOneWidget);
        expect(find.text('Risposta sintetica da recuperare'), findsOneWidget);
        await tester.ensureVisible(find.text('Recupera invio integrazione'));
        await capture('answered-recovery');
        current = liveJson(status: 'approved', revision: 5, xp: 10);
        await tester.runAsync(() => c.open('observation', author: true));
        await tester.pumpAndSettle();
        expect(find.text('XP correnti del contributo: 10'), findsOneWidget);
        expect(find.text('Saldo XP dal server: 10'), findsOneWidget);
        await tester.ensureVisible(find.byKey(const ValueKey('current-xp')));
        await capture('current-xp');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
}
