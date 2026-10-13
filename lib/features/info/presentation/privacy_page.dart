import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:flutter/material.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
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
  String? _clearError;

  Future<void> _clearDataAndRestart(BuildContext context) async {
    if (_clearing) return;
    final config = context.read<AppConfig>();
    final hasRemoteData =
        config.fantasyDataSource == FantasyDataSource.api ||
        config.gameDataSource == GameDataSource.api ||
        config.nextProblemsDataSource == NextProblemsDataSource.api;
    if (hasRemoteData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminare i dati online?'),
          content: const Text(
            'Saranno cancellati voti, previsioni, esiti, squadra e partecipazione alle leghe associati alla '
            'sessione anonima. Le proposte pubblicate resteranno senza un '
            'collegamento alla sessione. Le leghe che hai creato saranno archiviate e i loro inviti revocati. Le squadre degli altri resteranno salvate. Verranno azzerate anche le '
            'preferenze locali, la partita demo e le partite conservate, le proposte demo, le bozze e le ricevute.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(VenialCopy.cancelCta),
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

    setState(() {
      _clearing = true;
      _clearError = null;
    });
    final prefs = context.read<AppPrefs>();
    final fantasyManager = config.fantasyModeEnabled
        ? context.read<FantasyManager>()
        : null;
    try {
      prefs.beginReset();
      if (hasRemoteData && !(fantasyManager?.isRemote ?? false)) {
        await context.read<ApiClient>().deleteJson(['v1', 'session']);
      }
      if (config.fantasyModeEnabled) {
        await fantasyManager!.clearLocalData();
      } else {
        await prefs.clearAll();
      }
      if (!context.mounted) return;
      context.go(config.fantasyModeEnabled ? '/welcome' : '/boot');
    } catch (error) {
      if (!context.mounted) return;
      setState(
        () => _clearError =
            'Cancellazione non completata: ${error is ApiException ? error.message : 'Riprova.'}',
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
        config.fantasyDataSource == FantasyDataSource.api ||
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
                            ? 'Puoi eliminare i dati della tua sessione anonima online e quelli locali. Le proposte pubblicate restano, senza il collegamento alla sessione.'
                            : 'Puoi cancellare i dati su questo dispositivo: preferenze, partita demo, partite conservate, proposte demo, bozze e ricevute. Poi riparti dall’inizio.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      if (_clearError != null) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _clearError!,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ),
                        const SizedBox(height: AppTokens.s12),
                      ],
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
                              : 'Elimina dati e riparti',
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
