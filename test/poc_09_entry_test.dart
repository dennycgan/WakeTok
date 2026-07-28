import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_09/poc_09_entry.dart';

void main() {
  test('POC-09 spike home flag defaults off', () {
    expect(kPoc09SpikeAsHome, isFalse);
  });
}
