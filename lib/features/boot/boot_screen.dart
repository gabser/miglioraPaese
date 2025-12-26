import 'package:flutter/material.dart';
import 'package:goodtime/core/theme/app_icons.dart';
import 'package:goodtime/core/theme/app_tokens.dart';
import 'package:goodtime/core/widgets/icon_label.dart';
import 'package:goodtime/core/widgets/max_width_container.dart';
import 'package:goodtime/features/game/domain/problem_type.dart';

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
              const SizedBox(height: AppTokens.s16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppTokens.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Icon set',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      Text(
                        'Icone centralizzate per navigazione e problemi.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppTokens.s16),
                      Text(
                        'Tab principali',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppTokens.s8),
                      Wrap(
                        spacing: AppTokens.s16,
                        runSpacing: AppTokens.s12,
                        children: const [
                          IconLabel(
                            icon: AppIcons.home,
                            text: 'Home',
                          ),
                          IconLabel(
                            icon: AppIcons.play,
                            text: 'Gioca',
                          ),
                          IconLabel(
                            icon: AppIcons.leaderboard,
                            text: 'Classifica',
                          ),
                          IconLabel(
                            icon: AppIcons.profile,
                            text: 'Profilo',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.s16),
                      Text(
                        'Tipologie di problema',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppTokens.s8),
                      Wrap(
                        spacing: AppTokens.s16,
                        runSpacing: AppTokens.s12,
                        children: ProblemType.values
                            .map(
                              (type) => IconLabel(
                                icon: AppIcons.forProblemType(type),
                                text: AppIcons.labelForProblemType(type),
                              ),
                            )
                            .toList(),
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
