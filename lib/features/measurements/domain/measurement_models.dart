import 'dart:convert';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';

num measurementNumber(Object? value) {
  if (value is! num || !value.isFinite || value.abs() > 1e9) {
    throw const FormatException('Misura numerica non valida.');
  }
  return value;
}

Map<String, dynamic> frozenMeasurement(Object? value) =>
    Map.unmodifiable(missionObject(jsonDecode(jsonEncode(value))));
List<Map<String, dynamic>> measurementItems(Object? value) {
  if (value is! List)
    throw const FormatException('Elenco misurazioni mancante.');
  return List.unmodifiable(value.map(frozenMeasurement));
}

class MeasurementScope {
  MeasurementScope.fromJson(Object? raw) {
    final m = missionObject(raw);
    municipalityId = missionString(m, 'municipalityId');
    seasonId = missionString(m, 'seasonId');
    matchdayId = missionString(m, 'matchdayId');
  }
  late final String municipalityId, seasonId, matchdayId;
}

class MeasurementCoverage {
  MeasurementCoverage.fromJson(Object? raw) {
    final m = missionObject(raw);
    expectedCards = missionInt(m, 'expectedCards');
    evaluableCards = missionInt(m, 'evaluableCards');
    closedUndeterminableCards = missionInt(m, 'closedUndeterminableCards');
    validatedPlaceWindows = missionInt(m, 'validatedPlaceWindows');
    expectedPlaceWindows = missionInt(m, 'expectedPlaceWindows');
    reasons = measurementItems(m['reasons']);
    for (final r in reasons) {
      missionString(r, 'code');
      missionInt(r, 'count');
    }
    if (evaluableCards + closedUndeterminableCards > expectedCards ||
        validatedPlaceWindows > expectedPlaceWindows)
      throw const FormatException('Copertura incoerente.');
  }
  late final int expectedCards,
      evaluableCards,
      closedUndeterminableCards,
      validatedPlaceWindows,
      expectedPlaceWindows;
  late final List<Map<String, dynamic>> reasons;
}

const undeterminableReasons = [
  'insufficientEvidence',
  'contradictoryEvidence',
  'incomparableEvidence',
  'missingBaseline',
  'deadlineExpired',
];
String measurementReason(String? code) => switch (code) {
  'insufficientEvidence' => 'Prove insufficienti',
  'contradictoryEvidence' => 'Prove discordanti',
  'incomparableEvidence' => 'Prove non confrontabili',
  'missingBaseline' => 'Baseline mancante',
  'deadlineExpired' => 'Termine di valutazione scaduto',
  _ => code ?? '',
};

class EvaluationPublished {
  EvaluationPublished.fromJson(Object? raw) {
    data = frozenMeasurement(raw);
    id = missionString(data, 'id');
    placeId = data['placeId'] == null ? null : missionString(data, 'placeId');
    version = missionInt(data, 'version');
    revision = missionInt(data, 'revision');
    for (final k in [
      'seasonId',
      'matchdayId',
      'cardId',

      'rationale',
      'origin',
    ]) {
      missionString(data, k);
    }
    if (data['protocolId'] != null) missionString(data, 'protocolId');
    if (data['unit'] != null) missionString(data, 'unit');
    if (data['protocolVersion'] != null) missionInt(data, 'protocolVersion');
    missionDate(data, 'publishedAt');
    final d = data['disposition'];
    if (d == 'determinate') {
      disposition = OutcomeDisposition.determinate;
      observed = CivicTrend.values.byName(missionString(data, 'observed'));
      measurementNumber(data['afterValue']);
      if (data['undeterminableReason'] != null)
        throw const FormatException('Motivo incompatibile.');
    } else if (d == 'undeterminable' &&
        data['observed'] == null &&
        undeterminableReasons.contains(data['undeterminableReason'])) {
      disposition = OutcomeDisposition.undeterminable;
      observed = null;
    } else {
      throw const FormatException('Disposizione esito non valida.');
    }
    if (data['baselineValue'] != null) measurementNumber(data['baselineValue']);
    if (data['afterValue'] != null) measurementNumber(data['afterValue']);
    if (data['measuredAt'] != null) missionDate(data, 'measuredAt');
    sources = measurementItems(data['sources']);
    for (final s in sources) {
      missionString(s, 'id');
      missionString(s, 'label');
      missionDate(s, 'sourceDate');
    }
    missionStrings(data['interventionIds']);
    if (version < 1 ||
        revision < 1 ||
        !['human', 'deadline'].contains(data['origin']))
      throw const FormatException('Versione esito non valida.');
  }
  late final String? placeId;
  late final Map<String, dynamic> data;
  late final String id;
  late final int version, revision;
  late final OutcomeDisposition disposition;
  late final CivicTrend? observed;
  late final List<Map<String, dynamic>> sources;
  String get label => disposition == OutcomeDisposition.undeterminable
      ? 'Non determinabile'
      : observed!.label;
}

class MeasurementOverview {
  MeasurementOverview.fromJson(Object? raw) {
    final m = missionObject(raw);
    scope = MeasurementScope.fromJson(m);
    revision = missionInt(m, 'revision');
    serverTime = missionDate(m, 'serverTime');
    problems = measurementItems(m['problems']);
    protocols = measurementItems(m['protocols']);
    interventions = measurementItems(m['interventions']);
    evaluations = List.unmodifiable(
      (m['evaluations'] as List).map(EvaluationPublished.fromJson),
    );
    for (final e in evaluations) {
      if (e.data['seasonId'] != scope.seasonId ||
          e.data['matchdayId'] != scope.matchdayId)
        throw const FormatException('Valutazione di un altro scope.');
    }
    coverage = MeasurementCoverage.fromJson(m['coverage']);
  }
  late final MeasurementScope scope;
  late final int revision;
  late final DateTime serverTime;
  late final List<Map<String, dynamic>> problems, protocols, interventions;
  late final List<EvaluationPublished> evaluations;
  late final MeasurementCoverage coverage;
}

class MeasurementWorkspace {
  MeasurementWorkspace.fromJson(Object? raw) {
    final m = missionObject(raw);
    scope = MeasurementScope.fromJson(m['scope']);
    revision = missionInt(m, 'revision');
    problems = measurementItems(m['problems']);
    protocols = measurementItems(m['protocols']);
    interventions = measurementItems(m['interventions']);
    evaluationDrafts = measurementItems(m['evaluationDrafts']);
    appeals = measurementItems(m['appeals']);
    sources = measurementItems(m['sources']);
    approvedObservations = measurementItems(m['approvedObservations']);
  }
  late final MeasurementScope scope;
  late final int revision;
  late final List<Map<String, dynamic>> problems,
      protocols,
      interventions,
      evaluationDrafts,
      appeals,
      sources,
      approvedObservations;
}
