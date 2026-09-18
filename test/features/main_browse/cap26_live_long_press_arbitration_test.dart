import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/cap26_live_long_press_arbitration.dart';

void main() {
  group('U-26.2-1 classifyLiveLongPress', () {
    test('hold constants align Cap 19 edge-hold / early-motion', () {
      expect(kLiveLongPressHoldDuration, kCap19EdgeHoldWindow);
      expect(kLiveLongPressMaxSlopPx, kCap19LeftSwipeEarlyMotionThreshold);
      expect(kLiveLongPressHoldDuration, const Duration(milliseconds: 400));
      expect(kLiveLongPressMaxSlopPx, 24);
    });

    test('tracking before hold elapses', () {
      expect(
        classifyLiveLongPress(
          delta: Offset.zero,
          pressDuration: const Duration(milliseconds: 200),
        ),
        LiveLongPressPhase.tracking,
      );
    });

    test('fire when hold elapsed and within slop', () {
      expect(
        classifyLiveLongPress(
          delta: const Offset(10, 10),
          pressDuration: const Duration(milliseconds: 400),
        ),
        LiveLongPressPhase.fire,
      );
    });

    test('cancel when slop exceeded before fire', () {
      expect(
        classifyLiveLongPress(
          delta: const Offset(25, 0),
          pressDuration: const Duration(milliseconds: 200),
        ),
        LiveLongPressPhase.cancelled,
      );
    });
  });

  group('U-26.2-2 shouldArmLiveLongPress', () {
    test('arms only for current Live static idle page', () {
      expect(
        shouldArmLiveLongPress(
          isCurrent: true,
          isLiveStill: true,
          liveMotionMounted: false,
          livePreparing: false,
          liveSilentReplayInFlight: false,
          isCurrentStillMagnified: false,
          transientPinchActive: false,
          stillPinchContact: false,
        ),
        isTrue,
      );
    });

    test('disarms when mounted / preparing / silent in-flight / magnified', () {
      const base = (
        isCurrent: true,
        isLiveStill: true,
        liveMotionMounted: false,
        livePreparing: false,
        liveSilentReplayInFlight: false,
        isCurrentStillMagnified: false,
        transientPinchActive: false,
        stillPinchContact: false,
      );
      expect(
        shouldArmLiveLongPress(
          isCurrent: base.isCurrent,
          isLiveStill: base.isLiveStill,
          liveMotionMounted: true,
          livePreparing: base.livePreparing,
          liveSilentReplayInFlight: base.liveSilentReplayInFlight,
          isCurrentStillMagnified: base.isCurrentStillMagnified,
          transientPinchActive: base.transientPinchActive,
          stillPinchContact: base.stillPinchContact,
        ),
        isFalse,
      );
      expect(
        shouldArmLiveLongPress(
          isCurrent: base.isCurrent,
          isLiveStill: base.isLiveStill,
          liveMotionMounted: base.liveMotionMounted,
          livePreparing: true,
          liveSilentReplayInFlight: base.liveSilentReplayInFlight,
          isCurrentStillMagnified: base.isCurrentStillMagnified,
          transientPinchActive: base.transientPinchActive,
          stillPinchContact: base.stillPinchContact,
        ),
        isFalse,
      );
      expect(
        shouldArmLiveLongPress(
          isCurrent: base.isCurrent,
          isLiveStill: base.isLiveStill,
          liveMotionMounted: base.liveMotionMounted,
          livePreparing: base.livePreparing,
          liveSilentReplayInFlight: true,
          isCurrentStillMagnified: base.isCurrentStillMagnified,
          transientPinchActive: base.transientPinchActive,
          stillPinchContact: base.stillPinchContact,
        ),
        isFalse,
      );
      expect(
        shouldArmLiveLongPress(
          isCurrent: base.isCurrent,
          isLiveStill: base.isLiveStill,
          liveMotionMounted: base.liveMotionMounted,
          livePreparing: base.livePreparing,
          liveSilentReplayInFlight: base.liveSilentReplayInFlight,
          isCurrentStillMagnified: true,
          transientPinchActive: base.transientPinchActive,
          stillPinchContact: base.stillPinchContact,
        ),
        isFalse,
      );
    });
  });

  group('U-26.5a shouldMountLiveLongPressListener', () {
    test('keeps Listener after fire when mounted disarms mayFire', () {
      expect(
        shouldMountLiveLongPressListener(
          mayFire: false,
          holdingAfterFire: true,
          isCurrent: true,
        ),
        isTrue,
      );
    });

    test('shrinks when panels open or leave-current (abort hold)', () {
      expect(
        shouldMountLiveLongPressListener(
          mayFire: false,
          holdingAfterFire: true,
          isCurrent: true,
          cap19PanelOpen: true,
        ),
        isFalse,
      );
      expect(
        shouldMountLiveLongPressListener(
          mayFire: true,
          holdingAfterFire: false,
          isCurrent: false,
        ),
        isFalse,
      );
    });

    test('idle without mayFire or hold does not mount', () {
      expect(
        shouldMountLiveLongPressListener(
          mayFire: false,
          holdingAfterFire: false,
          isCurrent: true,
        ),
        isFalse,
      );
    });
  });
}
