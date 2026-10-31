import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/missions/data/mission_repository.dart';
import 'package:fanta_comune/features/missions/data/mission_photo_picker.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/features/missions/logic/mission_controller.dart';
import '../../helpers/memory_local_backend.dart';
import '../../support/fantasy_backend.dart';
import 'mission_test_support.dart' show syntheticPng, missionId;

class MissionTransport extends CookieClient {
  bool loseSubmission = false, loseChunk = false, abortSubmission = false;
  int submissions = 0;
  final keys = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    if (r.method == 'POST' && r.url.path.endsWith('/observations')) {
      submissions++;
      keys.add(
        (jsonDecode((r as http.Request).body) as Map)['idempotencyKey']
            as String,
      );
      if (abortSubmission) throw http.ClientException('offline before POST');
    }
    final response = await super.send(r);
    if ((r.method == 'POST' &&
            r.url.path.endsWith('/observations') &&
            loseSubmission) ||
        (r.url.path.endsWith('/chunks') && loseChunk)) {
      loseSubmission = false;
      loseChunk = false;
      await response.stream.drain<void>();
      throw http.ClientException('lost committed response');
    }
    return response;
  }
}

class RealDevice {
  RealDevice(this.fixture, this.transport, {LocalDataStore? data})
    : data = data ?? LocalDataStore(backend: MemoryLocalBackend()) {
    client = ApiClient(baseUrl: Uri.parse(fixture.url), client: transport);
    account = AccountSessionStore(
      client: client,
      data: this.data,
      environment: 'mission-pg',
    );
    repo = MissionRepository(
      client: client,
      account: account,
      environment: 'mission-pg',
      municipalityId: 'tuglie',
    );
  }
  final BackendFixture fixture;
  final MissionTransport transport;
  final LocalDataStore data;
  late ApiClient client;
  late AccountSessionStore account;
  late MissionRepository repo;
  Future<void> login(String email) async {
    final raw =
        await client.postJson(['v1', 'auth', 'code'], body: {'email': email})
            as Map;
    await account.verify(
      challengeId: raw['challengeId'] as String,
      code: await fixture.accountCode(email),
    );
  }

  void dispose({bool keepData = false}) {
    account.dispose();
    if (!keepData) data.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real PostgreSQL last slot race, idempotent booking, release and account isolation',
    () async {
      HttpOverrides.global = null;
      final f = BackendFixture();
      await f.start();
      addTearDown(f.stop);
      await f.command('clock', '2026-10-14T10:00:00Z');
      await f.command('missionCapacity', '1');
      final t1 = MissionTransport(), t2 = MissionTransport();
      addTearDown(t1.close);
      addTearDown(t2.close);
      final a = RealDevice(f, t1), b = RealDevice(f, t2);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await a.login('slot-a@example.invalid');
      await b.login('slot-b@example.invalid');
      final m = await a.repo.detail(missionId);
      final results = await Future.wait([
        a.repo.book(m).then<Object>((v) => v).catchError((Object e) => e),
        b.repo.book(m).then<Object>((v) => v).catchError((Object e) => e),
      ]);
      expect(results.whereType<MissionBooking>().length, 1);
      expect(results.whereType<ApiException>().single.code, 'mission_full');
      final winner = results[0] is MissionBooking ? a : b,
          loser = identical(winner, a) ? b : a;
      final booking = results.whereType<MissionBooking>().single;
      expect((await winner.repo.book(m)).id, booking.id);
      expect((await f.privateCommand('missionCounts'))['active'], 1);
      await expectLater(
        loser.repo.booking(m, booking.id),
        throwsA(isA<ApiException>()),
      );
      expect((await winner.repo.release(m, booking)).status, 'released');
      expect((await loser.repo.book(m)).status, 'active');
    },
  );
  test(
    'interrupted upload, process restart, lost observation reply and immutable receipt lookup create one contribution',
    () async {
      HttpOverrides.global = null;
      final f = BackendFixture();
      await f.start();
      addTearDown(f.stop);
      await f.command('clock', '2026-10-14T10:00:00Z');
      final transport = MissionTransport();
      addTearDown(transport.close);
      var device = RealDevice(f, transport);
      await device.login('observation@example.invalid');
      var m = await device.repo.detail(missionId);
      await device.repo.book(m);
      var draft = device.repo.restore(m)!;
      draft = draft.copy(
        answer: MissionAnswer.noIssue,
        notes: 'Osservazione sintetica',
        photos: [
          MissionPhoto(
            id: 'proof-key-synthetic-123',
            bytes: await MissionPhotoNormalizer.normalize(syntheticPng()),
          ),
        ],
      );
      await device.repo.save(draft);
      transport.loseChunk = true;
      await expectLater(
        device.repo.submit(draft),
        throwsA(isA<ApiException>()),
      );
      draft = device.repo.restore(m)!;
      expect(draft.photos.single.uploadId, isNotNull);
      expect(draft.submitBody, isNull);
      transport.loseSubmission = true;
      await expectLater(
        device.repo.submit(draft),
        throwsA(isA<ApiException>()),
      );
      draft = device.repo.restore(m)!;
      expect(draft.submitBody, isNotNull);
      expect(draft.receipt, isNull);
      final body = jsonEncode(draft.submitBody), data = device.data;
      device.dispose(keepData: true);
      await f.command('restart');
      device = RealDevice(f, transport, data: data);
      addTearDown(device.dispose);
      m = await device.repo.detail(missionId);
      draft = device.repo.restore(m)!;
      expect(jsonEncode(draft.submitBody), body);
      final receipt = await device.repo.submit(draft);
      expect(receipt.xpAwarded, 0);
      expect(receipt.protocolVersion, 1);
      expect(receipt.proofIds, [draft.photos.single.uploadId]);
      expect(transport.submissions, 1);
      expect(device.repo.restore(m)!.receipt, receipt.snapshot);
      expect((await f.privateCommand('missionCounts'))['observations'], 1);
      final otherTransport = MissionTransport();
      addTearDown(otherTransport.close);
      final other = RealDevice(f, otherTransport);
      addTearDown(other.dispose);
      await other.login('other@example.invalid');
      final otherLease = await other.account.active();
      await expectLater(
        other.client.getJson([
          'v1',
          'proofs',
          receipt.proofIds.single,
        ], headers: otherLease.headers),
        throwsA(isA<ApiException>()),
      );
    },
  );
  test(
    'prepared but undelivered request expires: definitive rejection plus absent receipt allows explicit discard',
    () async {
      HttpOverrides.global = null;
      final f = BackendFixture();
      await f.start();
      addTearDown(f.stop);
      await f.command('clock', '2026-10-14T10:00:00Z');
      final transport = MissionTransport();
      addTearDown(transport.close);
      final d = RealDevice(f, transport);
      addTearDown(d.dispose);
      await d.login('expiry@example.invalid');
      final c = MissionController(repository: d.repo);
      addTearDown(c.dispose);
      await c.open(missionId);
      await c.reserve();
      await c.saveAnswer(MissionAnswer.nonObservable);
      transport.abortSubmission = true;
      expect(await c.send(), isFalse);
      expect(c.uncertain, isTrue);
      expect(await c.discard(), isFalse);
      transport.abortSubmission = false;
      await f.command('clock', '2026-10-14T10:31:00Z');
      expect(await c.send(), isFalse);
      expect(c.draft!.rejectionCode, 'booking_expired');
      expect(c.uncertain, isFalse);
      expect(await c.discard(), isTrue);
      expect(d.data.keysWithPrefix('mission-draft:'), isEmpty);
      expect((await f.privateCommand('missionCounts'))['observations'], 0);
    },
  );
}
