import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_assets.dart';
import 'package:fanta_comune/core/theme/app_motion.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/ticket_progress.dart';

class WarmWelcomePage extends StatefulWidget {
  const WarmWelcomePage({super.key});

  @override
  State<WarmWelcomePage> createState() => _WarmWelcomePageState();
}

class _WarmWelcomePageState extends State<WarmWelcomePage> {
  int? _stepIndex;

  List<_WarmStep> get _steps => const [
    _WarmStep(
      title: VenialCopy.welcomeStep1Title,
      subtitle: VenialCopy.welcomeStep1Subtitle,
      asset: AppAssets.tutorialComune,
      cta: VenialCopy.welcomeStep1Cta,
    ),
    _WarmStep(
      title: VenialCopy.welcomeStep2Title,
      subtitle: VenialCopy.welcomeStep2Subtitle,
      asset: AppAssets.tutorialPrevedi,
      cta: VenialCopy.welcomeStep2Cta,
    ),
    _WarmStep(
      title: VenialCopy.welcomeStep3Title,
      subtitle: VenialCopy.welcomeStep3Subtitle,
      asset: AppAssets.tutorialReputazione,
    ),
  ];

  Future<void> _completeAndGo(String target) async {
    final prefs = context.read<AppPrefs>();
    await prefs.setHasSeenWarmWelcome(true);
    if (!mounted) return;
    context.go(target);
  }

  Future<void> _skipWelcome() async {
    await _completeAndGo('/home');
  }

  void _nextStep() {
    final current = _stepIndex ?? 0;
    if (current >= _steps.length - 1) {
      _completeAndGo('/home');
      return;
    }
    setState(() {
      _stepIndex = current + 1;
    });
  }

  void _startTutorial() {
    setState(() {
      _stepIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final padding = isCompact ? AppTokens.s12 : AppTokens.s16;
    final sectionGap = isCompact ? AppTokens.s12 : AppTokens.s16;
    final stepIndex = _stepIndex;
    final step = stepIndex == null ? null : _steps[stepIndex];
    final progressLabel = stepIndex == null
        ? ''
        : '${stepIndex + 1}/${_steps.length}';

    return Scaffold(
      appBar: AppBar(title: const Text(VenialCopy.appTitle)),
      body: SafeArea(
        child: MaxWidthContainer(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: SingleChildScrollView(
              child: FcPanel(
                elevated: true,
                padding: EdgeInsets.all(padding),
                child: AnimatedSwitcherX(
                  duration: AppMotion.normal,
                  switchInCurve: const Interval(
                    0.2,
                    1,
                    curve: AppMotion.standard,
                  ),
                  child: step == null
                      ? _WelcomeLanding(
                          onEnter: _skipWelcome,
                          onTutorial: _startTutorial,
                          onProfile: () => _completeAndGo('/profile'),
                        )
                      : _TutorialStepView(
                          key: ValueKey('warm-step-${stepIndex! + 1}'),
                          step: step,
                          stepIndex: stepIndex,
                          totalSteps: _steps.length,
                          progressLabel: progressLabel,
                          textTheme: textTheme,
                          colorScheme: colorScheme,
                          sectionGap: sectionGap,
                          isCompact: isCompact,
                          onNext: _nextStep,
                          onSkip: _skipWelcome,
                          onChooseMunicipality: () =>
                              _completeAndGo('/onboarding'),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeLanding extends StatelessWidget {
  const _WelcomeLanding({
    required this.onEnter,
    required this.onTutorial,
    required this.onProfile,
  });

  final VoidCallback onEnter;
  final VoidCallback onTutorial;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('welcome-landing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radiusSmall),
              child: Image.asset(AppAssets.appIcon, width: 54, height: 54),
            ),
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    VenialCopy.welcomeLandingTitle,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s4),
                  Text(
                    VenialCopy.welcomeLandingSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.s20),
        Center(
          child: AppSvg(
            AppAssets.cityMap,
            size: MediaQuery.of(context).size.width < 600 ? 180 : 240,
          ),
        ),
        const SizedBox(height: AppTokens.s20),
        _WelcomeAction(
          title: VenialCopy.welcomeEnterTitle,
          subtitle: VenialCopy.welcomeEnterSubtitle,
          icon: AppAssets.navPlay,
          primary: true,
          onTap: onEnter,
        ),
        const SizedBox(height: AppTokens.s8),
        _WelcomeAction(
          title: VenialCopy.welcomeTutorialTitle,
          subtitle: VenialCopy.welcomeTutorialSubtitle,
          icon: AppAssets.uiSpark,
          onTap: onTutorial,
        ),
        const SizedBox(height: AppTokens.s8),
        _WelcomeAction(
          title: VenialCopy.welcomeProfileTitle,
          subtitle: VenialCopy.welcomeProfileSubtitle,
          icon: AppAssets.navProfile,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _WelcomeAction extends StatelessWidget {
  const _WelcomeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String title;
  final String subtitle;
  final String icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = primary ? scheme.primary : scheme.onSurfaceVariant;

    return Material(
      color: primary ? scheme.primaryContainer : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s12),
          child: Row(
            children: [
              AppSvg(icon, size: 22, color: color),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        color: primary ? scheme.primary : scheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTokens.s4),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.s8),
              Icon(Icons.chevron_right, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialStepView extends StatelessWidget {
  const _TutorialStepView({
    super.key,
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.progressLabel,
    required this.textTheme,
    required this.colorScheme,
    required this.sectionGap,
    required this.isCompact,
    required this.onNext,
    required this.onSkip,
    required this.onChooseMunicipality,
  });

  final _WarmStep step;
  final int stepIndex;
  final int totalSteps;
  final String progressLabel;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final double sectionGap;
  final bool isCompact;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final VoidCallback onChooseMunicipality;

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex >= totalSteps - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TicketProgress(
            label: VenialCopy.welcomeProgressLabel.replaceAll(
              '{step}',
              progressLabel,
            ),
            currentStep: stepIndex + 1,
            totalSteps: totalSteps,
          ),
        ),
        SizedBox(height: sectionGap),
        Center(child: AppSvg(step.asset, size: isCompact ? 150 : 190)),
        SizedBox(height: sectionGap),
        Semantics(
          header: true,
          child: Text(
            step.title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
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
        Wrap(
          spacing: AppTokens.s12,
          runSpacing: AppTokens.s12,
          children: [
            FilledButton(
              onPressed: onNext,
              child: Text(step.cta ?? VenialCopy.welcomeStep3Play),
            ),
            if (isLast)
              OutlinedButton(
                onPressed: onChooseMunicipality,
                child: const Text(VenialCopy.welcomeStep3Municipality),
              )
            else
              TextButton(
                onPressed: onSkip,
                child: const Text(VenialCopy.welcomeSkip),
              ),
          ],
        ),
      ],
    );
  }
}

class _WarmStep {
  const _WarmStep({
    required this.title,
    required this.subtitle,
    required this.asset,
    this.cta,
  });

  final String title;
  final String subtitle;
  final String asset;
  final String? cta;
}
