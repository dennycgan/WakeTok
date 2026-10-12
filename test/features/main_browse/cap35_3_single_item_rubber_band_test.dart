import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/onboarding/cap30_first_launch_guide_logic.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/cap30_first_launch_guide_wiring.dart';
import 'package:waketok/features/main_browse/cap30_vertical_hint_guide.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../onboarding/fake_cap30_first_launch_guide_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

final _iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

FakeAssetSourceRepository _sources(List<String> ids) {
  return FakeAssetSourceRepository(
    allIds: ids,
    availabilityById: FakeAssetSourceRepository.deviceLocalForIds(ids),
  );
}

Future<void> _pumpFeedFor(
  WidgetTester tester,
  List<String> ids, {
  FakeCap30FirstLaunchGuidePreferences? cap30,
}) async {
  await tester.pumpWidget(
    permissionUiHarness(
      repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
      assetSources: _sources(ids),
      cap30FirstLaunchGuidePreferences: cap30,
    ),
  );
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await ensureShellMediaCoverVisible(tester);
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(VerticalMediaFeed)),
  );
}

PageView _pageView(WidgetTester tester) {
  return tester.widget<PageView>(find.byType(PageView));
}

ScrollPosition _position(WidgetTester tester) {
  return tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(PageView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;
}

/// Drags in small steps with identical timestamps, so release velocity is
/// zero and settle depends on position only. Leaves the pointer down.
Future<TestGesture> _holdDrag(WidgetTester tester, double dy) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(PageView)),
  );
  const steps = 8;
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(Offset(0, dy / steps));
    await tester.pump(const Duration(milliseconds: 16));
  }
  return gesture;
}

/// Frames until the bounce / snap ballistic ends, without pumpAndSettle
/// (other timers in the shell keep scheduling frames).
Future<void> _pumpSettle(WidgetTester tester) async {
  for (var i = 0; i < 90; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets(
    'W-35.3-1 single item: slow drag down rubber-bands and returns to 0',
    (tester) async {
      await _pumpFeedFor(tester, const ['a1']);
      final container = _container(tester);
      expect(_pageView(tester).physics, isA<AlwaysScrollableScrollPhysics>());
      expect(_position(tester).pixels, 0);

      final gesture = await _holdDrag(tester, 200);
      expect(
        _position(tester).pixels,
        lessThan(0),
        reason: 'single item must accept a downward drag (leading overscroll)',
      );

      await gesture.up();
      await _pumpSettle(tester);
      expect(_position(tester).pixels, 0);
      expect(container.read(mainBrowseFeedIndexProvider), 0);
    },
    variant: _iOS,
  );

  testWidgets(
    'W-35.3-2 single item: slow drag up rubber-bands without a new round',
    (tester) async {
      await _pumpFeedFor(tester, const ['a1']);
      final container = _container(tester);
      final before = container.read(browseSessionProvider).requireValue;

      final gesture = await _holdDrag(tester, -200);
      expect(
        _position(tester).pixels,
        greaterThan(0),
        reason: 'single item must accept an upward drag (trailing overscroll)',
      );

      await gesture.up();
      await _pumpSettle(tester);
      expect(_position(tester).pixels, 0);
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      final after = container.read(browseSessionProvider).requireValue;
      expect(after.roundEpoch, before.roundEpoch);
      expect(after.orderedAssetIds, before.orderedAssetIds);
      expect(
        find.byKey(const Key('mainBrowseNewRoundToast'), skipOffstage: false),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('mainBrowseEndlessRoundPlaceholder'),
          skipOffstage: false,
        ),
        findsNothing,
      );
    },
    variant: _iOS,
  );

  testWidgets('W-35.3-3 single item: flings up and down both return to 0', (
    tester,
  ) async {
    await _pumpFeedFor(tester, const ['a1']);
    final container = _container(tester);

    await tester.fling(find.byType(PageView), const Offset(0, -300), 2000);
    await _pumpSettle(tester);
    expect(_position(tester).pixels, 0);
    expect(container.read(mainBrowseFeedIndexProvider), 0);

    await tester.fling(find.byType(PageView), const Offset(0, 300), 2000);
    await _pumpSettle(tester);
    expect(_position(tester).pixels, 0);
    expect(container.read(mainBrowseFeedIndexProvider), 0);
  }, variant: _iOS);

  testWidgets(
    'W-35.3-4 single item: settled stays true through the rubber band',
    (tester) async {
      await _pumpFeedFor(tester, const ['a1']);
      final container = _container(tester);
      expect(container.read(mainBrowseVerticalFeedSettledProvider), isTrue);

      for (final dy in const [200.0, -200.0]) {
        final gesture = await _holdDrag(tester, dy);
        expect(_position(tester).pixels, isNot(0));
        expect(
          container.read(mainBrowseVerticalFeedSettledProvider),
          isTrue,
          reason:
              'PageController.page clamps overscroll to page 0, so chrome '
              'stays visible, same as a multi-item first-item pull-down',
        );

        await gesture.up();
        await _pumpSettle(tester);
        expect(_position(tester).pixels, 0);
        expect(container.read(mainBrowseVerticalFeedSettledProvider), isTrue);
      }
    },
    variant: _iOS,
  );

  testWidgets(
    'W-35.3-5 single item magnified still: physics locked, drag does not move',
    (tester) async {
      await _pumpFeedFor(tester, const ['a1']);
      final container = _container(tester);

      container
          .read(browseMagnificationProvider.notifier)
          .setStillMagnified(true);
      await tester.pump();
      expect(_pageView(tester).physics, isA<NeverScrollableScrollPhysics>());

      final gesture = await _holdDrag(tester, 200);
      expect(_position(tester).pixels, 0);
      await gesture.up();
      await _pumpSettle(tester);
      expect(_position(tester).pixels, 0);
      expect(container.read(mainBrowseFeedIndexProvider), 0);
    },
    variant: _iOS,
  );

  testWidgets('W-35.3-6 five items: AlwaysScrollable keeps page snapping', (
    tester,
  ) async {
    await _pumpFeedFor(tester, const ['a1', 'a2', 'a3', 'a4', 'a5']);
    final container = _container(tester);
    expect(_pageView(tester).physics, isA<AlwaysScrollableScrollPhysics>());
    final extent = _position(tester).viewportDimension;

    var gesture = await _holdDrag(tester, -extent * 0.2);
    await gesture.up();
    await _pumpSettle(tester);
    expect(_position(tester).pixels, 0, reason: '20% drag returns');
    expect(container.read(mainBrowseFeedIndexProvider), 0);

    gesture = await _holdDrag(tester, -extent * 0.6);
    await gesture.up();
    await _pumpSettle(tester);
    expect(_position(tester).pixels, extent, reason: '60% drag snaps');
    expect(container.read(mainBrowseFeedIndexProvider), 1);
  }, variant: _iOS);

  testWidgets(
    'W-35.3-7 Cap 30 step 0 single item: rubber band keeps <1> until timeout',
    (tester) async {
      final cap30 = FakeCap30FirstLaunchGuidePreferences()..step = 0;
      await _pumpFeedFor(tester, const ['a1'], cap30: cap30);
      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsOneWidget);

      final orch = ProviderScope.containerOf(
        tester.element(find.byType(Cap30VerticalHintGuideHost)),
      ).read(cap30FirstLaunchGuideOrchestratorProvider);
      expect(orch.diskStep, 1);

      final gesture = await _holdDrag(tester, -200);
      await gesture.up();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        find.byKey(const Key('cap30VerticalHintGuide')),
        findsOneWidget,
        reason: 'no feed index change: <1> must not end early',
      );
      expect(orch.diskStep, 1);

      await tester.pump(kCap30VerticalHintGuideDuration);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap30VerticalHintGuide')), findsNothing);
      expect(find.byKey(const Key('cap30CreatePoolTip')), findsOneWidget);
      expect(orch.activeChrome, Cap30GuideChromeKind.createPoolTip);
      expect(orch.diskStep, 2);
    },
    variant: _iOS,
  );

  testWidgets('W-35.3-8 soft delete 2 → 1 keeps the same ScrollPosition', (
    tester,
  ) async {
    await _pumpFeedFor(tester, const ['a1', 'a2']);
    final container = _container(tester);
    final keyBefore = _pageView(tester).key;
    final positionBefore = _position(tester);
    expect(_pageView(tester).physics, isA<AlwaysScrollableScrollPhysics>());

    final view = container.read(browseSessionProvider).requireValue;
    final landing = container
        .read(browseSessionProvider.notifier)
        .removeAssetAndLand(assetId: view.orderedAssetIds.first, feedIndex: 0);
    container.read(mainBrowseFeedIndexProvider.notifier).setIndex(landing!);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      container.read(browseSessionProvider).requireValue.orderedAssetIds,
      hasLength(1),
    );
    expect(_pageView(tester).key, keyBefore);
    expect(_pageView(tester).physics, isA<AlwaysScrollableScrollPhysics>());
    expect(
      identical(_position(tester), positionBefore),
      isTrue,
      reason: 'same physics type and key: no ScrollPosition rebuild',
    );

    final gesture = await _holdDrag(tester, 200);
    expect(_position(tester).pixels, lessThan(0));
    await gesture.up();
    await _pumpSettle(tester);
    expect(_position(tester).pixels, 0);

    // Control: a physics type change does rebuild the position, so the
    // identity check above can fail.
    container
        .read(browseMagnificationProvider.notifier)
        .setStillMagnified(true);
    await tester.pump();
    expect(identical(_position(tester), positionBefore), isFalse);
  }, variant: _iOS);
}
