import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/game/data/api_game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/next_problems/data/api_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';

void main() {
  test('configuration defaults to mock and validates opt-in values', () {
    expect(
      AppConfig.fromValues().nextProblemsDataSource,
      NextProblemsDataSource.mock,
    );
    expect(AppConfig.fromValues().gameDataSource, GameDataSource.mock);
    expect(
      AppConfig.fromValues(
        nextProblemsDataSource: 'API',
      ).nextProblemsDataSource,
      NextProblemsDataSource.api,
    );
    expect(
      () => AppConfig.fromValues(nextProblemsDataSource: 'automatic'),
      throwsArgumentError,
    );
    expect(
      AppConfig.fromValues(gameDataSource: 'API').gameDataSource,
      GameDataSource.api,
    );
    expect(
      () => AppConfig.fromValues(gameDataSource: 'automatic'),
      throwsArgumentError,
    );
    expect(
      () => AppConfig.fromValues(apiBaseUrl: 'not-an-url'),
      throwsArgumentError,
    );
  });

  test('repository factory keeps mock as the default', () {
    final store = CivicLoopStore(currentUserId: 'user:test');
    final repository = createNextProblemsRepository(
      config: AppConfig.fromValues(),
      currentUserId: 'user:test',
      mockStore: store,
    );

    expect(repository, isA<MockNextProblemsRepository>());
  });

  test('repository factory creates API implementation only when opted in', () {
    final config = AppConfig.fromValues(nextProblemsDataSource: 'api');
    final apiClient = ApiClient(
      baseUrl: config.apiBaseUrl,
      client: MockClient((_) async => http.Response('{"items":[]}', 200)),
    );

    final repository = createNextProblemsRepository(
      config: config,
      currentUserId: 'user:test',
      mockStore: CivicLoopStore(currentUserId: 'user:test'),
      apiClient: apiClient,
    );

    expect(repository, isA<ApiNextProblemsRepository>());
  });

  test('API opt-in requires an injected client', () {
    expect(
      () => createNextProblemsRepository(
        config: AppConfig.fromValues(nextProblemsDataSource: 'api'),
        currentUserId: 'user:test',
        mockStore: CivicLoopStore(currentUserId: 'user:test'),
      ),
      throwsArgumentError,
    );
  });

  test('game repository is mock by default and API only when opted in', () {
    final store = CivicLoopStore(currentUserId: 'user:test');
    final mock = createGameRepository(
      config: AppConfig.fromValues(),
      currentUserId: 'user:test',
      mockStore: store,
    );
    final config = AppConfig.fromValues(gameDataSource: 'api');
    final api = createGameRepository(
      config: config,
      currentUserId: 'user:test',
      mockStore: store,
      apiClient: ApiClient(
        baseUrl: config.apiBaseUrl,
        client: MockClient((_) async => http.Response('{"items":[]}', 200)),
      ),
    );

    expect(mock, isA<MockGameRepository>());
    expect(api, isA<ApiGameRepository>());
    expect(api.currentUserId, 'user:test');
  });

  test('game API opt-in requires an injected client', () {
    expect(
      () => createGameRepository(
        config: AppConfig.fromValues(gameDataSource: 'api'),
        currentUserId: 'user:test',
        mockStore: CivicLoopStore(currentUserId: 'user:test'),
      ),
      throwsArgumentError,
    );
  });
}
