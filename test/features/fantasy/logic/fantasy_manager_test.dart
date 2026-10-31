import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import '../fantasy_test_support.dart';

void main() {
  test(
    'over-budget stored roster is rejected before any field is applied',
    () async {
      final h = await createHarness();
      final payload =
          jsonDecode(h.prefs.fantasyStateJson!) as Map<String, dynamic>;
      (payload['squadIds'] as List)[2] = 'expensive';
      (payload['starterIds'] as List)[2] = 'expensive';
      payload['captainId'] = 'bus-stazione';
      await h.prefs.setFantasyStateJson(jsonEncode(payload));
      final expensive = FantasyCard(
        id: 'expensive',
        title: 'Demo',
        zone: 'Demo',
        role: FantasyRole.environment,
        price: 100,
        form: const [CivicTrend.stable],
        observationWindow: '7 giorni',
        sourceStatus: FantasySourceStatus.verified,
        sourceLabel: 'Demo',
        sourceUpdatedAt: epoch,
        popularity: 0,
        illustrationKey: 'park',
      );
      final restored = FantasyManager(
        h.prefs,
        now: () => epoch,
        initialCards: [...h.manager.cards, expensive],
        observeTime: false,
      );
      addTearDown(restored.dispose);
      expect(restored.recoveryMessage, isNotNull);
      expect(restored.captainId, 'buche-centro');
      expect(restored.budgetRemaining, 15);
    },
  );

  test(
    'published outcome itself remains stable after provider data changes on restart',
    () async {
      final h = await createHarness();
      await h.manager.confirmLineup();
      await h.at(day.observationEndsAt);
      await h.manager.settled;
      final restored = FantasyManager(
        h.prefs,
        now: () => h.time,
        observeTime: false,
        initialOutcomes: [result(observed: CivicTrend.improves)],
      );
      addTearDown(restored.dispose);
      expect(restored.outcomes.single.observed, CivicTrend.stable);
      expect(
        restored.scoreFor(result()).total,
        h.manager.scoreFor(result()).total,
      );
    },
  );

  test(
    'privacy reset drains queued writes and blocks edits until data is cleared',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = ControlledPrefs(await SharedPreferences.getInstance());
      final h = Harness(prefs);
      await h.manager.settled;
      prefs.gate = Completer<void>();
      unawaited(h.manager.setPrediction('buche-centro', CivicTrend.stable));
      await Future<void>.delayed(Duration.zero);
      final cleared = h.manager.clearLocalData();
      await h.manager.setMotivation('buche-centro', 'Must not be saved');
      expect(h.manager.isLocked, isTrue);
      prefs.gate!.complete();
      prefs.gate = null;
      await cleared;
      await h.manager.settled;
      expect(prefs.fantasyStateJson, isNull);
      expect(h.manager.predictions, isEmpty);
      expect(h.manager.motivations, isEmpty);
      expect(h.manager.confirmed, isFalse);
      expect(h.manager.isLocked, isFalse);
    },
  );

  test('seed respects roster, lineup, roles and budget', () async {
    final h = await createHarness();
    expect(h.manager.squadIds, hasLength(8));
    expect(h.manager.starterIds, hasLength(5));
    expect(h.manager.benchIds, hasLength(3));
    expect(h.manager.budgetRemaining, 15);
    expect(h.manager.lineupIssue, isNull);
  });

  test(
    'dates, swaps, captain, prediction and motivation survive reload',
    () async {
      final h = await createHarness();
      await h.manager.swapCards(
        starterId: 'buche-centro',
        reserveId: 'attraversamenti-scuole',
      );
      await h.manager.setCaptain('attraversamenti-scuole');
      await h.manager.setPrediction(
        'attraversamenti-scuole',
        CivicTrend.improves,
      );
      await h.manager.setMotivation(
        'attraversamenti-scuole',
        'Nuovo attraversamento',
      );
      h.time = epoch.add(const Duration(hours: 1));
      final restored = await h.reload();
      expect(restored.matchday.locksAt, day.locksAt);
      expect(restored.matchday.observationEndsAt, day.observationEndsAt);
      expect(restored.captainId, 'attraversamenti-scuole');
      expect(
        restored.motivations['attraversamenti-scuole'],
        'Nuovo attraversamento',
      );
      expect(
        restored.predictions['attraversamenti-scuole'],
        CivicTrend.improves,
      );
    },
  );

  for (final offset in [-1, 0, 1]) {
    test('lock boundary at ${offset}ms applies to every operation', () async {
      final h = await createHarness();
      h.time = day.locksAt.add(Duration(milliseconds: offset));
      await h.manager.setPrediction('buche-centro', CivicTrend.stable);
      await h.manager.setMotivation('buche-centro', 'Segnale');
      await h.manager.setCaptain('bus-stazione');
      await h.manager.swapCards(
        starterId: 'bus-stazione',
        reserveId: 'attraversamenti-scuole',
      );
      final transferError = await h.manager.transfer(
        outgoingId: 'parco-nord',
        incomingId: 'fontanelle-ovest',
      );
      final confirmed = await h.manager.confirmLineup();
      if (offset < 0) {
        expect(transferError, isNull);
        expect(confirmed, isTrue);
        expect(h.manager.isLocked, isFalse);
      } else {
        expect(transferError, contains('chiuso'));
        expect(confirmed, isFalse);
        expect(h.manager.captainId, 'buche-centro');
        expect(h.manager.predictions, isEmpty);
        expect(h.manager.motivations, isEmpty);
        expect(h.manager.starterIds, contains('bus-stazione'));
        expect(h.manager.squadIds, contains('parco-nord'));
      }
    });
  }

  test(
    'lock is recovered after offline restart and remains closed if clock rolls back',
    () async {
      final h = await createHarness();
      await h.manager.setPrediction('buche-centro', CivicTrend.stable);
      await h.manager.confirmLineup();
      h.time = day.locksAt;
      final restored = await h.reload();
      expect(restored.snapshotFor(day.id)!.eligible, isTrue);
      expect(
        restored.snapshotFor(day.id)!.predictions['buche-centro'],
        CivicTrend.stable,
      );
      h.time = epoch;
      await restored.setPrediction('buche-centro', CivicTrend.worsens);
      expect(restored.isLocked, isTrue);
      expect(restored.predictions['buche-centro'], CivicTrend.stable);
    },
  );

  test(
    'published score and prediction are immutable across a new matchday and restart',
    () async {
      final h = await createHarness();
      await h.manager.setPrediction('buche-centro', CivicTrend.improves);
      await h.manager.confirmLineup();
      await h.at(day.observationEndsAt);
      final total = h.manager.scoreFor(result()).total;
      expect(total, 5); // (stable 1 + adjacent prediction 2) * 1.5, rounded.
      expect(await h.manager.startNextMatchday(nextDay), isTrue);
      await h.manager.setPrediction('buche-centro', CivicTrend.stable);
      await h.manager.setCaptain('bus-stazione');
      expect(h.manager.scoreFor(result()).total, total);
      expect(h.manager.predictionFor(result()), CivicTrend.improves);
      final restored = await h.reload();
      expect(restored.scoreFor(result()).total, total);
      expect(restored.predictionFor(result()), CivicTrend.improves);
    },
  );

  test(
    'unconfirmed or invalid formation receives zero including reflection',
    () async {
      for (final invalid in [false, true]) {
        final h = await createHarness();
        if (invalid) {
          await h.manager.swapCards(
            starterId: 'lampioni-sud',
            reserveId: 'alberi-viale',
          );
          expect(await h.manager.confirmLineup(), isFalse);
        }
        await h.at(day.observationEndsAt);
        expect(h.manager.scoreFor(result()).total, 0);
        expect(h.manager.scoreForMatchday(day.id).total, 0);
        expect(
          await h.manager.submitReflection(
            result(),
            ReflectionAnswer.externalConditions,
          ),
          isFalse,
        );
        final restored = await h.reload();
        expect(restored.scoreForMatchday(day.id).total, 0);
      }
    },
  );

  test(
    'reflection starts at zero, is only accepted after reveal and is idempotent',
    () async {
      final h = await createHarness();
      await h.manager.setPrediction('buche-centro', CivicTrend.stable);
      await h.manager.confirmLineup();
      expect(
        await h.manager.submitReflection(
          result(),
          ReflectionAnswer.externalConditions,
        ),
        isFalse,
      );
      await h.at(day.locksAt);
      expect(
        await h.manager.submitReflection(
          result(),
          ReflectionAnswer.externalConditions,
        ),
        isFalse,
      );
      await h.at(day.observationEndsAt);
      expect(h.manager.scoreFor(result()).reflectionPoints, 0);
      expect(h.manager.scoreFor(result()).total, 8);
      expect(
        await h.manager.submitReflection(
          result(),
          ReflectionAnswer.externalConditions,
        ),
        isTrue,
      );
      expect(h.manager.scoreFor(result()).total, 9);
      expect(
        await h.manager.submitReflection(
          result(),
          ReflectionAnswer.insufficientInformation,
        ),
        isFalse,
      );
      final restored = await h.reload();
      expect(restored.scoreFor(result()).total, 9);
      expect(
        restored.reflectionFor(result()),
        ReflectionAnswer.externalConditions,
      );
      expect(
        await restored.submitReflection(
          result(),
          ReflectionAnswer.externalConditions,
        ),
        isFalse,
      );
    },
  );

  test(
    'unverified, reserve and historical demo outcomes award no personal points',
    () async {
      final h = await createHarness();
      final other = FantasyManager(
        h.prefs,
        now: () => h.time,
        initialMatchday: day,
        initialOutcomes: [
          result(status: FantasySourceStatus.pending),
          result(cardId: 'alberi-viale'),
          result(dayId: 'matchday-1'),
        ],
        observeTime: false,
      );
      addTearDown(other.dispose);
      await other.settled;
      await other.confirmLineup();
      h.time = day.observationEndsAt;
      await other.refreshTime();
      for (final outcome in other.outcomes) {
        expect(other.scoreFor(outcome).total, 0);
        expect(other.hasPersonalResult(outcome), isFalse);
        expect(
          await other.submitReflection(
            outcome,
            ReflectionAnswer.observedIntervention,
          ),
          isFalse,
        );
      }
    },
  );

  test(
    'third and fourth transfers charge once; negative total survives reload',
    () async {
      final h = await createHarness();
      for (var i = 0; i < 4; i++) {
        expect(h.manager.nextTransferPenalty, i < 2 ? 0 : 4);
        expect(
          await h.manager.transfer(
            outgoingId: i.isEven ? 'parco-nord' : 'fontanelle-ovest',
            incomingId: i.isEven ? 'fontanelle-ovest' : 'parco-nord',
          ),
          isNull,
        );
      }
      await h.manager.confirmLineup();
      await h.at(day.observationEndsAt);
      expect(h.manager.transfersRemaining, 0);
      expect(h.manager.transferPenalty, 8);
      expect(h.manager.scoreForMatchday(day.id).total, -6);
      expect(h.manager.scoreForMatchday(day.id).total, -6);
      final restored = await h.reload();
      expect(restored.scoreForMatchday(day.id).transferPenalty, 8);
      expect(restored.scoreForMatchday(day.id).total, -6);
      expect(h.manager.communityScore, 68);
    },
  );

  test(
    'invalid and stale transfer confirmations do not consume transfers',
    () async {
      final h = await createHarness();
      expect(
        await h.manager.transfer(
          outgoingId: 'lampioni-sud',
          incomingId: 'fontanelle-ovest',
        ),
        contains('meno di 2'),
      );
      expect(
        await h.manager.transfer(
          outgoingId: 'parco-nord',
          incomingId: 'missing',
        ),
        isNotNull,
      );
      expect(
        await h.manager.transfer(
          outgoingId: 'parco-nord',
          incomingId: 'ciclabile-est',
        ),
        contains('Fonte non disponibile'),
      );
      expect(
        await h.manager.transfer(
          outgoingId: 'parco-nord',
          incomingId: 'fontanelle-ovest',
          expectedPenalty: 4,
        ),
        contains('penalità è cambiata'),
      );
      expect(h.manager.transfersRemaining, 2);
      expect(h.manager.transfers, isEmpty);
    },
  );

  test(
    'explicitly unavailable and over-budget cards are refused; pending source is allowed',
    () async {
      final h = await createHarness();
      FantasyCard custom(
        String id, {
        int price = 7,
        CardAvailability availability = CardAvailability.available,
      }) => FantasyCard(
        id: id,
        title: id,
        zone: 'Demo',
        role: FantasyRole.environment,
        price: price,
        form: const [CivicTrend.stable],
        observationWindow: '7 giorni',
        sourceStatus: FantasySourceStatus.pending,
        sourceLabel: 'Demo',
        sourceUpdatedAt: epoch,
        popularity: 0,
        illustrationKey: 'park',
        availability: availability,
      );
      final manager = FantasyManager(
        h.prefs,
        now: () => h.time,
        initialMatchday: day,
        initialCards: [
          ...h.manager.cards,
          custom('unavailable', availability: CardAvailability.unavailable),
          custom('expensive', price: 100),
          custom('pending'),
        ],
        observeTime: false,
      );
      addTearDown(manager.dispose);
      await manager.settled;
      expect(
        await manager.transfer(
          outgoingId: 'parco-nord',
          incomingId: 'unavailable',
        ),
        contains('non disponibile'),
      );
      expect(
        await manager.transfer(
          outgoingId: 'parco-nord',
          incomingId: 'expensive',
        ),
        contains('insufficienti'),
      );
      expect(
        await manager.transfer(outgoingId: 'parco-nord', incomingId: 'pending'),
        isNull,
      );
      expect(manager.transfers, hasLength(1));
    },
  );

  test(
    'new day resets free transfer allowance and preserves previous penalties',
    () async {
      final h = await createHarness();
      await h.manager.transfer(
        outgoingId: 'parco-nord',
        incomingId: 'fontanelle-ovest',
      );
      expect(await h.manager.startNextMatchday(nextDay), isFalse);
      await h.at(day.observationEndsAt);
      expect(await h.manager.startNextMatchday(nextDay), isTrue);
      expect(h.manager.transfersRemaining, 2);
      expect(
        await h.manager.transfer(
          outgoingId: 'fontanelle-ovest',
          incomingId: 'parco-nord',
        ),
        isNull,
      );
      expect(h.manager.transfers.last.matchdayId, nextDay.id);
      expect(h.manager.transfers.last.cost, 0);
      final restored = await h.reload();
      expect(restored.transfersRemaining, 1);
      expect(restored.snapshotFor(day.id), isNotNull);
    },
  );

  test(
    'legacy payload migrates valid values and recomputes transfer penalties without history',
    () async {
      final h = await createHarness();
      final payload =
          jsonDecode(h.prefs.fantasyStateJson!) as Map<String, dynamic>;
      payload.remove('version');
      payload['confirmed'] = true;
      payload['predictions'] = {'buche-centro': 'stable'};
      payload['transfers'] = List.generate(
        4,
        (index) => {
          'outgoingCardId': index.isEven ? 'parco-nord' : 'fontanelle-ovest',
          'incomingCardId': index.isEven ? 'fontanelle-ovest' : 'parco-nord',
          'createdAt': epoch.toIso8601String(),
          'cost': 999,
        },
      );
      await h.prefs.setFantasyStateJson(jsonEncode(payload));
      final manager = FantasyManager(
        h.prefs,
        now: () => epoch,
        initialMatchday: day,
        observeTime: false,
      );
      addTearDown(manager.dispose);
      await manager.settled;
      await manager.settled;
      expect(manager.confirmed, isTrue);
      expect(manager.predictions['buche-centro'], CivicTrend.stable);
      expect(manager.transferPenalty, 8);
      expect(manager.snapshotFor('matchday-1'), isNull);
      expect((jsonDecode(h.prefs.fantasyStateJson!) as Map)['version'], 2);
    },
  );

  for (final corruption in [
    'id',
    'duplicate',
    'captain',
    'enum',
    'snapshot',
    'version',
    'json',
  ]) {
    test('corrupt $corruption state restores atomically', () async {
      final h = await createHarness();
      await h.manager.setCaptain('bus-stazione');
      await h.manager.confirmLineup();
      await h.at(day.locksAt);
      await h.manager.settled;
      final payload =
          jsonDecode(h.prefs.fantasyStateJson!) as Map<String, dynamic>;
      switch (corruption) {
        case 'id':
          (payload['squadIds'] as List)[0] = 'missing';
        case 'duplicate':
          (payload['squadIds'] as List)[0] = 'bus-stazione';
        case 'captain':
          payload['captainId'] = 'alberi-viale';
        case 'enum':
          payload['predictions'] = {'buche-centro': 'unknown'};
        case 'snapshot':
          (payload['snapshots'] as List).first['captainId'] = 'alberi-viale';
        case 'version':
          payload['version'] = 99;
        case 'json':
          break;
      }
      await h.prefs.setFantasyStateJson(
        corruption == 'json' ? '{' : jsonEncode(payload),
      );
      final restored = FantasyManager(
        h.prefs,
        now: () => epoch,
        observeTime: false,
      );
      addTearDown(restored.dispose);
      expect(restored.recoveryMessage, isNotNull);
      expect(restored.captainId, 'buche-centro');
      expect(restored.confirmed, isFalse);
      expect(restored.predictions, isEmpty);
      expect(restored.snapshotFor(day.id), isNull);
    });
  }

  test(
    'queued saves stay ordered; failure is visible and can be retried',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = ControlledPrefs(await SharedPreferences.getInstance());
      final h = Harness(prefs);
      await h.manager.settled;
      final count = prefs.writes.length;
      prefs.gate = Completer<void>();
      unawaited(h.manager.setPrediction('buche-centro', CivicTrend.improves));
      unawaited(h.manager.setPrediction('buche-centro', CivicTrend.stable));
      unawaited(h.manager.setMotivation('buche-centro', 'Latest'));
      await Future<void>.delayed(Duration.zero);
      expect(prefs.writes, hasLength(count));
      prefs.gate!.complete();
      prefs.gate = null;
      await h.manager.settled;
      expect(prefs.writes, hasLength(count + 3));
      expect(
        (jsonDecode(prefs.writes[count]) as Map)['predictions']['buche-centro'],
        'improves',
      );
      expect(
        (jsonDecode(prefs.writes[count + 1])
            as Map)['predictions']['buche-centro'],
        'stable',
      );
      final saved = jsonDecode(prefs.writes.last) as Map;
      expect(saved['predictions']['buche-centro'], 'stable');
      expect(saved['motivations']['buche-centro'], 'Latest');
      prefs.fail = true;
      await h.manager.setMotivation('buche-centro', 'Retry me');
      await h.manager.settled;
      expect(h.manager.persistenceError, isNotNull);
      prefs.fail = false;
      await h.manager.retrySave();
      expect(h.manager.persistenceError, isNull);
      expect(
        (jsonDecode(prefs.writes.last) as Map)['motivations']['buche-centro'],
        'Retry me',
      );
    },
  );
}
