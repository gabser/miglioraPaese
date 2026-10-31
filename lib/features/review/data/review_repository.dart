import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/network/session_lease_source.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import '../domain/review_models.dart';

class ReviewRepository {
  ReviewRepository({
    required this.client,
    required this.account,
    required this.environment,
    required this.municipality,
    this.municipalityChanges,
  }) {
    _lastMunicipality = municipalityId;
    municipalityChanges?.addListener(_scopeChanged);
  }
  final ApiClient client;
  final AccountSessionStore account;
  final String environment;
  final String Function() municipality;
  final Listenable? municipalityChanges;
  String get municipalityId => municipality();
  late String _lastMunicipality;
  int _municipalityGeneration = 0;
  (String, int) get _scope => (municipalityId, _municipalityGeneration);
  void _scopeChanged() {
    if (municipalityId != _lastMunicipality) {
      _lastMunicipality = municipalityId;
      _municipalityGeneration++;
    }
  }

  void dispose() => municipalityChanges?.removeListener(_scopeChanged);
  void check(ProposalSessionLease lease, (String, int) scope) {
    account.checkLease(lease);
    if (_scope != scope) throw const LocalDataResetException();
  }

  List<String> _operator(String municipalityId, [String? id, String? action]) =>
      [
        'v1',
        'review',
        'municipalities',
        municipalityId,
        'observations',
        if (id != null) id,
        if (action != null) action,
      ];
  Future<Object?> _get(
    List<String> Function(String) path, {
    Map<String, String>? query,
  }) async {
    final scope = _scope, lease = await account.active();
    check(lease, scope);
    final raw = await client.getJson(
      path(scope.$1),
      headers: lease.headers,
      queryParameters: query ?? const {},
    );
    check(lease, scope);
    return raw;
  }

  ObservationLive _observation(Object? raw, {String? id}) {
    final o = ObservationLive.fromJson(raw);
    if (o.municipalityId != municipalityId || (id != null && o.id != id))
      throw const FormatException('Osservazione di un altro scope.');
    return o;
  }

  Future<ReviewCapabilities> capabilities() async =>
      ReviewCapabilities.fromJson(
        await _get(
          (m) => ['v1', 'review', 'municipalities', m, 'capabilities'],
        ),
      );
  Future<List<ObservationLive>> queue({String? status}) async {
    if (status != null && !reviewStatuses.contains(status))
      throw ArgumentError.value(status);
    final raw = missionObject(
      await _get(
        (m) => _operator(m),
        query: status == null ? null : {'status': status},
      ),
    );
    return List.unmodifiable(
      (raw['items'] as List).map((v) => _observation(v)),
    );
  }

  Future<ObservationLive> detail(String id, {bool author = false}) async =>
      _observation(
        await _get(
          (m) => author ? ['v1', 'observations', id] : _operator(m, id),
        ),
        id: id,
      );
  Future<XpLedger> ledger() async =>
      XpLedger.fromJson(await _get((_) => ['v1', 'me', 'xp']));
  String _intentKey(
    ProposalSessionLease lease,
    String municipalityId,
    List<String> path,
  ) =>
      'review-intent:${jsonEncode([environment, account.current!.id, municipalityId, ...path])}';
  Future<Object?> _command(
    List<String> Function(String) path,
    Map<String, Object?> fields, {
    void Function(Object?)? validate,
  }) async {
    final scope = _scope, lease = await account.active();
    check(lease, scope);
    final route = path(scope.$1),
        key = _intentKey(lease, scope.$1, path(scope.$1));
    final prepared = await account.data.mutate<(Map<String, Object?>, bool)>(
      key,
      (prior) {
        check(lease, scope);
        // An uncertain command always replays its original body, even after UI edits.
        final body = prior == null
            ? <String, Object?>{...fields, 'idempotencyKey': newLocalId()}
            : missionObject(prior).cast<String, Object?>();
        return LocalDataMutation(body, (body, prior == null));
      },
      expectedEpoch: lease.epoch,
      check: () => check(lease, scope),
    );
    final body = prepared.$1, fresh = prepared.$2;
    Object? raw;
    try {
      raw = await client.postJson(route, body: body, headers: lease.headers);
      check(lease, scope);
    } on ApiException catch (e) {
      check(lease, scope);
      if (e.kind == ApiExceptionKind.response &&
              [
                'review_revision_conflict',
                'integration_closed',
                'replication_closed',
                'invalid_field',
                'proof_invalid',
              ].contains(e.code) ||
          (e.kind == ApiExceptionKind.response &&
              e.statusCode == 403 &&
              fresh)) {
        await _clearIntent(key, lease, scope);
      }
      rethrow;
    }
    validate?.call(raw);
    await _clearIntent(key, lease, scope);
    return raw;
  }

  Future<void> _clearIntent(
    String key,
    ProposalSessionLease lease,
    (String, int) scope,
  ) => account.data.mutate<void>(
    key,
    (_) => const LocalDataMutation(null, null),
    expectedEpoch: lease.epoch,
    check: () => check(lease, scope),
  );
  Future<ObservationLive> command(
    ObservationLive o,
    String action, {
    String? decision,
    String? reason,
    String? message,
  }) async {
    if (o.municipalityId != municipalityId)
      throw const LocalDataResetException();
    if (![
      'assignment',
      'screening',
      'integration-requests',
      'decisions',
    ].contains(action))
      throw ArgumentError.value(action);
    return _observation(
      await _command((m) => _operator(m, o.id, action), {
        'expectedRevision': o.revision,
        if (decision != null) 'decision': decision,
        if (reason != null) 'reason': reason,
        if (message != null) 'message': message,
      }, validate: (raw) => _observation(raw, id: o.id)),
      id: o.id,
    );
  }

  Map<String, dynamic> _replication(
    Object? raw, {
    String? id,
    ObservationLive? observation,
    bool author = false,
  }) {
    final m = missionObject(raw);
    for (final key in [
      'id',
      'authorId',
      'missionId',
      'municipalityId',
      'placeId',
      'windowId',
      'status',
    ]) {
      missionString(m, key);
    }
    if (missionInt(m, 'protocolVersion') < 1 ||
        ![
          'open',
          'accepted',
          'booked',
          'expired',
          'closed',
        ].contains(m['status']))
      throw const FormatException('Replica non valida.');
    missionDate(m, 'dueAt');
    if ((m['bookingId'] != null &&
            (m['bookingId'] is! String ||
                (m['bookingId'] as String).isEmpty)) ||
        (m['status'] == 'booked' && m['bookingId'] == null))
      throw const FormatException(
        'Prenotazione replica mancante o non valida.',
      );
    if (m['municipalityId'] != municipalityId ||
        (id != null && m['id'] != id) ||
        (author && m['authorId'] != account.current?.id) ||
        (observation != null &&
            (m['missionId'] != observation.missionId ||
                m['placeId'] != observation.placeId ||
                m['windowId'] != observation.windowId ||
                m['protocolVersion'] != observation.protocolVersion)))
      throw const FormatException('Replica di un altro scope.');
    return Map<String, dynamic>.unmodifiable(m);
  }

  Future<Map<String, dynamic>> replication(
    ObservationLive o,
    String reason,
  ) async {
    if (o.municipalityId != municipalityId)
      throw const LocalDataResetException();
    return _replication(
      await _command((m) => _operator(m, o.id, 'replication-requests'), {
        'expectedRevision': o.revision,
        'reason': reason,
      }, validate: (raw) => _replication(raw, observation: o)),
      observation: o,
    );
  }

  Future<Map<String, dynamic>> replicationDetail(String id) async =>
      _replication(
        await _get((_) => ['v1', 'replication-requests', id]),
        id: id,
        author: true,
      );
  Future<MissionBooking> acceptReplication(String id) async {
    final scope = _scope, lease = await account.active();
    check(lease, scope);
    final request = await replicationDetail(id);
    check(lease, scope);
    MissionBooking validate(Object? raw) {
      final b = MissionBooking.fromJson(raw);
      if (b.replicationRequestId != id ||
          b.missionId != request['missionId'] ||
          b.windowId != request['windowId'] ||
          b.protocolVersion != request['protocolVersion'])
        throw const FormatException('Prenotazione di un’altra replica.');
      return b;
    }

    final raw = await _command(
      (_) => ['v1', 'replication-requests', id, 'bookings'],
      {},
      validate: validate,
    );
    check(lease, scope);
    return validate(raw);
  }

  Future<Uint8List> proof(
    ObservationLive o,
    MissionProof proof, {
    bool author = false,
  }) async {
    if (o.municipalityId != municipalityId ||
        ![
          ...o.proofs,
          ...o.supplements.expand((s) => s.proofs),
        ].any((p) => p.id == proof.id))
      throw const LocalDataResetException();
    final raw = missionObject(
      await _get(
        (m) => author
            ? ['v1', 'proofs', proof.id]
            : ['v1', 'review', 'municipalities', m, 'proofs', proof.id],
      ),
    );
    if (raw['id'] != proof.id || raw['sha256'] != proof.sha256)
      throw const FormatException('Prova di un altro scope.');
    return base64Decode(missionString(raw, 'dataBase64'));
  }

  String _supplementKey(ProposalSessionLease lease, ObservationLive o) =>
      'review-supplement:${jsonEncode([environment, account.current!.id, o.municipalityId, o.id, o.integration?.id])}';
  Future<void> saveSupplement(
    ObservationLive o,
    String notes,
    List<MissionPhoto> photos,
  ) async {
    if (o.municipalityId != municipalityId || o.integration == null)
      throw const LocalDataResetException();
    if (notes.length > 1000 ||
        photos.length > 3 ||
        photos.any((p) => p.bytes.isEmpty || p.bytes.length > 256 * 1024))
      throw StateError('Massimo tre prove sintetiche.');
    final scope = _scope, lease = await account.active();
    check(lease, scope);
    await account.data.mutate<void>(
      _supplementKey(lease, o),
      (prior) {
        if (prior != null && missionObject(prior)['body'] != null)
          throw StateError('Invio incerto: recupera prima di modificare.');
        return LocalDataMutation({
          'notes': notes,
          'photos': photos.map((p) => p.toJson()).toList(),
          'body': null,
        }, null);
      },
      expectedEpoch: lease.epoch,
      check: () => check(lease, scope),
    );
  }

  Future<Map<String, dynamic>?> supplementDraft(ObservationLive o) async {
    final scope = _scope, lease = await account.active();
    check(lease, scope);
    final raw = account.data.read(_supplementKey(lease, o));
    return raw == null ? null : missionObject(raw);
  }

  Future<ObservationLive> submitSupplement(ObservationLive o) async {
    if (o.municipalityId != municipalityId || o.integration == null)
      throw const LocalDataResetException();
    final scope = _scope, lease = await account.active();
    check(lease, scope);
    final key = _supplementKey(lease, o);
    var draft = missionObject(account.data.read(key));
    Future<void> persist() async {
      await account.data.mutate<void>(
        key,
        (_) => LocalDataMutation(draft, null),
        expectedEpoch: lease.epoch,
        check: () => check(lease, scope),
      );
    }

    var freshBody = false;
    if (draft['body'] == null) {
      final photos = (draft['photos'] as List)
          .map(MissionPhoto.fromJson)
          .toList();
      for (var i = 0; i < photos.length; i++) {
        var p = photos[i];
        Map<String, dynamic> status;
        if (p.uploadId == null) {
          status = missionObject(
            await client.postJson(
              ['v1', 'observations', o.id, 'uploads'],
              body: {
                'integrationRequestId': o.integration!.id,
                'mimeType': 'image/png',
                'totalBytes': p.bytes.length,
                'synthetic': true,
                'idempotencyKey': p.id,
              },
              headers: lease.headers,
            ),
          );
          check(lease, scope);
          p = p.withUpload(missionString(status, 'id'));
          photos[i] = p;
          draft = {...draft, 'photos': photos.map((p) => p.toJson()).toList()};
          await persist();
        } else {
          status = missionObject(
            await client.getJson([
              'v1',
              'uploads',
              p.uploadId!,
            ], headers: lease.headers),
          );
          check(lease, scope);
        }
        if (status['id'] != p.uploadId ||
            status['bookingId'] != o.bookingId ||
            status['totalBytes'] != p.bytes.length)
          throw const FormatException('Upload di un altro scope.');
        var offset = missionInt(status, 'receivedBytes');
        if (offset > p.bytes.length)
          throw const FormatException('Offset upload non valido.');
        while (offset < p.bytes.length) {
          final end = min(offset + 32768, p.bytes.length);
          status = missionObject(
            await client.putJson(
              ['v1', 'uploads', p.uploadId!, 'chunks'],
              body: {
                'offset': offset,
                'dataBase64': base64Encode(p.bytes.sublist(offset, end)),
              },
              headers: lease.headers,
            ),
          );
          check(lease, scope);
          if (status['receivedBytes'] != end)
            throw const FormatException('Chunk non confermato.');
          offset = end;
        }
        if (status['status'] != 'complete') {
          status = missionObject(
            await client.postJson(
              ['v1', 'uploads', p.uploadId!, 'complete'],
              body: {},
              headers: lease.headers,
            ),
          );
          check(lease, scope);
          if (status['status'] != 'complete')
            throw const FormatException('Upload incompleto.');
        }
      }
      draft = {
        ...draft,
        'body': {
          'expectedRevision': o.revision,
          'idempotencyKey': newLocalId(),
          'integrationRequestId': o.integration!.id,
          'notes': draft['notes'],
          'proofIds': photos.map((p) => p.uploadId!).toList(),
        },
      };
      freshBody = true;
      await persist();
    }
    Object? raw;
    try {
      raw = await client.postJson(
        ['v1', 'observations', o.id, 'supplements'],
        body: missionObject(draft['body']).cast<String, Object?>(),
        headers: lease.headers,
      );
    } on ApiException catch (e) {
      check(lease, scope);
      if (e.kind == ApiExceptionKind.response &&
              [
                'review_revision_conflict',
                'integration_closed',
                'proof_invalid',
                'invalid_field',
              ].contains(e.code) ||
          (e.kind == ApiExceptionKind.response &&
              e.statusCode == 403 &&
              freshBody)) {
        draft = {...draft, 'body': null};
        await persist();
      }
      rethrow;
    }
    check(lease, scope);
    final result = _observation(raw, id: o.id);
    await account.data.mutate<void>(
      key,
      (_) => const LocalDataMutation(null, null),
      expectedEpoch: lease.epoch,
      check: () => check(lease, scope),
    );
    return result;
  }
}
