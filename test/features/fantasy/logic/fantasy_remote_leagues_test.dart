import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/data/api_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/fantasy/logic/fantasy_manager.dart';
import '../../../support/fantasy_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'three independent managers share a complete remote season day and private ranking',
    () async {
      HttpOverrides.global = null;
      final fixture = BackendFixture();
      await fixture.start();
      addTearDown(fixture.stop);
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPrefs(await SharedPreferences.getInstance());
      final transports = List.generate(4, (_) => CookieClient());
      for (final t in transports) {
        addTearDown(t.close);
      }
      ApiFantasyRepository repository(int i) => ApiFantasyRepository(
        client: ApiClient(
          baseUrl: Uri.parse(fixture.url),
          client: transports[i],
        ),
        prefs: prefs,
        environment: 'isolated-leagues',
        municipalityId: 'tuglie',
      );
      final repositories = List.generate(4, repository);
      final managers = repositories
          .map((r) => FantasyManager.withRepository(r, observeTime: false))
          .toList();
      for (final m in managers) {
        addTearDown(m.dispose);
        await m.settled;
        expect(m.hasData, isTrue);
      }
      final a = managers[0],
          b = managers[1],
          c = managers[2],
          outsider = managers[3];
      // Lost create reply is retried with the same durable key after repository restart.
      transports[0].loseLeagueReply = true;
      expect(await a.createLeague('Amici'), isFalse);
      expect(a.leagueError, isNotNull);
      final restarted = repository(0);
      await restarted.load();
      await restarted.createLeague('Amici');
      expect(transports[0].leagueKeys.length, 2);
      expect(transports[0].leagueKeys.toSet().length, 1);
      await a.refreshLeagues();
      expect(a.remoteLeagues.length, 1);
      final id = a.remoteLeagues.single.table.id;
      final invitation = await a.rotateInvite(id);
      expect(invitation, isNotNull);
      expect(await b.joinLeague(invitation!.token), isTrue);
      await a.refreshLeagues();
      expect(a.remoteLeagues.single.table.entries, isEmpty);
      expect(await c.joinLeague(invitation.token), isTrue);
      for (final m in [a, b, c]) {
        await m.refreshLeagues();
        expect(m.remoteLeagues.single.table.entries.length, 3);
      }
      final api = ApiClient(
        baseUrl: Uri.parse(fixture.url),
        client: transports[3],
      );
      await expectLater(
        api.getJson([
          'v1',
          'fantasy',
          'municipalities',
          'tuglie',
          'leagues',
          id,
        ]),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
      expect(outsider.remoteLeagues, isEmpty);
      expect(await b.rotateInvite(id), isNull);
      expect(b.leagueError, isNotNull);
      for (final pair in [
        ['parco-nord', 'fontanelle-ovest'],
        ['fontanelle-ovest', 'parco-nord'],
        ['parco-nord', 'fontanelle-ovest'],
        ['fontanelle-ovest', 'parco-nord'],
      ]) {
        final quote = await c.quoteTransfer(pair[0], pair[1]);
        expect(quote, isNotNull);
        expect(
          await c.transfer(
            outgoingId: pair[0],
            incomingId: pair[1],
            expectedPenalty: quote!.penalty,
            quote: quote,
          ),
          isNull,
        );
      }
      expect(c.transferPenalty, 8);
      for (final m in [a, b, c]) {
        for (final card in m.starterIds) {
          await m.setPrediction(card, CivicTrend.stable);
          await m.settled;
        }
        expect(await m.confirmLineup(), isTrue);
        await m.settled;
      }
      final longInvite = await a.rotateInvite(id);
      expect(longInvite, isNotNull);
      await fixture.command('clock', '2026-10-10T00:00:00Z');
      for (final m in [a, b, c]) {
        await m.refreshTime(force: true);
        expect(m.isLocked, isTrue);
        expect(await m.confirmLineup(), isFalse);
      }
      // The 24-hour invite has expired; refresh errors do not invent membership.
      expect(await outsider.joinLeague(longInvite!.token), isFalse);
      expect(outsider.remoteLeagues, isEmpty);
      await fixture.command('clock', '2026-10-15T00:00:00Z');
      await fixture.command('publish');
      for (final m in [a, b, c]) {
        await m.refreshTime(force: true);
        expect(m.summaryStatus('matchday-1'), 'final');
      }
      expect(a.scoreForMatchday('matchday-1').total, 28);
      expect(c.scoreForMatchday('matchday-1').total, 20);
      final outcome = a.outcomes.firstWhere((o) => o.cardId == 'buche-centro');
      expect(
        await a.submitReflection(
          outcome,
          ReflectionAnswer.observedIntervention,
        ),
        isTrue,
      );
      await a.settled;
      for (final m in [a, b, c]) {
        await m.refreshLeagues();
      }
      final ranking = a.remoteLeagues.single.table.entries;
      expect(ranking.map((e) => e.points), [29, 28, 20]);
      expect(ranking.map((e) => e.rank), [1, 2, 3]);
      for (final m in [b, c]) {
        expect(
          m.remoteLeagues.single.table.entries.map(
            (e) => [e.userId, e.points, e.rank],
          ),
          ranking.map((e) => [e.userId, e.points, e.rank]),
        );
      }
      // Owner deletion archives, removes its membership and preserves other history.
      await a.clearLocalData();
      expect(a.hasData, isFalse);
      expect(a.remoteLeagues, isEmpty);
      for (final m in [b, c]) {
        await m.refreshTime(force: true);
        expect(m.remoteLeagues.single.archived, isTrue);
        expect(m.remoteLeagues.single.table.entries, isEmpty);
      }
      expect(b.scoreForMatchday('matchday-1').total, 28);
      expect(c.scoreForMatchday('matchday-1').total, 20);
      await fixture.command('restart');
      final afterRestart = repository(1);
      final data = await afterRestart.load();
      expect(data.summaries['matchday-1']!.total, 28);
      expect((await afterRestart.loadLeagues()).single.archived, isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
