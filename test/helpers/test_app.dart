import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fanta_comune/app/app.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/civic_loop/data/civic_loop_store.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';

Future<AppPrefs> createTestPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return AppPrefs.init();
}

Widget buildTestApp(
  AppPrefs prefs, {
  AppConfig? config,
  FantasyManager? fantasyManager,
}) {
  return MultiProvider(
    providers: [
      Provider<AppConfig>.value(value: config ?? AppConfig.fromValues()),
      ChangeNotifierProvider<AppPrefs>.value(value: prefs),
      if (fantasyManager != null)
        ChangeNotifierProvider<FantasyManager>.value(value: fantasyManager)
      else
        ChangeNotifierProvider<FantasyManager>(
          create: (_) => FantasyManager(prefs, observeTime: false),
        ),
      Provider<CivicLoopStore>(
        create: (context) =>
            CivicLoopStore(currentUserId: context.read<AppPrefs>().userId),
      ),
      Provider<GameRepository>(
        create: (context) =>
            MockGameRepository(civicLoopStore: context.read<CivicLoopStore>()),
      ),
      Provider<NextProblemsRepository>(
        create: (context) => MockNextProblemsRepository(
          currentUserId: context.read<AppPrefs>().userId,
          store: context.read<CivicLoopStore>(),
        ),
      ),
    ],
    child: const App(),
  );
}

Future<void> pumpRoutingFrame(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
