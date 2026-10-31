import '../data/fantasy_api_mapper.dart';

Map<String, dynamic> object(Object? raw) => FantasyApiMapper.object(raw);
String text(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v is! String || v.isEmpty)
    throw const FormatException('Dato lega mancante.');
  return v;
}

int revision(Map<String, dynamic> m, [String key = 'revision']) {
  final v = m[key];
  if (v is! int || v < 0)
    throw const FormatException('Revisione lega non valida.');
  return v;
}

class LeagueInvitePreview {
  LeagueInvitePreview.fromJson(Object? raw) {
    final m = object(raw);
    serverTime = FantasyApiMapper.date(m['serverTime']);
    municipalityId = text(m, 'municipalityId');
    seasonId = text(m, 'seasonId');
    leagueId = text(m, 'leagueId');
    name = text(m, 'name');
    leagueRevision = revision(m, 'leagueRevision');
    expiresAt = FantasyApiMapper.date(m['expiresAt']);
    firstLocksAt = FantasyApiMapper.date(m['firstLocksAt']);
    expectedRole = text(m, 'expectedRole');
    lateJoinReason = m['lateJoinReason'] as String?;
    if (!['competitor', 'spectator'].contains(expectedRole) ||
        ![null, 'firstLockReached', 'snapshotFrozen'].contains(lateJoinReason))
      throw const FormatException('Ruolo invito non valido.');
  }
  late final String municipalityId, seasonId, leagueId, name, expectedRole;
  late final String? lateJoinReason;
  late final int leagueRevision;
  late final DateTime serverTime, expiresAt, firstLocksAt;
}

class OwnershipCandidate {
  OwnershipCandidate.fromJson(Object? raw) {
    final m = object(raw);
    memberId = text(m, 'memberId');
    pseudonym = text(m, 'pseudonym');
  }
  late final String memberId, pseudonym;
}

class OwnershipOffer {
  OwnershipOffer.fromJson(Object? raw) {
    final m = object(raw);
    id = text(m, 'id');
    targetMemberId = text(m, 'targetMemberId');
    targetPseudonym = text(m, 'targetPseudonym');
    status = text(m, 'status');
    expiresAt = FantasyApiMapper.date(m['expiresAt']);
    isTarget = m['isTarget'] as bool;
    if (![
      'pending',
      'accepted',
      'revoked',
      'expired',
      'cancelled',
    ].contains(status))
      throw const FormatException('Stato offerta non valido.');
  }
  late final String id, targetMemberId, targetPseudonym, status;
  late final DateTime expiresAt;
  late final bool isTarget;
}

class OwnershipWorkspace {
  OwnershipWorkspace.fromJson(Object? raw) {
    final m = object(raw);
    serverTime = FantasyApiMapper.date(m['serverTime']);
    seasonId = text(m, 'seasonId');
    leagueId = text(m, 'leagueId');
    leagueRevision = revision(m);
    isOwner = m['isOwner'] as bool;
    candidates = List.unmodifiable(
      (m['candidates'] as List).map(OwnershipCandidate.fromJson),
    );
    pendingOffer = m['pendingOffer'] == null
        ? null
        : OwnershipOffer.fromJson(m['pendingOffer']);
    if (!isOwner && candidates.isNotEmpty)
      throw const FormatException('Candidati riservati.');
  }
  late final String seasonId, leagueId;
  late final DateTime serverTime;
  late final int leagueRevision;
  late final bool isOwner;
  late final List<OwnershipCandidate> candidates;
  late final OwnershipOffer? pendingOffer;
}
