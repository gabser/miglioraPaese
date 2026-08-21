import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';

/// Shell responsiva con sidebar desktop e bottom navigation mobile.
class ShellPage extends StatelessWidget {
  const ShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= AppTokens.desktopBreakpoint;
    final currentIndex = navigationShell.currentIndex;
    final destinations = _destinations;
    final municipalityId = context.watch<AppPrefs>().municipalityId ?? 'demo';
    final municipalityName = MunicipalityCatalog.displayNameFromId(
      municipalityId,
    );

    if (isWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _Sidebar(
                currentIndex: currentIndex,
                destinations: destinations,
                municipalityName: municipalityName,
                onSelect: (index) => _onDestinationSelected(context, index),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppTokens.appBackground,
                  ),
                  child: navigationShell,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: destinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
            )
            .toList(),
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
      ),
    );
  }
}

const _destinations = [
  _ShellDestination(
    icon: AppIcons.home,
    selectedIcon: Icons.home,
    label: VenialCopy.navHome,
  ),
  _ShellDestination(
    icon: AppIcons.play,
    selectedIcon: Icons.play_circle,
    label: VenialCopy.navPlay,
  ),
  _ShellDestination(
    icon: AppIcons.leaderboard,
    selectedIcon: Icons.leaderboard,
    label: VenialCopy.navLeaderboard,
  ),
  _ShellDestination(
    icon: AppIcons.profile,
    selectedIcon: Icons.person,
    label: VenialCopy.navProfile,
  ),
];

class _ShellDestination {
  const _ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.currentIndex,
    required this.destinations,
    required this.municipalityName,
    required this.onSelect,
  });

  final int currentIndex;
  final List<_ShellDestination> destinations;
  final String municipalityName;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: AppTokens.sidebarWidth,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTokens.blue, AppTokens.navy],
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
                  ),
                  child: const Center(
                    child: Text(
                      'FC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        VenialCopy.appTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        municipalityName,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s24),
            ...destinations.indexed.map((entry) {
              final index = entry.$1;
              final destination = entry.$2;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTokens.s8),
                child: _SidebarItem(
                  destination: destination,
                  selected: index == currentIndex,
                  onTap: () => onSelect(index),
                ),
              );
            }),
            const SizedBox(height: AppTokens.s16),
            OutlinedButton.icon(
              onPressed: () => context.go('/board'),
              icon: const Icon(AppIcons.board),
              label: const Text(VenialCopy.boardTitle),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(AppTokens.s16),
              decoration: BoxDecoration(
                color: AppTokens.navy,
                borderRadius: BorderRadius.circular(AppTokens.radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modalità demo',
                    style: textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s8),
                  Text(
                    'Dati di gioco mock locali',
                    style: textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s12),
                  Text(
                    'Nessuna segnalazione ufficiale viene inviata.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s12,
            vertical: AppTokens.s12,
          ),
          child: Row(
            children: [
              Icon(
                selected ? destination.selectedIcon : destination.icon,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Text(
                  destination.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
