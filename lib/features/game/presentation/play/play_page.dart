import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/primary_card.dart';

/// Pagina placeholder della sezione di gioco.
class PlayPage extends StatelessWidget {
  const PlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const IconLabel(icon: AppIcons.play, text: 'Gioca e fai previsioni'),
          const SizedBox(height: AppTokens.s12),
          PrimaryCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sfide civiche in arrivo',
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: AppTokens.s8),
                Text(
                  'Costruiremo missioni e pronostici per coinvolgere i cittadini in modo leggero e trasparente.',
                  style: textTheme.bodyMedium,
                ),
                const SizedBox(height: AppTokens.s12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.go('/how-it-works'),
                    icon: const Icon(AppIcons.info),
                    label: const Text('Come funziona'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
