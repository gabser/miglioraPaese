import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanta_comune/app/app.dart';
import 'package:fanta_comune/app/app_dependencies.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';

Future<AppPrefs> createTestPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return AppPrefs.init();
}

Widget buildTestApp(
  AppPrefs prefs, {
  AppConfig? config,
  FantasyManager? fantasyManager,
}) {
  return AppDependencies(
    appPrefs: prefs,
    config: config ?? AppConfig.fromValues(),
    fantasyManager: fantasyManager,
    child: const App(),
  );
}

Future<void> pumpRoutingFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
