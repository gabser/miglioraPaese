import 'dart:convert';
import 'package:fanta_comune/features/fantasy/data/fantasy_league_repository.dart';
import 'dart:math';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/preferences/app_prefs.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_api_mapper.dart';
import 'package:fanta_comune/features/fantasy/data/fantasy_repository.dart';
import 'package:fanta_comune/features/fantasy/domain/fantasy_models.dart';

class ApiFantasyRepository
    implements RemoteFantasyRepository, FantasyLeagueRepository {
  ApiFantasyRepository({
    required this.client,
    required this.prefs,
    required this.environment,
    required this.municipalityId,
  });
  final ApiClient client;
  final AppPrefs prefs;
  final String environment;
  final String municipalityId;
  FantasyData? _cached;
  String? _scope;
  Map<String, dynamic>? _pending;
  bool _deleted = false;
  final Map<String, Matchday> _days = {};
  @override
  FantasyData? get cached => _cached;
  @override
  bool get hasPendingTransfer => _pending != null;
  List<String> path(List<String> tail) => [
    'v1',
    'fantasy',
    'municipalities',
    municipalityId,
    ...tail,
  ];
  Future<Map<String, dynamic>> get(List<String> tail) async =>
      FantasyApiMapper.object(await client.getJson(path(tail)));
  Future<Map<String, dynamic>> post(
    List<String> tail,
    Map<String, Object?> body,
  ) async =>
      FantasyApiMapper.object(await client.postJson(path(tail), body: body));

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      if (e.code == 'stale_revision')
        throw const FantasyFailure(
          FantasyFailureKind.staleRevision,
          'La squadra è cambiata. Stato ricaricato: ripeti la scelta.',
        );
      rethrow;
    } on FormatException catch (e) {
      throw ApiException.invalidPayload('Dati fantasy non validi.', cause: e);
    } on TypeError catch (e) {
      throw ApiException.invalidPayload(
        'Contratto fantasy non valido.',
        cause: e,
      );
    }
  }

  @override
  Future<FantasyData> load() => _guard(() async {
    _deleted = false;
    final season = await get(['season']), catalog = await get(['cards']);
    Map<String, dynamic> team;
    try {
      team = await get(['team']);
    } on ApiException catch (e) {
      if (e.statusCode != 404) rethrow;
      team = await post(['enrollment'], {});
    }
    final scope = jsonEncode([
      environment,
      municipalityId,
      team['seasonId'],
      team['sessionScope'] as String,
    ]);
    if (_scope != scope) {
      _days.clear();
      _pending = null;
    }
    _scope = scope;
    final receipt = prefs.fantasyReceipt(scope);
    if (receipt != null)
      _pending = FantasyApiMapper.object(jsonDecode(receipt));
    final ids = <String>{
      team['matchdayId'] as String,
      for (final raw in team['snapshots'] as List)
        FantasyApiMapper.object(raw)['matchdayId'] as String,
    };
    final reveals = <Map<String, dynamic>>[];
    for (final id in ids) {
      _days[id] ??= FantasyApiMapper.day(
        (await get(['matchdays', id]))['matchday'],
      );
      reveals.add(await get(['matchdays', id, 'reveal']));
    }
    final data = FantasyApiMapper.data(
      seasonResponse: season,
      catalog: catalog,
      teamResponse: team,
      days: _days,
      reveals: reveals,
    );
    _cached = data;
    return data;
  });
  @override
  Future<FantasyData> synchronize({required int expectedRevision}) => _deleted
      ? Future.error(
          const FantasyFailure(
            FantasyFailureKind.invalidCommand,
            'Dati cancellati. Avvia una nuova squadra.',
          ),
        )
      : load();

  @override
  Future<FantasyTransferQuote> quoteTransfer(
    String outgoingId,
    String incomingId,
    int revision,
  ) => _guard(() async {
    if (hasPendingTransfer)
      throw const FantasyFailure(
        FantasyFailureKind.busy,
        'Verifica il trasferimento precedente con Riprova.',
      );
    final v = FantasyApiMapper.object(
      (await post(
        ['transfers', 'quote'],
        {
          'expectedRevision': revision,
          'matchdayId': _cached!.state.matchday.id,
          'outgoingId': outgoingId,
          'incomingId': incomingId,
        },
      ))['quote'],
    );
    return FantasyTransferQuote(
      id: v['id'] as String,
      revision: v['expectedRevision'] as int,
      outgoingPrice: v['outgoingPrice'] as int,
      incomingPrice: v['incomingPrice'] as int,
      penalty: v['penalty'] as int,
      expiresAt: FantasyApiMapper.date(v['expiresAt']),
    );
  });
  @override
  Future<FantasyData> retryPendingTransfer() => _guard(() async {
    final receipt = _pending;
    if (receipt == null) return load();
    try {
      await post([
        'transfers',
        'confirmation',
      ], receipt.cast<String, Object?>());
    } on ApiException catch (e) {
      // Only a definitive rejection permits forgetting this key. A lost reply
      // must be retried verbatim, including after a browser restart or lock.
      if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500) {
        await prefs.setFantasyReceipt(_scope!, null);
        _pending = null;
      }
      rethrow;
    }
    await prefs.setFantasyReceipt(_scope!, null);
    _pending = null;
    return load();
  });
  @override
  Future<FantasyData> execute(
    FantasyCommand command, {
    required int expectedRevision,
  }) => _guard(() async {
    if (_deleted || _cached == null)
      throw const FantasyFailure(
        FantasyFailureKind.invalidCommand,
        'Carica prima la squadra.',
      );
    if (hasPendingTransfer)
      throw const FantasyFailure(
        FantasyFailureKind.busy,
        'Esito trasferimento da verificare: premi Riprova.',
      );
    final state = _cached!.state;
    final base = <String, Object?>{
      'expectedRevision': expectedRevision,
      'matchdayId': state.matchday.id,
    };
    switch (command) {
      case ConfirmFantasyLineup():
        await post(['team', 'confirmation'], base);
      case TransferFantasyCard():
        final q =
            command.quote ??
            await quoteTransfer(
              command.outgoingId,
              command.incomingId,
              expectedRevision,
            );
        if (command.expectedPenalty != null &&
            q.penalty != command.expectedPenalty)
          throw const FantasyFailure(
            FantasyFailureKind.staleRevision,
            'Penalità cambiata: richiedi un nuovo preventivo.',
          );
        final random = Random.secure();
        _pending = {
          'quoteId': q.id,
          'expectedRevision': q.revision,
          'idempotencyKey': base64UrlEncode(
            List.generate(24, (_) => random.nextInt(256)),
          ).replaceAll('=', ''),
        };
        // Persist BEFORE sending. No competitive data is accepted locally.
        await prefs.setFantasyReceipt(_scope!, jsonEncode(_pending));
        return retryPendingTransfer();
      case ReflectOnFantasyCard():
        await post(
          [
            'matchdays',
            command.outcome.matchdayId,
            'cards',
            command.outcome.cardId,
            'reflection',
          ],
          {'expectedRevision': expectedRevision, 'answer': command.answer.name},
        );
      case StartFantasyMatchday():
        throw const FantasyFailure(
          FantasyFailureKind.invalidCommand,
          'Il calendario è gestito dal server.',
        );
      default:
        final starters = [...state.starterIds],
            predictions = {...state.predictions},
            motivations = {...state.motivations};
        var captain = state.captainId;
        switch (command) {
          case SwapFantasyCards():
            final index = starters.indexOf(command.starterId);
            if (index < 0 ||
                !state.squadIds.contains(command.reserveId) ||
                starters.contains(command.reserveId))
              throw const FantasyFailure(
                FantasyFailureKind.invalidCommand,
                'Cambio non valido.',
              );
            starters[index] = command.reserveId;
            predictions.remove(command.starterId);
            motivations.remove(command.starterId);
            if (captain == command.starterId) captain = command.reserveId;
          case SetFantasyCaptain():
            captain = command.cardId;
          case SetFantasyPrediction():
            predictions[command.cardId] = command.trend;
          case SetFantasyMotivation():
            motivations[command.cardId] = command.text;
          default:
            throw const FantasyFailure(
              FantasyFailureKind.invalidCommand,
              'Comando non supportato.',
            );
        }
        await client.putJson(
          path(['team']),
          body: {
            ...base,
            'starterIds': starters,
            'captainId': captain,
            'predictions': predictions.map((k, v) => MapEntry(k, v.name)),
            'motivations': motivations,
          },
        );
    }
    return load();
  });

  String _randomKey() => base64UrlEncode(
    List.generate(24, (_) => Random.secure().nextInt(256)),
  ).replaceAll('=', '');
  @override
  Future<List<RemoteFantasyLeague>> loadLeagues() => _guard(() async {
    final listing = await get(['leagues']);
    final leagues = <RemoteFantasyLeague>[];
    for (final raw in listing['items'] as List) {
      final id = FantasyApiMapper.object(raw)['id'] as String;
      final detail = await get(['leagues', id]);
      if (detail['seasonId'] != cached?.season?.id)
        throw const FormatException('Mixed league season');
      leagues.add(RemoteFantasyLeague.fromJson(detail));
    }
    return List.unmodifiable(leagues);
  });
  @override
  Future<void> createLeague(String name) => _guard(() async {
    if (_scope == null || _deleted)
      throw const FantasyFailure(
        FantasyFailureKind.invalidCommand,
        'Carica prima la squadra.',
      );
    final scope = '${_scope!}/league-creation';
    final stored = prefs.fantasyReceipt(scope);
    final body = stored == null
        ? <String, dynamic>{'name': name, 'idempotencyKey': _randomKey()}
        : FantasyApiMapper.object(jsonDecode(stored));
    if (body['name'] != name)
      throw const FantasyFailure(
        FantasyFailureKind.busy,
        'Verifica prima la creazione della lega precedente selezionando lo stesso tipo.',
      );
    await prefs.setFantasyReceipt(scope, jsonEncode(body));
    try {
      await post(['leagues'], body.cast<String, Object?>());
    } on ApiException catch (e) {
      if (e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500)
        await prefs.setFantasyReceipt(scope, null);
      rethrow;
    }
    await prefs.setFantasyReceipt(scope, null);
  });
  @override
  Future<void> joinLeague(String token) => _guard(() async {
    await post(['leagues', 'join'], {'token': token});
  });
  @override
  Future<void> leaveLeague(String id) => _guard(() async {
    await client.deleteJson(path(['leagues', id, 'membership']));
  });
  @override
  Future<FantasyLeagueInvite> rotateInvite(String id) => _guard(() async {
    final invite = FantasyApiMapper.object(
      (await post(
        ['leagues', id, 'invites'],
        {'expiresInHours': 24},
      ))['invite'],
    );
    return FantasyLeagueInvite(
      id: invite['id'] as String,
      token: invite['token'] as String,
      expiresAt: FantasyApiMapper.date(invite['expiresAt']),
    );
  });
  @override
  Future<void> revokeInvite(String leagueId, String inviteId) => _guard(
    () async {
      await client.deleteJson(path(['leagues', leagueId, 'invites', inviteId]));
    },
  );

  @override
  Future<FantasyData?> clear() async {
    await client.deleteJson(['v1', 'session']);
    // Remote deletion must succeed before any local state is removed.
    _deleted = true;
    _cached = null;
    _pending = null;
    _scope = null;
    _days.clear();
    await prefs.clearAll();
    return null;
  }
}
