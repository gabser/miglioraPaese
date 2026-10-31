import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/data/api_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/continuity/continuity_repository.dart';
import '../../../helpers/memory_local_backend.dart';
import '../../../support/fantasy_backend.dart';

class LostContinuityClient extends CookieClient {
  bool loseOwnership = false;
  final bodies = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await super.send(request);
    if (request.method == 'POST' && request.url.path.contains('/ownership/')) {
      bodies.add((request as http.Request).body);
      if (loseOwnership) {
        loseOwnership = false;
        await response.stream.drain<void>();
        throw http.ClientException('lost after commit');
      }
    }
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real PostgreSQL guided join, lock refresh, ownership offer/accept/revoke and archive',
    () async {
      HttpOverrides.global = null;
      final fixture = BackendFixture();
      await fixture.start();
      addTearDown(fixture.stop);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repositories = <ApiFantasyRepository>[],
          continuity = <LeagueContinuityRepository>[];
      final transports = <LostContinuityClient>[];
      for (var i = 0; i < 3; i++) {
        final data = LocalDataStore(backend: MemoryLocalBackend());
        final appPrefs = AppPrefs(prefs, dataStore: data);
        addTearDown(appPrefs.dispose);
        final transport = LostContinuityClient();
        transports.add(transport);
        addTearDown(transport.close);
        final client = ApiClient(
          baseUrl: Uri.parse(fixture.url),
          client: transport,
        );
        final repo = ApiFantasyRepository(
          client: client,
          prefs: appPrefs,
          environment: 'continuity-$i',
          municipalityId: 'tuglie',
        );
        addTearDown(repo.dispose);
        await repo.load();
        repositories.add(repo);
        final c = LeagueContinuityRepository(
          client: client,
          data: data,
          sessions: repo.sessions,
          environment: 'continuity-$i',
          intentKey: 'invite',
          municipality: () => 'tuglie',
        );
        addTearDown(c.dispose);
        continuity.add(c);
      }
      final owner = repositories[0],
          target = repositories[1],
          observer = repositories[2];
      await owner.createLeague('Amici');
      final league = (await owner.loadLeagues()).single;
      final id = league.table.id, season = league.seasonId!;
      final invite = await owner.rotateInvite(id);
      await continuity[1].rememberInvite(invite.token);
      final summary = await continuity[1].preview();
      expect(summary.expectedRole, 'competitor');
      expect(
        await target.loadLeagues(),
        isEmpty,
      ); // Preview never creates membership.
      await continuity[1].join(summary);
      expect((await target.loadLeagues()).single.isSpectator, false);
      var w = await continuity[0].ownership(id, season);
      expect(w.candidates.length, 1);
      expect((await continuity[1].ownership(id, season)).candidates, isEmpty);
      transports[0].loseOwnership = true;
      await expectLater(
        continuity[0].ownershipCommand(
          id,
          season,
          ['offers'],
          {
            'expectedRevision': w.leagueRevision,
            'targetMemberId': w.candidates.single.memberId,
          },
        ),
        throwsA(isA<ApiException>()),
      );
      expect(
        (await continuity[0].ownership(id, season)).pendingOffer,
        isNotNull,
      );
      await continuity[0].retryOwnership(id, season);
      expect(transports[0].bodies[0], transports[0].bodies[1]);
      final received = await continuity[1].ownership(id, season);
      expect(received.pendingOffer!.isTarget, true);
      transports[1].loseOwnership = true;
      await expectLater(
        continuity[1].ownershipCommand(
          id,
          season,
          ['offers', received.pendingOffer!.id, 'accept'],
          {'expectedRevision': received.leagueRevision},
        ),
        throwsA(isA<ApiException>()),
      );
      await continuity[1].retryOwnership(id, season);
      expect(transports[1].bodies[0], transports[1].bodies[1]);
      expect((await continuity[1].ownership(id, season)).isOwner, true);
      expect((await continuity[0].ownership(id, season)).isOwner, false);
      await expectLater(
        owner.rotateInvite(id),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)),
      );
      await fixture.command('clock', '2026-10-09T23:50:00Z');
      final refreshed = await target.rotateInvite(id);
      await continuity[2].rememberInvite(refreshed.token);
      final beforeLock = await continuity[2].preview();
      await fixture.command('clock', '2026-10-10T00:00:00Z');
      await expectLater(
        continuity[2].join(beforeLock),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'league_revision_conflict',
          ),
        ),
      );
      final afterLock = await continuity[2].preview();
      expect(afterLock.expectedRole, 'spectator');
      await continuity[2].join(afterLock);
      expect((await observer.loadLeagues()).single.isSpectator, true);
      w = await continuity[1].ownership(id, season);
      await continuity[1].ownershipCommand(
        id,
        season,
        ['offers'],
        {
          'expectedRevision': w.leagueRevision,
          'targetMemberId': w.candidates.first.memberId,
        },
      );
      final offered = await continuity[1].ownership(id, season);
      await continuity[1].ownershipCommand(
        id,
        season,
        ['offers', offered.pendingOffer!.id, 'revoke'],
        {'expectedRevision': offered.leagueRevision},
      );
      expect((await continuity[1].ownership(id, season)).pendingOffer, null);
      await target.leaveLeague(id);
      expect((await owner.loadLeagues()).single.archived, true);
      await continuity[2].rememberInvite(refreshed.token);
      await expectLater(
        continuity[2].preview(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
