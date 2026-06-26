import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/card_illustration_slot.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';
import 'package:fanta_comune/core/widgets/ticket_progress.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/widgets/stamp_badge.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';

class WarmWelcomePage extends StatefulWidget {
  const WarmWelcomePage({super.key});

  @override
  State<WarmWelcomePage> createState() => _WarmWelcomePageState();
}

class _WarmWelcomePageState extends State<WarmWelcomePage> {
  int _stepIndex = 0;

  List<_WarmStep> get _steps => const [
        _WarmStep(
          title: VenialCopy.welcomeStep1Title,
          subtitle: VenialCopy.welcomeStep1Subtitle,
          cta: VenialCopy.welcomeStep1Cta,
        ),
        _WarmStep(
          title: VenialCopy.welcomeStep2Title,
          subtitle: VenialCopy.welcomeStep2Subtitle,
          cta: VenialCopy.welcomeStep2Cta,
        ),
        _WarmStep(
          title: VenialCopy.welcomeStep3Title,
          subtitle: VenialCopy.welcomeStep3Subtitle,
        ),
      ];

  Future<void> _completeAndGo(String target) async {
    final prefs = context.read<AppPrefs>();
    await prefs.setHasSeenWarmWelcome(true);
    if (!mounted) return;
    context.go(target);
  }

  Future<void> _skipWelcome() async {
    final prefs = context.read<AppPrefs>();
    await prefs.setHasSeenWarmWelcome(true);
    if (!mounted) return;
    final next = prefs.municipalityId == null ? '/onboarding' : '/play';
    context.go(next);
  }

  void _nextStep() {
    if (_stepIndex >= _steps.length - 1) {
      final prefs = context.read<AppPrefs>();
      final next = prefs.municipalityId == null ? '/onboarding' : '/play';
      _completeAndGo(next);
      return;
    }
    setState(() {
      _stepIndex += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final padding = isCompact ? AppTokens.s12 : AppTokens.s16;
    final sectionGap = isCompact ? AppTokens.s12 : AppTokens.s16;
    final prefs = context.read<AppPrefs>();
    final step = _steps[_stepIndex];
    final progressLabel = '${_stepIndex + 1}/${_steps.length}';
    final hasMunicipality = prefs.municipalityId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(VenialCopy.appTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTokens.s12),
            child: InkWell(
              onTap: _skipWelcome,
              borderRadius: BorderRadius.circular(AppTokens.radius),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTokens.s8),
                  child: StampBadge(
                    label: VenialCopy.welcomeSkip,
                    angle: -0.04,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: PrimaryCard(
              textured: true,
              elevated: true,
              padding: EdgeInsets.all(padding),
              child: AnimatedSwitcherX(
                duration: AppMotion.normal,
                switchInCurve:
                    const Interval(0.2, 1, curve: AppMotion.standard),
                child: Column(
                  key: ValueKey('warm-step-${_stepIndex + 1}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TicketProgress(
                        label: VenialCopy.welcomeProgressLabel
                            .replaceAll('{step}', progressLabel),
                        currentStep: _stepIndex + 1,
                        totalSteps: _steps.length,
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    CardIllustrationSlot(
                      fallbackIcon: AppIcons.play,
                      height: 72,
                      compact: true,
                    ),
                    SizedBox(height: sectionGap),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s12,
                        vertical: AppTokens.s8 / 2,
                      ),
                      decoration: VintagePaper.tapeDecoration(colorScheme),
                      child: Semantics(
                        header: true,
                        child: Text(
                          step.title,
                          style: TypographyX.titleMedium(context)?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    Text(
                      step.subtitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: isCompact ? AppTokens.s16 : AppTokens.s24),
                    if (_stepIndex < _steps.length - 1)
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _nextStep,
                          child: Text(step.cta ?? ''),
                        ),
                      )
                    else
                      Wrap(
                        spacing: AppTokens.s12,
                        runSpacing: AppTokens.s12,
                        children: [
                          if (hasMunicipality)
                            FilledButton(
                              onPressed: () => _completeAndGo('/play'),
                              child: const Text(VenialCopy.welcomeStep3Play),
                            )
                          else
                            FilledButton(
                              onPressed: () => _completeAndGo('/onboarding'),
                              child: const Text(
                                  VenialCopy.welcomeStep3Municipality),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarmStep {
  const _WarmStep({
    required this.title,
    required this.subtitle,
    this.cta,
  });

  final String title;
  final String subtitle;
  final String? cta;
}
