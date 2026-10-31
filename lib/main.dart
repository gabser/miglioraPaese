import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/fantasy/continuity/invite_link.dart';
import 'package:flutter/material.dart';

import 'package:fanta_comune/app/app.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';

Future<void> main() async {
  final inviteToken = captureLeagueInvite();
  WidgetsFlutterBinding.ensureInitialized();
  final appPrefs = await AppPrefs.init();
  final config = AppConfig.fromEnvironment();

  if (inviteToken != null && config.leagueContinuityModeEnabled) {
    await appPrefs.localData.mutate<void>(
      "league-invite-intent:${config.apiBaseUrl}",
      (_) => LocalDataMutation({"token": inviteToken}, null),
    );
  }
  runApp(
    AppDependencies(appPrefs: appPrefs, config: config, child: const App()),
  );
}
