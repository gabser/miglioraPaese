import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../../../helpers/test_app.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/data/api_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_api_mapper.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';

class CookieClient extends http.BaseClient {
  final http.Client inner = http.Client();
  String? cookie;
  bool loseTransferReply = false;
  bool offline = false;
  bool refuseDeletion = false;
  final List<String> keys = [];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw http.ClientException('offline');
    if (refuseDeletion && request.method == 'DELETE')
      return http.StreamedResponse(
        Stream.value(
          utf8.encode('{"error":"unavailable","message":"Riprova"}'),
        ),
        503,
      );
    if (cookie != null) request.headers['cookie'] = cookie!;
    final response = await inner.send(request);
    cookie = response.headers['set-cookie']?.split(';').first ?? cookie;
    if (request.url.path.endsWith('/transfers/confirmation')) {
      keys.add(
        (jsonDecode((request as http.Request).body) as Map)['idempotencyKey']
            as String,
      );
      if (loseTransferReply) {
        loseTransferReply = false;
        await response.stream.drain<void>();
        throw http.ClientException('reply lost after commit');
      }
    }
    return response;
  }

  @override
  void close() => inner.close();
}

class BackendFixture {
  late Process process;
  late StreamIterator<String> lines;
  late String url;
  Future<void> start() async {
    final node = Platform.environment['FANTASY_TEST_NODE'] ?? 'node';
    process = await Process.start(node, [
      'test/support/fantasy_backend_fixture.mjs',
    ]);
    process.stderr.drain<void>();
    lines = StreamIterator(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    url = (await read())['url'] as String;
  }

  Future<Map<String, dynamic>> read() async {
    await lines.moveNext().timeout(const Duration(seconds: 15));
    return (jsonDecode(lines.current) as Map).cast<String, dynamic>();
  }

  Future<void> command(String action, [String? value]) async {
    process.stdin.writeln(jsonEncode({'action': action, 'value': value}));
    final result = await read();
    if (result['error'] != null) throw StateError(result['error'] as String);
    if (result['url'] != null) url = result['url'] as String;
  }

  Future<void> stop() async {
    process.stdin.writeln('{"action":"stop"}');
    await process.stdin.close();
    await process.exitCode.timeout(const Duration(seconds: 10));
    await lines.cancel();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('fantasy selector is independent and rejects unknown values', () {
    expect(
      AppConfig.fromValues(fantasyDataSource: 'api').gameDataSource,
      GameDataSource.mock,
    );
    expect(AppConfig.fromValues().fantasyDataSource, FantasyDataSource.mock);
    expect(
      () => AppConfig.fromValues(fantasyDataSource: 'other'),
      throwsArgumentError,
    );
  });
  test(
    'strict mapper rejects unknown enum, incomplete DTO and missing timezone',
    () {
      expect(() => FantasyApiMapper.trend('improve'), throwsFormatException);
      expect(() => FantasyApiMapper.role('unknown'), throwsFormatException);
      expect(() => FantasyApiMapper.source('approved'), throwsFormatException);
      expect(() => FantasyApiMapper.answer('free text'), throwsFormatException);
      expect(
        () => FantasyApiMapper.card({'id': 'x'}),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => FantasyApiMapper.date('2026-10-08T00:00:00'),
        throwsFormatException,
      );
    },
  );
  test(
    'real synthetic backend: accepted state, lost transfer reply, restart, server clock, frozen history and privacy',
    () async {
      HttpOverrides.global = null;
      final fixture = BackendFixture();
      await fixture.start();
      addTearDown(fixture.stop);
      SharedPreferences.setMockInitialValues({
        'fantasy_manager_state_v1': 'DEMO NOT IMPORTED',
      });
      final prefs = AppPrefs(await SharedPreferences.getInstance());
      final transport = CookieClient();
      addTearDown(transport.close);
      ApiFantasyRepository repository() => ApiFantasyRepository(
        client: ApiClient(baseUrl: Uri.parse(fixture.url), client: transport),
        prefs: prefs,
        environment: 'isolated-test',
        municipalityId: 'tuglie',
      );
      var repo = repository();
      var data = await repo.load();
      expect(data.state.predictions, isEmpty);
      expect(data.season!.id, contains('fantasy-demo-tuglie'));
      expect(prefs.fantasyStateJson, 'DEMO NOT IMPORTED');
      final manager = FantasyManager.withRepository(
        repo,
        now: () => DateTime.utc(2099),
        observeTime: false,
      );
      addTearDown(manager.dispose);
      await manager.settled;
      expect(manager.isLocked, isFalse);
      expect(manager.now.year, 2026);
      await manager.setPrediction('buche-centro', CivicTrend.stable);
      await manager.settled;
      expect(manager.predictions['buche-centro'], CivicTrend.stable);
      data = repo.cached!;
      await expectLater(
        repo.execute(
          const SetFantasyCaptain('bus-stazione'),
          expectedRevision: 1,
        ),
        throwsA(isA<FantasyFailure>()),
      );
      final quote = await repo.quoteTransfer(
        'parco-nord',
        'fontanelle-ovest',
        data.revision,
      );
      transport.loseTransferReply = true;
      await expectLater(
        repo.execute(
          TransferFantasyCard(
            'parco-nord',
            'fontanelle-ovest',
            0,
            quote: quote,
          ),
          expectedRevision: data.revision,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(repo.hasPendingTransfer, isTrue);
      repo = repository();
      await repo.load();
      expect(repo.hasPendingTransfer, isTrue);
      data = await repo.retryPendingTransfer();
      expect(transport.keys.length, 2);
      expect(transport.keys.toSet().length, 1);
      expect(data.state.transfers.length, 1);
      expect(data.state.confirmed, isFalse);
      // Restore a verified starter for a complete five-card reveal.
      data = await repo.execute(
        const TransferFantasyCard('fontanelle-ovest', 'parco-nord', 0),
        expectedRevision: data.revision,
      );
      for (final id in data.state.starterIds)
        data = await repo.execute(
          SetFantasyPrediction(id, CivicTrend.stable),
          expectedRevision: data.revision,
        );
      data = await repo.execute(
        const ConfirmFantasyLineup(),
        expectedRevision: data.revision,
      );
      final acceptedRevision = data.revision;
      transport.offline = true;
      await expectLater(
        repo.execute(
          const SetFantasyCaptain('bus-stazione'),
          expectedRevision: acceptedRevision,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(repo.cached!.revision, acceptedRevision);
      transport.offline = false;
      await fixture.command('clock', '2026-10-10T00:00:00Z');
      await expectLater(
        repo.execute(
          const SetFantasyCaptain('bus-stazione'),
          expectedRevision: acceptedRevision,
        ),
        throwsA(isA<ApiException>()),
      );
      await fixture.command('clock', '2026-10-15T00:00:00Z');
      await fixture.command('publish');
      data = await repo.load();
      expect(data.summaryStatuses['matchday-1'], 'final');
      expect(data.summaries['matchday-1']!.total, 28);
      final outcome = data.outcomes.firstWhere(
        (o) => o.cardId == 'buche-centro',
      );
      data = await repo.execute(
        ReflectOnFantasyCard(outcome, ReflectionAnswer.observedIntervention),
        expectedRevision: data.revision,
      );
      expect(data.summaries['matchday-1']!.total, 29);
      final history = data.scores.map((k, v) => MapEntry(k, v.total));
      await fixture.command('restart');
      repo = repository();
      data = await repo.load();
      expect(data.scores.map((k, v) => MapEntry(k, v.total)), history);
      data = await repo.execute(
        const SetFantasyPrediction('buche-centro', CivicTrend.worsens),
        expectedRevision: data.revision,
      );
      expect(data.summaries['matchday-1']!.total, 29);
      transport.refuseDeletion = true;
      await expectLater(repo.clear(), throwsA(isA<ApiException>()));
      expect(repo.cached, isNotNull);
      expect(prefs.fantasyStateJson, isNotNull);
      transport.refuseDeletion = false;
      await repo.clear();
      expect(repo.cached, isNull);
      expect(prefs.fantasyStateJson, isNull);
      final other = CookieClient();
      addTearDown(other.close);
      final fresh = await ApiFantasyRepository(
        client: ApiClient(baseUrl: Uri.parse(fixture.url), client: other),
        prefs: prefs,
        environment: 'isolated-test',
        municipalityId: 'tuglie',
      ).load();
      expect(fresh.state.transfers, isEmpty);
      expect(fresh.scores, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  for (final size in [
    const Size(390, 844),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    testWidgets('remote accepted state renders all areas at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BackendFixture fixture;
      late CookieClient transport;
      late AppPrefs prefs;
      late FantasyManager manager;
      await tester.runAsync(() async {
        HttpOverrides.global = null;
        fixture = BackendFixture();
        await fixture.start();
        transport = CookieClient();
        SharedPreferences.setMockInitialValues({});
        prefs = AppPrefs(await SharedPreferences.getInstance());
        manager = FantasyManager.withRepository(
          ApiFantasyRepository(
            client: ApiClient(
              baseUrl: Uri.parse(fixture.url),
              client: transport,
            ),
            prefs: prefs,
            environment: 'isolated-widget',
            municipalityId: 'tuglie',
          ),
          observeTime: false,
        );
        await manager.settled;
      });
      expect(manager.hasData, isTrue);
      await tester.pumpWidget(
        buildTestApp(
          prefs,
          config: AppConfig.fromValues(
            fantasyModeEnabled: true,
            fantasyDataSource: 'api',
            pilotMunicipalityId: 'tuglie',
          ),
          fantasyManager: manager,
        ),
      );
      await pumpRoutingFrame(tester);
      await tester.tap(find.text('Crea la tua rosa'));
      await pumpRoutingFrame(tester);
      for (final label in ['Giornata', 'Mercato', 'Leghe', 'Squadra']) {
        await tester.tap(find.text(label).last);
        await pumpRoutingFrame(tester);
        expect(tester.takeException(), isNull);
      }
      expect(find.textContaining('Rehearsal API'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
      await tester.runAsync(() async {
        transport.close();
        await fixture.stop();
      });
    });
  }
}
