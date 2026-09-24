import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_preferences.dart';

class FakeCap30FirstLaunchGuidePreferences
    implements Cap30FirstLaunchGuidePreferences {
  int step = 0;

  @override
  Future<int> getStep() async => clampCap30GuideStep(step);

  @override
  Future<void> setStep(int value) async {
    step = clampCap30GuideStep(value);
  }
}
