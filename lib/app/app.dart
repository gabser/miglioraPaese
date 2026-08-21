import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/app/router.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';

/// Entry point dell'applicazione Fanta Comune con tema e router dichiarativo.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final appPrefs = context.read<AppPrefs>();
    final config = context.read<AppConfig>();
    return MaterialApp.router(
      title: 'Fanta Comune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: buildRouter(appPrefs, config),
    );
  }
}
