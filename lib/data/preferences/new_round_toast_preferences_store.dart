import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/domain/browse/new_round_toast_preferences.dart';

/// Product KV for Cap 22.5 new-round Browse toast (Settings Browse section).
class NewRoundToastPreferencesStore implements NewRoundToastPreferences {
  NewRoundToastPreferencesStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const newRoundToastEnabledKey = 'waketok.cap22.newRoundToastEnabled';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<bool> isNewRoundToastEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(newRoundToastEnabledKey) ?? true;
  }

  @override
  Future<void> setNewRoundToastEnabled(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(newRoundToastEnabledKey, value);
  }
}
