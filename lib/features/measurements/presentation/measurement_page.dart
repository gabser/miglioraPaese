import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/features/cooperation/cooperation_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import '../domain/measurement_models.dart';
import '../logic/measurement_controller.dart';
import 'measurement_editor.dart';

class MeasurementPage extends StatefulWidget {
  const MeasurementPage({this.evaluationId, this.operator = false, super.key});
  final String? evaluationId;
  final bool operator;
  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage> {
  bool _initialized = false;
  final _season = TextEditingController(),
      _day = TextEditingController(),
      _appeal = TextEditingController(),
      _appealId = TextEditingController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  @override
  void didUpdateWidget(MeasurementPage old) {
    super.didUpdateWidget(old);
    if (old.evaluationId != widget.evaluationId ||
        old.operator != widget.operator)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
  }

  void _load() {
    final c = context.read<MeasurementController>();
    if (widget.evaluationId != null) {
      if (widget.operator)
        c.openDraft(widget.evaluationId!);
      else
        c.open(widget.evaluationId!);
    } else if (widget.operator)
      c.loadWorkspace();
    else
      c.browse();
  }

  @override
  void dispose() {
    for (final t in [_season, _day, _appeal, _appealId]) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _edit(String action, {Map<String, dynamic>? entity}) async {
    final c = context.read<MeasurementController>();
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: c,
          child: MeasurementEditor(action: action, entity: entity),
        ),
      ),
    );
    if (done == true && mounted) _load();
  }

  Widget _evaluation(EvaluationPublished e, {bool link = true}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (context.read<AppConfig?>()?.cooperationModeEnabled == true &&
              e.placeId != null)
            FollowPlaceButton(e.placeId!),
          Text(e.label, style: Theme.of(context).textTheme.titleLarge),
          Text(
            'Versione ${e.version} · revisione ${e.revision} · ${e.data['publishedAt']}',
          ),
          Text(
            'Baseline: ${e.data['baselineValue'] ?? "non disponibile"} ${e.data['unit']} · dopo: ${e.data['afterValue'] ?? "non disponibile"}',
          ),
          if (e.disposition == OutcomeDisposition.undeterminable)
            Text(measurementReason(e.data['undeterminableReason'] as String?)),
          Text(e.data['rationale'] as String),
          for (final s in e.sources)
            Text('Fonte: ${s['label']} · ${s['sourceDate']}'),
          if (e.data['supersedesVersion'] != null)
            Text('Rettifica della versione ${e.data['supersedesVersion']}'),
          if (link)
            TextButton(
              onPressed: () => context.go('/measurements/evaluations/${e.id}'),
              child: const Text('Consulta valutazione e storico'),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = context.watch<MeasurementController>(),
        o = c.overview,
        w = c.workspace,
        current = c.current;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.operator ? 'Responsabile esiti' : 'Misurazioni ed esiti',
        ),
        actions: [
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: c.busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Misurazioni pubbliche',
            onPressed: () => context.go('/measurements'),
            icon: const Icon(Icons.public),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: 960,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (c.busy) const LinearProgressIndicator(),
                if (c.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(c.error!),
                      ),
                    ),
                  ),
                if (widget.evaluationId == null) ...[
                  Text('Comune: ${c.repository.municipalityId}'),
                  Text(
                    'Stagione: ${c.repository.seasonId ?? "risoluzione server"} · giornata: ${c.repository.matchdayId ?? "risoluzione server"}',
                  ),
                  ExpansionTile(
                    title: const Text('Consulta un altro periodo'),
                    children: [
                      TextField(
                        controller: _season,
                        decoration: const InputDecoration(
                          labelText: 'ID stagione pubblicata',
                        ),
                      ),
                      TextField(
                        controller: _day,
                        decoration: const InputDecoration(
                          labelText: 'ID giornata pubblicata',
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () {
                                    c.selectScope(null, null);
                                    _load();
                                  },
                            child: const Text('Periodo corrente'),
                          ),
                          FilledButton(
                            onPressed: c.busy
                                ? null
                                : () {
                                    if (_season.text.trim().isNotEmpty &&
                                        _day.text.trim().isNotEmpty) {
                                      c.selectScope(
                                        _season.text.trim(),
                                        _day.text.trim(),
                                      );
                                      _load();
                                    }
                                  },
                            child: const Text('Consulta periodo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                if (!widget.operator &&
                    widget.evaluationId == null &&
                    o != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Copertura',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            '${o.coverage.evaluableCards}/${o.coverage.expectedCards} carte valutabili · ${o.coverage.closedUndeterminableCards} non determinabili',
                          ),
                          Text(
                            '${o.coverage.validatedPlaceWindows}/${o.coverage.expectedPlaceWindows} unità luogo/finestra validate',
                          ),
                          for (final r in o.coverage.reasons)
                            Text(
                              '${measurementReason(r['code'] as String)}: ${r['count']}',
                            ),
                        ],
                      ),
                    ),
                  ),
                  for (final p in o.problems)
                    Card(
                      child: ListTile(
                        title: Text(p['title'] as String),
                        subtitle: Text(
                          'Baseline: ${missionObject(p['baseline'])['value']} ${missionObject(p['baseline'])['unit']}',
                        ),
                      ),
                    ),
                  for (final p in o.protocols)
                    ExpansionTile(
                      title: Text(
                        'Protocollo ${p['indicator']} · versione ${p['version']}',
                      ),
                      children: [
                        ListTile(
                          title: Text(
                            '${p['unit']} · tolleranza ${p['threshold']}',
                          ),
                          subtitle: Text(
                            'Una differenza assoluta fino alla soglia inclusa è stabile.\n${(p['instructions'] as List).join("\n")}\nTermine: ${p['declaredDeadline']}',
                          ),
                        ),
                      ],
                    ),
                  for (final i in o.interventions)
                    Card(
                      child: ListTile(
                        title: Text(i['title'] as String),
                        subtitle: Text(
                          '${i['status']} · ${i['temporary'] == true ? "temporaneo" : "durata non temporanea dichiarata"}\nDurata attesa: ${i['expectedDurationDays'] ?? "non indicata"} giorni. Il completamento non prova un beneficio.',
                        ),
                      ),
                    ),
                  for (final e in o.evaluations) _evaluation(e),
                  if (o.evaluations.isEmpty)
                    const Text(
                      'Nessuna valutazione pubblicata per questo periodo.',
                    ),
                  OutlinedButton(
                    onPressed: () => context.go('/measurements/workspace'),
                    child: const Text('Area responsabile esiti'),
                  ),
                ],
                if (widget.operator && widget.evaluationId == null) ...[
                  if (!c.busy && !c.supervisor)
                    const Text(
                      'È richiesto il ruolo responsabile esiti per questo Comune. Le autorizzazioni sono verificate dal server.',
                    ),
                  if (w != null) ...[
                    const Text(
                      'Valutazione umana: qualità, indipendenza, tempi e confrontabilità. Una fonte documentale autorizzata pertinente oppure almeno due misure indipendenti approvate. Nessuna maggioranza automatica.',
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: c.busy ? null : () => _edit('problem'),
                          child: const Text('Pubblica problema'),
                        ),
                        OutlinedButton(
                          onPressed: c.busy
                              ? null
                              : () => _edit('intervention'),
                          child: const Text('Nuovo intervento'),
                        ),
                        OutlinedButton(
                          onPressed: c.busy ? null : () => _edit('evaluation'),
                          child: const Text('Nuova valutazione'),
                        ),
                      ],
                    ),
                    for (final p in w.problems)
                      Card(
                        child: ListTile(
                          title: Text(p['title'] as String),
                          subtitle: Text(
                            'Baseline: ${missionObject(p['baseline'])['value']}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Pubblica protocollo prima del lock',
                            onPressed: c.busy
                                ? null
                                : () => _edit('protocol', entity: p),
                            icon: const Icon(Icons.rule),
                          ),
                        ),
                      ),
                    for (final i in w.interventions)
                      Card(
                        child: ListTile(
                          title: Text(i['title'] as String),
                          subtitle: Text(
                            '${i['status']} · ${(i['problemIds'] as List).length} problemi collegati',
                          ),
                          onTap: () => _edit('intervention', entity: i),
                        ),
                      ),
                    for (final d in w.evaluationDrafts)
                      Card(
                        child: ListTile(
                          title: Text('Valutazione ${d['cardId']}'),
                          subtitle: Text('Revisione ${d['revision']}'),
                          onTap: () => context.go(
                            '/measurements/workspace/evaluations/${d['id']}',
                          ),
                        ),
                      ),
                    for (final a in w.appeals)
                      Card(
                        child: ListTile(
                          title: Text('Contestazione ${a['status']}'),
                          subtitle: Text(a['reason'] as String),
                          onTap: () => context.go(
                            '/measurements/workspace/evaluations/${a['evaluationId']}',
                          ),
                        ),
                      ),
                    ExpansionTile(
                      title: const Text('Registro fonti autorizzate'),
                      children: [
                        for (final s in w.sources)
                          ListTile(
                            title: Text(s['label'] as String),
                            subtitle: Text(
                              '${s['value']} ${s['unit']} · ${s['measuredAt'] ?? s['sourceDate']}',
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
                if (widget.evaluationId != null) ...[
                  if (current != null) _evaluation(current, link: false),
                  if (current != null && !widget.operator)
                    TextButton(
                      onPressed: () => context.go(
                        '/measurements/workspace/evaluations/${current.id}',
                      ),
                      child: const Text('Apri caso come responsabile esiti'),
                    ),
                  if (c.history.isNotEmpty)
                    Text(
                      'Storico delle pubblicazioni',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  for (final e in c.history) _evaluation(e, link: false),
                  if (widget.operator && c.caseWorkspace != null) ...[
                    if (c.caseWorkspace!['draft'] case final Map draft) ...[
                      Text('Bozza: ${draft['rationale']}'),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: c.busy
                                ? null
                                : () => _edit(
                                    'evaluation',
                                    entity: Map<String, dynamic>.from(draft),
                                  ),
                            child: const Text('Modifica bozza'),
                          ),
                          FilledButton(
                            onPressed: c.busy
                                ? null
                                : () => _edit(
                                    'publication',
                                    entity: Map<String, dynamic>.from(draft),
                                  ),
                            child: const Text('Pubblica valutazione'),
                          ),
                        ],
                      ),
                    ],
                    if (current != null)
                      FilledButton(
                        onPressed: c.busy
                            ? null
                            : () => _edit('correction', entity: current.data),
                        child: const Text('Rettifica con nuove prove'),
                      ),
                    for (final a
                        in (c.caseWorkspace!['appeals'] as List? ?? []))
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Contestazione: ${a['reason']} · ${a['status']}',
                              ),
                              if (a['status'] == 'open')
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: c.busy
                                          ? null
                                          : () => _edit(
                                              'rejectAppeal',
                                              entity: missionObject(a),
                                            ),
                                      child: const Text(
                                        'Rifiuta motivatamente',
                                      ),
                                    ),
                                    if (current != null)
                                      TextButton(
                                        onPressed: c.busy
                                            ? null
                                            : () => _edit(
                                                'correction',
                                                entity: {
                                                  ...current.data,
                                                  'appealId': a['id'],
                                                },
                                              ),
                                        child: const Text(
                                          'Accogli tramite rettifica',
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    for (final observation
                        in (missionObject(
                                  c.caseWorkspace!['evidence'],
                                )['observations']
                                as List? ??
                            [])) ...[
                      Text(
                        'Misura approvata del caso: ${missionObject(observation)['measurement']}',
                      ),
                      for (final raw
                          in (missionObject(observation)['proofs'] as List? ??
                              []))
                        TextButton(
                          onPressed: c.busy
                              ? null
                              : () => c.showProof(
                                  widget.evaluationId!,
                                  MissionProof.fromJson(raw),
                                ),
                          child: const Text('Apri prova privata del caso'),
                        ),
                    ],
                    for (final publication
                        in (missionObject(
                                  c.caseWorkspace!['evidence'],
                                )['published']
                                as List? ??
                            []))
                      for (final observation
                          in (missionObject(publication)['observations']
                                  as List? ??
                              [])) ...[
                        Text(
                          'Misura approvata del caso: ${missionObject(observation)['measurement']}',
                        ),
                        for (final raw
                            in (missionObject(observation)['proofs'] as List? ??
                                []))
                          TextButton(
                            onPressed: c.busy
                                ? null
                                : () => c.showProof(
                                    widget.evaluationId!,
                                    MissionProof.fromJson(raw),
                                  ),
                            child: const Text('Apri prova privata del caso'),
                          ),
                      ],
                    if (c.preview != null) ...[
                      Image.memory(c.preview!, height: 320),
                      TextButton(
                        onPressed: c.closeProof,
                        child: const Text('Chiudi prova'),
                      ),
                    ],
                  ],
                  if (!widget.operator &&
                      current != null &&
                      !c.repository.account.hasCredentials)
                    OutlinedButton(
                      onPressed: () => context.go(
                        Uri(
                          path: '/account',
                          queryParameters: {
                            'returnTo':
                                '/measurements/evaluations/${current.id}',
                          },
                        ).toString(),
                      ),
                      child: const Text(
                        'Accedi per contestare una valutazione',
                      ),
                    ),
                  if (!widget.operator &&
                      current != null &&
                      c.repository.account.hasCredentials) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _appeal,
                      maxLength: 2000,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Motivo della contestazione (privato)',
                      ),
                    ),
                    FilledButton(
                      onPressed: c.busy
                          ? null
                          : () async {
                              if (_appeal.text.trim().isEmpty) return;
                              await c.command(
                                ['evaluations', current.id, 'appeals'],
                                {
                                  'expectedRevision': current.revision,
                                  'publishedVersion': current.version,
                                  'reason': _appeal.text.trim(),
                                },
                              );
                            },
                      child: const Text('Invia contestazione con account'),
                    ),
                    if (c.lastCommand != null)
                      SelectableText(
                        'Contestazione ${c.lastCommand!['id']} · ${c.lastCommand!['status']}',
                      ),
                    TextField(
                      controller: _appealId,
                      decoration: const InputDecoration(
                        labelText: 'ID contestazione da recuperare',
                      ),
                    ),
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () async {
                              await c.recoverAppeal(
                                current.id,
                                _appealId.text.trim(),
                              );
                            },
                      child: const Text(
                        'Recupera stato della mia contestazione',
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
