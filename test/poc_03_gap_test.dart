import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_03/poc_03_gap.dart';

void main() {
  test('poc03Percentile p90 on 10 samples', () {
    final samples = List<double>.generate(10, (i) => (i + 1) * 10.0);
    expect(poc03Percentile(samples, 90), closeTo(91.0, 0.01));
  });

  test('formatGapSummary pass when p90 under target', () {
    final samples = List<double>.filled(8, 40.0);
    final s = formatGapSummary(samples);
    expect(s.contains('PASS'), isTrue);
    expect(s.contains('p90=40ms'), isTrue);
  });
}
