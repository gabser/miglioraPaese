import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/data/local_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import '../fantasy_test_support.dart';

void main() {
  Future<ControlledPrefs> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return ControlledPrefs(await SharedPreferences.getInstance());
  }

  test(
    'failed command never publishes a confirmation and explicit retry accepts it',
    () async {
      final storage = await prefs();
      final manager = FantasyManager(
        storage,
        now: () => epoch,
        observeTime: false,
      );
      addTearDown(manager.dispose);
      await manager.settled;
      storage.fail = true;
      expect(await manager.confirmLineup(), isFalse);
      expect(manager.confirmed, isFalse);
      expect(jsonDecode(storage.fantasyStateJson!)['confirmed'], isFalse);
      expect(manager.persistenceError, contains('non è stata confermata'));
      storage.fail = false;
      await manager.retrySave();
      expect(manager.confirmed, isTrue);
      expect(manager.persistenceError, isNull);
    },
  );

  test(
    'a pending transfer leaves accepted roster unchanged and blocks double submit',
    () async {
      final storage = await prefs();
      final manager = FantasyManager(
        storage,
        now: () => epoch,
        observeTime: false,
      );
      addTearDown(manager.dispose);
      await manager.settled;
      storage.gate = Completer<void>();
      final first = manager.transfer(
        outgoingId: 'parco-nord',
        incomingId: 'fontanelle-ovest',
      );
      await Future<void>.delayed(Duration.zero);
      expect(manager.busy, isTrue);
      expect(manager.squadIds, contains('parco-nord'));
      expect(manager.transfers, isEmpty);
      final duplicate = await manager.transfer(
        outgoingId: 'parco-nord',
        incomingId: 'fontanelle-ovest',
      );
      expect(duplicate, contains('in corso'));
      storage.gate!.complete();
      expect(await first, isNull);
      await manager.settled;
      expect(manager.transfers, hasLength(1));
      expect(manager.squadIds, contains('fontanelle-ovest'));
      expect(manager.busy, isFalse);
    },
  );

  test(
    'loading failure is visible, has no fabricated data and supports retry',
    () async {
      final repository = DelayedRepository(
        LocalFantasyRepository(await prefs(), now: () => epoch),
      );
      final manager = FantasyManager.withRepository(
        repository,
        observeTime: false,
      );
      addTearDown(manager.dispose);
      expect(manager.loading, isTrue);
      expect(manager.hasData, isFalse);
      repository.read.completeError(
        const FantasyFailure(FantasyFailureKind.storage, 'Lettura fallita'),
      );
      await manager.settled;
      expect(manager.loading, isFalse);
      expect(manager.persistenceError, 'Lettura fallita');
      expect(await manager.confirmLineup(), isFalse);
      repository.read = Completer<FantasyData>();
      final retry = manager.retrySave();
      repository.read.complete(await repository.delegate.load());
      await retry;
      expect(manager.hasData, isTrue);
      expect(manager.loading, isFalse);
      expect(manager.persistenceError, isNull);
    },
  );

  test(
    'dispose during first read suppresses publication and notifications',
    () async {
      final repository = DelayedRepository(
        LocalFantasyRepository(await prefs(), now: () => epoch),
      );
      final manager = FantasyManager.withRepository(
        repository,
        observeTime: false,
      );
      var notifications = 0;
      manager.addListener(() => notifications++);
      manager.dispose();
      repository.read.complete(await repository.delegate.load());
      await manager.settled;
      expect(notifications, 0);
      expect(manager.hasData, isFalse);
      expect(await manager.confirmLineup(), isFalse);
    },
  );

  test(
    'dispose during a write allows persistence but never notifies a dead UI',
    () async {
      final storage = await prefs();
      final manager = FantasyManager(
        storage,
        now: () => epoch,
        observeTime: false,
      );
      await manager.settled;
      storage.gate = Completer<void>();
      var notifications = 0;
      manager.addListener(() => notifications++);
      final submitted = manager.confirmLineup();
      await Future<void>.delayed(Duration.zero);
      manager.dispose();
      final before = notifications;
      storage.gate!.complete();
      await submitted;
      await manager.settled;
      expect(notifications, before);
      expect(manager.confirmed, isFalse);
      expect(jsonDecode(storage.fantasyStateJson!)['confirmed'], isTrue);
    },
  );

  test(
    'stale revision is rejected without changing state or consuming a transfer',
    () async {
      final repository = LocalFantasyRepository(
        await prefs(),
        now: () => epoch,
      );
      final original = await repository.load();
      final accepted = await repository.execute(
        const SetFantasyCaptain('bus-stazione'),
        expectedRevision: original.revision,
      );
      await expectLater(
        repository.execute(
          const TransferFantasyCard('parco-nord', 'fontanelle-ovest', 0),
          expectedRevision: original.revision,
        ),
        throwsA(
          isA<FantasyFailure>().having(
            (e) => e.kind,
            'kind',
            FantasyFailureKind.staleRevision,
          ),
        ),
      );
      expect(repository.cached.revision, accepted.revision);
      expect(repository.cached.state.transfers, isEmpty);
      expect(repository.cached.state.captainId, 'bus-stazione');
      expect(
        () => repository.cached.state.predictions['buche-centro'] =
            CivicTrend.stable,
        throwsUnsupportedError,
      );
      expect(
        () => repository.cached.state.snapshots.clear(),
        throwsUnsupportedError,
      );
    },
  );
}

class DelayedRepository implements FantasyRepository {
  DelayedRepository(this.delegate);
  final FantasyRepository delegate;
  Completer<FantasyData> read = Completer<FantasyData>();
  @override
  FantasyData? get cached => null;
  @override
  Future<FantasyData> load() => read.future;
  @override
  Future<FantasyData> execute(
    FantasyCommand command, {
    required int expectedRevision,
  }) => delegate.execute(command, expectedRevision: expectedRevision);
  @override
  Future<FantasyData> synchronize({required int expectedRevision}) =>
      delegate.synchronize(expectedRevision: expectedRevision);
  @override
  Future<FantasyData> clear() => delegate.clear();
}
