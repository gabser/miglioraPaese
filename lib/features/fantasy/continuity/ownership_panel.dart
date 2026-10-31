import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'continuity_models.dart';
import 'continuity_repository.dart';

/// All mutations require an explicit action against the latest server revision.
class OwnershipPanel extends StatefulWidget {
  const OwnershipPanel({
    super.key,
    required this.leagueId,
    required this.seasonId,
    required this.onChanged,
  });
  final String leagueId, seasonId;
  final Future<void> Function() onChanged;
  @override
  State<OwnershipPanel> createState() => _OwnershipPanelState();
}

class _OwnershipPanelState extends State<OwnershipPanel> {
  LeagueContinuityRepository? repository;
  OwnershipWorkspace? workspace;
  bool busy = false, pending = false;
  String? message;
  int generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (repository == null) {
      repository = context.read<LeagueContinuityRepository>();
      repository!.addListener(invalidated);
    }
  }

  void invalidated() {
    generation++;
    if (mounted)
      setState(() {
        workspace = null;
        pending = false;
        busy = false;
        message = null;
      });
  }

  @override
  void didUpdateWidget(covariant OwnershipPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leagueId != widget.leagueId ||
        oldWidget.seasonId != widget.seasonId)
      invalidated();
  }

  @override
  void dispose() {
    generation++;
    repository?.removeListener(invalidated);
    super.dispose();
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    final g = ++generation;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      final value = await repository!.ownership(
        widget.leagueId,
        widget.seasonId,
      );
      final command = await repository!.pendingOwnership(
        widget.leagueId,
        widget.seasonId,
      );
      if (mounted && g == generation)
        setState(() {
          workspace = value;
          pending = command != null;
        });
    } catch (_) {
      if (mounted && g == generation)
        setState(() {
          workspace = null;
          message =
              'Operazione non confermata. Ricarica lo stato prima di procedere.';
        });
    } finally {
      if (mounted && g == generation) setState(() => busy = false);
    }
  }

  Future<void> command(List<String> tail, Map<String, Object?> fields) =>
      run(() async {
        await repository!.ownershipCommand(
          widget.leagueId,
          widget.seasonId,
          tail,
          fields,
        );
        await widget.onChanged();
      });
  @override
  Widget build(BuildContext context) {
    final w = workspace, offer = w?.pendingOffer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          'Proprietà della lega',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'La proprietà organizzativa non cambia ruolo competitivo o punti. Il destinatario deve accettare.',
        ),
        if (busy) const LinearProgressIndicator(),
        if (message != null) Semantics(liveRegion: true, child: Text(message!)),
        TextButton(
          onPressed: busy ? null : () => run(() async {}),
          child: const Text('Ricarica proprietà e offerte'),
        ),
        if (pending) ...[
          const Text(
            'Un comando non ha ancora una ricevuta certa. La lettura dello stato non lo ripete.',
          ),
          OutlinedButton(
            onPressed: busy
                ? null
                : () => run(() async {
                    await repository!.retryOwnership(
                      widget.leagueId,
                      widget.seasonId,
                    );
                    await widget.onChanged();
                  }),
            child: const Text('Riprova lo stesso comando'),
          ),
        ],
        if (w != null && !pending) ...[
          if (offer != null) ...[
            Text('Proposta a ${offer.targetPseudonym} · ${offer.status}'),
            Text('Scadenza: ${offer.expiresAt.toLocal()}'),
            if (offer.status == 'pending' && offer.isTarget)
              FilledButton(
                onPressed: busy
                    ? null
                    : () => command(
                        ['offers', offer.id, 'accept'],
                        {'expectedRevision': w.leagueRevision},
                      ),
                child: const Text('Accetta proprietà della lega'),
              ),
            if (offer.status == 'pending' && w.isOwner)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => command(
                        ['offers', offer.id, 'revoke'],
                        {'expectedRevision': w.leagueRevision},
                      ),
                child: const Text('Revoca proposta di proprietà'),
              ),
          ],
          if (w.isOwner && offer == null) ...[
            const Text('Proponi il trasferimento a un membro attivo:'),
            for (final candidate in w.candidates)
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () => command(
                        ['offers'],
                        {
                          'expectedRevision': w.leagueRevision,
                          'targetMemberId': candidate.memberId,
                        },
                      ),
                child: Text('Proponi a ${candidate.pseudonym}'),
              ),
            if (w.candidates.isEmpty)
              const Text('Nessun altro membro attivo disponibile.'),
          ],
          if (!w.isOwner && offer == null)
            const Text('Nessuna proposta di proprietà destinata a te.'),
        ],
      ],
    );
  }
}
