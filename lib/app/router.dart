import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/boot/boot_screen.dart';
import 'package:fanta_comune/features/home/presentation/home_page.dart';
import 'package:fanta_comune/features/game/presentation/play/play_page.dart';
import 'package:fanta_comune/features/info/presentation/how_it_works_page.dart';
import 'package:fanta_comune/features/info/presentation/privacy_page.dart';
import 'package:fanta_comune/features/leaderboard/presentation/leaderboard_page.dart';
import 'package:fanta_comune/features/onboarding/presentation/onboarding_page.dart';
import 'package:fanta_comune/features/profile/presentation/profile_page.dart';
import 'package:fanta_comune/features/shell/presentation/shell_page.dart';

/// Costruisce la configurazione di routing dichiarativo usando [GoRouter].
GoRouter buildRouter(AppPrefs appPrefs) {
  return GoRouter(
    initialLocation: '/boot',
    refreshListenable: appPrefs,
    redirect: (context, state) {
      final municipalityId = appPrefs.municipalityId;
      final location = state.uri.path;
      const publicPaths = {
        '/boot',
        '/onboarding',
        '/how-it-works',
        '/privacy',
      };

      if (municipalityId == null) {
        if (publicPaths.contains(location)) {
          return null;
        }
        return '/onboarding';
      }

      if (location == '/onboarding') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/boot',
        builder: (context, state) => const BootScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/how-it-works',
        builder: (context, state) => const HowItWorksPage(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final currentPath = state.uri.path;
          final currentIndex = switch (currentPath) {
            '/home' => 0,
            '/play' => 1,
            '/leaderboard' => 2,
            '/profile' => 3,
            _ => 0,
          };
          return ShellPage(
            child: child,
            currentIndex: currentIndex,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/play',
            builder: (context, state) => const PlayPage(),
          ),
          GoRoute(
            path: '/leaderboard',
            builder: (context, state) => const LeaderboardPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
}
