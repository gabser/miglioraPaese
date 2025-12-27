import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/app/app.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/game/data/game_repository.dart';
import 'package:fanta_comune/features/game/data/mock_game_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appPrefs = await AppPrefs.init();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppPrefs>.value(
          value: appPrefs,
        ),
        RepositoryProvider<GameRepository>(
          create: (_) => MockGameRepository(),
        ),
      ],
      child: const App(),
    ),
  );
}
