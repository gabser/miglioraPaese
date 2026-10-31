import 'package:fanta_comune/features/next_problems/presentation/proposal_receipt_page.dart';
import 'package:fanta_comune/features/next_problems/presentation/proposal_detail_page.dart';
import 'package:fanta_comune/features/next_problems/domain/proposal_route_context.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/features/map/presentation/tuglie_map_page.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/boot/boot_screen.dart';
import 'package:fanta_comune/features/home/presentation/home_page.dart';
import 'package:fanta_comune/features/game/presentation/play/play_page.dart';
import 'package:fanta_comune/features/game/presentation/board/board_page.dart';
import 'package:fanta_comune/features/fantasy/presentation/pages/fantasy_pages.dart';
import 'package:fanta_comune/features/info/presentation/how_it_works_page.dart';
import 'package:fanta_comune/features/info/presentation/privacy_page.dart';
import 'package:fanta_comune/features/leaderboard/presentation/leaderboard_page.dart';
import 'package:fanta_comune/features/onboarding/presentation/cynic_onboarding_page.dart';
import 'package:fanta_comune/features/onboarding/presentation/onboarding_page.dart';
import 'package:fanta_comune/features/onboarding/presentation/warm_welcome_page.dart';
import 'package:fanta_comune/features/next_problems/presentation/next_problems_page.dart';
import 'package:fanta_comune/features/next_problems/presentation/suggest_problem_page.dart';
import 'package:fanta_comune/features/profile/presentation/profile_page.dart';
import 'package:fanta_comune/features/shell/presentation/shell_page.dart';

/// Costruisce la configurazione di routing dichiarativo usando [GoRouter].
GoRouter buildRouter(AppPrefs appPrefs, AppConfig config) {
  if (config.fantasyModeEnabled) {
    return _buildFantasyRouter(appPrefs, config);
  }
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: appPrefs,
    redirect: (context, state) {
      final municipalityId = appPrefs.municipalityId;
      final location = state.matchedLocation.isNotEmpty
          ? state.matchedLocation
          : state.uri.path;

      if (municipalityId != null && location == '/onboarding') {
        return _selectionDestination(state, municipalityId: municipalityId);
      }
      if (config.pilotMunicipalityId != null &&
          location == '/change-municipality') {
        return '/profile';
      }

      if (ProposalRouteContext.isProposalPath(location)) {
        final scope = ProposalRouteContext.resolve(
          state.uri,
          preference: municipalityId,
        );
        if (!scope.invalid && scope.municipalityId != null) {
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
      GoRoute(path: '/boot', builder: (context, state) => const BootScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WarmWelcomePage(),
      ),
      GoRoute(
        path: '/cynic-onboarding',
        builder: (context, state) => const CynicOnboardingPage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingPage(
          afterSelectionRoute: _selectionDestination(
            state,
            fallback: config.fantasyModeEnabled ? '/squad' : '/home',
          ),
        ),
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
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),
      GoRoute(
        path: '/suggest-problem',
        builder: (context, state) => SuggestProblemPage(
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),
      GoRoute(
        path: '/proposal-receipt',
        builder: (context, state) => ProposalReceiptPage(
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),
      GoRoute(
        path: '/proposal-receipt/:problemId',
        builder: (context, state) => ProposalReceiptPage(
          problemId: state.pathParameters['problemId'],
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),
      GoRoute(
        path: '/next-problems/:problemId',
        builder: (context, state) => ProposalDetailPage(
          problemId: state.pathParameters['problemId']!,
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ).restrictToPilot(config.pilotMunicipalityId),
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellPage(navigationShell: navigationShell);
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

GoRouter _buildFantasyRouter(AppPrefs appPrefs, AppConfig config) {
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: appPrefs,
    redirect: (context, state) {
      final municipalityId = appPrefs.municipalityId;
      final location = state.matchedLocation.isNotEmpty
          ? state.matchedLocation
          : state.uri.path;
      if (municipalityId != null && location == '/onboarding') {
        return _selectionDestination(
          state,
          municipalityId: municipalityId,
          fallback: '/squad',
        );
      }
      if (config.pilotMunicipalityId != null &&
          location == '/change-municipality') {
        return '/profile';
      }
      if (ProposalRouteContext.isProposalPath(location)) {
        final scope = ProposalRouteContext.resolve(
          state.uri,
          preference: municipalityId,
        );
        if (!scope.invalid && scope.municipalityId != null) {
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
      GoRoute(path: '/home', redirect: (context, state) => '/squad'),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const FantasyWelcomePage(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingPage(
          afterSelectionRoute: _selectionDestination(
            state,
            fallback: config.fantasyModeEnabled ? '/squad' : '/home',
          ),
        ),
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
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),
      GoRoute(
        path: '/suggest-problem',
        builder: (context, state) => SuggestProblemPage(
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),
      GoRoute(
        path: '/proposal-receipt',
        builder: (context, state) => ProposalReceiptPage(
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),
      GoRoute(
        path: '/proposal-receipt/:problemId',
        builder: (context, state) => ProposalReceiptPage(
          problemId: state.pathParameters['problemId'],
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),
      GoRoute(
        path: '/next-problems/:problemId',
        builder: (context, state) => ProposalDetailPage(
          problemId: state.pathParameters['problemId']!,
          routeContext: ProposalRouteContext.resolve(
            state.uri,
            preference: appPrefs.municipalityId,
          ).restrictToPilot(config.pilotMunicipalityId),
        ),
      ),

      GoRoute(
        path: '/map',
        redirect: (_, __) => config.tuglieMapEnabled ? null : '/squad',
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
        '/squad',
      ].contains(route)
      ? route!
      : fallback;
  return municipalityId != null &&
          ProposalRouteContext.isProposalPath(destination)
      ? ProposalRouteContext.location(destination, municipalityId)
      : destination;
}
