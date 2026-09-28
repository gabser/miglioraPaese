import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/info/presentation/privacy_page.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('API mode confirms and deletes remote data before local prefs', (
    tester,
  ) async {
    late http.Request captured;
    final prefs = await createTestPrefs({
      'municipality_id': 'castel-bolognese',
    });
    final config = AppConfig.fromValues(
      gameDataSource: 'api',
      pilotMunicipalityId: 'castel-bolognese',
    );
    final apiClient = ApiClient(
      baseUrl: Uri.parse('https://pilot.example.test'),
      client: MockClient((request) async {
        captured = request;
        return http.Response('{"status":"deleted"}', 200);
      }),
    );

    await tester.pumpWidget(_testApp(prefs, config, apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elimina dati e riparti'));
    await tester.pumpAndSettle();
    expect(find.text('Eliminare i dati del pilot?'), findsOneWidget);
    await tester.tap(find.text('Elimina e riparti'));
    await tester.pumpAndSettle();

    expect(captured.method, 'DELETE');
    expect(captured.url.path, '/v1/session');
    expect(prefs.municipalityId, isNull);
    expect(find.text('Boot'), findsOneWidget);
  });

  testWidgets('API deletion failure preserves local preferences', (
    tester,
  ) async {
    final prefs = await createTestPrefs({
      'municipality_id': 'castel-bolognese',
    });
    final config = AppConfig.fromValues(
      nextProblemsDataSource: 'api',
      pilotMunicipalityId: 'castel-bolognese',
    );
    final apiClient = ApiClient(
      baseUrl: Uri.parse('https://pilot.example.test'),
      client: MockClient(
        (_) async => http.Response(
          '{"error":"service_unavailable","message":"Riprova più tardi."}',
          503,
        ),
      ),
    );

    await tester.pumpWidget(_testApp(prefs, config, apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Elimina dati e riparti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina e riparti'));
    await tester.pumpAndSettle();

    expect(prefs.municipalityId, 'castel-bolognese');
    expect(find.textContaining('Cancellazione non completata'), findsOneWidget);
  });
}

Widget _testApp(AppPrefs prefs, AppConfig config, ApiClient apiClient) {
  final router = GoRouter(
    initialLocation: '/privacy',
    routes: [
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyPage()),
      GoRoute(
        path: '/boot',
        builder: (_, _) => const Scaffold(body: Text('Boot')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: config),
      ChangeNotifierProvider<AppPrefs>.value(value: prefs),
      Provider<ApiClient>.value(value: apiClient),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
