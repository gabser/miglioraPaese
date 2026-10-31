import 'dart:convert';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';

const reviewStatuses = [
  'pendingReview',
  'screened',
  'needsIntegration',
  'approved',
  'rejected',
];

class ReviewCapabilities {
  ReviewCapabilities.fromJson(Object? raw) {
    final m = missionObject(raw);
    roles = missionStrings(m['roles']);
    if (m['synthetic'] != true ||
        roles.any(
          (r) => !['moderator', 'verifier', 'outcomesSupervisor'].contains(r),
        )) {
      throw const FormatException('Capacità operatore non valide.');
    }
  }
  late final List<String> roles;
  bool get moderator => roles.contains('moderator');
  bool get verifier => roles.contains('verifier');
  bool get canReview => moderator || verifier;
}

class ReviewIntegration {
  ReviewIntegration.fromJson(Object? raw) {
    final m = missionObject(raw);
    id = missionString(m, 'id');
    message = missionString(m, 'message');
    status = missionString(m, 'status');
    requestedAt = missionDate(m, 'requestedAt');
    dueAt = missionDate(m, 'dueAt');
    revision = missionInt(m, 'revision');
    if (!['open', 'answered', 'expired', 'closed'].contains(status) ||
        revision < 1)
      throw const FormatException('Integrazione non valida.');
  }
  late final String id, message, status;
  late final DateTime requestedAt, dueAt;
  late final int revision;
}

class ReviewAudit {
  ReviewAudit.fromJson(Object? raw) {
    final m = missionObject(raw);
    id = missionString(m, 'id');
    action = missionString(m, 'action');
    actorId = missionString(m, 'actorId');
    reason = m['reason'] as String? ?? '';
    at = missionDate(m, 'at');
    revision = missionInt(m, 'revision');
    if (revision < 1) throw const FormatException('Audit non valido.');
  }
  late final String id, action, actorId, reason;
  late final DateTime at;
  late final int revision;
}

class ReviewSupplement {
  ReviewSupplement.fromJson(Object? raw) {
    final m = missionObject(raw);
    id = missionString(m, 'id');
    notes = m['notes'] as String;
    submittedAt = missionDate(m, 'submittedAt');
    proofs = List<MissionProof>.unmodifiable(
      (m['proofs'] as List).map(MissionProof.fromJson),
    );
  }
  late final String id, notes;
  late final DateTime submittedAt;
  late final List<MissionProof> proofs;
}

class ObservationLive {
  ObservationLive.fromJson(Object? raw) {
    final m = missionObject(raw);
    snapshot = Map<String, Object?>.unmodifiable(
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>,
    );
    id = missionString(m, 'id');
    bookingId = missionString(m, 'bookingId');
    municipalityId = missionString(m, 'municipalityId');
    missionId = missionString(m, 'missionId');
    placeId = missionString(m, 'placeId');
    windowId = missionString(m, 'windowId');
    status = missionString(m, 'status');
    notes = m['notes'] as String;
    answer = MissionAnswer.values.byName(missionString(m, 'answer'));
    submittedAt = missionDate(m, 'submittedAt');
    assignedTo = m['assignedTo'] as String?;
    revision = missionInt(m, 'revision');
    protocolVersion = missionInt(m, 'protocolVersion');
    xpAwarded = missionInt(m, 'xpAwarded');
    if (!reviewStatuses.contains(status) ||
        revision < 1 ||
        protocolVersion < 1 ||
        ![0, 10].contains(xpAwarded))
      throw const FormatException('Stato osservazione non valido.');
    proofs = List<MissionProof>.unmodifiable(
      (m['proofs'] as List).map(MissionProof.fromJson),
    );
    integration = m['integrationRequest'] == null
        ? null
        : ReviewIntegration.fromJson(m['integrationRequest']);
    supplements = List<ReviewSupplement>.unmodifiable(
      (m['supplements'] as List).map(ReviewSupplement.fromJson),
    );
    audit = List<ReviewAudit>.unmodifiable(
      (m['audit'] as List).map(ReviewAudit.fromJson),
    );
  }
  late final String id,
      bookingId,
      municipalityId,
      missionId,
      placeId,
      windowId,
      status,
      notes;
  late final String? assignedTo;
  late final int revision, protocolVersion, xpAwarded;
  late final MissionAnswer answer;
  late final DateTime submittedAt;
  late final ReviewIntegration? integration;
  late final List<MissionProof> proofs;
  late final List<ReviewSupplement> supplements;
  late final List<ReviewAudit> audit;
  late final Map<String, Object?> snapshot;
}

class XpEvent {
  XpEvent.fromJson(Object? raw) {
    final m = missionObject(raw);
    id = missionString(m, 'id');
    observationId = missionString(m, 'observationId');
    placeId = missionString(m, 'placeId');
    windowId = missionString(m, 'windowId');
    amount = missionInt(m, 'amount');
    ruleVersion = missionInt(m, 'ruleVersion');
    awardedAt = missionDate(m, 'awardedAt');
    replicationRequestId = m['replicationRequestId'] as String?;
    if (amount != 10 || ruleVersion != 1)
      throw const FormatException('Evento XP non supportato.');
  }
  late final String id, observationId, placeId, windowId;
  late final String? replicationRequestId;
  late final int amount, ruleVersion;
  late final DateTime awardedAt;
}

class XpLedger {
  XpLedger.fromJson(Object? raw) {
    final m = missionObject(raw);
    balance = missionInt(m, 'balance');
    items = List<XpEvent>.unmodifiable(
      (m['items'] as List).map(XpEvent.fromJson),
    );
  }
  late final int balance;
  late final List<XpEvent> items;
}
