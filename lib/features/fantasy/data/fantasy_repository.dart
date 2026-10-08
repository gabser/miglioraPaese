import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_saved_state.dart';

/// An accepted repository revision. Lists and maps cannot be changed by the UI.
class FantasyData {
  FantasyData({
    required this.state,
    required List<FantasyCard> cards,
    required List<CardOutcome> outcomes,
    required List<FantasyLeague> leagues,
    required this.serverTime,
    required this.revision,
    required this.isDemo,
    this.recoveryMessage,
  }) : cards = List.unmodifiable(cards),
       outcomes = List.unmodifiable(outcomes),
       leagues = List.unmodifiable(leagues);

  final FantasySavedState state;
  final List<FantasyCard> cards;
  final List<CardOutcome> outcomes;
  final List<FantasyLeague> leagues;
  final DateTime serverTime;
  final int revision;
  final bool isDemo;
  final String? recoveryMessage;
}

enum FantasyFailureKind { storage, staleRevision, invalidCommand, busy }

class FantasyFailure implements Exception {
  const FantasyFailure(this.kind, this.message);
  final FantasyFailureKind kind;
  final String message;
  @override
  String toString() => message;
}

/// The UI receives success only after the repository accepts a command.
/// Remote implementations must validate commands and revisions on the server;
/// they must never upload this local saved-state payload as authoritative data.
abstract interface class FantasyRepository {
  FantasyData? get cached;
  Future<FantasyData> load();
  Future<FantasyData> execute(
    FantasyCommand command, {
    required int expectedRevision,
  });
  Future<FantasyData> synchronize({required int expectedRevision});
  Future<FantasyData> clear();
}

sealed class FantasyCommand {
  const FantasyCommand();
}

class SwapFantasyCards extends FantasyCommand {
  const SwapFantasyCards(this.starterId, this.reserveId);
  final String starterId;
  final String reserveId;
}

class SetFantasyCaptain extends FantasyCommand {
  const SetFantasyCaptain(this.cardId);
  final String cardId;
}

class ConfirmFantasyLineup extends FantasyCommand {
  const ConfirmFantasyLineup();
}

class SetFantasyPrediction extends FantasyCommand {
  const SetFantasyPrediction(this.cardId, this.trend);
  final String cardId;
  final CivicTrend trend;
}

class SetFantasyMotivation extends FantasyCommand {
  const SetFantasyMotivation(this.cardId, this.text);
  final String cardId;
  final String text;
}

class TransferFantasyCard extends FantasyCommand {
  const TransferFantasyCard(
    this.outgoingId,
    this.incomingId,
    this.expectedPenalty,
  );
  final String outgoingId;
  final String incomingId;
  final int? expectedPenalty;
}

class ReflectOnFantasyCard extends FantasyCommand {
  const ReflectOnFantasyCard(this.outcome, this.answer);
  final CardOutcome outcome;
  final ReflectionAnswer answer;
}

/// Only the local demo host supports explicit day transitions.
class StartFantasyMatchday extends FantasyCommand {
  const StartFantasyMatchday(this.matchday);
  final Matchday matchday;
}
