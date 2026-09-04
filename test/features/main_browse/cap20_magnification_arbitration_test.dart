import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/magnification_arbitration.dart';

void main() {
  group('magnification_arbitration pure predicates', () {
    test('T-20.2-1 still magnified locks vertical PageView', () {
      expect(
        verticalPageViewScrollLocked(
          isCurrentStillMagnified: true,
          videoPinchActive: false,
        ),
        isTrue,
      );
    });

    test('T-20.2-2 video pinch active locks vertical PageView', () {
      expect(
        verticalPageViewScrollLocked(
          isCurrentStillMagnified: false,
          videoPinchActive: true,
        ),
        isTrue,
      );
    });

    test('T-20.2-3 fit + no video pinch does not lock PageView', () {
      expect(
        verticalPageViewScrollLocked(
          isCurrentStillMagnified: false,
          videoPinchActive: false,
        ),
        isFalse,
      );
    });

    test('T-20.2-4 live motion rising edge force-fits when magnified', () {
      expect(
        shouldForceFitOnLiveMotionRisingEdge(
          previouslyMounted: false,
          currentlyMounted: true,
          isStillMagnified: true,
        ),
        isTrue,
      );
    });

    test('T-20.2-5 live motion rising edge is a no-op when already fit', () {
      expect(
        shouldForceFitOnLiveMotionRisingEdge(
          previouslyMounted: false,
          currentlyMounted: true,
          isStillMagnified: false,
        ),
        isFalse,
      );
    });

    test('T-20.2-6 live motion falling edge does not force-fit', () {
      expect(
        shouldForceFitOnLiveMotionRisingEdge(
          previouslyMounted: true,
          currentlyMounted: false,
          isStillMagnified: true,
        ),
        isFalse,
      );
    });

    test('T-20.2-7 stay mounted true→true is not a rising edge', () {
      expect(
        shouldForceFitOnLiveMotionRisingEdge(
          previouslyMounted: true,
          currentlyMounted: true,
          isStillMagnified: true,
        ),
        isFalse,
      );
    });

    test('T-20.2-8 panel open rising edge force-fits when magnified', () {
      expect(
        shouldForceFitOnActionsPanelOpen(
          previouslyOpen: false,
          currentlyOpen: true,
          isStillMagnified: true,
        ),
        isTrue,
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

    test('T-20.2-14 leave current clears still + video pinch', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final mag = container.read(browseMagnificationProvider.notifier);
      mag.setStillMagnified(true);
      mag.setVideoPinchActive(true);
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
          .setVideoPinchActive(true);
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isTrue,
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);
    });
  });
}
