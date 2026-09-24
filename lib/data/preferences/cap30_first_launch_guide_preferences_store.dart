import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_preferences.dart';

/// SharedPreferences store for Cap 30 first-launch guide step (ADR-060 D5).
class Cap30FirstLaunchGuidePreferencesStore
    implements Cap30FirstLaunchGuidePreferences {
  Cap30FirstLaunchGuidePreferencesStore({SharedPreferences? preferences})
      : _preferences = preferences;

  static const stepKey = 'waketok.cap30.firstLaunchGuideStep';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<int> getStep() async {
    final prefs = await _prefs();
    final raw = prefs.getInt(stepKey);
    if (raw == null) {
      return 0;
    }
    return clampCap30GuideStep(raw);
  }

  @override
  Future<void> setStep(int step) async {
    final prefs = await _prefs();
    await prefs.setInt(stepKey, clampCap30GuideStep(step));
  }
}
