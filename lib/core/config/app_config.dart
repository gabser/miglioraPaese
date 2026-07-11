enum NextProblemsDataSource { mock, api }

class AppConfig {
  AppConfig({
    required this.nextProblemsDataSource,
    required Uri apiBaseUrl,
    this.apiTimeout = const Duration(seconds: 8),
  }) : apiBaseUrl = _validateApiBaseUrl(apiBaseUrl);

  factory AppConfig.fromEnvironment() {
    const dataSource = String.fromEnvironment(
      'NEXT_PROBLEMS_DATA_SOURCE',
      defaultValue: 'mock',
    );
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8787',
    );
    return AppConfig.fromValues(
      nextProblemsDataSource: dataSource,
      apiBaseUrl: apiBaseUrl,
    );
  }

  factory AppConfig.fromValues({
    String nextProblemsDataSource = 'mock',
    String apiBaseUrl = 'http://127.0.0.1:8787',
    Duration apiTimeout = const Duration(seconds: 8),
  }) {
    final source = switch (nextProblemsDataSource.trim().toLowerCase()) {
      'mock' => NextProblemsDataSource.mock,
      'api' => NextProblemsDataSource.api,
      final value => throw ArgumentError.value(
        value,
        'nextProblemsDataSource',
        'Valori supportati: mock, api.',
      ),
    };
    return AppConfig(
      nextProblemsDataSource: source,
      apiBaseUrl: Uri.parse(apiBaseUrl),
      apiTimeout: apiTimeout,
    );
  }

  final NextProblemsDataSource nextProblemsDataSource;
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
