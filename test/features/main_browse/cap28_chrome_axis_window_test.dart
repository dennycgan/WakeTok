import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cap28_chrome_axis_window.dart';

void main() {
  group('Cap28ChromeAxisWindow', () {
    test('U-28.4-chrome-win stable+buf closes after quiet period', () {
      final w = Cap28ChromeAxisWindow(
        stableFor: const Duration(milliseconds: 500),
        bufferAfterStable: const Duration(milliseconds: 750),
        hardCap: const Duration(seconds: 3),
      );
      final t0 = DateTime.utc(2026, 9, 22, 1, 0, 0);
      w.arm(t0, 'A');
      expect(w.isArmed, isTrue);
      expect(w.tick(t0.add(const Duration(milliseconds: 499))), isTrue);
      expect(w.isInBuffer, isFalse);
      expect(w.tick(t0.add(const Duration(milliseconds: 500))), isTrue);
      expect(w.isInBuffer, isTrue);
      expect(w.tick(t0.add(const Duration(milliseconds: 1249))), isTrue);
      expect(w.tick(t0.add(const Duration(milliseconds: 1250))), isFalse);
      expect(w.closeReason, 'stable+buf');
      expect(w.crossFrameFingerprintCount, 1);
    });

    test('U-28.4-chrome-win change during buffer restarts stability', () {
      final w = Cap28ChromeAxisWindow(
        stableFor: const Duration(milliseconds: 500),
        bufferAfterStable: const Duration(milliseconds: 750),
        hardCap: const Duration(seconds: 5),
      );
      final t0 = DateTime.utc(2026, 9, 22, 1, 0, 0);
      w.arm(t0, 'A');
      w.tick(t0.add(const Duration(milliseconds: 500)));
      expect(w.isInBuffer, isTrue);
      expect(w.onEvent(t0.add(const Duration(milliseconds: 600)), 'B'), isTrue);
      expect(w.isInBuffer, isFalse);
      expect(w.crossFrameFingerprintCount, 2);
      // Need another 500ms quiet + 750ms buffer from the change.
      expect(w.tick(t0.add(const Duration(milliseconds: 1099))), isTrue);
      expect(w.isInBuffer, isFalse);
      expect(w.tick(t0.add(const Duration(milliseconds: 1100))), isTrue);
      expect(w.isInBuffer, isTrue);
      expect(w.tick(t0.add(const Duration(milliseconds: 1850))), isFalse);
      expect(w.closeReason, 'stable+buf');
    });

    test('U-28.4-chrome-win hardCap wins over unfinished buffer', () {
      final w = Cap28ChromeAxisWindow(
        stableFor: const Duration(milliseconds: 500),
        bufferAfterStable: const Duration(milliseconds: 750),
        hardCap: const Duration(seconds: 3),
      );
      final t0 = DateTime.utc(2026, 9, 22, 1, 0, 0);
      w.arm(t0, 'A');
      // Keep changing so stability never completes.
      w.onEvent(t0.add(const Duration(milliseconds: 100)), 'B');
      w.onEvent(t0.add(const Duration(milliseconds: 200)), 'C');
      w.onEvent(t0.add(const Duration(milliseconds: 1000)), 'D');
      w.onEvent(t0.add(const Duration(milliseconds: 2000)), 'E');
      expect(w.tick(t0.add(const Duration(seconds: 3))), isFalse);
      expect(w.closeReason, 'hardCap');
      expect(w.crossFrameFingerprintCount, greaterThan(1));
    });

    test('U-28.4-chrome-win bounce A>B>A increments bounceCount', () {
      final w = Cap28ChromeAxisWindow(
        crossFrameGap: const Duration(milliseconds: 8),
      );
      final t0 = DateTime.utc(2026, 9, 22, 1, 0, 0);
      w.arm(t0, 'A');
      w.onEvent(t0.add(const Duration(milliseconds: 20)), 'B');
      w.onEvent(t0.add(const Duration(milliseconds: 40)), 'A');
      expect(w.bounceCount, 1);
      expect(w.orderedCrossFrameFingerprints, ['A', 'B', 'A']);
    });

    test('U-28.4-chrome-win same-frame burst folds into one cross-frame fp', () {
      final w = Cap28ChromeAxisWindow(
        crossFrameGap: const Duration(milliseconds: 8),
      );
      final t0 = DateTime.utc(2026, 9, 22, 1, 0, 0);
      w.arm(t0, 'A');
      w.onEvent(t0.add(const Duration(milliseconds: 1)), 'B');
      w.onEvent(t0.add(const Duration(milliseconds: 2)), 'C');
      expect(w.crossFrameFingerprintCount, 1);
      expect(w.orderedCrossFrameFingerprints.single, 'C');
      expect(w.sameFrameBurstCount, 2);
    });
  });
}
