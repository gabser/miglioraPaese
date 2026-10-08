import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_saved_state.dart';

/// Unknown transport values are errors, never substituted with demo values.
class FantasyApiMapper {
  static Map<String, dynamic> object(Object? raw) =>
      (raw as Map).cast<String, dynamic>();
  static List<String> strings(Object? raw) =>
      List<String>.unmodifiable((raw as List).cast<String>());
  static CivicTrend trend(Object? raw) => switch (raw) {
    'improves' => CivicTrend.improves,
    'stable' => CivicTrend.stable,
    'worsens' => CivicTrend.worsens,
    _ => throw const FormatException('Unknown trend'),
  };
  static FantasyRole role(Object? raw) => switch (raw) {
    'mobility' => FantasyRole.mobility,
    'environment' => FantasyRole.environment,
    'servicesAndSafety' => FantasyRole.servicesAndSafety,
    _ => throw const FormatException('Unknown role'),
  };
  static FantasySourceStatus source(Object? raw) => switch (raw) {
    'verified' => FantasySourceStatus.verified,
    'pending' => FantasySourceStatus.pending,
    'unavailable' => FantasySourceStatus.unavailable,
    _ => throw const FormatException('Unknown source'),
  };
  static ReflectionAnswer answer(Object? raw) => switch (raw) {
    'observedIntervention' => ReflectionAnswer.observedIntervention,
    'externalConditions' => ReflectionAnswer.externalConditions,
    'insufficientInformation' => ReflectionAnswer.insufficientInformation,
    _ => throw const FormatException('Unknown reflection'),
  };
  static DateTime date(Object? raw) {
    final text = raw as String;
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(text))
      throw const FormatException('Timezone required');
    return DateTime.parse(text).toUtc();
  }

  static Map<String, CivicTrend> predictions(Object? raw) =>
      object(raw).map((k, v) => MapEntry(k, trend(v)));
  static FantasyCard card(Object? raw) {
    final v = object(raw);
    return FantasyCard(
      id: v['id'] as String,
      title: v['title'] as String,
      zone: v['zone'] as String,
      role: role(v['role']),
      price: v['price'] as int,
      form: List.unmodifiable((v['form'] as List).map(trend)),
      observationWindow: v['observationWindow'] as String,
      sourceStatus: source(v['sourceStatus']),
      sourceLabel: v['sourceLabel'] as String,
      sourceUpdatedAt: v['sourceUpdatedAt'] == null
          ? null
          : date(v['sourceUpdatedAt']),
      popularity: v['popularity'] as int,
      illustrationKey: v['illustrationKey'] as String,
      availability: switch (v['availability']) {
        'available' => CardAvailability.available,
        'unavailable' => CardAvailability.unavailable,
        _ => throw const FormatException('Unknown availability'),
      },
    );
  }

  static Matchday day(Object? raw) {
    final v = object(raw);
    if (v['rulesVersion'] != 'fantasy-demo-v1')
      throw const FormatException('Unsupported rules');
    return Matchday(
      id: v['id'] as String,
      number: v['number'] as int,
      startsAt: date(v['startsAt']),
      locksAt: date(v['locksAt']),
      observationEndsAt: date(v['observationEndsAt']),
    );
  }

  static CardOutcome outcome(Object? raw) {
    final v = object(raw);
    return CardOutcome(
      matchdayId: v['matchdayId'] as String,
      cardId: v['cardId'] as String,
      observed: trend(v['observed']),
      sourceLabel: v['sourceLabel'] as String,
      sourceDate: date(v['sourceDate']),
      explanation: v['explanation'] as String,
      sourceStatus: source(v['sourceStatus']),
    );
  }

  static FantasyData data({
    required Map<String, dynamic> seasonResponse,
    required Map<String, dynamic> catalog,
    required Map<String, dynamic> teamResponse,
    required Map<String, Matchday> days,
    required List<Map<String, dynamic>> reveals,
  }) {
    final s = object(seasonResponse['season']);
    if (teamResponse['seasonId'] != s['id'] || catalog['seasonId'] != s['id'])
      throw const FormatException('Mixed seasons');
    final team = object(teamResponse['team']);
    final snapshots = <String, MatchdaySnapshot>{};
    for (final raw in teamResponse['snapshots'] as List) {
      final v = object(raw), id = v['matchdayId'] as String;
      snapshots[id] = MatchdaySnapshot(
        matchday: days[id]!,
        eligible: v['eligible'] as bool,
        squadIds: strings(v['squadIds']),
        starterIds: strings(v['starterIds']),
        captainId: v['captainId'] as String,
        predictions: predictions(v['predictions']),
        transferPenalty: v['transferPenalty'] as int,
      );
    }
    final outcomes = <String, CardOutcome>{},
        personal = <String, CardOutcome>{};
    final reflections = <String, ReflectionAnswer>{},
        scores = <String, ScoreBreakdown>{};
    final summaries = <String, MatchdayScore>{}, statuses = <String, String>{};
    for (final reveal in reveals) {
      if (reveal['seasonId'] != s['id'])
        throw const FormatException('Mixed results');
      for (final raw in reveal['outcomes'] as List) {
        final o = outcome(raw);
        outcomes[FantasySavedState.resultKey(o.matchdayId, o.cardId)] = o;
      }
      for (final raw in reveal['results'] as List) {
        final v = object(raw),
            o = outcome(v['outcome']),
            score = object(v['score']);
        final key = FantasySavedState.resultKey(o.matchdayId, o.cardId);
        personal[key] = o;
        scores[key] = ScoreBreakdown(
          cardId: o.cardId,
          observationPoints: score['observationPoints'] as int,
          predictionPoints: score['predictionPoints'] as int,
          reflectionPoints: score['reflectionPoints'] as int,
          captainMultiplier: (score['captainMultiplier'] as num).toDouble(),
        );
        if (scores[key]!.total != score['total'] ||
            scores[key]!.frozenTotal != score['frozenTotal'])
          throw const FormatException('Inconsistent score');
        if (v['reflection'] != null) reflections[key] = answer(v['reflection']);
      }
      final summary = object(reveal['summary']),
          id = reveal['matchdayId'] as String;
      final status = summary['status'];
      if (status != 'final' && status != 'provisional')
        throw const FormatException('Unknown status');
      statuses[id] = status as String;
      summaries[id] = MatchdayScore(
        frozenPoints: summary['frozenPoints'] as int,
        reflectionBonus: summary['reflectionBonus'] as int,
        transferPenalty: summary['transferPenalty'] as int,
        eligible: summary['eligible'] as bool,
      );
      if (summaries[id]!.total != summary['total'])
        throw const FormatException('Inconsistent total');
    }
    return FantasyData(
      state: FantasySavedState(
        matchday: days[teamResponse['matchdayId']]!,
        squadIds: strings(team['squadIds']),
        starterIds: strings(team['starterIds']),
        captainId: team['captainId'] as String,
        confirmed: team['confirmed'] as bool,
        predictions: predictions(team['predictions']),
        motivations: object(team['motivations']).cast<String, String>(),
        transfers: (teamResponse['transfers'] as List).map((raw) {
          final v = object(raw);
          return Transfer(
            matchdayId: v['matchdayId'] as String,
            outgoingCardId: v['outgoingCardId'] as String,
            incomingCardId: v['incomingCardId'] as String,
            createdAt: date(v['createdAt']),
            cost: v['cost'] as int,
          );
        }).toList(),
        snapshots: snapshots,
        reflections: reflections,
        revealed: personal,
      ),
      cards: (catalog['items'] as List).map(card).toList(),
      outcomes: outcomes.values.toList(),
      leagues: [],
      serverTime: date(teamResponse['serverTime']),
      revision: teamResponse['revision'] as int,
      isDemo: teamResponse['isDemo'] as bool,
      season: FantasySeason(
        id: s['id'] as String,
        name: s['name'] as String,
        totalMatchdays: s['totalMatchdays'] as int,
        currentMatchday: s['currentMatchday'] as int,
      ),
      scores: Map.unmodifiable(scores),
      summaries: Map.unmodifiable(summaries),
      summaryStatuses: Map.unmodifiable(statuses),
    );
  }
}
