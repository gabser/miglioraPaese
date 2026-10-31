import 'dart:async';
import 'dart:convert';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/network/session_lease_source.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/fantasy/continuity/continuity_controller.dart';
import 'package:fanta_comune/features/fantasy/continuity/continuity_models.dart';
import 'package:fanta_comune/features/fantasy/continuity/continuity_repository.dart';
import 'package:fanta_comune/features/fantasy/continuity/invite_link.dart';
import '../../../helpers/memory_local_backend.dart';

final inviteToken = 'a' * 43;
Map<String, Object?> previewJson({
  String role = 'competitor',
  int revision = 3,
}) => {
  'serverTime': '2026-10-08T00:00:00Z',
  'municipalityId': 'tuglie',
  'seasonId': 's1',
  'leagueId': 'l1',
  'name': 'Amici',
  'leagueRevision': revision,
  'expiresAt': '2026-10-09T00:00:00Z',
  'firstLocksAt': '2026-10-10T00:00:00Z',
  'expectedRole': role,
  'lateJoinReason': role == 'spectator' ? 'firstLockReached' : null,
};
Map<String, Object?> offerJson({String status = 'pending'}) => {
  'id': 'o1',
  'targetMemberId': 'm2',
  'targetPseudonym': 'Sentinella 2',
  'status': status,
  'expiresAt': '2026-10-14T00:00:00Z',
  'isTarget': false,
};
Map<String, Object?> workspaceJson({bool owner = true, bool offer = false}) => {
  'serverTime': '2026-10-08T00:00:00Z',
  'seasonId': 's1',
  'leagueId': 'l1',
  'revision': 3,
  'isOwner': owner,
  'candidates': owner
      ? [
          {'memberId': 'm2', 'pseudonym': 'Sentinella 2'},
        ]
      : [],
  'pendingOffer': offer ? offerJson() : null,
};
http.Response reply(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

class FakeSessions extends ChangeNotifier implements SessionLeaseSource {
  int generation = 0, calls = 0;
  String scope = "guest";
  void change() {
    generation++;
    notifyListeners();
  }

  @override
  Future<ProposalSessionLease> active({
    bool allowCreate = false,
    String? expectedScope,
  }) async {
    calls++;
    return ProposalSessionLease(
      token: 'secret',
      submissionScope: scope,
      epoch: 0,
      generation: generation,
    );
  }

  @override
  void checkLease(ProposalSessionLease lease) {
    if (lease.generation != generation) throw const LocalDataResetException();
  }

  @override
  Future<ProposalSessionLease?> existing() => active();
  @override
  Future<void> revokeBeforeReset() async {
    change();
  }

  @override
  bool get preservesCompetitiveDataOnReset => false;
}

class Harness {
  Harness(Future<http.Response> Function(http.Request) handler) {
    transport = MockClient((request) {
      requests.add(request);
      return handler(request);
    });
    repository = LeagueContinuityRepository(
      client: ApiClient(
        baseUrl: Uri.parse('https://fixture.invalid'),
        client: transport,
      ),
      data: data,
      sessions: sessions,
      environment: 'test',
      intentKey: 'invite',
      municipality: () => municipality,
      municipalityChanges: changes,
      identityChanges: sessions,
    );
  }
  final backend = MemoryLocalBackend();
  late final data = LocalDataStore(backend: backend);
  final sessions = FakeSessions(), changes = ChangeNotifier();
  String municipality = 'tuglie';
  final requests = <http.Request>[];
  late final MockClient transport;
  late final LeagueContinuityRepository repository;
  void close() {
    repository.dispose();
    sessions.dispose();
    changes.dispose();
    data.dispose();
    transport.close();
  }
}

LeagueContinuityRepository restart(Harness h) {
  final recovered = LocalDataStore(backend: h.backend);
  final repository = LeagueContinuityRepository(
    client: ApiClient(
      baseUrl: Uri.parse('https://fixture.invalid'),
      client: h.transport,
    ),
    data: recovered,
    sessions: h.sessions,
    environment: 'test',
    intentKey: 'invite',
    municipality: () => h.municipality,
    identityChanges: h.sessions,
    municipalityChanges: h.changes,
  );
  addTearDown(() {
    repository.dispose();
    recovered.dispose();
  });
  return repository;
}

void main() {
  test(
    'link preserves app origin/base path and never places token in request path or query',
    () {
      final uri = leagueInviteLink(
        inviteToken,
        base: Uri.parse('https://civic.invalid/pilot/#/leagues'),
      );
      expect(uri.path, '/pilot/');
      expect(uri.query, '');
      expect(uri.fragment, 'league-invite=$inviteToken');
      expect(inviteFromFragment(uri.fragment), inviteToken);
      expect(inviteFromFragment('league-invite=bad'), null);
    },
  );
  test(
    'public preview does not acquire identity or enrollment and survives repository restart',
    () async {
      final h = Harness((r) async => reply(previewJson()));
      addTearDown(h.close);
      await h.repository.rememberInvite(inviteToken);
      final p = await h.repository.preview();
      expect(p.leagueId, 'l1');
      expect(h.sessions.calls, 0);
      expect(h.requests.single.url.path, '/v1/fantasy/league-invites/preview');
      expect(h.requests.single.url.toString(), isNot(contains(inviteToken)));
      expect(h.requests.single.headers.containsKey('authorization'), false);
      final recovered = LocalDataStore(backend: h.backend);
      expect((recovered.read('invite') as Map)['token'], inviteToken);
      recovered.dispose();
    },
  );
  for (final dimension in ['identity', 'municipality', 'season']) {
    test('late preview discarded after $dimension ABA', () async {
      final gate = Completer<http.Response>();
      final h = Harness((_) => gate.future);
      addTearDown(h.close);
      await h.repository.rememberInvite(inviteToken);
      final pending = h.repository.preview();
      if (dimension == 'identity') {
        h.sessions.change();
        h.sessions.change();
      }
      if (dimension == 'municipality') {
        h.municipality = 'lecce';
        h.changes.notifyListeners();
        h.municipality = 'tuglie';
        h.changes.notifyListeners();
      }
      if (dimension == 'season') {
        h.repository.selectSeason('s2');
        h.repository.selectSeason('s1');
      }
      gate.complete(reply(previewJson()));
      await expectLater(pending, throwsA(isA<LocalDataResetException>()));
    });
  }
  test(
    'join receipt lost keeps body across restart; no GET replays the join',
    () async {
      bool lose = true;
      final h = Harness((r) async {
        if (r.url.path.endsWith('/join')) {
          if (lose) {
            lose = false;
            throw http.ClientException('lost');
          }
          return reply({
            'seasonId': 's1',
            'league': {'id': 'l1', 'seasonId': 's1', 'role': 'competitor'},
          });
        }
        return reply(workspaceJson());
      });
      addTearDown(h.close);
      await h.repository.rememberInvite(inviteToken);
      final p = LeagueInvitePreview.fromJson(previewJson());
      await expectLater(h.repository.join(p), throwsA(isA<ApiException>()));
      final recovered = restart(h);
      await recovered.ownership('l1', 's1');
      expect(h.requests.where((r) => r.method == 'POST').length, 1);
      await recovered.join(p);
      expect(recovered.inviteToken, null);
      final commands = h.requests.where((r) => r.method == 'POST').toList();
      expect(commands[0].body, commands[1].body);
      expect(jsonDecode(commands.last.body)['expectedRole'], 'competitor');
    },
  );
  test(
    'CAS conflict clears only obsolete command, preserves intent and forces summary',
    () async {
      var conflict = false;
      final h = Harness(
        (r) async => conflict
            ? reply({
                'error': 'league_revision_conflict',
                'message': 'changed',
              }, 409)
            : reply(previewJson()),
      );
      addTearDown(h.close);
      final c = LeagueInviteController(h.repository);
      addTearDown(c.dispose);
      await c.preview(inviteToken);
      c.teamReady = true;
      conflict = true;
      await c.confirm();
      expect(c.joined, false);
      expect(c.summary, null);
      expect(h.repository.inviteToken, inviteToken);
    },
  );
  test(
    'ownership lost response preserves idempotency key; reads and reload never mutate',
    () async {
      bool lose = true;
      final h = Harness((r) async {
        if (r.method == 'GET') return reply(workspaceJson(offer: true));
        if (lose) {
          lose = false;
          throw http.ClientException('lost');
        }
        return reply({
          'serverTime': '2026-10-08T00:00:00Z',
          'seasonId': 's1',
          'leagueId': 'l1',
          'revision': 4,
          'offer': offerJson(),
        });
      });
      addTearDown(h.close);
      await expectLater(
        h.repository.ownershipCommand(
          'l1',
          's1',
          ['offers'],
          {'expectedRevision': 3, 'targetMemberId': 'm2'},
        ),
        throwsA(isA<ApiException>()),
      );
      expect(await h.repository.pendingOwnership('l1', 's1'), isNotNull);
      final recovered = restart(h);
      await recovered.ownership('l1', 's1');
      expect(h.requests.where((r) => r.method == 'POST').length, 1);
      await recovered.retryOwnership('l1', 's1');
      expect(await recovered.pendingOwnership('l1', 's1'), null);
      final writes = h.requests.where((r) => r.method == 'POST').toList();
      expect(writes[0].body, writes[1].body);
    },
  );
  test(
    'identity switch while local command write queued cannot publish command',
    () async {
      final h = Harness((_) async => reply({}));
      addTearDown(h.close);
      final gate = Completer<bool>();
      h.backend.onWrite = (_, __) => gate.future;
      final pending = h.repository.ownershipCommand(
        'l1',
        's1',
        ['offers'],
        {'expectedRevision': 3, 'targetMemberId': 'm2'},
      );
      await Future<void>.delayed(Duration.zero);
      h.sessions.change();
      gate.complete(true);
      await expectLater(pending, throwsA(isA<LocalDataResetException>()));
      expect(h.requests, isEmpty);
    },
  );
  test(
    'account commands survive reauthentication with another submission scope, isolate other account',
    () async {
      final data = LocalDataStore(backend: MemoryLocalBackend()),
          sessions = FakeSessions();
      var accountId = 'account-one';
      var lose = true;
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/verify'))
          return reply({
            'token': 'A' * 43,
            'submissionScope': '11111111-1111-1111-1111-111111111111',
            'sessionId': '11111111-1111-1111-1111-111111111111',
            'expiresAt': '2027-01-01T00:00:00Z',
            'account': {
              'id': accountId,
              'pseudonym': 'Custode',
              'email': 'fixture@example.invalid',
              'emailVerified': true,
            },
          });
        if (lose) {
          lose = false;
          throw http.ClientException('lost');
        }
        return reply({
          'seasonId': 's1',
          'leagueId': 'l1',
          'revision': 4,
          'offer': offerJson(),
        });
      });
      final client = ApiClient(
        baseUrl: Uri.parse('https://fixture.invalid'),
        client: transport,
      );
      final account = AccountSessionStore(
        client: client,
        data: data,
        environment: 'test',
      );
      final repository = LeagueContinuityRepository(
        client: client,
        data: data,
        sessions: sessions,
        account: account,
        identityChanges: account,
        environment: 'test',
        intentKey: 'invite',
        municipality: () => 'tuglie',
      );
      addTearDown(() {
        repository.dispose();
        account.dispose();
        sessions.dispose();
        data.dispose();
        transport.close();
      });
      await account.verify(challengeId: 'challenge', code: '123456');
      await expectLater(
        repository.ownershipCommand(
          'l1',
          's1',
          ['offers'],
          {'targetMemberId': 'm2', 'expectedRevision': 3},
        ),
        throwsA(isA<ApiException>()),
      );
      final original = await repository.pendingOwnership('l1', 's1');
      expect(original, isNotNull);
      sessions.scope = 'another-device-scope';
      await account.verify(challengeId: 'challenge', code: '123456');
      expect(await repository.pendingOwnership('l1', 's1'), original);
      accountId = 'account-two';
      await account.verify(challengeId: 'challenge', code: '123456');
      expect(await repository.pendingOwnership('l1', 's1'), null);
      accountId = 'account-one';
      await account.verify(challengeId: 'challenge', code: '123456');
      await repository.retryOwnership('l1', 's1');
      expect(await repository.pendingOwnership('l1', 's1'), null);
    },
  );
  test(
    'unknown role, missing revision, reserved candidates and unknown offer status rejected',
    () {
      expect(
        () => LeagueInvitePreview.fromJson(previewJson(role: 'owner')),
        throwsFormatException,
      );
      expect(
        () => LeagueInvitePreview.fromJson(
          {...previewJson()}..remove('leagueRevision'),
        ),
        throwsFormatException,
      );
      expect(
        () =>
            OwnershipWorkspace.fromJson({...workspaceJson(), 'isOwner': false}),
        throwsFormatException,
      );
      expect(
        () => OwnershipOffer.fromJson(offerJson(status: 'other')),
        throwsFormatException,
      );
    },
  );
}
