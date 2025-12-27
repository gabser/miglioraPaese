import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';

/// Shell responsiva che gestisce NavigationRail su desktop e BottomNavigationBar su mobile.
class ShellPage extends StatelessWidget {
  const ShellPage({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  final Widget child;
  final int currentIndex;

  void _onDestinationSelected(BuildContext context, int index) {
    switch (index) {
      case 0:
        if (currentIndex != 0) context.go('/home');
        break;
      case 1:
        if (currentIndex != 1) context.go('/play');
        break;
      case 2:
        if (currentIndex != 2) context.go('/leaderboard');
        break;
      case 3:
        if (currentIndex != 3) context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isWide = mediaQuery.size.width >= 900;
    final destinations = const [
      NavigationDestination(
        icon: Icon(AppIcons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(AppIcons.play),
        label: 'Gioca',
      ),
      NavigationDestination(
        icon: Icon(AppIcons.leaderboard),
        label: 'Classifica',
      ),
      NavigationDestination(
        icon: Icon(AppIcons.profile),
        label: 'Profilo',
      ),
    ];

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentIndex,
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map(
                    (destination) => NavigationRailDestination(
                      icon: destination.icon,
                      label: Text(destination.label),
                    ),
                  )
                  .toList(),
              onDestinationSelected: (index) => _onDestinationSelected(context, index),
            ),
            const SizedBox(width: AppTokens.s16),
            Expanded(
              child: MaxWidthContainer(
                child: SingleChildScrollView(
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: destinations,
        onDestinationSelected: (index) => _onDestinationSelected(context, index),
      ),
    );
  }
}
