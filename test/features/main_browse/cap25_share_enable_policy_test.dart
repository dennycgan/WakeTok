import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cap25_share_enable_policy.dart';

void main() {
  group('cap25ShareEnablePredicate (ADR-051 Decision 14)', () {
    Cap25ShareEnable eval({
      bool actionable = true,
      bool settled = true,
      bool covering = false,
      bool layer2Ready = true,
      bool liveMotion = false,
    }) {
      return cap25ShareEnablePredicate(
        actionable: actionable,
        verticalFeedSettled: settled,
        transitionCovering: covering,
        layer2DisplayReady: layer2Ready,
        liveMotionMounted: liveMotion,
      );
    }

    test('T-25.14-1 local still L1-only → chrome visible, tap disabled', () {
      final e = eval(layer2Ready: false);
      expect(e.chromeVisible, isTrue);
      expect(e.tapEnabled, isFalse);
      expect(e.dimmed, isTrue);
    });

    test('T-25.14-2 local still L2 ready → tap enabled', () {
      final e = eval(layer2Ready: true);
      expect(e.chromeVisible, isTrue);
      expect(e.tapEnabled, isTrue);
    });

    test('T-25.14-3 Live motion mounted → tap disabled', () {
      final e = eval(liveMotion: true);
      expect(e.chromeVisible, isTrue);
      expect(e.tapEnabled, isFalse);
    });

    test('T-25.14-4 Live still (motion off) + L2 ready → tap enabled', () {
      final e = eval(liveMotion: false, layer2Ready: true);
      expect(e.tapEnabled, isTrue);
    });

    test(
      'T-25.14-5 iCloud unreadiness does not skip L2 / Live limbs',
      () {
        // Availability is not an enable input; same as local ¬L2 + Live.
        final e = eval(layer2Ready: false, liveMotion: true);
        expect(e.chromeVisible, isTrue);
        expect(e.tapEnabled, isFalse);
      },
    );

    test('T-25.14-5b ¬L2 alone → dimmed (no availability limb)', () {
      final e = eval(layer2Ready: false, liveMotion: false);
      expect(e.tapEnabled, isFalse);
    });

    test('T-25.14-6a peek (!settled) → chrome closed (hide axis)', () {
      final e = eval(settled: false);
      expect(e.chromeVisible, isFalse);
      expect(e.tapEnabled, isFalse);
    });

    test('T-25.14-6b covering → chrome closed (hide axis)', () {
      final e = eval(covering: true);
      expect(e.chromeVisible, isFalse);
    });

    test(
      'T-25.14-7 debt-400 shape: ¬L2 dimmed; L2 later → enabled '
      '(no permanent lock branch)',
      () {
        final blocked = eval(layer2Ready: false);
        expect(blocked.tapEnabled, isFalse);
        final ready = eval(layer2Ready: true);
        expect(ready.tapEnabled, isTrue);
      },
    );

    test('not actionable → chrome closed regardless of L2', () {
      final e = eval(actionable: false, layer2Ready: false);
      expect(e.chromeVisible, isFalse);
      expect(e.tapEnabled, isFalse);
    });
  });
}
