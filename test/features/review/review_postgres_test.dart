import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/features/review/data/review_repository.dart';
import '../../support/fantasy_backend.dart';
import '../missions/mission_postgres_test.dart'
    show RealDevice, MissionTransport;
import '../missions/mission_test_support.dart' show syntheticPng, missionId;

class ReviewTransport extends MissionTransport {
  bool loseDecision = false, loseSupplement = false, loseReplicaBooking = false;
  final decisions = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    if (r.url.path.endsWith('/decisions'))
      decisions.add(
        (jsonDecode((r as http.Request).body) as Map)['idempotencyKey']
            as String,
      );
    final response = await super.send(r);
    if ((r.url.path.endsWith('/decisions') && loseDecision) ||
        (r.url.path.endsWith('/supplements') && loseSupplement) ||
        (r.url.path.contains('/replication-requests/') &&
            r.url.path.endsWith('/bookings') &&
            r.method == 'POST' &&
            loseReplicaBooking)) {
      loseDecision = false;
      loseSupplement = false;
      loseReplicaBooking = false;
      await response.stream.drain<void>();
      throw http.ClientException('synthetic lost committed review response');
    }
    return response;
  }
}

ReviewRepository review(RealDevice d, {String municipality = 'tuglie'}) =>
    ReviewRepository(
      client: d.client,
      account: d.account,
      environment: 'mission-pg',
      municipality: () => municipality,
    );
Future<void> grant(BackendFixture f, RealDevice d, String role) async {
  final result = await f.privateCommand('reviewRole', {
    'accountId': d.account.current!.id,
    'municipalityId': 'tuglie',
    'role': role,
  });
  if (result['error'] != null) throw StateError(result['error'] as String);
}

Future<MissionReceipt> observe(RealDevice d, {String? replicaId}) async {
  final m = await d.repo.detail(missionId);
  if (replicaId == null) await d.repo.book(m);
  final draft = d.repo.restore(m, replicationRequestId: replicaId)!;
  await d.repo.save(
    draft.copy(
      answer: MissionAnswer.noIssue,
      notes: 'Nessuna criticità sintetica',
      photos: [
        MissionPhoto(id: 'photo-${draft.bookingId}', bytes: syntheticPng()),
      ],
    ),
  );
  return d.repo.submit(d.repo.restore(m, replicationRequestId: replicaId)!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real PostgreSQL role stages, private proof, expiry integration, lost approvals, original receipt and authorized replica ledger',
    () async {
      HttpOverrides.global = null;
      final f = BackendFixture();
      await f.start();
      addTearDown(f.stop);
      await f.command('clock', '2026-10-14T10:00:00Z');
      final ta = ReviewTransport(),
          tm = ReviewTransport(),
          tv = ReviewTransport();
      addTearDown(ta.close);
      addTearDown(tm.close);
      addTearDown(tv.close);
      final author = RealDevice(f, ta),
          moderator = RealDevice(f, tm),
          verifier = RealDevice(f, tv);
      addTearDown(author.dispose);
      addTearDown(moderator.dispose);
      addTearDown(verifier.dispose);
      await author.login('review-author@example.invalid');
      await moderator.login('review-moderator@example.invalid');
      await verifier.login('review-verifier@example.invalid');
      await grant(f, moderator, 'moderator');
      await grant(f, verifier, 'verifier');
      final ra = review(author),
          rm = review(moderator),
          rv = review(verifier),
          foreign = review(verifier, municipality: 'other');
      addTearDown(ra.dispose);
      addTearDown(rm.dispose);
      addTearDown(rv.dispose);
      addTearDown(foreign.dispose);
      expect((await ra.capabilities()).roles, isEmpty);
      expect((await rm.capabilities()).moderator, isTrue);
      final receipt = await observe(author), original = receipt.snapshot;
      var queued = (await rm.queue()).single;
      expect(queued.proofs, isEmpty);
      await expectLater(
        rm.detail(receipt.id),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'review_forbidden'),
        ),
      );
      await expectLater(foreign.queue(), throwsA(isA<ApiException>()));
      queued = await rm.command(queued, 'assignment');
      expect(queued.proofs.length, 1);
      expect((await rm.proof(queued, queued.proofs.single)).isNotEmpty, isTrue);
      await expectLater(
        verifier.client.postJson(
          [
            'v1',
            'review',
            'municipalities',
            'tuglie',
            'observations',
            queued.id,
            'decisions',
          ],
          body: {
            'expectedRevision': queued.revision,
            'decision': 'approve',
            'reason': 'insufficient stage',
            'idempotencyKey': 'synthetic-negative-stage-key-123456',
          },
          headers: (await verifier.account.active()).headers,
        ),
        throwsA(isA<ApiException>()),
      );
      var screened = await rm.command(
        queued,
        'screening',
        decision: 'forward',
        reason: 'Contenuti pertinenti',
      );
      expect(screened.assignedTo, isNull);
      expect(screened.xpAwarded, 0);
      screened = await rv.command(screened, 'assignment');
      final needs = await rv.command(
        screened,
        'integration-requests',
        message: 'Aggiungere un’inquadratura sintetica',
      );
      expect(needs.integration!.status, 'open');
      await f.command('clock', '2026-10-14T11:00:00Z');
      final own = await ra.detail(receipt.id, author: true);
      await ra.saveSupplement(own, 'Prova aggiuntiva', [
        MissionPhoto(id: 'supplement-photo', bytes: syntheticPng()),
      ]);
      ta.loseSupplement = true;
      await expectLater(ra.submitSupplement(own), throwsA(isA<ApiException>()));
      final supplemented = await ra.submitSupplement(own);
      expect(supplemented.supplements.length, 1);
      expect(supplemented.status, 'screened');
      var current = await rv.detail(receipt.id);
      tv.loseDecision = true;
      await expectLater(
        rv.command(
          current,
          'decisions',
          decision: 'approve',
          reason: 'Qualità verificata',
        ),
        throwsA(isA<ApiException>()),
      );
      final approved = await rv.command(
        current,
        'decisions',
        decision: 'reject',
        reason: 'Changed after loss',
      );
      expect(approved.xpAwarded, 10);
      expect(tv.decisions[tv.decisions.length - 2], tv.decisions.last);
      expect((await ra.ledger()).balance, 10);
      expect((await ra.ledger()).items.length, 1);
      final draft = author.repo.restore(await author.repo.detail(missionId))!;
      expect((await author.repo.lookup(draft))!.snapshot, original);
      expect(
        author.repo.restore(await author.repo.detail(missionId))!.receipt,
        original,
      );
      await expectLater(
        rv.command(
          current,
          'decisions',
          decision: 'approve',
          reason: 'Obsolete',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'review_revision_conflict',
          ),
        ),
      );
      expect((await ra.detail(receipt.id, author: true)).xpAwarded, 10);
      final request = await rv.replication(
        approved,
        'Replica sintetica richiesta',
      );
      expect(
        (await ra.replicationDetail(request['id'] as String))['placeId'],
        approved.placeId,
      );
      ta.loseReplicaBooking = true;
      await expectLater(
        ra.acceptReplication(request['id'] as String),
        throwsA(isA<ApiException>()),
      );
      final committed = await ra.replicationDetail(request['id'] as String);
      final booking = await author.repo.booking(
        await author.repo.detail(missionId),
        committed['bookingId'] as String,
      );
      expect(booking.replicationRequestId, request['id']);
      final newTransport = ReviewTransport();
      addTearDown(newTransport.close);
      final secondDevice = RealDevice(f, newTransport);
      addTearDown(secondDevice.dispose);
      await secondDevice.login('review-author@example.invalid');
      final secondReview = review(secondDevice);
      addTearDown(secondReview.dispose);
      final recoveredRequest = await secondReview.replicationDetail(
        request['id'] as String,
      );
      expect(recoveredRequest['bookingId'], booking.id);
      expect(recoveredRequest['status'], 'booked');
      final activeBefore = (await f.privateCommand('missionCounts'))['active'];
      await secondDevice.repo.restoreReplica(
        await secondDevice.repo.detail(missionId),
        recoveredRequest['bookingId'] as String,
      );
      expect(
        secondDevice.repo
            .restore(
              await secondDevice.repo.detail(missionId),
              replicationRequestId: request['id'] as String,
            )!
            .scope
            .length,
        8,
      );
      expect((await f.privateCommand('missionCounts'))['active'], activeBefore);
      expect((await secondReview.ledger()).balance, 10);

      final m = await author.repo.detail(missionId);
      await author.repo.restoreReplica(m, booking.id);
      final replicaReceipt = await observe(
        author,
        replicaId: booking.replicationRequestId,
      );
      expect(replicaReceipt.id, isNot(receipt.id));
      var replica = (await rm.queue()).singleWhere(
        (o) => o.id == replicaReceipt.id,
      );
      replica = await rm.command(replica, 'assignment');
      replica = await rm.command(
        replica,
        'screening',
        decision: 'forward',
        reason: 'Replica pertinente',
      );
      replica = await rv.command(replica, 'assignment');
      await rv.command(
        replica,
        'decisions',
        decision: 'approve',
        reason: 'Replica verificata',
      );
      expect((await ra.ledger()).balance, 20);
      expect(
        (await ra.ledger()).items
            .where((e) => e.replicationRequestId != null)
            .length,
        1,
      );
      expect((await author.repo.lookup(draft))!.snapshot, original);
      await grant(f, author, 'moderator');
      final self = (await ra.queue()).singleWhere((o) => o.id == receipt.id);
      await expectLater(
        ra.command(self, 'assignment'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'self_review'),
        ),
      );
    },
  );
}
