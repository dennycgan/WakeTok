/// Spike helpers for POC-09 duration / fallback advisory (9.2 notes threshold).
library;

/// Notes acceptance: original is "obviously longer" when delta exceeds this.
const double kPoc09OriginalLongerThresholdSec = 2.0;

/// Notes acceptance: export matches current when |exp - cur| is within this.
const double kPoc09ExportMatchToleranceSec = 0.25;

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

/// Advisory: exported file duration matches current representation.
bool isExportMatchingCurrent({
  required double? exportSec,
  required double? currentSec,
  double toleranceSec = kPoc09ExportMatchToleranceSec,
}) {
  if (exportSec == null || currentSec == null) return false;
  if (!exportSec.isFinite || !currentSec.isFinite) return false;
  return (exportSec - currentSec).abs() <= toleranceSec;
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

/// 9.2 Trim advisory line for HUD (notes gate; not a unit-test hard fail).
String formatTrimGateSummary({
  required double? currentAvDurationSec,
  required double? originalAvDurationSec,
  required double? exportDurationSec,
  String? errorCode,
}) {
  if (errorCode != null && errorCode.isNotEmpty) {
    return 'trimGate=FAIL error=$errorCode';
  }
  final longer = isOriginalObviouslyLonger(
    originalSec: originalAvDurationSec,
    currentSec: currentAvDurationSec,
  );
  final match = isExportMatchingCurrent(
    exportSec: exportDurationSec,
    currentSec: currentAvDurationSec,
  );
  final delta = (originalAvDurationSec != null && currentAvDurationSec != null)
      ? (originalAvDurationSec - currentAvDurationSec)
      : null;
  final deltaStr = delta?.toStringAsFixed(2) ?? '—';
  final pass = longer && match;
  return 'trimGate=${pass ? "PASS" : "CHECK"} '
      'delta(orig-cur)=${deltaStr}s '
      'origLonger(>2s)=$longer exp≈cur(±0.25s)=$match';
}
