import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_03/poc_03_entry.dart';

void main() {
  test('POC-03 spike home flag defaults off', () {
    expect(kPoc03SpikeAsHome, isFalse);
  });
}
