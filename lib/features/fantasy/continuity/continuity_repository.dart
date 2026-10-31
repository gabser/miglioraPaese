import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/network/session_lease_source.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/data/account_session_store.dart';
import 'continuity_models.dart';
import 'invite_link.dart';

/// API-only. Invite intent is separate from commands bound to a stable principal.
class LeagueContinuityRepository extends ChangeNotifier {
  LeagueContinuityRepository({
    required this.client,
    required this.data,
    required this.sessions,
    required this.environment,
    required this.intentKey,
    required this.municipality,
    this.municipalityChanges,
    this.identityChanges,
    this.account,
  }) {
    _lastMunicipality = municipality();
    _lastEpoch = data.epoch;
    data.addListener(_dataChanged);
    municipalityChanges?.addListener(_scopeChanged);
    identityChanges?.addListener(_identityChanged);
  }
  final ApiClient client;
  final LocalDataStore data;
  final SessionLeaseSource sessions;
  final AccountSessionStore? account;
  final String environment, intentKey;
  final String Function() municipality;
  final Listenable? municipalityChanges, identityChanges;
  String? Function()? season;
  Listenable? seasonChanges;
  void observeSeason(Listenable changes, String? Function() readSeason) {
    seasonChanges?.removeListener(_seasonChanged);
    seasonChanges = changes;
    season = readSeason;
    _season = readSeason();
    changes.addListener(_seasonChanged);
  }

  void _seasonChanged() => selectSeason(season?.call());
  late String _lastMunicipality;
  String? _season;
  String? get seasonId => _season;
  late int _lastEpoch;
  void _dataChanged() {
    if (_lastEpoch != data.epoch) {
      _lastEpoch = data.epoch;
      generation++;
      notifyListeners();
    }
  }

  int generation = 0;
  bool _disposed = false;
  void _identityChanged() {
    generation++;
    notifyListeners();
  }

  void _scopeChanged() {
    if (_lastMunicipality != municipality()) {
      _lastMunicipality = municipality();
      _season = null;
      generation++;
      notifyListeners();
    }
  }

  void selectSeason(String? season) {
    if (_season != season) {
      _season = season;
      generation++;
      notifyListeners();
    }
  }

  void check(int g, int epoch, [ProposalSessionLease? lease]) {
    if (_disposed || generation != g || data.epoch != epoch || data.resetting)
      throw const LocalDataResetException();
    if (lease != null) sessions.checkLease(lease);
  }

  @override
  void dispose() {
    data.removeListener(_dataChanged);
    _disposed = true;
    generation++;
    seasonChanges?.removeListener(_seasonChanged);
    municipalityChanges?.removeListener(_scopeChanged);
    identityChanges?.removeListener(_identityChanged);
    super.dispose();
  }

  String? get inviteToken {
    final raw = data.read(intentKey);
    if (raw == null) return null;
    final token = object(raw)['token'];
    if (token is! String || !validInviteToken(token))
      throw const LocalDataCorruptException();
    return token;
  }

  Future<void> rememberInvite(String token) async {
    if (!validInviteToken(token))
      throw const FormatException('Invito non valido.');
    final g = ++generation, epoch = data.epoch;
    await data.mutate<void>(
      intentKey,
      (_) => LocalDataMutation({'token': token}, null),
      expectedEpoch: epoch,
      check: () => check(g, epoch),
    );
  }

  Future<LeagueInvitePreview> preview() async {
    final token = inviteToken;
    if (token == null)
      throw const FormatException('Inserisci un invito valido.');
    final g = generation, epoch = data.epoch;
    final raw = await client.postJson(
      ['v1', 'fantasy', 'league-invites', 'preview'],
      body: {'token': token},
    );
    check(g, epoch);
    if (token != inviteToken) throw const LocalDataResetException();
    return LeagueInvitePreview.fromJson(raw);
  }

  List<String> _path(String m, List<String> tail) => [
    'v1',
    'fantasy',
    'municipalities',
    m,
    ...tail,
  ];
  Map<String, String> _query(String s) => {'seasonId': s};
  Future<bool> hasTeam(LeagueInvitePreview p) async {
    final g = generation, epoch = data.epoch, lease = await sessions.active();
    check(g, epoch, lease);
    try {
      final raw = object(
        await client.getJson(
          _path(p.municipalityId, ['team']),
          headers: lease.headers,
          queryParameters: _query(p.seasonId),
        ),
      );
      check(g, epoch, lease);
      if (raw['seasonId'] != p.seasonId)
        throw const FormatException('Stagione diversa.');
      return true;
    } on ApiException catch (e) {
      check(g, epoch, lease);
      if (e.code == 'team_not_found' && e.statusCode == 404) return false;
      rethrow;
    }
  }

  Future<void> enroll(LeagueInvitePreview p) async {
    final g = generation, epoch = data.epoch;
    final lease = await sessions.active(allowCreate: true);
    check(g, epoch, lease);
    final raw = object(
      await client.postJson(
        _path(p.municipalityId, ['enrollment']),
        headers: lease.headers,
        queryParameters: _query(p.seasonId),
        body: {},
      ),
    );
    check(g, epoch, lease);
    if (raw['seasonId'] != p.seasonId)
      throw const FormatException('Stagione diversa.');
  }

  String _principal(ProposalSessionLease lease) {
    if (account?.hasCredentials == true) {
      final id = account?.current?.id;
      if (id == null) throw const LocalDataResetException();
      return 'account:$id';
    }
    return 'guest:${lease.submissionScope}';
  }

  String _key(
    String principal,
    String m,
    String s,
    String league,
    String kind,
  ) =>
      'league-continuity-command:${jsonEncode([environment, principal, m, s, league, kind])}';

  /// Reads never replay a command, including ownership recovery on a new device.
  Future<OwnershipWorkspace> ownership(String league, String season) async {
    final g = generation, epoch = data.epoch, m = municipality();
    final lease = await sessions.active();
    check(g, epoch, lease);
    final value = OwnershipWorkspace.fromJson(
      await client.getJson(
        _path(m, ['leagues', league, 'ownership']),
        headers: lease.headers,
        queryParameters: _query(season),
      ),
    );
    check(g, epoch, lease);
    if (value.leagueId != league || value.seasonId != season)
      throw const FormatException('Proprietà di un’altra lega o stagione.');
    return value;
  }

  Future<Map<String, dynamic>?> pendingOwnership(
    String league,
    String season,
  ) async {
    final g = generation, epoch = data.epoch, lease = await sessions.active();
    check(g, epoch, lease);
    final raw = data.read(
      _key(_principal(lease), municipality(), season, league, 'ownership'),
    );
    check(g, epoch, lease);
    return raw == null ? null : object(raw);
  }

  Future<void> join(LeagueInvitePreview p) async {
    final g = generation, epoch = data.epoch;
    final token = inviteToken;
    if (token == null) throw const FormatException('Invito mancante.');
    await _command(
      m: p.municipalityId,
      s: p.seasonId,
      league: p.leagueId,
      kind: 'join',
      tail: ['leagues', 'join'],
      fields: {
        'token': token,
        'expectedLeagueRevision': p.leagueRevision,
        'expectedRole': p.expectedRole,
      },
      idempotent: false,
    );
    // Successful server receipt is required before forgetting the navigation intent.
    check(g, epoch);
    if (inviteToken == token)
      await data.mutate<void>(
        intentKey,
        (_) => const LocalDataMutation(null, null),
        expectedEpoch: epoch,
        check: () => check(g, epoch),
      );
  }

  Future<void> ownershipCommand(
    String league,
    String season,
    List<String> tail,
    Map<String, Object?> fields,
  ) => _command(
    m: municipality(),
    s: season,
    league: league,
    kind: 'ownership',
    tail: ['leagues', league, 'ownership', ...tail],
    fields: fields,
  );
  Future<void> retryOwnership(String league, String season) async {
    final g = generation, epoch = data.epoch, m = municipality();
    final pending = await pendingOwnership(league, season);
    check(g, epoch);
    if (pending == null) return;
    await _command(
      m: m,
      s: season,
      league: league,
      kind: 'ownership',
      tail: (pending['tail'] as List).cast<String>(),
      fields: object(pending['body']).cast<String, Object?>(),
    );
  }

  Future<void> _command({
    required String m,
    required String s,
    required String league,
    required String kind,
    required List<String> tail,
    required Map<String, Object?> fields,
    bool idempotent = true,
  }) async {
    final g = generation, epoch = data.epoch, lease = await sessions.active();
    check(g, epoch, lease);
    final principal = _principal(lease),
        key = _key(_principal(lease), m, s, league, kind);
    void guard() {
      check(g, epoch, lease);
      if (_principal(lease) != principal) throw const LocalDataResetException();
    }

    final doc = await data.mutate<Map<String, dynamic>>(
      key,
      (prior) {
        guard();
        if (prior != null) return LocalDataMutation(prior, object(prior));
        final value = <String, dynamic>{
          'tail': tail,
          'body': {...fields, if (idempotent) 'idempotencyKey': newLocalId()},
        };
        return LocalDataMutation(value, value);
      },
      expectedEpoch: epoch,
      check: guard,
    );
    Future<void> clear() => data.mutate<void>(
      key,
      (_) => const LocalDataMutation(null, null),
      expectedEpoch: epoch,
      check: guard,
    );
    try {
      final raw = object(
        await client.postJson(
          _path(m, (doc['tail'] as List).cast<String>()),
          body: object(doc['body']).cast<String, Object?>(),
          headers: lease.headers,
          queryParameters: _query(s),
        ),
      );
      guard();
      if (raw['seasonId'] != s)
        throw const FormatException('Ricevuta di un’altra stagione.');
      if (kind == 'join') {
        final metadata = object(raw['league']);
        if (metadata['id'] != league ||
            metadata['seasonId'] != s ||
            !['competitor', 'spectator'].contains(metadata['role'])) {
          throw const FormatException('Ricevuta adesione non valida.');
        }
      }
      if (kind == 'ownership') {
        if (raw['leagueId'] != league)
          throw const FormatException('Ricevuta di un’altra lega.');
        revision(raw);
        OwnershipOffer.fromJson(raw['offer']);
      }
      await clear();
    } on ApiException catch (e) {
      guard();
      if (e.kind == ApiExceptionKind.response &&
          [400, 403, 404, 409, 422].contains(e.statusCode))
        await clear();
      rethrow;
    }
  }
}
