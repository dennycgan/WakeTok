import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_guide.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/cap30_create_pool_tip.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_orchestrator.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_wiring.dart';
import 'package:waketok/features/main_browse/cap30_vertical_hint_guide.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

bool _rectsOverlap(Rect a, Rect b) => a.overlaps(b);

Rect _rectOf(WidgetTester tester, Finder finder) {
  return tester.getRect(finder);
}

/// Outward caret contract: above bubble, air gap to bubble top, clear of Create.
Future<void> _pumpTipSettled(WidgetTester tester) async {
  await tester.pumpAndSettle();
  // Laid width → arrow X is post-frame; one extra settle covers EN/zh.
  await tester.pump();
  await tester.pumpAndSettle();
}

void _expectOutwardCaretAim({
  required Rect arrow,
  required Rect tip,
  required Rect create,
}) {
  expect(arrow.top, lessThan(tip.top - 0.5), reason: 'caret outside bubble');
  expect(
    tip.top - arrow.bottom,
    closeTo(kCap30CreatePoolTipCaretBubbleGap, 1.0),
    reason: 'air gap between caret base and bubble top',
  );
  expect(
    arrow.top,
    greaterThanOrEqualTo(create.bottom - 0.5),
    reason: 'caret must not intrude Create',
  );
  expect(arrow.center.dx, greaterThanOrEqualTo(create.left - 1.0));
  expect(arrow.center.dx, lessThanOrEqualTo(create.right + 1.0));
  // Absolute Create center (not tip center); allow 2px measure slack.
  expect((arrow.center.dx - create.center.dx).abs(), lessThanOrEqualTo(2.0));
}

void main() {
  setUp(Cap19LeftSwipeGuideSession.resetForTest);
  tearDown(Cap19LeftSwipeGuideSession.resetForTest);

  testWidgets(
    'T-30.4-W1 disk2 cold start shows tip via Vertical Host sync path',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 2;
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

      // Full shell: sole sync owner must stay mounted while tip paints.
      expect(find.byType(Cap30VerticalHintGuideHost), findsOneWidget);
      expect(find.byType(Cap30CreatePoolTipHost), findsOneWidget);
      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);

      final container = tester.element(find.byType(Cap30VerticalHintGuideHost));
      final orch = ProviderScope.containerOf(container)
          .read(cap30FirstLaunchGuideOrchestratorProvider);
      expect(orch.diskStep, 2);
      expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
      expect(cap30.step, 2);
    },
  );

  testWidgets(
    'T-30.4-W2 chain from step0 shows tip widget after vertical duration',
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

      await tester.pump(kCap30VerticalHintGuideDuration);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      final container = tester.element(find.byType(Cap30CreatePoolTipHost));
      final orch = ProviderScope.containerOf(container)
          .read(cap30FirstLaunchGuideOrchestratorProvider);
      expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
      expect(orch.diskStep, 2);
    },
  );

  testWidgets(
    'T-30.4-W3 tip duration completes chain and unblocks Cap19 tip',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 2;
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
      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);

      await tester.pump(kCap30CreatePoolTipDuration);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap30CreatePoolTip')), findsNothing);
      final container = tester.element(find.byType(Cap30VerticalHintGuideHost));
      final orch = ProviderScope.containerOf(container)
          .read(cap30FirstLaunchGuideOrchestratorProvider);
      expect(orch.diskStep, 3);
      expect(orch.activeChrome, Cap30GuideChromeKind.none);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsOneWidget);
    },
  );

  testWidgets(
    'T-30.4-W4 Limited tip does not overlap helper BuiltIn or Saved',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 2;
      await tester.pumpWidget(
        permissionUiHarness(
          repo:
              ControllablePhotosAuthorizationRepository(PhotosAccess.limited),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await _pumpTipSettled(tester);

      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseCreatePool')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseCreatePoolRequiresFullAccess')),
        findsOneWidget,
      );

      final tip = _rectOf(tester, find.byKey(const Key('cap30CreatePoolTip')));
      final helper = _rectOf(
        tester,
        find.byKey(const Key('mainBrowseCreatePoolRequiresFullAccess')),
      );
      final create =
          _rectOf(tester, find.byKey(const Key('mainBrowseCreatePool')));
      final builtIn =
          _rectOf(tester, find.byKey(const Key('mainBrowseBuiltInMenu')));
      final saved =
          _rectOf(tester, find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      final arrow =
          _rectOf(tester, find.byKey(const Key('cap30CreatePoolTipArrow')));

      expect(_rectsOverlap(tip, helper), isFalse);
      expect(_rectsOverlap(tip, builtIn), isFalse);
      expect(_rectsOverlap(tip, saved), isFalse);
      expect(_rectsOverlap(arrow, helper), isFalse);
      expect(tip.top >= helper.bottom - 1.0, isTrue);
      expect(
        arrow.top,
        greaterThanOrEqualTo(helper.bottom - 0.5),
        reason: 'caret must not cover Limited helper',
      );
      _expectOutwardCaretAim(arrow: arrow, tip: tip, create: create);
    },
  );

  testWidgets(
    'T-30.4-W5 Full tip below Create right-aligned; no overlap chrome',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 2;
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
      await _pumpTipSettled(tester);

      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      expect(
        find.byKey(const Key('mainBrowseCreatePoolRequiresFullAccess')),
        findsNothing,
      );

      final tip = _rectOf(tester, find.byKey(const Key('cap30CreatePoolTip')));
      final create =
          _rectOf(tester, find.byKey(const Key('mainBrowseCreatePool')));
      final builtIn =
          _rectOf(tester, find.byKey(const Key('mainBrowseBuiltInMenu')));
      final saved =
          _rectOf(tester, find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      final arrow =
          _rectOf(tester, find.byKey(const Key('cap30CreatePoolTipArrow')));
      expect(_rectsOverlap(tip, create), isFalse);
      expect(_rectsOverlap(arrow, create), isFalse);
      expect(tip.top >= create.bottom - 1.0, isTrue);
      expect((tip.right - create.right).abs(), lessThanOrEqualTo(1.0));
      expect(_rectsOverlap(tip, builtIn), isFalse);
      expect(_rectsOverlap(tip, saved), isFalse);
      _expectOutwardCaretAim(arrow: arrow, tip: tip, create: create);
    },
  );

  testWidgets(
    'T-30.4-W5n narrow 390 zh tip right-aligned under Create; outward caret',
    (tester) async {
      // iPhone 13 Pro logical ~390×844 @3x — catches fixed-width left-shift
      // landing under Built-in (device bug that default 800-wide miss).
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 2;
      await tester.pumpWidget(
        permissionUiHarness(
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hans',
          ),
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await _pumpTipSettled(tester);

      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);

      final tip = _rectOf(tester, find.byKey(const Key('cap30CreatePoolTip')));
      final create =
          _rectOf(tester, find.byKey(const Key('mainBrowseCreatePool')));
      final builtIn =
          _rectOf(tester, find.byKey(const Key('mainBrowseBuiltInMenu')));
      final saved =
          _rectOf(tester, find.byKey(const Key('mainBrowseSavedPoolsMenu')));
      final arrow =
          _rectOf(tester, find.byKey(const Key('cap30CreatePoolTipArrow')));

      expect(_rectsOverlap(tip, create), isFalse);
      expect(_rectsOverlap(arrow, create), isFalse);
      expect(tip.top >= create.bottom - 1.0, isTrue);
      expect((tip.right - create.right).abs(), lessThanOrEqualTo(1.0));
      // Tip must sit with Create on the right half — not under Built-in.
      expect(tip.center.dx, greaterThan(builtIn.center.dx));
      expect(_rectsOverlap(tip, builtIn), isFalse);
      expect(_rectsOverlap(tip, saved), isFalse);
      expect(tip.width, lessThanOrEqualTo(kCap30CreatePoolTipMaxWidth + 0.5));
      _expectOutwardCaretAim(arrow: arrow, tip: tip, create: create);
    },
  );

  testWidgets(
    'T-30.4-W5n-en narrow 390 EN tip; laid width then absolute Create aim',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 2;
      await tester.pumpWidget(
        permissionUiHarness(
          locale: const Locale('en'),
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: FakeAssetSourceRepository(
            allIds: const ['a1'],
            availabilityById:
                FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
          ),
          cap30FirstLaunchGuidePreferences: cap30,
        ),
      );
      await _pumpTipSettled(tester);

      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      final tip = _rectOf(tester, find.byKey(const Key('cap30CreatePoolTip')));
      final create =
          _rectOf(tester, find.byKey(const Key('mainBrowseCreatePool')));
      final arrow =
          _rectOf(tester, find.byKey(const Key('cap30CreatePoolTipArrow')));
      expect((tip.right - create.right).abs(), lessThanOrEqualTo(1.0));
      expect(_rectsOverlap(tip, create), isFalse);
      _expectOutwardCaretAim(arrow: arrow, tip: tip, create: create);
    },
  );

  testWidgets('T-30.4-W6 step3 never shows create pool tip', (tester) async {
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
    expect(find.byKey(const Key('cap30CreatePoolTip')), findsNothing);
  });

  testWidgets(
    'T-30.4-W7 feed index change does not early-end create pool tip',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 2;
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
      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);

      final container = tester.element(find.byType(Cap30CreatePoolTipHost));
      final ref = ProviderScope.containerOf(container);
      ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(1);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      final orch = ref.read(cap30FirstLaunchGuideOrchestratorProvider);
      expect(orch.diskStep, 2);
      expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
    },
  );

  test('T-30.4-W8 concurrent syncCap30BrowseReady does not double-advance',
      () async {
    Future<void> assertOnce({required int startStep}) async {
      final prefs = FakeCap30FirstLaunchGuidePreferences()..step = startStep;
      final orch = Cap30FirstLaunchGuideOrchestrator(prefs);
      var bumps = 0;
      await Future.wait([
        syncCap30BrowseReady(
          orch: orch,
          bumpEpoch: () => bumps++,
          ready: true,
        ),
        syncCap30BrowseReady(
          orch: orch,
          bumpEpoch: () => bumps++,
          ready: true,
        ),
      ]);
      if (startStep == 2) {
        expect(orch.diskStep, 2);
        expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
      } else {
        expect(orch.diskStep, 1);
        expect(orch.activeChrome, Cap30GuideChromeKind.verticalHint);
      }
      expect(bumps, 1);
    }

    await assertOnce(startStep: 2);
    await assertOnce(startStep: 0);
  });
}
