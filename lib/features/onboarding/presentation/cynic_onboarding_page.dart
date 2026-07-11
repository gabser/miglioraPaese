import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/ticket_progress.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';

class CynicOnboardingPage extends StatefulWidget {
  const CynicOnboardingPage({super.key});

  @override
  State<CynicOnboardingPage> createState() => _CynicOnboardingPageState();
}

class _CynicOnboardingPageState extends State<CynicOnboardingPage> {
  int _stepIndex = 0;

  List<_OnboardingStep> get _steps => const [
    _OnboardingStep(
      title: VenialCopy.onboardingStep1Title,
      subtitle: VenialCopy.onboardingStep1Subtitle,
      bullet: VenialCopy.onboardingStep1Bullet,
      cta: VenialCopy.onboardingStep1Cta,
    ),
    _OnboardingStep(
      title: VenialCopy.onboardingStep2Title,
      subtitle: VenialCopy.onboardingStep2Subtitle,
      bullet: VenialCopy.onboardingStep2Bullet,
      cta: VenialCopy.onboardingStep2Cta,
    ),
    _OnboardingStep(
      title: VenialCopy.onboardingStep3Title,
      subtitle: VenialCopy.onboardingStep3Subtitle,
      bullet: VenialCopy.onboardingStep3Bullet,
      cta: VenialCopy.onboardingStep3Cta,
    ),
    _OnboardingStep(
      title: VenialCopy.onboardingStep4Title,
      subtitle: VenialCopy.onboardingStep4Subtitle,
      bullet: VenialCopy.onboardingStep4Bullet,
      cta: VenialCopy.onboardingStep4Cta,
    ),
  ];

  Future<void> _completeOnboarding(BuildContext context) async {
    final prefs = context.read<AppPrefs>();
    await prefs.setHasSeenCynicOnboarding(true);
    if (!context.mounted) return;
    context.go('/home');
  }

  void _nextStep() {
    if (_stepIndex >= _steps.length - 1) {
      _completeOnboarding(context);
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
    final step = _steps[_stepIndex];
    final progressLabel = '${_stepIndex + 1}/${_steps.length}';

    return Scaffold(
      appBar: AppBar(
        title: const Text(VenialCopy.appTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTokens.s12),
            child: TextButton(
              onPressed: () => _completeOnboarding(context),
              child: const Text(VenialCopy.onboardingSkip),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: FcPanel(
              tint: AppTokens.blue,
              elevated: true,
              padding: EdgeInsets.all(padding),
              child: AnimatedSwitcherX(
                duration: AppMotion.normal,
                switchInCurve: const Interval(
                  0.2,
                  1,
                  curve: AppMotion.standard,
                ),
                child: Column(
                  key: ValueKey('cynic-step-${_stepIndex + 1}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TicketProgress(
                        label: VenialCopy.onboardingProgressLabel.replaceAll(
                          '{step}',
                          progressLabel,
                        ),
                        currentStep: _stepIndex + 1,
                        totalSteps: _steps.length,
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppTokens.radiusSmall,
                        ),
                      ),
                      child: Icon(AppIcons.play, color: colorScheme.primary),
                    ),
                    SizedBox(height: sectionGap),
                    Semantics(
                      header: true,
                      child: Text(
                        step.title,
                        style: TypographyX.titleMedium(
                          context,
                        )?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s8),
                    Text(
                      step.subtitle,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: isCompact ? AppTokens.s12 : AppTokens.s16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 20),
                        const SizedBox(width: AppTokens.s8),
                        Expanded(
                          child: Text(step.bullet, style: textTheme.bodyMedium),
                        ),
                      ],
                    ),
                    SizedBox(height: isCompact ? AppTokens.s16 : AppTokens.s24),
                    Semantics(
                      button: true,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _nextStep,
                          child: Text(step.cta),
                        ),
                      ),
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

class _OnboardingStep {
  const _OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.bullet,
    required this.cta,
  });

  final String title;
  final String subtitle;
  final String bullet;
  final String cta;
}
