import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waketok/data/preferences/cap30_first_launch_guide_preferences_store.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('T-30.2-S1 default step is 0', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = Cap30FirstLaunchGuidePreferencesStore(preferences: prefs);
    expect(await store.getStep(), 0);
  });

  test('T-30.2-S2 set/get round-trips 1/2/3', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final store = Cap30FirstLaunchGuidePreferencesStore(preferences: prefs);

    await store.setStep(1);
    expect(await store.getStep(), 1);
    await store.setStep(2);
    expect(await store.getStep(), 2);
    await store.setStep(3);
    expect(await store.getStep(), 3);
  });

  test('T-30.2-S3 clamp: 99→3 and -1→0', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      Cap30FirstLaunchGuidePreferencesStore.stepKey: 99,
    });
    final prefs = await SharedPreferences.getInstance();
    final store = Cap30FirstLaunchGuidePreferencesStore(preferences: prefs);
    expect(await store.getStep(), kCap30GuideStepComplete);

    await store.setStep(-1);
    expect(await store.getStep(), 0);
    expect(
      prefs.getInt(Cap30FirstLaunchGuidePreferencesStore.stepKey),
      0,
    );
  });
}
