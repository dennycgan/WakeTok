import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

FakeCap19LeftSwipePreferences _cap19TipsOn() => FakeCap19LeftSwipePreferences()
  ..leftSwipeAddEnabled = true
  ..leftSwipeGuideEnabled = true;

FakeAssetSourceRepository _oneAsset() => FakeAssetSourceRepository(
      allIds: const ['a1'],
      availabilityById:
          FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
    );

/// D6: Cap 19 tip must never share a frame with `<1>` or `<2>`.
void _expectNoCap19Stack(WidgetTester tester) {
  final hasVertical =
      tester.any(find.byKey(const Key('cap30VerticalHintGuide')));
  final hasCreate = tester.any(find.byKey(const Key('cap30CreatePoolTip')));
  final hasCap19 = tester.any(find.byKey(const Key('cap19LeftSwipeGuide')));
  expect(
    hasCap19 && hasVertical,
    isFalse,
    reason: 'Cap19 must not share a frame with vertical hint',
  );
  expect(
    hasCap19 && hasCreate,
    isFalse,
    reason: 'Cap19 must not share a frame with Create Pool tip',
  );
}

/// Walk frames after a coarse duration jump; assert no Cap19 stack each frame.
Future<void> _pumpTransitionFrames(
  WidgetTester tester, {
  required bool Function() done,
  int maxFrames = 30,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump();
    _expectNoCap19Stack(tester);
    if (done()) {
      return;
    }
  }
  fail('transition did not complete within $maxFrames frames');
}

void main() {
  setUp(Cap19LeftSwipeGuideSession.resetForTest);
  tearDown(Cap19LeftSwipeGuideSession.resetForTest);

  testWidgets(
    'T-30.5-W1 full chain never stacks Cap19; per-frame at both boundaries',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 0;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: _oneAsset(),
          cap19LeftSwipePreferences: _cap19TipsOn(),
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsOneWidget);
      _expectNoCap19Stack(tester);

      // Coarse advance to <1> timer end; walk frames into <2>.
      await tester.pump(kCap30VerticalHintGuideDuration);
      await _pumpTransitionFrames(
        tester,
        done: () {
          if (!tester.any(find.byKey(const Key('cap30CreatePoolTip')))) {
            return false;
          }
          expect(
            find.byKey(const Key('cap30VerticalHintGuide')),
            findsNothing,
          );
          return true;
        },
      );

      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      _expectNoCap19Stack(tester);

      // Coarse advance to <2> timer end; walk frames until tip gone.
      await tester.pump(kCap30CreatePoolTipDuration);
      await _pumpTransitionFrames(
        tester,
        done: () => !tester.any(find.byKey(const Key('cap30CreatePoolTip'))),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
      expect(find.byKey(const Key('cap30CreatePoolTip')), findsNothing);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsOneWidget);
      expect(cap30.step, 3);
    },
  );

  testWidgets(
    'T-30.5-W2 disk2 cold start blocks Cap19 until create tip ends',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 2;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: _oneAsset(),
          cap19LeftSwipePreferences: _cap19TipsOn(),
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      _expectNoCap19Stack(tester);

      await tester.pump(kCap30CreatePoolTipDuration);
      await _pumpTransitionFrames(
        tester,
        done: () => !tester.any(find.byKey(const Key('cap30CreatePoolTip'))),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsOneWidget);
    },
  );

  testWidgets(
    'T-30.5-W3 disk1 cold start blocks Cap19 during vertical replay',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 1;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: _oneAsset(),
          cap19LeftSwipePreferences: _cap19TipsOn(),
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsOneWidget);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
      _expectNoCap19Stack(tester);
    },
  );

  testWidgets(
    'T-30.5-W4 disk3 with Cap19 tip Settings on shows Cap19',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 3;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: _oneAsset(),
          cap19LeftSwipePreferences: _cap19TipsOn(),
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
      expect(find.byKey(const Key('cap30CreatePoolTip')), findsNothing);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsOneWidget);
    },
  );

  testWidgets(
    'T-30.5-W5 disk3 with Cap19 tip Settings off shows no Cap19',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 3;
      final cap19 = FakeCap19LeftSwipePreferences()
        ..leftSwipeAddEnabled = true
        ..leftSwipeGuideEnabled = false;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: _oneAsset(),
          cap19LeftSwipePreferences: cap19,
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
    },
  );
}
