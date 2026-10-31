import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/features/cooperation/cooperation_repository.dart';
import 'package:fanta_comune/features/cooperation/cooperation_models.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import '../../support/fantasy_backend.dart';
import '../missions/mission_postgres_test.dart'
    show RealDevice, MissionTransport;
import '../review/review_postgres_test.dart'
    show grant, review, ReviewTransport;
import 'package:fanta_comune/core/network/api_exception.dart';

Map<String, Object?> calendar(int week) {
  final at = DateTime.utc(2026, 12, 1).add(Duration(days: (week - 1) * 7));
  String date(int d) => at.add(Duration(days: d)).toIso8601String();
  final s = 'cooperation-week-$week';
  final cards =
      (jsonDecode(
                File(
                  'services/backend/src/domain/fantasy/cards.demo.json',
                ).readAsStringSync(),
              )
              as List)
          .map(
            (v) => {
              ...(v as Map).cast<String, Object?>(),
              'id': '$s-${v['id']}',
              'version': 1,
              'sourceStatus': 'pending',
            },
          )
          .toList();
  return {
    'idempotencyKey': 'synthetic-calendar-flutter-week-$week',
    'municipalityId': 'tuglie',
    'season': {
      'id': s,
      'name': 'Settimana sintetica $week',
      'startsAt': date(0),
      'endsAt': date(5),
      'catalogVersion': 1,
      'synthetic': true,
    },
    'cards': cards,
    'matchdays': [
      {
        'id': '$s-day',
        'number': 1,
        'startsAt': date(0),
        'locksAt': date(1),
        'observationEndsAt': date(3),
        'closeAt': date(4),
      },
    ],
    'missions': [
      {
        'id': '$s-mission',
        'zoneId': 'synthetic-centre',
        'title': 'Controllo sintetico settimana $week',
        'area': {
          'label': 'Area sintetica',
          'boundary': 'Solo fixture locale',
          'public': true,
        },
        'placeId': '$s-place',
        'durationMinutes': 15,
        'matchdayId': '$s-day',
        'cardId': '$s-rifiuti-mercato',
        'baseline': {
          'value': 10,
          'unit': 'items',
          'measuredAt': '2026-10-01T00:00:00Z',
          'label': 'Baseline sintetica',
          'provenance': 'Fixture locale esplicita',
        },
        'protocol': {
          'id': '$s-protocol',
          'version': 1,
          'instructions': ['Conta elementi sintetici'],
          'photoPoints': <Object>[],
          'minPhotos': 0,
          'indicator': 'Elementi sintetici',
          'unit': 'items',
          'threshold': 1,
          'lowerIsBetter': true,
          'measurementDefinition': {
            'minValue': 0,
            'maxValue': 100,
            'integerOnly': true,
          },
        },
        'windows': [
          {
            'id': '$s-window',
            'startsAt': date(1),
            'endsAt': date(3),
            'capacity': 20,
          },
        ],
      },
    ],
    'coverageGoals': [
      {
        'id': '$s-goal',
        'matchdayId': '$s-day',
        'title': 'Obiettivo settimanale sintetico',
        'version': 1,
        'targets': [
          {'placeId': '$s-place', 'startsAt': date(1), 'endsAt': date(3)},
        ],
      },
    ],
  };
}

CooperationRepository repo(RealDevice d) => CooperationRepository(
  client: d.client,
  account: d.account,
  municipality: () => 'tuglie',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real PostgreSQL calendar weekly return, approved target coverage, server read retry new device and explicit follow',
    () async {
      HttpOverrides.global = null;
      final f = BackendFixture();
      await f.start();
      addTearDown(f.stop);
      await f.command('clock', '2026-12-01T00:00:00Z');
      final transports = <MissionTransport>[
        MissionTransport(),
        MissionTransport(),
        ReviewTransport(),
        MissionTransport(),
      ];
      for (final t in transports) addTearDown(t.close);
      final author = RealDevice(f, transports[0]),
          moderator = RealDevice(f, transports[1]),
          verifier = RealDevice(f, transports[2]),
          secondDevice = RealDevice(f, transports[3]);
      for (final d in [author, moderator, verifier, secondDevice])
        addTearDown(d.dispose);
      await author.login('cooperation-author@example.invalid');
      await moderator.login('cooperation-moderator@example.invalid');
      await verifier.login('cooperation-verifier@example.invalid');
      await f.command('clock', '2026-12-01T00:02:00Z');
      await secondDevice.login('cooperation-author@example.invalid');
      expect(author.account.current!.id, secondDevice.account.current!.id);
      await grant(f, moderator, 'moderator');
      await grant(f, verifier, 'verifier');
      final rm = review(moderator), rv = review(verifier);
      addTearDown(rm.dispose);
      addTearDown(rv.dispose);
      final ar = repo(author), sr = repo(secondDevice), other = repo(moderator);
      addTearDown(ar.dispose);
      addTearDown(sr.dispose);
      addTearDown(other.dispose);
      for (final week in [1, 2]) {
        final input = calendar(week);
        final receipt = await f.privateCommand('cooperationCalendar', input);
        expect(receipt['error'], isNull);
        expect(await f.privateCommand('cooperationCalendar', input), receipt);
        final s = 'cooperation-week-$week';
        ar.selectScope(s, '$s-day');
        sr.selectScope(s, '$s-day');
        expect((await ar.progress()).coverage.validated, 0);
        await f.command(
          'clock',
          DateTime.utc(
            2026,
            12,
            2,
          ).add(Duration(days: (week - 1) * 7, hours: 1)).toIso8601String(),
        );
        final m = await author.repo.detail('$s-mission');
        expect(m.snapshot['placeId'], '$s-place');
        await ar.follow('$s-place', true);
        expect((await sr.followed()).any((p) => p.id == '$s-place'), isTrue);
        await author.repo.book(m);
        await author.repo.save(
          author.repo
              .restore(m)!
              .copy(answer: MissionAnswer.noIssue, measurementValue: 5),
        );
        final observation = await author.repo.submit(author.repo.restore(m)!);
        var q = (await rm.queue()).singleWhere((o) => o.id == observation.id);
        q = await rm.command(q, 'assignment');
        q = await rm.command(
          q,
          'screening',
          decision: 'forward',
          reason: 'Contenuto sintetico pertinente',
        );
        q = await rv.command(q, 'assignment');
        (transports[2] as ReviewTransport).loseDecision = true;
        await expectLater(
          rv.command(
            q,
            'decisions',
            decision: 'approve',
            reason: 'Controllo umano sintetico validato',
          ),
          throwsA(isA<ApiException>()),
        );
        await rv.command(
          q,
          'decisions',
          decision: 'approve',
          reason: 'Controllo umano sintetico validato',
        );
        expect((await ar.progress()).coverage.validated, 1);
        expect((await ar.progress()).coverage.ratio, 1);
        final all = await ar.inbox();
        expect(
          all.items.where((m) => m.type == 'observationApproved').length,
          week,
        );
        final inbox = await ar.inbox(limit: 1);
        expect(inbox.items, isNotEmpty);
        expect(inbox.items.single.target, isA<ObservationTarget>());
        final same = await sr.inbox(limit: 1);
        expect(same.items.single.id, inbox.items.single.id);
        await ar.read(inbox.items.single.id);
        await ar.read(inbox.items.single.id);
        expect((await sr.inbox(limit: 1)).items.single.readAt, isNotNull);
        expect((await other.inbox()).items, isEmpty);
        await ar.follow('$s-place', false);
        expect((await sr.followed()).any((p) => p.id == '$s-place'), isFalse);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
