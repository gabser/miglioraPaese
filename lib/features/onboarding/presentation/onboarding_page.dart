import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/theme/typography_x.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';

/// Schermata di onboarding per scegliere il Comune di riferimento.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({this.afterSelectionRoute = '/home', super.key});

  final String afterSelectionRoute;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _filteredCities {
    final query = _controller.text.toLowerCase().trim();
    if (query.isEmpty) return MunicipalityCatalog.activeCities;
    return MunicipalityCatalog.activeCities
        .where((city) => city.toLowerCase().contains(query))
        .toList();
  }

  String? get _customCity {
    final value = _controller.text.trim();
    if (value.length < 2) return null;
    final alreadyListed = MunicipalityCatalog.activeCities.any(
      (city) => city.toLowerCase() == value.toLowerCase(),
    );
    return alreadyListed ? null : value;
  }

  Future<void> _selectCity(BuildContext context, String city) async {
    final prefs = context.read<AppPrefs>();
    await prefs.setMunicipalityId(MunicipalityCatalog.idForCity(city));
    if (!context.mounted) return;
    context.go(widget.afterSelectionRoute);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final padding = isCompact ? AppTokens.s12 : AppTokens.s16;

    return Scaffold(
      appBar: AppBar(title: const Text(VenialCopy.onboardingTitle)),
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
                FcPanel(
                  tint: AppTokens.blue,
                  elevated: true,
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FcStatusChip(
                        label: VenialCopy.onboardingRibbonLabel,
                        color: AppTokens.blue,
                        icon: AppIcons.home,
                      ),
                      SizedBox(
                        height: isCompact ? AppTokens.s8 : AppTokens.s12,
                      ),
                      Text(
                        VenialCopy.onboardingCityTitle,
                        style: TypographyX.titleMedium(
                          context,
                        )?.copyWith(fontWeight: FontWeight.w800),
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
                      ...[
                        ..._filteredCities,
                        if (_customCity != null) _customCity!,
                      ].map(
                        (city) => Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTokens.s8,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              AppTokens.radius,
                            ),
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
                                        MunicipalityCatalog.activeCities
                                                .contains(city)
                                            ? city
                                            : 'Attiva $city',
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
