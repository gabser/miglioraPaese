import 'package:fanta_comune/core/copy/venial_copy.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/theme/app_tokens.dart';
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
              child: const Text(VenialCopy.cancelCta),
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
            'La classifica online è visibile con almeno 3 giocatori in gara. Il punteggio cooperativo non è disponibile.',
          ),
          const Text(
            'La sessione anonima è legata a questo browser. Non è un account e non consente recupero su altri dispositivi.',
          ),
          const SizedBox(height: 16),
          const FcPanel(
            tint: AppTokens.blue,
            child: Text(
              'Crea una lega o usa un invito. La classifica confronta i punti delle squadre dagli esiti fissati al termine dell’osservazione. Non usa la reputazione né i voti alle proposte.',
            ),
          ),
          const SizedBox(height: 16),
          if (manager.remoteLeagues.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text('Non partecipi ancora a una lega privata.'),
            ),
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
                                  'Il servizio assegna un nome automatico a ogni giocatore. Dopo il primo blocco della stagione puoi entrare solo come spettatore.',
                                ) &&
                                mounted) {
                              if (await manager.createLeague(template)) {
                                accepted('Lega creata.');
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
                                  'Puoi entrare in gara prima del primo blocco della stagione. Dopo, entri come spettatore.',
                                ) &&
                                mounted) {
                              if (await manager.joinLeague(
                                tokenController.text.trim(),
                              )) {
                                tokenController.clear();
                                accepted('Sei entrato nella lega.');
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
                                  'I vecchi inviti smettono di funzionare. Il nuovo codice scade entro 24 ore: condividilo solo con il gruppo autorizzato alla prova online.',
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
                                    : 'La tua squadra e i tuoi punti restano salvati. Se rientri dopo il blocco, partecipi come spettatore.',
                              )) {
                                return;
                              }
                              if (await manager.leaveLeague(league.table.id)) {
                                if (mounted) {
                                  setState(
                                    () => invites.remove(league.table.id),
                                  );
                                }
                                accepted('Hai lasciato la lega.');
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
