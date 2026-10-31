import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'continuity_controller.dart';
import 'continuity_repository.dart';

class LeagueInvitePage extends StatefulWidget {
  const LeagueInvitePage({super.key});
  @override
  State<LeagueInvitePage> createState() => _LeagueInvitePageState();
}

class _LeagueInvitePageState extends State<LeagueInvitePage> {
  final token = TextEditingController();
  LeagueInviteController? controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controller == null) {
      controller = LeagueInviteController(
        context.read<LeagueContinuityRepository>(),
      );
      if (controller!.repository.inviteToken != null)
        Future.microtask(controller!.preview);
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller!,
    builder: (context, _) {
      final c = controller!, p = c.summary;
      return Scaffold(
        appBar: AppBar(title: const Text('Invito alla lega')),
        body: SafeArea(
          child: MaxWidthContainer(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Rivedi l’invito',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Il riepilogo non iscrive alla lega. Comune, stagione e ruolo sono stabiliti dal server.',
                  ),
                  const SizedBox(height: 16),
                  if (c.busy) const LinearProgressIndicator(),
                  if (c.message != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(c.message!),
                      ),
                    ),
                  if (p == null && !c.joined) ...[
                    TextField(
                      controller: token,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Codice invito privato',
                      ),
                      enabled: !c.busy,
                    ),
                    FilledButton(
                      onPressed: c.busy
                          ? null
                          : () => c.preview(
                              token.text.isEmpty ? null : token.text,
                            ),
                      child: const Text('Mostra riepilogo'),
                    ),
                  ],
                  if (p != null && !c.joined)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              p.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              'Comune: ${MunicipalityCatalog.displayNameFromId(p.municipalityId)}',
                            ),
                            Text('Stagione: ${p.seasonId}'),
                            Text(
                              'Ruolo previsto: ${p.expectedRole == 'spectator' ? 'spettatore' : 'competitore'}',
                            ),
                            if (p.lateJoinReason != null)
                              Text(
                                p.lateJoinReason == 'firstLockReached'
                                    ? 'Il primo lock è trascorso: puoi seguire la lega come spettatore.'
                                    : 'La squadra è già congelata: puoi seguire la lega come spettatore.',
                              ),
                            Text('Primo lock: ${p.firstLocksAt.toLocal()}'),
                            Text(
                              'Invito valido fino a: ${p.expiresAt.toLocal()}',
                            ),
                            const SizedBox(height: 16),
                            if (context.read<AppConfig>().accountModeEnabled)
                              OutlinedButton(
                                onPressed: c.busy
                                    ? null
                                    : () => context.go(
                                        '/account?returnTo=/league-invite',
                                      ),
                                child: const Text(
                                  'Accedi e riprendi questo invito',
                                ),
                              ),
                            if (!c.teamReady) ...[
                              TextButton(
                                onPressed: c.busy ? null : c.checkTeam,
                                child: const Text('Verifica la mia squadra'),
                              ),
                              FilledButton.tonal(
                                onPressed: c.busy ? null : c.enroll,
                                child: const Text(
                                  'Prepara squadra nel Comune e stagione indicati',
                                ),
                              ),
                            ],
                            if (c.teamReady)
                              FilledButton(
                                onPressed: c.busy ? null : c.confirm,
                                child: const Text(
                                  'Conferma adesione alla lega',
                                ),
                              ),
                            TextButton(
                              onPressed: c.busy ? null : () => c.preview(),
                              child: const Text('Aggiorna riepilogo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (c.joined)
                    FilledButton(
                      onPressed: () => context.go('/leagues'),
                      child: const Text('Vai alle leghe'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
