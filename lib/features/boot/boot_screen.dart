import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/models/problem_status.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_size_x.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/core/widgets/segmented_choice.dart';
import 'package:fanta_comune/core/widgets/status_pill.dart';
import 'package:fanta_comune/core/privacy/privacy_copy.dart';
import 'package:go_router/go_router.dart';

/// Schermata iniziale che conferma l'avvio e presenta il tema base.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  bool _showMotionDetails = false;
  ProblemStatus _selectedStatus = ProblemStatus.improving;

  @override
  void initState() {
    super.initState();
    final prefs = context.read<AppPrefs>();
    _showMotionDetails = prefs.motionDemoEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final appPrefs = context.read<AppPrefs>();
    final nextLocation = appPrefs.municipalityId == null ? '/onboarding' : '/home';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fanta Comune'),
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryCard(
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
                          'Crea partite civiche, segnala problemi e scala la classifica locale.',
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTokens.s16),
                        Text(
                          'Bootstrap completato. Prossimo step: feature di gioco e routing.',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),
                  PrimaryCard(
                    child: Wrap(
                      spacing: AppTokens.s12,
                      runSpacing: AppTokens.s12,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(AppIcons.play),
                          label: const Text('Vai all’app'),
                          onPressed: () => context.go(nextLocation),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(AppIcons.privacy),
                          label: const Text('Reset dati locali'),
                          onPressed: () async {
                            await appPrefs.clearAll();
                            if (!mounted) return;
                            context.go('/boot');
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),
                  PrimaryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Info & privacy',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTokens.s8),
                        Text(
                          PrivacyCopy.micropitch,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppTokens.s12),
                        Wrap(
                          spacing: AppTokens.s12,
                          runSpacing: AppTokens.s12,
                          children: [
                            FilledButton.icon(
                              icon: const Icon(AppIcons.info),
                              label: const Text('Come funziona'),
                              onPressed: () => context.go('/how-it-works'),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(AppIcons.privacy),
                              label: const Text('Privacy'),
                              onPressed: () => context.go('/privacy'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),
                  PrimaryCard(
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
                  const SizedBox(height: AppTokens.s16),
                  PrimaryCard(
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
                            'Transizioni coordinate con AnimatedSwitcherX e token di motion.',
                            style: textTheme.bodyMedium,
                          ),
                          onChanged: (value) async {
                            setState(() {
                              _showMotionDetails = value;
                            });
                            await appPrefs.setMotionDemoEnabled(value);
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
                  const SizedBox(height: AppTokens.s16),
                  PrimaryCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Components demo',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppTokens.s12),
                        Wrap(
                          spacing: AppTokens.s12,
                          runSpacing: AppTokens.s12,
                          children: const [
                            StatusPill(status: ProblemStatus.improving),
                            StatusPill(status: ProblemStatus.stable),
                            StatusPill(status: ProblemStatus.worsening),
                          ],
                        ),
                        const SizedBox(height: AppTokens.s12),
                        SegmentedChoice<ProblemStatus>(
                          value: _selectedStatus,
                          options: const [
                            ProblemStatus.improving,
                            ProblemStatus.stable,
                            ProblemStatus.worsening,
                          ],
                          labelBuilder: (status) => switch (status) {
                            ProblemStatus.improving => 'Migliora',
                            ProblemStatus.stable => 'Stabile',
                            ProblemStatus.worsening => 'Peggiora',
                          },
                          onChanged: (status) {
                            setState(() => _selectedStatus = status);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
