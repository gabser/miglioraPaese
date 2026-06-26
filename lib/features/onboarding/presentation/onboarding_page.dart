import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/vintage_paper.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/core/widgets/card_illustration_slot.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';

/// Schermata di onboarding per scegliere il Comune di riferimento.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final TextEditingController _controller = TextEditingController();

  static const _cities = [
    'Milano',
    'Roma',
    'Torino',
    'Bologna',
    'Napoli',
    'Palermo',
    'Firenze',
    'Genova',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _filteredCities {
    final query = _controller.text.toLowerCase().trim();
    if (query.isEmpty) return _cities;
    return _cities.where((city) => city.toLowerCase().contains(query)).toList();
  }

  Future<void> _selectCity(BuildContext context, String city) async {
    final prefs = context.read<AppPrefs>();
    await prefs.setMunicipalityId('comune:$city');
    if (!mounted) return;
    context.go('/play');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final padding = isCompact ? AppTokens.s12 : AppTokens.s16;

    return Scaffold(
      appBar: AppBar(
        title: const Text(VenialCopy.onboardingTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IconLabel(
                  icon: AppIcons.home,
                  text: VenialCopy.appTitle,
                  iconSize: textTheme.titleMedium?.fontSize ?? 24,
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  VenialCopy.onboardingSubtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: isCompact ? AppTokens.s12 : AppTokens.s16),
                PrimaryCard(
                  textured: true,
                  elevated: true,
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardIllustrationSlot(
                        fallbackIcon: AppIcons.home,
                        height: 72,
                        compact: true,
                        labelRibbon: VenialCopy.onboardingRibbonLabel,
                      ),
                      SizedBox(
                          height: isCompact ? AppTokens.s8 : AppTokens.s12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTokens.s12,
                          vertical: AppTokens.s8 / 2,
                        ),
                        decoration: VintagePaper.tapeDecoration(colorScheme),
                        child: Text(
                          VenialCopy.onboardingCityTitle,
                          style: TypographyX.titleMedium(context)?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTokens.s12),
                      TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: VenialCopy.onboardingSearchHint,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppTokens.s16),
                      ..._filteredCities.map(
                        (city) => Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppTokens.s8),
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(AppTokens.radius),
                            onTap: () => _selectCity(context, city),
                            child: Semantics(
                              label: VenialCopy.onboardingCitySelectTemplate
                                  .replaceAll('{city}', city),
                              button: true,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppTokens.s12,
                                  horizontal: AppTokens.s8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(AppIcons.play),
                                    const SizedBox(width: AppTokens.s12),
                                    Expanded(
                                      child: Text(
                                        city,
                                        style: textTheme.titleMedium,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
