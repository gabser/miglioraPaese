import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'package:fanta_comune/features/review/data/review_repository.dart';
import '../domain/measurement_models.dart';

/// API only. A command's durable intent is owned by the account, not its token.
class MeasurementRepository {
  MeasurementRepository({
    required this.client,
    required this.account,
    required this.review,
    required this.environment,
    required this.municipality,
    this.municipalityChanges,
  }) {
    _lastMunicipality = municipalityId;
    municipalityChanges?.addListener(_changed);
  }
  final ApiClient client;
  final AccountSessionStore account;
  final ReviewRepository review;
  final String environment;
  final String Function() municipality;
  final Listenable? municipalityChanges;
  String get municipalityId => municipality();
  late String _lastMunicipality;
  String? seasonId, matchdayId;
  int generation = 0;
  void _changed() {
    if (_lastMunicipality != municipalityId) {
      _lastMunicipality = municipalityId;
      generation++;
      seasonId = null;
      matchdayId = null;
    }
  }

  void selectScope(String? season, String? day) {
    if ((season == null) != (day == null))
      throw ArgumentError('Seleziona stagione e giornata insieme.');
    if (seasonId != season || matchdayId != day) {
      generation++;
      seasonId = season;
      matchdayId = day;
    }
  }

  void dispose() => municipalityChanges?.removeListener(_changed);
  (String, int) get _scope => (municipalityId, generation);
  Map<String, String> get _query => {
    if (seasonId != null) 'seasonId': seasonId!,
    if (matchdayId != null) 'matchdayId': matchdayId!,
  };
  void _check((String, int) scope) {
    if (scope != _scope || account.data.resetting)
      throw const LocalDataResetException();
  }

  List<String> _public(String m) => ['v1', 'municipalities', m, 'measurements'];
  List<String> _private(String m) => [
    'v1',
    'measurements',
    'municipalities',
    m,
  ];
  Future<Object?> _get(
    List<String> Function(String) route, {
    bool private = false,
    bool scoped = false,
  }) async {
    final scope = _scope;
    final lease = private ? await account.active() : null;
    _check(scope);
    if (lease != null) account.checkLease(lease);
    final raw = await client.getJson(
      route(scope.$1),
      headers: lease?.headers ?? const {},
      queryParameters: scoped ? _query : const {},
    );
    _check(scope);
    if (lease != null) account.checkLease(lease);
    return raw;
  }

  void _validateScope(MeasurementScope s) {
    if (s.municipalityId != municipalityId ||
        seasonId != null &&
            (s.seasonId != seasonId || s.matchdayId != matchdayId))
      throw const FormatException('Risposta di un altro Comune o periodo.');
  }

  Future<MeasurementOverview> overview() async {
    final v = MeasurementOverview.fromJson(await _get(_public, scoped: true));
    _validateScope(v.scope);
    seasonId ??= v.scope.seasonId;
    matchdayId ??= v.scope.matchdayId;
    return v;
  }

  Future<MeasurementWorkspace> workspace() async {
    final v = MeasurementWorkspace.fromJson(
      await _get(
        (m) => [..._private(m), 'workspace'],
        private: true,
        scoped: true,
      ),
    );
    _validateScope(v.scope);
    seasonId ??= v.scope.seasonId;
    matchdayId ??= v.scope.matchdayId;
    return v;
  }

  Future<EvaluationPublished> evaluation(String id) async {
    final e = EvaluationPublished.fromJson(
      await _get((m) => [..._public(m), 'evaluations', id]),
    );
    if (e.id != id) throw const FormatException('Caso diverso.');
    return e;
  }

  Future<List<EvaluationPublished>> history(String id) async {
    final m = missionObject(
      await _get((m) => [..._public(m), 'evaluations', id, 'history']),
    );
    final list = List<EvaluationPublished>.unmodifiable(
      (m['items'] as List).map(EvaluationPublished.fromJson),
    );
    if (list.any((e) => e.id != id))
      throw const FormatException('Storico di un altro caso.');
    return list;
  }

  Future<Map<String, dynamic>> caseDetail(String id) async => frozenMeasurement(
    await _get((m) => [..._private(m), 'evaluations', id], private: true),
  );
  Future<Uint8List> proof(String evaluationId, MissionProof p) async {
    final m = missionObject(
      await _get(
        (m) => [..._private(m), 'evaluations', evaluationId, 'proofs', p.id],
        private: true,
      ),
    );
    if (m['id'] != p.id || m['sha256'] != p.sha256)
      throw const FormatException('Prova di un altro caso.');
    return base64Decode(missionString(m, 'dataBase64'));
  }

  String _key(List<String> route) =>
      'measurements-intent:${jsonEncode([environment, account.current!.id, municipalityId, seasonId, matchdayId, ...route])}';
  Future<Map<String, dynamic>?> pending(List<String> tail) async {
    final scope = _scope,
        epoch = account.data.epoch,
        accountGeneration = account.generation;
    _check(scope);
    if (account.current == null) throw const LocalDataResetException();
    final raw = account.data.read(_key([..._private(scope.$1), ...tail]));
    _check(scope);
    if (epoch != account.data.epoch || accountGeneration != account.generation)
      throw const LocalDataResetException();
    return raw == null ? null : frozenMeasurement(raw);
  }

  Future<Map<String, dynamic>> command(
    List<String> tail,
    Map<String, Object?> fields,
  ) async {
    final scope = _scope, lease = await account.active();
    _check(scope);
    account.checkLease(lease);
    final route = [..._private(scope.$1), ...tail],
        key = _key([..._private(scope.$1), ...tail]);
    void check() {
      _check(scope);
      account.checkLease(lease);
    }

    final prepared = await account.data.mutate<(Map<String, Object?>, bool)>(
      key,
      (prior) {
        check();
        final body = prior == null
            ? <String, Object?>{...fields, 'idempotencyKey': newLocalId()}
            : missionObject(prior).cast<String, Object?>();
        return LocalDataMutation(body, (body, prior == null));
      },
      expectedEpoch: lease.epoch,
      check: check,
    );
    Future<void> clear() => account.data.mutate<void>(
      key,
      (_) => const LocalDataMutation(null, null),
      expectedEpoch: lease.epoch,
      check: check,
    );
    Object? raw;
    try {
      raw = await client.postJson(
        route,
        body: prepared.$1,
        headers: lease.headers,
      );
      check();
    } on ApiException catch (e) {
      check();
      if (e.kind == ApiExceptionKind.response &&
          (e.statusCode == 409 ||
              e.statusCode == 400 ||
              e.statusCode == 422 ||
              e.statusCode == 403 && prepared.$2))
        await clear();
      rethrow;
    }
    final value = frozenMeasurement(raw);
    missionString(value, 'id');
    missionInt(value, 'revision');
    if (value['municipalityId'] != null && value['municipalityId'] != scope.$1)
      throw const FormatException('Comando di un altro Comune.');
    await clear();
    return value;
  }

  Future<Map<String, dynamic>> appeal(
    String evaluationId,
    int revision,
    int version,
    String reason,
  ) => command(
    ['evaluations', evaluationId, 'appeals'],
    {
      'expectedRevision': revision,
      'publishedVersion': version,
      'reason': reason,
    },
  );
  Future<Map<String, dynamic>> appealDetail(
    String evaluationId,
    String appealId,
  ) async => frozenMeasurement(
    await _get(
      (m) => [..._private(m), 'evaluations', evaluationId, 'appeals', appealId],
      private: true,
    ),
  );
}
