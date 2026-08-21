enum NextProblemsDataSource { mock, api }

enum GameDataSource { mock, api }

class AppConfig {
  AppConfig({
    required this.nextProblemsDataSource,
    required this.gameDataSource,
    required Uri apiBaseUrl,
    this.apiTimeout = const Duration(seconds: 8),
  }) : apiBaseUrl = _validateApiBaseUrl(apiBaseUrl);

  factory AppConfig.fromEnvironment() {
    const dataSource = String.fromEnvironment(
      'NEXT_PROBLEMS_DATA_SOURCE',
      defaultValue: 'mock',
    );
    const gameDataSource = String.fromEnvironment(
      'GAME_DATA_SOURCE',
      defaultValue: 'mock',
    );
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8787',
    );
    return AppConfig.fromValues(
      nextProblemsDataSource: dataSource,
      gameDataSource: gameDataSource,
      apiBaseUrl: apiBaseUrl,
    );
  }

  factory AppConfig.fromValues({
    String nextProblemsDataSource = 'mock',
    String gameDataSource = 'mock',
    String apiBaseUrl = 'http://127.0.0.1:8787',
    Duration apiTimeout = const Duration(seconds: 8),
  }) {
    final nextProblemsSource = switch (nextProblemsDataSource
        .trim()
        .toLowerCase()) {
      'mock' => NextProblemsDataSource.mock,
      'api' => NextProblemsDataSource.api,
      final value => throw ArgumentError.value(
        value,
        'nextProblemsDataSource',
        'Valori supportati: mock, api.',
      ),
    };
    final gameSource = switch (gameDataSource.trim().toLowerCase()) {
      'mock' => GameDataSource.mock,
      'api' => GameDataSource.api,
      final value => throw ArgumentError.value(
        value,
        'gameDataSource',
        'Valori supportati: mock, api.',
      ),
    };
    return AppConfig(
      nextProblemsDataSource: nextProblemsSource,
      gameDataSource: gameSource,
      apiBaseUrl: Uri.parse(apiBaseUrl),
      apiTimeout: apiTimeout,
    );
  }

  final NextProblemsDataSource nextProblemsDataSource;
  final GameDataSource gameDataSource;
  final Uri apiBaseUrl;
  final Duration apiTimeout;

  static Uri _validateApiBaseUrl(Uri value) {
    if (!value.hasScheme ||
        (value.scheme != 'http' && value.scheme != 'https') ||
        value.host.isEmpty ||
        value.hasQuery ||
        value.hasFragment) {
      throw ArgumentError.value(
        value,
        'apiBaseUrl',
        'Deve essere un URL HTTP(S) assoluto senza query o fragment.',
      );
    }
    return value;
  }
}
