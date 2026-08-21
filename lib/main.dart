import 'package:flutter/material.dart';

import 'package:fanta_comune/app/app.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appPrefs = await AppPrefs.init();
  final config = AppConfig.fromEnvironment();
  final pilotMunicipalityId = config.pilotMunicipalityId;
  if (pilotMunicipalityId != null &&
      appPrefs.municipalityId != pilotMunicipalityId) {
    await appPrefs.setMunicipalityId(pilotMunicipalityId);
  }

  runApp(
    AppDependencies(appPrefs: appPrefs, config: config, child: const App()),
  );
}
