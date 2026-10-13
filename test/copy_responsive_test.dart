import 'dart:io';
import 'dart:ui' as ui;

import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'features/fantasy/fantasy_test_support.dart';
import 'helpers/test_app.dart';

void main() {
  setUpAll(() async {
    final directory = Platform.environment['COPY_FONT_DIR'];
    if (directory == null) {
      return;
    }
    for (final (family, names) in [
      (
        'Roboto',
        ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Italic.ttf'],
      ),
      ('MaterialIcons', ['MaterialIcons-Regular.otf']),
    ]) {
      final loader = FontLoader(family);
      for (final name in names) {
        loader.addFont(
          File(
            '$directory/$name',
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
  });
  for (final (width, scale) in [
    (320.0, 2.0),
    (390.0, 2.0),
    (720.0, 2.0),
    (1440.0, 2.0),
    (320.0, 4.0),
    (390.0, 4.0),
  ]) {
    for (final fantasy in [false, true]) {
      testWidgets('copy routes $width at $scale, squad mode $fantasy', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = await createHarness();
        await h.prefs.setMunicipalityId('comune:Tuglie');
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: buildTestApp(
              h.prefs,
              config: AppConfig.fromValues(fantasyModeEnabled: fantasy),
              fantasyManager: h.manager,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
        for (final route in [
          '/welcome',
          if (!fantasy) ...[
            '/cynic-onboarding',
            '/boot',
            '/home',
            '/play',
            '/board',
            '/leaderboard',
            '/profile',
          ],
          if (fantasy) ...['/squad', '/matchday', '/market', '/leagues'],
          '/next-problems',
          '/suggest-problem',
          '/proposal-receipt',
          '/privacy',
          '/how-it-works',
        ]) {
          router.go(route);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$route at $width/$scale',
          );
          await captureCopy(
            tester,
            boundaryKey,
            '${fantasy ? 'squad' : 'classic'}-${width.toInt()}-${scale.toInt()}-${route.substring(1)}',
          );
          // Reach the bottom as well: long copy and actions must remain scrollable.
          final scrollables = tester
              .widgetList<Scrollable>(find.byType(Scrollable))
              .toList();
          for (final widget in scrollables) {
            final state = tester.state<ScrollableState>(find.byWidget(widget));
            if (state.position.axis == Axis.vertical &&
                state.position.hasContentDimensions) {
              state.position.jumpTo(state.position.maxScrollExtent);
            }
          }
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'bottom $route at $width/$scale',
          );
        }
        if (fantasy) {
          router.go('/squad');
          await tester.pumpAndSettle();
          await h.manager.setPrediction('buche-centro', CivicTrend.stable);
          final confirm = find.widgetWithText(
            FilledButton,
            'Conferma formazione',
          );
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          expect(h.manager.confirmed, isTrue);
          expect(find.text('Formazione salvata'), findsOneWidget);
          await captureCopy(
            tester,
            boundaryKey,
            'state-${width.toInt()}-${scale.toInt()}-confirmed',
          );
          await h.at(day.observationEndsAt);
          router.go('/matchday');
          await tester.pumpAndSettle();
          expect(find.text('Formazione bloccata'), findsOneWidget);
          final outcome = find.text('Esito osservato: Stabile');
          await tester.ensureVisible(outcome);
          await tester.pumpAndSettle();
          expect(h.manager.scoreFor(result()).total, greaterThan(0));
          await captureCopy(
            tester,
            boundaryKey,
            'state-${width.toInt()}-${scale.toInt()}-results',
          );
          router.go('/squad');
          await tester.pumpAndSettle();
          final restart = find.widgetWithText(TextButton, 'Nuova partita demo');
          await tester.ensureVisible(restart);
          await tester.pumpAndSettle();
          await tester.tap(restart);
          await tester.pumpAndSettle();
          expect(h.manager.isLocked, isFalse);
          expect(h.manager.confirmed, isFalse);
          expect(h.manager.hasPreviousDemo, isTrue);
          await captureCopy(
            tester,
            boundaryKey,
            'state-${width.toInt()}-${scale.toInt()}-new-demo',
          );
          final recover = find.widgetWithText(
            TextButton,
            'Riprendi partita precedente',
          );
          await tester.ensureVisible(recover);
          await tester.pumpAndSettle();
          await tester.tap(recover);
          await tester.pumpAndSettle();
          expect(h.manager.isLocked, isTrue);
          expect(h.manager.predictions['buche-centro'], CivicTrend.stable);
          expect(h.manager.scoreFor(result()).total, greaterThan(0));
          await captureCopy(
            tester,
            boundaryKey,
            'state-${width.toInt()}-${scale.toInt()}-recovered',
          );
          expect(tester.takeException(), isNull);
        }
        router.go('/privacy');
        await tester.pumpAndSettle();
        final delete = find.widgetWithText(
          FilledButton,
          'Elimina dati e riparti',
        );
        await tester.ensureVisible(delete);
        await tester.tap(delete);
        await tester.pumpAndSettle();
        expect(h.prefs.municipalityId, isNull);
        expect(h.prefs.fantasyDemoArchive, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

Future<void> captureCopy(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  final directory = Platform.environment['COPY_SCREENSHOT_DIR'];
  if (directory == null) {
    return;
  }
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final picture = await boundary.toImage();
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File(
      '$directory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}
