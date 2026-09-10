import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/still_in_library.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';

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
        BrowseOriginSavedPool,
        BrowseLeftChipKind,
        leftChipKindFor,
        builtInControlSelected,
        BrowseSessionNotifier,
        BrowseSessionView,
        browseChromeStateProvider,
        browseEmptyRetryDelaysProvider,
        browseLayer2DwellProvider,
        browseLocalFirstVisitDwellProvider,
        browseSessionProvider,
        browseShuffleRandomFactoryProvider,
        browseSnapshotCacheProvider,
        BrowseSnapshotCache,
        mainBrowseSelectedSourceProvider,
        MainBrowseSelectedSource;
export 'package:waketok/app/saved_pool_providers.dart'
    show savedPoolRepositoryProvider, savedPoolRecordsProvider;

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
    ref
        .read(mainBrowseCurrentAssetHostUnavailableProvider.notifier)
        .setUnavailable(false);
  }
}

/// True while a full-screen Browse cover route is open (e.g. Build a Pool).
///
/// Cap 21.4b: opening sets user-intent pause via [PlaybackCoordinator]
/// so the center play affordance is already present when the cover pops.
class BrowseCoveringRouteOpenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOpen(bool open) {
    if (state == open) {
      return;
    }
    state = open;
  }
}

final browseCoveringRouteOpenProvider =
    NotifierProvider<BrowseCoveringRouteOpenNotifier, bool>(
      BrowseCoveringRouteOpenNotifier.new,
    );

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

/// True when Browse has a determinate current asset id **and** the current
/// feed page is not in Cap 21.6 Host-`assetUnavailable` fail chrome.
///
/// Cap 19 entry / left-swipe arm / future share (ADR-042 Decision 7).
/// Distinct from debt **456b** / ADR-049 still-in-library — this limb only
/// mirrors an already-known feed fail reason (has-current axis).
final mainBrowseCurrentAssetActionableProvider = Provider<bool>((ref) {
  final id = ref.watch(mainBrowseCurrentAssetIdProvider);
  if (id == null || id.isEmpty) {
    return false;
  }
  return !ref.watch(mainBrowseCurrentAssetHostUnavailableProvider);
});

/// Cap 23 / ADR-049: last known Photos-existence probe for the current asset.
///
/// Orthogonal to [mainBrowseCurrentAssetActionableProvider] — AND at call
/// sites via [mutationChromeMayProceed]; do not merge axes.
enum StillInLibraryStatus { unknown, probing, inLibrary, missing }

final mainBrowseCurrentAssetStillInLibraryProvider = NotifierProvider<
  MainBrowseCurrentAssetStillInLibrary,
  StillInLibraryStatus
>(MainBrowseCurrentAssetStillInLibrary.new);

class MainBrowseCurrentAssetStillInLibrary
    extends Notifier<StillInLibraryStatus> {
  @override
  StillInLibraryStatus build() {
    ref.listen<String?>(mainBrowseCurrentAssetIdProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      state = StillInLibraryStatus.unknown;
    });
    return StillInLibraryStatus.unknown;
  }

  /// On-demand single-id [AssetSourceRepository.getAssetAvailabilities] probe.
  ///
  /// Returns whether the **captured** current id is still in Photos. Does not
  /// consult actionable. While [StillInLibraryStatus.probing], further calls
  /// return `false` (in-flight latch hook for Cap 23.3). Stale completions
  /// (current id changed during await) discard results and return `false`.
  Future<bool> probeCurrentAssetStillInLibrary() async {
    if (state == StillInLibraryStatus.probing) {
      return false;
    }
    final capturedId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (capturedId == null || capturedId.isEmpty) {
      state = StillInLibraryStatus.missing;
      return false;
    }

    state = StillInLibraryStatus.probing;
    try {
      final map = await ref
          .read(assetSourceRepositoryProvider)
          .getAssetAvailabilities([capturedId]);
      if (ref.read(mainBrowseCurrentAssetIdProvider) != capturedId) {
        return false;
      }
      final availability =
          map[capturedId] ?? AssetAvailability.unavailable;
      final stillIn = isAssetStillInLibrary(availability);
      state = stillIn
          ? StillInLibraryStatus.inLibrary
          : StillInLibraryStatus.missing;
      return stillIn;
    } catch (_) {
      if (ref.read(mainBrowseCurrentAssetIdProvider) != capturedId) {
        return false;
      }
      state = StillInLibraryStatus.missing;
      return false;
    }
  }
}

/// Cap 21.6: current feed page reports Host `assetUnavailable` fail chrome.
///
/// Written by [MediaFeedPage] while current; cleared on leave-current /
/// successful L2. Drives Cap 19 entry dim + Overlay hide — not a Photos
/// existence probe (debt **456b** / ADR-049).
final mainBrowseCurrentAssetHostUnavailableProvider =
    NotifierProvider<MainBrowseCurrentAssetHostUnavailable, bool>(
      MainBrowseCurrentAssetHostUnavailable.new,
    );

class MainBrowseCurrentAssetHostUnavailable extends Notifier<bool> {
  @override
  bool build() => false;

  void setUnavailable(bool unavailable) {
    if (state == unavailable) {
      return;
    }
    state = unavailable;
  }
}

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
