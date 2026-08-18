import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/layer2_dwell.dart';

void main() {
  test('U-16.4 remaining is N minus elapsed, floor at zero', () {
    const n = Duration(milliseconds: 500);
    expect(
      remainingLayer2Dwell(n: n, elapsed: Duration.zero),
      n,
    );
    expect(
      remainingLayer2Dwell(n: n, elapsed: const Duration(milliseconds: 200)),
      const Duration(milliseconds: 300),
    );
    expect(
      remainingLayer2Dwell(n: n, elapsed: n),
      Duration.zero,
    );
    expect(
      remainingLayer2Dwell(n: n, elapsed: const Duration(milliseconds: 800)),
      Duration.zero,
    );
    expect(
      remainingLayer2Dwell(n: Duration.zero, elapsed: Duration.zero),
      Duration.zero,
    );
  });
}
