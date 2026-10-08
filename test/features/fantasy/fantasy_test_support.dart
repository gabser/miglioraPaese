import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';

final epoch = DateTime.utc(2026, 10, 8);
final day = Matchday(
  id: 'matchday-2',
  number: 2,
  startsAt: epoch,
  locksAt: epoch.add(const Duration(days: 1)),
  observationEndsAt: epoch.add(const Duration(days: 2)),
);
final nextDay = Matchday(
  id: 'matchday-3',
  number: 3,
  startsAt: day.observationEndsAt,
  locksAt: epoch.add(const Duration(days: 3)),
  observationEndsAt: epoch.add(const Duration(days: 4)),
);

CardOutcome result({
  String dayId = 'matchday-2',
  String cardId = 'buche-centro',
  CivicTrend observed = CivicTrend.stable,
  FantasySourceStatus status = FantasySourceStatus.verified,
}) => CardOutcome(
  matchdayId: dayId,
  cardId: cardId,
  observed: observed,
  sourceLabel: 'Fonte demo',
  sourceDate: dayId == nextDay.id
      ? nextDay.observationEndsAt
      : day.observationEndsAt,
  explanation: 'Esito simulato',
  sourceStatus: status,
);

class Harness {
  Harness(this.prefs) {
    manager = FantasyManager(
      prefs,
      now: () => time,
      initialMatchday: day,
      initialOutcomes: [
        result(),
        result(dayId: nextDay.id),
      ],
      observeTime: false,
    );
    addTearDown(manager.dispose);
  }
  final AppPrefs prefs;
  DateTime time = epoch;
  late final FantasyManager manager;
  Future<void> at(DateTime value) async {
    time = value;
    await manager.refreshTime();
  }

  Future<FantasyManager> reload() async {
    await manager.settled;
    final restored = FantasyManager(
      prefs,
      now: () => time,
      observeTime: false,
      initialOutcomes: [
        result(),
        result(dayId: nextDay.id),
      ],
    );
    addTearDown(restored.dispose);
    await restored.settled;
    return restored;
  }
}

Future<Harness> createHarness() async {
  SharedPreferences.setMockInitialValues({});
  final h = Harness(await AppPrefs.init());
  await h.manager.settled;
  return h;
}

class ControlledPrefs extends AppPrefs {
  ControlledPrefs(super.prefs);
  bool fail = false;
  Completer<void>? gate;
  final List<String> writes = [];
  @override
  Future<void> setFantasyStateJson(String value) async {
    final currentGate = gate;
    if (currentGate != null) await currentGate.future;
    if (fail) throw StateError('disk full');
    writes.add(value);
    await super.setFantasyStateJson(value);
  }
}
