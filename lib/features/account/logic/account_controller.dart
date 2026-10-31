import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fanta_comune/core/network/api_exception.dart';
import '../data/account_intent_store.dart';
import '../data/account_repository.dart';
import '../domain/account_models.dart';

class AccountController extends ChangeNotifier {
  AccountController({
    required this.repository,
    required this.intents,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_disposed && challenge != null) notifyListeners();
    });
    settled = refresh();
  }
  final AccountRepository repository;
  final AccountIntentStore intents;
  final DateTime Function() _now;
  late Future<void> settled;
  Timer? _timer;
  bool _disposed = false, busy = false;
  int _operation = 0;
  String? error, lastErrorCode;
  String email = '';
  AccountChallenge? challenge;
  DateTime? _resendAt;
  List<AccountDevice> devices = const [];
  List<GuestLinkConflict> conflicts = const [];
  AccountProfile? get profile => repository.sessions.current;
  bool get logoutPending => repository.sessions.signingOut;
  bool get linkPending => repository.hasPendingLink;
  int get resendRemaining => _resendAt == null
      ? 0
      : (_resendAt!.difference(_now()).inSeconds + 1).clamp(0, 86400);
  static String messageFor(Object failure) {
    if (failure is! ApiException) return 'Operazione non completata. Riprova.';
    return switch (failure.code) {
      'code_invalid' => 'Il codice non è corretto. Controlla le sei cifre.',
      'code_expired' => 'Il codice è scaduto. Richiedine uno nuovo.',
      'code_used' => 'Questo codice è già stato usato. Richiedine uno nuovo.',
      'code_attempts_exceeded' =>
        'Troppi tentativi. Richiedi un nuovo codice quando disponibile.',
      'auth_rate_limited' => 'Troppe richieste. Attendi prima di riprovare.',
      'account_required' ||
      'proposal_session_revoked' ||
      'session_expired' => 'Questo accesso non è più valido. Accedi di nuovo.',
      'account_logout_pending' =>
        'Disconnessione non completata. Riprova prima di continuare.',
      _ =>
        failure.isRetryable
            ? 'Il servizio non è raggiungibile. I dati restano disponibili: riprova.'
            : failure.message,
    };
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_disposed || busy) return false;
    final operation = ++_operation;
    busy = true;
    error = null;
    lastErrorCode = null;
    notifyListeners();
    try {
      await action();
      return !_disposed && operation == _operation;
    } catch (failure) {
      if (!_disposed && operation == _operation) {
        error = messageFor(failure);
        lastErrorCode = failure is ApiException ? failure.code : null;
        if (failure is ApiException && failure.retryAfterSeconds != null)
          _resendAt = _now().add(Duration(seconds: failure.retryAfterSeconds!));
      }
      return false;
    } finally {
      if (!_disposed && operation == _operation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async {
    await _run(() async {
      if (!repository.sessions.hasCredentials) {
        devices = const [];
        return;
      }
      await repository.sessions.active();
      devices = await repository.devices();
    });
  }

  Future<bool> sendCode(String address) => _run(() async {
    final requested = await repository.requestCode(
      address.trim().toLowerCase(),
    );
    email = address.trim().toLowerCase();
    challenge = requested;
    _resendAt = _now().add(Duration(seconds: requested.retryAfterSeconds));
  });
  Future<bool> verify(String code) => _run(() async {
    if (challenge == null) return;
    await repository.verify(challengeId: challenge!.id, code: code);
    challenge = null;
    devices = await repository.devices();
    final link = await repository.linkGuest();
    conflicts = link?.conflicts ?? const [];
  });
  Future<bool> linkGuest({bool keepAccount = false}) => _run(() async {
    final result = await repository.linkGuest(keepAccount: keepAccount);
    conflicts = result?.conflicts ?? const [];
  });
  Future<bool> retryLink() =>
      linkGuest(keepAccount: repository.pendingLinkKeepsAccount);
  void deferLink() {
    conflicts = const [];
    error = null;
    notifyListeners();
  }

  void resetChallenge() {
    challenge = null;
    error = null;
    lastErrorCode = null;
    notifyListeners();
  }

  Future<bool> updatePseudonym(String value) => _run(() async {
    await repository.updatePseudonym(value.trim());
  });

  Future<bool> revoke(AccountDevice device) => _run(() async {
    await repository.revokeDevice(device);
    devices = repository.sessions.hasCredentials
        ? await repository.devices()
        : const [];
  });
  Future<bool> logout() => _run(() async {
    await repository.sessions.logout();
    devices = const [];
    conflicts = const [];
    challenge = null;
  });
  Future<String> resume() async => await intents.consume() ?? '/profile';
  @override
  void dispose() {
    _disposed = true;
    _operation++;
    _timer?.cancel();
    super.dispose();
  }
}
