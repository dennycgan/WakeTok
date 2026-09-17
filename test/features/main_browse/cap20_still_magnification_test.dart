import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/waketok_album_constants.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_append_controller.dart';
import 'package:waketok/features/main_browse/magnification_reset_button.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/features/main_browse/magnification_surface.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../domain/library/fake_waketok_album_store.dart';
import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

const _wakeTokAlbumId = 'waketok-album-cap20';

Future<void> _pumpFeed(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  await ensureShellMediaCoverVisible(tester);
}

ProviderContainer _feedContainer(WidgetTester tester) {
  final element = tester.element(find.byType(VerticalMediaFeed));
  return ProviderScope.containerOf(element);
}

PageView _pageView(WidgetTester tester) {
  return tester.widget<PageView>(find.byType(PageView));
}

FakeAssetSourceRepository _sourcesWithWakeTokAlbum(List<String> allIds) {
  return FakeAssetSourceRepository(
    allIds: allIds,
    availabilityById: FakeAssetSourceRepository.deviceLocalForIds(allIds),
    extraSources: [
      AssetSource(
        kind: AssetSourceKind.album,
        id: _wakeTokAlbumId,
        displayName: waketokAlbumTitle,
        estimatedCount: 1,
        availability: AssetSourceAvailability.available,
        canAddContent: true,
      ),
    ],
  );
}

void main() {
  test('T-20.3-1 Overlay columnHeightFor is fixed MVP three rows', () {
    expect(
      MediaInfoOverlay.columnHeightFor(null),
      MediaInfoOverlay.rowHeight * MediaInfoOverlay.baseRowCount,
    );
    expect(
      MediaInfoOverlay.columnHeightFor(
        const PresentationOverlaySnapshot(
          assetIdentifier: 'a',
          locationLabel: 'Auckland',
        ),
      ),
      MediaInfoOverlay.rowHeight * MediaInfoOverlay.baseRowCount,
      reason: 'MVP overlay ignores locationLabel (half-sheet later)',
    );
  });

  test('T-20.6-1 kCap20MaxScale is owner-locked 4×', () {
    expect(kCap20MaxScale, 4.0);
    expect(kCap20MinScale, 1.0);
  });

  testWidgets('T-20.3-3 Reset button appears only while still magnified', (
    tester,
  ) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: waketokTheme(Brightness.dark),
              home: const Scaffold(
                body: MagnificationResetButton(overlaySnapshot: null),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('magnificationResetButton')), findsNothing);

    container.read(browseMagnificationProvider.notifier).setStillMagnified(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('magnificationResetButton')), findsOneWidget);
    final resetSize = tester.getSize(find.byKey(const Key('magnificationResetButton')));
    expect(
      resetSize.height,
      greaterThanOrEqualTo(kResetMinHitEdge),
      reason: 'Reset pill hit height must meet iOS 44pt minimum',
    );
    expect(
      resetSize.width,
      greaterThanOrEqualTo(kResetMinHitEdge),
      reason: 'Reset pill hit width must meet iOS 44pt minimum',
    );

    await tester.tap(find.byKey(const Key('magnificationResetButton')));
    await tester.pumpAndSettle();
    expect(container.read(browseStillMagnifiedProvider), isFalse);
    expect(find.byKey(const Key('magnificationResetButton')), findsNothing);
  });

  testWidgets(
    'T-20.3-4 magnified still sets PageView NeverScrollableScrollPhysics',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFeed(tester);
      expect(find.byType(PageView), findsOneWidget);

      final container = _feedContainer(tester);
      expect(
        _pageView(tester).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );

      container.read(browseMagnificationProvider.notifier).setStillMagnified(true);
      await tester.pump();
      expect(
        _pageView(tester).physics,
        isA<NeverScrollableScrollPhysics>(),
      );

      container.read(browseMagnificationProvider.notifier).forceFit();
      await tester.pump();
      expect(
        _pageView(tester).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );
    },
  );

  testWidgets(
    'T-20.3-5 magnified still vertical drag does not change feed index',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFeed(tester);

      final container = _feedContainer(tester);
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      // Control first: fit-state vertical drag must page (proves harness +
      // fit-state Listener/Transform does not steal PageView).
      await tester.drag(find.byType(PageView), const Offset(0, -280));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(mainBrowseFeedIndexProvider),
        1,
        reason: 'fit-state vertical drag must page before lock test',
      );

      // Return to index 0 for the magnified limb.
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      container.read(browseMagnificationProvider.notifier).setStillMagnified(true);
      await tester.pump();
      expect(
        _pageView(tester).physics,
        isA<NeverScrollableScrollPhysics>(),
      );

      await tester.drag(find.byType(PageView), const Offset(0, -280));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(mainBrowseFeedIndexProvider),
        0,
        reason: 'Decision 16: magnified still vertical drag must not page',
      );
    },
  );

  testWidgets(
    'T-20.3-6 leave Browse clears magnified lock so PageView physics unlock',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFeed(tester);

      final container = _feedContainer(tester);
      container.read(browseMagnificationProvider.notifier).setStillMagnified(true);
      await tester.pump();
      expect(
        _pageView(tester).physics,
        isA<NeverScrollableScrollPhysics>(),
      );

      // IndexedStack keeps VerticalMediaFeed mounted offstage — destination
      // listen must clear magnification and unlock physics.
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(browseStillMagnifiedProvider), isFalse);
      final pageViews = find.byType(PageView, skipOffstage: false);
      expect(
        pageViews,
        findsOneWidget,
        reason: 'Browse feed stays mounted under IndexedStack (offstage OK)',
      );
      final pageView = tester.widget<PageView>(pageViews);
      expect(
        pageView.physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
        reason: 'leave Browse must unlock PageView after clearing magnified',
      );
    },
  );

  testWidgets(
    'T-20.3-7 real two-finger pinch scales; photo L2 release stays persistent',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFeed(tester);

      final container = _feedContainer(tester);
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.still,
        reason: 'photo L2 (FeedDisplayLayer.full) arms persistent still mode',
      );
      expect(
        find.byKey(const Key('magnificationPointerHost')),
        findsOneWidget,
      );

      final surface = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(surface);

      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isFalse,
        reason: 'Plan A: 1st finger alone must not lock',
      );

      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isTrue,
        reason: '2nd finger must lock via stillPinchContact',
      );

      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();

      expect(
        container.read(magnificationMatrixProvider).scale,
        greaterThan(1.5),
      );

      Transform readTransform() {
        return tester.widget<Transform>(
          find.byKey(const Key('stillMagnificationTransform')),
        );
      }

      final scaleAfterSpread = readTransform().transform.getMaxScaleOnAxis();
      expect(scaleAfterSpread, greaterThan(1.5));

      await g1.moveBy(const Offset(20, 0));
      await g2.moveBy(const Offset(-20, 0));
      await tester.pump();
      final scaleAfterPinchIn = readTransform().transform.getMaxScaleOnAxis();
      expect(scaleAfterPinchIn, lessThan(scaleAfterSpread));
      expect(scaleAfterPinchIn, greaterThan(1.0 + kCap20MagnifiedEpsilon));

      await g1.up();
      await g2.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(browseStillMagnifiedProvider),
        isTrue,
        reason: 'photo L2 must stay magnified after release',
      );
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isFalse,
      );
      expect(
        container.read(magnificationMatrixProvider).scale,
        greaterThan(1.0 + kCap20MagnifiedEpsilon),
      );
      expect(find.byKey(const Key('magnificationResetButton')), findsOneWidget);
    },
  );

  testWidgets(
    'T-20.3-8 single-finger drag pages (no candidate lock round-trip)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFeed(tester);

      final container = _feedContainer(tester);
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      final surface = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(surface);

      // One finger down — must not lock; same finger continues into a page.
      final g = await tester.startGesture(center);
      await tester.pump();
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isFalse,
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isFalse,
        reason: 'Plan A: no single-finger candidate window',
      );

      await g.moveBy(const Offset(0, -280));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await g.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        container.read(mainBrowseFeedIndexProvider),
        1,
        reason: 'single-finger drag must page (index assertion, not physics)',
      );
    },
  );

  testWidgets(
    'T-20.3-9 unlocked→locked: 2nd finger brakes mid-scroll; settle stays',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFeed(tester);

      final container = _feedContainer(tester);
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      final feedState = tester.state<VerticalMediaFeedState>(
        find.byType(VerticalMediaFeed),
      );
      final pageController = feedState.debugPageController;
      expect(pageController, isNotNull);

      final surface = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(surface);

      // Finger 1: past drag slop so PageView is actually tracking, but not
      // far enough to commit the next page before finger 2 arrives.
      final g1 = await tester.startGesture(center);
      await tester.pump();
      await g1.moveBy(const Offset(0, -40));
      await tester.pump();
      final pageAfterSlop = pageController!.page;
      expect(pageAfterSlop, isNotNull);
      expect(
        pageAfterSlop!,
        greaterThan(0.01),
        reason: 'pre-2nd-finger move must engage real PageView scroll',
      );
      expect(
        pageAfterSlop,
        lessThan(0.45),
        reason: 'stay below mid-page so settle-to-next is not already armed',
      );
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      // Finger 2: stagger like T-20.3-7 → Plan A lock.
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(48, 0));
      await tester.pump();
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isTrue,
      );
      final indexAtLock = container.read(mainBrowseFeedIndexProvider);
      expect(indexAtLock, 0);

      // Large further drag while locked — index must not advance.
      await g1.moveBy(const Offset(0, -280));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(mainBrowseFeedIndexProvider),
        indexAtLock,
        reason: 'after 2nd finger, further drag must not change feed index',
      );

      await g1.up();
      await g2.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));

      expect(
        container.read(mainBrowseFeedIndexProvider),
        0,
        reason:
            'early 1st-finger pixels must not fling/settle into the next page '
            'after 2nd-finger brake + release',
      );
    },
  );

  testWidgets(
    'T-20.3-10 fit-state Cap19 left-swipe still arms and appends with pinch host',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final mutations = FakeAlbumMutationRepository();
      final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _sourcesWithWakeTokAlbum(const ['a1', 'a2']),
          albumMutations: mutations,
          wakeTokAlbumStore: albumStore,
        ),
      );
      await _pumpFeed(tester);

      final container = _feedContainer(tester);
      expect(
        find.byKey(const Key('magnificationPointerHost')),
        findsOneWidget,
        reason: 'PageView-outer pinch host must be present',
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(
        container.read(cap19LeftSwipeArmingProvider),
        isTrue,
        reason: 'fit + actionable still must arm left-swipe',
      );
      expect(
        find.byKey(const Key('cap19LeftSwipeGesture')),
        findsOneWidget,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await gesture.moveBy(const Offset(-100, 4));
      await gesture.up();
      await tester.pump();
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(
        mutations.addCalls,
        1,
        reason:
            'pinch host outside PageView must not block Cap19 left-swipe append',
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      await tester.pump(kCap19BrowseToastDuration);
      resetCap19BrowseToastForTest();
    },
  );

  testWidgets(
    'T-20.3-11 vertical page with pinch host present (fit, single finger)',
    (tester) async {
      // Explicit regression guard for "Listener parent of PageView eats
      // single-finger scroll". Behaviorally equivalent to T-20.3-8; kept as
      // its own ID so the host-outside-PageView risk stays visible in the
      // Cap 20.3 checklist.
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFeed(tester);

      final container = _feedContainer(tester);
      expect(find.byKey(const Key('magnificationPointerHost')), findsOneWidget);
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.still,
        reason: 'settled photo L2 arms persistent still host mode',
      );

      // Host must be an ancestor of PageView (outside scrollable child tree).
      final hostContext = tester.element(
        find.byKey(const Key('magnificationPointerHost')),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('magnificationPointerHost')),
          matching: find.byType(PageView),
        ),
        findsOneWidget,
      );
      expect(hostContext.findAncestorWidgetOfExactType<PageView>(), isNull);

      await tester.drag(find.byType(PageView), const Offset(0, -280));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(mainBrowseFeedIndexProvider), 1);
    },
  );

  Future<ProviderContainer> _pumpStillFeed(WidgetTester tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
      ),
    );
    await _pumpFeed(tester);
    return _feedContainer(tester);
  }

  Future<void> _pinchMagnify(WidgetTester tester) async {
    final host = find.byKey(const Key('magnificationPointerHost'));
    final center = tester.getCenter(host);
    final g1 = await tester.startGesture(center + const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final g2 = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    await g1.moveBy(const Offset(-70, 0));
    await g2.moveBy(const Offset(70, 0));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pump();
  }

  // Cap 20.5b uses wall-clock via [cap20DoubleTapNow]; WidgetTester.pump
  // does not advance DateTime.now — inject a fake clock for interval tests.
  var doubleTapClock = DateTime.utc(2026, 1, 1);

  void _installDoubleTapClock() {
    doubleTapClock = DateTime.utc(2026, 1, 1);
    cap20DoubleTapNow = () => doubleTapClock;
  }

  void _restoreDoubleTapClock() {
    cap20DoubleTapNow = DateTime.now;
  }

  void _advanceDoubleTapClock(Duration delta) {
    doubleTapClock = doubleTapClock.add(delta);
  }

  Future<void> _tapAt(
    WidgetTester tester,
    Offset global, {
    Duration press = const Duration(milliseconds: 40),
  }) async {
    final g = await tester.startGesture(global);
    _advanceDoubleTapClock(press);
    await tester.pump(press);
    await g.up();
    await tester.pump();
  }

  testWidgets('T-20.5b-1 magnified double-tap forceFits via same path as Reset', (
    tester,
  ) async {
    _installDoubleTapClock();
    addTearDown(_restoreDoubleTapClock);
    final container = await _pumpStillFeed(tester);
    await _pinchMagnify(tester);
    expect(container.read(browseStillMagnifiedProvider), isTrue);
    expect(container.read(magnificationMatrixProvider).scale, greaterThan(1.5));

    final center = tester.getCenter(
      find.byKey(const Key('magnificationPointerHost')),
    );
    await _tapAt(tester, center);
    _advanceDoubleTapClock(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));
    await _tapAt(tester, center);

    expect(container.read(browseStillMagnifiedProvider), isFalse);
    expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
  });

  testWidgets('T-20.5b-2 double-tap interval over 350ms does not forceFit', (
    tester,
  ) async {
    _installDoubleTapClock();
    addTearDown(_restoreDoubleTapClock);
    final container = await _pumpStillFeed(tester);
    await _pinchMagnify(tester);
    final center = tester.getCenter(
      find.byKey(const Key('magnificationPointerHost')),
    );
    await _tapAt(tester, center);
    final gap = kCap20DoubleTapMaxInterval + const Duration(milliseconds: 40);
    _advanceDoubleTapClock(gap);
    await tester.pump(gap);
    await _tapAt(tester, center);
    expect(container.read(browseStillMagnifiedProvider), isTrue);
    expect(container.read(magnificationMatrixProvider).scale, greaterThan(1.5));
  });

  testWidgets('T-20.5b-3 double-tap beyond 24px slop does not forceFit', (
    tester,
  ) async {
    _installDoubleTapClock();
    addTearDown(_restoreDoubleTapClock);
    final container = await _pumpStillFeed(tester);
    await _pinchMagnify(tester);
    final center = tester.getCenter(
      find.byKey(const Key('magnificationPointerHost')),
    );
    await _tapAt(tester, center);
    _advanceDoubleTapClock(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));
    await _tapAt(tester, center + const Offset(kCap20DoubleTapSlop + 8, 0));
    expect(container.read(browseStillMagnifiedProvider), isTrue);
  });

  testWidgets('T-20.5b-4 pan/pinch motion cancels double-tap candidate', (
    tester,
  ) async {
    _installDoubleTapClock();
    addTearDown(_restoreDoubleTapClock);
    final container = await _pumpStillFeed(tester);
    await _pinchMagnify(tester);
    final center = tester.getCenter(
      find.byKey(const Key('magnificationPointerHost')),
    );

    // First tap then pan (move beyond cancel slop) — candidate must die.
    await _tapAt(tester, center);
    _advanceDoubleTapClock(const Duration(milliseconds: 40));
    await tester.pump(const Duration(milliseconds: 40));
    final pan = await tester.startGesture(center);
    await tester.pump();
    await pan.moveBy(const Offset(40, 0));
    await tester.pump();
    await pan.up();
    await tester.pump();
    await _tapAt(tester, center);
    expect(
      container.read(browseStillMagnifiedProvider),
      isTrue,
      reason: 'tap after pan must not complete a stale double-tap',
    );

    // Expire the verifying tap's first-candidate before the pinch limb,
    // otherwise that tap + the next tap would complete a double-tap.
    _advanceDoubleTapClock(
      kCap20DoubleTapMaxInterval + const Duration(milliseconds: 40),
    );

    // Pinch clears candidate: first tap, then two-finger, then one tap.
    await _tapAt(tester, center);
    _advanceDoubleTapClock(const Duration(milliseconds: 40));
    await tester.pump(const Duration(milliseconds: 40));
    final g1 = await tester.startGesture(center + const Offset(-30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final g2 = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pump();
    await _tapAt(tester, center);
    expect(container.read(browseStillMagnifiedProvider), isTrue);
  });

  testWidgets(
    'T-20.5b-5 magnified pan starts without double-tap disambiguation delay',
    (tester) async {
      _installDoubleTapClock();
      addTearDown(_restoreDoubleTapClock);
      final container = await _pumpStillFeed(tester);
      await _pinchMagnify(tester);
      final before = container.read(magnificationMatrixProvider).translation;
      final center = tester.getCenter(
        find.byKey(const Key('magnificationPointerHost')),
      );

      final g = await tester.startGesture(center);
      await tester.pump(); // same frame family — no 300ms wait
      await g.moveBy(const Offset(30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final after = container.read(magnificationMatrixProvider).translation;
      await g.up();

      expect(
        (after - before).distance,
        greaterThan(5),
        reason: 'pan must apply within one 16ms pump after down+move '
            '(no GestureDetector double-tap disambiguation window)',
      );
      expect(container.read(browseStillMagnifiedProvider), isTrue);
    },
  );

  testWidgets('T-20.5b-6 Reset hit-test path forceFits without Host double-tap', (
    tester,
  ) async {
    _installDoubleTapClock();
    addTearDown(_restoreDoubleTapClock);
    final container = await _pumpStillFeed(tester);
    await _pinchMagnify(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('magnificationResetButton')), findsOneWidget);

    await tester.tap(find.byKey(const Key('magnificationResetButton')));
    await tester.pumpAndSettle();
    expect(container.read(browseStillMagnifiedProvider), isFalse);
    expect(find.byKey(const Key('magnificationResetButton')), findsNothing);
  });

  testWidgets('T-20.5b-7 fit-state double-tap does not enter magnification', (
    tester,
  ) async {
    _installDoubleTapClock();
    addTearDown(_restoreDoubleTapClock);
    final container = await _pumpStillFeed(tester);
    expect(container.read(browseStillMagnifiedProvider), isFalse);
    final center = tester.getCenter(
      find.byKey(const Key('magnificationPointerHost')),
    );
    await _tapAt(tester, center);
    _advanceDoubleTapClock(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 80));
    await _tapAt(tester, center);
    expect(container.read(browseStillMagnifiedProvider), isFalse);
    expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
  });

  testWidgets(
    'T-20.5b-8 forceFit clears pending double-tap candidate (no stale second tap)',
    (tester) async {
      _installDoubleTapClock();
      addTearDown(_restoreDoubleTapClock);
      final container = await _pumpStillFeed(tester);
      await _pinchMagnify(tester);
      final center = tester.getCenter(
        find.byKey(const Key('magnificationPointerHost')),
      );
      await _tapAt(tester, center);
      _advanceDoubleTapClock(const Duration(milliseconds: 40));
      await tester.pump(const Duration(milliseconds: 40));

      // Any forceFit source (Reset / leave / panel) must wipe the candidate.
      container.read(browseMagnificationProvider.notifier).forceFit();
      await tester.pump();
      expect(container.read(browseStillMagnifiedProvider), isFalse);

      await _pinchMagnify(tester);
      expect(container.read(browseStillMagnifiedProvider), isTrue);
      // Keep fake clock inside the original interval so a stale candidate
      // would still match — forceFit must have cleared it.
      await _tapAt(tester, center);
      expect(container.read(browseStillMagnifiedProvider), isTrue);
      expect(container.read(magnificationMatrixProvider).scale, greaterThan(1.5));
    },
  );
}
