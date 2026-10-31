import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/features/review/domain/review_models.dart';
import 'package:fanta_comune/features/review/logic/review_controller.dart';
import '../missions/mission_test_support.dart';
import 'review_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('review default off and explicitly requires account plus missions', () {
    expect(AppConfig.fromValues().reviewModeEnabled, isFalse);
    expect(
      () => AppConfig.fromValues(reviewModeEnabled: true),
      throwsArgumentError,
    );
    expect(
      () => AppConfig.fromValues(
        reviewModeEnabled: true,
        accountModeEnabled: true,
      ),
      throwsArgumentError,
    );
    expect(
      AppConfig.fromValues(
        reviewModeEnabled: true,
        accountModeEnabled: true,
        missionsModeEnabled: true,
      ).reviewModeEnabled,
      isTrue,
    );
  });
  test(
    'strict live DTO and ledger reject unknown state, roles, fractional XP and missing scope',
    () {
      expect(ObservationLive.fromJson(liveJson()).xpAwarded, 0);
      expect(
        XpLedger.fromJson(ledgerJson(balance: 10)).items.single.amount,
        10,
      );
      for (final bad in [
        {...liveJson(), 'status': 'publicOutcome'},
        {...liveJson(), 'revision': 0},
        {...liveJson(), 'xpAwarded': 20},
        {...liveJson(), 'placeId': null},
        {...liveJson(), 'submittedAt': '2026-10-08T00:00:00'},
      ])
        expect(() => ObservationLive.fromJson(bad), throwsFormatException);
      expect(
        () => ReviewCapabilities.fromJson({
          'roles': ['admin'],
          'synthetic': true,
        }),
        throwsFormatException,
      );
      expect(
        ReviewCapabilities.fromJson({
          'roles': ['outcomesSupervisor'],
          'synthetic': true,
        }).canReview,
        isFalse,
      );
    },
  );
  test('current state does not mutate original phase3 receipt snapshot', () {
    final original = {...liveJson(), 'proofIds': <String>[]};
    final receipt = MissionReceipt.fromJson(original),
        before = jsonEncode(receipt.snapshot);
    final live = ObservationLive.fromJson(
      liveJson(status: 'approved', revision: 3, xp: 10),
    );
    expect(live.xpAwarded, 10);
    expect(jsonEncode(receipt.snapshot), before);
    expect(receipt.xpAwarded, 0);
  });
  test(
    'foreign Municipality and self-review server errors remain explicit',
    () async {
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/assignment'))
          return reply({'error': 'self_review', 'message': 'Forbidden'}, 403);
        if (r.url.path.endsWith('/observation'))
          return reply(liveJson(municipality: 'other'));
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      await expectLater(repo.detail('observation'), throwsFormatException);
      await expectLater(
        repo.command(ObservationLive.fromJson(liveJson()), 'assignment'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'self_review'),
        ),
      );
    },
  );
  test(
    'lost decision reply persists body and replays same key after repository restart',
    () async {
      final commands = <Map<String, dynamic>>[];
      var lose = true;
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/decisions')) {
          commands.add(jsonDecode(r.body) as Map<String, dynamic>);
          if (lose) {
            lose = false;
            throw http.ClientException('lost after commit');
          }
          return reply(liveJson(status: 'approved', revision: 3, xp: 10));
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h),
          o = ObservationLive.fromJson(liveJson());
      await expectLater(
        repo.command(o, 'decisions', decision: 'approve', reason: 'Verificata'),
        throwsA(isA<ApiException>()),
      );
      repo.dispose();
      expect(h.data.keysWithPrefix('review-intent:').length, 1);
      final restarted = reviewRepository(h);
      addTearDown(restarted.dispose);
      final result = await restarted.command(
        o,
        'decisions',
        decision: 'reject',
        reason: 'Edited after loss',
      );
      expect(result.xpAwarded, 10);
      expect(commands.length, 2);
      expect(commands[1], commands[0]);
      expect(commands[1]['decision'], 'approve');
      expect(h.data.keysWithPrefix('review-intent:'), isEmpty);
    },
  );
  test(
    'revision conflict clears rejected command then fresh intent uses new revision',
    () async {
      var conflict = true;
      final bodies = <Map>[];
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/decisions')) {
          bodies.add(jsonDecode(r.body) as Map);
          if (conflict) {
            conflict = false;
            return reply({
              'error': 'review_revision_conflict',
              'message': 'stale',
            }, 409);
          }
          return reply(liveJson(status: 'approved', revision: 4, xp: 10));
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      await expectLater(
        repo.command(
          ObservationLive.fromJson(liveJson()),
          'decisions',
          decision: 'approve',
          reason: 'First',
        ),
        throwsA(isA<ApiException>()),
      );
      await repo.command(
        ObservationLive.fromJson(liveJson(revision: 3)),
        'decisions',
        decision: 'approve',
        reason: 'Current',
      );
      expect(bodies[1]['expectedRevision'], 3);
      expect(bodies[1]['idempotencyKey'], isNot(bodies[0]['idempotencyKey']));
    },
  );
  test(
    'A to B to A rejects delayed response and delayed durable intent before dispatch',
    () async {
      final arrived = Completer<void>(), gate = Completer<void>();
      var writes = 0, posts = 0;
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/observation')) {
          arrived.complete();
          await gate.future;
          return reply(liveJson());
        }
        if (r.url.path.endsWith('/assignment')) posts++;
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      final fetch = repo.detail('observation');
      await arrived.future;
      h.municipalityId = 'other';
      h.municipalityId = 'tuglie';
      gate.complete();
      await expectLater(fetch, throwsA(isA<LocalDataResetException>()));
      final writing = Completer<void>(), written = Completer<void>();
      h.backend.onWrite = (k, v) async {
        if (++writes == 1) {
          writing.complete();
          await written.future;
        }
        return true;
      };
      final command = repo.command(
        ObservationLive.fromJson(liveJson()),
        'assignment',
      );
      await writing.future;
      h.municipalityId = 'other';
      h.municipalityId = 'tuglie';
      written.complete();
      await expectLater(command, throwsA(isA<LocalDataResetException>()));
      expect(posts, 0);
      expect(h.data.keysWithPrefix('review-intent:'), isEmpty);
    },
  );
  test(
    'controller drops private state on logout generation or Municipality change',
    () async {
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/capabilities'))
          return reply({
            'roles': ['verifier'],
            'synthetic': true,
          });
        if (r.url.path.endsWith('/observation')) return reply(liveJson());
        if (r.url.path.endsWith('/observations'))
          return reply({
            'items': [liveJson()],
          });
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      final c = ReviewController(repository: repo);
      addTearDown(c.dispose);
      await c.open('observation');
      expect(c.observation, isNotNull);
      h.municipalityId = 'other';
      expect(c.observation, isNull);
      expect(c.capabilities, isNull);
    },
  );
  test(
    'supplement upload loss resumes status and keeps identical submission on response loss',
    () async {
      var lostChunk = true, lostSubmit = true, offset = 0;
      final bodies = <Map>[];
      final h = MissionHarness((r) async {
        final p = r.url.path;
        Map<String, Object?> upload() => {
          'id': 'upload',
          'bookingId': bookingId,
          'totalBytes': 3,
          'receivedBytes': offset,
          'status': offset == 3 ? 'complete' : 'uploading',
        };
        if (p.endsWith('/observations/observation/uploads'))
          return reply(upload());
        if (p.endsWith('/uploads/upload')) return reply(upload());
        if (p.endsWith('/chunks')) {
          offset = 3;
          if (lostChunk) {
            lostChunk = false;
            throw http.ClientException('chunk committed reply lost');
          }
          return reply(upload());
        }
        if (p.endsWith('/supplements')) {
          bodies.add(jsonDecode(r.body) as Map);
          if (lostSubmit) {
            lostSubmit = false;
            throw http.ClientException('supplement committed reply lost');
          }
          return reply(liveJson(status: 'screened', revision: 3));
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      final o = ObservationLive.fromJson(
        liveJson(status: 'needsIntegration', revision: 2, integration: true),
      );
      await repo.saveSupplement(o, 'Aggiunta sintetica', [
        MissionPhoto(id: 'photo', bytes: Uint8List.fromList([1, 2, 3])),
      ]);
      await expectLater(repo.submitSupplement(o), throwsA(isA<ApiException>()));
      expect(offset, 3);
      await expectLater(repo.submitSupplement(o), throwsA(isA<ApiException>()));
      await expectLater(
        repo.saveSupplement(o, 'Changed', []),
        throwsStateError,
      );
      final result = await repo.submitSupplement(o);
      expect(result.status, 'screened');
      expect(bodies.length, 2);
      expect(bodies[0], bodies[1]);
      expect(h.data.keysWithPrefix('review-supplement:'), isEmpty);
    },
  );
  test(
    'proof only fetches private endpoint and verifies metadata relationship',
    () async {
      final requests = <String>[];
      final proof = {
        'id': 'proof',
        'sha256': 'a' * 64,
        'sizeBytes': 3,
        'mimeType': 'image/png',
        'width': 1,
        'height': 1,
      };
      final h = MissionHarness((r) async {
        requests.add(r.url.path);
        if (r.url.path.endsWith('/proof'))
          return reply({...proof, 'dataBase64': 'AQID'});
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      final o = ObservationLive.fromJson({
        ...liveJson(),
        'proofs': [proof],
      });
      expect(await repo.proof(o, o.proofs.single), [1, 2, 3]);
      expect(requests.last, '/v1/review/municipalities/tuglie/proofs/proof');
      await repo.proof(o, o.proofs.single, author: true);
      expect(requests.last, '/v1/proofs/proof');
      await expectLater(
        repo.proof(o, MissionProof.fromJson({...proof, 'id': 'foreign'})),
        throwsA(isA<LocalDataResetException>()),
      );
    },
  );
  test(
    'server confirmed replica uses separate eight-part draft scope, base survives',
    () async {
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/bookings/replica-booking'))
          return reply({
            ...bookingJson(),
            'id': 'replica-booking',
            'replicationRequestId': 'request-server',
          });
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final mission = Mission.fromJson(missionJson());
      await h.repository.book(mission);
      final base = h.repository.restore(mission)!;
      await h.repository.restoreReplica(mission, 'replica-booking');
      expect(h.repository.restore(mission)!.bookingId, base.bookingId);
      final replica = h.repository.restore(
        mission,
        replicationRequestId: 'request-server',
      )!;
      expect(replica.scope.length, 8);
      expect(replica.scope.last, 'request-server');
      expect(replica.bookingId, 'replica-booking');
      await expectLater(
        h.repository.restoreReplica(mission, bookingId),
        throwsFormatException,
      );
    },
  );
  test(
    'definitively rejected supplement releases stale CAS body but preserves draft then fresh retry',
    () async {
      var conflict = true;
      final bodies = <Map>[];
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/supplements')) {
          bodies.add(jsonDecode(r.body) as Map);
          if (conflict) {
            conflict = false;
            return reply({
              'error': 'review_revision_conflict',
              'message': 'stale',
            }, 409);
          }
          return reply(liveJson(status: 'screened', revision: 5));
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      final stale = ObservationLive.fromJson(
        liveJson(status: 'needsIntegration', revision: 2, integration: true),
      );
      await repo.saveSupplement(stale, 'Preserved notes', []);
      await expectLater(
        repo.submitSupplement(stale),
        throwsA(isA<ApiException>()),
      );
      final draft = await repo.supplementDraft(stale);
      expect(draft!['notes'], 'Preserved notes');
      expect(draft['body'], isNull);
      final refreshed = ObservationLive.fromJson(
        liveJson(status: 'needsIntegration', revision: 4, integration: true),
      );
      await repo.submitSupplement(refreshed);
      expect(bodies[1]['expectedRevision'], 4);
      expect(bodies[1]['idempotencyKey'], isNot(bodies[0]['idempotencyKey']));
    },
  );
  test(
    'authorization uncertainty retains original command key on 401 and 403',
    () async {
      var denied = 401;
      final bodies = <Map>[];
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/decisions')) {
          bodies.add(jsonDecode(r.body) as Map);
          return reply({
            'error': denied == 401 ? 'session_expired' : 'review_forbidden',
            'message': 'synthetic',
          }, denied);
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      final o = ObservationLive.fromJson(liveJson());
      await expectLater(
        repo.command(o, 'decisions', decision: 'approve', reason: 'Original'),
        throwsA(isA<ApiException>()),
      );
      denied = 403;
      await expectLater(
        repo.command(o, 'decisions', decision: 'reject', reason: 'Changed'),
        throwsA(isA<ApiException>()),
      );
      expect(bodies[0], bodies[1]);
      expect(h.data.keysWithPrefix('review-intent:').length, 1);
    },
  );
  test(
    'fresh403 releases intent; changed role refresh submits new key, ambiguous replay403 keeps key',
    () async {
      var forbidden = true, lost = false;
      final bodies = <Map>[];
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/decisions')) {
          bodies.add(jsonDecode(r.body) as Map);
          if (lost) {
            lost = false;
            throw http.ClientException('unknown commit');
          }
          if (forbidden)
            return reply({
              'error': 'review_forbidden',
              'message': 'synthetic',
            }, 403);
          return reply(liveJson(status: 'approved', revision: 3, xp: 10));
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      final o = ObservationLive.fromJson(liveJson());
      await expectLater(
        repo.command(o, 'decisions', decision: 'approve', reason: 'First403'),
        throwsA(isA<ApiException>()),
      );
      expect(h.data.keysWithPrefix('review-intent:'), isEmpty);
      forbidden = false;
      await repo.command(
        o,
        'decisions',
        decision: 'approve',
        reason: 'Role refreshed',
      );
      expect(bodies[1]['idempotencyKey'], isNot(bodies[0]['idempotencyKey']));
      lost = true;
      await expectLater(
        repo.command(o, 'decisions', decision: 'approve', reason: 'Unknown'),
        throwsA(isA<ApiException>()),
      );
      forbidden = true;
      await expectLater(
        repo.command(o, 'decisions', decision: 'reject', reason: 'Edited'),
        throwsA(isA<ApiException>()),
      );
      expect(bodies[3], bodies[2]);
      expect(h.data.keysWithPrefix('review-intent:').length, 1);
    },
  );
  test(
    'same account relogin with different submission scope recovers original command key',
    () async {
      var loginCount = 0, lose = true;
      final bodies = <Map>[];
      final h = MissionHarness((r) async {
        if (r.url.path.endsWith('/auth/verify')) {
          loginCount++;
          return reply({
            ...authJson(),
            'submissionScope': loginCount == 1
                ? '22222222-2222-2222-2222-222222222222'
                : '33333333-3333-3333-3333-333333333333',
          });
        }
        if (r.url.path.endsWith('/auth/me'))
          return reply({
            ...authJson(),
            'submissionScope': loginCount == 1
                ? '22222222-2222-2222-2222-222222222222'
                : '33333333-3333-3333-3333-333333333333',
          });
        if (r.url.path.endsWith('/decisions')) {
          bodies.add(jsonDecode(r.body) as Map);
          if (lose) {
            lose = false;
            throw http.ClientException('lost');
          }
          return reply(liveJson(status: 'approved', revision: 3, xp: 10));
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = reviewRepository(h);
      addTearDown(repo.dispose);
      final o = ObservationLive.fromJson(liveJson());
      await expectLater(
        repo.command(o, 'decisions', decision: 'approve', reason: 'Original'),
        throwsA(isA<ApiException>()),
      );
      await h.account.logout();
      await h.login();
      await repo.command(o, 'decisions', decision: 'reject', reason: 'Changed');
      expect(bodies[0], bodies[1]);
      expect(h.data.keysWithPrefix('review-intent:'), isEmpty);
    },
  );
}
