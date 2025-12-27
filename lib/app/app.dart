import 'package:flutter/material.dart';
import 'package:fanta_comune/core/theme/app_theme.dart';
import 'package:fanta_comune/features/boot/boot_screen.dart';

/// Entry point dell'applicazione Fanta Comune con tema e home screen.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fanta Comune',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const BootScreen(),
    );
  }
}
