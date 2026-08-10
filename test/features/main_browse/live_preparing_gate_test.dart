import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';

void main() {
  test('L-S6-unit stale generation does not clear preparing', () {
    final gate = FeedMediaRequestGate();
    final g1 = gate.begin();
    var preparing = true;

    // Newer activation.
    final g2 = gate.begin();
    preparing = gatedFlagUpdate(
      gate: gate,
      generation: g2,
      current: preparing,
      next: true,
    );
    expect(preparing, isTrue);

    // Stale clear from g1 must not apply (litmus: remove isCurrent → fails).
    preparing = gatedFlagUpdate(
      gate: gate,
      generation: g1,
      current: preparing,
      next: false,
    );
    expect(preparing, isTrue);

    preparing = gatedFlagUpdate(
      gate: gate,
      generation: g2,
      current: preparing,
      next: false,
    );
    expect(preparing, isFalse);
  });
}
