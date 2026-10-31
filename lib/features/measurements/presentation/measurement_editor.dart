import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fanta_comune/core/widgets/max_width_container.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import '../domain/measurement_models.dart';
import '../logic/measurement_controller.dart';

/// Structured forms use authorized registry metadata. No client trust switches.
class MeasurementEditor extends StatefulWidget {
  const MeasurementEditor({required this.action, this.entity, super.key});
  final String action;
  final Map<String, dynamic>? entity;
  @override
  State<MeasurementEditor> createState() => _MeasurementEditorState();
}

class _MeasurementEditorState extends State<MeasurementEditor> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _text = {};
  final Map<String, String?> _choices = {};
  final Map<String, Set<String>> _many = {};
  final Map<String, bool> _flags = {};
  bool _initialized = false, _loading = true;
  Map<String, dynamic>? _pending;
  List<String> _route = const [];
  String get action => widget.action;
  Map<String, dynamic> get entity => widget.entity ?? const {};
  bool get evidence => ['evaluation', 'correction'].contains(action);
  bool get verdict => ['publication', 'correction'].contains(action);
  String get title => switch (action) {
    'problem' => 'Pubblica problema e baseline',
    'protocol' => 'Pubblica protocollo prelock',
    'intervention' => 'Intervento e problemi collegati',
    'evaluation' => 'Bozza di valutazione',
    'publication' => 'Pubblica valutazione motivata',
    'correction' => 'Rettifica pubblicata',
    'rejectAppeal' => 'Rifiuta contestazione',
    _ => 'Misurazioni',
  };
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _route = switch (action) {
      'problem' => ['problems'],
      'protocol' => ['problems', entity['id'] as String, 'protocol-versions'],
      'intervention' => [
        'interventions',
        if (widget.entity != null) ...[entity['id'] as String, 'updates'],
      ],
      'evaluation' => [
        'evaluations',
        if (widget.entity != null) ...[entity['id'] as String, 'draft-updates'],
      ],
      'publication' => ['evaluations', entity['id'] as String, 'publications'],
      'correction' => ['evaluations', entity['id'] as String, 'corrections'],
      'rejectAppeal' => [
        'evaluations',
        entity['evaluationId'] as String,
        'appeals',
        entity['id'] as String,
        'resolutions',
      ],
      _ => throw StateError('Azione sconosciuta'),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = context.read<MeasurementController>();
      try {
        final p = await c.repository.pending(_route);
        if (!mounted) return;
        setState(() {
          _pending = p;
          _loading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _loading = false);
      }
    });
  }

  dynamic initial(String key) =>
      _pending?[key] ??
      (key == 'sourceId' && _pending?['baseline'] is Map
          ? _pending!['baseline']['sourceId']
          : null) ??
      entity[key];
  TextEditingController controller(String key, {Object? value}) =>
      _text.putIfAbsent(
        key,
        () => TextEditingController(
          text: (value ?? initial(key))?.toString() ?? '',
        ),
      );
  Widget text(
    String key,
    String label, {
    bool number = false,
    bool date = false,
    bool optional = false,
    int lines = 1,
    Object? value,
    int max = 2000,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller(key, value: value),
      readOnly: _pending != null || context.watch<MeasurementController>().busy,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : date
          ? TextInputType.datetime
          : TextInputType.multiline,
      maxLines: lines,
      maxLength: number
          ? 24
          : date
          ? 40
          : max,
      decoration: InputDecoration(
        labelText: label,
        helperText: date ? 'Data UTC, ad esempio 2026-10-16T10:00:00Z' : null,
      ),
      validator: (v) {
        if (optional && (v ?? '').trim().isEmpty) return null;
        if ((v ?? '').trim().isEmpty) return 'Campo obbligatorio';
        if (number) {
          try {
            measurementNumber(num.tryParse(v!.replaceAll(',', '.')));
          } catch (_) {
            return 'Inserisci un numero finito tra -1e9 e 1e9';
          }
        }
        if (date) {
          try {
            missionDate({'v': v}, 'v');
          } catch (_) {
            return 'Inserisci una data con fuso orario';
          }
        }
        return null;
      },
    ),
  );
  Widget choice(
    String key,
    String label,
    List<MapEntry<String, String>> options, {
    bool optional = false,
  }) {
    _choices.putIfAbsent(key, () {
      final value = initial(key)?.toString();
      return options.any((o) => o.key == value) ? value : null;
    });
    final selected = _choices[key];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: options.any((e) => e.key == selected) ? selected : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (optional)
            const DropdownMenuItem(value: '', child: Text('Nessuno')),
          for (final o in options)
            DropdownMenuItem(
              value: o.key,
              child: Text(o.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged:
            _pending != null || context.watch<MeasurementController>().busy
            ? null
            : (v) => setState(() => _choices[key] = v),
        validator: (v) =>
            !optional && (v ?? '').isEmpty ? 'Seleziona un valore' : null,
      ),
    );
  }

  Widget multi(String key, String label, List<Map<String, dynamic>> options) {
    _many.putIfAbsent(
      key,
      () => Set<String>.from((initial(key) as List?) ?? const []),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          if (options.isEmpty)
            const Text('Nessun record autorizzato disponibile.'),
          for (final o in options)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text((o['label'] ?? o['title'] ?? o['id']).toString()),
              subtitle: Text(
                [
                  o['value'],
                  o['unit'],
                  o['measuredAt'],
                  o['status'],
                ].where((v) => v != null).join(' · '),
              ),
              value: _many[key]!.contains(o['id']),
              onChanged:
                  _pending != null ||
                      context.watch<MeasurementController>().busy
                  ? null
                  : (v) => setState(() {
                      if (v == true)
                        _many[key]!.add(o['id'] as String);
                      else
                        _many[key]!.remove(o['id']);
                    }),
            ),
        ],
      ),
    );
  }

  Widget flag(String key, String label, {bool defaultValue = false}) {
    _flags.putIfAbsent(key, () => initial(key) as bool? ?? defaultValue);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: _flags[key]!,
      onChanged: _pending != null || context.watch<MeasurementController>().busy
          ? null
          : (v) => setState(() => _flags[key] = v),
    );
  }

  String str(String key) => _text[key]!.text.trim();
  num? number(String key) =>
      str(key).isEmpty ? null : num.parse(str(key).replaceAll(',', '.'));
  List<String> ids(String key) => _many[key]?.toList() ?? const [];
  Future<void> submit() async {
    if (_pending == null && !_form.currentState!.validate()) return;
    final c = context.read<MeasurementController>(), w = c.workspace;
    Map<String, Object?> fields;
    if (_pending != null) {
      fields = _pending!.cast<String, Object?>();
    } else {
      fields = {};
      if (action == 'problem') {
        final source = w!.sources.singleWhere(
          (s) => s['id'] == _choices['sourceId'],
        );
        fields = {
          'title': str('title'),
          'placeId': source['placeId'],
          'baseline': {
            'value': source['value'],
            'unit': source['unit'],
            'measuredAt': source['measuredAt'] ?? source['sourceDate'],
            'sourceId': source['id'],
          },
        };
      }
      if (action == 'intervention')
        fields = {
          'title': str('title'),
          'problemIds': ids('problemIds'),
          'status': _choices['status'],
          'temporary': _flags['temporary'],
          'expectedDurationDays': number('expectedDurationDays'),
          'sourceId': _choices['sourceId'],
          'sourceDate': str('sourceDate'),
        };
      if (action == 'protocol')
        fields = {
          'problemId': entity['id'],
          'seasonId': w!.scope.seasonId,
          'matchdayId': w.scope.matchdayId,
          'cardId': str('cardId'),
          'missionIds': str(
            'missionIds',
          ).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
          'indicator': str('indicator'),
          'unit': str('unit'),
          'threshold': number('threshold'),
          'lowerIsBetter': _flags['lowerIsBetter'],
          'instructions': str(
            'instructions',
          ).split('\n').where((s) => s.trim().isNotEmpty).toList(),
          'observationStartsAt': str('observationStartsAt'),
          'observationEndsAt': str('observationEndsAt'),
          'declaredDeadline': str('declaredDeadline'),
          if (str('missionIds').isNotEmpty)
            'measurementDefinition': {
              'minValue': number('minValue'),
              'maxValue': number('maxValue'),
              'integerOnly': _flags['integerOnly'],
            },
        };
      if (evidence) {
        fields = {
          'afterValue': number('afterValue'),
          'measuredAt': str('measuredAt').isEmpty ? null : str('measuredAt'),
          'sourceIds': ids('sourceIds'),
          'approvedObservationIds': ids('approvedObservationIds'),
          'interventionIds': ids('interventionIds'),
          'rationale': str('rationale'),
        };
        if (action == 'evaluation' && widget.entity == null) {
          final p = w!.protocols.singleWhere(
            (p) => p['id'] == _choices['protocolId'],
          );
          fields.addAll({
            'protocolId': p['id'],
            'protocolVersion': p['version'],
          });
        }
      }
      if (verdict) {
        fields.addAll({
          'disposition': _choices['disposition'],
          'observed': _choices['disposition'] == 'undeterminable'
              ? null
              : _choices['observed'],
          'rationale': str('rationale'),
          'undeterminableReason': _choices['disposition'] == 'undeterminable'
              ? _choices['undeterminableReason']
              : null,
        });
        if (action == 'correction') {
          fields['appealId'] = entity['appealId'];
          if ((_choices['protocolId'] ?? '').isNotEmpty) {
            final protocol = w!.protocols.singleWhere(
              (p) => p['id'] == _choices['protocolId'],
            );
            fields.addAll({
              'protocolId': protocol['id'],
              'protocolVersion': protocol['version'],
            });
          }
        }
      }
      if (action == 'rejectAppeal')
        fields = {'decision': 'reject', 'reason': str('reason')};
      if (widget.entity != null)
        fields['expectedRevision'] = entity['revision'];
    }
    if (await c.command(_route, fields)) {
      if (mounted) Navigator.pop(context, true);
    } else {
      final p = await c.repository.pending(_route);
      if (!mounted) return;
      setState(() {
        _pending = p;
        if (p != null) {
          for (final t in _text.entries) {
            if (p[t.key] != null) t.value.text = p[t.key].toString();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    for (final t in _text.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MeasurementController>(), w = c.workspace;
    final sources = w?.sources ?? const <Map<String, dynamic>>[];
    if (_loading)
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: MaxWidthContainer(
          maxWidth: 800,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loading || c.busy) const LinearProgressIndicator(),
                  if (c.error != null)
                    Semantics(liveRegion: true, child: Text(c.error!)),
                  if (_pending != null)
                    const Text(
                      'Invio incerto: campi bloccati sul contenuto originale. Recupera la stessa richiesta.',
                    ),
                  if (_pending?['baseline'] case final Map baseline)
                    Text(
                      'Baseline inviata: ${baseline['value']} ${baseline['unit']} · ${baseline['measuredAt']} · fonte ${baseline['sourceId']}',
                    ),
                  if (_pending?['sourceIds'] case final List sources)
                    Text(
                      'Fonti della richiesta originale: ${sources.join(', ')}',
                    ),
                  if (_pending?['approvedObservationIds']
                      case final List observations)
                    Text(
                      'Misure approvate della richiesta originale: ${observations.join(', ')}',
                    ),
                  if (action == 'problem' || action == 'intervention')
                    text('title', 'Titolo', max: 200),
                  if (action == 'problem' || action == 'intervention')
                    choice('sourceId', 'Fonte documentale autorizzata', [
                      for (final s in sources)
                        MapEntry(
                          s['id'] as String,
                          '${s['label']} · ${s['value']} ${s['unit']}',
                        ),
                    ]),
                  if (action == 'intervention') ...[
                    multi(
                      'problemIds',
                      'Problemi collegati (molti a molti)',
                      w?.problems ?? const [],
                    ),
                    choice('status', 'Stato', [
                      for (final s in [
                        'proposed',
                        'started',
                        'completed',
                        'suspended',
                      ])
                        MapEntry(s, s),
                    ]),
                    flag('temporary', 'Intervento temporaneo'),
                    text(
                      'expectedDurationDays',
                      'Durata attesa in giorni (non prova il beneficio)',
                      number: true,
                      optional: true,
                    ),
                    text('sourceDate', 'Data della fonte', date: true),
                  ],
                  if (action == 'protocol') ...[
                    const Text(
                      'Il server consente la pubblicazione solo prima del lock. Le missioni devono essere compatibili, non iniziate e senza prenotazioni.',
                    ),
                    text('cardId', 'ID carta della giornata', max: 128),
                    text(
                      'missionIds',
                      'ID missioni compatibili, separati da virgola',
                      optional: true,
                      max: 2600,
                    ),
                    text('indicator', 'Indicatore', max: 128),
                    text('unit', 'Unità', max: 64),
                    text(
                      'threshold',
                      'Tolleranza (uguaglianza = stabile)',
                      number: true,
                    ),
                    flag(
                      'lowerIsBetter',
                      'Valori inferiori indicano miglioramento',
                    ),
                    text(
                      'instructions',
                      'Istruzioni (una per riga)',
                      lines: 4,
                      max: 20000,
                    ),
                    text(
                      'observationStartsAt',
                      'Inizio osservazione',
                      date: true,
                    ),
                    text('observationEndsAt', 'Fine osservazione', date: true),
                    text(
                      'declaredDeadline',
                      'Termine pubblicato di valutazione',
                      date: true,
                    ),
                    text(
                      'minValue',
                      'Minimo misura (per missioni quantitative)',
                      number: true,
                      optional: true,
                    ),
                    text(
                      'maxValue',
                      'Massimo misura (per missioni quantitative)',
                      number: true,
                      optional: true,
                    ),
                    flag('integerOnly', 'Misure intere'),
                  ],
                  if (action == 'correction')
                    choice(
                      'protocolId',
                      'Protocollo per rettifica (facoltativo)',
                      [
                        for (final p
                            in w?.protocols ?? const <Map<String, dynamic>>[])
                          MapEntry(
                            p['id'] as String,
                            '${p['indicator']} · versione ${p['version']}',
                          ),
                      ],
                      optional: true,
                    ),
                  if (evidence) ...[
                    if (action == 'evaluation' && widget.entity == null)
                      choice('protocolId', 'Protocollo pubblicato', [
                        for (final p
                            in w?.protocols ?? const <Map<String, dynamic>>[])
                          MapEntry(
                            p['id'] as String,
                            '${p['indicator']} · versione ${p['version']}',
                          ),
                      ]),
                    text(
                      'afterValue',
                      'Valore dopo l’intervento',
                      number: true,
                      optional: true,
                    ),
                    text(
                      'measuredAt',
                      'Data della misura',
                      date: true,
                      optional: true,
                    ),
                    multi(
                      'sourceIds',
                      'Fonti documentali pertinenti autorizzate',
                      sources,
                    ),
                    multi(
                      'approvedObservationIds',
                      'Misure approvate indipendenti',
                      w?.approvedObservations ?? const [],
                    ),
                    multi(
                      'interventionIds',
                      'Interventi collegati',
                      w?.interventions ?? const [],
                    ),
                    const Text(
                      'Documento pertinente oppure almeno due misure quantitative indipendenti approvate. Considera tutte le prove discordanti disponibili: la maggioranza non determina l’esito.',
                    ),
                  ],
                  if (verdict) ...[
                    choice('disposition', 'Disposizione', [
                      const MapEntry('determinate', 'Determinabile'),
                      const MapEntry('undeterminable', 'Non determinabile'),
                    ]),
                    if (_choices['disposition'] == 'undeterminable')
                      choice('undeterminableReason', 'Motivo', [
                        for (final s in undeterminableReasons)
                          MapEntry(s, measurementReason(s)),
                      ])
                    else
                      choice('observed', 'Direzione dal confronto numerico', [
                        const MapEntry('improves', 'Migliora'),
                        const MapEntry('stable', 'Stabile'),
                        const MapEntry('worsens', 'Peggiora'),
                      ]),
                  ],
                  if (evidence || verdict)
                    text('rationale', 'Motivazione pubblicabile', lines: 5),
                  if (action == 'rejectAppeal')
                    text('reason', 'Motivo privato del rifiuto', lines: 4),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: c.busy || _loading ? null : submit,
                    child: Text(
                      _pending != null ? 'Recupera richiesta originale' : title,
                    ),
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
