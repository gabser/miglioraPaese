import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/data/api_fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import 'package:fanta_comune/features/account/data/authenticated_session_source.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/features/measurements/data/measurement_repository.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import '../../support/fantasy_backend.dart';
import '../missions/mission_postgres_test.dart'
    show RealDevice, MissionTransport;
import '../review/review_postgres_test.dart' show grant, review;

class MeasurementTransport extends MissionTransport {
  bool losePublication = false;
  final bodies = <String>[];
  @override
  Future<http.StreamedResponse> send(http.BaseRequest r) async {
    if (r.url.path.endsWith('/publications') ||
        r.url.path.endsWith('/corrections'))
      bodies.add((r as http.Request).body);
    final response = await super.send(r);
    if (losePublication &&
        (r.url.path.endsWith('/publications') ||
            r.url.path.endsWith('/corrections'))) {
      losePublication = false;
      await response.stream.drain<void>();
      throw http.ClientException('lost committed measurement publication');
    }
    return response;
  }
}

MeasurementRepository repo(RealDevice d) => MeasurementRepository(
  client: d.client,
  account: d.account,
  review: review(d),
  environment: 'measurement-pg',
  municipality: () => 'tuglie',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real PostgreSQL source OR evidence pipeline, numeric receipt, lost publication replay, appeal correction and immutable history',
    () async {
      HttpOverrides.global = null;
      final f = BackendFixture();
      await f.start();
      addTearDown(f.stop);
      final scope = await f.privateCommand('measurementSeed', {
        'seasonId': 'synthetic-measurement-flutter-v2',
      });
      expect(scope['error'], isNull);
      await f.command('clock', scope['startsAt'] as String);
      final st = MeasurementTransport(), at = MeasurementTransport();
      addTearDown(st.close);
      addTearDown(at.close);
      final supervisor = RealDevice(f, st), author = RealDevice(f, at);
      addTearDown(supervisor.dispose);
      addTearDown(author.dispose);
      await supervisor.login('measurement-supervisor@example.invalid');
      await author.login('measurement-author@example.invalid');
      await grant(f, supervisor, 'outcomesSupervisor');
      final r = repo(supervisor), ar = repo(author);
      addTearDown(r.dispose);
      addTearDown(ar.dispose);
      r.selectScope(scope['seasonId'] as String, scope['matchdayId'] as String);
      ar.selectScope(
        scope['seasonId'] as String,
        scope['matchdayId'] as String,
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = AppPrefs(
        await SharedPreferences.getInstance(),
        dataStore: author.data,
      );
      final sessions = AuthenticatedSessionSource(
        guest: ProposalSessionStore(
          client: author.client,
          data: author.data,
          environment: 'measurement-pg',
        ),
        account: author.account,
      );
      addTearDown(sessions.dispose);
      final fantasy = ApiFantasyRepository(
        client: author.client,
        prefs: prefs,
        environment: 'measurement-pg',
        municipalityId: 'tuglie',
        sessions: sessions,
        seasonId: scope['seasonId'] as String,
      );
      addTearDown(fantasy.dispose);
      await author.client.postJson(
        ['v1', 'fantasy', 'municipalities', 'tuglie', 'enrollment'],
        body: {'squadIds': scope['squadIds']},
        headers: (await author.account.active()).headers,
        queryParameters: {'seasonId': scope['seasonId'] as String},
      );
      var team = await fantasy.load();
      for (final id in team.state.starterIds) {
        team = await fantasy.execute(
          SetFantasyPrediction(id, CivicTrend.stable),
          expectedRevision: team.revision,
        );
      }
      team = await fantasy.execute(
        SetFantasyCaptain(scope['cardId'] as String),
        expectedRevision: team.revision,
      );
      team = await fantasy.execute(
        const ConfirmFantasyLineup(),
        expectedRevision: team.revision,
      );
      final workspace = await r.workspace();
      expect(workspace.sources.length, 2);
      final baseline = workspace.sources.singleWhere(
        (s) => s['id'] == scope['baselineSourceId'],
      );
      final p = await r.command(
        ['problems'],
        {
          'title': 'Problema sintetico quantitativo',
          'placeId': scope['placeId'],
          'baseline': {
            'value': baseline['value'],
            'unit': baseline['unit'],
            'measuredAt': baseline['sourceDate'],
            'sourceId': baseline['id'],
          },
        },
      );
      final protocol = await r.command(
        ['problems', p['id'] as String, 'protocol-versions'],
        {
          'expectedRevision': p['revision'],
          'problemId': p['id'],
          'seasonId': scope['seasonId'],
          'matchdayId': scope['matchdayId'],
          'cardId': scope['cardId'],
          'missionIds': [scope['missionId']],
          'indicator': scope['indicator'],
          'unit': scope['unit'],
          'threshold': 1,
          'lowerIsBetter': true,
          'instructions': ['Misurare solo dati sintetici.'],
          'observationStartsAt': scope['observationStartsAt'],
          'observationEndsAt': scope['observationEndsAt'],
          'declaredDeadline': scope['closeAt'],
          'measurementDefinition': {
            'minValue': 0,
            'maxValue': 100,
            'integerOnly': true,
          },
        },
      );
      await f.command('clock', '2026-12-02T12:00:00Z');
      final mission = await author.repo.detail(scope['missionId'] as String);
      expect(mission.measurementDefinition!.protocolVersion, 1);
      expect(mission.protocolVersion, 2);
      await author.repo.book(mission);
      var draft = author.repo.restore(mission)!;
      await author.repo.save(
        draft.copy(answer: MissionAnswer.noIssue, measurementValue: 5),
      );
      draft = author.repo.restore(mission)!;
      at.loseSubmission = true;
      await expectLater(
        author.repo.submit(draft),
        throwsA(isA<ApiException>()),
      );
      final receipt = await author.repo.submit(author.repo.restore(mission)!);
      expect(receipt.measurement!.value, 5);
      expect(receipt.xpAwarded, 0);
      final original = jsonEncode(receipt.snapshot);
      final after = (await r.workspace()).sources.singleWhere(
        (s) => s['id'] == scope['afterSourceId'],
      );
      final evidence = {
        'afterValue': 5,
        'measuredAt': after['sourceDate'],
        'sourceIds': [after['id']],
        'approvedObservationIds': <String>[],
        'interventionIds': <String>[],
        'rationale':
            'Documento sintetico autorizzato pertinente: qualità, unità e tempi confrontabili.',
      };
      final e = await r.command(
        ['evaluations'],
        {
          'protocolId': protocol['id'],
          'protocolVersion': protocol['version'],
          ...evidence,
        },
      );
      await f.command('clock', scope['observationEndsAt'] as String);
      final verdict = {
        'expectedRevision': e['revision'],
        'disposition': 'determinate',
        'observed': 'improves',
        'rationale': evidence['rationale'],
        'undeterminableReason': null,
      };
      st.losePublication = true;
      await expectLater(
        r.command(['evaluations', e['id'] as String, 'publications'], verdict),
        throwsA(isA<ApiException>()),
      );
      final published = await r.command(
        ['evaluations', e['id'] as String, 'publications'],
        {...verdict, 'observed': 'worsens'},
      );
      expect(st.bodies[0], st.bodies[1]);
      expect(published['version'], 1);
      final public = await ar.overview();
      expect(public.evaluations.single.observed, isNotNull);
      final appeal = await ar.appeal(
        e['id'] as String,
        published['revision'] as int,
        1,
        'Richiesta sintetica di riesame della confrontabilità.',
      );
      expect(
        (await ar.appealDetail(
          e['id'] as String,
          appeal['id'] as String,
        ))['status'],
        'open',
      );
      final correction = await r.command(
        ['evaluations', e['id'] as String, 'corrections'],
        {
          ...evidence,
          'expectedRevision': published['revision'],
          'disposition': 'undeterminable',
          'observed': null,
          'undeterminableReason': 'contradictoryEvidence',
          'appealId': appeal['id'],
        },
      );
      expect(correction['version'], 2);
      team = await fantasy.load();
      final corrected = team.state.revealed.values.single;
      expect(corrected.observed, isNull);
      expect(corrected.disposition, OutcomeDisposition.undeterminable);
      expect(team.scores.values.single.frozenTotal, 0);
      team = await fantasy.execute(
        ReflectOnFantasyCard(
          corrected,
          ReflectionAnswer.insufficientInformation,
        ),
        expectedRevision: team.revision,
      );
      expect(team.scores.values.single.reflectionBonus, 2);
      final resultHistory = await fantasy.resultsHistory(
        scope['matchdayId'] as String,
      );
      expect((resultHistory['items'] as List).length, greaterThanOrEqualTo(2));
      expect(resultHistory['original'], isNotNull);
      final history = await ar.history(e['id'] as String);
      expect(history.length, 2);
      expect(history.first.data['observed'], 'improves');
      expect(history.last.disposition.name, 'undeterminable');
      expect(
        (await ar.appealDetail(
          e['id'] as String,
          appeal['id'] as String,
        ))['status'],
        'accepted',
      );
      expect(
        jsonEncode(
          (await author.repo.lookup(author.repo.restore(mission)!))!.snapshot,
        ),
        original,
      );
      expect(
        jsonEncode(history.map((e) => e.data).toList()),
        isNot(contains('authorId')),
      );
      await f.command('clock', scope['closeAt'] as String);
      final closed = await r.overview();
      expect(closed.coverage.expectedCards, (scope['cardIds'] as List).length);
      expect(
        closed.coverage.closedUndeterminableCards,
        (scope['cardIds'] as List).length,
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
