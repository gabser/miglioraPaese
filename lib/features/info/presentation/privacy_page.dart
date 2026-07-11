import 'package:flutter/material.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/privacy/privacy_copy.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Pagina dedicata a privacy e controllo dei dati locali.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  Future<void> _clearDataAndRestart(BuildContext context) async {
    final prefs = context.read<AppPrefs>();
    await prefs.clearAll();
    if (!context.mounted) return;
    context.go('/boot');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: SafeArea(
        child: MaxWidthContainer(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FcPanel(
                  tint: AppTokens.blue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In breve', style: textTheme.titleLarge),
                      const SizedBox(height: AppTokens.s12),
                      ...PrivacyCopy.principles.map(
                        (principle) => Padding(
                          padding: const EdgeInsets.only(bottom: AppTokens.s8),
                          child: IconLabel(
                            icon: AppIcons.info,
                            text: principle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
                FcPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Controllo dati', style: textTheme.titleLarge),
                      const SizedBox(height: AppTokens.s12),
                      Text(
                        'Puoi azzerare le preferenze locali e ripartire in qualsiasi momento.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      FilledButton.icon(
                        onPressed: () => _clearDataAndRestart(context),
                        icon: const Icon(AppIcons.privacy),
                        label: const Text('Azzera preferenze e riparti'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTokens.s12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppTokens.radius),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Text(
                    PrivacyCopy.disclaimer,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
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
