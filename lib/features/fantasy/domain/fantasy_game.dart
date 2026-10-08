import 'dart:convert';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'fantasy_models.dart';
import 'fantasy_saved_state.dart';

/// Domain rules. No preferences, timers, widgets, or network side effects.
class FantasyGame {
  FantasyGame({
    required Matchday matchday,
    required this.cards,
    required List<CardOutcome> outcomes,
    required DateTime Function() now,
    required this.usingDemoOutcomes,
    required this.leagues,
    FantasySavedState? restored,
  }) : _matchday = matchday,
       _outcomes = outcomes,
       _now = now {
    if (restored != null) restore(restored);
  }
  final DateTime Function() _now;
  Matchday _matchday;
  final List<FantasyCard> cards;
  List<CardOutcome> _outcomes;
  final bool usingDemoOutcomes;
  final List<FantasyLeague> leagues;
  final Map<String, MatchdaySnapshot> _snapshots = {};
  final Map<String, ReflectionAnswer> _reflections = {};
  final Map<String, CardOutcome> _revealed = {};
  FantasySeason get season => FantasySeason(
    id: 'season-demo-1',
    name: 'Stagione civica · Autunno',
    totalMatchdays: 8,
    currentMatchday: matchday.number,
  );
  Matchday get matchday => _matchday;
  DateTime get now => _now();
  bool get isLocked =>
      _snapshots.containsKey(matchday.id) || matchday.isLockedAt(now);

  static const _initialSquad = [
    'buche-centro',
    'bus-stazione',
    'parco-nord',
    'rifiuti-mercato',
    'lampioni-sud',
    'attraversamenti-scuole',
    'alberi-viale',
    'sportello-anagrafe',
  ];
  static const _initialStarters = [
    'buche-centro',
    'bus-stazione',
    'parco-nord',
    'rifiuti-mercato',
    'lampioni-sud',
  ];
  List<String> _squadIds = [..._initialSquad];
  List<String> _starterIds = [..._initialStarters];
  String _captainId = 'buche-centro';
  bool _confirmed = false;
  Map<String, CivicTrend> _predictions = {};
  Map<String, String> _motivations = {};
  List<Transfer> _transfers = [];

  List<String> get squadIds => List.unmodifiable(_squadIds);
  List<String> get starterIds => List.unmodifiable(_starterIds);
  List<String> get benchIds => _squadIds
      .where((id) => !_starterIds.contains(id))
      .toList(growable: false);
  String get captainId => _captainId;
  bool get confirmed => _confirmed;
  Map<String, CivicTrend> get predictions => Map.unmodifiable(_predictions);
  Map<String, String> get motivations => Map.unmodifiable(_motivations);
  List<Transfer> get transfers => List.unmodifiable(_transfers);
  int get transfersRemaining =>
      (2 - _dayTransfers(matchday.id).length).clamp(0, 2);
  int get nextTransferPenalty => transfersRemaining > 0 ? 0 : 4;
  int get communityScore => 68;
  int get transferPenalty => _penaltyFor(matchday.id);
  Squad get squad => Squad(cardIds: squadIds);
  Lineup get lineup => Lineup(
    starterIds: starterIds,
    benchIds: benchIds,
    captainId: captainId,
    confirmed: confirmed,
  );
  List<FantasyCard> get squadCards =>
      _squadIds.map(cardById).toList(growable: false);
  List<FantasyCard> get starterCards =>
      _starterIds.map(cardById).toList(growable: false);
  List<FantasyCard> get benchCards =>
      benchIds.map(cardById).toList(growable: false);
  List<FantasyCard> get marketCards => cards
      .where((card) => !_squadIds.contains(card.id))
      .toList(growable: false);
  int get squadCost => squadCards.fold(0, (sum, card) => sum + card.price);
  int get budgetRemaining => squad.initialBudget - squadCost;
  int get predictionsCompleted =>
      _starterIds.where(_predictions.containsKey).length;
  FantasyCard cardById(String id) => cards.firstWhere((card) => card.id == id);
  bool _known(String id) => cards.any((card) => card.id == id);
  Iterable<Transfer> _dayTransfers(String id) =>
      _transfers.where((t) => t.matchdayId == id);
  int _penaltyFor(String id) =>
      _dayTransfers(id).fold(0, (sum, t) => sum + t.cost);
  static String _key(String dayId, String cardId) =>
      FantasySavedState.resultKey(dayId, cardId);

  String? get lineupIssue {
    if (_squadIds.length != 8) return 'La rosa deve contenere 8 carte.';
    for (final role in FantasyRole.values) {
      if (squadCards.where((card) => card.role == role).length < 2) {
        return 'Servono almeno 2 carte per il ruolo ${role.label}.';
      }
      if (starterCards.every((card) => card.role != role)) {
        return 'Schiera almeno una carta ${role.label}.';
      }
    }
    if (_starterIds.length != 5) return 'Schiera esattamente 5 titolari.';
    if (!_starterIds.contains(_captainId)) {
      return 'Il capitano deve essere tra i titolari.';
    }
    return null;
  }

  void swapCards({required String starterId, required String reserveId}) {
    refreshTime();
    if (isLocked ||
        !_starterIds.contains(starterId) ||
        !benchIds.contains(reserveId)) {
      return;
    }
    _starterIds[_starterIds.indexOf(starterId)] = reserveId;
    if (_captainId == starterId) _captainId = reserveId;
    _confirmed = false;
  }

  void setCaptain(String cardId) {
    refreshTime();
    if (isLocked || !_starterIds.contains(cardId)) return;
    _captainId = cardId;
    _confirmed = false;
  }

  bool confirmLineup() {
    refreshTime();
    if (isLocked || lineupIssue != null) return false;
    _confirmed = true;
    return true;
  }

  void setPrediction(String cardId, CivicTrend trend) {
    refreshTime();
    if (isLocked || !_starterIds.contains(cardId)) return;
    _predictions[cardId] = trend;
  }

  void setMotivation(String cardId, String text) {
    refreshTime();
    if (isLocked || !_starterIds.contains(cardId)) return;
    _motivations[cardId] = text;
  }

  String? purchaseIssue(FantasyCard card) {
    if (isLocked) return 'Mercato chiuso: giornata bloccata.';
    if (card.availability == CardAvailability.unavailable) {
      return 'Carta non disponibile per questa giornata.';
    }
    if (card.sourceStatus == FantasySourceStatus.unavailable) {
      return 'Fonte non disponibile: acquisto sospeso.';
    }
    return null;
  }

  String? transfer({
    required String outgoingId,
    required String incomingId,
    int? expectedPenalty,
  }) {
    refreshTime();
    if (isLocked) return 'Mercato chiuso: giornata bloccata.';
    if (!_squadIds.contains(outgoingId)) return 'Carta da cedere non valida.';
    if (!_known(incomingId)) return 'Carta da acquistare non valida.';
    if (_squadIds.contains(incomingId)) return 'La carta è già nella rosa.';
    final incoming = cardById(incomingId);
    final issue = purchaseIssue(incoming);
    if (issue != null) return issue;
    if (expectedPenalty != null && expectedPenalty != nextTransferPenalty) {
      return 'La penalità è cambiata. Riapri il confronto.';
    }
    final outgoing = cardById(outgoingId);
    if (budgetRemaining + outgoing.price < incoming.price) {
      return 'Crediti insufficienti per il trasferimento.';
    }
    final nextIds = [..._squadIds]
      ..[_squadIds.indexOf(outgoingId)] = incomingId;
    for (final role in FantasyRole.values) {
      if (nextIds.map(cardById).where((card) => card.role == role).length < 2) {
        return 'Il trasferimento lascerebbe meno di 2 carte ${role.label}.';
      }
    }
    final penalty = nextTransferPenalty;
    _squadIds = nextIds;
    if (_starterIds.contains(outgoingId)) {
      _starterIds[_starterIds.indexOf(outgoingId)] = incomingId;
    }
    if (_captainId == outgoingId) _captainId = incomingId;
    _predictions.remove(outgoingId);
    _motivations.remove(outgoingId);
    _confirmed = false;
    _transfers.add(
      Transfer(
        matchdayId: matchday.id,
        outgoingCardId: outgoingId,
        incomingCardId: incomingId,
        createdAt: now,
        cost: penalty,
      ),
    );
    return null;
  }

  MatchdaySnapshot? snapshotFor(String dayId) => _snapshots[dayId];

  List<CardOutcome> get outcomes {
    final combined = <String, CardOutcome>{
      for (final o in _outcomes)
        if (!o.sourceDate.isAfter(now) &&
            (o.matchdayId != matchday.id ||
                !now.isBefore(matchday.observationEndsAt)))
          _key(o.matchdayId, o.cardId): o,
      ..._revealed,
    };
    return List.unmodifiable(combined.values);
  }

  CivicTrend? predictionFor(CardOutcome o) =>
      _snapshots[o.matchdayId]?.predictions[o.cardId];
  ReflectionAnswer? reflectionFor(CardOutcome o) =>
      _reflections[_key(o.matchdayId, o.cardId)];
  bool hasPersonalResult(CardOutcome o) {
    final snapshot = _snapshots[o.matchdayId];
    return snapshot != null &&
        snapshot.eligible &&
        snapshot.starterIds.contains(o.cardId) &&
        _revealed.containsKey(_key(o.matchdayId, o.cardId));
  }

  ScoreBreakdown scoreFor(CardOutcome outcome) {
    final snapshot = _snapshots[outcome.matchdayId];
    final published = _revealed[_key(outcome.matchdayId, outcome.cardId)];
    final eligible = hasPersonalResult(outcome);
    final observed = published?.observed;
    final prediction = snapshot?.predictions[outcome.cardId];
    final observation = !eligible
        ? 0
        : observed == CivicTrend.improves
        ? 4
        : observed == CivicTrend.stable
        ? 1
        : 0;
    final forecast = !eligible || prediction == null
        ? 0
        : prediction == observed
        ? 4
        : prediction == CivicTrend.stable || observed == CivicTrend.stable
        ? 2
        : 0;
    return ScoreBreakdown(
      cardId: outcome.cardId,
      observationPoints: observation,
      predictionPoints: forecast,
      reflectionPoints: eligible && reflectionFor(outcome) != null ? 1 : 0,
      captainMultiplier: eligible && snapshot!.captainId == outcome.cardId
          ? 1.5
          : 1,
    );
  }

  MatchdayScore scoreForMatchday(String dayId) {
    final snapshot = _snapshots[dayId];
    final scores = _revealed.values
        .where((o) => o.matchdayId == dayId)
        .map(scoreFor);
    return MatchdayScore(
      frozenPoints: scores.fold(0, (sum, s) => sum + s.frozenTotal),
      reflectionBonus: scores.fold(0, (sum, s) => sum + s.reflectionBonus),
      transferPenalty: snapshot?.transferPenalty ?? _penaltyFor(dayId),
      eligible: snapshot?.eligible ?? false,
    );
  }

  bool submitReflection(CardOutcome outcome, ReflectionAnswer answer) {
    refreshTime();
    final key = _key(outcome.matchdayId, outcome.cardId);
    if (!hasPersonalResult(outcome) || _reflections.containsKey(key)) {
      return false;
    }
    _reflections[key] = answer;
    return true;
  }

  /// Explicit transition for the demo host; archived snapshots never change.
  bool startNextMatchday(Matchday next, List<CardOutcome> nextOutcomes) {
    refreshTime();
    if (now.isBefore(matchday.observationEndsAt) ||
        next.number != matchday.number + 1 ||
        next.number > season.totalMatchdays ||
        _snapshots.containsKey(next.id) ||
        next.id == matchday.id ||
        !_validDay(next) ||
        !now.isBefore(next.locksAt)) {
      return false;
    }
    _matchday = next;
    if (usingDemoOutcomes) {
      _outcomes = List.unmodifiable([..._outcomes, ...nextOutcomes]);
    }
    _confirmed = false;
    _predictions = {};
    _motivations = {};
    return true;
  }

  bool synchronize() {
    var changed = false;
    if (isLocked && !_snapshots.containsKey(matchday.id)) {
      _snapshots[matchday.id] = MatchdaySnapshot(
        matchday: matchday,
        eligible: _confirmed && lineupIssue == null,
        squadIds: _squadIds,
        starterIds: _starterIds,
        captainId: _captainId,
        predictions: _predictions,
        transferPenalty: transferPenalty,
      );
      changed = true;
    }
    for (final outcome in _outcomes) {
      final snapshot = _snapshots[outcome.matchdayId];
      final key = _key(outcome.matchdayId, outcome.cardId);
      if (snapshot != null &&
          !now.isBefore(snapshot.matchday.observationEndsAt) &&
          !outcome.sourceDate.isAfter(now) &&
          outcome.sourceStatus == FantasySourceStatus.verified &&
          !_revealed.containsKey(key)) {
        _revealed[key] = outcome;
        changed = true;
      }
    }
    return changed;
  }

  void refreshTime() => synchronize();

  FantasySavedState get savedState => FantasySavedState(
    matchday: matchday,
    squadIds: squadIds,
    starterIds: starterIds,
    captainId: captainId,
    confirmed: confirmed,
    predictions: predictions,
    motivations: motivations,
    transfers: transfers,
    snapshots: Map.of(_snapshots),
    reflections: Map.of(_reflections),
    revealed: Map.of(_revealed),
  );

  bool _validDay(Matchday d) =>
      d.id.isNotEmpty &&
      !d.id.contains('/') &&
      d.number >= 1 &&
      d.number <= 8 &&
      d.startsAt.isBefore(d.locksAt) &&
      d.locksAt.isBefore(d.observationEndsAt);

  void _validate(FantasySavedState state) {
    bool uniqueKnown(List<String> ids) =>
        ids.toSet().length == ids.length && ids.every(_known);
    void require(bool value) {
      if (!value) throw const FormatException('Invalid fantasy state');
    }

    require(_validDay(state.matchday));
    require(state.squadIds.length == 8 && uniqueKnown(state.squadIds));
    require(
      state.squadIds.map(cardById).fold<int>(0, (sum, c) => sum + c.price) <=
          100,
    );
    require(
      state.starterIds.length == 5 &&
          uniqueKnown(state.starterIds) &&
          state.starterIds.every(state.squadIds.contains) &&
          state.starterIds.contains(state.captainId),
    );
    for (final role in FantasyRole.values) {
      require(
        state.squadIds.map(cardById).where((c) => c.role == role).length >= 2,
      );
      if (state.confirmed) {
        require(state.starterIds.map(cardById).any((c) => c.role == role));
      }
    }
    require(state.predictions.keys.every(state.squadIds.contains));
    require(state.motivations.keys.every(state.squadIds.contains));
    for (final transfer in state.transfers) {
      require(
        _known(transfer.outgoingCardId) &&
            _known(transfer.incomingCardId) &&
            transfer.outgoingCardId != transfer.incomingCardId,
      );
      require(
        transfer.matchdayId == state.matchday.id ||
            state.snapshots.containsKey(transfer.matchdayId),
      );
    }
    for (final snapshot in state.snapshots.values) {
      require(snapshot.squadIds.length == 8 && uniqueKnown(snapshot.squadIds));
      require(
        snapshot.squadIds
                .map(cardById)
                .fold<int>(0, (sum, card) => sum + card.price) <=
            100,
      );
      for (final role in FantasyRole.values) {
        require(
          snapshot.squadIds
                  .map(cardById)
                  .where((card) => card.role == role)
                  .length >=
              2,
        );
      }
      require(
        _validDay(snapshot.matchday) &&
            snapshot.matchday.number <= state.matchday.number,
      );
      require(
        snapshot.starterIds.length == 5 &&
            snapshot.starterIds.every(snapshot.squadIds.contains) &&
            uniqueKnown(snapshot.starterIds) &&
            snapshot.starterIds.contains(snapshot.captainId),
      );
      require(snapshot.predictions.keys.every(snapshot.squadIds.contains));
      require(
        snapshot.transferPenalty ==
            state.transfers
                .where((t) => t.matchdayId == snapshot.matchday.id)
                .fold<int>(0, (sum, t) => sum + t.cost),
      );
      if (snapshot.eligible) {
        for (final role in FantasyRole.values) {
          require(snapshot.starterIds.map(cardById).any((c) => c.role == role));
        }
      }
      if (snapshot.matchday.id == state.matchday.id) {
        require(
          jsonEncode(FantasySavedState.dayToJson(snapshot.matchday)) ==
              jsonEncode(FantasySavedState.dayToJson(state.matchday)),
        );
        require(
          listEquals(snapshot.starterIds, state.starterIds) &&
              listEquals(snapshot.squadIds, state.squadIds) &&
              snapshot.captainId == state.captainId &&
              mapEquals(snapshot.predictions, state.predictions) &&
              snapshot.eligible == state.confirmed,
        );
      }
    }
    for (final outcome in state.revealed.values) {
      require(
        _known(outcome.cardId) &&
            state.snapshots.containsKey(outcome.matchdayId) &&
            outcome.sourceStatus == FantasySourceStatus.verified,
      );
    }
    for (final key in state.reflections.keys) {
      final outcome = state.revealed[key];
      require(outcome != null);
      final snapshot = state.snapshots[outcome!.matchdayId]!;
      require(
        snapshot.eligible && snapshot.starterIds.contains(outcome.cardId),
      );
    }
  }

  void restore(FantasySavedState state) {
    _validate(state);
    _matchday = state.matchday;
    _squadIds = List.of(state.squadIds);
    _starterIds = List.of(state.starterIds);
    _captainId = state.captainId;
    _confirmed = state.confirmed;
    _predictions = Map.of(state.predictions);
    _motivations = Map.of(state.motivations);
    _transfers = List.of(state.transfers);
    _snapshots.addAll(state.snapshots);
    _reflections.addAll(state.reflections);
    _revealed.addAll(state.revealed);
  }
}
