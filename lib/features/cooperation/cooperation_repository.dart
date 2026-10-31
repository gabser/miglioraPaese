import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'package:fanta_comune/features/missions/domain/mission_models.dart';
import 'cooperation_models.dart';

/// API owned progress and messages. No client event generation or local unread state.
class CooperationRepository extends ChangeNotifier {
  CooperationRepository({
    required this.client,
    required this.account,
    required this.municipality,
    this.municipalityChanges,
  }) {
    _m = municipality();
    _a = account.generation;
    _e = account.data.epoch;
    municipalityChanges?.addListener(_changed);
    account.addListener(_changed);
    account.data.addListener(_changed);
  }
  final ApiClient client;
  final AccountSessionStore account;
  final String Function() municipality;
  final Listenable? municipalityChanges;
  late String _m;
  late int _a, _e;
  int generation = 0;
  String? seasonId, matchdayId;
  String get municipalityId => municipality();
  void _changed() {
    if (_m == municipalityId &&
        _a == account.generation &&
        _e == account.data.epoch &&
        !account.data.resetting)
      return;
    if (_m != municipalityId) {
      seasonId = null;
      matchdayId = null;
    }
    _m = municipalityId;
    _a = account.generation;
    _e = account.data.epoch;
    generation++;
    notifyListeners();
  }

  void selectScope(String? season, String? day) {
    if ((season == null) != (day == null))
      throw ArgumentError('Seleziona stagione e giornata insieme.');
    if (season == seasonId && day == matchdayId) return;
    seasonId = season;
    matchdayId = day;
    generation++;
    notifyListeners();
  }

  void check(int g) {
    if (g != generation || account.data.resetting)
      throw const LocalDataResetException();
  }

  Future<Object?> _request(
    List<String> path, {
    bool private = false,
    String method = 'GET',
    Map<String, String?> query = const {},
  }) async {
    final g = generation, a = account.generation, e = account.data.epoch;
    final lease = private ? await account.active() : null;
    void valid() {
      check(g);
      account.check(a, e);
      if (lease != null) account.checkLease(lease);
    }

    valid();
    final headers = lease?.headers ?? const <String, String>{};
    final raw = await switch (method) {
      'PUT' => client.putJson(
        path,
        body: const {},
        headers: headers,
        queryParameters: query,
      ),
      'DELETE' => client.deleteJson(
        path,
        headers: headers,
        queryParameters: query,
      ),
      _ => client.getJson(path, headers: headers, queryParameters: query),
    };
    valid();
    return raw;
  }

  Future<CooperationProgress> progress({
    String? leagueId,
    String? leagueSeasonId,
    String? day,
  }) async {
    final m = municipalityId;
    final p = CooperationProgress.fromJson(
      await _request(
        leagueId == null
            ? ['v1', 'municipalities', m, 'cooperation']
            : [
                'v1',
                'fantasy',
                'municipalities',
                m,
                'leagues',
                leagueId,
                'cooperation',
              ],
        private: leagueId != null,
        query: {
          if (leagueId == null) 'seasonId': seasonId,
          'matchdayId': day ?? (leagueId == null ? matchdayId : null),
        },
      ),
    );
    if (p.municipalityId != m ||
        p.leagueId != leagueId ||
        (leagueId == null && seasonId != null && p.seasonId != seasonId) ||
        (leagueSeasonId != null && p.seasonId != leagueSeasonId) ||
        ((day ?? (leagueId == null ? matchdayId : null)) != null &&
            p.matchdayId != (day ?? (leagueId == null ? matchdayId : null))))
      throw const FormatException('Progresso di un altro scope.');
    return p;
  }

  Future<InboxPageData> inbox({String? cursor, int limit = 20}) async {
    if (limit < 1 || limit > 50 || (cursor?.length ?? 0) > 2048)
      throw ArgumentError('Pagina non valida.');
    final m = municipalityId;
    final p = InboxPageData.fromJson(
      await _request(
        ['v1', 'me', 'inbox'],
        private: true,
        query: {'municipalityId': m, 'limit': '$limit', 'cursor': cursor},
      ),
    );
    if (p.items.any((i) => i.municipalityId != m))
      throw const FormatException('Inbox di un altro Comune.');
    return p;
  }

  Future<void> read(String id) async {
    final m = missionObject(
      await _request(
        ['v1', 'me', 'inbox', id, 'read'],
        private: true,
        method: 'PUT',
      ),
    );
    if (m['messageId'] != id) throw const FormatException('Messaggio diverso.');
    missionDate(m, 'readAt');
  }

  Future<List<FollowedPlace>> followed() async {
    final m = municipalityId;
    final raw = missionObject(
      await _request(
        ['v1', 'me', 'followed-places'],
        private: true,
        query: {'municipalityId': m},
      ),
    );
    final places = List<FollowedPlace>.unmodifiable(
      (raw['items'] as List).map(FollowedPlace.fromJson),
    );
    if (places.any((p) => p.municipalityId != m))
      throw const FormatException('Luoghi di un altro Comune.');
    return places;
  }

  Future<void> follow(String id, bool following) async {
    final m = municipalityId;
    final v = missionObject(
      await _request(
        ['v1', 'me', 'followed-places', id],
        private: true,
        method: following ? 'PUT' : 'DELETE',
        query: {'municipalityId': m},
      ),
    );
    if (v['placeId'] != id ||
        v['municipalityId'] != m ||
        v['following'] != following)
      throw const FormatException('Preferenza incoerente.');
  }

  @override
  void dispose() {
    municipalityChanges?.removeListener(_changed);
    account.removeListener(_changed);
    account.data.removeListener(_changed);
    super.dispose();
  }
}
