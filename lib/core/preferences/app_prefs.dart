import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper semplice attorno a [SharedPreferences] per le preferenze locali.
class AppPrefs {
  /// Crea un'istanza usando le [SharedPreferences] già disponibili.
  const AppPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const _motionDemoKey = 'motion_demo_enabled';

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
  }

  /// Cancella tutte le preferenze locali.
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
