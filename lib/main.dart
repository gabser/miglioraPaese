import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:fanta_comune/app/app.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';
import 'package:fanta_comune/features/next_problems/data/next_problems_repository.dart';
import 'package:fanta_comune/features/next_problems/data/mock_next_problems_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appPrefs = await AppPrefs.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppPrefs>.value(value: appPrefs),
        Provider<GameRepository>(create: (_) => MockGameRepository()),
        Provider<NextProblemsRepository>(
          create: (context) => MockNextProblemsRepository(
            currentUserId: context.read<AppPrefs>().userId,
          ),
        ),
      ],
      child: const App(),
    ),
  );
}
