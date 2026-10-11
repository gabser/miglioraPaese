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
        Provider<GameRepository>(
          create: (context) => MockGameRepository(
            civicLoopStore: context.read<CivicLoopStore>(),
          ),
          dispose: (_, repository) =>
              (repository as MockGameRepository).dispose(),
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
        Provider<ProposalSessionStore?>(
          lazy: false,
          create: (context) {
            if (config.nextProblemsDataSource != NextProblemsDataSource.api) {
              return null;
            }
            final sessions = ProposalSessionStore(
              client: context.read<ApiClient>(),
              data: appPrefs.localData,
              environment: ProposalScope.environmentFor(config),
            );
            appPrefs.beforeClearAll = sessions.revokeBeforeReset;
            return sessions;
          },
          dispose: (_, sessions) {
            if (sessions != null &&
                appPrefs.beforeClearAll == sessions.revokeBeforeReset) {
              appPrefs.beforeClearAll = null;
            }
          },
        ),
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
