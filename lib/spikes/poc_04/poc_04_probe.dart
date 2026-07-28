import 'package:waketok/spikes/poc_04/generated/poc_04_photo_library.g.dart';
import 'package:waketok/spikes/poc_04/poc_04_feed_controller.dart';

/// One diagnostics snapshot during a sustained-scroll probe.
class Poc04ProbeSample {
  const Poc04ProbeSample({
    required this.step,
    required this.activeCount,
    required this.warmingCount,
    required this.tempFileCount,
  });

  final int step;
  final int activeCount;
  final int warmingCount;
  final int tempFileCount;

  factory Poc04ProbeSample.fromDiagnostics(int step, Poc04PoolDiagnostics d) {
    return Poc04ProbeSample(
      step: step,
      activeCount: d.activeCount,
      warmingCount: d.warmingCount,
      tempFileCount: d.tempFileCount,
    );
  }
}

/// Pass/fail evaluation for phase 2.4 bounded-resource probes (pure / testable).
class Poc04ProbeEvaluation {
  const Poc04ProbeEvaluation({
    required this.passed,
    required this.summary,
    required this.maxActive,
    required this.maxWarming,
    required this.maxTemp,
    required this.firstWindowMaxTemp,
    required this.lastWindowMaxTemp,
  });

  final bool passed;
  final String summary;
  final int maxActive;
  final int maxWarming;
  final int maxTemp;
  final int firstWindowMaxTemp;
  final int lastWindowMaxTemp;
}

/// Evaluates probe samples. [window] is used for first/last monotonic compare.
Poc04ProbeEvaluation evaluatePoc04Probe({
  required List<Poc04ProbeSample> samples,
  required int transitions,
  int tempSoftCap = kPoc04TempFileSoftCap,
  int tempSlack = 2,
  int window = 10,
}) {
  if (samples.isEmpty) {
    return const Poc04ProbeEvaluation(
      passed: false,
      summary: 'FAIL no samples',
      maxActive: 0,
      maxWarming: 0,
      maxTemp: 0,
      firstWindowMaxTemp: 0,
      lastWindowMaxTemp: 0,
    );
  }

  var maxActive = 0;
  var maxWarming = 0;
  var maxTemp = 0;
  var poolOk = true;
  for (final s in samples) {
    maxActive = maxActive > s.activeCount ? maxActive : s.activeCount;
    maxWarming = maxWarming > s.warmingCount ? maxWarming : s.warmingCount;
    maxTemp = maxTemp > s.tempFileCount ? maxTemp : s.tempFileCount;
    final d = Poc04PoolDiagnostics(
      activeCount: s.activeCount,
      warmingCount: s.warmingCount,
      tempFileCount: s.tempFileCount,
    );
    if (!Poc04FeedController.poolWithinCap(d)) {
      poolOk = false;
    }
  }

  final first = samples.where((s) => s.step < window).toList();
  final lastStart = transitions > window ? transitions - window : 0;
  final last = samples.where((s) => s.step >= lastStart).toList();

  int maxTempIn(List<Poc04ProbeSample> list) {
    var m = 0;
    for (final s in list) {
      if (s.tempFileCount > m) m = s.tempFileCount;
    }
    return m;
  }

  final firstMaxTemp = first.isEmpty ? maxTempIn(samples) : maxTempIn(first);
  final lastMaxTemp = last.isEmpty ? maxTempIn(samples) : maxTempIn(last);

  final tempEndOk = samples.last.tempFileCount <= tempSoftCap + tempSlack;
  // Last window must not systematically exceed first window (allow small slack).
  final growthOk = lastMaxTemp <= firstMaxTemp + tempSlack;
  final passed = poolOk && tempEndOk && growthOk;

  final verdict = passed ? 'PASS' : 'FAIL';
  final summary =
      '$verdict poolMax=$maxActive+$maxWarming tmpMax=$maxTemp '
      'tmpFirst$window=$firstMaxTemp tmpLast$window=$lastMaxTemp '
      '(n=$transitions)';

  return Poc04ProbeEvaluation(
    passed: passed,
    summary: summary,
    maxActive: maxActive,
    maxWarming: maxWarming,
    maxTemp: maxTemp,
    firstWindowMaxTemp: firstMaxTemp,
    lastWindowMaxTemp: lastMaxTemp,
  );
}
