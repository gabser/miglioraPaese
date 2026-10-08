import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_state.dart';

class FantasyManager extends ChangeNotifier with WidgetsBindingObserver {
  FantasyManager(
    this._prefs, {
    DateTime Function()? now,
    Matchday? initialMatchday,
    List<FantasyCard>? initialCards,
    List<CardOutcome>? initialOutcomes,
    bool observeTime = true,
  }) : _now = now ?? DateTime.now {
    final time = _now();
    _matchday =
        initialMatchday ??
        Matchday(
          id: 'matchday-2',
          number: 2,
          startsAt: time.subtract(const Duration(days: 1)),
          locksAt: time.add(const Duration(days: 2, hours: 4)),
          observationEndsAt: time.add(const Duration(days: 7)),
        );
    cards = List.unmodifiable(initialCards ?? _seedCards());
    _restore();
    _usingDemoOutcomes = initialOutcomes == null;
    _outcomes = List.unmodifiable(initialOutcomes ?? _seedOutcomes());
    _synchronize();
    _persist();
    if (observeTime) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => refreshTime());
    }
  }

  final AppPrefs _prefs;
  final DateTime Function() _now;
  late Matchday _matchday;
  late final List<FantasyCard> cards;
  late List<CardOutcome> _outcomes;
  late final bool _usingDemoOutcomes;
  Timer? _timer;
  bool _observing = false;
  bool _disposed = false;
  bool _clearing = false;
  Future<void> _saveQueue = Future.value();
  String? persistenceError;
  String? recoveryMessage;
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
      _clearing ||
      _snapshots.containsKey(matchday.id) ||
      matchday.isLockedAt(now);
  late final List<FantasyLeague> leagues = _seedLeagues();

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
    _changed();
  }

  void setCaptain(String cardId) {
    refreshTime();
    if (isLocked || !_starterIds.contains(cardId)) return;
    _captainId = cardId;
    _confirmed = false;
    _changed();
  }

  bool confirmLineup() {
    refreshTime();
    if (isLocked || lineupIssue != null) return false;
    _confirmed = true;
    _changed();
    return true;
  }

  void setPrediction(String cardId, CivicTrend trend) {
    refreshTime();
    if (isLocked || !_starterIds.contains(cardId)) return;
    _predictions[cardId] = trend;
    _changed();
  }

  void setMotivation(String cardId, String text) {
    refreshTime();
    if (isLocked || !_starterIds.contains(cardId)) return;
    _motivations[cardId] = text;
    _changed();
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
    _changed();
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
    if (_clearing || _disposed) return false;
    refreshTime();
    final key = _key(outcome.matchdayId, outcome.cardId);
    if (!hasPersonalResult(outcome) || _reflections.containsKey(key)) {
      return false;
    }
    _reflections[key] = answer;
    _changed();
    return true;
  }

  /// Explicit transition for the demo host; archived snapshots never change.
  bool startNextMatchday(Matchday next) {
    if (_clearing || _disposed) return false;
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
    if (_usingDemoOutcomes) {
      _outcomes = List.unmodifiable([
        ..._outcomes,
        ..._seedOutcomes().where((o) => o.matchdayId == next.id),
      ]);
    }
    _confirmed = false;
    _predictions = {};
    _motivations = {};
    _changed();
    return true;
  }

  bool _synchronize() {
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

  void refreshTime() {
    if (_disposed || _clearing) return;
    if (_synchronize()) _persist();
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshTime();
  }

  void _changed() {
    _persist();
    if (!_disposed) notifyListeners();
  }

  Future<void> get settled => _saveQueue;
  Future<void> retrySave() {
    if (_clearing) return settled;
    _persist();
    return settled;
  }

  /// Drain writes before deleting preferences so an old queued save cannot restore them.
  Future<void> clearLocalData() async {
    _clearing = true;
    try {
      await settled;
      await _prefs.clearAll();
      _squadIds = [..._initialSquad];
      _starterIds = [..._initialStarters];
      _captainId = _starterIds.first;
      _confirmed = false;
      _predictions = {};
      _motivations = {};
      _transfers = [];
      _snapshots.clear();
      _reflections.clear();
      _revealed.clear();
      _matchday = Matchday(
        id: 'matchday-2',
        number: 2,
        startsAt: now.subtract(const Duration(days: 1)),
        locksAt: now.add(const Duration(days: 2, hours: 4)),
        observationEndsAt: now.add(const Duration(days: 7)),
      );
      _outcomes = List.unmodifiable(
        _usingDemoOutcomes ? _seedOutcomes() : <CardOutcome>[],
      );
      persistenceError = null;
      recoveryMessage = null;
    } finally {
      _clearing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _persist() {
    if (_clearing) return;
    final payload = jsonEncode(_savedState.toJson());
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _prefs.setFantasyStateJson(payload);
        if (persistenceError != null) {
          persistenceError = null;
          if (!_disposed) notifyListeners();
        }
      } catch (_) {
        persistenceError =
            'Salvataggio non riuscito. Le ultime modifiche potrebbero andare perse.';
        if (!_disposed) notifyListeners();
      }
    });
  }

  FantasySavedState get _savedState => FantasySavedState(
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

  void _restore() {
    final raw = _prefs.fantasyStateJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final state = FantasySavedState.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
        matchday,
      );
      _validate(state);
      _matchday = state.matchday;
      _squadIds = state.squadIds;
      _starterIds = state.starterIds;
      _captainId = state.captainId;
      _confirmed = state.confirmed;
      _predictions = state.predictions;
      _motivations = state.motivations;
      _transfers = state.transfers;
      _snapshots.addAll(state.snapshots);
      _reflections.addAll(state.reflections);
      _revealed.addAll(state.revealed);
    } catch (_) {
      recoveryMessage =
          'Dati demo incompatibili: partita ripristinata. Conferma nuovamente la formazione.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<FantasyCard> _seedCards() {
    final now = this.now;
    return [
      _card(
        'buche-centro',
        'Buche sulle vie centrali',
        'Centro',
        FantasyRole.mobility,
        13,
        const [CivicTrend.stable, CivicTrend.worsens, CivicTrend.improves],
        '7 giorni',
        FantasySourceStatus.verified,
        'Open data manutenzioni · demo',
        now.subtract(const Duration(days: 1)),
        74,
        'road',
      ),
      _card(
        'bus-stazione',
        'Regolarità bus stazione',
        'Stazione',
        FantasyRole.mobility,
        12,
        const [CivicTrend.improves, CivicTrend.stable, CivicTrend.stable],
        '7 giorni',
        FantasySourceStatus.verified,
        'Orari trasporto locale · demo',
        now.subtract(const Duration(hours: 18)),
        68,
        'bus',
      ),
      _card(
        'attraversamenti-scuole',
        'Attraversamenti scolastici',
        'Zona scuole',
        FantasyRole.mobility,
        10,
        const [CivicTrend.stable, CivicTrend.improves, CivicTrend.improves],
        '5 giorni',
        FantasySourceStatus.pending,
        'Osservazione civica moderata',
        now.subtract(const Duration(days: 2)),
        61,
        'crosswalk',
      ),
      _card(
        'ciclabile-est',
        'Continuità pista ciclabile',
        'Quartiere Est',
        FantasyRole.mobility,
        9,
        const [CivicTrend.worsens, CivicTrend.stable, CivicTrend.stable],
        '7 giorni',
        FantasySourceStatus.unavailable,
        'Fonte in aggiornamento',
        null,
        39,
        'bike',
      ),
      _card(
        'parco-nord',
        'Pulizia del parco',
        'Parco Nord',
        FantasyRole.environment,
        11,
        const [CivicTrend.stable, CivicTrend.improves, CivicTrend.improves],
        '7 giorni',
        FantasySourceStatus.verified,
        'Calendario servizi · demo',
        now.subtract(const Duration(days: 1)),
        70,
        'park',
      ),
      _card(
        'rifiuti-mercato',
        'Rifiuti dopo il mercato',
        'Piazza Mercato',
        FantasyRole.environment,
        12,
        const [CivicTrend.worsens, CivicTrend.stable, CivicTrend.improves],
        '3 giorni',
        FantasySourceStatus.verified,
        'Report gestore rifiuti · demo',
        now.subtract(const Duration(hours: 8)),
        82,
        'waste',
      ),
      _card(
        'alberi-viale',
        'Cura degli alberi del viale',
        'Viale Europa',
        FantasyRole.environment,
        8,
        const [CivicTrend.stable, CivicTrend.stable, CivicTrend.improves],
        '14 giorni',
        FantasySourceStatus.pending,
        'Verifica ufficio verde · demo',
        now.subtract(const Duration(days: 3)),
        44,
        'tree',
      ),
      _card(
        'fontanelle-ovest',
        'Fontanelle funzionanti',
        'Quartiere Ovest',
        FantasyRole.environment,
        7,
        const [CivicTrend.improves, CivicTrend.stable, CivicTrend.worsens],
        '7 giorni',
        FantasySourceStatus.verified,
        'Controlli manutenzione · demo',
        now.subtract(const Duration(days: 1)),
        36,
        'water',
      ),
      _card(
        'lampioni-sud',
        'Lampioni attivi',
        'Quartiere Sud',
        FantasyRole.servicesAndSafety,
        10,
        const [CivicTrend.improves, CivicTrend.improves, CivicTrend.stable],
        '7 notti',
        FantasySourceStatus.verified,
        'Registro illuminazione · demo',
        now.subtract(const Duration(hours: 12)),
        77,
        'light',
      ),
      _card(
        'sportello-anagrafe',
        'Attesa allo sportello',
        'Municipio',
        FantasyRole.servicesAndSafety,
        9,
        const [CivicTrend.stable, CivicTrend.stable, CivicTrend.improves],
        '5 giorni',
        FantasySourceStatus.verified,
        'Tempi medi servizio · demo',
        now.subtract(const Duration(days: 1)),
        49,
        'office',
      ),
      _card(
        'fermata-accessibile',
        'Accessibilità fermata',
        'Via Roma',
        FantasyRole.servicesAndSafety,
        8,
        const [CivicTrend.worsens, CivicTrend.stable, CivicTrend.improves],
        '7 giorni',
        FantasySourceStatus.pending,
        'Sopralluogo in verifica',
        now.subtract(const Duration(days: 4)),
        57,
        'stop',
      ),
      _card(
        'biblioteca-orari',
        'Apertura biblioteca',
        'Centro civico',
        FantasyRole.servicesAndSafety,
        6,
        const [CivicTrend.stable, CivicTrend.improves, CivicTrend.stable],
        '7 giorni',
        FantasySourceStatus.verified,
        'Calendario biblioteca · demo',
        now.subtract(const Duration(hours: 20)),
        32,
        'library',
      ),
    ];
  }

  FantasyCard _card(
    String id,
    String title,
    String zone,
    FantasyRole role,
    int price,
    List<CivicTrend> form,
    String window,
    FantasySourceStatus source,
    String sourceLabel,
    DateTime? updatedAt,
    int popularity,
    String illustration,
  ) => FantasyCard(
    id: id,
    title: title,
    zone: zone,
    role: role,
    price: price,
    form: form,
    observationWindow: window,
    sourceStatus: source,
    sourceLabel: sourceLabel,
    sourceUpdatedAt: updatedAt,
    popularity: popularity,
    illustrationKey: illustration,
  );

  List<CardOutcome> _seedOutcomes() => [
    CardOutcome(
      matchdayId: 'matchday-1',
      cardId: 'buche-centro',
      observed: CivicTrend.stable,
      sourceLabel: 'Open data manutenzioni · demo',
      sourceDate: matchday.startsAt.subtract(const Duration(days: 7)),
      sourceStatus: FantasySourceStatus.verified,
      explanation:
          'Le segnalazioni verificate sono rimaste nella stessa fascia.',
    ),
    CardOutcome(
      matchdayId: 'matchday-1',
      cardId: 'parco-nord',
      observed: CivicTrend.improves,
      sourceLabel: 'Calendario servizi · demo',
      sourceDate: matchday.startsAt.subtract(const Duration(days: 7)),
      sourceStatus: FantasySourceStatus.verified,
      explanation:
          'Due passaggi di pulizia risultano completati nella finestra.',
    ),
    ...cards.map(
      (card) => CardOutcome(
        matchdayId: matchday.id,
        cardId: card.id,
        observed: card.form.last,
        sourceLabel: '${card.sourceLabel} · esito simulato',
        sourceDate: matchday.observationEndsAt,
        sourceStatus: card.sourceStatus,
        explanation:
            'Esempio demo nella finestra di osservazione. Nessuna condizione reale certificata.',
      ),
    ),
  ];

  List<FantasyLeague> _seedLeagues() {
    const privateEntries = [
      LeagueEntry(userId: 'anna', displayName: 'Anna', points: 86, rank: 1),
      LeagueEntry(
        userId: 'me',
        displayName: 'Tu',
        points: 79,
        rank: 2,
        isCurrentUser: true,
      ),
      LeagueEntry(userId: 'marco', displayName: 'Marco', points: 72, rank: 3),
      LeagueEntry(userId: 'sara', displayName: 'Sara', points: 61, rank: 4),
    ];
    final municipalEntries = List.generate(
      12,
      (index) => LeagueEntry(
        userId: index == 4 ? 'me' : 'citizen-$index',
        displayName: index == 4 ? 'Tu' : 'Manager civico ${index + 1}',
        points: 104 - (index * 5),
        rank: index + 1,
        isCurrentUser: index == 4,
      ),
    );
    return [
      const FantasyLeague(
        id: 'friends',
        name: 'Amici del quartiere',
        entries: privateEntries,
        isMunicipal: false,
      ),
      FantasyLeague(
        id: 'municipal',
        name: 'Classifica comunale',
        entries: municipalEntries,
        isMunicipal: true,
        minimumParticipants: 10,
      ),
    ];
  }
}
