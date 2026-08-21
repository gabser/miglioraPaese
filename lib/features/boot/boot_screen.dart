import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/models/problem_key.dart';
import 'package:fanta_comune/core/models/problem_status.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/animated_size_x.dart';
import 'package:fanta_comune/core/widgets/animated_switcher_x.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/widgets/segmented_choice.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
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
    final isCompact = MediaQuery.of(context).size.width < 600;
    final sectionGap = isCompact ? AppTokens.s12 : AppTokens.s16;
    final cardPadding = EdgeInsets.all(
      isCompact ? AppTokens.s12 : AppTokens.s16,
    );
    final appPrefs = context.read<AppPrefs>();
    const nextLocation = '/home';

    return Scaffold(
      appBar: AppBar(title: const Text(VenialCopy.appTitle)),
      body: SafeArea(
        child: MaxWidthContainer(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: sectionGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FcPanel(
                    tint: AppTokens.blue,
                    elevated: true,
                    padding: cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FcStatusChip(
                          label: VenialCopy.bootStickerLabel,
                          color: AppTokens.blue,
                          icon: AppIcons.board,
                        ),
                        const SizedBox(height: AppTokens.s12),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppTokens.radiusSmall,
                            ),
                          ),
                          child: Icon(
                            AppIcons.board,
                            color: colorScheme.primary,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: AppTokens.s12),
                        Text(
                          VenialCopy.bootHeroTitle,
                          style: TypographyX.headlineSmall(
                            context,
                          )?.copyWith(color: colorScheme.primary),
                        ),
                        const SizedBox(height: AppTokens.s12),
                        Text(
                          VenialCopy.bootHeroSubtitle,
                          style: textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppTokens.s16),
                        Text(
                          VenialCopy.bootHeroNote,
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  FcPanel(
                    padding: cardPadding,
                    child: Wrap(
                      spacing: AppTokens.s12,
                      runSpacing: AppTokens.s12,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(AppIcons.play),
                          label: const Text(VenialCopy.bootPrimaryCta),
                          onPressed: () => context.go(nextLocation),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(AppIcons.privacy),
                          label: const Text(VenialCopy.bootResetCta),
                          onPressed: () async {
                            await appPrefs.clearAll();
                            if (!mounted) return;
                            context.go('/boot');
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  FcPanel(
                    padding: cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          VenialCopy.bootInfoTitle,
                          style: TypographyX.titleLarge(context),
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
                              label: const Text(VenialCopy.bootInfoCtaHow),
                              onPressed: () => context.go('/how-it-works'),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(AppIcons.privacy),
                              label: const Text(VenialCopy.bootInfoCtaPrivacy),
                              onPressed: () => context.go('/privacy'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  FcPanel(
                    padding: cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          VenialCopy.bootIconsTitle,
                          style: TypographyX.titleLarge(context),
                        ),
                        const SizedBox(height: AppTokens.s12),
                        Text(
                          VenialCopy.bootIconsSubtitle,
                          style: textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppTokens.s16),
                        Text(
                          VenialCopy.bootIconsTabsTitle,
                          style: textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppTokens.s8),
                        Wrap(
                          spacing: AppTokens.s16,
                          runSpacing: AppTokens.s12,
                          children: const [
                            IconLabel(
                              icon: AppIcons.home,
                              text: VenialCopy.navHome,
                            ),
                            IconLabel(
                              icon: AppIcons.play,
                              text: VenialCopy.navPlay,
                            ),
                            IconLabel(
                              icon: AppIcons.leaderboard,
                              text: VenialCopy.navLeaderboard,
                            ),
                            IconLabel(
                              icon: AppIcons.profile,
                              text: VenialCopy.navProfile,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTokens.s16),
                        Text(
                          VenialCopy.bootIconsProblemsTitle,
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
                  SizedBox(height: sectionGap),
                  FcPanel(
                    padding: cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          VenialCopy.bootMotionTitle,
                          style: TypographyX.titleLarge(context),
                        ),
                        const SizedBox(height: AppTokens.s12),
                        Material(
                          type: MaterialType.transparency,
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _showMotionDetails,
                            activeColor: colorScheme.primary,
                            title: Text(
                              VenialCopy.bootMotionToggle,
                              style: textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              VenialCopy.bootMotionSubtitle,
                              style: textTheme.bodyMedium,
                            ),
                            onChanged: (value) async {
                              setState(() {
                                _showMotionDetails = value;
                              });
                              await appPrefs.setMotionDemoEnabled(value);
                            },
                          ),
                        ),
                        AnimatedSwitcherX(
                          child: _showMotionDetails
                              ? AnimatedSizeX(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppTokens.s12,
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(
                                        AppTokens.s12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          AppTokens.radius,
                                        ),
                                        border: Border.all(
                                          color: colorScheme.outlineVariant,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Micro-animazioni coordinate',
                                            style: textTheme.titleMedium
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onPrimaryContainer,
                                                ),
                                          ),
                                          const SizedBox(height: AppTokens.s8),
                                          Text(
                                            'Ingressi morbidi con fade + slide per comunicare cambi di stato senza distrazioni. '
                                            'Le durate e le curve derivano da AppMotion per un feeling premium su Web.',
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onPrimaryContainer,
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
                  FcPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Components demo', style: textTheme.titleLarge),
                        const SizedBox(height: AppTokens.s12),
                        Wrap(
                          spacing: AppTokens.s12,
                          runSpacing: AppTokens.s12,
                          children: const [
                            FcStatusChip(
                              label: 'Migliora',
                              color: AppTokens.success,
                              icon: Icons.trending_up,
                            ),
                            FcStatusChip(
                              label: 'Stabile',
                              color: AppTokens.warning,
                              icon: Icons.drag_handle,
                            ),
                            FcStatusChip(
                              label: 'Peggiora',
                              color: AppTokens.danger,
                              icon: Icons.trending_down,
                            ),
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
