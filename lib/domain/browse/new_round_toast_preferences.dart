/// Cap 22.5 — Browse "starting over" toast preference (Settings).
abstract class NewRoundToastPreferences {
  Future<bool> isNewRoundToastEnabled();

  Future<void> setNewRoundToastEnabled(bool value);
}
