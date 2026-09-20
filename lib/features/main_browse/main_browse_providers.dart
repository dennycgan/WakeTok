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
export 'package:waketok/app/browse/browse_live_motion_watchdog.dart'
    show
        BrowseLiveMotionWatchdogSkipIds,
        browseLiveMotionWatchdogSkipIdsProvider,
        kLiveMotionEndedWatchdog;
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
        browseEffectiveFeedDataSourceIdProvider,
        browseLayer2DwellProvider,
        browseLocalFirstVisitDwellProvider,
        browseOriginSessionDeltaProvider,
        browseSessionProvider,
        browseShuffleRandomFactoryProvider,
        browseSnapshotCacheProvider,
        browseStickyFeedDataSourceIdProvider,
        BrowseSnapshotCache,
        mainBrowseSelectedSourceProvider,
        MainBrowseSelectedSource;
export 'package:waketok/app/saved_pool_providers.dart'
    show savedPoolRepositoryProvider, savedPoolRecordsProvider;

/// Bottom destinations for the Main Browse shell.
/// Cap 27.4 / ADR-055: Browse + Settings only. Order is an action slot, not
/// a destination (does not call [MainBrowseDestinationNotifier.select]).
enum MainBrowseDestination { browse, settings }

final mainBrowseDestinationProvider =
    NotifierProvider<MainBrowseDestinationNotifier, MainBrowseDestination>(
      MainBrowseDestinationNotifier.new,
    );

class MainBrowseDestinationNotifier extends Notifier<MainBrowseDestination> {
  @override
  MainBrowseDestination build() => MainBrowseDestination.browse;

  /// Bottom-nav destination change.
  ///
  /// Cap 14.4e / ADR-027 (Cap 27.4 narrow): leaving Browse → Settings ends the
  /// current Consumption Session. Order is intentional — destination first so
  /// `browseActive` is already false before session/index reset (avoids a
  /// half-new Session while still current). App background / lock never calls
  /// this method, so those paths do not reset. Opening the order-control
  /// sheet must not call this method.
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
    ref
        .read(mainBrowseCurrentAssetLayer2DisplayReadyProvider.notifier)
        .setReady(false);
    ref
        .read(mainBrowseCurrentLiveMotionMountedProvider.notifier)
        .setMounted(false);
    ref
        .read(mainBrowseCurrentAssetListAvailabilityProvider.notifier)
        .setAvailability(null);
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
        if (prev == null || prev == next) {
          return;
        }
        // ADR-057 D3: shared signal only — no private promote heuristic.
        if (ref.read(browseOriginSessionDeltaProvider).isIdentityPreservingPromote) {
          return;
        }
        state = 0;
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

/// Probe status plus shared mutation-gate latch (ADR-049 D6).
class StillInLibraryGateState {
  const StillInLibraryGateState({
    this.status = StillInLibraryStatus.unknown,
    this.dialogVisible = false,
  });

  final StillInLibraryStatus status;
  final bool dialogVisible;

  /// True while a probe is in flight or the shared unavailable dialog is up.
  bool get isBusy =>
      status == StillInLibraryStatus.probing || dialogVisible;

  StillInLibraryGateState copyWith({
    StillInLibraryStatus? status,
    bool? dialogVisible,
  }) {
    return StillInLibraryGateState(
      status: status ?? this.status,
      dialogVisible: dialogVisible ?? this.dialogVisible,
    );
  }
}

final mainBrowseCurrentAssetStillInLibraryProvider = NotifierProvider<
  MainBrowseCurrentAssetStillInLibrary,
  StillInLibraryGateState
>(MainBrowseCurrentAssetStillInLibrary.new);

class MainBrowseCurrentAssetStillInLibrary
    extends Notifier<StillInLibraryGateState> {
  @override
  StillInLibraryGateState build() {
    ref.listen<String?>(mainBrowseCurrentAssetIdProvider, (prev, next) {
      if (prev == next) {
        return;
      }
      state = const StillInLibraryGateState();
    });
    return const StillInLibraryGateState();
  }

  bool get isBusy => state.isBusy;

  void setDialogVisible(bool visible) {
    if (state.dialogVisible == visible) {
      return;
    }
    state = state.copyWith(dialogVisible: visible);
  }

  /// On-demand single-id [AssetSourceRepository.getAssetAvailabilities] probe.
  ///
  /// Returns whether the **captured** current id is still in Photos. Does not
  /// consult actionable. While [StillInLibraryGateState.isBusy], further calls
  /// return `false` (in-flight / dialog latch). Stale completions (current id
  /// changed during await) discard results and return `false`.
  Future<bool> probeCurrentAssetStillInLibrary() async {
    if (state.isBusy) {
      return false;
    }
    final capturedId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (capturedId == null || capturedId.isEmpty) {
      state = state.copyWith(status: StillInLibraryStatus.missing);
      return false;
    }

    state = state.copyWith(status: StillInLibraryStatus.probing);
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
      state = state.copyWith(
        status: stillIn
            ? StillInLibraryStatus.inLibrary
            : StillInLibraryStatus.missing,
      );
      return stillIn;
    } catch (_) {
      if (ref.read(mainBrowseCurrentAssetIdProvider) != capturedId) {
        return false;
      }
      state = state.copyWith(status: StillInLibraryStatus.missing);
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

/// Cap 25 / ADR-051 Decision 14: current page L2 display / video surface ready.
///
/// Written by [MediaFeedPage] only. Still: full L2 apply; video: `_surfaceReady`.
/// Cleared on arm in-flight / leave-current / reload / fail. Not
/// [browseL2ReadySessionProvider] (session mint can precede video surface-ready).
final mainBrowseCurrentAssetLayer2DisplayReadyProvider =
    NotifierProvider<MainBrowseCurrentAssetLayer2DisplayReady, bool>(
      MainBrowseCurrentAssetLayer2DisplayReady.new,
    );

class MainBrowseCurrentAssetLayer2DisplayReady extends Notifier<bool> {
  @override
  bool build() => false;

  void setReady(bool ready) {
    if (state == ready) {
      return;
    }
    state = ready;
  }
}

/// Cap 26.4c / ADR-054: current page has painted a real media cover.
///
/// Written by [MediaFeedPage] only (see [mediaCoverVisiblePredicate]).
/// Cleared on leave-current. Orthogonal to actionable / Layer2DisplayReady.
final mainBrowseCurrentAssetMediaCoverVisibleProvider =
    NotifierProvider<MainBrowseCurrentAssetMediaCoverVisible, bool>(
      MainBrowseCurrentAssetMediaCoverVisible.new,
    );

class MainBrowseCurrentAssetMediaCoverVisible extends Notifier<bool> {
  @override
  bool build() => false;

  void setVisible(bool visible) {
    if (state == visible) {
      return;
    }
    state = visible;
  }
}

/// Cap 25 / ADR-051 Decision 14: Live motion UiKitView mounted on current item.
///
/// Published from [BrowseMagnificationNotifier.onLiveMotionMountedChanged]
/// (and leave-current clear). Must not live on [BrowseMagnificationState] —
/// [BrowseMagnificationNotifier.forceFit] resets that state.
final mainBrowseCurrentLiveMotionMountedProvider =
    NotifierProvider<MainBrowseCurrentLiveMotionMounted, bool>(
      MainBrowseCurrentLiveMotionMounted.new,
    );

class MainBrowseCurrentLiveMotionMounted extends Notifier<bool> {
  @override
  bool build() => false;

  void setMounted(bool mounted) {
    if (state == mounted) {
      return;
    }
    state = mounted;
  }
}

/// Cap 25 / ADR-051 Decision 14: list-time availability for the current asset.
///
/// Written by [MediaFeedPage] after Cap 15.12 become-current probe (or snapshot
/// inject when non-null). Resolve snapshots intentionally omit availabilities
/// (ADR-033) — do not read [browseSnapshotCacheProvider] for this signal.
final mainBrowseCurrentAssetListAvailabilityProvider =
    NotifierProvider<MainBrowseCurrentAssetListAvailability, AssetAvailability?>(
      MainBrowseCurrentAssetListAvailability.new,
    );

class MainBrowseCurrentAssetListAvailability
    extends Notifier<AssetAvailability?> {
  @override
  AssetAvailability? build() => null;

  void setAvailability(AssetAvailability? availability) {
    if (state == availability) {
      return;
    }
    state = availability;
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

/// Cap 25 / ADR-051 Decision 9: Share tap → Cap 23 probe → Host present
/// settle window. Clears when that window ends; does not cover system sheet
/// lifetime (no PopScope). Keeps [Cap25ShareEntryIcon] a [ConsumerWidget].
final mainBrowseSharePresentInFlightProvider =
    NotifierProvider<MainBrowseSharePresentInFlight, bool>(
      MainBrowseSharePresentInFlight.new,
    );

class MainBrowseSharePresentInFlight extends Notifier<bool> {
  @override
  bool build() => false;

  bool get isInFlight => state;

  void begin() {
    if (state) {
      return;
    }
    state = true;
  }

  void end() {
    if (!state) {
      return;
    }
    state = false;
  }
}
