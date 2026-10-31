import 'package:flutter/material.dart';
import 'package:fanta_comune/core/privacy/privacy_copy.dart';
import 'package:fanta_comune/core/theme/app_icons.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/icon_label.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:go_router/go_router.dart';

/// Pagina informativa che spiega in breve le regole di gioco e rimanda alla privacy.
class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Come funziona')),
      body: SafeArea(
        child: MaxWidthContainer(
          child: SingleChildScrollView(
            child: Column(
              children: [
                FcPanel(
                  tint: AppTokens.blue,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IconLabel(
                        icon: AppIcons.info,
                        text: PrivacyCopy.micropitch,
                      ),
                      const SizedBox(height: AppTokens.s16),
                      Wrap(
                        spacing: AppTokens.s12,
                        runSpacing: AppTokens.s12,
                        children: const [
                          _StepCard(stepNumber: 1, title: 'Scegli il Comune'),
                          _StepCard(
                            stepNumber: 2,
                            title:
                                'Fai previsioni: Migliora / Stabile / Peggiora',
                          ),
                          _StepCard(
                            stepNumber: 3,
                            title:
                                'Guadagna reputazione e confrontati in classifica',
                          ),
                        ],
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
                const SizedBox(height: AppTokens.s16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.go('/privacy'),
                    icon: const Icon(AppIcons.privacy),
                    label: const Text('Privacy'),
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

class _StepCard extends StatelessWidget {
  const _StepCard({required this.stepNumber, required this.title});

  final int stepNumber;
  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 260),
      child: FcPanel(
        padding: const EdgeInsets.all(AppTokens.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: AppTokens.s16,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                '$stepNumber',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.s12),
            Expanded(child: Text(title, style: textTheme.titleMedium)),
          ],
        ),
      ),
    );
  }
}
