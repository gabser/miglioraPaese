import 'dart:async';
import 'package:fanta_comune/features/fantasy/data/fantasy_league_repository.dart';
import 'package:fanta_comune/core/network/api_exception.dart';

import 'package:flutter/widgets.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/data/local_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_game.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';

/// Coordinates accepted repository state and the UI lifecycle.
class FantasyManager extends ChangeNotifier with WidgetsBindingObserver {
  factory FantasyManager(
    AppPrefs prefs, {
    DateTime Function()? now,
    Matchday? initialMatchday,
    List<FantasyCard>? initialCards,
    List<CardOutcome>? initialOutcomes,
    bool observeTime = true,
  }) => FantasyManager.withRepository(
    LocalFantasyRepository(
      prefs,
      now: now,
      initialMatchday: initialMatchday,
      initialCards: initialCards,
      initialOutcomes: initialOutcomes,
    ),
    now: now,
    observeTime: observeTime,
  );

  FantasyManager.withRepository(
    this._repository, {
    DateTime Function()? now,
    bool observeTime = true,
  }) : _now = now ?? DateTime.now {
    final cached = _repository.cached;
    if (cached != null) _apply(cached);
    _queue = _load();
    if (observeTime) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => refreshTime());
    }
  }

  final FantasyRepository _repository;
  final DateTime Function() _now;
  bool get isRemote => _repository is RemoteFantasyRepository;
  final Stopwatch _serverElapsed = Stopwatch();
  DateTime? _serverTime;
  final Stopwatch _pollClock = Stopwatch()..start();
  int _nextPoll = 0;
  int _pollDelay = 30000;
  FantasyData? _data;
  FantasyGame? _projection;
  Future<void> _queue = Future.value();
  Timer? _timer;
  bool _observing = false;
  bool _disposed = false;
  bool _clearing = false;
  bool _submitting = false;
  bool _refreshing = false;
  int _pending = 0;
  bool loading = true;
  FantasyCommand? _failedCommand;
  String? persistenceError;
  String? leagueError;
  bool leagueBusy = false;
  List<RemoteFantasyLeague> remoteLeagues = const [];
  Future<void> _readLeagues() async {
    if (_repository case final FantasyLeagueRepository repo) {
      try {
        final leagues = await repo.loadLeagues();
        if (!_disposed) {
          remoteLeagues = leagues;
          leagueError = null;
        }
      } catch (error) {
        if (!_disposed)
          leagueError = error is ApiException
              ? error.message
              : 'Leghe non disponibili. Riprova.';
      }
    }
  }

  Future<T?> _leagueCommand<T>(
    Future<T> Function(FantasyLeagueRepository repo) action,
  ) async {
    if (busy ||
        leagueBusy ||
        _disposed ||
        _repository is! FantasyLeagueRepository)
      return null;
    leagueBusy = true;
    _notify();
    T? value;
    _queue = _queue.then((_) async {
      try {
        if (_disposed || _clearing) return;
        value = await action(_repository as FantasyLeagueRepository);
        await _readLeagues();
      } catch (error) {
        leagueError = error is ApiException ? error.message : error.toString();
      } finally {
        leagueBusy = false;
        _notify();
      }
    });
    await _queue;
    return value;
  }

  Future<bool> createLeague(String name) async =>
      await _leagueCommand((repo) async {
        await repo.createLeague(name);
        return true;
      }) ??
      false;
  Future<bool> joinLeague(String token) async =>
      await _leagueCommand((repo) async {
        await repo.joinLeague(token);
        return true;
      }) ??
      false;
  Future<bool> leaveLeague(String id) async =>
      await _leagueCommand((repo) async {
        await repo.leaveLeague(id);
        return true;
      }) ??
      false;
  Future<FantasyLeagueInvite?> rotateInvite(String id) =>
      _leagueCommand((repo) => repo.rotateInvite(id));
  Future<bool> revokeInvite(String leagueId, String inviteId) async =>
      await _leagueCommand((repo) async {
        await repo.revokeInvite(leagueId, inviteId);
        return true;
      }) ??
      false;
  Future<void> refreshLeagues() async {
    await _leagueCommand((repo) async {
      await _readLeagues();
      return true;
    });
  }

  String? get recoveryMessage => _data?.recoveryMessage;
  bool get hasData => _projection != null;
  bool get busy =>
      leagueBusy || loading || _pending > 0 || _submitting || _clearing;
  int get revision => _data?.revision ?? 0;

  FantasyGame get _game => _projection!;
  void _apply(FantasyData data) {
    _data = data;
    _serverTime = data.serverTime;
    _serverElapsed
      ..reset()
      ..start();
    _projection = FantasyGame(
      matchday: data.state.matchday,
      cards: data.cards,
      outcomes: data.outcomes,
      leagues: data.leagues,
      now: () => this.now,
      usingDemoOutcomes: false,
      restored: data.state,
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _load() async {
    loading = true;
    try {
      final data = await _repository.load();
      if (!_disposed) {
        _apply(data);
        await _readLeagues();
        persistenceError =
            isRemote &&
                (_repository as RemoteFantasyRepository).hasPendingTransfer
            ? 'Trasferimento da verificare: premi Riprova.'
            : null;
      }
    } catch (error) {
      if (!_disposed) _error(error);
    } finally {
      loading = false;
      _notify();
    }
  }

  void _error(Object error) {
    persistenceError = error is FantasyFailure
        ? error.message
        : error is ApiException
        ? '${error.message} Stato di sola lettura: Riprova.'
        : 'Operazione non riuscita. Riprova.';
  }

  Future<bool> _command(FantasyCommand command, {bool exclusive = false}) {
    if ((isRemote && (busy || persistenceError != null)) ||
        _disposed ||
        _clearing ||
        (exclusive && (_submitting || loading))) {
      return Future.value(false);
    }
    if (exclusive) _submitting = true;
    _pending++;
    _notify();
    final result = _queue.then((_) async {
      if (_disposed || loading || !hasData) return false;
      try {
        final data = await _repository.execute(
          command,
          expectedRevision: revision,
        );
        if (!_disposed) {
          _apply(data);
          await _readLeagues();
          persistenceError = null;
          _failedCommand = null;
        }
        return true;
      } catch (error) {
        if (!_disposed) {
          _error(error);
          _failedCommand =
              error is FantasyFailure &&
                  error.kind == FantasyFailureKind.storage
              ? command
              : null;
          if (error is FantasyFailure &&
              error.kind == FantasyFailureKind.staleRevision) {
            await _load();
          }
        }
        return false;
      }
    });
    _queue = result.then((_) {
      _pending--;
      if (exclusive) _submitting = false;
      _notify();
    });
    return result;
  }

  Future<void> get settled => _queue;
  Future<void> retrySave() async {
    if (_disposed || _clearing || busy) return;
    if (isRemote &&
        (_repository as RemoteFantasyRepository).hasPendingTransfer) {
      loading = true;
      _notify();
      _queue = () async {
        try {
          _apply(await _repository.retryPendingTransfer());
          persistenceError = null;
        } catch (error) {
          _error(error);
        } finally {
          loading = false;
          _notify();
        }
      }();
      await _queue;
      return;
    }
    final command = _failedCommand;
    if (command != null) {
      await _command(command, exclusive: true);
    } else {
      _queue = _load();
      await _queue;
    }
  }

  Future<void> swapCards({
    required String starterId,
    required String reserveId,
  }) async {
    await _command(SwapFantasyCards(starterId, reserveId));
  }

  Future<void> setCaptain(String id) async {
    await _command(SetFantasyCaptain(id));
  }

  Future<bool> confirmLineup() =>
      _command(const ConfirmFantasyLineup(), exclusive: true);
  Future<void> setPrediction(String id, CivicTrend trend) async {
    await _command(SetFantasyPrediction(id, trend));
  }

  Future<void> setMotivation(String id, String text) async {
    await _command(SetFantasyMotivation(id, text));
  }

  Future<String?> transfer({
    required String outgoingId,
    required String incomingId,
    int? expectedPenalty,
    FantasyTransferQuote? quote,
  }) async {
    if (busy) return 'Operazione già in corso.';
    final accepted = await _command(
      TransferFantasyCard(
        outgoingId,
        incomingId,
        expectedPenalty,
        quote: quote,
      ),
      exclusive: true,
    );
    return accepted
        ? null
        : persistenceError ?? 'Trasferimento non consentito.';
  }

  Future<bool> submitReflection(CardOutcome outcome, ReflectionAnswer answer) =>
      _command(ReflectOnFantasyCard(outcome, answer), exclusive: true);
  Future<bool> startNextMatchday(Matchday next) =>
      _command(StartFantasyMatchday(next), exclusive: true);

  Future<FantasyTransferQuote?> quoteTransfer(
    String outgoing,
    String incoming,
  ) async {
    if (!isRemote || busy || persistenceError != null) return null;
    _submitting = true;
    _notify();
    try {
      return await (_repository as RemoteFantasyRepository).quoteTransfer(
        outgoing,
        incoming,
        revision,
      );
    } catch (error) {
      _error(error);
      if (error is FantasyFailure &&
          error.kind == FantasyFailureKind.staleRevision)
        await _load();
      return null;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  Future<void> refreshTime({bool force = false}) {
    if (_disposed || _clearing || loading || _refreshing || !hasData) {
      return settled;
    }
    if (isRemote) {
      _notify();
      if (busy || (!force && _pollClock.elapsedMilliseconds < _nextPoll))
        return settled;
      _nextPoll = _pollClock.elapsedMilliseconds + _pollDelay;
    }
    _refreshing = true;
    _notify(); // Disable controls at the clock boundary while persistence completes.
    _queue = _queue
        .then((_) async {
          if (_disposed || _clearing) return;
          try {
            final data = await _repository.synchronize(
              expectedRevision: revision,
            );
            if (!_disposed) {
              _apply(data);
              await _readLeagues();
              persistenceError =
                  isRemote &&
                      (_repository as RemoteFantasyRepository)
                          .hasPendingTransfer
                  ? 'Trasferimento da verificare: premi Riprova.'
                  : null;
              _pollDelay = 30000;
            }
          } catch (error) {
            if (!_disposed) _error(error);
            _pollDelay = (_pollDelay * 2).clamp(30000, 300000);
            _nextPoll = _pollClock.elapsedMilliseconds + _pollDelay;
          }
        })
        .whenComplete(() {
          _refreshing = false;
          _notify();
        });
    return _queue;
  }

  Future<void> clearLocalData() async {
    if (_disposed || _clearing) return;
    _clearing = true;
    _notify();
    try {
      await settled;
      final data = await _repository.clear();
      if (!_disposed) {
        if (data != null) {
          _apply(data);
        } else {
          _data = null;
          _projection = null;
          remoteLeagues = const [];
          leagueError = null;
        }
        _failedCommand = null;
        persistenceError = null;
      }
    } catch (error) {
      if (!_disposed) _error(error);
      rethrow;
    } finally {
      _clearing = false;
      _notify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refreshTime(force: true));
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  FantasySeason get season => _data?.season ?? _game.season;
  Matchday get matchday => _game.matchday;
  DateTime get now => isRemote && _serverTime != null
      ? _serverTime!.add(_serverElapsed.elapsed)
      : _now();
  bool get isLocked =>
      _clearing ||
      !hasData ||
      (isRemote && persistenceError != null) ||
      _game.isLocked;
  List<FantasyCard> get cards => _game.cards;
  List<FantasyLeague> get leagues => _game.leagues;
  List<String> get squadIds => _game.squadIds;
  List<String> get starterIds => _game.starterIds;
  List<String> get benchIds => _game.benchIds;
  String get captainId => _game.captainId;
  bool get confirmed => _game.confirmed;
  Map<String, CivicTrend> get predictions => _game.predictions;
  Map<String, String> get motivations => _game.motivations;
  List<Transfer> get transfers => _game.transfers;
  int get transfersRemaining => _game.transfersRemaining;
  int get nextTransferPenalty => _game.nextTransferPenalty;
  int? get communityScore => isRemote ? null : _game.communityScore;
  int get transferPenalty => _game.transferPenalty;
  Squad get squad => _game.squad;
  Lineup get lineup => _game.lineup;
  List<FantasyCard> get squadCards => _game.squadCards;
  List<FantasyCard> get starterCards => _game.starterCards;
  List<FantasyCard> get benchCards => _game.benchCards;
  List<FantasyCard> get marketCards => _game.marketCards;
  int get squadCost => _game.squadCost;
  int get budgetRemaining => _game.budgetRemaining;
  int get predictionsCompleted => _game.predictionsCompleted;
  String? get lineupIssue => _game.lineupIssue;
  FantasyCard cardById(String id) => _game.cardById(id);
  String? purchaseIssue(FantasyCard card) => _game.purchaseIssue(card);
  MatchdaySnapshot? snapshotFor(String dayId) => _game.snapshotFor(dayId);
  List<CardOutcome> get outcomes => _game.outcomes;
  CivicTrend? predictionFor(CardOutcome o) => _game.predictionFor(o);
  ReflectionAnswer? reflectionFor(CardOutcome o) => _game.reflectionFor(o);
  bool hasPersonalResult(CardOutcome o) => _game.hasPersonalResult(o);
  ScoreBreakdown scoreFor(CardOutcome o) => isRemote
      ? _data!.scores['${o.matchdayId}/${o.cardId}'] ??
            const ScoreBreakdown(
              cardId: '',
              observationPoints: 0,
              predictionPoints: 0,
              reflectionPoints: 0,
              captainMultiplier: 1,
            )
      : _game.scoreFor(o);
  MatchdayScore scoreForMatchday(String dayId) => isRemote
      ? _data!.summaries[dayId] ??
            const MatchdayScore(
              frozenPoints: 0,
              reflectionBonus: 0,
              transferPenalty: 0,
              eligible: false,
            )
      : _game.scoreForMatchday(dayId);
  String summaryStatus(String dayId) =>
      _data?.summaryStatuses[dayId] ?? 'provisional';
}
