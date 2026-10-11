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
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  bool _resetting = false;
  bool _failed = false;

  Future<void> _clearUnrecoverableData() async {
    if (_resetting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ripartire solo su questo dispositivo?'),
        content: const Text(
          'La sessione salvata non è recuperabile. Non posso confermare la sua chiusura sul server. '
          'Le proposte già inviate potrebbero restare presenti. Le bozze e lo storico locali verranno cancellati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancella solo i dati locali'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _resetting = true;
      _failed = false;
    });
    try {
      await context.read<AppPrefs>().clearUnrecoverableLocalData();
      if (mounted) context.go('/boot');
    } catch (_) {
      if (mounted)
        setState(() {
          _resetting = false;
          _failed = true;
        });
    }
  }

  Future<void> _clearDataAndRestart(BuildContext context) async {
    if (_resetting) return;
    setState(() {
      _resetting = true;
      _failed = false;
    });
    final prefs = context.read<AppPrefs>();
    try {
      await prefs.clearAll();
    } catch (_) {
      if (mounted)
        setState(() {
          _resetting = false;
          _failed = true;
        });
      return;
    }
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
                        'Puoi cancellare bozze, proposte e voti della demo salvati su questo dispositivo, insieme alle preferenze. I dati già inviati al server API non vengono cancellati da questo comando.'
                        '${context.read<AppPrefs>().beforeClearAll == null ? '' : ' In modalità API viene prima chiusa la sessione di invio: se il server non risponde, i dati locali restano disponibili per riprovare.'}',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppTokens.s12),
                      FilledButton(
                        onPressed: _resetting
                            ? null
                            : () => _clearDataAndRestart(context),
                        child: Text(
                          _resetting
                              ? 'Cancellazione in corso…'
                              : 'Azzera dati locali e riparti',
                        ),
                      ),
                      if (_failed)
                        Semantics(
                          liveRegion: true,
                          child: const Text(
                            'Non riesco a completare la cancellazione. Riprova.',
                          ),
                        ),
                      if (_failed &&
                          context.read<AppPrefs>().sessionUnrecoverable)
                        TextButton(
                          onPressed: _resetting
                              ? null
                              : _clearUnrecoverableData,
                          child: const Text(
                            'Sessione non recuperabile: riparti localmente',
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
