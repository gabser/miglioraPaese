import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:fanta_comune/core/config/app_config.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/measurements/domain/measurement_models.dart';
import 'package:fanta_comune/features/measurements/logic/measurement_controller.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_api_mapper.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';
import '../missions/mission_test_support.dart';
import 'measurement_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('measurements opt in requires complete API dependencies', () {
    expect(AppConfig.fromValues().measurementsModeEnabled, isFalse);
    expect(
      () => AppConfig.fromValues(measurementsModeEnabled: true),
      throwsArgumentError,
    );
    expect(
      AppConfig.fromValues(
        measurementsModeEnabled: true,
        reviewModeEnabled: true,
        missionsModeEnabled: true,
        accountModeEnabled: true,
        fantasyModeEnabled: true,
        fantasyDataSource: 'api',
      ).measurementsModeEnabled,
      isTrue,
    );
  });
  test(
    'quantitative mission binding separate version, finite range, integer and optional legacy draft',
    () {
      final m = Mission.fromJson(measurementMissionJson()),
          def = m.measurementDefinition!;
      expect(m.protocolVersion, 1);
      expect(def.protocolVersion, 7);
      expect(def.validate('0'), isNull);
      for (final v in ['', 'NaN', 'Infinity', '-1', '101', '2.5']) {
        expect(def.validate(v), isNotNull);
      }
      expect(def.requiresValue(MissionAnswer.nonObservable), isFalse);
      expect(def.requiresValue(MissionAnswer.unsure), isFalse);
      expect(Mission.fromJson(missionJson()).measurementDefinition, isNull);
      final d = MissionDraft(
        scope: ['x'],
        bookingId: 'b',
        bookingRevision: 1,
        measurementValue: 5,
      );
      expect(MissionDraft.fromJson(d.toJson()).measurementValue, 5);
      expect(
        d
            .copy(answer: MissionAnswer.unsure, clearMeasurement: true)
            .measurementValue,
        isNull,
      );
    },
  );
  test(
    'v2 disposition stays separate from nullable direction; deadline without protocol valid',
    () {
      final e = EvaluationPublished.fromJson(
        evaluationJson(disposition: 'undeterminable'),
      );
      expect(e.observed, isNull);
      expect(e.disposition, OutcomeDisposition.undeterminable);
      expect(
        () => EvaluationPublished.fromJson({
          ...evaluationJson(disposition: 'undeterminable'),
          'observed': 'stable',
        }),
        throwsFormatException,
      );
      expect(
        () => EvaluationPublished.fromJson({
          ...evaluationJson(),
          'afterValue': double.nan,
        }),
        throwsA(anything),
      );
      expect(
        EvaluationPublished.fromJson({
          ...evaluationJson(disposition: 'undeterminable'),
          'protocolId': null,
          'protocolVersion': null,
          'unit': null,
          'origin': 'deadline',
        }).observed,
        isNull,
      );
      final o = FantasyApiMapper.outcome({
        ...evaluationJson(disposition: 'undeterminable'),
        'rulesVersion': 'fantasy-v2',
        'publicationId': 'evaluation',
      });
      expect(o.observed, isNull);
      expect(o.authoritativePublication, isTrue);
      expect(o.sourceStatus, FantasySourceStatus.unavailable);
      expect(
        () => FantasyApiMapper.outcome({...evaluationJson(), 'observed': null}),
        throwsFormatException,
      );
    },
  );
  test(
    'v2 undeterminable keeps reflection rounding and transfer penalty but never stable/captain observation points',
    () {
      final score = scoreFantasyOutcome(
        cardId: 'c',
        observed: null,
        prediction: CivicTrend.stable,
        captain: true,
        reflection: true,
        rulesVersion: 'fantasy-v2',
        disposition: OutcomeDisposition.undeterminable,
      );
      expect(score.observationPoints, 0);
      expect(score.predictionPoints, 0);
      expect(score.frozenTotal, 0);
      expect(score.reflectionBonus, 2);
      expect(
        MatchdayScore(
          frozenPoints: 0,
          reflectionBonus: score.reflectionBonus,
          transferPenalty: 4,
          eligible: true,
        ).total,
        -2,
      );
      expect(
        scoreFantasyOutcome(
          cardId: 'c',
          observed: null,
          prediction: CivicTrend.stable,
          captain: true,
          reflection: true,
        ).reflectionBonus,
        0,
      );
    },
  );
  test(
    'public default scope freezes server selection, stale municipality ABA and season reads rejected',
    () async {
      final gate = Completer<http.Response>();
      var delayed = false;
      final queries = <Uri>[];
      final h = MissionHarness((r) async {
        queries.add(r.url);
        if (delayed) return gate.future;
        return reply(overviewJson());
      });
      addTearDown(h.dispose);
      final repo = measurements(h);
      addTearDown(repo.dispose);
      await repo.overview();
      await repo.overview();
      expect(queries.last.queryParameters, {
        'seasonId': 'season',
        'matchdayId': 'day',
      });
      delayed = true;
      final pending = repo.overview();
      await Future<void>.delayed(Duration.zero);
      h.municipalityId = 'other';
      h.municipalityId = 'tuglie';
      gate.complete(reply(overviewJson()));
      await expectLater(pending, throwsA(isA<LocalDataResetException>()));
    },
  );
  test(
    'pending command immutable replay after lost response/new token; definitive conflict clears intent',
    () async {
      var fail = true, conflict = false;
      final bodies = <Map>[];
      final h = MissionHarness((r) async {
        if (r.url.path.contains('/measurements/') && r.method == 'POST') {
          bodies.add(jsonDecode(r.body) as Map);
          if (fail) throw http.ClientException('lost');
          if (conflict)
            return reply({'error': 'measurement_revision_conflict'}, 409);
          return reply({'id': 'problem', 'revision': 1});
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = measurements(h);
      addTearDown(repo.dispose);
      await expectLater(
        repo.command(['problems'], {'title': 'original'}),
        throwsA(isA<ApiException>()),
      );
      await h.login();
      fail = false;
      await repo.command(['problems'], {'title': 'edited'});
      expect(bodies[0], bodies[1]);
      expect(await repo.pending(['problems']), isNull);
      fail = true;
      await expectLater(
        repo.command(['problems'], {'title': 'draft'}),
        throwsA(isA<ApiException>()),
      );
      fail = false;
      conflict = true;
      await expectLater(
        repo.command(['problems'], {'title': 'draft'}),
        throwsA(isA<ApiException>()),
      );
      expect(await repo.pending(['problems']), isNull);
    },
  );
  test(
    'fresh403 permits changes, uncertain replay403 preserves original command',
    () async {
      var status = 403;
      final h = MissionHarness((r) async {
        if (r.url.path.contains('/measurements/') && r.method == 'POST') {
          if (status == 0) throw http.ClientException('lost');
          return reply({'error': 'measurements_forbidden'}, status);
        }
        return defaultReply(r);
      });
      addTearDown(h.dispose);
      await h.login();
      final repo = measurements(h);
      addTearDown(repo.dispose);
      await expectLater(
        repo.command(['problems'], {'title': 'one'}),
        throwsA(isA<ApiException>()),
      );
      expect(await repo.pending(['problems']), isNull);
      status = 0;
      await expectLater(
        repo.command(['problems'], {'title': 'two'}),
        throwsA(isA<ApiException>()),
      );
      status = 403;
      await expectLater(
        repo.command(['problems'], {'title': 'edited'}),
        throwsA(isA<ApiException>()),
      );
      expect((await repo.pending(['problems']))!['title'], 'two');
    },
  );
  test(
    'controller public delayed response cannot populate changed season scope',
    () async {
      final gate = Completer<http.Response>();
      final h = MissionHarness((r) => gate.future);
      addTearDown(h.dispose);
      final repo = measurements(h), c = MeasurementController(measurements(h));
      addTearDown(repo.dispose);
      addTearDown(c.repository.dispose);
      addTearDown(c.dispose);
      final f = c.browse();
      c.selectScope('season2', 'day2');
      gate.complete(reply(overviewJson()));
      await f;
      expect(c.overview, isNull);
    },
  );
}
