import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';

export 'package:waketok/app/browse/browse_l2_ready_session.dart'
    show
        BrowseL2ReadySession,
        FeedL2ReadyEntry,
        FeedL2ReadyKind,
        browseL2ReadySessionProvider;
export 'package:waketok/app/browse/browse_session_providers.dart'
    show
        BrowseChromeState,
        BrowseChromeStateNotifier,
        BrowseOrigin,
        BrowseOriginBuiltIn,
        BrowseOriginEphemeralPool,
        BrowseSessionNotifier,
        BrowseSessionView,
        browseChromeStateProvider,
        browseEmptyRetryDelaysProvider,
        browseLayer2DwellProvider,
        browseLocalFirstVisitDwellProvider,
        browseSessionProvider,
        browseShuffleRandomFactoryProvider,
        browseSnapshotCacheProvider,
        mainBrowseSelectedSourceProvider,
        MainBrowseSelectedSource;

/// Bottom destinations for the Main Browse shell.
enum MainBrowseDestination { browse, clips, auto, settings }

final mainBrowseDestinationProvider =
    NotifierProvider<MainBrowseDestinationNotifier, MainBrowseDestination>(
      MainBrowseDestinationNotifier.new,
    );

class MainBrowseDestinationNotifier extends Notifier<MainBrowseDestination> {
  @override
  MainBrowseDestination build() => MainBrowseDestination.browse;

  /// Bottom-nav destination change.
  ///
  /// Cap 14.4e / ADR-027: leaving Browse (→ Settings / Clips / Auto) ends the
  /// current Consumption Session. Order is intentional — destination first so
  /// `browseActive` is already false before session/index reset (avoids a
  /// half-new Session while still current). App background / lock never calls
  /// this method, so those paths do not reset.
  void select(MainBrowseDestination next) {
    final leavingBrowse =
        state == MainBrowseDestination.browse &&
        next != MainBrowseDestination.browse;
    state = next;
    if (!leavingBrowse) {
      return;
    }
    unawaited(ref.read(browseSessionProvider.notifier).restartSession());
    ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    ref.read(mainBrowseVerticalFeedSettledProvider.notifier).setSettled(true);
  }
}

/// Current PageView index; resets to 0 when the top source changes (Cap 7.5 /
/// ADR-023 D8: tab = new Session).
final mainBrowseFeedIndexProvider = NotifierProvider<MainBrowseFeedIndex, int>(
  MainBrowseFeedIndex.new,
);

class MainBrowseFeedIndex extends Notifier<int> {
  @override
  int build() {
    ref.listen<BrowseOrigin>(
      browseChromeStateProvider.select((s) => s.activeOrigin),
      (prev, next) {
        if (prev != next) {
          state = 0;
        }
      },
    );
    return 0;
  }

  void setIndex(int index) {
    if (index == state) {
      return;
    }
    state = index;
  }

  /// Clamp [feedIndex] into the queue, or ignore when empty (restore safety).
  void applyRestoreIndex(int feedIndex, int queueLength) {
    if (queueLength <= 0) {
      return;
    }
    final clamped = feedIndex.clamp(0, queueLength - 1);
    setIndex(clamped);
  }
}

/// Current feed asset id (Cap 19.5 append target).
final mainBrowseCurrentAssetIdProvider = Provider<String?>((ref) {
  final sessionAsync = ref.watch(browseSessionProvider);
  final feedIndex = ref.watch(mainBrowseFeedIndexProvider);
  final view = sessionAsync.asData?.value;
  if (view == null) {
    return null;
  }
  final ids = view.orderedAssetIds;
  if (ids.isEmpty || feedIndex < 0 || feedIndex >= ids.length) {
    return null;
  }
  return ids[feedIndex];
});

/// True when Browse has a determinate current asset id (Cap 19 entry / future
/// share / left-swipe arm). Not playback-ready — distinct from scrubber L2 gates.
final mainBrowseCurrentAssetActionableProvider = Provider<bool>((ref) {
  final id = ref.watch(mainBrowseCurrentAssetIdProvider);
  return id != null && id.isNotEmpty;
});

/// Vertical PageView settle for trailing mutation chrome (ADR-042 Decision 8)
/// and scrubber peek hide. Written by [VerticalMediaFeed] on scroll-notification
/// edges only — not every PageController frame.
final mainBrowseVerticalFeedSettledProvider =
    NotifierProvider<MainBrowseVerticalFeedSettled, bool>(
      MainBrowseVerticalFeedSettled.new,
    );

class MainBrowseVerticalFeedSettled extends Notifier<bool> {
  @override
  bool build() => true;

  void setSettled(bool settled) {
    if (state == settled) {
      return;
    }
    state = settled;
  }
}
