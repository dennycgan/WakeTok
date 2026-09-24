import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_orchestrator.dart';

import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';

void main() {
  group('clampCap30GuideStep', () {
    test('clamps negatives to 0 and above-complete to complete', () {
      expect(clampCap30GuideStep(-5), 0);
      expect(clampCap30GuideStep(0), 0);
      expect(clampCap30GuideStep(2), 2);
      expect(clampCap30GuideStep(3), 3);
      expect(clampCap30GuideStep(99), kCap30GuideStepComplete);
    });
  });

  group('cap30GuideChromeDuration', () {
    test('each chrome maps to its own step constant', () {
      expect(
        cap30GuideChromeDuration(Cap30GuideChromeKind.verticalHint),
        kCap30VerticalHintGuideDuration,
      );
      expect(
        cap30GuideChromeDuration(Cap30GuideChromeKind.createPoolTip),
        kCap30CreatePoolTipDuration,
      );
      expect(
        cap30GuideChromeDuration(Cap30GuideChromeKind.none),
        Duration.zero,
      );
      expect(kCap30VerticalHintGuideDuration, const Duration(milliseconds: 2000));
      expect(kCap30CreatePoolTipDuration, const Duration(milliseconds: 3500));
    });
  });

  group('shouldBlockLeftSwipeGuideForCap30 G1–G8', () {
    test('T-30.2-G1 disk0 armed false → no block', () {
      expect(
        shouldBlockLeftSwipeGuideForCap30(
          diskStep: 0,
          chainArmedThisLaunch: false,
        ),
        isFalse,
      );
    });

    test('T-30.2-G2 disk0 armed true → block', () {
      expect(
        shouldBlockLeftSwipeGuideForCap30(
          diskStep: 0,
          chainArmedThisLaunch: true,
        ),
        isTrue,
      );
    });

    test('T-30.2-G3 disk1 armed false → block', () {
      expect(
        shouldBlockLeftSwipeGuideForCap30(
          diskStep: 1,
          chainArmedThisLaunch: false,
        ),
        isTrue,
      );
    });

    test('T-30.2-G4 disk1 armed true → block', () {
      expect(
        shouldBlockLeftSwipeGuideForCap30(
          diskStep: 1,
          chainArmedThisLaunch: true,
        ),
        isTrue,
      );
    });

    test('T-30.2-G5 disk2 armed false → block', () {
      expect(
        shouldBlockLeftSwipeGuideForCap30(
          diskStep: 2,
          chainArmedThisLaunch: false,
        ),
        isTrue,
      );
    });

    test('T-30.2-G6 disk2 armed true → block', () {
      expect(
        shouldBlockLeftSwipeGuideForCap30(
          diskStep: 2,
          chainArmedThisLaunch: true,
        ),
        isTrue,
      );
    });

    test('T-30.2-G7 disk3 armed false → no block', () {
      expect(
        shouldBlockLeftSwipeGuideForCap30(
          diskStep: 3,
          chainArmedThisLaunch: false,
        ),
        isFalse,
      );
    });

    test('T-30.2-G8 disk3 armed true → no block', () {
      expect(
        shouldBlockLeftSwipeGuideForCap30(
          diskStep: 3,
          chainArmedThisLaunch: true,
        ),
        isFalse,
      );
    });
  });

  group('Cap30FirstLaunchGuideOrchestrator', () {
    late FakeCap30FirstLaunchGuidePreferences prefs;
    late Cap30FirstLaunchGuideOrchestrator orch;

    setUp(() {
      prefs = FakeCap30FirstLaunchGuidePreferences();
      orch = Cap30FirstLaunchGuideOrchestrator(prefs);
    });

    test('T-30.2-O1 not ready → no disk write, not armed', () async {
      await orch.hydrate();
      expect(orch.diskStep, 0);
      expect(orch.chainArmedThisLaunch, isFalse);
      expect(orch.activeChrome, Cap30GuideChromeKind.none);
      expect(prefs.step, 0);
    });

    test('T-30.2-O2 ready + step0 → begin <1>, disk1, armed', () async {
      await orch.hydrate();
      await orch.onBrowseItemReadyChanged(true);
      expect(orch.activeChrome, Cap30GuideChromeKind.verticalHint);
      expect(orch.diskStep, 1);
      expect(prefs.step, 1);
      expect(orch.chainArmedThisLaunch, isTrue);
      expect(orch.shouldBlockLeftSwipeGuide, isTrue);
    });

    test('T-30.2-O3 resume A: disk1 replays <1> and arms', () async {
      prefs.step = 1;
      await orch.hydrate();
      await orch.onBrowseItemReadyChanged(true);
      expect(orch.activeChrome, Cap30GuideChromeKind.verticalHint);
      expect(orch.diskStep, 1);
      expect(orch.chainArmedThisLaunch, isTrue);
    });

    test('T-30.2-O4 <1> display ended → <2> disk2', () async {
      await orch.hydrate();
      await orch.onBrowseItemReadyChanged(true);
      await orch.notifyStepDisplayEnded();
      expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
      expect(orch.diskStep, 2);
      expect(prefs.step, 2);
    });

    test('T-30.2-O5 <1> page change → <2>', () async {
      await orch.hydrate();
      await orch.onBrowseItemReadyChanged(true);
      await orch.notifyVerticalPageChanged();
      expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
      expect(orch.diskStep, 2);
    });

    test('T-30.2-O6 <2> end → disk3, no chrome', () async {
      prefs.step = 2;
      await orch.hydrate();
      await orch.onBrowseItemReadyChanged(true);
      expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
      await orch.notifyStepDisplayEnded();
      expect(orch.activeChrome, Cap30GuideChromeKind.none);
      expect(orch.diskStep, kCap30GuideStepComplete);
      expect(prefs.step, kCap30GuideStepComplete);
      expect(orch.shouldBlockLeftSwipeGuide, isFalse);
    });

    test('T-30.2-O7 step3 → no arm, no chrome', () async {
      prefs.step = 3;
      await orch.hydrate();
      await orch.onBrowseItemReadyChanged(true);
      expect(orch.activeChrome, Cap30GuideChromeKind.none);
      expect(orch.chainArmedThisLaunch, isFalse);
      expect(orch.shouldBlockLeftSwipeGuide, isFalse);
    });

    test('T-30.2-O8 kill mid-chain: new orch, arm not on disk', () async {
      prefs.step = 1;
      final first = Cap30FirstLaunchGuideOrchestrator(prefs);
      await first.hydrate();
      await first.onBrowseItemReadyChanged(true);
      expect(first.chainArmedThisLaunch, isTrue);

      final second = Cap30FirstLaunchGuideOrchestrator(prefs);
      expect(second.chainArmedThisLaunch, isFalse);
      await second.hydrate();
      expect(second.chainArmedThisLaunch, isFalse);
      await second.onBrowseItemReadyChanged(true);
      expect(second.activeChrome, Cap30GuideChromeKind.verticalHint);
      expect(second.chainArmedThisLaunch, isTrue);
      expect(prefs.step, 1);
    });
  });
}
