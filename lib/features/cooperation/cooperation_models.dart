import 'package:fanta_comune/features/missions/domain/mission_models.dart';

class CooperativeCoverage {
  CooperativeCoverage.fromJson(Object? raw) {
    final m = missionObject(raw);
    expected = missionInt(m, 'expectedPlaceWindows');
    validated = missionInt(m, 'validatedPlaceWindows');
    final r = m['ratio'];
    if (expected < 0 ||
        validated < 0 ||
        validated > expected ||
        (expected == 0
            ? r != null
            : r is! num ||
                  !r.isFinite ||
                  (r - validated / expected).abs() > 0.000001)) {
      throw const FormatException('Copertura cooperativa incoerente.');
    }
    ratio = (r as num?)?.toDouble();
  }
  late final int expected, validated;
  late final double? ratio;
}

class CooperationProgress {
  CooperationProgress.fromJson(Object? raw) {
    final m = missionObject(raw);
    municipalityId = missionString(m, 'municipalityId');
    seasonId = missionString(m, 'seasonId');
    matchdayId = missionString(m, 'matchdayId');
    missionDate(m, 'serverTime');
    leagueId = m['leagueId'] as String?;
    coverage = CooperativeCoverage.fromJson(m['coverage']);
    municipal = m['municipalCoverage'] == null
        ? null
        : CooperativeCoverage.fromJson(m['municipalCoverage']);
    if (m['goal'] != null) {
      final goal = missionObject(m['goal']);
      missionString(goal, 'id');
      title = missionString(goal, 'title');
      if (missionInt(goal, 'version') < 1 ||
          missionInt(goal, 'expectedPlaceWindows') != coverage.expected)
        throw const FormatException('Obiettivo incoerente.');
      missionDate(goal, 'publishedAt');
    } else {
      title = null;
      if (coverage.expected != 0 || coverage.ratio != null)
        throw const FormatException('Obiettivo assente.');
    }
  }
  late final String municipalityId, seasonId, matchdayId;
  late final String? leagueId, title;
  late final CooperativeCoverage coverage;
  late final CooperativeCoverage? municipal;
}

sealed class InboxTarget {
  const InboxTarget();
  static InboxTarget fromJson(Object? raw) {
    final m = missionObject(raw);
    String id(String key) {
      final value = missionString(m, key);
      if (value.length > 160 ||
          value.trim().isEmpty ||
          value == '.' ||
          value == '..' ||
          RegExp(r'[\x00-\x1f\x7f-\x9f/\\?#%]').hasMatch(value))
        throw const FormatException('Destinazione non valida.');
      return value;
    }

    final keys = switch (m['kind']) {
      'observation' => {'kind', 'observationId'},
      'mission' => {'kind', 'missionId'},
      'evaluation' => {'kind', 'evaluationId', 'seasonId', 'matchdayId'},
      'recheck' => {'kind', 'replicationRequestId', 'missionId'},
      _ => throw const FormatException('Destinazione sconosciuta.'),
    };
    if (m.length != keys.length || !m.keys.every(keys.contains))
      throw const FormatException('Destinazione non consentita.');
    return switch (m['kind']) {
      'mission' => MissionTarget(id('missionId')),
      'observation' => ObservationTarget(id('observationId')),
      'evaluation' => EvaluationTarget(
        id('evaluationId'),
        id('seasonId'),
        id('matchdayId'),
      ),
      _ => RecheckTarget(id('replicationRequestId'), id('missionId')),
    };
  }
}

class ObservationTarget extends InboxTarget {
  const ObservationTarget(this.id);
  final String id;
}

class EvaluationTarget extends InboxTarget {
  const EvaluationTarget(this.id, this.seasonId, this.matchdayId);
  final String id, seasonId, matchdayId;
}

class RecheckTarget extends InboxTarget {
  const RecheckTarget(this.id, this.missionId);
  final String id, missionId;
}

const inboxTitles = {
  'integrationRequested': 'Integrazione richiesta',
  'observationApproved': 'Osservazione approvata',
  'observationRejected': 'Osservazione non approvata',
  'outcomePublished': 'Esito pubblicato',
  'outcomeCorrected': 'Esito rettificato',
  'recheckRequested': 'Nuovo ricontrollo richiesto',
};

class InboxMessage {
  InboxMessage.fromJson(Object? raw) {
    final m = missionObject(raw);
    id = missionString(m, 'id');
    municipalityId = missionString(m, 'municipalityId');
    type = missionString(m, 'type');
    if (!inboxTitles.containsKey(type))
      throw const FormatException('Evento sconosciuto.');
    createdAt = missionDate(m, 'createdAt');
    readAt = m['readAt'] == null ? null : missionDate(m, 'readAt');
    target = InboxTarget.fromJson(m['target']);
  }
  late final String id, municipalityId, type;
  String get title => inboxTitles[type]!;
  late final DateTime createdAt;
  late final DateTime? readAt;
  late final InboxTarget target;
}

class InboxPageData {
  InboxPageData.fromJson(Object? raw) {
    final m = missionObject(raw);
    missionDate(m, 'serverTime');
    items = List.unmodifiable((m['items'] as List).map(InboxMessage.fromJson));
    cursor = m['nextCursor'] as String?;
    unread = missionInt(m, 'unreadCount');
    if (unread < 0 || (cursor?.length ?? 0) > 2048)
      throw const FormatException('Pagina inbox non valida.');
  }
  late final List<InboxMessage> items;
  late final String? cursor;
  late final int unread;
}

class FollowedPlace {
  FollowedPlace.fromJson(Object? raw) {
    final m = missionObject(raw);
    id = missionString(m, 'placeId');
    municipalityId = missionString(m, 'municipalityId');
    name = m['displayName'] as String? ?? id;
  }
  late final String id, municipalityId, name;
}

class MissionTarget extends InboxTarget {
  const MissionTarget(this.id);
  final String id;
}
