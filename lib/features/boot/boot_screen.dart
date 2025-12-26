import 'package:flutter/material.dart';
import 'package:goodtime/core/models/problem_key.dart';
import 'package:goodtime/core/theme/app_icons.dart';
import 'package:goodtime/core/theme/app_tokens.dart';
import 'package:goodtime/core/widgets/animated_size_x.dart';
import 'package:goodtime/core/widgets/animated_switcher_x.dart';
import 'package:goodtime/core/widgets/icon_label.dart';
import 'package:goodtime/core/widgets/max_width_container.dart';

/// Schermata iniziale che conferma l'avvio e presenta il tema base.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _showMotionDetails = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GoodTime'),
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
                        'GoodTime',
                        style: textTheme.headlineMedium?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s12),
                      Text(
                        'Pianifica attività e routine con un taccuino digitale.',
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
                        children: ProblemKey.values
                            .map(
                              (problem) => IconLabel(
                                icon: AppIcons.forProblemKey(problem),
                                text: AppIcons.labelForProblemKey(problem),
                              ),
                            )
                            .toList(),
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
                        'Motion demo',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _showMotionDetails,
                        activeColor: colorScheme.primary,
                        title: Text(
                          'Mostra dettagli motion demo',
                          style: textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          'Transizioni leggere e coerenti con i token di motion.',
                          style: textTheme.bodyMedium,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _showMotionDetails = value;
                          });
                        },
                      ),
                      AnimatedSwitcherX(
                        child: _showMotionDetails
                            ? AnimatedSizeX(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: AppTokens.s12),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(AppTokens.s12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(AppTokens.radius),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Micro-animazioni coordinate',
                                          style: textTheme.titleMedium?.copyWith(
                                            color: colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                        const SizedBox(height: AppTokens.s8),
                                        Text(
                                          'Ingressi morbidi con fade + slide per comunicare cambi di stato senza distrazioni. '
                                          'Le durate e le curve derivano da AppMotion per un feeling premium su Web.',
                                          style: textTheme.bodyMedium?.copyWith(
                                            color: colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
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
