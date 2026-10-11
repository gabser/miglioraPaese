import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';

class ProposalScopeNotice extends StatelessWidget {
  const ProposalScopeNotice({
    required this.invalid,
    required this.returnTo,
    super.key,
  });

  final bool invalid;
  final String returnTo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fanta Comune')),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: AppTokens.narrowContentWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.s16),
            child: FcPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      invalid
                          ? 'Il Comune nel collegamento non è valido.'
                          : 'Scegli un Comune per vedere le proposte.',
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),
                  FilledButton(
                    onPressed: () => context.go(
                      Uri(
                        path: context.read<AppPrefs>().municipalityId == null
                            ? '/onboarding'
                            : '/change-municipality',
                        queryParameters: {'returnTo': returnTo},
                      ).toString(),
                    ),
                    child: const Text('Scegli il Comune'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Torna alla home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
