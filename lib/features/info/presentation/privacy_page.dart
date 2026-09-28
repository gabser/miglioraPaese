import 'package:flutter/material.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/privacy/privacy_copy.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Pagina dedicata a privacy e controllo dei dati locali e del pilot.
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _clearing = false;

  Future<void> _clearDataAndRestart(BuildContext context) async {
    if (_clearing) return;
    final config = context.read<AppConfig>();
    final hasRemoteData =
        config.gameDataSource == GameDataSource.api ||
        config.nextProblemsDataSource == NextProblemsDataSource.api;
    if (hasRemoteData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminare i dati del pilot?'),
          content: const Text(
            'Saranno cancellati voti, previsioni ed esiti associati alla '
            'sessione anonima. Le proposte pubblicate resteranno senza un '
            'collegamento alla sessione. Verranno azzerate anche le '
            'preferenze locali.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Elimina e riparti'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    setState(() => _clearing = true);
    final prefs = context.read<AppPrefs>();
    try {
      if (hasRemoteData) {
        await context.read<ApiClient>().deleteJson(['v1', 'session']);
      }
      await prefs.clearAll();
      if (!context.mounted) return;
      context.go('/boot');
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cancellazione non completata: ${error.message} Riprova.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final config = context.watch<AppConfig>();
    final hasRemoteData =
        config.gameDataSource == GameDataSource.api ||
        config.nextProblemsDataSource == NextProblemsDataSource.api;

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
                        hasRemoteData
                            ? 'Puoi eliminare i dati associati alla sessione anonima del pilot e azzerare le preferenze locali.'
                            : 'Puoi azzerare le preferenze locali e ripartire in qualsiasi momento.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      FilledButton.icon(
                        onPressed: _clearing
                            ? null
                            : () => _clearDataAndRestart(context),
                        icon: const Icon(AppIcons.privacy),
                        label: Text(
                          _clearing
                              ? 'Cancellazione in corso…'
                              : hasRemoteData
                              ? 'Elimina dati e riparti'
                              : 'Azzera preferenze e riparti',
                        ),
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
