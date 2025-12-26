import 'package:flutter/material.dart';
import 'package:goodtime/core/theme/app_tokens.dart';
import 'package:goodtime/core/widgets/max_width_container.dart';

/// Schermata iniziale che conferma l'avvio e presenta il tema base.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fanta Comune'),
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fanta Comune',
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s12),
                      Text(
                        'Il Fantacalcio dei problemi del tuo Comune.',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppTokens.s16),
                      Text(
                        'Bootstrap completato. Prossimo step: UI e routing.',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
