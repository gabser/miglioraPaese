import 'package:fanta_comune/features/cooperation/cooperation_repository.dart';
import 'package:fanta_comune/features/cooperation/cooperation_controller.dart';
import 'package:fanta_comune/features/fantasy/continuity/continuity_repository.dart';
import 'package:fanta_comune/features/measurements/data/measurement_repository.dart';
import 'package:fanta_comune/features/measurements/logic/measurement_controller.dart';
import 'package:fanta_comune/features/review/data/review_repository.dart';
import 'package:fanta_comune/features/review/logic/review_controller.dart';
import 'package:fanta_comune/features/account/data/fantasy_identity_recovery.dart';
import 'package:fanta_comune/features/missions/data/mission_repository.dart';
import 'package:fanta_comune/features/missions/logic/mission_controller.dart';
import 'package:fanta_comune/core/network/session_lease_source.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/account/data/account_repository.dart';
import 'package:fanta_comune/features/account/data/account_intent_store.dart';
import 'package:fanta_comune/features/account/data/authenticated_session_source.dart';
import 'package:fanta_comune/features/account/logic/account_controller.dart';
import 'package:fanta_comune/features/fantasy/data/api_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/data/local_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:fanta_comune/features/game/data/api_game_repository.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_submission_gateway.dart';
import 'package:fanta_comune/features/next_problems/logic/proposal_submission_coordinator.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_draft_store.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_scope.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
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
    this.httpClient,
    super.key,
  });

  final AppPrefs appPrefs;
  final AppConfig config;
  final Widget child;
  final http.Client? httpClient;

  @override
  Widget build(BuildContext context) {
    appPrefs.configuredMunicipalityId = config.pilotMunicipalityId;
    ApiFantasyRepository? currentFantasyApi;
    return MultiProvider(
      providers: [
        Provider<AppConfig>.value(value: config),
        ChangeNotifierProvider<AppPrefs>.value(value: appPrefs),
        ChangeNotifierProvider<LocalDataStore>.value(value: appPrefs.localData),
        Provider<ProposalDraftStore>(
          create: (_) => ProposalDraftStore(appPrefs.localData),
        ),
        Provider<CivicLoopStore>(
          create: (context) => CivicLoopStore(
            currentUserId: appPrefs.userId,
            userId: () => appPrefs.userId,
            localData: appPrefs.localData,
            storageKey: () =>
                'mock:${appPrefs.localData.namespace}:${ProposalScope.environmentFor(config)}',
          ),
          dispose: (_, store) => store.dispose(),
        ),
        Provider<http.Client>(
          create: (_) => httpClient ?? http.Client(),
          dispose: (_, client) {
            if (httpClient == null) client.close();
          },
        ),
        Provider<ApiClient>(
          create: (context) => ApiClient(
            baseUrl: config.apiBaseUrl,
            client: context.read<http.Client>(),
            timeout: config.apiTimeout,
          ),
        ),
        if (config.accountModeEnabled) ...[
          ChangeNotifierProvider<AccountSessionStore>(
            create: (context) => AccountSessionStore(
              client: context.read<ApiClient>(),
              data: appPrefs.localData,
              environment: ProposalScope.environmentFor(config),
            ),
          ),
          Provider<AccountIntentStore>(
            create: (_) => AccountIntentStore(
              appPrefs.localData,
              ProposalScope.environmentFor(config),
            ),
          ),
        ],
        Provider<ProposalSessionStore?>(
          lazy: false,
          create: (context) {
            if (config.nextProblemsDataSource != NextProblemsDataSource.api &&
                config.fantasyDataSource != FantasyDataSource.api &&
                config.gameDataSource != GameDataSource.api &&
                !config.accountModeEnabled) {
              return null;
            }
            final sessions = ProposalSessionStore(
              client: context.read<ApiClient>(),
              data: appPrefs.localData,
              environment: ProposalScope.environmentFor(config),
            );
            String? erasedNamespace;
            Future<void> resetRemoteData() async {
              if (config.accountModeEnabled) {
                final account = context.read<AccountSessionStore>();
                if (account.hasCredentials ||
                    account.authenticating ||
                    account.signingOut)
                  await account.logout();
              }
              if (config.fantasyDataSource == FantasyDataSource.api &&
                  erasedNamespace != appPrefs.localData.namespace) {
                final lease = await sessions.existing();
                if (lease != null) {
                  await context.read<ApiClient>().deleteJson([
                    'v1',
                    'session',
                  ], headers: lease.headers);
                  sessions.checkLease(lease);
                  erasedNamespace = appPrefs.localData.namespace;
                  if (config.fantasyModeEnabled) {
                    currentFantasyApi?.acceptRemoteErase();
                  }
                }
              }
              await sessions.revokeBeforeReset();
            }

            appPrefs.beforeClearAll = resetRemoteData;
            return sessions;
          },
          dispose: (_, sessions) {
            if (sessions != null) {
              appPrefs.beforeClearAll = null;
            }
          },
        ),
        if (config.accountModeEnabled) ...[
          ChangeNotifierProvider<AuthenticatedSessionSource>(
            create: (context) => AuthenticatedSessionSource(
              guest: context.read<ProposalSessionStore?>()!,
              account: context.read<AccountSessionStore>(),
            ),
          ),
          Provider<AccountRepository>(
            create: (context) => AccountRepository(
              client: context.read<ApiClient>(),
              sessions: context.read<AccountSessionStore>(),
              guest: context.read<ProposalSessionStore?>()!,
              environment: ProposalScope.environmentFor(config),
              beforeIdentityChange: FantasyIdentityRecovery(
                client: context.read<ApiClient>(),
                data: appPrefs.localData,
                guest: context.read<ProposalSessionStore?>()!,
                account: context.read<AccountSessionStore>(),
                environment: ProposalScope.environmentFor(config),
              ).recover,
            ),
          ),
          ChangeNotifierProvider<AccountController>(
            create: (context) => AccountController(
              repository: context.read<AccountRepository>(),
              intents: context.read<AccountIntentStore>(),
            ),
          ),
        ],
        if (config.missionsModeEnabled) ...[
          Provider<MissionRepository>(
            create: (context) => MissionRepository(
              client: context.read<ApiClient>(),
              account: context.read<AccountSessionStore>(),
              environment: ProposalScope.environmentFor(config),
              municipalityId:
                  config.pilotMunicipalityId ?? appPrefs.municipalityId ?? '',
              municipality: () =>
                  config.pilotMunicipalityId ?? appPrefs.municipalityId ?? '',
              municipalityChanges: appPrefs,
            ),
            dispose: (_, repository) => repository.dispose(),
          ),
          ChangeNotifierProvider<MissionController>(
            create: (context) => MissionController(
              repository: context.read<MissionRepository>(),
              municipalityChanges: appPrefs,
            ),
          ),
        ],
        if (config.reviewModeEnabled) ...[
          Provider<ReviewRepository>(
            create: (context) => ReviewRepository(
              client: context.read<ApiClient>(),
              account: context.read<AccountSessionStore>(),
              environment: ProposalScope.environmentFor(config),
              municipality: () =>
                  config.pilotMunicipalityId ?? appPrefs.municipalityId ?? '',
              municipalityChanges: appPrefs,
            ),
            dispose: (_, repository) => repository.dispose(),
          ),
          ChangeNotifierProvider<ReviewController>(
            create: (context) =>
                ReviewController(repository: context.read<ReviewRepository>()),
          ),
        ],
        if (config.measurementsModeEnabled) ...[
          Provider<MeasurementRepository>(
            create: (context) => MeasurementRepository(
              client: context.read<ApiClient>(),
              account: context.read<AccountSessionStore>(),
              review: context.read<ReviewRepository>(),
              environment: ProposalScope.environmentFor(config),
              municipality: () =>
                  config.pilotMunicipalityId ?? appPrefs.municipalityId ?? '',
              municipalityChanges: appPrefs,
            ),
            dispose: (_, r) => r.dispose(),
          ),
          ChangeNotifierProvider<MeasurementController>(
            create: (context) =>
                MeasurementController(context.read<MeasurementRepository>()),
          ),
        ],
        if (config.cooperationModeEnabled) ...[
          ChangeNotifierProvider<CooperationRepository>(
            create: (context) => CooperationRepository(
              client: context.read<ApiClient>(),
              account: context.read<AccountSessionStore>(),
              municipality: () =>
                  config.pilotMunicipalityId ?? appPrefs.municipalityId ?? '',
              municipalityChanges: appPrefs,
            ),
          ),
          ChangeNotifierProvider<CooperationController>(
            create: (context) =>
                CooperationController(context.read<CooperationRepository>()),
          ),
        ],
        // Alias only: ownership and identity notifications stay with the source provider.
        InheritedProvider<SessionLeaseSource?>(
          create: (context) => config.accountModeEnabled
              ? context.read<AuthenticatedSessionSource>()
              : context.read<ProposalSessionStore?>(),
        ),
        Provider<GameRepository>(
          create: (context) => createGameRepository(
            config: config,
            currentUserId: appPrefs.userId,
            mockStore: context.read<CivicLoopStore>(),
            apiClient: context.read<ApiClient>(),
            sessions: context.read<SessionLeaseSource?>(),
          ),
          dispose: (_, repository) {
            if (repository is MockGameRepository) repository.dispose();
          },
        ),
        if (config.leagueContinuityModeEnabled)
          ChangeNotifierProvider<LeagueContinuityRepository>(
            create: (context) => LeagueContinuityRepository(
              client: context.read<ApiClient>(),
              data: appPrefs.localData,
              sessions: context.read<SessionLeaseSource?>()!,
              account: config.accountModeEnabled
                  ? context.read<AccountSessionStore>()
                  : null,
              environment: ProposalScope.environmentFor(config),
              intentKey: 'league-invite-intent:${config.apiBaseUrl}',
              municipality: () =>
                  config.pilotMunicipalityId ??
                  MunicipalityCatalog.apiIdFor(appPrefs.municipalityId ?? '') ??
                  '',
              municipalityChanges: appPrefs,
              identityChanges: config.accountModeEnabled
                  ? context.read<AuthenticatedSessionSource>()
                  : null,
            ),
          ),
        if (config.fantasyModeEnabled) ...[
          Provider<FantasyRepository>(
            dispose: (_, r) {
              if (r is ApiFantasyRepository) r.dispose();
            },
            create: (context) =>
                config.fantasyDataSource == FantasyDataSource.mock
                ? LocalFantasyRepository(appPrefs)
                : currentFantasyApi = ApiFantasyRepository(
                    client: context.read<ApiClient>(),
                    prefs: appPrefs,
                    sessions: context.read<SessionLeaseSource?>(),
                    environment: ProposalScope.environmentFor(config),
                    municipality: () =>
                        config.pilotMunicipalityId ??
                        MunicipalityCatalog.apiIdFor(
                          appPrefs.municipalityId ?? '',
                        ) ??
                        '',
                    municipalityChanges: appPrefs,
                    municipalityId:
                        config.pilotMunicipalityId ??
                        MunicipalityCatalog.apiIdFor(
                          appPrefs.municipalityId ?? '',
                        ) ??
                        '',
                  ),
          ),
          ChangeNotifierProvider<FantasyManager>(
            create: (context) {
              final manager = FantasyManager.withRepository(
                context.read<FantasyRepository>(),
                identityChanges: config.accountModeEnabled
                    ? context.read<AuthenticatedSessionSource>()
                    : null,
              );
              if (config.leagueContinuityModeEnabled) {
                context.read<LeagueContinuityRepository>().observeSeason(
                  manager,
                  () => manager.hasData ? manager.season.id : null,
                );
              }
              return manager;
            },
          ),
        ],
        Provider<NextProblemsRepository>(
          create: (context) => createNextProblemsRepository(
            config: config,
            currentUserId: context.read<AppPrefs>().userId,
            mockStore: context.read<CivicLoopStore>(),
            proposalSessions: context.read<ProposalSessionStore?>(),
            apiClient:
                config.nextProblemsDataSource == NextProblemsDataSource.api
                ? context.read<ApiClient>()
                : null,
          ),
        ),
        ChangeNotifierProvider<ProposalSubmissionCoordinator>(
          create: (context) => ProposalSubmissionCoordinator(
            store: ProposalSubmissionStore(appPrefs.localData),
            drafts: context.read<ProposalDraftStore>(),
            gateway:
                context.read<NextProblemsRepository>()
                    as ProposalSubmissionGateway,
            isMock:
                config.nextProblemsDataSource == NextProblemsDataSource.mock,
          ),
        ),
      ],
      child: child,
    );
  }
}

NextProblemsRepository createNextProblemsRepository({
  required AppConfig config,
  required String currentUserId,
  required CivicLoopStore mockStore,
  ApiClient? apiClient,
  ProposalSessionStore? proposalSessions,
}) {
  return switch (config.nextProblemsDataSource) {
    NextProblemsDataSource.mock => MockNextProblemsRepository(
      currentUserId: currentUserId,
      store: mockStore,
    ),
    NextProblemsDataSource.api => ApiNextProblemsRepository(
      client: apiClient ?? (throw ArgumentError.notNull('apiClient')),
      userId: currentUserId,
      sessions: proposalSessions,
    ),
  };
}

GameRepository createGameRepository({
  required AppConfig config,
  required String currentUserId,
  required CivicLoopStore mockStore,
  ApiClient? apiClient,
  SessionLeaseSource? sessions,
}) => switch (config.gameDataSource) {
  GameDataSource.mock => MockGameRepository(civicLoopStore: mockStore),
  GameDataSource.api => ApiGameRepository(
    client: apiClient ?? (throw ArgumentError.notNull('apiClient')),
    userId: currentUserId,
    sessions: sessions,
  ),
};
