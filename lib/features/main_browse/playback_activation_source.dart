/// Cap 28.4 / ADR-058: explicit become-current activation source.
///
/// [PlaybackCoordinator] reads **only** this marked source (plus lifecycle /
/// cover gates) to decide seek0 / force wantsPlay. Never infer Settings
/// resume from display-generation deltas.
enum PlaybackActivationSource {
  /// True swipe / first become-current / other trusted navigation.
  navigation,

  /// Browse←Settings resume latch (keep playhead + pause intent; Live static).
  settingsResume,
}
