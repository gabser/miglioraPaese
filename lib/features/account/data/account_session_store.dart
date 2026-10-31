import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/network/session_lease_source.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/features/account/domain/account_models.dart';

/// Account credentials never replace the guest scope used by proposal receipts.
class AccountSessionStore extends ChangeNotifier {
  AccountSessionStore({
    required this.client,
    required this.data,
    required String environment,
  }) : key = 'account-session:$environment';
  final ApiClient client;
  final LocalDataStore data;
  final String key;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  int _generation = 0;
  int get generation => _generation;
  bool _authenticating = false;
  bool get authenticating => _authenticating;
  bool _signingOut = false;
  bool get signingOut => _signingOut;
  AccountProfile? current;
  String? currentSessionId;
  bool get hasCredentials => data.read(key) != null;
  static final tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static final uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  Map<String, dynamic> _stored() {
    final value = data.read(key);
    if (value is! Map<String, dynamic> ||
        value['token'] is! String ||
        !tokenPattern.hasMatch(value['token'] as String) ||
        value['submissionScope'] is! String ||
        !uuidPattern.hasMatch(value['submissionScope'] as String)) {
      throw const LocalDataCorruptException();
    }
    return value;
  }

  void check(int generation, int epoch) {
    if (_disposed ||
        _generation != generation ||
        data.epoch != epoch ||
        data.resetting)
      throw const LocalDataResetException();
  }

  void checkLease(ProposalSessionLease lease) {
    check(lease.generation, lease.epoch);
    if (_signingOut || !hasCredentials || _stored()['token'] != lease.token)
      throw const LocalDataResetException();
  }

  void invalidateIdentity() {
    _generation++;
    _notify();
  }

  Map<String, dynamic> _validate(Object? value, {required String token}) {
    if (value is! Map<String, dynamic> ||
        value['submissionScope'] is! String ||
        !uuidPattern.hasMatch(value['submissionScope'] as String) ||
        value['sessionId'] is! String ||
        !uuidPattern.hasMatch(value['sessionId'] as String) ||
        value['expiresAt'] is! String ||
        !RegExp(
          r'(Z|[+-]\d{2}:\d{2})$',
        ).hasMatch(value['expiresAt'] as String) ||
        !tokenPattern.hasMatch(token)) {
      throw ApiException.invalidPayload('Sessione account non valida.');
    }
    DateTime.parse(value['expiresAt'] as String);
    final account = AccountProfile.fromJson(value['account']);
    return {
      'token': token,
      'submissionScope': value['submissionScope'],
      'sessionId': value['sessionId'],
      'expiresAt': value['expiresAt'],
      'account': account.toJson(),
    };
  }

  Future<ProposalSessionLease> active() async {
    if (_authenticating) throw const LocalDataResetException();
    if (_signingOut)
      throw ApiException.configuration(
        code: 'account_logout_pending',
        message: 'Completa la disconnessione prima di continuare.',
      );
    final stored = _stored(), generation = _generation, epoch = data.epoch;
    Object? payload;
    try {
      payload = await client.getJson(
        ['v1', 'auth', 'me'],
        headers: {'Authorization': 'Bearer ${stored['token']}'},
      );
    } on ApiException catch (failure) {
      if (failure.statusCode == 401) {
        check(generation, epoch);
        current = null;
        currentSessionId = null;
        _signingOut = true;
        invalidateIdentity();
        final rejectedGeneration = _generation;
        await data.mutate<void>(key, (_) {
          check(rejectedGeneration, epoch);
          return const LocalDataMutation(null, null);
        }, expectedEpoch: epoch);
        check(rejectedGeneration, epoch);
        _signingOut = false;
        _notify();
      }
      rethrow;
    }
    check(generation, epoch);
    final parsed = _validate(payload, token: stored['token'] as String);
    if (parsed['submissionScope'] != stored['submissionScope'])
      throw ApiException.invalidPayload('Lo scope del dispositivo è cambiato.');
    current = AccountProfile.fromJson(parsed['account']);
    currentSessionId = parsed['sessionId'] as String;
    return ProposalSessionLease(
      token: parsed['token'] as String,
      submissionScope: parsed['submissionScope'] as String,
      epoch: epoch,
      generation: generation,
    );
  }

  Future<AccountProfile> verify({
    required String challengeId,
    required String code,
    String deviceName = 'Browser locale',
  }) async {
    if (_signingOut)
      throw ApiException.configuration(
        code: 'account_logout_pending',
        message: 'Completa la disconnessione.',
      );
    _authenticating = true;
    invalidateIdentity();
    final generation = _generation, epoch = data.epoch;
    Object? payload;
    try {
      payload = await client.postJson(
        ['v1', 'auth', 'verify'],
        body: {
          'challengeId': challengeId,
          'code': code,
          'deviceName': deviceName,
        },
      );
    } catch (_) {
      if (_generation == generation) {
        _authenticating = false;
        _notify();
      }
      rethrow;
    }
    final rawToken = payload is Map ? payload['token'] : null;
    if (rawToken is! String) {
      if (_generation == generation) {
        _authenticating = false;
        _notify();
      }
      throw ApiException.invalidPayload('Credenziale account mancante.');
    }
    try {
      final parsed = _validate(payload, token: rawToken);
      check(generation, epoch);
      await data.mutate<void>(key, (_) {
        check(generation, epoch);
        return LocalDataMutation(parsed, null);
      }, expectedEpoch: epoch);
      check(generation, epoch);
      _authenticating = false;
      _signingOut = false;
      current = AccountProfile.fromJson(parsed['account']);
      currentSessionId = parsed['sessionId'] as String;
      _notify();
      return current!;
    } catch (_) {
      if (_generation == generation) {
        _authenticating = false;
        _notify();
      }
      // A reply received after logout/reset must not become a new credential.
      try {
        await client.postJson(
          ['v1', 'auth', 'logout'],
          body: {},
          headers: {'Authorization': 'Bearer $rawToken'},
        );
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> logout() async {
    _authenticating = false;
    _signingOut = true;
    current = null;
    currentSessionId = null;
    invalidateIdentity();
    final epoch = data.epoch, generation = _generation;
    if (hasCredentials) {
      final stored = _stored();
      final response = await client.postJson(
        ['v1', 'auth', 'logout'],
        body: {},
        headers: {'Authorization': 'Bearer ${stored['token']}'},
      );
      check(generation, epoch);
      if (response is! Map || response['revoked'] != true)
        throw ApiException.invalidPayload('Disconnessione non confermata.');
      await data.mutate<void>(key, (_) {
        check(generation, epoch);
        return const LocalDataMutation(null, null);
      }, expectedEpoch: epoch);
    }
    check(generation, epoch);
    current = null;
    currentSessionId = null;
    _signingOut = false;
    _notify();
  }
}
