import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import '../data/measurement_repository.dart';
import '../domain/measurement_models.dart';

class MeasurementController extends ChangeNotifier {
  MeasurementController(this.repository) {
    _municipality = repository.municipalityId;
    _epoch = repository.account.data.epoch;
    _accountGeneration = repository.account.generation;
    repository.municipalityChanges?.addListener(_changed);
    repository.account.addListener(_changed);
    repository.account.data.addListener(_changed);
  }
  final MeasurementRepository repository;
  late String _municipality;
  late int _epoch, _accountGeneration;
  int _generation = 0;
  bool _disposed = false, busy = false, supervisor = false;
  String? error;
  MeasurementOverview? overview;
  MeasurementWorkspace? workspace;
  EvaluationPublished? current;
  List<EvaluationPublished> history = const [];
  Map<String, dynamic>? caseWorkspace, lastCommand;
  Uint8List? preview;
  void _changed() {
    if (_municipality == repository.municipalityId &&
        _epoch == repository.account.data.epoch &&
        _accountGeneration == repository.account.generation &&
        !repository.account.data.resetting)
      return;
    _municipality = repository.municipalityId;
    _epoch = repository.account.data.epoch;
    _accountGeneration = repository.account.generation;
    _clear();
  }

  void _clear() {
    _generation++;
    busy = false;
    supervisor = false;
    overview = null;
    workspace = null;
    current = null;
    history = const [];
    caseWorkspace = null;
    lastCommand = null;
    preview = null;
    error = null;
    if (!_disposed) notifyListeners();
  }

  void selectScope(String? season, String? day) {
    repository.selectScope(season, day);
    _clear();
  }

  void _valid(int g) {
    if (_disposed || g != _generation) throw const LocalDataResetException();
  }

  Future<bool> run(Future<void> Function(int) action) async {
    if (busy) return false;
    final g = _generation, rg = repository.generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action(g);
      _valid(g);
      if (rg != repository.generation) throw const LocalDataResetException();
      return true;
    } catch (e) {
      if (!_disposed && g == _generation)
        error = e is ApiException
            ? (e.isRetryable
                  ? 'Connessione assente o risposta incerta. La richiesta è conservata: riprova per recuperarla.'
                  : 'Richiesta rifiutata dal server (${e.code}). Aggiorna il caso e verifica le autorizzazioni.')
            : e is LocalDataWriteException
            ? 'Salvataggio locale non riuscito. Nessun nuovo comando inviato.'
            : e is StateError
            ? e.message.toString()
            : 'Dati non disponibili. Aggiorna e riprova.';
      return false;
    } finally {
      if (!_disposed && g == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> browse() => run((g) async {
    final v = await repository.overview();
    _valid(g);
    overview = v;
  });
  Future<bool> loadWorkspace() => run((g) async {
    final caps = await repository.review.capabilities();
    _valid(g);
    supervisor = caps.roles.contains('outcomesSupervisor');
    if (!supervisor) {
      workspace = null;
      return;
    }
    final v = await repository.workspace();
    _valid(g);
    workspace = v;
  });
  Future<bool> open(String id, {bool private = false}) => run((g) async {
    current = null;
    history = const [];
    caseWorkspace = null;
    preview = null;
    final e = await repository.evaluation(id);
    _valid(g);
    current = e;
    final h = await repository.history(id);
    _valid(g);
    history = h;
    if (private) {
      final v = await repository.caseDetail(id);
      _valid(g);
      caseWorkspace = v;
    }
  });
  Future<bool> openDraft(String id) => run((g) async {
    final caps = await repository.review.capabilities();
    _valid(g);
    supervisor = caps.roles.contains('outcomesSupervisor');
    final work = await repository.workspace();
    _valid(g);
    workspace = work;
    final v = await repository.caseDetail(id);
    _valid(g);
    caseWorkspace = v;
    current = v['currentPublished'] == null
        ? null
        : EvaluationPublished.fromJson(v['currentPublished']);
    history = List.unmodifiable(
      (v['history'] as List).map(EvaluationPublished.fromJson),
    );
  });
  Future<bool> command(List<String> tail, Map<String, Object?> fields) =>
      run((g) async {
        final v = await repository.command(tail, fields);
        _valid(g);
        lastCommand = v;
      });
  Future<bool> recoverAppeal(String evaluationId, String appealId) =>
      run((g) async {
        final a = await repository.appealDetail(evaluationId, appealId);
        _valid(g);
        lastCommand = a;
      });
  Future<bool> showProof(String id, MissionProof proof) => run((g) async {
    final v = await repository.proof(id, proof);
    _valid(g);
    preview = v;
  });
  void closeProof() {
    preview = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    repository.municipalityChanges?.removeListener(_changed);
    repository.account.removeListener(_changed);
    repository.account.data.removeListener(_changed);
    super.dispose();
  }
}
