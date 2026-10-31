import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import '../logic/review_controller.dart';
import '../domain/review_models.dart';

String reviewLabel(String status) => switch (status) {
  'pendingReview' => 'In attesa di revisione',
  'screened' => 'Contenuti esaminati',
  'needsIntegration' => 'Integrazione richiesta',
  'approved' => 'Validata',
  'rejected' => 'Rifiutata',
  _ => status,
};

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    this.observationId,
    this.replicationRequestId,
    this.author = false,
    this.ledger = false,
    super.key,
  });
  final String? observationId, replicationRequestId;
  final bool author, ledger;
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final _reason = TextEditingController(),
      _notes = TextEditingController(),
      _replica = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _initialized = false;
  String? _notesScope;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  void _load() {
    final c = context.read<ReviewController>();
    if (widget.replicationRequestId != null) {
      _replica.text = widget.replicationRequestId!;
      c.inspectReplica(widget.replicationRequestId!);
    } else if (widget.ledger)
      c.loadLedger();
    else if (widget.observationId != null)
      c.open(widget.observationId!, author: widget.author);
    else
      c.browse();
  }

  @override
  void didUpdateWidget(ReviewPage old) {
    super.didUpdateWidget(old);
    if (old.replicationRequestId != widget.replicationRequestId ||
        old.observationId != widget.observationId ||
        old.author != widget.author ||
        old.ledger != widget.ledger) {
      _reason.clear();
      _notesScope = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _notes.dispose();
    _replica.dispose();
    super.dispose();
  }

  void _act(ReviewController c, String action, {String? decision}) {
    if (!_form.currentState!.validate()) return;
    if (action == 'replication-requests') {
      c.requestReplication(_reason.text.trim());
      return;
    }
    c.command(
      action,
      decision: decision,
      reason: action == 'integration-requests' ? null : _reason.text.trim(),
      message: action == 'integration-requests' ? _reason.text.trim() : null,
    );
  }

  Future<void> _proof(ReviewController c, MissionProof p) async {
    await c.showProof(p);
    if (!mounted || c.preview == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prova privata sintetica'),
        content: Consumer<ReviewController>(
          builder: (_, state, __) => state.preview == null
              ? const Text('Accesso terminato.')
              : Image.memory(
                  state.preview!,
                  fit: BoxFit.contain,
                  width: 320,
                  height: 320,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
    c.closeProof();
  }

  Widget _card(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReviewController>(), o = c.observation;
    final ns = o == null
        ? null
        : '${o.id}:${c.principalId}:${o.integration?.id}:${o.revision}';
    if (_notesScope != ns ||
        (c.supplementUncertain && _notes.text != c.notes)) {
      _notesScope = ns;
      _notes.text = c.notes;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.ledger
              ? 'Registro XP'
              : widget.author
              ? 'Stato osservazione'
              : 'Revisione locale',
        ),
        actions: [
          IconButton(
            tooltip: 'Aggiorna dal server',
            onPressed: c.busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: 1000,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _card(
                  const Text(
                    'Profilo web sintetico locale. Le prove sono private; i ruoli vengono verificati dal server nel Comune.',
                  ),
                ),
                if (c.busy)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Richiesta al server in corso',
                  ),
                if (c.error != null)
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.error!, key: const ValueKey('review-error')),
                        TextButton(
                          onPressed: () => context.go(
                            Uri(
                              path: '/account',
                              queryParameters: {
                                'returnTo': widget.ledger
                                    ? '/xp'
                                    : widget.observationId == null
                                    ? '/review'
                                    : '/${widget.author ? "observations" : "review"}/${widget.observationId}',
                              },
                            ).toString(),
                          ),
                          child: const Text('Gestisci account'),
                        ),
                      ],
                    ),
                  ),
                if (widget.ledger && c.ledger != null) _xp(c.ledger!),
                if (!widget.ledger && widget.observationId == null) ...[
                  if (c.capabilities != null && !c.capabilities!.canReview)
                    _card(
                      const Text(
                        'Nessun ruolo di revisione assegnato a questo account nel Comune.',
                      ),
                    ),
                  if (c.capabilities?.canReview == true) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Tutti'),
                          selected: c.statusFilter == null,
                          onSelected: c.busy ? null : (_) => c.browse(),
                        ),
                        for (final s in reviewStatuses)
                          ChoiceChip(
                            label: Text(reviewLabel(s)),
                            selected: c.statusFilter == s,
                            onSelected: c.busy
                                ? null
                                : (_) => c.browse(status: s),
                          ),
                      ],
                    ),
                    if (c.queue.isEmpty && !c.busy)
                      _card(
                        const Text(
                          'Nessuna osservazione nella coda selezionata.',
                        ),
                      ),
                    for (final item in c.queue)
                      _card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.answer.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              '${reviewLabel(item.status)} · revisione ${item.revision}',
                            ),
                            Text('Luogo ${item.placeId}'),
                            TextButton(
                              onPressed: () => context.go('/review/${item.id}'),
                              child: const Text('Apri caso'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
                if (o != null && widget.observationId != null) ...[
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviewLabel(o.status),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text('Codice ${o.id}'),
                        Text('${o.answer.label} · revisione ${o.revision}'),
                        Text(
                          'Note originali: ${o.notes.isEmpty ? "Nessuna" : o.notes}',
                        ),
                        Text(
                          'XP correnti del contributo: ${o.xpAwarded}',
                          key: const ValueKey('current-xp'),
                        ),
                        Text('Luogo ${o.placeId} · finestra ${o.windowId}'),
                        Text(
                          'Assegnato: ${o.assignedTo ?? "nessun operatore"}',
                        ),
                      ],
                    ),
                  ),
                  if (widget.author && c.ledger != null) _xp(c.ledger!),
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prove private',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (o.proofs.isEmpty)
                          const Text('Nessuna prova originale.'),
                        for (final p in o.proofs)
                          TextButton.icon(
                            onPressed: c.busy ? null : () => _proof(c, p),
                            icon: const Icon(Icons.image_outlined),
                            label: Text('Apri prova ${p.id}'),
                          ),
                        for (final s in o.supplements) ...[
                          Text('Integrazione ${s.id}: ${s.notes}'),
                          for (final p in s.proofs)
                            TextButton(
                              onPressed: c.busy ? null : () => _proof(c, p),
                              child: Text('Apri prova aggiunta ${p.id}'),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (o.integration != null)
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Richiesta di integrazione'),
                          Text(o.integration!.message),
                          Text(
                            'Stato: ${o.integration!.status} · scadenza UTC ${o.integration!.dueAt.toIso8601String()}',
                          ),
                        ],
                      ),
                    ),
                  if (widget.author &&
                      o.integration != null &&
                      (o.integration!.status == 'open' ||
                          c.supplementUncertain))
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _notes,
                            enabled: !c.busy && !c.supplementUncertain,
                            maxLength: 1000,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Note aggiuntive',
                              helperText:
                                  'L’originale e la ricevuta di accettazione restano immutabili.',
                            ),
                          ),
                          Text('${c.photos.length} prove sintetiche salvate'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: c.busy || c.supplementUncertain
                                    ? null
                                    : () => c.addPhoto(_notes.text),
                                child: const Text('Aggiungi file sintetico'),
                              ),
                              OutlinedButton(
                                onPressed: c.busy || c.supplementUncertain
                                    ? null
                                    : () => c.saveSupplement(_notes.text),
                                child: const Text('Salva bozza'),
                              ),
                              FilledButton(
                                onPressed: c.busy
                                    ? null
                                    : () => c.supplement(_notes.text),
                                child: Text(
                                  c.supplementUncertain
                                      ? 'Recupera invio integrazione'
                                      : 'Invia integrazione',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (!widget.author && c.capabilities?.canReview == true) ...[
                    if (!c.assigned &&
                        ((c.capabilities!.moderator &&
                                o.status == 'pendingReview') ||
                            (c.capabilities!.verifier &&
                                [
                                  'screened',
                                  'needsIntegration',
                                ].contains(o.status))))
                      FilledButton(
                        onPressed: c.busy
                            ? null
                            : () => c.command('assignment'),
                        child: const Text('Assegna a me'),
                      ),
                    if (c.assigned)
                      _card(
                        Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                controller: _reason,
                                enabled: !c.busy,
                                maxLength: 1000,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Motivazione / richiesta',
                                  helperText:
                                      'Obbligatoria; viene registrata nell’audit.',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Inserisci una motivazione.'
                                    : null,
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (c.capabilities!.moderator &&
                                      o.status == 'pendingReview') ...[
                                    FilledButton(
                                      onPressed: c.busy
                                          ? null
                                          : () => _act(
                                              c,
                                              'screening',
                                              decision: 'forward',
                                            ),
                                      child: const Text(
                                        'Inoltra al verificatore',
                                      ),
                                    ),
                                    OutlinedButton(
                                      onPressed: c.busy
                                          ? null
                                          : () => _act(
                                              c,
                                              'screening',
                                              decision: 'reject',
                                            ),
                                      child: const Text('Rifiuta contenuti'),
                                    ),
                                  ],
                                  if (c.capabilities!.verifier &&
                                      [
                                        'screened',
                                        'needsIntegration',
                                      ].contains(o.status)) ...[
                                    if (o.status == 'screened')
                                      OutlinedButton(
                                        onPressed: c.busy
                                            ? null
                                            : () => _act(
                                                c,
                                                'integration-requests',
                                              ),
                                        child: const Text(
                                          'Richiedi integrazione',
                                        ),
                                      ),
                                    if (o.status == 'screened')
                                      FilledButton(
                                        onPressed: c.busy
                                            ? null
                                            : () => _act(
                                                c,
                                                'decisions',
                                                decision: 'approve',
                                              ),
                                        child: const Text(
                                          'Valida osservazione',
                                        ),
                                      ),
                                    OutlinedButton(
                                      onPressed: c.busy
                                          ? null
                                          : () => _act(
                                              c,
                                              'decisions',
                                              decision: 'reject',
                                            ),
                                      child: const Text('Rifiuta osservazione'),
                                    ),
                                  ],
                                  if (c.capabilities!.verifier &&
                                      o.status == 'approved')
                                    OutlinedButton(
                                      onPressed: c.busy
                                          ? null
                                          : () =>
                                                _act(c, 'replication-requests'),
                                      child: const Text('Richiedi replica'),
                                    ),
                                ],
                              ),
                              if (c.replicationId.isNotEmpty)
                                SelectableText(
                                  'Codice richiesta replica: ${c.replicationId}',
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audit',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final a in o.audit)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${a.action} · attore ${a.actorId} · revisione ${a.revision}\n${a.at.toIso8601String()} · ${a.reason}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (widget.ledger) ...[
                  _card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _replica,
                          decoration: const InputDecoration(
                            labelText: 'Codice richiesta replica ricevuta',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: c.busy
                              ? null
                              : () => c.inspectReplica(_replica.text.trim()),
                          child: const Text('Verifica richiesta dal server'),
                        ),
                        if (c.replica != null) ...[
                          Text(
                            'Luogo ${c.replica!["placeId"]} · finestra ${c.replica!["windowId"]} · scadenza ${c.replica!["dueAt"]}',
                          ),
                          if (c.replicaBooking == null &&
                              c.replica!['bookingId'] == null &&
                              c.replica!['status'] == 'open')
                            FilledButton(
                              onPressed: c.busy ? null : c.acceptReplica,
                              child: const Text('Accetta prenotazione replica'),
                            ),
                          if (c.replicaBooking != null ||
                              c.replica!['bookingId'] != null)
                            TextButton(
                              onPressed: () => context.go(
                                '/missions/${c.replicaBooking?.missionId ?? c.replica!["missionId"]}?bookingId=${Uri.encodeQueryComponent(c.replicaBooking?.id ?? c.replica!["bookingId"] as String)}',
                              ),
                              child: const Text('Apri missione prenotata'),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _xp(XpLedger ledger) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Saldo XP dal server: ${ledger.balance}',
          key: const ValueKey('xp-balance'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'XP e punti fantasy sono separati. Nessuna promozione automatica.',
        ),
        for (final e in ledger.items)
          Text(
            '+${e.amount} · osservazione ${e.observationId} · ${e.awardedAt.toIso8601String()}${e.replicationRequestId == null ? "" : " · replica richiesta"}',
          ),
      ],
    ),
  );
}
