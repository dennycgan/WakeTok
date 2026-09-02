import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/domain/library/cap19_left_swipe_preferences.dart';

/// Product KV for Cap 19.6 left-swipe master + guide toggles (Settings UI in 19.7).
class Cap19LeftSwipePreferencesStore implements Cap19LeftSwipePreferences {
  Cap19LeftSwipePreferencesStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const leftSwipeAddEnabledKey = 'waketok.cap19.leftSwipeAddEnabled';
  static const leftSwipeGuideEnabledKey = 'waketok.cap19.leftSwipeGuideEnabled';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<bool> isLeftSwipeAddEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(leftSwipeAddEnabledKey) ?? true;
  }

  @override
  Future<bool> isLeftSwipeGuideEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(leftSwipeGuideEnabledKey) ?? true;
  }

  @override
  Future<void> setLeftSwipeAddEnabled(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(leftSwipeAddEnabledKey, value);
  }

  @override
  Future<void> setLeftSwipeGuideEnabled(bool value) async {
    final prefs = await _prefs();
    await prefs.setBool(leftSwipeGuideEnabledKey, value);
  }
}
