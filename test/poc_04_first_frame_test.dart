import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_04/poc_04_first_frame.dart';

void main() {
  test('poc04Percentile p90 on 20 samples', () {
    final samples = [for (var i = 1; i <= 20; i++) i * 10.0]; // 10..200
    expect(poc04Percentile(samples, 90), closeTo(181.0, 1.0));
    expect(poc04Percentile(samples, 50), closeTo(105.0, 1.0));
  });

  test('formatFirstFrameSummary', () {
    final s = formatFirstFrameSummary([100, 200, 300]);
    expect(s, contains('n=3'));
    expect(s, contains('p90='));
  });
}
