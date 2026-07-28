import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_09/poc_09_duration.dart';

void main() {
  test('isOriginalObviouslyLonger requires > 2.0s delta', () {
    expect(
      isOriginalObviouslyLonger(originalSec: 10, currentSec: 8.1),
      isFalse,
    );
    expect(
      isOriginalObviouslyLonger(originalSec: 10, currentSec: 7.9),
      isTrue,
    );
  });

  test('formatProbeSummary includes advisory flag', () {
    final s = formatProbeSummary(
      phAssetDurationSec: 8,
      currentAvDurationSec: 8,
      originalAvDurationSec: 30,
      exportDurationSec: 8,
      audioTrackCount: 1,
      textTrackCount: 0,
    );
    expect(s.contains('origLonger(>2s)=true'), isTrue);
  });
}
