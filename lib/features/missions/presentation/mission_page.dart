import 'package:fanta_comune/features/cooperation/cooperation_page.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/widgets/fc_widgets.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/core/models/municipality_catalog.dart';
import '../domain/mission_models.dart';
import '../logic/mission_controller.dart';

class MissionPage extends StatefulWidget {
  const MissionPage({this.missionId, this.bookingId, super.key});
  final String? missionId, bookingId;
  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {
  final _notes = TextEditingController();
  final _measurement = TextEditingController();
  String? _notesScope;
  bool _initialized = false;
  final _form = GlobalKey<FormState>();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final c = context.read<MissionController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.missionId == null)
          c.browse();
        else
          c.open(widget.missionId!, bookingId: widget.bookingId);
      });
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    _measurement.dispose();
    super.dispose();
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} UTC';
  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
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
  Future<void> _send(MissionController c) async {
    if (!_form.currentState!.validate()) return;
    if (!await c.saveMeasurement(_measurement.text)) return;
    if (!await c.saveNotes(_notes.text)) return;
    final draft = c.draft!;
    if (!await _confirm(
      'Riepilogo osservazione',
      '${c.mission!.title}\n${draft.answer!.label}\n'
          '${draft.photos.length} prove private\n'
          'Note: ${draft.notes.isEmpty ? "Nessuna" : draft.notes}\n\n'
          'Invio alla revisione umana. XP accreditati ora: 0. '
          'La risposta e le prove inviate resteranno nella ricevuta server.',
    ))
      return;
    if (!mounted || !identical(c.draft, draft) || !c.editable) return;
    await c.send();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MissionController>(),
        m = c.mission,
        draft = c.draft;
    final scope = draft?.scope.join('|');
    if (_notesScope != scope) {
      _notesScope = scope;
      _notes.text = draft?.notes ?? '';
      _measurement.text = draft?.measurementValue?.toString() ?? '';
      if (draft?.submitBody?['measurement'] != null)
        _measurement.text = missionObject(
          draft!.submitBody!['measurement'],
        )['value'].toString();
    }
    if (c.uncertain && draft?.submitBody?['measurement'] != null) {
      final value = missionObject(
        draft!.submitBody!['measurement'],
      )['value'].toString();
      if (_measurement.text != value) _measurement.text = value;
    }
    final busy = c.busy;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.missionId == null ? 'Missioni locali' : 'Dettaglio missione',
        ),
        actions: [
          IconButton(
            tooltip: 'Catalogo missioni',
            onPressed: () => context.go('/missions'),
            icon: const Icon(Icons.list_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: 800,
          child: SingleChildScrollView(
            key: const ValueKey('mission-scroll'),
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FcPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Laboratorio sintetico',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Missioni e immagini esclusivamente sintetiche. Nessuna raccolta sul territorio, nessuna geolocalizzazione richiesta. Una bozza offline non conferma prenotazione o invio.',
                      ),
                      Text(
                        'Le prove restano private. Il riconoscimento dichiarato è 10 XP dopo validazione umana; nessun accredito in questa fase.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (busy)
                  const LinearProgressIndicator(
                    semanticsLabel: 'Operazione missione in corso',
                  ),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        c.error!,
                        key: const ValueKey('mission-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                if (widget.missionId == null) ...[
                  Text(
                    'Comune: ${MunicipalityCatalog.displayNameFromId(c.repository.municipalityId)}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: busy ? null : () => c.browse(),
                        child: const Text('Tutte le zone'),
                      ),
                      for (final zone in c.catalog.map((m) => m.zoneId).toSet())
                        OutlinedButton(
                          onPressed: busy ? null : () => c.browse(zone: zone),
                          child: Text('Zona: $zone'),
                        ),
                    ],
                  ),
                  for (final item in c.catalog)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: FcPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              item.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(item.area),
                            Text(
                              '${item.durationMinutes} minuti · ${item.availableSlots} posti · ${item.rewardXp} XP dopo validazione',
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () =>
                                  context.go('/missions/${item.id}'),
                              child: const Text('Esplora missione'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!busy && c.catalog.isEmpty)
                    const Text(
                      'Nessuna missione disponibile. Aggiorna il catalogo; nessun dato demo sostituisce il server.',
                    ),
                  TextButton(
                    onPressed: busy ? null : () => c.browse(zone: c.zoneId),
                    child: const Text('Aggiorna catalogo'),
                  ),
                ] else if (m != null) ...[
                  if (context.read<AppConfig?>()?.cooperationModeEnabled ==
                          true &&
                      m.placeId != null)
                    FollowPlaceButton(
                      m.placeId!,
                      key: ValueKey('follow-${m.placeId}'),
                    ),

                  FcPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text('Area pubblica delimitata: ${m.area}'),
                        Text('Zona: ${m.zoneId}'),
                        Text('Durata indicativa: ${m.durationMinutes} minuti'),
                        Text(
                          'Finestra server: ${_date(m.startsAt)} – ${_date(m.endsAt)}',
                        ),
                        Text('Posti mostrati dal server: ${m.availableSlots}'),
                        const SizedBox(height: 12),
                        Text(
                          'Protocollo ${m.protocolId} · ${m.protocolVersion}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final instruction in m.instructions)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(instruction),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Prove richieste: almeno ${m.minPhotos} fotografie private per nessuna criticità o rifiuti visibili. Nessuna foto obbligatoria per non osservabile o non so.',
                        ),
                        for (final point in m.photoPoints)
                          Text('Punto ripetibile: $point'),
                        const SizedBox(height: 8),
                        const Text(
                          'Se l’area non è accessibile o presenta rischi, rinuncia senza penalità. Non entrare in aree private né intervenire sui rifiuti.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!c.accountReady)
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () => context.go(
                              Uri(
                                path: '/account',
                                queryParameters: {
                                  'returnTo':
                                      '/missions/${m.id}${widget.bookingId == null ? "" : "?bookingId=${Uri.encodeQueryComponent(widget.bookingId!)}"}',
                                },
                              ).toString(),
                            ),
                      child: const Text('Accedi per prenotare'),
                    )
                  else if (c.booking == null)
                    FilledButton(
                      onPressed: busy ? null : c.reserve,
                      child: const Text('Prenota: conferma dal server'),
                    )
                  else ...[
                    FcPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Prenotazione: ${switch (c.booking!.status) {
                              'active' => 'confermata',
                              'released' => 'rinunciata',
                              'expired' => 'scaduta',
                              'submitted' => 'osservazione inviata',
                              _ => c.booking!.status,
                            }}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            'Scadenza server: ${_date(c.booking!.expiresAt)}',
                          ),
                          if (c.booking!.status == 'active')
                            OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      if (await _confirm(
                                        'Rinunciare alla missione?',
                                        'Il posto verrà liberato dopo conferma server. Nessuna penalità; la bozza resta conservata.',
                                      ))
                                        await c.release();
                                    },
                              child: const Text('Rinuncia senza penalità'),
                            ),
                        ],
                      ),
                    ),
                    if (draft != null && c.receipt == null) ...[
                      const SizedBox(height: 16),
                      FcPanel(
                        child: Form(
                          key: _form,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Questionario breve',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Text(
                                'Osservazione autonoma: non determina un esito fantasy.',
                              ),
                              for (final answer in MissionAnswer.values)
                                Material(
                                  color: Colors.transparent,
                                  child: RadioListTile<MissionAnswer>(
                                    title: Text(answer.label),
                                    value: answer,
                                    groupValue: draft.answer,
                                    onChanged: busy || !c.editable
                                        ? null
                                        : (value) => c.saveAnswer(value!),
                                  ),
                                ),
                              if (m.measurementDefinition
                                  case final definition?) ...[
                                Text(
                                  '${definition.indicator} · ${definition.unit}',
                                ),
                                if (definition.requiresValue(draft.answer))
                                  TextFormField(
                                    key: const ValueKey('mission-measurement'),
                                    controller: _measurement,
                                    readOnly: !c.editable || c.busy,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Misura (${definition.unit})',
                                      helperText:
                                          'Da ${definition.minValue} a ${definition.maxValue}${definition.integerOnly ? " · interi" : ""}',
                                    ),
                                    validator: definition.validate,
                                  )
                                else
                                  const Text(
                                    'Non osservabile / non so: nessuna misura numerica, nessuno zero implicito.',
                                  ),
                              ],
                              TextFormField(
                                key: const ValueKey('mission-notes'),
                                controller: _notes,
                                enabled: !busy && c.editable,
                                maxLines: 3,
                                maxLength: 1000,
                                decoration: const InputDecoration(
                                  labelText: 'Note facoltative',
                                  helperText:
                                      'Salva la bozza prima di uscire. Nessun dato personale.',
                                ),
                                validator: (value) =>
                                    (value ?? '').length <= 1000
                                    ? null
                                    : 'Massimo 1000 caratteri.',
                              ),
                              OutlinedButton(
                                onPressed: busy || !c.editable
                                    ? null
                                    : () async {
                                        if (_form.currentState!.validate()) {
                                          await c.saveMeasurement(
                                            _measurement.text,
                                          );
                                          await c.saveNotes(_notes.text);
                                        }
                                      },
                                child: const Text('Salva bozza offline'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FcPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Prove private (${draft.photos.length}/3)',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const Text(
                              'Solo immagini sintetiche PNG/JPEG: originale massimo 2 MB, normalizzazione PNG fino a 1280 px/256 KB. Metadati eliminati; GPS non acquisito. Archivio locale: tre bozze, tre prove ciascuna.',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: busy || !c.editable
                                      ? null
                                      : () => c.addPhoto(camera: true),
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: const Text('Acquisisci prova'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: busy || !c.editable
                                      ? null
                                      : () => c.addPhoto(camera: false),
                                  icon: const Icon(Icons.image_outlined),
                                  label: const Text('Scegli file sintetico'),
                                ),
                              ],
                            ),
                            for (final photo in draft.photos)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Image.memory(
                                      photo.bytes,
                                      height: 160,
                                      fit: BoxFit.contain,
                                      semanticLabel:
                                          'Anteprima prova sintetica privata',
                                    ),
                                    Text(
                                      photo.uploadId == null
                                          ? 'Salvata sul dispositivo'
                                          : 'Upload recuperabile dal server',
                                    ),
                                    TextButton(
                                      onPressed: busy || !c.editable
                                          ? null
                                          : () => c.removePhoto(photo.id),
                                      child: const Text('Rimuovi questa prova'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (draft.rejectionCode != null)
                        Text(
                          'Invio rifiutato dal server (${draft.rejectionCode}) e ricevuta non trovata. La bozza originale resta conservata: puoi rimuoverla esplicitamente.',
                        ),
                      if (c.uncertain) ...[
                        const Text(
                          'Invio da verificare. La richiesta originale è conservata: non modificare né rimuovere questa bozza.',
                        ),
                        OutlinedButton(
                          onPressed: busy ? null : c.recover,
                          child: const Text('Recupera ricevuta'),
                        ),
                        FilledButton(
                          onPressed: busy ? null : c.send,
                          child: const Text('Ritenta lo stesso invio'),
                        ),
                      ] else
                        FilledButton(
                          onPressed:
                              busy ||
                                  !c.editable ||
                                  draft.answer == null ||
                                  ([
                                        MissionAnswer.noIssue,
                                        MissionAnswer.visibleWaste,
                                      ].contains(draft.answer) &&
                                      draft.photos.length < m.minPhotos)
                              ? null
                              : () => _send(c),
                          child: const Text('Invia per revisione umana'),
                        ),
                    ],
                    if (c.receipt != null)
                      FcPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ricevuta server',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text('Codice: ${c.receipt!.id}'),
                            Text('Accettata: ${_date(c.receipt!.submittedAt)}'),
                            Text('Risposta: ${c.receipt!.answer.label}'),
                            if (c.receipt!.measurement case final measurement?)
                              Text(
                                'Misura ricevuta: ${measurement.value} ${measurement.unit} · ${measurement.indicator} · protocollo ${measurement.protocolVersion}',
                              ),
                            const Text(
                              'In attesa di revisione umana. Nessuna validazione automatica.',
                            ),
                            Text('XP accreditati: ${c.receipt!.xpAwarded}'),
                            if (context.read<AppConfig?>()?.reviewModeEnabled ==
                                true)
                              TextButton(
                                onPressed: () => context.go(
                                  '/observations/${c.receipt!.id}',
                                ),
                                child: const Text(
                                  'Consulta stato corrente e integrazioni',
                                ),
                              ),
                            Text(
                              'Protocollo versione ${c.receipt!.protocolVersion} · finestra ${c.receipt!.windowId}',
                            ),
                            Text(
                              'Prove nella ricevuta: ${c.receipt!.proofs.length}',
                            ),
                            for (final proof in c.receipt!.proofs)
                              Text(
                                '${proof.id} · PNG ${proof.width}×${proof.height} · ${proof.sizeBytes} byte',
                              ),
                          ],
                        ),
                      ),
                    if (draft != null && !c.uncertain)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (await _confirm(
                                  'Rimuovere la bozza locale?',
                                  'Le prove locali verranno eliminate. Una ricevuta già confermata resta sul server. Rimuovi la bozza solo dopo aver rinunciato o concluso la missione.',
                                ))
                                  await c.discard();
                              },
                        child: const Text('Rimuovi esplicitamente la bozza'),
                      ),
                  ],
                  for (final archive in c.archives)
                    TextButton(
                      onPressed: busy ? null : () => c.openArchive(archive),
                      child: Text(
                        'Bozza conservata: finestra ${archive.scope.last}',
                      ),
                    ),
                  TextButton(
                    onPressed: busy ? null : () => c.open(m.id),
                    child: const Text('Aggiorna dal server'),
                  ),
                ] else if (!busy)
                  TextButton(
                    onPressed: () =>
                        c.open(widget.missionId!, bookingId: widget.bookingId),
                    child: const Text('Riprova dettaglio'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
