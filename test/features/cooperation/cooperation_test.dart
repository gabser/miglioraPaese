import 'package:fanta_comune/features/measurements/logic/measurement_controller.dart';
import '../review/review_test_support.dart';
import '../measurements/measurement_test_support.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/features/cooperation/cooperation_models.dart';
import 'package:fanta_comune/features/cooperation/cooperation_repository.dart';
import 'package:fanta_comune/features/cooperation/cooperation_controller.dart';
import '../missions/mission_test_support.dart';

Map<String, Object?> progressJson({
  String municipality = 'tuglie',
  String season = 'season',
  String day = 'day',
  String? league,
  int expected = 2,
  int validated = 1,
}) => {
  'municipalityId': municipality,
  'seasonId': season,
  'matchdayId': day,
  'serverTime': '2026-10-15T00:00:00Z',
  if (league != null) 'leagueId': league,
  'goal': expected == 0
      ? null
      : {
          'id': 'goal',
          'title': 'Controlli condivisi della settimana',
          'version': 1,
          'publishedAt': '2026-10-14T00:00:00Z',
          'expectedPlaceWindows': expected,
        },
  'coverage': {
    'expectedPlaceWindows': expected,
    'validatedPlaceWindows': validated,
    'ratio': expected == 0 ? null : validated / expected,
  },
  if (league != null)
    'municipalCoverage': {
      'expectedPlaceWindows': expected,
      'validatedPlaceWindows': expected,
      'ratio': 1.0,
    },
};
Map<String, Object?> inboxJson({
  String? cursor = 'opaque',
  int unread = 2,
  String id = 'message',
  Object? target,
}) => {
  'serverTime': '2026-10-15T00:00:00Z',
  'unreadCount': unread,
  'nextCursor': cursor,
  'items': [
    {
      'id': id,
      'type': 'observationApproved',
      'title': 'ignored server text',
      'municipalityId': 'tuglie',
      'createdAt': '2026-10-15T00:00:00Z',
      'readAt': unread == 0 ? '2026-10-15T00:01:00Z' : null,
      'target':
          target ?? {'kind': 'observation', 'observationId': 'observation'},
    },
  ],
};
CooperationRepository cooperation(MissionHarness h) => CooperationRepository(
  client: h.client,
  account: h.account,
  municipality: () => h.municipalityId,
  municipalityChanges: h.municipalityChanges,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('feature defaults off and API dependencies required', () {
    expect(AppConfig.fromValues().cooperationModeEnabled, isFalse);
    expect(
      () => AppConfig.fromValues(cooperationModeEnabled: true),
      throwsArgumentError,
    );
  });
  test(
    'coverage absent goal/zero is unavailable; incompatible ratios rejected',
    () {
      expect(
        CooperationProgress.fromJson(
          progressJson(expected: 0, validated: 0),
        ).coverage.ratio,
        isNull,
      );
      expect(
        CooperationProgress.fromJson(progressJson()).coverage.validated,
        1,
      );
      expect(
        () => CooperativeCoverage.fromJson({
          'expectedPlaceWindows': 0,
          'validatedPlaceWindows': 0,
          'ratio': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => CooperativeCoverage.fromJson({
          'expectedPlaceWindows': 2,
          'validatedPlaceWindows': 3,
          'ratio': 1.5,
        }),
        throwsFormatException,
      );
    },
  );
  test(
    'typed targets allow four scoped destinations and reject URL/additional fields',
    () {
      expect(
        InboxTarget.fromJson({'kind': 'mission', 'missionId': 'mission'}),
        isA<MissionTarget>(),
      );
      expect(
        InboxTarget.fromJson({
          'kind': 'recheck',
          'missionId': 'mission',
          'replicationRequestId': 'replica',
        }),
        isA<RecheckTarget>(),
      );
      expect(
        InboxTarget.fromJson({
          'kind': 'evaluation',
          'evaluationId': 'evaluation',
          'seasonId': 'season',
          'matchdayId': 'day',
        }),
        isA<EvaluationTarget>(),
      );
      final mission =
          InboxTarget.fromJson({
                'kind': 'mission',
                'missionId': 'mission:weekly',
              })
              as MissionTarget;
      expect(mission.id, 'mission:weekly');
      final evaluation =
          InboxTarget.fromJson({
                'kind': 'evaluation',
                'evaluationId': 'evaluation:published',
                'seasonId': 'season:weekly return',
                'matchdayId': 'day:second check',
              })
              as EvaluationTarget;
      expect(evaluation.seasonId, 'season:weekly return');
      expect(evaluation.matchdayId, 'day:second check');
      for (final id in [
        '.',
        '..',
        'a/b',
        r'a\b',
        'a%2Fb',
        'a?b',
        'a#b',
        'a\nb',
        'a\u007fb',
      ]) {
        expect(
          () => InboxTarget.fromJson({'kind': 'mission', 'missionId': id}),
          throwsFormatException,
        );
      }
      for (final target in [
        {'kind': 'url', 'url': 'https://evil.invalid'},
        {'kind': 'observation', 'observationId': '../other'},
        {
          'kind': 'observation',
          'observationId': 'valid',
          'url': 'https://evil.invalid',
        },
      ]) {
        expect(() => InboxTarget.fromJson(target), throwsFormatException);
      }
    },
  );
  test(
    'inbox pagination dedups, reads on server, follow is explicit and reversible',
    () async {
      final requests = <String>[];
      bool read = false, following = false;
      final h = MissionHarness((r) async {
        requests.add('${r.method} ${r.url.path}?${r.url.query}');
        if (r.url.path.endsWith('/inbox'))
          return reply(
            inboxJson(
              cursor: r.url.queryParameters['cursor'] == null ? 'opaque' : null,
              unread: read ? 0 : 2,
            ),
          );
        if (r.url.path.endsWith('/read')) {
          read = true;
          return reply({
            'messageId': 'message',
            'readAt': '2026-10-15T00:01:00Z',
          });
        }
        if (r.url.path.endsWith('/followed-places'))
          return reply({
            'items': following
                ? [
                    {'placeId': 'place', 'municipalityId': 'tuglie'},
                  ]
                : [],
          });
        if (r.url.path.endsWith('/followed-places/place')) {
          following = r.method == 'PUT';
          return reply({
            'placeId': 'place',
            'municipalityId': 'tuglie',
            'following': following,
          });
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final r = cooperation(h), c = CooperationController(cooperation(h));
      addTearDown(r.dispose);
      addTearDown(c.repository.dispose);
      addTearDown(c.dispose);
      await c.loadInbox();
      expect(c.unread, 2);
      await c.loadInbox(more: true);
      expect(c.messages.length, 1);
      expect(requests.any((r) => r.contains('cursor=opaque')), isTrue);
      await c.markRead(c.messages.single);
      expect(c.unread, 0);
      expect(c.messages.single.readAt, isNotNull);
      await c.loadPlaces();
      expect(following, isFalse);
      expect(
        requests.where((r) => r.startsWith('PUT') && r.contains('followed')),
        isEmpty,
      );
      await c.setFollow('place', true);
      expect(c.places.single.id, 'place');
      await c.setFollow('place', false);
      expect(c.places, isEmpty);
    },
  );
  test(
    'ABA municipality, season and account reset discard delayed response',
    () async {
      final pending = Completer<void>();
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/cooperation')) {
          await pending.future;
          return reply(progressJson());
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final r = cooperation(h), c = CooperationController(cooperation(h));
      addTearDown(r.dispose);
      addTearDown(c.repository.dispose);
      addTearDown(c.dispose);
      final loading = c.loadProgress();
      await Future<void>.delayed(Duration.zero);
      h.municipalityId = 'other';
      h.municipalityId = 'tuglie';
      pending.complete();
      expect(await loading, isFalse);
      expect(c.progress, isNull);
      expect(c.busy, isFalse);
    },
  );
  test(
    'league uses authoritative season independent of selected public period',
    () async {
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/cooperation')) {
          expect(r.url.queryParameters, isEmpty);
          return reply(progressJson(league: 'league', season: 'archive'));
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final r = cooperation(h);
      addTearDown(r.dispose);
      r.selectScope('future', 'future-day');
      final p = await r.progress(leagueId: 'league', leagueSeasonId: 'archive');
      expect(p.seasonId, 'archive');
      expect(p.municipal!.validated, 2);
      expect(p.coverage.validated, 1);
    },
  );
  test(
    'season ABA and identity invalidation discard pending inbox pages',
    () async {
      for (final mode in ['season', 'account']) {
        final pending = Completer<void>();
        final h = MissionHarness((r) async {
          if (r.url.path.endsWith('/inbox')) {
            await pending.future;
            return reply(inboxJson());
          }
          return defaultReply(r);
        });
        await h.login();
        final r = cooperation(h), c = CooperationController(r);
        final loading = c.loadInbox();
        await Future<void>.delayed(Duration.zero);
        if (mode == 'season') {
          r.selectScope('other', 'other-day');
          r.selectScope(null, null);
        } else {
          h.account.invalidateIdentity();
        }
        pending.complete();
        expect(await loading, isFalse);
        expect(c.messages, isEmpty);
        expect(c.unread, 0);
        c.dispose();
        r.dispose();
        h.dispose();
      }
    },
  );
  test(
    'cross municipality inbox and malformed target rejected before UI exposure',
    () async {
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/inbox')) {
          final p = inboxJson();
          (p['items'] as List).first['municipalityId'] = 'other';
          return reply(p);
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final r = cooperation(h);
      addTearDown(r.dispose);
      await expectLater(r.inbox(), throwsFormatException);
    },
  );
  test(
    'inbox navigation checks owned recheck and public evaluation scope without automatic commands',
    () async {
      final calls = <String>[];
      bool own = true, opaqueScope = false;
      final h = MissionHarness((r) async {
        calls.add('${r.method} ${r.url.path}');
        if (r.url.path.endsWith('/replication-requests/replica'))
          return reply({
            'id': 'replica',
            'authorId': own ? accountId : 'another-account',
            'municipalityId': 'tuglie',
            'missionId': 'mission',
            'placeId': 'place',
            'windowId': 'window',
            'protocolVersion': 1,
            'status': 'open',
            'dueAt': '2026-12-31T00:00:00Z',
            'bookingId': null,
          });
        if (r.url.path.contains('/evaluations/'))
          return reply({
            ...evaluationJson(),
            if (opaqueScope) ...{
              'id': 'evaluation:published two',
              'seasonId': 'season:weekly return',
              'matchdayId': 'day:second check',
            },
          });
        if (r.url.path.endsWith('/observations/observation'))
          return reply(liveJson());
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      calls.clear();
      final r = cooperation(h),
          c = CooperationController(r),
          review = reviewRepository(h),
          mr = measurements(h),
          mc = MeasurementController(measurements(h));
      addTearDown(c.dispose);
      addTearDown(r.dispose);
      addTearDown(review.dispose);
      addTearDown(mr.dispose);
      addTearDown(mc.dispose);
      addTearDown(mc.repository.dispose);
      InboxMessage message(Object target) =>
          InboxPageData.fromJson(inboxJson(target: target)).items.single;
      expect(
        await c.resolve(
          message({'kind': 'mission', 'missionId': 'mission'}),
          review,
          mc,
        ),
        '/missions/mission',
      );
      expect(calls, isEmpty);
      expect(
        await c.resolve(
          message({'kind': 'mission', 'missionId': 'mission:weekly return'}),
          review,
          mc,
        ),
        '/missions/mission%3Aweekly%20return',
      );
      expect(calls, isEmpty);

      expect(
        await c.resolve(
          message({
            'kind': 'recheck',
            'replicationRequestId': 'replica',
            'missionId': 'mission',
          }),
          review,
          mc,
        ),
        '/review?replicationRequestId=replica',
      );
      own = false;
      expect(
        await c.resolve(
          message({
            'kind': 'recheck',
            'replicationRequestId': 'replica',
            'missionId': 'mission',
          }),
          review,
          mc,
        ),
        isNull,
      );
      expect(
        await c.resolve(
          message({'kind': 'observation', 'observationId': 'observation'}),
          review,
          mc,
        ),
        '/observations/observation',
      );
      expect(
        await c.resolve(
          message({
            'kind': 'evaluation',
            'evaluationId': 'evaluation',
            'seasonId': 'wrong',
            'matchdayId': 'day',
          }),
          review,
          mc,
        ),
        isNull,
      );
      expect(
        await c.resolve(
          message({
            'kind': 'evaluation',
            'evaluationId': 'evaluation',
            'seasonId': 'season',
            'matchdayId': 'day',
          }),
          review,
          mc,
        ),
        '/measurements/evaluations/evaluation',
      );
      opaqueScope = true;
      expect(
        await c.resolve(
          message({
            'kind': 'evaluation',
            'evaluationId': 'evaluation:published two',
            'seasonId': 'season:weekly return',
            'matchdayId': 'day:second check',
          }),
          review,
          mc,
        ),
        '/measurements/evaluations/evaluation%3Apublished%20two',
      );
      expect(mc.repository.seasonId, 'season:weekly return');
      expect(mc.repository.matchdayId, 'day:second check');
      expect(calls.every((r) => r.startsWith('GET ')), isTrue);
    },
  );
}
