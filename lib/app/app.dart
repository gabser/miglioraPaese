import 'package:flutter/material.dart';
import 'package:goodtime/core/theme/app_theme.dart';
import 'package:goodtime/features/boot/boot_screen.dart';

/// Entry point dell'applicazione che configura tema e navigazione.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fanta Comune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _routerConfig,
    );
  }
}

final RouterConfig<Object> _routerConfig = RouterConfig<Object>(
  routeInformationParser: _AppRouteInformationParser(),
  routerDelegate: _AppRouterDelegate(),
);

class _AppRoutePath {
  const _AppRoutePath.home();
}

class _AppRouteInformationParser
    extends RouteInformationParser<_AppRoutePath> {
  const _AppRouteInformationParser();

  @override
  Future<_AppRoutePath> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    return const _AppRoutePath.home();
  }

  @override
  RouteInformation restoreRouteInformation(_AppRoutePath configuration) {
    return const RouteInformation(location: '/');
  }
}

class _AppRouterDelegate extends RouterDelegate<_AppRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<_AppRoutePath> {
  _AppRouterDelegate();

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  _AppRoutePath? get currentConfiguration => const _AppRoutePath.home();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: const [
        MaterialPage(child: BootScreen()),
      ],
      onPopPage: (route, result) => route.didPop(result),
    );
  }

  @override
  Future<void> setNewRoutePath(_AppRoutePath configuration) async {
    return;
  }
}
