import 'package:fanta_comune/features/measurements/data/measurement_repository.dart';
import '../missions/mission_test_support.dart';
import '../review/review_test_support.dart';

Map<String, Object?> evaluationJson({
  int version = 1,
  String disposition = 'determinate',
}) => {
  'id': 'evaluation',
  'version': version,
  'revision': version + 1,
  'seasonId': 'season',
  'matchdayId': 'day',
  'cardId': 'card',
  'protocolId': 'protocol',
  'protocolVersion': 1,
  'disposition': disposition,
  'observed': disposition == 'determinate' ? 'improves' : null,
  'baselineValue': 10,
  'afterValue': disposition == 'determinate' ? 5 : null,
  'unit': 'items',
  'measuredAt': disposition == 'determinate' ? '2026-12-02T12:00:00Z' : null,
  'sources': <Object>[],
  'interventionIds': <Object>[],
  'rationale':
      'Valutazione umana sintetica motivata sulla comparabilità e qualità.',
  'undeterminableReason': disposition == 'determinate'
      ? null
      : 'contradictoryEvidence',
  'publishedAt': '2026-12-03T00:00:00Z',
  'supersedesVersion': version == 1 ? null : version - 1,
  'origin': 'human',
};
Map<String, Object?> overviewJson({
  String season = 'season',
  String municipality = 'tuglie',
}) => {
  'municipalityId': municipality,
  'seasonId': season,
  'matchdayId': 'day',
  'serverTime': '2026-12-03T00:00:00Z',
  'revision': 2,
  'problems': <Object>[],
  'protocols': <Object>[],
  'interventions': <Object>[],
  'evaluations': [evaluationJson(disposition: 'undeterminable')],
  'coverage': {
    'expectedCards': 8,
    'evaluableCards': 0,
    'closedUndeterminableCards': 1,
    'validatedPlaceWindows': 0,
    'expectedPlaceWindows': 1,
    'reasons': [
      {'code': 'contradictoryEvidence', 'count': 1},
    ],
  },
};
MeasurementRepository measurements(MissionHarness h) => MeasurementRepository(
  client: h.client,
  account: h.account,
  review: reviewRepository(h),
  environment: 'measurements-test',
  municipality: () => h.municipalityId,
  municipalityChanges: h.municipalityChanges,
);
Map<String, Object?> measurementMissionJson() {
  final m = missionJson();
  m['protocol'] = {
    ...(m['protocol'] as Map),
    'measurementDefinition': {
      'protocolId': 'measurement-protocol',
      'protocolVersion': 7,
      'indicator': 'Visible items',
      'unit': 'items',
      'minValue': 0,
      'maxValue': 100,
      'integerOnly': true,
    },
  };
  return m;
}
