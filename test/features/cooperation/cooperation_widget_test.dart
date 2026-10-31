import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/cooperation/cooperation_page.dart';
import 'package:fanta_comune/features/cooperation/cooperation_controller.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/core/network/session_lease_source.dart';
import '../missions/mission_test_support.dart';
import 'cooperation_test.dart' show progressJson, inboxJson, cooperation;

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
    testWidgets('cooperation inbox follow league keyboard and 2x text $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      bool following = false;
      int writes = 0;
      late MissionHarness h;
      await tester.runAsync(() async {
        h = MissionHarness((r) async {
          if (r.url.path.endsWith('/cooperation'))
            return reply(
              progressJson(
                league: r.url.path.contains('/leagues/') ? 'league' : null,
              ),
            );
          if (r.url.path.endsWith('/inbox'))
            return reply(inboxJson(cursor: null));
          if (r.url.path.endsWith('/followed-places'))
            return reply({
              'items': following
                  ? [
                      {'placeId': 'place', 'municipalityId': 'tuglie'},
                    ]
                  : [],
            });
          if (r.url.path.endsWith('/followed-places/place')) {
            writes++;
            following = r.method == 'PUT';
            return reply({
              'placeId': 'place',
              'municipalityId': 'tuglie',
              'following': following,
            });
          }
          return defaultReply(r);
        });
        await h.login();
      });
      addTearDown(h.dispose);
      final r = cooperation(h), c = CooperationController(r);
      addTearDown(r.dispose);
      addTearDown(c.dispose);
      final key = GlobalKey();
      Future<void> show(Widget page, {double text = 1}) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: r),
              ChangeNotifierProvider.value(value: c),
            ],
            child: RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1000),
                    textScaler: TextScaler.linear(text),
                  ),
                  child: page,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        final root = Platform.environment['SENTINELLE_COOPERATION_VISUALS'];
        if (root == null) return;
        await tester.runAsync(() async {
          Directory(root).createSync(recursive: true);
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await boundary.toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$root/$name-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      await show(const CooperationPage());
      expect(find.text('Progresso del Comune'), findsOneWidget);
      await capture('municipal');
      await tester.tap(find.text('Consulta un altro periodo'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'season');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.enterText(find.byType(TextField).last, 'day');
      expect(tester.takeException(), isNull);
      await show(const CooperationPage(inbox: true), text: 2);
      expect(find.text('2 messaggi non letti'), findsOneWidget);
      await capture('inbox-2x');
      await show(
        const Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                FollowPlaceButton('place'),
                LeagueCooperationTabs(
                  personal: Text("Classifica punti fantasy"),
                  leagueId: 'league',
                  seasonId: 'season',
                  archived: true,
                ),
              ],
            ),
          ),
        ),
        text: 2,
      );
      expect(writes, 0);
      await tester.tap(find.text('Segui aggiornamenti del luogo'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Non seguire più il luogo'), findsOneWidget);
      expect(find.text('Classifica punti fantasy'), findsOneWidget);
      await tester.ensureVisible(find.text('Cooperazione').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cooperazione').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cooperazione').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cooperazione').last);
      await tester.pumpAndSettle();
      expect(find.text('Progresso della lega'), findsOneWidget);
      expect(find.text('Progresso del Comune'), findsOneWidget);
      await capture('league-follow-2x');
      await show(const CooperationPage(followed: true));
      expect(find.text('Non seguire più'), findsOneWidget);
      await tester.tap(find.text('Non seguire più'));
      await tester.pumpAndSettle();
      expect(following, isFalse);
      expect(writes, 2);
      await capture('followed-empty');
    });
  testWidgets(
    'real AppDependencies resolves cooperation and session alias without ChangeNotifier ownership regression',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPrefs(await SharedPreferences.getInstance());
      final config = AppConfig.fromValues(
        accountModeEnabled: true,
        missionsModeEnabled: true,
        reviewModeEnabled: true,
        measurementsModeEnabled: true,
        cooperationModeEnabled: true,
        fantasyModeEnabled: true,
        fantasyDataSource: 'api',
        pilotMunicipalityId: 'tuglie',
      );
      late CooperationController controller;
      late AccountSessionStore account;
      await tester.pumpWidget(
        AppDependencies(
          appPrefs: prefs,
          config: config,
          child: Builder(
            builder: (context) {
              controller = context.read<CooperationController>();
              account = context.read<AccountSessionStore>();
              expect(context.read<SessionLeaseSource?>(), isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(controller.repository.account, same(account));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
