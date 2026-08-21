import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/http_client_factory.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/game/data/api_game_repository.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/next_problems/data/api_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';

class AppDependencies extends StatelessWidget {
  const AppDependencies({
    required this.appPrefs,
    required this.config,
    required this.child,
    super.key,
  });

  final AppPrefs appPrefs;
  final AppConfig config;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppPrefs>.value(value: appPrefs),
        Provider<CivicLoopStore>(
          create: (context) =>
              CivicLoopStore(currentUserId: context.read<AppPrefs>().userId),
        ),
        Provider<http.Client>(
          create: (_) => createHttpClient(),
          dispose: (_, client) => client.close(),
        ),
        Provider<ApiClient>(
          create: (context) => ApiClient(
            baseUrl: config.apiBaseUrl,
            client: context.read<http.Client>(),
            timeout: config.apiTimeout,
          ),
        ),
        Provider<GameRepository>(
          create: (context) => createGameRepository(
            config: config,
            currentUserId: context.read<AppPrefs>().userId,
            mockStore: context.read<CivicLoopStore>(),
            apiClient: config.gameDataSource == GameDataSource.api
                ? context.read<ApiClient>()
                : null,
          ),
        ),
        Provider<NextProblemsRepository>(
          create: (context) => createNextProblemsRepository(
            config: config,
            currentUserId: context.read<AppPrefs>().userId,
            mockStore: context.read<CivicLoopStore>(),
            apiClient:
                config.nextProblemsDataSource == NextProblemsDataSource.api
                ? context.read<ApiClient>()
                : null,
          ),
        ),
      ],
      child: child,
    );
  }
}

GameRepository createGameRepository({
  required AppConfig config,
  required String currentUserId,
  required CivicLoopStore mockStore,
  ApiClient? apiClient,
}) {
  final localRepository = MockGameRepository(civicLoopStore: mockStore);
  return switch (config.gameDataSource) {
    GameDataSource.mock => localRepository,
    GameDataSource.api => ApiGameRepository(
      client: apiClient ?? (throw ArgumentError.notNull('apiClient')),
      userId: currentUserId,
      localFallback: localRepository,
    ),
  };
}

NextProblemsRepository createNextProblemsRepository({
  required AppConfig config,
  required String currentUserId,
  required CivicLoopStore mockStore,
  ApiClient? apiClient,
}) {
  return switch (config.nextProblemsDataSource) {
    NextProblemsDataSource.mock => MockNextProblemsRepository(
      currentUserId: currentUserId,
      store: mockStore,
    ),
    NextProblemsDataSource.api => ApiNextProblemsRepository(
      client: apiClient ?? (throw ArgumentError.notNull('apiClient')),
    ),
  };
}
