import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';

/// Entrata breve; la vetrina dei componenti vive in /design-preview.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          child: FcPageShell(
            maxWidth: AppTokens.narrowContentWidth,
            child: FcPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_city_outlined,
                    size: 48,
                    color: AppTokens.blue,
                  ),
                  const SizedBox(height: AppTokens.s16),
                  const FcSectionHeader(
                    title: 'Fanta Comune',
                    subtitle:
                        'Osserva il tuo territorio, proponi un problema e prova il gioco civico.',
                  ),
                  const SizedBox(height: AppTokens.s12),
                  const Text(
                    'È una demo. Le proposte non sostituiscono i canali ufficiali del Comune.',
                  ),
                  const SizedBox(height: AppTokens.s16),
                  FilledButton(
                    onPressed: () => context.go(
                      context.read<AppPrefs>().municipalityId == null
                          ? '/welcome'
                          : '/home',
                    ),
                    child: const Text('Entra'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
