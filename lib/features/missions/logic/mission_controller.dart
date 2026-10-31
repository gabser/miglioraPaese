import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import '../data/mission_repository.dart';
import '../data/mission_photo_picker.dart';
import '../domain/mission_models.dart';

class MissionController extends ChangeNotifier {
  MissionController({
    required this.repository,
    MissionPhotoPicker? picker,
    this.municipalityChanges,
  }) : picker = picker ?? DeviceMissionPhotoPicker() {
    _lastMunicipality = repository.municipalityId;
    municipalityChanges?.addListener(_municipalityChanged);
    repository.account.addListener(_identityChanged);
    repository.data.addListener(_localChanged);
  }
  final MissionRepository repository;
  final MissionPhotoPicker picker;
  final Listenable? municipalityChanges;
  late String _lastMunicipality;
  void _municipalityChanged() {
    if (_lastMunicipality == repository.municipalityId) return;
    _lastMunicipality = repository.municipalityId;
    catalog = const [];
    mission = null;
    _identityChanged();
  }

  List<Mission> catalog = const [];
  Mission? mission;
  MissionBooking? booking;
  MissionDraft? draft;
  MissionReceipt? receipt;
  String? error, zoneId;
  bool busy = false, _disposed = false;
  int _generation = 0;
  bool get accountReady =>
      repository.account.hasCredentials &&
      !repository.account.signingOut &&
      !repository.account.authenticating;
  bool get uncertain =>
      draft?.submitBody != null &&
      draft?.receipt == null &&
      draft?.rejectionCode == null;
  bool get editable =>
      draft != null && draft!.submitBody == null && booking?.status == 'active';
  List<MissionDraft> get archives {
    if (!accountReady || mission == null) return const [];
    final expected = repository.scope(mission!);
    return repository.data
        .keysWithPrefix('mission-draft:')
        .map((k) => MissionDraft.fromJson(repository.data.read(k)))
        .where(
          (d) =>
              [7, 8].contains(d.scope.length) &&
              d.scope.take(4).join('/') == expected.take(4).join('/') &&
              jsonEncode(d.scope) != jsonEncode(expected),
        )
        .toList();
  }

  void _identityChanged() {
    _generation++;
    busy = false;
    draft = null;
    booking = null;
    receipt = null;
    error = null;
    if (!_disposed) notifyListeners();
  }

  void _localChanged() {
    if (repository.data.resetting) _identityChanged();
  }

  String message(Object failure) => failure is ApiException
      ? switch (failure.code) {
          'mission_full' =>
            'Tutti i posti sono occupati. Aggiorna il catalogo: nessuna prenotazione è stata confermata.',
          'booking_expired' =>
            'La prenotazione è scaduta. La bozza resta conservata.',
          'booking_revision_conflict' || 'protocol_version_conflict' =>
            'Il server ha una revisione diversa. Aggiorna prima di proseguire; la bozza è conservata.',
          'proof_required' => 'Aggiungi le prove richieste dal protocollo.',
          'account_required' ||
          'proposal_session_revoked' ||
          'session_expired' =>
            'Accedi con un account verificato per proseguire.',
          _ =>
            failure.isRetryable
                ? 'Servizio non raggiungibile. Bozza conservata. Un invio senza ricevuta resta da verificare.'
                : failure.message,
        }
      : failure is LocalDataWriteException
      ? 'Salvataggio locale non riuscito. I dati precedenti sono conservati: riprova.'
      : failure is LocalDataResetException
      ? 'L’identità è cambiata. Accedi di nuovo prima di proseguire.'
      : failure.toString().replaceFirst('Bad state: ', '');
  Future<bool> _run(Future<void> Function(int generation) action) async {
    if (busy || _disposed) return false;
    final g = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action(g);
      return !_disposed && g == _generation;
    } catch (failure) {
      if (!_disposed && g == _generation) error = message(failure);
      return false;
    } finally {
      if (!_disposed && g == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void _check(int g) {
    if (_disposed || g != _generation) throw const LocalDataResetException();
  }

  Future<bool> browse({String? zone}) => _run((g) async {
    final items = await repository.catalog(zoneId: zone);
    _check(g);
    catalog = items;
    zoneId = zone;
  });
  String? _replicationRequestId;
  Future<bool> open(String id, {String? bookingId}) => _run((g) async {
    _replicationRequestId = null;
    mission = null;
    draft = null;
    booking = null;
    receipt = null;
    final value = await repository.detail(id);
    _check(g);
    mission = value;
    if (accountReady) {
      try {
        if (bookingId != null) {
          final b = await repository.restoreReplica(value, bookingId);
          _check(g);
          booking = b;
          _replicationRequestId = b.replicationRequestId;
          draft = repository.restore(
            value,
            replicationRequestId: _replicationRequestId,
          );
        } else {
          draft = repository.restore(value);
          final b = draft == null
              ? await repository.existing(value)
              : await repository.booking(value, draft!.bookingId);
          _check(g);
          booking = b;
          draft = repository.restore(value);
        }
        if (draft?.receipt != null)
          receipt = MissionReceipt.fromJson(draft!.receipt);
      } catch (failure) {
        _check(g);
        error = message(failure);
      }
    }
  });
  Future<bool> openArchive(MissionDraft archived) => _run((g) async {
    final m = Mission.fromJson(archived.missionSnapshot);
    if (jsonEncode(
          repository.scope(
            m,
            replicationRequestId: archived.scope.length == 8
                ? archived.scope[7]
                : null,
          ),
        ) !=
        jsonEncode(archived.scope))
      throw const LocalDataResetException();
    _check(g);
    _replicationRequestId = archived.scope.length == 8
        ? archived.scope[7]
        : null;
    mission = m;
    draft = archived;
    receipt = archived.receipt == null
        ? null
        : MissionReceipt.fromJson(archived.receipt);
    booking = await repository.booking(m, archived.bookingId);
    _check(g);
    if (booking!.replicationRequestId != _replicationRequestId)
      throw const FormatException('Prenotazione di un altro scope replica.');
  });
  Future<bool> reserve() => _run((g) async {
    if (_replicationRequestId != null)
      throw StateError(
        'Per una replica serve una nuova richiesta del verificatore.',
      );
    final b = await repository.book(mission!);
    _check(g);
    booking = b;
    draft = repository.restore(
      mission!,
      replicationRequestId: _replicationRequestId,
    );
  });
  Future<bool> release() => _run((g) async {
    final b = await repository.release(mission!, booking!);
    _check(g);
    booking = b;
  });
  Future<bool> saveAnswer(MissionAnswer answer) => _run((g) async {
    if (!editable) return;
    final value = draft!.copy(
      answer: answer,
      clearMeasurement:
          answer == MissionAnswer.unsure ||
          answer == MissionAnswer.nonObservable,
    );
    await repository.save(value);
    _check(g);
    draft = value;
  });
  Future<bool> saveMeasurement(String text) => _run((g) async {
    if (!editable) throw StateError('Bozza non modificabile.');
    final def = mission?.measurementDefinition;
    if (def == null) return;
    final needed = def.requiresValue(draft!.answer);
    if (needed && def.validate(text) != null)
      throw StateError(def.validate(text)!);
    final value = draft!.copy(
      measurementValue: needed
          ? num.parse(text.trim().replaceAll(',', '.'))
          : null,
      clearMeasurement: !needed,
    );
    await repository.save(value);
    _check(g);
    draft = value;
  });
  Future<bool> saveNotes(String notes) => _run((g) async {
    if (!editable) return;
    final value = draft!.copy(notes: notes);
    await repository.save(value);
    _check(g);
    draft = value;
  });
  Future<bool> addPhoto({required bool camera}) => _run((g) async {
    if (!editable) return;
    final lease = repository.localLease();
    final raw = await picker.pick(camera: camera);
    repository.account.checkLease(lease);
    _check(g);
    if (raw == null)
      throw StateError(
        'Acquisizione annullata o permesso negato. Puoi scegliere un file sintetico senza posizione GPS.',
      );
    final bytes = await MissionPhotoNormalizer.normalize(raw);
    repository.account.checkLease(lease);
    _check(g);
    final value = draft!.copy(
      photos: [
        ...draft!.photos,
        MissionPhoto(id: newLocalId(), bytes: bytes),
      ],
    );
    await repository.save(value);
    _check(g);
    draft = value;
  });
  Future<bool> removePhoto(String id) => _run((g) async {
    if (!editable) return;
    final value = draft!.copy(
      photos: draft!.photos.where((p) => p.id != id).toList(),
    );
    await repository.save(value);
    _check(g);
    draft = value;
  });
  Future<bool> send() => _run((g) async {
    MissionReceipt accepted;
    try {
      accepted = await repository.submit(draft!);
    } finally {
      if (!_disposed && g == _generation)
        draft = repository.restore(
          mission!,
          replicationRequestId: _replicationRequestId,
        );
    }
    _check(g);
    receipt = accepted;
    try {
      booking = await repository.booking(mission!, draft!.bookingId);
      _check(g);
    } catch (failure) {
      _check(g);
      error = message(failure);
    }
  });
  Future<bool> recover() => _run((g) async {
    final found = await repository.lookup(draft!);
    _check(g);
    if (found == null)
      throw StateError(
        'Il server non ha una ricevuta per questo invio. Puoi ritentare conservando la stessa chiave.',
      );
    // submit rechecks the receipt and durably saves the exact snapshot.
    MissionReceipt accepted;
    try {
      accepted = await repository.submit(draft!);
    } finally {
      if (!_disposed && g == _generation)
        draft = repository.restore(
          mission!,
          replicationRequestId: _replicationRequestId,
        );
    }
    _check(g);
    receipt = accepted;
  });
  Future<bool> discard() => _run((g) async {
    if (booking?.status == 'active' && draft?.rejectionCode == null)
      throw StateError(
        'Rinuncia prima alla prenotazione dal server. La bozza è conservata.',
      );
    await repository.discard(
      mission!,
      replicationRequestId: _replicationRequestId,
    );
    _check(g);
    draft = null;
    receipt = null;
    booking = null;
  });
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    municipalityChanges?.removeListener(_municipalityChanged);
    repository.account.removeListener(_identityChanged);
    repository.data.removeListener(_localChanged);
    super.dispose();
  }
}
