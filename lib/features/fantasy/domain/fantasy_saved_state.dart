import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';

/// The whole persisted payload is decoded and validated before manager state changes.
class FantasySavedState {
  FantasySavedState({
    required this.matchday,
    required List<String> squadIds,
    required List<String> starterIds,
    required this.captainId,
    required this.confirmed,
    required Map<String, CivicTrend> predictions,
    required Map<String, String> motivations,
    required List<Transfer> transfers,
    required Map<String, MatchdaySnapshot> snapshots,
    required Map<String, ReflectionAnswer> reflections,
    required Map<String, CardOutcome> revealed,
  }) : squadIds = List.unmodifiable(squadIds),
       starterIds = List.unmodifiable(starterIds),
       predictions = Map.unmodifiable(predictions),
       motivations = Map.unmodifiable(motivations),
       transfers = List.unmodifiable(transfers),
       snapshots = Map.unmodifiable(snapshots),
       reflections = Map.unmodifiable(reflections),
       revealed = Map.unmodifiable(revealed);

  final Matchday matchday;
  final List<String> squadIds;
  final List<String> starterIds;
  final String captainId;
  final bool confirmed;
  final Map<String, CivicTrend> predictions;
  final Map<String, String> motivations;
  final List<Transfer> transfers;
  final Map<String, MatchdaySnapshot> snapshots;
  final Map<String, ReflectionAnswer> reflections;
  final Map<String, CardOutcome> revealed;

  factory FantasySavedState.fromJson(
    Map<String, dynamic> json,
    Matchday initial,
  ) {
    final legacy = !json.containsKey('version');
    if (!legacy && json['version'] != 2) {
      throw const FormatException('Unknown version');
    }
    final day = legacy ? initial : dayFromJson(map(json['matchday']));
    final counts = <String, int>{};
    final transfers = (json['transfers'] as List<dynamic>? ?? []).map((raw) {
      final item = map(raw);
      final dayId = legacy ? day.id : item['matchdayId'] as String;
      final count = counts.update(dayId, (n) => n + 1, ifAbsent: () => 1);
      final expected = count <= 2 ? 0 : 4;
      if (!legacy && item['cost'] != expected) {
        throw const FormatException('Transfer penalty');
      }
      return Transfer(
        matchdayId: dayId,
        outgoingCardId: item['outgoingCardId'] as String,
        incomingCardId: item['incomingCardId'] as String,
        createdAt: DateTime.parse(item['createdAt'] as String),
        cost: expected,
      );
    }).toList();
    final snapshots = <String, MatchdaySnapshot>{};
    for (final raw
        in legacy ? <dynamic>[] : json['snapshots'] as List<dynamic>) {
      final item = map(raw);
      final snapshot = MatchdaySnapshot(
        matchday: dayFromJson(map(item['matchday'])),
        eligible: item['eligible'] as bool,
        squadIds: strings(item['squadIds']),
        starterIds: strings(item['starterIds']),
        captainId: item['captainId'] as String,
        predictions: trends(map(item['predictions'])),
        transferPenalty: item['transferPenalty'] as int,
      );
      if (snapshots.containsKey(snapshot.matchday.id)) {
        throw const FormatException('Duplicate snapshot');
      }
      snapshots[snapshot.matchday.id] = snapshot;
    }
    final revealed = <String, CardOutcome>{};
    for (final raw
        in legacy ? <dynamic>[] : json['revealed'] as List<dynamic>) {
      final item = map(raw);
      final outcome = CardOutcome(
        matchdayId: item['matchdayId'] as String,
        cardId: item['cardId'] as String,
        observed: CivicTrend.values.byName(item['observed'] as String),
        sourceLabel: item['sourceLabel'] as String,
        sourceDate: DateTime.parse(item['sourceDate'] as String),
        explanation: item['explanation'] as String,
        sourceStatus: FantasySourceStatus.values.byName(
          item['sourceStatus'] as String,
        ),
      );
      final key = resultKey(outcome.matchdayId, outcome.cardId);
      if (revealed.containsKey(key)) {
        throw const FormatException('Duplicate outcome');
      }
      revealed[key] = outcome;
    }
    return FantasySavedState(
      matchday: day,
      squadIds: strings(json['squadIds']),
      starterIds: strings(json['starterIds']),
      captainId: json['captainId'] as String,
      confirmed: json['confirmed'] as bool? ?? false,
      predictions: trends(map(json['predictions'] ?? <String, dynamic>{})),
      motivations: legacy
          ? {}
          : map(
              json['motivations'],
            ).map((key, value) => MapEntry(key, value as String)),
      transfers: transfers,
      snapshots: snapshots,
      reflections: legacy
          ? {}
          : map(json['reflections']).map(
              (key, value) => MapEntry(
                key,
                ReflectionAnswer.values.byName(value as String),
              ),
            ),
      revealed: revealed,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 2,
    'matchday': dayToJson(matchday),
    'squadIds': squadIds,
    'starterIds': starterIds,
    'captainId': captainId,
    'confirmed': confirmed,
    'predictions': predictions.map((k, v) => MapEntry(k, v.name)),
    'motivations': motivations,
    'transfers': transfers
        .map(
          (t) => {
            'matchdayId': t.matchdayId,
            'outgoingCardId': t.outgoingCardId,
            'incomingCardId': t.incomingCardId,
            'createdAt': t.createdAt.toUtc().toIso8601String(),
            'cost': t.cost,
          },
        )
        .toList(),
    'snapshots': snapshots.values
        .map(
          (s) => {
            'matchday': dayToJson(s.matchday),
            'eligible': s.eligible,
            'squadIds': s.squadIds,
            'starterIds': s.starterIds,
            'captainId': s.captainId,
            'predictions': s.predictions.map((k, v) => MapEntry(k, v.name)),
            'transferPenalty': s.transferPenalty,
          },
        )
        .toList(),
    'reflections': reflections.map((k, v) => MapEntry(k, v.name)),
    'revealed': revealed.values
        .map(
          (o) => {
            'matchdayId': o.matchdayId,
            'cardId': o.cardId,
            'observed': o.observed.name,
            'sourceLabel': o.sourceLabel,
            'sourceDate': o.sourceDate.toUtc().toIso8601String(),
            'explanation': o.explanation,
            'sourceStatus': o.sourceStatus.name,
          },
        )
        .toList(),
  };

  static String resultKey(String dayId, String cardId) => '$dayId/$cardId';
  static Map<String, dynamic> map(dynamic value) =>
      (value as Map).cast<String, dynamic>();
  static List<String> strings(dynamic value) =>
      (value as List).cast<String>().toList();
  static Map<String, CivicTrend> trends(Map<String, dynamic> value) =>
      value.map((k, v) => MapEntry(k, CivicTrend.values.byName(v as String)));
  static Matchday dayFromJson(Map<String, dynamic> value) => Matchday(
    id: value['id'] as String,
    number: value['number'] as int,
    startsAt: DateTime.parse(value['startsAt'] as String),
    locksAt: DateTime.parse(value['locksAt'] as String),
    observationEndsAt: DateTime.parse(value['observationEndsAt'] as String),
  );
  static Map<String, dynamic> dayToJson(Matchday day) => {
    'id': day.id,
    'number': day.number,
    'startsAt': day.startsAt.toUtc().toIso8601String(),
    'locksAt': day.locksAt.toUtc().toIso8601String(),
    'observationEndsAt': day.observationEndsAt.toUtc().toIso8601String(),
  };
}
