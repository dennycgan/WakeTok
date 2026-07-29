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

/// 9.3 Slow-mo advisory (Q4=A): export ≈ Photos-displayed / PHAsset duration.
String formatSloMoGateSummary({
  required bool isHighFrameRate,
  required double phAssetDurationSec,
  required double? currentAvDurationSec,
  required double? exportDurationSec,
  String? errorCode,
}) {
  if (errorCode != null && errorCode.isNotEmpty) {
    return 'sloMoGate=FAIL error=$errorCode';
  }
  if (!isHighFrameRate) {
    return 'sloMoGate=N/A (not HFR subtype)';
  }
  final matchCur = isExportMatchingCurrent(
    exportSec: exportDurationSec,
    currentSec: currentAvDurationSec,
  );
  final matchPh = isExportMatchingCurrent(
    exportSec: exportDurationSec,
    currentSec: phAssetDurationSec,
  );
  final curPh = isExportMatchingCurrent(
    exportSec: currentAvDurationSec,
    currentSec: phAssetDurationSec,
  );
  final pass = matchCur && matchPh && curPh;
  return 'sloMoGate=${pass ? "PASS" : "CHECK"} HFR=true '
      'exp≈cur=$matchCur exp≈ph=$matchPh cur≈ph=$curPh';
}

/// 9.4 Default audio advisory: ≥1 audio track + successful export (listen = manual).
String formatAudioGateSummary({
  required int audioTrackCount,
  required String? exportPath,
  required double? exportDurationSec,
  String? errorCode,
}) {
  if (errorCode != null && errorCode.isNotEmpty) {
    return 'audioGate=FAIL error=$errorCode';
  }
  final hasTrack = audioTrackCount >= 1;
  final hasFile = exportPath != null &&
      exportPath.isNotEmpty &&
      exportDurationSec != null &&
      exportDurationSec > 0.01;
  if (!hasTrack) {
    return 'audioGate=FAIL audioTracks=0 (silent or missing)';
  }
  if (!hasFile) {
    return 'audioGate=CHECK audioTracks=$audioTrackCount (no export file)';
  }
  return 'audioGate=PASS audioTracks=$audioTrackCount '
      '(listen export to confirm audible)';
}

/// 9.6 Explicit-failure advisory (Q5=A): cloud-only + network off.
String formatFailGateSummary({
  required bool networkAccessAllowed,
  required String? errorCode,
  required String? exportPath,
}) {
  if (networkAccessAllowed) {
    return 'failGate=N/A (network on)';
  }
  final hasPath = exportPath != null && exportPath.isNotEmpty;
  if (hasPath) {
    return 'failGate=FAIL exportPath set (must not succeed silently)';
  }
  if (errorCode == 'inCloudUnavailable') {
    return 'failGate=PASS error=inCloudUnavailable (no export path)';
  }
  if (errorCode != null && errorCode.isNotEmpty) {
    return 'failGate=CHECK error=$errorCode (not inCloudUnavailable)';
  }
  return 'failGate=CHECK no error and no path';
}

/// 9.6 Control leg: same F5 with network on must export successfully.
String formatControlGateSummary({
  required bool networkAccessAllowed,
  required String? errorCode,
  required String? exportPath,
  required double? exportDurationSec,
}) {
  if (!networkAccessAllowed) {
    return 'controlGate=N/A (network off)';
  }
  final hasFile = exportPath != null &&
      exportPath.isNotEmpty &&
      exportDurationSec != null &&
      exportDurationSec > 0.01;
  final clean = errorCode == null || errorCode.isEmpty;
  if (clean && hasFile) {
    return 'controlGate=PASS export OK (path + duration)';
  }
  final err = (errorCode != null && errorCode.isNotEmpty) ? errorCode : 'none';
  return 'controlGate=CHECK error=$err hasFile=$hasFile';
}
