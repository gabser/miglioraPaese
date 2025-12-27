import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper semplice attorno a [SharedPreferences] per le preferenze locali,
/// utilizzato anche per notificare i listener quando cambiano i dati.
class AppPrefs extends ChangeNotifier {
  /// Crea un'istanza usando le [SharedPreferences] già disponibili.
  AppPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const _motionDemoKey = 'motion_demo_enabled';
  static const _municipalityKey = 'municipality_id';

  /// Inizializza le preferenze condivise e restituisce il wrapper.
  static Future<AppPrefs> init() async {
    final prefs = await SharedPreferences.getInstance();
    return AppPrefs(prefs);
  }

  /// Indica se l'utente ha attivato la demo di motion.
  bool get motionDemoEnabled => _prefs.getBool(_motionDemoKey) ?? false;

  /// Aggiorna la preferenza della demo di motion.
  Future<void> setMotionDemoEnabled(bool value) async {
    await _prefs.setBool(_motionDemoKey, value);
    notifyListeners();
  }

  /// Restituisce l'identificativo del Comune selezionato, se presente.
  String? get municipalityId => _prefs.getString(_municipalityKey);

  /// Imposta l'identificativo del Comune selezionato e notifica i listener.
  Future<void> setMunicipalityId(String municipalityId) async {
    await _prefs.setString(_municipalityKey, municipalityId);
    notifyListeners();
  }

  /// Cancella tutte le preferenze locali.
  Future<void> clearAll() async {
    await _prefs.clear();
    notifyListeners();
  }
}
