import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'continuity_repository.dart';
import 'continuity_models.dart';

class LeagueInviteController extends ChangeNotifier {
  LeagueInviteController(this.repository) {
    repository.addListener(_changed);
  }
  final LeagueContinuityRepository repository;
  LeagueInvitePreview? summary;
  bool busy = false, teamReady = false, joined = false;
  String? message;
  int _generation = 0;
  bool _disposed = false;
  void _changed() {
    _generation++;
    summary = null;
    teamReady = false;
    joined = false;
    busy = false;
    message = null;
    notifyListeners();
  }

  Future<void> _run(Future<void> Function(int) action) async {
    if (busy) return;
    final g = ++_generation;
    busy = true;
    message = null;
    notifyListeners();
    try {
      await action(g);
    } catch (e) {
      if (g == _generation && !_disposed) {
        if (e is ApiException &&
            [400, 403, 404, 409, 422].contains(e.statusCode)) {
          summary = null;
          teamReady = false;
        }
        message = e is LocalDataResetException
            ? 'La sessione o lo scope è cambiato. Ricarica il riepilogo.'
            : e is ApiException && e.code == 'league_revision_conflict'
            ? 'La lega o il ruolo è cambiato. Rileggi il riepilogo prima di confermare.'
            : 'Operazione non confermata. Ricarica per verificare o riprova.';
      }
    } finally {
      if (g == _generation && !_disposed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  bool _current(int g) => !_disposed && g == _generation;
  Future<void> preview([String? token]) => _run((g) async {
    summary = null;
    teamReady = false;
    joined = false;
    if (token != null) await repository.rememberInvite(token.trim());
    final p = await repository.preview();
    if (_current(g)) summary = p;
    // Public preview never bootstraps a session, player, or enrollment.
  });
  Future<void> checkTeam() => _run((g) async {
    final p = summary;
    if (p == null) return;
    final ready = await repository.hasTeam(p);
    if (_current(g)) {
      teamReady = ready;
      message = ready
          ? 'Squadra già presente. Conferma esplicitamente l’adesione.'
          : 'Per proseguire serve una squadra in questo Comune e stagione.';
    }
  });
  Future<void> enroll() => _run((g) async {
    final p = summary;
    if (p == null) return;
    await repository.enroll(p);
    if (_current(g)) {
      teamReady = true;
      message = 'Squadra pronta. Ora conferma l’adesione alla lega.';
    }
  });
  Future<void> confirm() => _run((g) async {
    final p = summary;
    if (p == null || !teamReady) return;
    await repository.join(p);
    if (_current(g)) {
      joined = true;
      message = 'Adesione confermata dal server.';
    }
  });
  @override
  void dispose() {
    _disposed = true;
    _generation++;
    repository.removeListener(_changed);
    super.dispose();
  }
}
