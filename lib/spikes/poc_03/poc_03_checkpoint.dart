/// Spike helpers for POC-03 SessionCheckpoint display / validation (3.5).
library;

/// Human-readable checkpoint line for HUD / tests.
String formatCheckpointSummary({
  required String? clipId,
  required int? positionMs,
  required bool? wasPlaying,
}) {
  if (clipId == null || clipId.isEmpty || positionMs == null) {
    return 'ckpt=none';
  }
  final playing = wasPlaying == true ? 'wasPlaying' : 'wasPaused';
  return 'ckpt=$clipId@${positionMs}ms ($playing)';
}

/// True when a cold-start Restore? offer should be shown (P5=A).
bool shouldOfferRestore({
  required bool engineConfigured,
  required String? pendingClipId,
}) {
  if (engineConfigured) return false;
  return pendingClipId != null && pendingClipId.isNotEmpty;
}
