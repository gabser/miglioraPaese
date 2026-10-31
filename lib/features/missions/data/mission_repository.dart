import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/network/session_lease_source.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/account/domain/account_models.dart';
import '../domain/mission_models.dart';
import 'mission_draft_store.dart';

class MissionRepository {
  MissionRepository({
    required this.client,
    required this.account,
    required this.environment,
    required String municipalityId,
    this.municipality,
    this.municipalityChanges,
  }) : _municipalityId = municipalityId,
       drafts = MissionDraftStore(account.data) {
    _lastMunicipality = this.municipalityId;
    municipalityChanges?.addListener(_scopeChanged);
  }
  final Listenable? municipalityChanges;
  late String _lastMunicipality;
  int _municipalityGeneration = 0;
  void _scopeChanged() {
    final next = municipalityId;
    if (next == _lastMunicipality) return;
    _lastMunicipality = next;
    _municipalityGeneration++;
  }

  void dispose() => municipalityChanges?.removeListener(_scopeChanged);
  (String, int) get _municipalityLease =>
      (municipalityId, _municipalityGeneration);
  final ApiClient client;
  final AccountSessionStore account;
  final String environment, _municipalityId;
  final String Function()? municipality;
  String get municipalityId => municipality?.call() ?? _municipalityId;
  final MissionDraftStore drafts;
  LocalDataStore get data => account.data;
  void _checkMunicipality((String, int) expected) {
    if (_municipalityLease != expected) throw const LocalDataResetException();
  }

  void _checkLease(ProposalSessionLease lease, (String, int) expected) {
    _checkMunicipality(expected);
    account.checkLease(lease);
  }

  Future<ProposalSessionLease> _active((String, int) expected) async {
    final lease = await account.active();
    _checkLease(lease, expected);
    return lease;
  }

  void _checkDraftScope(MissionDraft draft) {
    final current = missionObject(data.read(account.key));
    final principal = AccountProfile.fromJson(current['account']).id;
    if (![7, 8].contains(draft.scope.length) ||
        draft.scope[0] != environment ||
        draft.scope[1] != principal ||
        draft.scope[2] != municipalityId)
      throw const LocalDataResetException();
    if (draft.missionSnapshot != null) {
      final m = Mission.fromJson(draft.missionSnapshot);
      if (jsonEncode(
            scope(
              m,
              replicationRequestId: draft.scope.length == 8
                  ? draft.scope[7]
                  : null,
            ),
          ) !=
          jsonEncode(draft.scope))
        throw const LocalDataResetException();
    }
  }

  List<String> path([String? id]) => [
    'v1',
    'municipalities',
    municipalityId,
    'missions',
    if (id != null) id,
  ];
  ProposalSessionLease localLease() {
    if (account.authenticating || account.signingOut)
      throw const LocalDataResetException();
    final stored = data.read(account.key);
    if (stored is! Map ||
        stored['token'] is! String ||
        stored['submissionScope'] is! String ||
        !AccountSessionStore.tokenPattern.hasMatch(stored['token'] as String))
      throw ApiException.configuration(
        code: 'account_required',
        message: 'Accedi con un account verificato per prenotare.',
      );
    final lease = ProposalSessionLease(
      token: stored['token'] as String,
      submissionScope: stored['submissionScope'] as String,
      epoch: data.epoch,
      generation: account.generation,
    );
    account.checkLease(lease);
    return lease;
  }

  List<String> scope(Mission mission, {String? replicationRequestId}) {
    if (mission.municipalityId != municipalityId)
      throw const LocalDataResetException();
    localLease();
    final stored = missionObject(data.read(account.key));
    final profile = AccountProfile.fromJson(stored['account']);
    return [
      environment,
      profile.id,
      mission.municipalityId,
      mission.id,
      mission.protocolId,
      mission.protocolVersion.toString(),
      mission.windowId,
      if (replicationRequestId != null) replicationRequestId,
    ];
  }

  Future<List<Mission>> catalog({String? zoneId}) async {
    final municipalityAtStart = _municipalityLease;
    final epoch = data.epoch, generation = account.generation;
    final raw = missionObject(
      await client.getJson(
        path(),
        queryParameters: {if (zoneId != null) 'zoneId': zoneId},
      ),
    );
    account.check(generation, epoch);
    _checkMunicipality(municipalityAtStart);
    if (raw['items'] is! List)
      throw const FormatException('Catalogo missioni non valido.');
    final result = (raw['items'] as List).map(Mission.fromJson).toList();
    if (result.any(
      (m) =>
          m.municipalityId != municipalityId ||
          (zoneId != null && m.zoneId != zoneId),
    ))
      throw const FormatException('Catalogo di un altro Comune/zona.');
    final nextWindows = <String, Mission>{};
    for (final mission in result) {
      nextWindows.putIfAbsent(mission.id, () => mission);
    }
    return nextWindows.values.toList();
  }

  Future<Mission> detail(String id) async {
    final municipalityAtStart = _municipalityLease;
    final epoch = data.epoch, generation = account.generation;
    final raw = missionObject(await client.getJson(path(id)));
    account.check(generation, epoch);
    _checkMunicipality(municipalityAtStart);
    final mission = Mission.fromJson(raw['mission']);
    if (mission.id != id || mission.municipalityId != municipalityId)
      throw const FormatException('Missione di un altro scope.');
    return mission;
  }

  MissionDraft? restore(Mission mission, {String? replicationRequestId}) =>
      drafts.read(scope(mission, replicationRequestId: replicationRequestId));

  Future<MissionBooking> restoreReplica(Mission mission, String id) async {
    final municipalityAtStart = _municipalityLease;
    final lease = await _active(municipalityAtStart);
    final b = await booking(mission, id);
    _checkLease(lease, municipalityAtStart);
    if (b.id != id || b.replicationRequestId == null)
      throw const FormatException(
        'Prenotazione non appartenente a una replica richiesta.',
      );
    final currentScope = scope(
      mission,
      replicationRequestId: b.replicationRequestId,
    );
    if (b.status == 'active' && drafts.read(currentScope) == null)
      await drafts.save(
        MissionDraft(
          scope: currentScope,
          bookingId: b.id,
          bookingRevision: b.revision,
          missionSnapshot: mission.snapshot,
        ),
        epoch: lease.epoch,
        check: () => _checkLease(lease, municipalityAtStart),
      );
    return b;
  }

  Future<void> save(MissionDraft draft) async {
    _checkDraftScope(draft);
    final municipalityAtStart = _municipalityLease;
    final lease = localLease();
    await drafts.save(
      draft,
      epoch: lease.epoch,
      check: () => _checkLease(lease, municipalityAtStart),
    );
  }

  Future<MissionBooking?> existing(Mission mission) async {
    final municipalityAtStart = _municipalityLease;
    final lease = await _active(municipalityAtStart);
    final raw = missionObject(
      await client.getJson([
        ...path(mission.id),
        'booking',
      ], headers: lease.headers),
    );
    _checkLease(lease, municipalityAtStart);
    if (raw['booking'] == null) return null;
    final booking = _booking(raw['booking'], mission);
    final currentScope = scope(mission);
    if (booking.status == 'active' && drafts.read(currentScope) == null)
      await drafts.save(
        MissionDraft(
          scope: currentScope,
          bookingId: booking.id,
          bookingRevision: booking.revision,
          missionSnapshot: mission.snapshot,
        ),
        epoch: lease.epoch,
        check: () => _checkLease(lease, municipalityAtStart),
      );
    return booking;
  }

  MissionBooking _booking(Object? raw, Mission mission) {
    final b = MissionBooking.fromJson(raw);
    if (b.missionId != mission.id ||
        b.windowId != mission.windowId ||
        b.protocolVersion != mission.protocolVersion)
      throw const FormatException(
        'Prenotazione di un altro protocollo/finestra.',
      );
    return b;
  }

  Future<MissionBooking> book(Mission mission) async {
    final municipalityAtStart = _municipalityLease;
    final lease = await _active(municipalityAtStart);
    final currentScope = scope(mission);
    final key = 'mission-booking-intent:${jsonEncode(currentScope)}';
    final body = await data.mutate<Map<String, Object?>>(
      key,
      (prior) {
        _checkLease(lease, municipalityAtStart);
        final body = prior == null
            ? <String, Object?>{
                'windowId': mission.windowId,
                'idempotencyKey': newLocalId(),
              }
            : missionObject(prior).cast<String, Object?>();
        return LocalDataMutation(body, body);
      },
      expectedEpoch: lease.epoch,
      check: () => _checkLease(lease, municipalityAtStart),
    );
    final raw = await client.postJson(
      [...path(mission.id), 'bookings'],
      body: body,
      headers: lease.headers,
    );
    _checkLease(lease, municipalityAtStart);
    final booking = _booking(raw, mission);
    final prior = drafts.read(currentScope);
    if (prior == null)
      await drafts.save(
        MissionDraft(
          scope: currentScope,
          bookingId: booking.id,
          bookingRevision: booking.revision,
          missionSnapshot: mission.snapshot,
        ),
        epoch: lease.epoch,
        check: () => _checkLease(lease, municipalityAtStart),
      );
    else if (prior.bookingId != booking.id)
      throw StateError(
        'Una bozza precedente è conservata: rimuovila esplicitamente prima di cambiare prenotazione.',
      );
    return booking;
  }

  Future<MissionBooking> booking(Mission mission, String id) async {
    final municipalityAtStart = _municipalityLease;
    final lease = await _active(municipalityAtStart);
    final raw = await client.getJson([
      'v1',
      'bookings',
      id,
    ], headers: lease.headers);
    _checkLease(lease, municipalityAtStart);
    final result = _booking(raw, mission);
    if (result.id != id)
      throw const FormatException('Prenotazione di un altro scope.');
    return result;
  }

  Future<MissionBooking> release(
    Mission mission,
    MissionBooking booking,
  ) async {
    final municipalityAtStart = _municipalityLease;
    final lease = await _active(municipalityAtStart);
    final raw = await client.postJson(
      ['v1', 'bookings', booking.id, 'release'],
      body: {'expectedRevision': booking.revision},
      headers: lease.headers,
    );
    _checkLease(lease, municipalityAtStart);
    return _booking(raw, mission);
  }

  Future<MissionDraft> upload(MissionDraft initial) async {
    _checkDraftScope(initial);
    final municipalityAtStart = _municipalityLease;
    final lease = await _active(municipalityAtStart);
    var draft = initial;
    for (var index = 0; index < draft.photos.length; index++) {
      var photo = draft.photos[index];
      Map<String, dynamic> status;
      if (photo.uploadId == null) {
        status = missionObject(
          await client.postJson(
            ['v1', 'bookings', draft.bookingId, 'uploads'],
            body: {
              'mimeType': 'image/png',
              'totalBytes': photo.bytes.length,
              'synthetic': true,
              'idempotencyKey': photo.id,
            },
            headers: lease.headers,
          ),
        );
        _checkLease(lease, municipalityAtStart);
        photo = photo.withUpload(missionString(status, 'id'));
        final photos = [...draft.photos];
        photos[index] = photo;
        draft = draft.copy(photos: photos);
        await drafts.save(
          draft,
          epoch: lease.epoch,
          check: () => _checkLease(lease, municipalityAtStart),
        );
      } else {
        status = missionObject(
          await client.getJson([
            'v1',
            'uploads',
            photo.uploadId!,
          ], headers: lease.headers),
        );
        _checkLease(lease, municipalityAtStart);
      }
      if (status['id'] != photo.uploadId ||
          status['bookingId'] != draft.bookingId ||
          status['totalBytes'] != photo.bytes.length)
        throw const FormatException('Upload di un’altra prova.');
      var offset = missionInt(status, 'receivedBytes');
      if (offset > photo.bytes.length)
        throw const FormatException('Posizione upload non valida.');
      while (offset < photo.bytes.length) {
        final end = min(offset + 32768, photo.bytes.length);
        status = missionObject(
          await client.putJson(
            ['v1', 'uploads', photo.uploadId!, 'chunks'],
            body: {
              'offset': offset,
              'dataBase64': base64Encode(photo.bytes.sublist(offset, end)),
            },
            headers: lease.headers,
          ),
        );
        _checkLease(lease, municipalityAtStart);
        final accepted = missionInt(status, 'receivedBytes');
        if (accepted != end)
          throw const FormatException('Chunk non confermato.');
        offset = accepted;
      }
      if (status['status'] != 'complete') {
        status = missionObject(
          await client.postJson(
            ['v1', 'uploads', photo.uploadId!, 'complete'],
            body: {},
            headers: lease.headers,
          ),
        );
        _checkLease(lease, municipalityAtStart);
        if (status['status'] != 'complete')
          throw const FormatException('Prova non finalizzata.');
      }
    }
    return draft;
  }

  Future<MissionReceipt?> lookup(MissionDraft draft) async {
    _checkDraftScope(draft);
    final body = draft.submitBody;
    if (body == null) return null;
    final municipalityAtStart = _municipalityLease;
    final lease = await _active(municipalityAtStart);
    try {
      final raw = await client.getJson([
        'v1',
        'bookings',
        draft.bookingId,
        'receipts',
        body['idempotencyKey'] as String,
      ], headers: lease.headers);
      _checkLease(lease, municipalityAtStart);
      return _receipt(raw, draft);
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        _checkLease(lease, municipalityAtStart);
        return null;
      }
      rethrow;
    }
  }

  MissionReceipt _receipt(Object? raw, MissionDraft draft) {
    final r = MissionReceipt.fromJson(raw);
    final definition = draft.missionSnapshot == null
        ? null
        : Mission.fromJson(draft.missionSnapshot).measurementDefinition;
    if (r.measurement case final value?) {
      if (definition == null ||
          value.unit != definition.unit ||
          value.indicator != definition.indicator ||
          value.protocolId != definition.protocolId ||
          value.protocolVersion != definition.protocolVersion)
        throw const FormatException(
          'Ricevuta di un altro protocollo di misura.',
        );
    }
    if ((draft.scope.length == 8 &&
            r.snapshot['replicationRequestId'] != draft.scope[7]) ||
        r.bookingId != draft.bookingId ||
        r.missionId != draft.scope[3] ||
        r.municipalityId != draft.scope[2] ||
        r.windowId != draft.scope[6] ||
        r.answer.name != draft.submitBody?['answer'] ||
        r.measurement?.value !=
            (draft.submitBody?['measurement'] == null
                ? null
                : missionObject(draft.submitBody!['measurement'])['value']) ||
        r.protocolVersion.toString() != draft.scope[5] ||
        jsonEncode(r.proofIds) != jsonEncode(draft.submitBody?['proofIds']))
      throw const FormatException('Ricevuta di un’altra osservazione.');
    return r;
  }

  Future<MissionReceipt> submit(MissionDraft initial) async {
    _checkDraftScope(initial);
    var draft = initial;
    final municipalityAtStart = _municipalityLease;
    final lease = await _active(municipalityAtStart);
    if (draft.submitBody != null) {
      final receipt = await lookup(draft);
      _checkLease(lease, municipalityAtStart);
      if (receipt != null) {
        await _saveReceipt(draft, receipt, lease);
        return receipt;
      }
    } else {
      if (draft.answer == null)
        throw StateError('Scegli una risposta al questionario.');
      final definition = draft.missionSnapshot == null
          ? null
          : Mission.fromJson(draft.missionSnapshot).measurementDefinition;
      if (definition != null &&
          definition.requiresValue(draft.answer) &&
          definition.validate(draft.measurementValue?.toString()) != null)
        throw StateError(
          definition.validate(draft.measurementValue?.toString())!,
        );
      draft = await upload(draft);
      _checkLease(lease, municipalityAtStart);
      final body = <String, Object?>{
        'idempotencyKey': newLocalId(),
        'expectedRevision': draft.bookingRevision,
        'protocolVersion': int.parse(draft.scope[5]),
        'answer': draft.answer!.name,
        'notes': draft.notes,
        if (definition != null && definition.requiresValue(draft.answer))
          'measurement': {'value': draft.measurementValue},
        'proofIds': draft.photos.map((p) => p.uploadId!).toList(),
      };
      draft = draft.copy(submitBody: body);
      await drafts.save(
        draft,
        epoch: lease.epoch,
        check: () => _checkLease(lease, municipalityAtStart),
      );
    }
    Object? raw;
    try {
      raw = await client.postJson(
        ['v1', 'bookings', draft.bookingId, 'observations'],
        body: draft.submitBody!,
        headers: lease.headers,
      );
      _checkLease(lease, municipalityAtStart);
    } on ApiException catch (failure) {
      if ([
        'booking_expired',
        'booking_revision_conflict',
        'protocol_version_conflict',
        'proof_invalid',
        'proof_required',
        'invalid_field',
      ].contains(failure.code)) {
        _checkLease(lease, municipalityAtStart);
        final receipt = await lookup(draft);
        _checkLease(lease, municipalityAtStart);
        if (receipt != null) {
          await _saveReceipt(draft, receipt, lease);
          return receipt;
        }
        await drafts.save(
          draft.copy(rejectionCode: failure.code),
          epoch: lease.epoch,
          check: () => _checkLease(lease, municipalityAtStart),
        );
      }
      rethrow;
    }
    final receipt = _receipt(raw, draft);
    await _saveReceipt(draft, receipt, lease);
    return receipt;
  }

  Future<void> _saveReceipt(
    MissionDraft draft,
    MissionReceipt receipt,
    ProposalSessionLease lease,
  ) async {
    final municipalityAtStart = (draft.scope[2], _municipalityGeneration);
    // Persist the exact acknowledgement; never recompute XP or a fantasy trend.
    await drafts.save(
      draft.copy(receipt: receipt.snapshot),
      epoch: lease.epoch,
      check: () => _checkLease(lease, municipalityAtStart),
    );
  }

  Future<void> discard(Mission mission, {String? replicationRequestId}) async {
    final municipalityAtStart = _municipalityLease;
    final lease = localLease();
    final currentScope = scope(
      mission,
      replicationRequestId: replicationRequestId,
    );
    final draft = drafts.read(currentScope);
    if (draft?.submitBody != null &&
        draft?.receipt == null &&
        draft?.rejectionCode == null)
      throw StateError(
        'Invio incerto: recupera la ricevuta prima di rimuovere la bozza.',
      );
    await drafts.remove(
      currentScope,
      epoch: lease.epoch,
      check: () => _checkLease(lease, municipalityAtStart),
    );
    await data.mutate<void>(
      'mission-booking-intent:${jsonEncode(currentScope)}',
      (_) {
        _checkLease(lease, municipalityAtStart);
        return const LocalDataMutation(null, null);
      },
      expectedEpoch: lease.epoch,
      check: () => _checkLease(lease, municipalityAtStart),
    );
  }
}
