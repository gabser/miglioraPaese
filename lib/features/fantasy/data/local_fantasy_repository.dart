import 'dart:convert';

import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_game.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_saved_state.dart';
import 'fantasy_demo_seed.dart';
import 'fantasy_repository.dart';

class LocalFantasyRepository implements FantasyRepository {
  LocalFantasyRepository(
    this._prefs, {
    DateTime Function()? now,
    Matchday? initialMatchday,
    List<FantasyCard>? initialCards,
    List<CardOutcome>? initialOutcomes,
  }) : _now = now ?? DateTime.now,
       _initialMatchday = initialMatchday,
       _initialCards = initialCards,
       _initialOutcomes = initialOutcomes {
    _game = _fresh();
    final raw = _prefs.fantasyStateJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        _game.restore(
          FantasySavedState.fromJson(
            (jsonDecode(raw) as Map).cast<String, dynamic>(),
            _game.matchday,
          ),
        );
        // The fixture calendar follows the restored matchday, never a restart.
        _game = _copy(_game.savedState);
      } catch (_) {
        _recovery =
            'Dati demo incompatibili: partita ripristinata. Conferma nuovamente la formazione.';
      }
    }
  }

  final AppPrefs _prefs;
  final DateTime Function() _now;
  final Matchday? _initialMatchday;
  final List<FantasyCard>? _initialCards;
  final List<CardOutcome>? _initialOutcomes;
  late FantasyGame _game;
  int _revision = 0;
  bool _busy = false;
  String? _recovery;

  Matchday _defaultDay() {
    final time = _now();
    return Matchday(
      id: 'matchday-2',
      number: 2,
      startsAt: time.subtract(const Duration(days: 1)),
      locksAt: time.add(const Duration(days: 2, hours: 4)),
      observationEndsAt: time.add(const Duration(days: 7)),
    );
  }

  FantasyGame _fresh() => _copy(null);
  FantasyGame _copy(FantasySavedState? state) {
    final day = state?.matchday ?? _initialMatchday ?? _defaultDay();
    final seed = FantasyDemoSeed(_now(), day);
    return FantasyGame(
      matchday: day,
      cards: List.unmodifiable(_initialCards ?? seed.cards),
      outcomes: List.unmodifiable(_initialOutcomes ?? seed.seedOutcomes()),
      leagues: List.unmodifiable(seed.seedLeagues()),
      now: _now,
      usingDemoOutcomes: _initialOutcomes == null,
      restored: state,
    );
  }

  FantasyData _view(FantasyGame game) => FantasyData(
    state: game.savedState,
    cards: game.cards,
    outcomes: game.outcomes,
    leagues: game.leagues,
    serverTime: _now(),
    revision: _revision,
    isDemo: true,
    recoveryMessage: _recovery,
  );

  @override
  FantasyData get cached => _view(_game);

  void _check(int expectedRevision) {
    if (_busy) {
      throw const FantasyFailure(
        FantasyFailureKind.busy,
        'Operazione già in corso.',
      );
    }
    if (expectedRevision != _revision) {
      throw const FantasyFailure(
        FantasyFailureKind.staleRevision,
        'Dati aggiornati: ricarica e riprova.',
      );
    }
  }

  Future<FantasyData> _accept(FantasyGame next) async {
    try {
      await _prefs.setFantasyStateJson(jsonEncode(next.savedState.toJson()));
    } catch (_) {
      throw const FantasyFailure(
        FantasyFailureKind.storage,
        'Salvataggio non riuscito. La modifica non è stata confermata. Riprova.',
      );
    }
    _game = next;
    _revision++;
    return cached;
  }

  @override
  Future<FantasyData> load() =>
      synchronize(expectedRevision: _revision, persistUnchanged: true);

  @override
  Future<FantasyData> synchronize({
    required int expectedRevision,
    bool persistUnchanged = false,
  }) async {
    _check(expectedRevision);
    _busy = true;
    try {
      final next = _copy(_game.savedState);
      if (next.synchronize() || persistUnchanged) return await _accept(next);
      return cached;
    } finally {
      _busy = false;
    }
  }

  @override
  Future<FantasyData> execute(
    FantasyCommand command, {
    required int expectedRevision,
  }) async {
    _check(expectedRevision);
    _busy = true;
    try {
      final next = _copy(_game.savedState);
      next.synchronize();
      if (next.isLocked &&
          command is! ReflectOnFantasyCard &&
          command is! StartFantasyMatchday) {
        throw FantasyFailure(
          FantasyFailureKind.invalidCommand,
          command is TransferFantasyCard
              ? 'Mercato chiuso: giornata bloccata.'
              : 'Giornata bloccata: modifica non consentita.',
        );
      }
      final validTarget = switch (command) {
        SwapFantasyCards() =>
          next.starterIds.contains(command.starterId) &&
              next.benchIds.contains(command.reserveId),
        SetFantasyCaptain() => next.starterIds.contains(command.cardId),
        SetFantasyPrediction() => next.starterIds.contains(command.cardId),
        SetFantasyMotivation() => next.starterIds.contains(command.cardId),
        _ => true,
      };
      if (!validTarget) {
        throw const FantasyFailure(
          FantasyFailureKind.invalidCommand,
          'Carta non valida per questa operazione.',
        );
      }
      final before = jsonEncode(next.savedState.toJson());
      String? issue;
      switch (command) {
        case SwapFantasyCards():
          next.swapCards(
            starterId: command.starterId,
            reserveId: command.reserveId,
          );
        case SetFantasyCaptain():
          next.setCaptain(command.cardId);
        case ConfirmFantasyLineup():
          if (!next.confirmLineup()) {
            issue = next.lineupIssue ?? 'Conferma non consentita.';
          }
        case SetFantasyPrediction():
          next.setPrediction(command.cardId, command.trend);
        case SetFantasyMotivation():
          next.setMotivation(command.cardId, command.text);
        case TransferFantasyCard():
          issue = next.transfer(
            outgoingId: command.outgoingId,
            incomingId: command.incomingId,
            expectedPenalty: command.expectedPenalty,
          );
        case ReflectOnFantasyCard():
          if (!next.submitReflection(command.outcome, command.answer)) {
            issue = 'Riflessione non consentita o già confermata.';
          }
        case StartFantasyMatchday():
          final outcomes = FantasyDemoSeed(
            _now(),
            command.matchday,
          ).seedOutcomes();
          if (!next.startNextMatchday(command.matchday, outcomes)) {
            issue = 'Cambio giornata non consentito.';
          }
      }
      if (issue != null) {
        throw FantasyFailure(FantasyFailureKind.invalidCommand, issue);
      }
      if (before == jsonEncode(next.savedState.toJson())) return cached;
      return await _accept(next);
    } finally {
      _busy = false;
    }
  }

  @override
  Future<FantasyData> clear() async {
    _check(_revision);
    _busy = true;
    try {
      try {
        await _prefs.clearAll();
      } catch (_) {
        throw const FantasyFailure(
          FantasyFailureKind.storage,
          'Cancellazione non riuscita. Riprova.',
        );
      }
      _game = _fresh();
      _recovery = null;
      _revision++;
      return cached;
    } finally {
      _busy = false;
    }
  }
}
