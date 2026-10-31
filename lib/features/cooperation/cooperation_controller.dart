import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/features/review/data/review_repository.dart';
import 'package:fanta_comune/features/measurements/logic/measurement_controller.dart';
import 'cooperation_models.dart';
import 'cooperation_repository.dart';

class CooperationController extends ChangeNotifier {
  CooperationController(this.repository) {
    repository.addListener(_clear);
  }
  final CooperationRepository repository;
  bool busy = false, _disposed = false;
  int _generation = 0;
  String? error, cursor;
  int unread = 0;
  CooperationProgress? progress;
  List<InboxMessage> messages = const [];
  List<FollowedPlace> places = const [];
  void _clear() {
    _generation++;
    busy = false;
    error = null;
    cursor = null;
    unread = 0;
    progress = null;
    messages = const [];
    places = const [];
    notifyListeners();
  }

  Future<bool> run(Future<void> Function(void Function()) action) async {
    if (busy) return false;
    final g = _generation, rg = repository.generation;
    void check() {
      if (_disposed || g != _generation) throw StateError('Scope cambiato');
      repository.check(rg);
    }

    busy = true;
    error = null;
    notifyListeners();
    try {
      await action(check);
      check();
      return true;
    } catch (e) {
      if (!_disposed && g == _generation)
        error =
            e is ApiException &&
                [
                  'season_not_found',
                  'matchday_not_found',
                  'no_matchday',
                  'no_season',
                ].contains(e.code)
            ? 'Calendario non disponibile per il periodo richiesto.'
            : 'Dati non disponibili. Verifica account e Comune, poi riprova.';
      return false;
    } finally {
      if (!_disposed && g == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<bool> loadProgress() => run((check) async {
    final p = await repository.progress();
    check();
    progress = p;
  });
  Future<bool> loadInbox({bool more = false}) => run((check) async {
    final p = await repository.inbox(cursor: more ? cursor : null);
    check();
    messages = List.unmodifiable(
      {
        for (final m in [...(more ? messages : <InboxMessage>[]), ...p.items])
          m.id: m,
      }.values,
    );
    cursor = p.cursor;
    unread = p.unread;
  });
  Future<bool> markRead(InboxMessage message) => run((check) async {
    await repository.read(message.id);
    check();
    final p = await repository.inbox();
    check();
    messages = p.items;
    cursor = p.cursor;
    unread = p.unread;
  });
  Future<bool> loadPlaces() => run((check) async {
    final p = await repository.followed();
    check();
    places = p;
  });
  Future<bool> setFollow(String id, bool following) => run((check) async {
    await repository.follow(id, following);
    check();
    final p = await repository.followed();
    check();
    places = p;
  });

  /// Resolve owned targets before navigating. Opening never reserves or submits.
  Future<String?> resolve(
    InboxMessage m,
    ReviewRepository review,
    MeasurementController measurements,
  ) async {
    String? route;
    if (!await run((check) async {
      if (m.municipalityId != repository.municipalityId)
        throw StateError('Comune diverso');
      switch (m.target) {
        case MissionTarget(:final id):
          route = '/missions/${Uri.encodeComponent(id)}';
        case ObservationTarget(:final id):
          await review.detail(id, author: true);
          check();
          route = '/observations/${Uri.encodeComponent(id)}';
        case EvaluationTarget(:final id, :final seasonId, :final matchdayId):
          final evaluation = await measurements.repository.evaluation(id);
          check();
          if (evaluation.data['seasonId'] != seasonId ||
              evaluation.data['matchdayId'] != matchdayId)
            throw StateError('Esito di un altro periodo');
          measurements.selectScope(seasonId, matchdayId);
          route = '/measurements/evaluations/${Uri.encodeComponent(id)}';
        case RecheckTarget(:final id, :final missionId):
          final r = await review.replicationDetail(id);
          check();
          if (r['missionId'] != missionId ||
              r['authorId'] != repository.account.current?.id)
            throw StateError('Replica non propria');
          route =
              '/review?replicationRequestId=${Uri.encodeQueryComponent(id)}';
      }
      check();
    }))
      return null;
    return route;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    repository.removeListener(_clear);
    super.dispose();
  }
}
