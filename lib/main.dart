import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/app/app.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appPrefs = await AppPrefs.init();

  runApp(
    RepositoryProvider<AppPrefs>.value(
      value: appPrefs,
      child: const App(),
    ),
  );
}
