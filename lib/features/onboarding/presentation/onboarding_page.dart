import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
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
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli il tuo Comune'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IconLabel(
                  icon: AppIcons.home,
                  text: 'Fanta Comune',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  'Seleziona il Comune per sbloccare le partite e la classifica locale.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
                PrimaryCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Cerca il tuo Comune',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppTokens.s16),
                      ..._filteredCities.map(
                        (city) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppTokens.s8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppTokens.radius),
                            onTap: () => _selectCity(context, city),
                            child: Semantics(
                              label: 'Seleziona $city',
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
