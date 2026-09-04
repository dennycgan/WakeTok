import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_drag.dart';

void main() {
  test('T-19.6-1 horizontal-dominant left delta classifies leftSwipeAppend', () {
    expect(
      classifyEarlyMotion(
        delta: const Offset(-40, 4),
        pressDuration: const Duration(milliseconds: 80),
      ),
      Cap19HorizontalGestureIntent.leftSwipeAppend,
    );
  });

  test('T-19.6-2 stationary past hold window classifies edgeHold2x', () {
    expect(
      classifyEarlyMotion(
        delta: Offset.zero,
        pressDuration: kCap19EdgeHoldWindow + const Duration(milliseconds: 1),
      ),
      Cap19HorizontalGestureIntent.edgeHold2x,
    );
  });

  test('T-19.6-3 vertical-dominant motion classifies none', () {
    expect(
      classifyEarlyMotion(
        delta: const Offset(2, -80),
        pressDuration: const Duration(milliseconds: 50),
      ),
      Cap19HorizontalGestureIntent.none,
    );
  });

  test('T-19.6-4 magnified still blocks arming', () {
    expect(
      leftSwipeArmingAllowed(
        leftSwipeAddEnabled: true,
        isCurrentStillMagnified: true,
        cap19PanelOpen: false,
        currentAssetActionable: true,
      ),
      isFalse,
    );
  });

  test('T-19.8-arm current asset not actionable blocks arming', () {
    expect(
      leftSwipeArmingAllowed(
        leftSwipeAddEnabled: true,
        isCurrentStillMagnified: false,
        cap19PanelOpen: false,
        currentAssetActionable: false,
      ),
      isFalse,
    );
  });

  test('shouldTriggerLeftSwipeAppend requires threshold and horizontal dominance',
      () {
    expect(
      shouldTriggerLeftSwipeAppend(totalDelta: const Offset(-80, 10)),
      isTrue,
    );
    expect(
      shouldTriggerLeftSwipeAppend(totalDelta: const Offset(-40, 0)),
      isFalse,
    );
    expect(
      shouldTriggerLeftSwipeAppend(totalDelta: const Offset(-80, 120)),
      isFalse,
    );
  });

  test('chip opacity and scale interpolate toward armed state at threshold', () {
    expect(cap19LeftSwipeChipOpacity(0), kCap19LeftSwipeChipMinOpacity);
    expect(cap19LeftSwipeChipOpacity(1), 1.0);
    expect(cap19LeftSwipeChipScale(0), kCap19LeftSwipeChipMinScale);
    expect(cap19LeftSwipeChipScale(0.5), 1.0);
    expect(cap19LeftSwipeChipScale(1.0), kCap19LeftSwipeChipArmedScale);
    expect(cap19LeftSwipeDragIsArmed(-kCap19LeftSwipeDistanceThreshold), isTrue);
  });
}
