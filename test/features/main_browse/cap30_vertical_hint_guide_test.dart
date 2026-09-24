import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_guide.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_wiring.dart';
import 'package:waketok/features/main_browse/cap30_vertical_hint_guide.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

void main() {
  setUp(Cap19LeftSwipeGuideSession.resetForTest);
  tearDown(Cap19LeftSwipeGuideSession.resetForTest);

  testWidgets('T-30.3-W1 ready + step0 shows vertical hint and arms',
      (tester) async {
    final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 0;
    final cap19 = FakeCap19LeftSwipePreferences()
      ..leftSwipeAddEnabled = true
      ..leftSwipeGuideEnabled = true;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1'],
          availabilityById:
              FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
        ),
        cap19LeftSwipePreferences: cap19,
        cap30FirstLaunchGuidePreferences: cap30,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap30VerticalHintGuide')), findsOneWidget);
    expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);

    final container = tester.element(find.byType(Cap30VerticalHintGuideHost));
    final containerRef = ProviderScope.containerOf(container);
    final orch = containerRef.read(cap30FirstLaunchGuideOrchestratorProvider);
    expect(orch.chainArmedThisLaunch, isTrue);
    expect(orch.diskStep, 1);
    expect(cap30.step, 1);
  });

  testWidgets('T-30.3-W2 2.5s ends hint and advances to createPoolTip state',
      (tester) async {
    final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 0;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1'],
          availabilityById:
              FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
        ),
        cap30FirstLaunchGuidePreferences: cap30,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cap30VerticalHintGuide')), findsOneWidget);

    await tester.pump(kCap30GuideStepDuration);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
    final container = tester.element(find.byType(Cap30VerticalHintGuideHost));
    final orch = ProviderScope.containerOf(container)
        .read(cap30FirstLaunchGuideOrchestratorProvider);
    expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
    expect(orch.diskStep, 2);
  });

  testWidgets('T-30.3-W3 feed index change early-ends vertical hint',
      (tester) async {
    final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 0;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1', 'a2'],
          availabilityById:
              FakeAssetSourceRepository.deviceLocalForIds(const ['a1', 'a2']),
        ),
        cap30FirstLaunchGuidePreferences: cap30,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cap30VerticalHintGuide')), findsOneWidget);

    final container = tester.element(find.byType(Cap30VerticalHintGuideHost));
    final ref = ProviderScope.containerOf(container);
    ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
    final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
    expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
    expect(orch.diskStep, 2);
  });

  testWidgets('T-30.3-W4 step3 never shows vertical hint', (tester) async {
    final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 3;
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: FakeAssetSourceRepository(
          allIds: const ['a1'],
          availabilityById:
              FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
        ),
        cap30FirstLaunchGuidePreferences: cap30,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
  });

  testWidgets(
    'T-30.3-W5a disk3 allows Cap19 tip (positive D6 path)',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 3;
      final cap19 = FakeCap19LeftSwipePreferences()
        ..leftSwipeAddEnabled = true
        ..leftSwipeGuideEnabled = true;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap19LeftSwipePreferences: cap19,
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsOneWidget);
    },
  );

  testWidgets(
    'T-30.3-W5b armed / disk1 blocks Cap19 tip (negative D6 path)',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 0;
      final cap19 = FakeCap19LeftSwipePreferences()
        ..leftSwipeAddEnabled = true
        ..leftSwipeGuideEnabled = true;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap19LeftSwipePreferences: cap19,
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsOneWidget);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
    },
  );

  testWidgets(
    'T-30.3-W6 same orchestrator instance for Host arm and Cap19 D6',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 0;
      final cap19 = FakeCap19LeftSwipePreferences()
        ..leftSwipeAddEnabled = true
        ..leftSwipeGuideEnabled = true;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap19LeftSwipePreferences: cap19,
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await tester.pumpAndSettle();

      final hintEl = tester.element(find.byType(Cap30VerticalHintGuideHost));
      final cap19El = tester.element(find.byType(Cap19LeftSwipeGuideHost));
      final orchFromHint = ProviderScope.containerOf(hintEl)
          .read(cap30FirstLaunchGuideOrchestratorProvider);
      final orchFromCap19 = ProviderScope.containerOf(cap19El)
          .read(cap30FirstLaunchGuideOrchestratorProvider);
      expect(identical(orchFromHint, orchFromCap19), isTrue);
      expect(orchFromHint.chainArmedThisLaunch, isTrue);
      expect(orchFromCap19.shouldBlockLeftSwipeGuide, isTrue);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
    },
  );
}
