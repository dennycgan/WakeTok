import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/magnification_arbitration.dart';

void main() {
  group('magnification_arbitration pure predicates', () {
    test('T-20.2-1 still magnified locks vertical PageView', () {
      expect(
        verticalPageViewScrollLocked(
          isCurrentStillMagnified: true,
          transientPinchActive: false,
        ),
        isTrue,
      );
    });

    test('T-20.2-2 transient pinch active locks vertical PageView', () {
      expect(
        verticalPageViewScrollLocked(
          isCurrentStillMagnified: false,
          transientPinchActive: true,
        ),
        isTrue,
      );
    });

    test('T-20.2-3 fit + no transient pinch does not lock PageView', () {
      expect(
        verticalPageViewScrollLocked(
          isCurrentStillMagnified: false,
          transientPinchActive: false,
        ),
        isFalse,
      );
    });

    test('T-20.2-3b still pinch contact alone locks PageView', () {
      expect(
        verticalPageViewScrollLocked(
          isCurrentStillMagnified: false,
          transientPinchActive: false,
          stillPinchContact: true,
        ),
        isTrue,
      );
    });

    test('T-20.2-4 live motion rising edge force-fits when magnified', () {
      expect(
        shouldForceFitOnLiveMotionRisingEdge(
          previouslyMounted: false,
          currentlyMounted: true,
          hasActiveMagnification: true,
        ),
        isTrue,
      );
    });

    test('T-20.2-5 live motion rising edge is a no-op when already fit', () {
      expect(
        shouldForceFitOnLiveMotionRisingEdge(
          previouslyMounted: false,
          currentlyMounted: true,
          hasActiveMagnification: false,
        ),
        isFalse,
      );
    });

    test('T-20.2-6 live motion falling edge does not force-fit', () {
      expect(
        shouldForceFitOnLiveMotionRisingEdge(
          previouslyMounted: true,
          currentlyMounted: false,
          hasActiveMagnification: true,
        ),
        isFalse,
      );
    });

    test('T-20.2-7 stay mounted true→true is not a rising edge', () {
      expect(
        shouldForceFitOnLiveMotionRisingEdge(
          previouslyMounted: true,
          currentlyMounted: true,
          hasActiveMagnification: true,
        ),
        isFalse,
      );
    });

    test('T-20.2-8 panel open rising edge force-fits when magnified', () {
      expect(
        shouldForceFitOnActionsPanelOpen(
          previouslyOpen: false,
          currentlyOpen: true,
          hasActiveMagnification: true,
        ),
        isTrue,
      );
    });

    test('T-20.4-3 panel open rising edge force-fits video pinch', () {
      expect(
        shouldForceFitOnActionsPanelOpen(
          previouslyOpen: false,
          currentlyOpen: true,
          hasActiveMagnification: true,
        ),
        isTrue,
      );
    });

    test('T-20.4-3b panel open is no-op when no magnification active', () {
      expect(
        shouldForceFitOnActionsPanelOpen(
          previouslyOpen: false,
          currentlyOpen: true,
          hasActiveMagnification: false,
        ),
        isFalse,
      );
    });

    test('T-20.2-9 leave current clears when magnification active', () {
      expect(
        shouldClearMagnificationOnLeaveCurrent(
          wasCurrentOrBrowseActive: true,
          isCurrentOrBrowseActive: false,
          hasActiveMagnification: true,
        ),
        isTrue,
      );
    });
  });

  group('pointerIdsToClearAfterNativeShareDismiss', () {
    test('T-clear-1 single residual at dismissedAtMs', () {
      expect(
        pointerIdsToClearAfterNativeShareDismiss(
          pointerDownAtMs: {10: 1000},
          dismissedAtMs: 1000,
        ),
        {10},
      );
    });

    test('T-clear-2 keeps post-dismiss pointer', () {
      expect(
        pointerIdsToClearAfterNativeShareDismiss(
          pointerDownAtMs: {10: 1000, 11: 2000},
          dismissedAtMs: 1500,
        ),
        {10},
      );
    });

    test('T-clear-3 empty map', () {
      expect(
        pointerIdsToClearAfterNativeShareDismiss(
          pointerDownAtMs: {},
          dismissedAtMs: 999,
        ),
        isEmpty,
      );
    });

    test('T-clear-4 all residuals cleared', () {
      expect(
        pointerIdsToClearAfterNativeShareDismiss(
          pointerDownAtMs: {1: 10, 2: 20, 3: 30},
          dismissedAtMs: 30,
        ),
        {1, 2, 3},
      );
    });
  });

  group('recoverBrowseMagnificationAfterNativeShareDismiss', () {
    test('T-rec-1 hasActive=false clears residual pointers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mag = container.read(browseMagnificationProvider.notifier);
      expect(
        container.read(browseMagnificationProvider).hasActiveMagnification,
        isFalse,
      );

      final pointers = <int, Offset>{10: Offset.zero};
      final downAt = <int, int>{10: 1000};
      var forceFitCalls = 0;
      final cleared = recoverBrowseMagnificationAfterNativeShareDismiss(
        forceFit: () {
          forceFitCalls += 1;
          mag.forceFit();
        },
        pointers: pointers,
        pointerDownAtMs: downAt,
        dismissedAtMs: 1000,
      );

      expect(forceFitCalls, 1);
      expect(
        container.read(browseMagnificationProvider).hasActiveMagnification,
        isFalse,
      );
      expect(cleared, {10});
      expect(pointers, isEmpty);
      expect(downAt, isEmpty);
    });

    test('T-rec-2 hasActive=true forceFits and clears pointers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mag = container.read(browseMagnificationProvider.notifier);
      mag.setTransientPinchActive(true);
      expect(
        container.read(browseMagnificationProvider).hasActiveMagnification,
        isTrue,
      );

      final pointers = <int, Offset>{7: const Offset(1, 2)};
      final downAt = <int, int>{7: 500};
      final cleared = recoverBrowseMagnificationAfterNativeShareDismiss(
        forceFit: mag.forceFit,
        pointers: pointers,
        pointerDownAtMs: downAt,
        dismissedAtMs: 500,
      );

      expect(
        container.read(browseMagnificationProvider).hasActiveMagnification,
        isFalse,
      );
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isFalse,
      );
      expect(cleared, {7});
      expect(pointers, isEmpty);
    });

    test('T-rec-3 clean state is full no-op on maps', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mag = container.read(browseMagnificationProvider.notifier);
      final before = container.read(browseMagnificationProvider);

      final pointers = <int, Offset>{};
      final downAt = <int, int>{};
      final cleared = recoverBrowseMagnificationAfterNativeShareDismiss(
        forceFit: mag.forceFit,
        pointers: pointers,
        pointerDownAtMs: downAt,
        dismissedAtMs: 42,
      );

      expect(cleared, isEmpty);
      expect(pointers, isEmpty);
      expect(container.read(browseMagnificationProvider), before);
    });

    test('T-rec-4 clears residual only keeps newer pointer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mag = container.read(browseMagnificationProvider.notifier);
      mag.setTransientPinchActive(true);

      final pointers = <int, Offset>{
        10: Offset.zero,
        11: const Offset(3, 4),
      };
      final downAt = <int, int>{10: 1000, 11: 2000};
      final cleared = recoverBrowseMagnificationAfterNativeShareDismiss(
        forceFit: mag.forceFit,
        pointers: pointers,
        pointerDownAtMs: downAt,
        dismissedAtMs: 1500,
      );

      expect(
        container.read(browseMagnificationProvider).hasActiveMagnification,
        isFalse,
      );
      expect(cleared, {10});
      expect(pointers.keys, {11});
      expect(downAt, {11: 2000});
    });
  });

  group('BrowseMagnificationNotifier', () {
    test('T-20.2-10 setStillMagnified feeds browseStillMagnifiedProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      container.read(browseMagnificationProvider.notifier).setStillMagnified(true);
      expect(container.read(browseStillMagnifiedProvider), isTrue);
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isTrue,
      );
    });

    test('T-20.2-11 still magnified blocks left-swipe arming', () {
      expect(
        leftSwipeArmingAllowed(
          leftSwipeAddEnabled: true,
          isCurrentStillMagnified: true,
          cap19PanelOpen: false,
          currentAssetMediaCoverVisible: true,
          currentAssetActionable: true,
        ),
        isFalse,
      );
    });

    test(
      'T-20.2-12a live rising edge (auto play-once path) force-fits',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final mag = container.read(browseMagnificationProvider.notifier);
        mag.setStillMagnified(true);
        mag.onLiveMotionMountedChanged(true);
        expect(container.read(browseStillMagnifiedProvider), isFalse);
      },
    );

    test(
      'T-20.2-12b live rising edge after unload→remount (explicit replay path)',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final mag = container.read(browseMagnificationProvider.notifier);
        // Simulate prior auto play-once cycle.
        mag.onLiveMotionMountedChanged(true);
        mag.onLiveMotionMountedChanged(false);
        mag.setStillMagnified(true);
        // Future Decision 17 replay remounts PV — same rising-edge guard.
        mag.onLiveMotionMountedChanged(true);
        expect(container.read(browseStillMagnifiedProvider), isFalse);
      },
    );

    test('T-20.2-13 panel open force-fits magnified still', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mag = container.read(browseMagnificationProvider.notifier);
      mag.setStillMagnified(true);
      // Warm listen registration inside BrowseMagnificationNotifier.build.
      container.read(browseMagnificationProvider);
      container.read(cap19ActionsPanelOpenProvider.notifier).state = true;
      expect(container.read(browseStillMagnifiedProvider), isFalse);
    });

    test('T-20.4-3c panel open force-fits active video pinch', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mag = container.read(browseMagnificationProvider.notifier);
      mag.setTransientPinchActive(true);
      container.read(browseMagnificationProvider);
      container.read(cap19ActionsPanelOpenProvider.notifier).state = true;
      expect(
        container.read(browseMagnificationProvider).transientPinchActive,
        isFalse,
      );
    });

    test('T-20.4-4 video pinch active blocks left-swipe arming', () {
      expect(
        leftSwipeArmingAllowed(
          leftSwipeAddEnabled: true,
          isCurrentStillMagnified: false,
          transientPinchActive: true,
          cap19PanelOpen: false,
          currentAssetMediaCoverVisible: true,
          currentAssetActionable: true,
        ),
        isFalse,
      );
    });

    test('T-20.4-4b still pinch contact blocks left-swipe arming', () {
      expect(
        leftSwipeArmingAllowed(
          leftSwipeAddEnabled: true,
          isCurrentStillMagnified: false,
          stillPinchContact: true,
          cap19PanelOpen: false,
          currentAssetMediaCoverVisible: true,
          currentAssetActionable: true,
        ),
        isFalse,
      );
    });

    test('T-20.4-4c fit video (no pinch flags) allows left-swipe arming', () {
      expect(
        leftSwipeArmingAllowed(
          leftSwipeAddEnabled: true,
          isCurrentStillMagnified: false,
          transientPinchActive: false,
          stillPinchContact: false,
          cap19PanelOpen: false,
          currentAssetMediaCoverVisible: true,
          currentAssetActionable: true,
        ),
        isTrue,
      );
    });

    test('T-20.2-14 leave current clears still + video pinch', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mag = container.read(browseMagnificationProvider.notifier);
      mag.setStillMagnified(true);
      mag.setTransientPinchActive(true);
      mag.clearBecauseLeftCurrentOrBrowse();
      expect(
        container.read(browseMagnificationProvider),
        const BrowseMagnificationState(),
      );
    });

    test('T-20.2-15 video pinch alone locks PageView flag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(browseMagnificationProvider.notifier)
          .setTransientPinchActive(true);
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isTrue,
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);
    });

    test('T-20.2-16 still pinch contact alone locks PageView flag', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(browseMagnificationProvider.notifier)
          .setStillPinchContact(true);
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isTrue,
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);
    });
  });

  group('usesPersistentMagnification policy', () {
    DisplayAsset stillAsset(PlaybackMediaKind kind) => DisplayAsset(
      assetIdentifier: 'x',
      mediaKind: kind,
      localFilePath: '/tmp/x.jpg',
      pixelWidth: 100,
      pixelHeight: 100,
    );

    test('T-20.4-policy-1 photo L2 full is persistent', () {
      expect(
        usesPersistentMagnification(
          FeedPageMedia.still(
            stillAsset(PlaybackMediaKind.image),
            layer: FeedDisplayLayer.full,
          ),
        ),
        isTrue,
      );
    });

    test('T-20.4-policy-2 Live L2 static full is persistent', () {
      expect(
        usesPersistentMagnification(
          FeedPageMedia.still(
            stillAsset(PlaybackMediaKind.livePhoto),
            layer: FeedDisplayLayer.full,
          ),
        ),
        isTrue,
        reason: 'ADR-043: Live static L2 shares persistent still path',
      );
    });

    test('T-20.4-policy-3 photo L1 preview is not persistent', () {
      expect(
        usesPersistentMagnification(
          FeedPageMedia.still(
            stillAsset(PlaybackMediaKind.image),
            layer: FeedDisplayLayer.preview,
          ),
        ),
        isFalse,
      );
    });

    test('T-20.4-policy-4 video poster still-kind is not persistent', () {
      expect(
        usesPersistentMagnification(
          FeedPageMedia.still(
            stillAsset(PlaybackMediaKind.video),
            layer: FeedDisplayLayer.full,
          ),
        ),
        isFalse,
      );
    });

    test('T-20.4-policy-5 video page media is not persistent', () {
      expect(
        usesPersistentMagnification(
          FeedPageMedia.video('v1', poster: stillAsset(PlaybackMediaKind.video)),
        ),
        isFalse,
      );
    });
  });
}
