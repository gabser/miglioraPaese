import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_league_repository.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import 'package:fanta_comune/features/fantasy/presentation/widgets/fantasy_widgets.dart';

class RemoteLeaguesPage extends StatefulWidget {
  const RemoteLeaguesPage({super.key});
  @override
  State<RemoteLeaguesPage> createState() => _RemoteLeaguesPageState();
}

class _RemoteLeaguesPageState extends State<RemoteLeaguesPage> {
  final tokenController = TextEditingController();
  String template = 'Amici';
  final Map<String, FantasyLeagueInvite> invites = {};
  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
  }

  Future<bool> confirm(String title, String content) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Conferma'),
            ),
          ],
        ),
      ) ??
      false;
  void accepted(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<FantasyManager>();
    final disabled = manager.busy;
    invites.removeWhere(
      (id, _) => !manager.remoteLeagues.any(
        (l) => l.table.id == id && l.isOwner && !l.archived,
      ),
    );
    return FantasyPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Leghe private',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Text(
            'Classifica personale dal server, visibile da tre competitori. Punteggio cooperativo non disponibile.',
          ),
          const Text(
            'La sessione anonima è legata a questo browser. Non è un account e non consente recupero su altri dispositivi.',
          ),
          const SizedBox(height: 16),
          if (manager.leagueError != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(manager.leagueError!),
                    TextButton(
                      onPressed: disabled ? null : manager.refreshLeagues,
                      child: const Text('Ricarica leghe'),
                    ),
                  ],
                ),
              ),
            ),
          if (manager.leagueBusy) const LinearProgressIndicator(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: template,
                    decoration: const InputDecoration(
                      labelText: 'Tipo di lega',
                    ),
                    items: ['Amici', 'Quartiere', 'Comune']
                        .map(
                          (name) =>
                              DropdownMenuItem(value: name, child: Text(name)),
                        )
                        .toList(),
                    onChanged: disabled
                        ? null
                        : (value) => setState(() => template = value!),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: disabled
                        ? null
                        : () async {
                            if (await confirm(
                                  'Creare la lega?',
                                  'Il server assegnerà pseudonimi automatici. Dopo il primo lock della stagione si entra come spettatori.',
                                ) &&
                                mounted) {
                              if (await manager.createLeague(template)) {
                                accepted('Lega creata sul server.');
                              }
                            }
                          },
                    child: const Text('Crea lega privata'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('league-invite-token'),
                    controller: tokenController,
                    enabled: !disabled,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: 43,
                    decoration: const InputDecoration(
                      labelText: 'Codice invito privato',
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: disabled
                        ? null
                        : () async {
                            if (await confirm(
                                  'Entrare nella lega?',
                                  'L’ingresso competitivo è consentito prima del primo lock. Un ingresso successivo è da spettatore.',
                                ) &&
                                mounted) {
                              if (await manager.joinLeague(
                                tokenController.text.trim(),
                              )) {
                                tokenController.clear();
                                accepted('Adesione accettata dal server.');
                              }
                            }
                          },
                    child: const Text('Entra con invito'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (manager.remoteLeagues.isEmpty)
            const Text('Non partecipi ancora a una lega privata.'),
          ...manager.remoteLeagues.map(
            (league) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      league.table.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${league.memberCount} membri · ${league.competitiveCount} competitori',
                    ),
                    Text(
                      league.archived
                          ? 'Lega archiviata'
                          : league.isSpectator
                          ? 'Partecipi come spettatore'
                          : 'Partecipi alla classifica personale',
                    ),
                    if (league.competitiveCount < 3)
                      const Text(
                        'Servono almeno tre competitori per mostrare la classifica.',
                      )
                    else
                      LeagueTable(league: league.table),
                    if (league.isOwner && !league.archived) ...[
                      TextButton(
                        onPressed: disabled
                            ? null
                            : () async {
                                if (!await confirm(
                                  'Generare un nuovo invito?',
                                  'Tutti gli inviti precedenti saranno revocati. Il codice scade entro 24 ore: condividilo solo con il gruppo pilot autorizzato.',
                                )) {
                                  return;
                                }
                                final invite = await manager.rotateInvite(
                                  league.table.id,
                                );
                                if (invite != null && mounted) {
                                  setState(
                                    () => invites[league.table.id] = invite,
                                  );
                                }
                              },
                        child: const Text('Genera o sostituisci invito'),
                      ),
                      if (invites[league.table.id]
                          case final FantasyLeagueInvite invite) ...[
                        const Text(
                          'Invito privato · mostrato solo in questa pagina',
                        ),
                        SelectableText(invite.token),
                        Text('Scadenza: ${invite.expiresAt.toLocal()}'),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: invite.token),
                              ),
                              child: const Text('Copia codice'),
                            ),
                            TextButton(
                              onPressed: disabled
                                  ? null
                                  : () async {
                                      if (await manager.revokeInvite(
                                            league.table.id,
                                            invite.id,
                                          ) &&
                                          mounted) {
                                        setState(
                                          () => invites.remove(league.table.id),
                                        );
                                      }
                                    },
                              child: const Text('Revoca invito'),
                            ),
                          ],
                        ),
                      ],
                    ],
                    TextButton(
                      onPressed: disabled
                          ? null
                          : () async {
                              if (!await confirm(
                                'Uscire dalla lega?',
                                league.isOwner
                                    ? 'La lega sarà archiviata e tutti gli inviti revocati. Le squadre degli altri membri resteranno conservate.'
                                    : 'La tua squadra e i tuoi punti personali resteranno conservati. Un eventuale rientro dopo il lock sarà da spettatore.',
                              )) {
                                return;
                              }
                              if (await manager.leaveLeague(league.table.id)) {
                                if (mounted) {
                                  setState(
                                    () => invites.remove(league.table.id),
                                  );
                                }
                                accepted('Uscita accettata dal server.');
                              }
                            },
                      child: const Text('Esci dalla lega'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: disabled ? null : manager.refreshLeagues,
            child: const Text('Aggiorna classifiche'),
          ),
        ],
      ),
    );
  }
}
