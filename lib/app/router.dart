import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/boot/boot_screen.dart';
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
import 'package:fanta_comune/features/profile/presentation/profile_page.dart';
import 'package:fanta_comune/features/shell/presentation/shell_page.dart';

/// Costruisce la configurazione di routing dichiarativo usando [GoRouter].
GoRouter buildRouter(AppPrefs appPrefs, AppConfig config) {
  return GoRouter(
    initialLocation: '/welcome',
    refreshListenable: appPrefs,
    redirect: (context, state) {
      final municipalityId = appPrefs.municipalityId;
      final location = state.matchedLocation.isNotEmpty
          ? state.matchedLocation
          : state.uri.path;

      if (municipalityId != null && location == '/onboarding') {
        return '/home';
      }
      if (config.pilotMunicipalityId != null &&
          location == '/change-municipality') {
        return '/profile';
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
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/change-municipality',
        builder: (context, state) =>
            const OnboardingPage(afterSelectionRoute: '/profile'),
      ),
      GoRoute(
        path: '/next-problems',
        builder: (context, state) => const NextProblemsPage(),
      ),
      GoRoute(
        path: '/suggest-problem',
        builder: (context, state) => const SuggestProblemPage(),
      ),
      GoRoute(path: '/board', builder: (context, state) => const BoardPage()),
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
