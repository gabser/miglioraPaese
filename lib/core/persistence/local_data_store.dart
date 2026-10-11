import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class LocalDataBackend {
  String? readString(String key);
  Future<bool> writeString(String key, String value);
  Future<bool> clear();
}

class SharedPreferencesLocalBackend implements LocalDataBackend {
  SharedPreferencesLocalBackend(
    this.prefs, {
    this.resetKeys,
    this.resetKeyPrefixes = const {},
  });
  final SharedPreferences prefs;
  final Set<String>? resetKeys;
  final Set<String> resetKeyPrefixes;
  @override
  String? readString(String key) => prefs.getString(key);
  @override
  Future<bool> writeString(String key, String value) async {
    try {
      final result = await prefs.setString(key, value);
      // SharedPreferences updates its cache before the platform confirms a write.
      if (!result) await prefs.reload();
      return result;
    } catch (_) {
      await prefs.reload();
      rethrow;
    }
  }

  @override
  Future<bool> clear() async {
    var result = true;
    if (resetKeys == null) {
      result = await prefs.clear();
    } else {
      for (final key in {
        ...resetKeys!,
        ...prefs.getKeys().where((key) => resetKeyPrefixes.any(key.startsWith)),
      }) {
        if (prefs.containsKey(key) && !await prefs.remove(key)) result = false;
      }
    }
    if (!result) await prefs.reload();
    return result;
  }
}

class LocalDataWriteException implements Exception {
  const LocalDataWriteException();
}

class LocalDataCorruptException implements Exception {
  const LocalDataCorruptException();
}

class LocalDataResetException implements Exception {
  const LocalDataResetException();
}

final _localRandom = Random.secure();
String newLocalId() => base64Url
    .encode(List<int>.generate(24, (_) => _localRandom.nextInt(256)))
    .replaceAll('=', '');

class LocalDataMutation<T> {
  const LocalDataMutation(this.value, this.result);
  final Object? value;
  final T result;
}

/// One atomic feature document and one queue shared with preference writes.
/// All mutations are committed before being published to consumers.
class LocalDataStore extends ChangeNotifier {
  LocalDataStore({required this.backend, this.key = 'proposal_local_data_v1'}) {
    try {
      final raw = backend.readString(key);
      if (raw != null) {
        final root = jsonDecode(raw);
        if (root is! Map<String, dynamic> ||
            root['version'] != 1 ||
            root['epoch'] is! int ||
            (root['epoch'] as int) < 0 ||
            root['namespace'] is! String ||
            (root['namespace'] as String).isEmpty ||
            root['entries'] is! Map<String, dynamic> ||
            root.length != 4) {
          throw const LocalDataCorruptException();
        }
        _epoch = root['epoch'] as int;
        _namespace = root['namespace'] as String;
        _entries = Map<String, Object?>.from(root['entries'] as Map);
      }
    } catch (_) {
      _corrupt = true;
    }
  }

  final LocalDataBackend backend;
  final String key;
  Map<String, Object?> _entries = {};
  String _namespace = newLocalId();
  int _epoch = 0;
  int _revision = 0;
  bool _corrupt = false;
  bool _resetting = false;
  bool _resetFailed = false;
  bool _disposed = false;
  Future<void> _tail = Future.value();
  Future<void>? _resetFuture;
  final Map<String, int> _reservedRevisions = {};

  int get epoch => _epoch;
  int get revision => _revision;
  String get namespace => _namespace;
  bool get resetting => _resetting;

  int reserveRevision(String entryKey, int minimum) {
    _checkReadable();
    final prior = _reservedRevisions[entryKey] ?? 0;
    final stored = _entries[entryKey];
    final persisted = stored is Map && stored['revision'] is int
        ? stored['revision'] as int
        : 0;
    return _reservedRevisions[entryKey] =
        max(max(prior, persisted), minimum) + 1;
  }

  void _checkReadable() {
    if (_resetting || _resetFailed) throw const LocalDataResetException();
    if (_corrupt) throw const LocalDataCorruptException();
  }

  Object? read(String entryKey) {
    _checkReadable();
    return _clone(_entries[entryKey]);
  }

  /// Captures the epoch when called, rather than when the queued task starts.
  Future<T> run<T>(FutureOr<T> Function() action, {int? expectedEpoch}) {
    final capturedEpoch = expectedEpoch ?? _epoch;
    if (_resetting || _resetFailed || capturedEpoch != _epoch) {
      return Future.error(const LocalDataResetException());
    }
    final result = _tail.then((_) async {
      if (capturedEpoch != _epoch) throw const LocalDataResetException();
      final value = await action();
      if (capturedEpoch != _epoch) throw const LocalDataResetException();
      return value;
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<T> mutate<T>(
    String entryKey,
    LocalDataMutation<T> Function(Object?) update, {
    int? expectedEpoch,
  }) {
    final capturedEpoch = expectedEpoch ?? _epoch;
    return run(() async {
      _checkReadable();
      final mutation = update(_clone(_entries[entryKey]));
      final next = Map<String, Object?>.from(_entries);
      if (mutation.value == null) {
        next.remove(entryKey);
      } else {
        next[entryKey] = _clone(mutation.value);
      }
      final encoded = jsonEncode({
        'version': 1,
        'epoch': _epoch,
        'namespace': _namespace,
        'entries': next,
      });
      if (!await backend.writeString(key, encoded))
        throw const LocalDataWriteException();
      if (capturedEpoch != _epoch) throw const LocalDataResetException();
      _entries = next;
      _revision++;
      _notify();
      return mutation.result;
    }, expectedEpoch: capturedEpoch);
  }

  Future<void> flush() => _tail;

  void invalidateForReset() {
    _epoch++;
    _resetFailed = true;
    _notify();
  }

  /// Immediately invalidates old work, then clears after any in-flight write.
  /// A failed reset blocks new writes until reset is retried successfully.
  Future<void> reset() {
    if (_resetting) return _resetFuture!;
    _epoch++;
    _resetting = true;
    _resetFailed = false;
    final result = _tail.then((_) async {
      try {
        if (!await backend.clear()) throw const LocalDataWriteException();
        _entries = {};
        _reservedRevisions.clear();
        _namespace = newLocalId();
        _corrupt = false;
        _revision++;
      } catch (_) {
        _resetFailed = true;
        rethrow;
      } finally {
        _resetting = false;
        _notify();
      }
    });
    _resetFuture = result;
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _notify();
    return result;
  }

  static Object? _clone(Object? value) =>
      value == null ? null : jsonDecode(jsonEncode(value));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
