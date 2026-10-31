import 'package:fanta_comune/core/network/session_lease_source.dart';
export 'package:fanta_comune/core/network/session_lease_source.dart';
import 'dart:async';
import 'dart:convert';
import 'package:fanta_comune/core/network/api_client.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import 'package:fanta_comune/core/persistence/local_data_store.dart';

/// New submissions may explicitly bootstrap. Recovery must prove the old scope.
/// Revocation blocks new leases until local reset successfully changes namespace.
class ProposalSessionStore implements SessionLeaseSource {
  @override
  bool get preservesCompetitiveDataOnReset => false;
  ProposalSessionStore({
    required ApiClient client,
    required LocalDataStore data,
    required String environment,
  }) : _client = client,
       _data = data,
       _key = 'api-session:$environment',
       _namespace = data.namespace;
  final ApiClient _client;
  final LocalDataStore _data;
  final String _key;
  String _namespace;
  int _generation = 0;
  bool _blocked = false;
  Future<ProposalSessionLease>? _pending;

  static final _token = RegExp(r'^[A-Za-z0-9_-]{43}$');
  static final _scope = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static const _capabilities = [
    'proposalLocation',
    'publicDetail',
    'privateSubmissionLookup',
    'scopedIdempotency',
    'revocation',
    'sessionRequiredForRecovery',
  ];

  void _checkNamespace() {
    if (_namespace != _data.namespace) {
      _namespace = _data.namespace;
      _generation++;
      _blocked = false;
      _pending = null;
    }
    if (_blocked || _data.resetting) throw const LocalDataResetException();
  }

  void checkLease(ProposalSessionLease lease) {
    _checkNamespace();
    if (lease.epoch != _data.epoch || lease.generation != _generation) {
      throw const LocalDataResetException();
    }
  }

  Future<ProposalSessionLease?> existing() async {
    _checkNamespace();
    if (_data.read(_key) == null) return null;
    return active();
  }

  Future<ProposalSessionLease> active({
    bool allowCreate = false,
    String? expectedScope,
  }) async {
    _checkNamespace();
    // Reading first also rejects a failed reset or corrupted storage.
    final stored = _data.read(_key);
    if (stored == null && (!allowCreate || expectedScope != null)) {
      throw ApiException.configuration(
        code: 'proposal_scope_missing',
        message: 'La sessione dell’invio non è più disponibile.',
      );
    }
    final pending = _pending;
    if (pending != null) {
      final lease = await pending;
      checkLease(lease);
      _checkExpected(lease.submissionScope, expectedScope);
      return lease;
    }
    final future = _load(stored, expectedScope);
    _pending = future;
    try {
      return await future;
    } finally {
      if (identical(_pending, future)) _pending = null;
    }
  }

  void _checkExpected(String actual, String? expected) {
    if (expected != null && actual != expected) {
      throw ApiException.configuration(
        code: 'proposal_scope_changed',
        message: 'La sessione attuale non appartiene a questo invio.',
      );
    }
  }

  Future<ProposalSessionLease> _load(
    Object? stored,
    String? expectedScope,
  ) async {
    final epoch = _data.epoch;
    final generation = _generation;
    late String token, scope;
    if (stored == null) {
      final payload = await _client.postJson([
        'v1',
        'proposal-session',
      ], body: {});
      if (payload is! Map<String, dynamic> ||
          payload['token'] is! String ||
          !_token.hasMatch(payload['token'] as String)) {
        throw ApiException.invalidPayload('Sessione server non valida.');
      }
      token = payload['token'] as String;
      try {
        scope = _validate(payload);
        final lease = ProposalSessionLease(
          token: token,
          submissionScope: scope,
          epoch: epoch,
          generation: generation,
        );
        checkLease(lease);
        _checkExpected(scope, expectedScope);
        await _data.mutate<void>(
          _key,
          (_) => LocalDataMutation({
            'token': token,
            'submissionScope': scope,
          }, null),
          expectedEpoch: epoch,
        );
        checkLease(lease);
        return lease;
      } catch (_) {
        // A token received after reset must never become the new local session.
        // Best effort revocation; no proposal can have been sent through this lease.
        try {
          await _client.postJson(
            ['v1', 'proposal-session', 'revoke'],
            body: {},
            headers: {'Authorization': 'Bearer $token'},
          );
        } catch (_) {}
        rethrow;
      }
    }
    if (stored is! Map<String, dynamic> ||
        stored.length != 2 ||
        stored['token'] is! String ||
        !_token.hasMatch(stored['token'] as String) ||
        stored['submissionScope'] is! String ||
        !_scope.hasMatch(stored['submissionScope'] as String)) {
      throw const LocalDataCorruptException();
    }
    token = stored['token'] as String;
    scope = stored['submissionScope'] as String;
    _checkExpected(scope, expectedScope);
    final payload = await _client.getJson(
      ['v1', 'proposal-session'],
      headers: {'Authorization': 'Bearer $token'},
    );
    final actualScope = _validate(payload);
    _checkExpected(actualScope, scope);
    final lease = ProposalSessionLease(
      token: token,
      submissionScope: scope,
      epoch: epoch,
      generation: generation,
    );
    checkLease(lease);
    return lease;
  }

  String _validate(Object? payload) {
    if (payload is! Map<String, dynamic> ||
        payload['submissionScope'] is! String ||
        !_scope.hasMatch(payload['submissionScope'] as String)) {
      throw ApiException.invalidPayload('Scope server non valido.');
    }
    final capabilities = payload['capabilities'];
    if (capabilities is! Map<String, dynamic> ||
        _capabilities.any((name) => capabilities[name] != true)) {
      throw ApiException.configuration(
        code: 'proposal_capabilities_missing',
        message: 'Questo server non supporta ancora l’invio recuperabile.',
      );
    }
    return payload['submissionScope'] as String;
  }

  /// Only called after informed abandonment of an intent whose scope is lost.
  /// It does not revoke a valid session or claim deletion of remote proposals.
  Future<void> abandonLostScope(String expectedScope) async {
    _checkNamespace();
    final pending = _pending;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    _checkNamespace();
    final epoch = _data.epoch;
    final stored = _data.read(_key);
    if (stored == null) return;
    if (stored is Map<String, dynamic> &&
        stored['submissionScope'] is String &&
        stored['submissionScope'] != expectedScope &&
        _scope.hasMatch(stored['submissionScope'] as String)) {
      return; // A different, already persisted session must be preserved.
    }
    if (stored is Map<String, dynamic> &&
        stored['token'] is String &&
        _token.hasMatch(stored['token'] as String)) {
      try {
        final response = await _client.getJson(
          ['v1', 'proposal-session'],
          headers: {'Authorization': 'Bearer ${stored['token']}'},
        );
        final actual = _validate(response);
        _checkExpected(actual, expectedScope);
        // A readable token proves the old session: repair its local shape instead.
        await _data.mutate<void>(_key, (value) {
          if (jsonEncode(value) != jsonEncode(stored))
            throw const LocalDataResetException();
          return LocalDataMutation({
            'token': stored['token'],
            'submissionScope': actual,
          }, null);
        }, expectedEpoch: epoch);
        return;
      } on ApiException catch (error) {
        if (error.statusCode != 401) rethrow;
      }
    }
    // Missing/invalid token or authoritative401: explicit consent permits only
    // forgetting this reference. Other saved intents still require their old scope.
    _generation++;
    await _data.mutate<void>(_key, (value) {
      if (jsonEncode(value) != jsonEncode(stored))
        throw const LocalDataResetException();
      return const LocalDataMutation(null, null);
    }, expectedEpoch: epoch);
  }

  /// Call before clearing local data. Keep the token on failure so reset can retry.
  Future<void> revokeBeforeReset() async {
    _blocked = true;
    _generation++;
    final pending = _pending;
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
    final stored = _data.read(_key);
    if (stored == null) return;
    if (stored is! Map<String, dynamic> ||
        stored['token'] is! String ||
        !_token.hasMatch(stored['token'] as String)) {
      throw const LocalDataCorruptException();
    }
    try {
      final payload = await _client.postJson(
        ['v1', 'proposal-session', 'revoke'],
        body: {},
        headers: {'Authorization': 'Bearer ${stored['token']}'},
      );
      if (payload is! Map<String, dynamic> || payload['revoked'] != true) {
        throw ApiException.invalidPayload(
          'Revoca della sessione non confermata.',
        );
      }
    } on ApiException catch (error) {
      if (error.statusCode != 401 || error.code != 'proposal_session_revoked')
        rethrow;
    }
  }
}
