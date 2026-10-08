enum FantasyRole { mobility, environment, servicesAndSafety }

extension FantasyRoleLabel on FantasyRole {
  String get label => switch (this) {
    FantasyRole.mobility => 'Mobilità',
    FantasyRole.environment => 'Ambiente',
    FantasyRole.servicesAndSafety => 'Servizi e sicurezza',
  };
}

enum FantasySourceStatus { verified, pending, unavailable }

extension FantasySourceStatusLabel on FantasySourceStatus {
  String get label => switch (this) {
    FantasySourceStatus.verified => 'Fonte verificata',
    FantasySourceStatus.pending => 'Fonte in attesa',
    FantasySourceStatus.unavailable => 'Fonte non disponibile',
  };
}

enum CardAvailability { available, unavailable }

enum CivicTrend { improves, stable, worsens }

extension CivicTrendLabel on CivicTrend {
  String get label => switch (this) {
    CivicTrend.improves => 'Migliora',
    CivicTrend.stable => 'Stabile',
    CivicTrend.worsens => 'Peggiora',
  };
}

class FantasySeason {
  const FantasySeason({
    required this.id,
    required this.name,
    required this.totalMatchdays,
    required this.currentMatchday,
  });

  final String id;
  final String name;
  final int totalMatchdays;
  final int currentMatchday;
}

class Matchday {
  const Matchday({
    required this.id,
    required this.number,
    required this.startsAt,
    required this.locksAt,
    required this.observationEndsAt,
  });

  final String id;
  final int number;
  final DateTime startsAt;
  final DateTime locksAt;
  final DateTime observationEndsAt;
  bool isLockedAt(DateTime now) => !now.isBefore(locksAt);
}

class FantasyCard {
  const FantasyCard({
    required this.id,
    required this.title,
    required this.zone,
    required this.role,
    required this.price,
    required this.form,
    required this.observationWindow,
    required this.sourceStatus,
    required this.sourceLabel,
    required this.sourceUpdatedAt,
    required this.popularity,
    required this.illustrationKey,
    this.availability = CardAvailability.available,
  });

  final String id;
  final String title;
  final String zone;
  final FantasyRole role;
  final int price;
  final List<CivicTrend> form;
  final String observationWindow;
  final FantasySourceStatus sourceStatus;
  final String sourceLabel;
  final DateTime? sourceUpdatedAt;
  final int popularity;
  final String illustrationKey;
  final CardAvailability availability;
}

class Squad {
  const Squad({required this.cardIds, this.initialBudget = 100});

  final List<String> cardIds;
  final int initialBudget;
}

class Lineup {
  const Lineup({
    required this.starterIds,
    required this.benchIds,
    required this.captainId,
    this.confirmed = false,
  });

  final List<String> starterIds;
  final List<String> benchIds;
  final String captainId;
  final bool confirmed;
}

class Transfer {
  const Transfer({
    required this.matchdayId,
    required this.outgoingCardId,
    required this.incomingCardId,
    required this.createdAt,
    required this.cost,
  });

  final String matchdayId;
  final String outgoingCardId;
  final String incomingCardId;
  final DateTime createdAt;
  final int cost;
}

class CardOutcome {
  const CardOutcome({
    required this.matchdayId,
    required this.cardId,
    required this.observed,
    required this.sourceLabel,
    required this.sourceDate,
    required this.explanation,
    required this.sourceStatus,
  });

  final String matchdayId;
  final String cardId;
  final CivicTrend observed;
  final String sourceLabel;
  final DateTime sourceDate;
  final String explanation;
  final FantasySourceStatus sourceStatus;
}

enum ReflectionAnswer {
  observedIntervention,
  externalConditions,
  insufficientInformation,
}

extension ReflectionAnswerLabel on ReflectionAnswer {
  String get label => switch (this) {
    ReflectionAnswer.observedIntervention => 'Intervento osservato',
    ReflectionAnswer.externalConditions => 'Condizioni esterne',
    ReflectionAnswer.insufficientInformation => 'Informazioni insufficienti',
  };
}

class MatchdaySnapshot {
  MatchdaySnapshot({
    required this.matchday,
    required this.eligible,
    required List<String> squadIds,
    required List<String> starterIds,
    required this.captainId,
    required Map<String, CivicTrend> predictions,
    required this.transferPenalty,
  }) : squadIds = List.unmodifiable(squadIds),
       starterIds = List.unmodifiable(starterIds),
       predictions = Map.unmodifiable(predictions);

  final Matchday matchday;
  final bool eligible;
  final List<String> squadIds;
  List<String> get benchIds =>
      List.unmodifiable(squadIds.where((id) => !starterIds.contains(id)));
  final List<String> starterIds;
  final String captainId;
  final Map<String, CivicTrend> predictions;
  final int transferPenalty;
}

class MatchdayScore {
  const MatchdayScore({
    required this.frozenPoints,
    required this.reflectionBonus,
    required this.transferPenalty,
    required this.eligible,
  });
  final int frozenPoints;
  final int reflectionBonus;
  final int transferPenalty;
  final bool eligible;
  int get total =>
      eligible ? frozenPoints + reflectionBonus - transferPenalty : 0;
}

class ScoreBreakdown {
  const ScoreBreakdown({
    required this.cardId,
    required this.observationPoints,
    required this.predictionPoints,
    required this.reflectionPoints,
    required this.captainMultiplier,
  });

  final String cardId;
  final int observationPoints;
  final int predictionPoints;
  final int reflectionPoints;
  final double captainMultiplier;

  int get frozenTotal =>
      ((observationPoints + predictionPoints) * captainMultiplier).round();
  int get reflectionBonus => total - frozenTotal;

  int get total =>
      ((observationPoints + predictionPoints + reflectionPoints) *
              captainMultiplier)
          .round();
}

class LeagueEntry {
  const LeagueEntry({
    required this.userId,
    required this.displayName,
    required this.points,
    required this.rank,
    this.isCurrentUser = false,
  });

  final String userId;
  final String displayName;
  final int points;
  final int rank;
  final bool isCurrentUser;
}

class FantasyLeague {
  const FantasyLeague({
    required this.id,
    required this.name,
    required this.entries,
    required this.isMunicipal,
    this.minimumParticipants = 2,
  });

  final String id;
  final String name;
  final List<LeagueEntry> entries;
  final bool isMunicipal;
  final int minimumParticipants;

  bool get isVisible => entries.length >= minimumParticipants;
}
