import 'package:flutter/widgets.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/data/api_fantasy_repository.dart';

const session = {
  'token': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'submissionScope': '11111111-1111-4111-8111-111111111111',
  'capabilities': {
    'proposalLocation': true,
    'publicDetail': true,
    'privateSubmissionLookup': true,
    'scopedIdempotency': true,
    'revocation': true,
    'sessionRequiredForRecovery': true,
  },
};
http.Response response(Object body, [int code = 200]) =>
    http.Response(jsonEncode(body), code);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'fantasy is off by default in environment and explicit constructors',
    () {
      expect(AppConfig.fromEnvironment().fantasyModeEnabled, isFalse);
      expect(AppConfig.fromValues().fantasyModeEnabled, isFalse);
      expect(
        AppConfig(
          nextProblemsDataSource: NextProblemsDataSource.mock,
          apiBaseUrl: Uri.parse('http://localhost'),
        ).fantasyModeEnabled,
        isFalse,
      );
    },
  );
  testWidgets(
    'explicit pilot remains authoritative after local preferences reset',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'municipality_id': 'comune:Bologna',
      });
      final prefs = AppPrefs(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        AppDependencies(
          appPrefs: prefs,
          config: AppConfig.fromValues(pilotMunicipalityId: 'tuglie'),
          child: const SizedBox.shrink(),
        ),
      );
      expect(prefs.municipalityId, 'tuglie');
      await prefs.clearAll();
      expect(prefs.municipalityId, 'tuglie');
      await tester.pumpWidget(
        AppDependencies(
          appPrefs: prefs,
          config: AppConfig.fromValues(),
          child: const SizedBox.shrink(),
        ),
      );
      expect(prefs.municipalityId, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      prefs.dispose();
    },
  );
  for (final remoteClear in [true, false]) {
    test(
      'delayed load is rejected after ${remoteClear ? "remote erase" : "local reset"}',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = AppPrefs(await SharedPreferences.getInstance());
        final arrived = Completer<void>(), release = Completer<void>();
        final requests = <http.Request>[];
        final transport = MockClient((req) async {
          requests.add(req);
          if (req.url.path == '/v1/proposal-session') return response(session);
          if (req.url.path.endsWith('/revoke') || req.method == 'DELETE')
            return response({'status': 'erased', 'revoked': true});
          if (req.url.path.endsWith('/season')) {
            arrived.complete();
            await release.future;
            return response({});
          }
          throw StateError('Unexpected request ${req.url}');
        });
        final repo = ApiFantasyRepository(
          client: ApiClient(
            baseUrl: Uri.parse('http://localhost'),
            client: transport,
          ),
          prefs: prefs,
          environment: 'reset-test',
          municipalityId: 'tuglie',
        );
        final loading = repo.load();
        final rejected = expectLater(
          loading,
          throwsA(isA<LocalDataResetException>()),
        );
        await arrived.future;
        if (remoteClear) {
          await repo.clear();
        } else {
          await prefs.clearAll();
        }
        release.complete();
        await rejected;
        expect(repo.cached, isNull);
        expect(repo.hasPendingTransfer, isFalse);
        expect(prefs.fantasyStateJson, isNull);
        for (final req in requests.where(
          (r) => r.url.path.contains('/fantasy/') || r.method == 'DELETE',
        )) {
          expect(
            req.headers['Authorization'] ?? req.headers['authorization'],
            'Bearer ${session['token']}',
          );
          expect(
            req.headers.keys.any((key) => key.toLowerCase() == 'x-user-id'),
            isFalse,
          );
        }
        prefs.dispose();
        transport.close();
      },
    );
  }
  test('unknown resource 404 never enrolls or falls back to demo', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = AppPrefs(await SharedPreferences.getInstance());
    var enrolled = false;
    final transport = MockClient((req) async {
      if (req.url.path == '/v1/proposal-session') return response(session);
      if (req.url.path.endsWith('/team'))
        return response({'error': 'not_found'}, 404);
      if (req.url.path.endsWith('/enrollment')) enrolled = true;
      return response({});
    });
    final repo = ApiFantasyRepository(
      client: ApiClient(
        baseUrl: Uri.parse('http://localhost'),
        client: transport,
      ),
      prefs: prefs,
      environment: '404-test',
      municipalityId: 'tuglie',
    );
    await expectLater(repo.load(), throwsA(isA<ApiException>()));
    expect(enrolled, isFalse);
    expect(repo.cached, isNull);
    prefs.dispose();
    transport.close();
  });
}
