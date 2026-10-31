import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/missions/data/mission_photo_picker.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import '../data/review_repository.dart';
import '../domain/review_models.dart';

class ReviewController extends ChangeNotifier {
  ReviewController({required this.repository, MissionPhotoPicker? picker})
    : picker = picker ?? DeviceMissionPhotoPicker() {
    _municipality = repository.municipalityId;
    _epoch = repository.account.data.epoch;
    _accountGeneration = repository.account.generation;
    repository.municipalityChanges?.addListener(_scopeChanged);
    repository.account.addListener(_scopeChanged);
    repository.account.data.addListener(_scopeChanged);
  }
  final ReviewRepository repository;
  final MissionPhotoPicker picker;
  late String _municipality;
  late int _epoch, _accountGeneration;
  int _generation = 0;
  bool _disposed = false, busy = false, author = false;
  ReviewCapabilities? capabilities;
  List<ObservationLive> queue = const [];
  ObservationLive? observation;
  XpLedger? ledger;
  Uint8List? preview;
  List<MissionPhoto> photos = const [];
  String notes = '', replicationId = '';
  bool supplementUncertain = false;
  Map<String, dynamic>? replica;
  MissionBooking? replicaBooking;
  String? error, statusFilter;
  String get principalId => repository.account.current?.id ?? '';
  bool get assigned =>
      observation?.assignedTo == principalId && principalId.isNotEmpty;
  void _scopeChanged() {
    if (_municipality == repository.municipalityId &&
        _epoch == repository.account.data.epoch &&
        _accountGeneration == repository.account.generation &&
        !repository.account.data.resetting)
      return;
    _municipality = repository.municipalityId;
    _epoch = repository.account.data.epoch;
    _accountGeneration = repository.account.generation;
    _generation++;
    busy = false;
    capabilities = null;
    queue = const [];
    observation = null;
    ledger = null;
    preview = null;
    photos = const [];
    notes = '';
    replica = null;
    replicaBooking = null;
    error = null;
    supplementUncertain = false;
    if (!_disposed) notifyListeners();
  }

  void _valid(int g) {
    if (_disposed || g != _generation) throw const LocalDataResetException();
  }

  Future<void> _run(Future<void> Function(int) action) async {
    if (busy) return;
    busy = true;
    error = null;
    preview = null;
    notifyListeners();
    final g = _generation;
    try {
      await action(g);
      _valid(g);
    } catch (e) {
      if (!_disposed && g == _generation) {
        error = e is ApiException
            ? switch (e.code) {
                'review_forbidden' || 'self_review' || 'competitive_conflict' =>
                  'Accesso o revisione non consentiti per questo account e Comune.',
                'review_revision_conflict' =>
                  'Revisione cambiata: aggiorna il caso prima di decidere.',
                'integration_closed' || 'replication_closed' =>
                  'La richiesta è chiusa o scaduta. Aggiorna lo stato.',
                'account_required' || 'session_expired' =>
                  'Accedi nuovamente con il tuo account verificato.',
                _ =>
                  e.isRetryable
                      ? 'Connessione assente o risposta incerta. La richiesta è conservata: riprova per recuperare lo stesso risultato.'
                      : 'Il server ha rifiutato la richiesta (${e.code}).',
              }
            : e is LocalDataResetException
            ? 'Account o Comune cambiato. Riapri il caso.'
            : e is LocalDataWriteException
            ? 'Salvataggio locale non riuscito. Nessun nuovo comando inviato.'
            : e is StateError
            ? e.message.toString()
            : 'Risposta non valida. Aggiorna e riprova.';
      }
    } finally {
      if (!_disposed && g == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> browse({String? status}) => _run((g) async {
    author = false;
    observation = null;
    statusFilter = status;
    final caps = await repository.capabilities();
    _valid(g);
    capabilities = caps;
    if (!caps.canReview) {
      queue = const [];
      return;
    }
    final items = await repository.queue(status: status);
    _valid(g);
    queue = items;
  });
  Future<void> open(String id, {bool author = false}) => _run((g) async {
    this.author = author;
    observation = null;
    photos = const [];
    notes = '';
    supplementUncertain = false;
    if (!author) {
      final caps = await repository.capabilities();
      _valid(g);
      capabilities = caps;
    }
    ObservationLive o;
    if (author) {
      o = await repository.detail(id, author: true);
    } else {
      final items = await repository.queue();
      _valid(g);
      final matches = items.where((item) => item.id == id).toList();
      if (matches.isEmpty)
        throw StateError('Caso non presente nella coda autorizzata.');
      o = matches.single;
      if (o.assignedTo == principalId) o = await repository.detail(id);
    }
    _valid(g);
    observation = o;
    if (author && o.integration != null) {
      final d = await repository.supplementDraft(o);
      _valid(g);
      if (d != null) {
        notes = d['notes'] as String;
        photos = (d['photos'] as List).map(MissionPhoto.fromJson).toList();
        supplementUncertain = d['body'] != null;
      }
    }
    if (author) {
      final xp = await repository.ledger();
      _valid(g);
      ledger = xp;
    }
  });
  Future<void> loadLedger() => _run((g) async {
    final xp = await repository.ledger();
    _valid(g);
    ledger = xp;
  });
  Future<void> command(
    String action, {
    String? decision,
    String? reason,
    String? message,
  }) => _run((g) async {
    final o = observation!;
    final next = await repository.command(
      o,
      action,
      decision: decision,
      reason: reason,
      message: message,
    );
    _valid(g);
    observation = next;
  });
  Future<void> showProof(MissionProof p) => _run((g) async {
    final bytes = await repository.proof(observation!, p, author: author);
    _valid(g);
    preview = bytes;
  });
  void closeProof() {
    preview = null;
    notifyListeners();
  }

  Future<void> addPhoto(String currentNotes) => _run((g) async {
    if (supplementUncertain)
      throw StateError('Invio incerto: recupera prima di modificare.');
    if (photos.length >= 3) throw StateError('Massimo tre prove sintetiche.');
    final source = await picker.pick(camera: false);
    _valid(g);
    if (source == null) return;
    final normalized = await MissionPhotoNormalizer.normalize(source);
    _valid(g);
    final next = [...photos, MissionPhoto(id: newLocalId(), bytes: normalized)];
    await repository.saveSupplement(observation!, currentNotes, next);
    _valid(g);
    photos = next;
    notes = currentNotes;
  });
  Future<void> saveSupplement(String value) => _run((g) async {
    await repository.saveSupplement(observation!, value, photos);
    _valid(g);
    notes = value;
  });
  Future<void> supplement(String value) => _run((g) async {
    if (!supplementUncertain) {
      await repository.saveSupplement(observation!, value, photos);
      _valid(g);
      notes = value;
    }
    supplementUncertain = true;
    ObservationLive next;
    try {
      next = await repository.submitSupplement(observation!);
    } on ApiException catch (e) {
      _valid(g);
      if (e.kind == ApiExceptionKind.response &&
          [
            'review_revision_conflict',
            'integration_closed',
            'proof_invalid',
            'invalid_field',
          ].contains(e.code))
        supplementUncertain = false;
      rethrow;
    }
    _valid(g);
    observation = next;
    photos = const [];
    notes = '';
    supplementUncertain = false;
  });
  Future<void> requestReplication(String reason) => _run((g) async {
    final result = await repository.replication(observation!, reason);
    _valid(g);
    replicationId = result['id'] as String;
  });
  Future<void> inspectReplica(String id) => _run((g) async {
    final result = await repository.replicationDetail(id);
    _valid(g);
    replica = result;
    replicaBooking = null;
  });
  Future<void> acceptReplica() => _run((g) async {
    final booking = await repository.acceptReplication(
      replica!['id'] as String,
    );
    _valid(g);
    replicaBooking = booking;
  });
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    repository.municipalityChanges?.removeListener(_scopeChanged);
    repository.account.removeListener(_scopeChanged);
    repository.account.data.removeListener(_scopeChanged);
    super.dispose();
  }
}
