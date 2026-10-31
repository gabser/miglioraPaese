import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:fanta_comune/core/persistence/local_data_store.dart';
import 'package:fanta_comune/core/persistence/browser_namespace.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fanta_comune/features/profile/domain/perspective_role.dart';

/// Wrapper semplice attorno a [SharedPreferences] per le preferenze locali,
/// utilizzato anche per notificare i listener quando cambiano i dati.
class AppPrefs extends ChangeNotifier {
  /// Crea un'istanza usando le [SharedPreferences] già disponibili.
  AppPrefs(this._prefs, {LocalDataStore? dataStore}) {
    final key =
        'proposal_local_data_v1:${base64Url.encode(utf8.encode(browserNamespace()))}';
    localData =
        dataStore ??
        LocalDataStore(
          backend: SharedPreferencesLocalBackend(
            _prefs,
            resetKeys: {
              key,
              _motionDemoKey,
              _municipalityKey,
              _cynicOnboardingKey,
              _warmWelcomeKey,
              _lastSuggestedAtKey,
              _userIdKey,
              _activePerspectiveKey,
              _perspectiveChangesKey,
              _lastSeenTurnIdKey,
              _insightSignaturesKey,
            },
          ),
          key: key,
        );
  }

  /// Explicit runtime profile pin, independent of user preferences and resets.
  String? configuredMunicipalityId;
  final SharedPreferences _prefs;
  late final LocalDataStore localData;

  /// API composition installs revocation before the local reset barrier.
  Future<void> Function()? beforeClearAll;
  bool _sessionUnrecoverable = false;
  bool get sessionUnrecoverable => _sessionUnrecoverable;

  static const _motionDemoKey = 'motion_demo_enabled';
  static const _municipalityKey = 'municipality_id';
  static const _cynicOnboardingKey = 'has_seen_cynic_onboarding';
  static const _warmWelcomeKey = 'has_seen_warm_welcome';
  static const _lastSuggestedAtKey = 'last_suggested_at_millis';
  static const _userIdKey = 'user_id';
  static const _activePerspectiveKey = 'active_perspective';
  static const _perspectiveChangesKey = 'perspective_changes_count';
  static const _lastSeenTurnIdKey = 'last_seen_turn_id';
  static const _insightSignaturesKey = 'insight_signatures';

  /// Inizializza le preferenze condivise e restituisce il wrapper.
  static Future<AppPrefs> init() async {
    final prefs = await SharedPreferences.getInstance();
    final existingUserId = prefs.getString(_userIdKey);
    if (existingUserId == null || existingUserId.isEmpty) {
      if (!await prefs.setString(_userIdKey, 'user_${newLocalId()}'))
        throw const LocalDataWriteException();
    }
    return AppPrefs(prefs);
  }

  /// Indica se l'utente ha attivato la demo di motion.
  bool get motionDemoEnabled => _prefs.getBool(_motionDemoKey) ?? false;

  /// Aggiorna la preferenza della demo di motion.
  Future<void> setMotionDemoEnabled(bool value) async {
    await _checkedWrite(() => _prefs.setBool(_motionDemoKey, value));
    notifyListeners();
  }

  /// Restituisce l'identificativo del Comune selezionato, se presente.
  String? get municipalityId =>
      configuredMunicipalityId ?? _prefs.getString(_municipalityKey);

  /// Imposta l'identificativo del Comune selezionato e notifica i listener.
  Future<void> setMunicipalityId(String municipalityId) async {
    await _checkedWrite(
      () => _prefs.setString(_municipalityKey, municipalityId),
    );
    notifyListeners();
  }

  /// Indica se l'utente ha completato l'onboarding "cinico".
  bool get hasSeenCynicOnboarding =>
      _prefs.getBool(_cynicOnboardingKey) ?? false;

  /// Aggiorna il flag di completamento dell'onboarding "cinico".
  Future<void> setHasSeenCynicOnboarding(bool value) async {
    await _checkedWrite(() => _prefs.setBool(_cynicOnboardingKey, value));
    notifyListeners();
  }

  /// Indica se l'utente ha completato il benvenuto "umano".
  bool get hasSeenWarmWelcome =>
      _prefs.getBool(_warmWelcomeKey) ?? hasSeenCynicOnboarding;

  /// Aggiorna il flag di completamento del benvenuto "umano".
  Future<void> setHasSeenWarmWelcome(bool value) async {
    await _checkedWrite(() => _prefs.setBool(_warmWelcomeKey, value));
    notifyListeners();
  }

  /// Identificativo stabile dell'utente locale.
  String get userId => _prefs.getString(_userIdKey) ?? 'user_local';

  /// Restituisce la lente attiva, se impostata.
  PerspectiveRole? getActivePerspective() {
    final raw = _prefs.getString(_activePerspectiveKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return PerspectiveRole.values.byName(raw);
    } catch (_) {
      return null;
    }
  }

  /// Aggiorna la lente attiva.
  Future<void> setActivePerspective(PerspectiveRole role) async {
    await _checkedWrite(
      () => _prefs.setString(_activePerspectiveKey, role.name),
    );
    notifyListeners();
  }

  /// Conta quante volte e' stata cambiata la lente.
  int get perspectiveChangesCount => _prefs.getInt(_perspectiveChangesKey) ?? 0;

  /// Incrementa il conteggio dei cambi di lente.
  Future<void> incrementPerspectiveChangesCount() async {
    final current = perspectiveChangesCount;
    await _checkedWrite(
      () => _prefs.setInt(_perspectiveChangesKey, current + 1),
    );
    notifyListeners();
  }

  /// Restituisce l'ultimo turno risolto che l'utente ha rivisitato.
  String? getLastSeenTurnId() => _prefs.getString(_lastSeenTurnIdKey);

  /// Salva l'ultimo turno risolto che l'utente ha rivisitato.
  Future<void> setLastSeenTurnId(String? value) async {
    if (value == null || value.isEmpty) {
      await _checkedWrite(() => _prefs.remove(_lastSeenTurnIdKey));
      notifyListeners();
      return;
    }
    await _checkedWrite(() => _prefs.setString(_lastSeenTurnIdKey, value));
    notifyListeners();
  }

  /// Recupera le firme degli insight viste dall'utente.
  Map<String, String> getInsightSignatures() {
    final raw = _prefs.getString(_insightSignaturesKey);
    if (raw == null || raw.isEmpty) return {};
    final entries = raw.split(';');
    final parsed = <String, String>{};
    for (final entry in entries) {
      final parts = entry.split('|');
      if (parts.length != 2) continue;
      parsed[parts[0]] = parts[1];
    }
    return parsed;
  }

  /// Salva le firme degli insight viste dall'utente.
  Future<void> setInsightSignatures(Map<String, String> signatures) async {
    if (signatures.isEmpty) {
      await _checkedWrite(() => _prefs.remove(_insightSignaturesKey));
      notifyListeners();
      return;
    }
    final encoded = signatures.entries
        .map((e) => '${e.key}|${e.value}')
        .join(';');
    await _checkedWrite(() => _prefs.setString(_insightSignaturesKey, encoded));
    notifyListeners();
  }

  /// Data dell'ultima proposta inviata, se presente.
  DateTime? get lastSuggestedAt {
    final millis = _prefs.getInt(_lastSuggestedAtKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// Aggiorna la data dell'ultima proposta inviata.
  Future<void> setLastSuggestedAt(DateTime value) async {
    await _checkedWrite(
      () => _prefs.setInt(_lastSuggestedAtKey, value.millisecondsSinceEpoch),
    );
    notifyListeners();
  }

  /// Verifica se e' possibile proporre un nuovo problema ora.
  bool canSuggestNow({Duration cooldown = const Duration(minutes: 5)}) {
    final last = lastSuggestedAt;
    if (last == null) return true;
    return DateTime.now().difference(last) > cooldown;
  }

  /// Fantasy documents share the reset barrier and atomic storage with proposals.
  String? get fantasyStateJson => localData.read('fantasy-state-v1') as String?;

  Future<void> setFantasyStateJson(String value) => localData.mutate<void>(
    'fantasy-state-v1',
    (_) => LocalDataMutation(value, null),
  );

  String? fantasyReceipt(String scope) =>
      localData.read('fantasy-receipt:$scope') as String?;

  Future<void> setFantasyReceipt(
    String scope,
    String? value, {
    int? expectedEpoch,
  }) => localData.mutate<void>(
    'fantasy-receipt:$scope',
    (_) => LocalDataMutation(value, null),
    expectedEpoch: expectedEpoch,
  );

  /// Cancella tutte le preferenze locali.
  Future<void> clearAll() async {
    _sessionUnrecoverable = false;
    try {
      await beforeClearAll?.call();
    } on LocalDataCorruptException {
      _sessionUnrecoverable = true;
      rethrow;
    }
    await _resetLocalData();
  }

  /// UI must explain that an unreadable token cannot be remotely revoked.
  /// Ordinary connectivity/revocation errors never enable this recovery path.
  Future<void> clearUnrecoverableLocalData() async {
    if (!_sessionUnrecoverable)
      throw StateError('Sessione non dimostrata come illeggibile.');
    await _resetLocalData();
  }

  Future<void> _resetLocalData() async {
    await localData.reset();
    await _checkedWrite(
      () => _prefs.setString(_userIdKey, 'user_${newLocalId()}'),
    );
    _sessionUnrecoverable = false;
    notifyListeners();
  }

  Future<void> _checkedWrite(Future<bool> Function() write) =>
      localData.run(() async {
        if (!await write()) {
          await _prefs.reload();
          throw const LocalDataWriteException();
        }
      });

  @override
  void dispose() {
    localData.dispose();
    super.dispose();
  }
}
