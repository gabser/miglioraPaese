import 'package:fanta_comune/features/review/data/review_repository.dart';
import '../missions/mission_test_support.dart';

Map<String, Object?> liveJson({
  String status = 'pendingReview',
  int revision = 1,
  int xp = 0,
  String municipality = 'tuglie',
  bool integration = false,
}) => {
  'id': 'observation',
  'bookingId': bookingId,
  'municipalityId': municipality,
  'missionId': missionId,
  'placeId': 'synthetic-place',
  'windowId': 'synthetic-week-1',
  'protocolVersion': 1,
  'answer': 'noIssue',
  'notes': 'Osservazione sintetica originale',
  'submittedAt': '2026-10-08T00:00:00Z',
  'status': status,
  'revision': revision,
  'assignedTo': accountId,
  'xpAwarded': xp,
  'proofs': <Object>[],
  'integrationRequest': integration
      ? {
          'id': 'integration',
          'message': 'Aggiungere prova sintetica',
          'requestedAt': '2026-10-08T00:00:00Z',
          'dueAt': '2026-10-09T00:00:00Z',
          'status': 'open',
          'revision': 2,
        }
      : null,
  'supplements': <Object>[],
  'audit': <Object>[],
};
Map<String, Object?> ledgerJson({int balance = 0}) => {
  'balance': balance,
  'items': balance == 0
      ? <Object>[]
      : [
          {
            'id': 'event',
            'observationId': 'observation',
            'placeId': 'synthetic-place',
            'windowId': 'synthetic-week-1',
            'amount': 10,
            'awardedAt': '2026-10-08T02:00:00Z',
            'ruleVersion': 1,
            'replicationRequestId': null,
          },
        ],
};
ReviewRepository reviewRepository(MissionHarness h) => ReviewRepository(
  client: h.client,
  account: h.account,
  environment: 'mission-test',
  municipality: () => h.municipalityId,
  municipalityChanges: h.municipalityChanges,
);
