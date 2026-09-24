/// Cap 30 — durable first-launch Browse guidance step index (ADR-060 D5).
abstract class Cap30FirstLaunchGuidePreferences {
  /// Clamped step in `0..kCap30GuideStepComplete` (see logic helpers).
  Future<int> getStep();

  Future<void> setStep(int step);
}
