import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';

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
    final destinations = [
      NavigationDestination(
        icon: _NavTokenIcon(icon: AppIcons.home, selected: false),
        selectedIcon: _NavTokenIcon(icon: AppIcons.home, selected: true),
        label: VenialCopy.navHome,
      ),
      NavigationDestination(
        icon: _NavTokenIcon(icon: AppIcons.play, selected: false),
        selectedIcon: _NavTokenIcon(icon: AppIcons.play, selected: true),
        label: VenialCopy.navPlay,
      ),
      NavigationDestination(
        icon: _NavTokenIcon(icon: AppIcons.leaderboard, selected: false),
        selectedIcon: _NavTokenIcon(icon: AppIcons.leaderboard, selected: true),
        label: VenialCopy.navLeaderboard,
      ),
      NavigationDestination(
        icon: _NavTokenIcon(icon: AppIcons.profile, selected: false),
        selectedIcon: _NavTokenIcon(icon: AppIcons.profile, selected: true),
        label: VenialCopy.navProfile,
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
                      selectedIcon: destination.selectedIcon,
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

class _NavTokenIcon extends StatelessWidget {
  const _NavTokenIcon({
    required this.icon,
    required this.selected,
  });

  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? VintagePaper.paperWarm(scheme) : Colors.transparent;
    final border = selected ? VintagePaper.inkStamp(scheme) : Colors.transparent;
    final iconColor = selected ? VintagePaper.inkStamp(scheme) : scheme.onSurfaceVariant;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Icon(icon, size: 20, color: iconColor),
    );
  }
}
