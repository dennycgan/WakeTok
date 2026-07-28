/// Spike helpers for POC-09 duration / fallback advisory (9.2 notes threshold).
library;

/// Notes acceptance: original is "obviously longer" when delta exceeds this.
const double kPoc09OriginalLongerThresholdSec = 2.0;

/// Advisory for HUD / notes (not a CI hard gate by itself).
bool isOriginalObviouslyLonger({
  required double? originalSec,
  required double? currentSec,
  double thresholdSec = kPoc09OriginalLongerThresholdSec,
}) {
  if (originalSec == null || currentSec == null) return false;
  if (!originalSec.isFinite || !currentSec.isFinite) return false;
  return (originalSec - currentSec) > thresholdSec;
}

String formatProbeSummary({
  required double phAssetDurationSec,
  required double? currentAvDurationSec,
  required double? originalAvDurationSec,
  required double? exportDurationSec,
  required int audioTrackCount,
  required int textTrackCount,
  String? errorCode,
}) {
  if (errorCode != null && errorCode.isNotEmpty) {
    return 'error=$errorCode';
  }
  final cur = currentAvDurationSec?.toStringAsFixed(2) ?? '—';
  final orig = originalAvDurationSec?.toStringAsFixed(2) ?? '—';
  final exp = exportDurationSec?.toStringAsFixed(2) ?? '—';
  final longer = isOriginalObviouslyLonger(
    originalSec: originalAvDurationSec,
    currentSec: currentAvDurationSec,
  );
  return 'ph=${phAssetDurationSec.toStringAsFixed(2)}s '
      'cur=${cur}s orig=${orig}s exp=${exp}s '
      'audio=$audioTrackCount text=$textTrackCount '
      'origLonger(>2s)=$longer';
}
