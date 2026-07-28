/// Target first-frame sample count for phase 2.5 (H3=B).
const int kPoc04FirstFrameSampleTarget = 20;

/// Per-sample timeout ms; timeouts still count in the distribution (H4=A).
const int kPoc04FirstFrameTimeoutMs = 3000;

/// Computes percentile [p] in 0–100 on a copy of [values].
double poc04Percentile(List<double> values, double p) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  if (sorted.length == 1) return sorted.first;
  final rank = (p / 100.0) * (sorted.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  if (lo == hi) return sorted[lo];
  final t = rank - lo;
  return sorted[lo] + (sorted[hi] - sorted[lo]) * t;
}

String formatFirstFrameSummary(List<double> samples) {
  if (samples.isEmpty) return 'ff n=0';
  final p50 = poc04Percentile(samples, 50);
  final p90 = poc04Percentile(samples, 90);
  return 'ff n=${samples.length} p50=${p50.toStringAsFixed(0)}ms '
      'p90=${p90.toStringAsFixed(0)}ms';
}
