import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import 'package:fanta_comune/app/app.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import '../../../helpers/memory_local_backend.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/fantasy/continuity/continuity_repository.dart';
import 'package:fanta_comune/features/fantasy/continuity/invite_page.dart';
import 'package:fanta_comune/features/fantasy/continuity/ownership_panel.dart';
import 'continuity_test.dart' as fixture;

void main() {
  setUpAll(() async {
    final font = File('/System/Library/Fonts/Supplemental/Arial.ttf');
    if (await font.exists()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
  });
  AppConfig config() => AppConfig(
    nextProblemsDataSource: NextProblemsDataSource.mock,
    fantasyModeEnabled: true,
    fantasyDataSource: FantasyDataSource.api,
    leagueContinuityModeEnabled: true,
    accountModeEnabled: true,
    apiBaseUrl: Uri.parse('https://fixture.invalid'),
  );
  Widget app(fixture.Harness h, Widget child, {double scale = 1}) =>
      MultiProvider(
        providers: [
          Provider<AppConfig>.value(value: config()),
          ChangeNotifierProvider<LeagueContinuityRepository>.value(
            value: h.repository,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: child,
        ),
      );
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['SENTINELLE_CAPTURE'] != 'true') return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.sentinelle-local/phase6/client/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [390.0, 1024.0, 1440.0]) {
    testWidgets('invite summary explicit actions, keyboard and render $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = fixture.Harness(
        (_) async => fixture.reply(fixture.previewJson(role: 'spectator')),
      );
      addTearDown(h.close);
      await h.repository.rememberInvite(fixture.inviteToken);
      final key = GlobalKey();
      await tester.pumpWidget(
        app(h, RepaintBoundary(key: key, child: const LeagueInvitePage())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ruolo previsto: spettatore'), findsOneWidget);
      expect(find.text('Comune: Tuglie'), findsOneWidget);
      expect(find.text('Accedi e riprendi questo invito'), findsOneWidget);
      expect(h.sessions.calls, 0);
      expect(h.requests.length, 1);
      expect(find.text('Conferma adesione alla lega'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus?.context, isNotNull);
      await capture(tester, key, 'invite-${width.toInt()}');
      expect(tester.takeException(), null);
    });
    testWidgets(
      'ownership candidates and pending offer recover only on read $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = fixture.Harness(
          (_) async => fixture.reply(fixture.workspaceJson()),
        );
        addTearDown(h.close);
        final key = GlobalKey();
        await tester.pumpWidget(
          app(
            h,
            RepaintBoundary(
              key: key,
              child: Scaffold(
                appBar: AppBar(title: const Text('Leghe private')),
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 768),
                      child: OwnershipPanel(
                        leagueId: 'l1',
                        seasonId: 's1',
                        onChanged: () async {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ricarica proprietà e offerte'));
        await tester.pumpAndSettle();
        expect(find.text('Proponi a Sentinella 2'), findsOneWidget);
        expect(h.requests.single.method, 'GET');
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus?.context, isNotNull);
        await capture(tester, key, 'ownership-${width.toInt()}');
        expect(tester.takeException(), null);
      },
    );
  }
  testWidgets(
    'real dependency graph opens saved invitation without session or enrollment',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final data = LocalDataStore(backend: MemoryLocalBackend());
      final appPrefs = AppPrefs(
        await SharedPreferences.getInstance(),
        dataStore: data,
      );
      final c = config();
      await data.mutate<void>(
        'league-invite-intent:${c.apiBaseUrl}',
        (_) => LocalDataMutation({'token': fixture.inviteToken}, null),
      );
      final paths = <String>[];
      final transport = MockClient((request) async {
        paths.add(request.url.path);
        return fixture.reply(fixture.previewJson());
      });
      await tester.pumpWidget(
        AppDependencies(
          appPrefs: appPrefs,
          config: c,
          httpClient: transport,
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rivedi l’invito'), findsOneWidget);
      expect(paths, ['/v1/fantasy/league-invites/preview']);
      await tester.pumpWidget(const SizedBox.shrink());
      appPrefs.dispose();
      transport.close();
    },
  );
  testWidgets('cold API startup waits for season and survives load failure', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final appPrefs = AppPrefs(
      await SharedPreferences.getInstance(),
      dataStore: LocalDataStore(backend: MemoryLocalBackend()),
    );
    final response = Completer<http.Response>();
    final transport = MockClient((_) => response.future);
    late FantasyManager manager;
    late LeagueContinuityRepository continuity;
    await tester.pumpWidget(
      AppDependencies(
        appPrefs: appPrefs,
        config: AppConfig(
          nextProblemsDataSource: NextProblemsDataSource.mock,
          fantasyModeEnabled: true,
          fantasyDataSource: FantasyDataSource.api,
          leagueContinuityModeEnabled: true,
          accountModeEnabled: true,
          pilotMunicipalityId: 'tuglie',
          apiBaseUrl: Uri.parse('https://fixture.invalid'),
        ),
        httpClient: transport,
        child: Builder(
          builder: (context) {
            manager = context.read<FantasyManager>();
            continuity = context.read<LeagueContinuityRepository>();
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(manager.hasData, isFalse);
    expect(manager.loading, isTrue);
    expect(continuity.seasonId, isNull);
    response.complete(http.Response('{"message":"Unavailable"}', 503));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(manager.loading, isFalse);
    expect(manager.persistenceError, isNotNull);
    expect(continuity.seasonId, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    appPrefs.dispose();
    transport.close();
  });
  testWidgets('large text small viewport preserves scroll and actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = fixture.Harness(
      (_) async => fixture.reply(fixture.previewJson()),
    );
    addTearDown(h.close);
    await h.repository.rememberInvite(fixture.inviteToken);
    await tester.pumpWidget(app(h, const LeagueInvitePage(), scale: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Aggiorna riepilogo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
  });
}
