import 'package:fanta_comune/core/models/municipality_catalog.dart';

enum NextProblemsDataSource { mock, api }

enum FantasyDataSource { mock, api }

enum GameDataSource { mock, api }

class AppConfig {
  AppConfig({
    required this.nextProblemsDataSource,
    this.gameDataSource = GameDataSource.mock,
    this.fantasyModeEnabled = false,
    this.accountModeEnabled = false,
    this.missionsModeEnabled = false,
    this.reviewModeEnabled = false,
    this.measurementsModeEnabled = false,
    this.leagueContinuityModeEnabled = false,
    this.cooperationModeEnabled = false,
    this.fantasyDataSource = FantasyDataSource.mock,
    this.tuglieMapEnabled = false,
    this.mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.mapProviderAttribution = '',
    this.mapProviderAttributionUrl = '',
    required Uri apiBaseUrl,
    String? pilotMunicipalityId,
    this.apiTimeout = const Duration(seconds: 8),
    String? candidateId,
  }) : candidateId = _validateCandidateId(candidateId),
       apiBaseUrl = _validateApiBaseUrl(apiBaseUrl),
       pilotMunicipalityId = _validatePilotMunicipalityId(pilotMunicipalityId) {
    if (cooperationModeEnabled &&
        (!measurementsModeEnabled ||
            !reviewModeEnabled ||
            !missionsModeEnabled ||
            !accountModeEnabled ||
            !fantasyModeEnabled ||
            fantasyDataSource != FantasyDataSource.api)) {
      throw ArgumentError(
        "La cooperazione richiede account, missioni, revisione, misurazioni e fantasy API.",
      );
    }
    if (leagueContinuityModeEnabled &&
        (!fantasyModeEnabled || fantasyDataSource != FantasyDataSource.api)) {
      throw ArgumentError(
        "La continuità delle leghe richiede fantasy API esplicito.",
      );
    }
    if (measurementsModeEnabled &&
        (!reviewModeEnabled ||
            !missionsModeEnabled ||
            !accountModeEnabled ||
            !fantasyModeEnabled ||
            fantasyDataSource != FantasyDataSource.api)) {
      throw ArgumentError(
        'Le misurazioni richiedono revisione, missioni, account e fantasy API.',
      );
    }
    if (reviewModeEnabled && (!missionsModeEnabled || !accountModeEnabled))
      throw ArgumentError(
        'La revisione richiede missioni e account espliciti.',
      );
  }

  factory AppConfig.fromEnvironment() {
    const dataSource = String.fromEnvironment(
      'NEXT_PROBLEMS_DATA_SOURCE',
      defaultValue: 'mock',
    );
    const gameDataSource = String.fromEnvironment(
      'GAME_DATA_SOURCE',
      defaultValue: 'mock',
    );
    const fantasyDataSource = String.fromEnvironment(
      'FANTASY_DATA_SOURCE',
      defaultValue: 'mock',
    );
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8787',
    );
    const pilotMunicipalityId = String.fromEnvironment('PILOT_MUNICIPALITY_ID');
    const missionsModeEnabled = bool.fromEnvironment(
      'MISSIONS_MODE_ENABLED',
      defaultValue: false,
    );
    const measurementsModeEnabled = bool.fromEnvironment(
      'MEASUREMENTS_MODE_ENABLED',
      defaultValue: false,
    );
    const reviewModeEnabled = bool.fromEnvironment(
      'REVIEW_MODE_ENABLED',
      defaultValue: false,
    );
    const accountModeEnabled = bool.fromEnvironment(
      'ACCOUNT_MODE_ENABLED',
      defaultValue: false,
    );
    const fantasyModeEnabled = bool.fromEnvironment(
      'FANTASY_MODE_ENABLED',
      defaultValue: false,
    );
    return AppConfig.fromValues(
      candidateId: const String.fromEnvironment('CANDIDATE_ID'),
      cooperationModeEnabled: const bool.fromEnvironment(
        "COOPERATION_MODE_ENABLED",
        defaultValue: false,
      ),
      tuglieMapEnabled: const bool.fromEnvironment('TUGLIE_MAP_ENABLED'),
      mapTileUrl: const String.fromEnvironment(
        'MAP_TILE_URL',
        defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ),
      mapProviderAttribution: const String.fromEnvironment(
        'MAP_PROVIDER_ATTRIBUTION',
      ),
      mapProviderAttributionUrl: const String.fromEnvironment(
        'MAP_PROVIDER_ATTRIBUTION_URL',
      ),
      nextProblemsDataSource: dataSource,
      gameDataSource: gameDataSource,
      fantasyDataSource: fantasyDataSource,
      apiBaseUrl: apiBaseUrl,
      pilotMunicipalityId: pilotMunicipalityId,
      fantasyModeEnabled: fantasyModeEnabled,
      accountModeEnabled: accountModeEnabled,
      missionsModeEnabled: missionsModeEnabled,
      reviewModeEnabled: reviewModeEnabled,
      measurementsModeEnabled: measurementsModeEnabled,
      leagueContinuityModeEnabled: const bool.fromEnvironment(
        "LEAGUE_CONTINUITY_MODE_ENABLED",
        defaultValue: false,
      ),
    );
  }

  factory AppConfig.fromValues({
    String nextProblemsDataSource = 'mock',
    String gameDataSource = 'mock',
    String fantasyDataSource = 'mock',
    String apiBaseUrl = 'http://127.0.0.1:8787',
    String? pilotMunicipalityId,
    bool fantasyModeEnabled = false,
    bool accountModeEnabled = false,
    bool missionsModeEnabled = false,
    bool reviewModeEnabled = false,
    bool measurementsModeEnabled = false,
    bool leagueContinuityModeEnabled = false,
    bool cooperationModeEnabled = false,
    bool tuglieMapEnabled = false,
    String mapTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    String mapProviderAttribution = '',
    String mapProviderAttributionUrl = '',
    Duration apiTimeout = const Duration(seconds: 8),
    String? candidateId,
  }) {
    if (reviewModeEnabled && (!missionsModeEnabled || !accountModeEnabled))
      throw ArgumentError(
        'La revisione richiede missioni e account espliciti.',
      );
    if (missionsModeEnabled && !accountModeEnabled)
      throw ArgumentError(
        'Le missioni richiedono ACCOUNT_MODE_ENABLED esplicito.',
      );
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
    final fantasySource = switch (fantasyDataSource.trim().toLowerCase()) {
      'mock' => FantasyDataSource.mock,
      'api' => FantasyDataSource.api,
      final value => throw ArgumentError.value(value, 'fantasyDataSource'),
    };
    return AppConfig(
      nextProblemsDataSource: nextProblemsSource,
      gameDataSource: gameSource,
      fantasyDataSource: fantasySource,
      fantasyModeEnabled: fantasyModeEnabled,
      accountModeEnabled: accountModeEnabled,
      missionsModeEnabled: missionsModeEnabled,
      reviewModeEnabled: reviewModeEnabled,
      measurementsModeEnabled: measurementsModeEnabled,
      leagueContinuityModeEnabled: leagueContinuityModeEnabled,
      cooperationModeEnabled: cooperationModeEnabled,
      tuglieMapEnabled: tuglieMapEnabled,
      mapTileUrl: mapTileUrl,
      mapProviderAttribution: mapProviderAttribution,
      mapProviderAttributionUrl: mapProviderAttributionUrl,
      apiBaseUrl: Uri.parse(apiBaseUrl),
      pilotMunicipalityId: pilotMunicipalityId,
      apiTimeout: apiTimeout,
      candidateId: candidateId,
    );
  }

  final NextProblemsDataSource nextProblemsDataSource;
  final GameDataSource gameDataSource;
  final FantasyDataSource fantasyDataSource;
  final bool fantasyModeEnabled;
  final bool accountModeEnabled;
  final bool missionsModeEnabled;
  final bool reviewModeEnabled;
  final bool measurementsModeEnabled;
  final bool leagueContinuityModeEnabled;
  final bool cooperationModeEnabled;
  final bool tuglieMapEnabled;
  final String mapTileUrl;
  final String mapProviderAttribution;
  final String mapProviderAttributionUrl;
  final Uri apiBaseUrl;
  final String? pilotMunicipalityId;
  final Duration apiTimeout;
  final String? candidateId;

  static String? _validateCandidateId(String? value) {
    if (value == null || value.isEmpty) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
      throw ArgumentError(
        'CANDIDATE_ID deve essere un digest SHA256 esadecimale minuscolo.',
      );
    }
    return value;
  }

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

  static String? _validatePilotMunicipalityId(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final apiId = MunicipalityCatalog.apiIdFor(value.trim());
    if (apiId == null) {
      throw ArgumentError.value(
        value,
        'pilotMunicipalityId',
        'Il Comune pilot deve avere un mapping API esplicito.',
      );
    }
    return apiId;
  }
}
