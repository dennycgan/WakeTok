/// Cap 19.6 — left-swipe append + guide preference store (ADR-040 Decision 18).
abstract class Cap19LeftSwipePreferences {
  Future<bool> isLeftSwipeAddEnabled();

  Future<bool> isLeftSwipeGuideEnabled();

  Future<void> setLeftSwipeAddEnabled(bool value);

  Future<void> setLeftSwipeGuideEnabled(bool value);
}
