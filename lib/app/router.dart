import 'package:fanta_comune/features/info/presentation/diagnostics_page.dart';
import 'package:fanta_comune/features/cooperation/cooperation_page.dart';
import 'package:fanta_comune/features/fantasy/continuity/invite_page.dart';
import 'package:fanta_comune/features/measurements/presentation/measurement_page.dart';
import 'package:fanta_comune/features/review/presentation/review_page.dart';
import 'package:fanta_comune/features/account/presentation/account_page.dart';
import 'package:fanta_comune/features/missions/presentation/mission_page.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/widgets.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/features/fantasy/presentation/pages/fantasy_pages.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/boot/boot_screen.dart';
import 'package:fanta_comune/features/boot/design_preview_page.dart';
import 'package:fanta_comune/features/home/presentation/home_page.dart';
import 'package:fanta_comune/features/game/presentation/play/play_page.dart';
import 'package:fanta_comune/features/game/presentation/board/board_page.dart';
import 'package:fanta_comune/features/info/presentation/how_it_works_page.dart';
import 'package:fanta_comune/features/info/presentation/privacy_page.dart';
import 'package:fanta_comune/features/leaderboard/presentation/leaderboard_page.dart';
import 'package:fanta_comune/features/onboarding/presentation/cynic_onboarding_page.dart';
import 'package:fanta_comune/features/onboarding/presentation/onboarding_page.dart';
import 'package:fanta_comune/features/onboarding/presentation/warm_welcome_page.dart';
import 'package:fanta_comune/features/next_problems/presentation/next_problems_page.dart';
import 'package:fanta_comune/features/next_problems/presentation/suggest_problem_page.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_receipt_page.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_detail_page.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:fanta_comune/features/profile/presentation/profile_page.dart';
import 'package:fanta_comune/features/shell/presentation/shell_page.dart';
import 'package:fanta_comune/features/map/presentation/tuglie_map_page.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';

/// Costruisce la configurazione di routing dichiarativo usando [GoRouter].
GoRouter buildRouter(AppPrefs appPrefs, [AppConfig? appConfig]) {
  final config = appConfig ?? AppConfig.fromValues();
  return GoRouter(
    initialLocation:
        config.leagueContinuityModeEnabled &&
            appPrefs.localData.read(
                  'league-invite-intent:${config.apiBaseUrl}',
                ) !=
                null
        ? '/league-invite'
        : '/welcome',
    refreshListenable: appPrefs,
    redirect: (context, state) {
      final municipalityId = appPrefs.municipalityId;
      final location = state.matchedLocation.isNotEmpty
          ? state.matchedLocation
          : state.uri.path;

      if (config.pilotMunicipalityId != null &&
          location == '/change-municipality') {
        return '/profile';
      }

      if (municipalityId != null && location == '/onboarding') {
        return config.fantasyModeEnabled
            ? '/squad'
            : _selectionDestination(state, municipalityId: municipalityId);
      }

      if (ProposalRouteContext.isProposalPath(location)) {
        final scope = ProposalRouteContext.resolve(
          state.uri,
          preference: municipalityId,
        );
        if (scope.municipalityId != null) {
          final canonical = state.uri.replace(
            queryParameters: {
              ...state.uri.queryParameters,
              'municipality': scope.municipalityId!,
            },
          );
          if (canonical != state.uri) return canonical.toString();
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/diagnostics',
        builder: (_, __) => const DiagnosticsPage(),
      ),
      GoRoute(
        path: '/cooperation',
        redirect: (_, __) => config.cooperationModeEnabled ? null : '/profile',
        builder: (_, __) => const CooperationPage(),
      ),
      GoRoute(
        path: '/inbox',
        redirect: (_, __) => config.cooperationModeEnabled ? null : '/profile',
        builder: (_, __) => const CooperationPage(inbox: true),
      ),
      GoRoute(
        path: '/followed-places',
        redirect: (_, __) => config.cooperationModeEnabled ? null : '/profile',
        builder: (_, __) => const CooperationPage(followed: true),
      ),
      GoRoute(
        path: "/league-invite",
        redirect: (_, __) =>
            config.leagueContinuityModeEnabled ? null : "/profile",
        builder: (_, __) => const LeagueInvitePage(),
      ),
      GoRoute(
        path: '/measurements',
        redirect: (_, __) => config.measurementsModeEnabled ? null : '/profile',
        builder: (_, __) => const MeasurementPage(),
      ),
      GoRoute(
        path: '/measurements/workspace',
        redirect: (_, __) => config.measurementsModeEnabled ? null : '/profile',
        builder: (_, __) => const MeasurementPage(operator: true),
      ),
      GoRoute(
        path: '/measurements/workspace/evaluations/:evaluationId',
        redirect: (_, __) => config.measurementsModeEnabled ? null : '/profile',
        builder: (_, s) => MeasurementPage(
          operator: true,
          evaluationId: s.pathParameters['evaluationId'],
        ),
      ),
      GoRoute(
        path: '/measurements/evaluations/:evaluationId',
        redirect: (_, __) => config.measurementsModeEnabled ? null : '/profile',
        builder: (_, s) =>
            MeasurementPage(evaluationId: s.pathParameters['evaluationId']),
      ),
      GoRoute(
        path: '/review',
        redirect: (_, __) => config.reviewModeEnabled ? null : '/profile',
        builder: (_, s) => ReviewPage(
          replicationRequestId: s.uri.queryParameters['replicationRequestId'],
        ),
      ),
      GoRoute(
        path: '/review/:observationId',
        redirect: (_, __) => config.reviewModeEnabled ? null : '/profile',
        builder: (_, state) =>
            ReviewPage(observationId: state.pathParameters['observationId']),
      ),
      GoRoute(
        path: '/observations/:observationId',
        redirect: (_, __) => config.reviewModeEnabled ? null : '/profile',
        builder: (_, state) => ReviewPage(
          observationId: state.pathParameters['observationId'],
          author: true,
        ),
      ),
      GoRoute(
        path: '/xp',
        redirect: (_, __) => config.reviewModeEnabled ? null : '/profile',
        builder: (_, __) => const ReviewPage(ledger: true),
      ),
      GoRoute(
        path: '/missions',
        redirect: (_, __) => config.missionsModeEnabled ? null : '/profile',
        builder: (_, __) => const MissionPage(),
      ),
      GoRoute(
        path: '/missions/:missionId',
        redirect: (_, __) => config.missionsModeEnabled ? null : '/profile',
        builder: (_, state) => MissionPage(
          missionId: state.pathParameters['missionId'],
          bookingId: state.uri.queryParameters['bookingId'],
        ),
      ),
      GoRoute(
        path: '/account',
        redirect: (_, __) => config.accountModeEnabled ? null : '/profile',
        builder: (context, state) =>
            AccountPage(returnTo: state.uri.queryParameters['returnTo']),
      ),
      if (config.fantasyModeEnabled)
        GoRoute(path: '/home', redirect: (_, __) => '/squad'),
      GoRoute(path: '/boot', builder: (context, state) => const BootScreen()),
      GoRoute(
        path: '/design-preview',
        builder: (context, state) => const DesignPreviewPage(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => config.fantasyModeEnabled
            ? const FantasyWelcomePage()
            : const WarmWelcomePage(),
      ),
      GoRoute(
        path: '/cynic-onboarding',
        builder: (context, state) => const CynicOnboardingPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) =>
            OnboardingPage(afterSelectionRoute: _selectionDestination(state)),
      ),
      GoRoute(
        path: '/change-municipality',
        builder: (context, state) => OnboardingPage(
          afterSelectionRoute: _selectionDestination(
            state,
            fallback: '/profile',
          ),
        ),
      ),
      GoRoute(
        path: '/next-problems',
        builder: (context, state) => NextProblemsPage(
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ),
        ),
      ),
      GoRoute(
        path: '/suggest-problem',
        builder: (context, state) => SuggestProblemPage(
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ),
        ),
      ),
      GoRoute(
        path: '/proposal-receipt',
        builder: (context, state) => ProposalReceiptPage(
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ),
        ),
      ),
      GoRoute(
        path: '/proposal-receipt/:problemId',
        builder: (context, state) => ProposalReceiptPage(
          problemId: state.pathParameters['problemId'],
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ),
        ),
      ),
      GoRoute(
        path: '/next-problems/:problemId',
        builder: (context, state) => ProposalDetailPage(
          problemId: state.pathParameters['problemId']!,
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ),
        ),
      ),
      GoRoute(path: '/board', builder: (context, state) => const BoardPage()),
      GoRoute(
        path: '/map',
        redirect: (_, __) => config.tuglieMapEnabled ? null : '/home',
        builder: (context, state) {
          final query = state.uri.queryParametersAll['municipality'];
          final id = query == null
              ? MunicipalityCatalog.apiIdFor(appPrefs.municipalityId ?? '')
              : query.length == 1
              ? MunicipalityCatalog.apiIdFor(query.single)
              : null;
          return TuglieMapPage(
            key: ValueKey('${state.uri}:${appPrefs.municipalityId}'),
            municipalityId: id,
          );
        },
      ),
      GoRoute(
        path: '/how-it-works',
        builder: (context, state) => const HowItWorksPage(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPage(),
      ),
      if (config.fantasyModeEnabled)
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              FantasyShellPage(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/squad',
                  builder: (context, state) => const SquadPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/matchday',
                  builder: (context, state) => const MatchdayPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/market',
                  builder: (context, state) => const MarketPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/leagues',
                  builder: (context, state) => const LeaguesPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfilePage(),
                ),
              ],
            ),
          ],
        )
      else
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return config.fantasyModeEnabled
                ? FantasyShellPage(navigationShell: navigationShell)
                : ShellPage(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomePage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/play',
                  builder: (context, state) => const PlayPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/leaderboard',
                  builder: (context, state) => const LeaderboardPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) => const ProfilePage(),
                ),
              ],
            ),
          ],
        ),
    ],
  );
}

String _selectionDestination(
  GoRouterState state, {
  String fallback = '/home',
  String? municipalityId,
}) {
  final route = state.uri.queryParameters['returnTo'];
  final destination =
      const [
        '/suggest-problem',
        '/next-problems',
        '/profile',
        '/home',
      ].contains(route)
      ? route!
      : fallback;
  return municipalityId != null &&
          ProposalRouteContext.isProposalPath(destination)
      ? ProposalRouteContext.location(destination, municipalityId)
      : destination;
}
