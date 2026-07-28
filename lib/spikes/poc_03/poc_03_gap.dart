/// Foreground gap probe helpers for POC-03 phase 3.2 (P3=B).
library;

/// Target for optional foreground gap p90 (ms).
const double kPoc03GapP90TargetMs = 150;

double poc03Percentile(List<double> samples, int percentile) {
  if (samples.isEmpty) return 0;
  final sorted = List<double>.from(samples)..sort();
  final rank = (percentile / 100.0) * (sorted.length - 1);
  final low = rank.floor();
  final high = rank.ceil();
  if (low == high) return sorted[low];
  final t = rank - low;
  return sorted[low] * (1 - t) + sorted[high] * t;
}

String formatGapSummary(List<double> samples) {
  if (samples.isEmpty) return 'gap n=0';
  final p50 = poc03Percentile(samples, 50);
  final p90 = poc03Percentile(samples, 90);
  final pass = samples.length >= 5 && p90 < kPoc03GapP90TargetMs;
  return 'gap n=${samples.length} p50=${p50.toStringAsFixed(0)}ms '
      'p90=${p90.toStringAsFixed(0)}ms '
      '(${pass ? 'PASS' : 'FAIL'} p90<${kPoc03GapP90TargetMs.toStringAsFixed(0)}; '
      'foreground probe)';
}
