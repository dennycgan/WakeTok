import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cancel_finish_dedupe.dart';
import 'package:waketok/features/main_browse/wait_chrome_policy.dart';

void main() {
  group('U-17.3 wait chrome policy', () {
    test('U-17.3a a4 suppress below T then after-band', () {
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a4L2ReadyEvict,
          elapsedInFlight: const Duration(milliseconds: 149),
          a4SuppressBelow: kDefaultA4SuppressBelow,
          isCurrent: true,
        ),
        WaitChromeKind.none,
      );
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a4L2ReadyEvict,
          elapsedInFlight: const Duration(milliseconds: 150),
          a4SuppressBelow: kDefaultA4SuppressBelow,
          isCurrent: true,
        ),
        WaitChromeKind.cornerSpinnerAfterBand,
      );
    });

    test('U-17.3b a1 always immediate regardless of T/elapsed', () {
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a1Miss,
          elapsedInFlight: Duration.zero,
          a4SuppressBelow: const Duration(hours: 1),
          isCurrent: true,
        ),
        WaitChromeKind.cornerSpinnerImmediate,
      );
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a1Miss,
          elapsedInFlight: const Duration(seconds: 5),
          a4SuppressBelow: kDefaultA4SuppressBelow,
          isCurrent: false,
        ),
        WaitChromeKind.cornerSpinnerImmediate,
      );
    });

    test('U-17.3c a3 is none', () {
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a3L2ReadyHit,
          elapsedInFlight: const Duration(seconds: 1),
          a4SuppressBelow: kDefaultA4SuppressBelow,
          isCurrent: true,
        ),
        WaitChromeKind.none,
      );
    });

    test('U-17.3d a2 policy helper is immediate (G applied in paint path)', () {
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a2WaitToPlayable,
          elapsedInFlight: Duration.zero,
          a4SuppressBelow: kDefaultA4SuppressBelow,
          isCurrent: true,
        ),
        WaitChromeKind.cornerSpinnerImmediate,
      );
    });

    test('U-17.3f a4 peek is none even when elapsed >> T', () {
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a4L2ReadyEvict,
          elapsedInFlight: const Duration(seconds: 5),
          a4SuppressBelow: kDefaultA4SuppressBelow,
          isCurrent: false,
        ),
        WaitChromeKind.none,
      );
    });

    test('U-17.3g a1 peek stays immediate (not global peek-none)', () {
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a1Miss,
          elapsedInFlight: Duration.zero,
          a4SuppressBelow: kDefaultA4SuppressBelow,
          isCurrent: false,
        ),
        WaitChromeKind.cornerSpinnerImmediate,
      );
    });

    test('U-17.3h a2 peek stays immediate (ignores isCurrent)', () {
      expect(
        resolveWaitChrome(
          path: WaitChromePathClass.a2WaitToPlayable,
          elapsedInFlight: Duration.zero,
          a4SuppressBelow: kDefaultA4SuppressBelow,
          isCurrent: false,
        ),
        WaitChromeKind.cornerSpinnerImmediate,
      );
    });

    test('U-17.3i stale a4 reveal tick is ignored when generation changes', () {
      expect(
        shouldApplyA4ChromeRevealTick(
          isMounted: true,
          layer2InFlight: true,
          armedGeneration: 1,
          currentInFlightGeneration: 1,
        ),
        isTrue,
      );
      expect(
        shouldApplyA4ChromeRevealTick(
          isMounted: true,
          layer2InFlight: true,
          armedGeneration: 1,
          currentInFlightGeneration: 2,
        ),
        isFalse,
        reason: 'leave/re-arm must not let old timer paint',
      );
      expect(
        shouldApplyA4ChromeRevealTick(
          isMounted: true,
          layer2InFlight: false,
          armedGeneration: 1,
          currentInFlightGeneration: 1,
        ),
        isFalse,
      );
    });
  });

  group('U-17.4 coverless wait label door', () {
    test('U-17.4a label shares spinner door (no independent trigger)', () {
      expect(coverlessWaitShowsLabel(showWaitSpinner: false), isFalse);
      expect(coverlessWaitShowsLabel(showWaitSpinner: true), isTrue);
    });

    test('U-17.4b coverless presentation is loading or no cover', () {
      expect(
        isCoverlessFeedPresentation(loading: true, hasDisplayableCover: true),
        isTrue,
      );
      expect(
        isCoverlessFeedPresentation(loading: false, hasDisplayableCover: false),
        isTrue,
      );
      expect(
        isCoverlessFeedPresentation(loading: false, hasDisplayableCover: true),
        isFalse,
      );
    });
  });

  group('U-17.5b corner reassure', () {
    const base = (
      isCurrent: true,
      layer2InFlight: true,
      layer2Failed: false,
      loadingMissPage: false,
      path: WaitChromePathClass.a2WaitToPlayable,
      waitSpinnerVisible: true,
    );

    test('U-17.5b-a shows only after 3s on a2 (cover optional)', () {
      expect(
        shouldShowLayer2CornerReassure(
          isCurrent: base.isCurrent,
          layer2InFlight: base.layer2InFlight,
          layer2Failed: base.layer2Failed,
          loadingMissPage: base.loadingMissPage,
          path: base.path,
          elapsedInFlight: const Duration(seconds: 2),
          waitSpinnerVisible: base.waitSpinnerVisible,
        ),
        isFalse,
      );
      expect(
        shouldShowLayer2CornerReassure(
          isCurrent: base.isCurrent,
          layer2InFlight: base.layer2InFlight,
          layer2Failed: base.layer2Failed,
          loadingMissPage: base.loadingMissPage,
          path: base.path,
          elapsedInFlight: kLayer2CornerReassureAfter,
          waitSpinnerVisible: base.waitSpinnerVisible,
        ),
        isTrue,
      );
    });

    test('U-17.5b-a4 and L1-miss excluded; covered still allowed', () {
      expect(
        shouldShowLayer2CornerReassure(
          isCurrent: true,
          layer2InFlight: true,
          layer2Failed: false,
          loadingMissPage: false,
          path: WaitChromePathClass.a4L2ReadyEvict,
          elapsedInFlight: kLayer2CornerReassureAfter,
          waitSpinnerVisible: true,
        ),
        isFalse,
      );
      expect(
        shouldShowLayer2CornerReassure(
          isCurrent: true,
          layer2InFlight: true,
          layer2Failed: false,
          loadingMissPage: false,
          path: WaitChromePathClass.a2WaitToPlayable,
          elapsedInFlight: kLayer2CornerReassureAfter,
          waitSpinnerVisible: true,
        ),
        isTrue,
        reason: 'L1/poster present must not block corner reassure',
      );
      expect(
        shouldShowLayer2CornerReassure(
          isCurrent: true,
          layer2InFlight: true,
          layer2Failed: false,
          loadingMissPage: true,
          path: WaitChromePathClass.a2WaitToPlayable,
          elapsedInFlight: kLayer2CornerReassureAfter,
          waitSpinnerVisible: true,
        ),
        isFalse,
      );
    });

    test('U-17.5b-live LIVE badge is not a reassure gate', () {
      expect(
        shouldShowLayer2CornerReassure(
          isCurrent: true,
          layer2InFlight: true,
          layer2Failed: false,
          loadingMissPage: false,
          path: WaitChromePathClass.a2WaitToPlayable,
          elapsedInFlight: kLayer2CornerReassureAfter,
          waitSpinnerVisible: true,
        ),
        isTrue,
        reason: 'LIVE stacks above spinner; reassure may coexist',
      );
    });

    test('U-17.5b-gen stale reassure tick ignored when generation changes', () {
      expect(
        shouldApplyLayer2ReassureTick(
          isMounted: true,
          layer2InFlight: true,
          armedGeneration: 1,
          currentInFlightGeneration: 1,
        ),
        isTrue,
      );
      expect(
        shouldApplyLayer2ReassureTick(
          isMounted: true,
          layer2InFlight: true,
          armedGeneration: 1,
          currentInFlightGeneration: 2,
        ),
        isFalse,
        reason: 'leave/re-arm must not let old 3s timer paint',
      );
    });
  });

  group('U-17.3e cancel finish dedupe', () {
    test('leave double finish collapses to one', () {
      const a = CancelFinishEvent(assetId: 'x', windowId: 'leave-1');
      const b = CancelFinishEvent(assetId: 'x', windowId: 'leave-1');
      const c = CancelFinishEvent(assetId: 'y', windowId: 'leave-1');
      expect(dedupeCancelFinishCount([a, b, c]), 2);
    });
  });
}
