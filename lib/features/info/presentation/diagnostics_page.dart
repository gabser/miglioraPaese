import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Configuration only: opening this page must never acquire a session or
/// instantiate repositories that can create remote data.
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final usesApi =
        config.gameDataSource == GameDataSource.api ||
        config.nextProblemsDataSource == NextProblemsDataSource.api ||
        (config.fantasyModeEnabled &&
            config.fantasyDataSource == FantasyDataSource.api) ||
        config.accountModeEnabled;
    final laboratory =
        config.accountModeEnabled ||
        config.missionsModeEnabled ||
        config.reviewModeEnabled ||
        config.measurementsModeEnabled ||
        config.leagueContinuityModeEnabled ||
        config.cooperationModeEnabled;
    final profile = laboratory
        ? 'Laboratorio sintetico configurato'
        : usesApi
        ? 'API configurata'
        : 'Demo locale';
    final flags = <String, String>{
      'Gioco': config.gameDataSource.name,
      'Proposte': config.nextProblemsDataSource.name,
      'Fantasy': config.fantasyModeEnabled
          ? config.fantasyDataSource.name
          : 'disattivato',
      'Account': _enabled(config.accountModeEnabled),
      'Missioni': _enabled(config.missionsModeEnabled),
      'Revisione': _enabled(config.reviewModeEnabled),
      'Misurazioni': _enabled(config.measurementsModeEnabled),
      'Continuità leghe': _enabled(config.leagueContinuityModeEnabled),
      'Cooperazione': _enabled(config.cooperationModeEnabled),
    };
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Informazioni ambiente')),
      body: SafeArea(
        child: SingleChildScrollView(
          child: MaxWidthContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FcPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile, style: textTheme.titleLarge),
                      const SizedBox(height: AppTokens.s12),
                      const Text(
                        'Configurazione di questa app. Backend non verificato: '
                        'questa pagina non contatta il server e non crea account o sessioni.',
                      ),
                      const SizedBox(height: AppTokens.s12),
                      const Text('Candidato client'),
                      SelectableText(config.candidateId ?? 'Non identificato'),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
                FcPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Funzioni configurate', style: textTheme.titleLarge),
                      const SizedBox(height: AppTokens.s12),
                      for (final flag in flags.entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppTokens.s8),
                          child: Text('${flag.key}: ${flag.value}'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTokens.s16),
                const FcPanel(
                  child: Text(
                    'Solo prove sintetiche locali. NO-GO operativo: i gate umani '
                    'per privacy, ruoli, fonti e servizi sono ancora aperti. '
                    'La configurazione e i test non autorizzano un pilot reale.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _enabled(bool value) => value ? 'attivo' : 'disattivato';
}
