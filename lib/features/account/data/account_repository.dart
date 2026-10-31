import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/next_problems/data/proposal_session_store.dart';
import '../domain/account_models.dart';
import 'account_session_store.dart';

class AccountRepository {
  AccountRepository({
    required this.client,
    required this.sessions,
    required this.guest,
    required this.environment,
    this.beforeIdentityChange,
  });
  final ApiClient client;
  final AccountSessionStore sessions;
  final ProposalSessionStore guest;
  final String environment;
  final Future<void> Function()? beforeIdentityChange;
  Future<AccountProfile> verify({
    required String challengeId,
    required String code,
  }) async {
    await beforeIdentityChange?.call();
    return sessions.verify(challengeId: challengeId, code: code);
  }

  String get _linkKey => 'account-link-intent:$environment';
  static DateTime _date(Object? raw) {
    if (raw is! String || !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw))
      throw const FormatException('Missing timezone');
    return DateTime.parse(raw).toUtc();
  }

  Future<AccountChallenge> requestCode(String email) async {
    final generation = sessions.generation, epoch = sessions.data.epoch;
    final raw = await client.postJson(
      ['v1', 'auth', 'code'],
      body: {'email': email},
    );
    sessions.check(generation, epoch);
    if (raw is! Map ||
        raw['challengeId'] is! String ||
        raw['retryAfterSeconds'] is! int ||
        raw['delivery'] != 'simulated')
      throw ApiException.invalidPayload(
        'Richiesta codice non valida per questo profilo locale.',
      );
    return AccountChallenge(
      id: raw['challengeId'] as String,
      expiresAt: _date(raw['expiresAt']),
      retryAfterSeconds: raw['retryAfterSeconds'] as int,
    );
  }

  Future<List<AccountDevice>> devices() async {
    final lease = await sessions.active();
    final raw = await client.getJson([
      'v1',
      'auth',
      'devices',
    ], headers: lease.headers);
    sessions.checkLease(lease);
    if (raw is! Map || raw['items'] is! List)
      throw ApiException.invalidPayload('Elenco dispositivi non valido.');
    return List.unmodifiable(
      (raw['items'] as List).map((v) {
        if (v is! Map ||
            v['id'] is! String ||
            v['name'] is! String ||
            v['isCurrent'] is! bool)
          throw const FormatException('Invalid device');
        return AccountDevice(
          id: v['id'] as String,
          name: v['name'] as String,
          createdAt: _date(v['createdAt']),
          isCurrent: v['isCurrent'] as bool,
          revokedAt: v['revokedAt'] == null ? null : _date(v['revokedAt']),
        );
      }),
    );
  }

  Future<void> revokeDevice(AccountDevice device) async {
    if (device.isCurrent) {
      await sessions.logout();
      return;
    }
    final lease = await sessions.active();
    final raw = await client.postJson(
      ['v1', 'auth', 'devices', device.id, 'revoke'],
      body: {},
      headers: lease.headers,
    );
    sessions.checkLease(lease);
    if (raw is! Map || raw['revoked'] != true)
      throw ApiException.invalidPayload('Revoca non confermata.');
  }

  Future<void> updatePseudonym(String pseudonym) async {
    final lease = await sessions.active();
    final raw = await client.postJson(
      ['v1', 'auth', 'profile'],
      body: {'pseudonym': pseudonym},
      headers: lease.headers,
    );
    sessions.checkLease(lease);
    if (raw is! Map) throw ApiException.invalidPayload('Profilo non valido.');
    AccountProfile.fromJson(raw['account']);
    await sessions.active();
  }

  bool get pendingLinkKeepsAccount {
    final stored = sessions.data.read(_linkKey);
    return stored is Map &&
        stored['body'] is Map &&
        (stored['body'] as Map)['conflictChoice'] == 'keepAccount';
  }

  bool get hasPendingLink => sessions.data.read(_linkKey) != null;
  Future<GuestLinkResult?> linkGuest({bool keepAccount = false}) async {
    await beforeIdentityChange?.call();
    final accountLease = await sessions.active();
    final guestLease = await guest.existing();
    if (guestLease == null) return null;
    Object? stored = sessions.data.read(_linkKey);
    if (stored == null) {
      stored = {
        'accountId': sessions.current!.id,
        'guestScope': guestLease.submissionScope,
        'body': {
          'guestToken': guestLease.token,
          'idempotencyKey': newLocalId(),
          if (keepAccount) 'conflictChoice': 'keepAccount',
        },
      };
      await sessions.data.mutate<void>(
        _linkKey,
        (_) => LocalDataMutation(stored, null),
        expectedEpoch: accountLease.epoch,
      );
    }
    if (stored is! Map ||
        stored['accountId'] != sessions.current!.id ||
        stored['guestScope'] != guestLease.submissionScope ||
        stored['body'] is! Map)
      throw const LocalDataCorruptException();
    final body = Map<String, Object?>.from(stored['body'] as Map);
    if (body['conflictChoice'] != (keepAccount ? 'keepAccount' : null))
      throw ApiException.configuration(
        code: 'account_link_pending',
        message: 'Riprova prima il collegamento precedente.',
      );
    final raw = await client.postJson(
      ['v1', 'auth', 'guest-link'],
      body: body,
      headers: accountLease.headers,
    );
    sessions.checkLease(accountLease);
    guest.checkLease(guestLease);
    if (raw is! Map ||
        !['linked', 'conflict'].contains(raw['status']) ||
        raw['conflicts'] is! List)
      throw ApiException.invalidPayload('Collegamento ospite non valido.');
    AccountProfile.fromJson(raw['account']);
    final conflicts = List<GuestLinkConflict>.unmodifiable(
      (raw['conflicts'] as List).map((v) {
        if (v is! Map ||
            v['seasonId'] is! String ||
            v['municipalityId'] is! String)
          throw const FormatException('Invalid conflict');
        return GuestLinkConflict(
          seasonId: v['seasonId'] as String,
          municipalityId: v['municipalityId'] as String,
        );
      }),
    );
    await sessions.data.mutate<void>(_linkKey, (_) {
      sessions.checkLease(accountLease);
      return const LocalDataMutation(null, null);
    }, expectedEpoch: accountLease.epoch);
    if (raw['status'] == 'linked') sessions.invalidateIdentity();
    return GuestLinkResult(
      linked: raw['status'] == 'linked',
      conflicts: conflicts,
    );
  }
}
