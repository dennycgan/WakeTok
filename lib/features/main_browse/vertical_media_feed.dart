import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/app/new_round_toast_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/still_in_library.dart';
import 'package:waketok/domain/live_photo/live_photo_repository.dart';
import 'package:waketok/domain/playback/media_display_repository.dart';
import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/live_photo_providers.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/library_smoke/shared_mute_provider.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/feed_activation_coordinator.dart';
import 'package:waketok/features/main_browse/magnification_reset_button.dart';
import 'package:waketok/features/main_browse/magnification_surface.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/media_cover_visible_policy.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_drag.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_gesture.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/cap24_more_panel_open.dart';
import 'package:waketok/features/main_browse/cap26_live_long_press_arbitration.dart';
import 'package:waketok/features/main_browse/cap26_live_long_press_gesture.dart';
import 'package:waketok/features/main_browse/playback_coordinator.dart';
import 'package:waketok/features/main_browse/playback_coordinator_provider.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/features/main_browse/presentation_size_cache.dart';
import 'package:waketok/features/main_browse/pv_transition_guard.dart';
import 'package:waketok/features/main_browse/scrubber_policy.dart';
import 'package:waketok/features/main_browse/video_progress_scrubber.dart';
import 'package:waketok/features/main_browse/wait_chrome_policy.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 17.4: top source chrome body below the status bar (pad 8+8, label,
/// pools subtitle). Feed is full-bleed under [_TopSourceChrome].
const double kCoverlessCenterTopChromeBody = 8 + 8 + 20 + 16;

/// True when a vertical feed scroll is past the trailing edge (next-item
/// direction). Used for Endless round advance **fallback** after the
/// static placeholder page (Cap 22.5 scheme A) — true overscroll only.
///
/// Last-page **settle** (`extentAfter == 0` but still in-range) must not
/// match — that would reshuffle when the user only lands on the last item.
bool isEndlessRoundAdvanceScroll(ScrollNotification notification) {
  if (notification.metrics.axis != Axis.vertical) {
    return false;
  }
  if (notification is OverscrollNotification) {
    return notification.overscroll > 0;
  }
  if (notification is ScrollUpdateNotification) {
    final delta = notification.scrollDelta ?? 0;
    if (delta <= 0) {
      return false;
    }
    final metrics = notification.metrics;
    return metrics.outOfRange && metrics.pixels > metrics.maxScrollExtent;
  }
  return false;
}

/// Vertical Manual feed over Cap 13 Shuffle Session Queue (ADR-023).
class VerticalMediaFeed extends ConsumerStatefulWidget {
  const VerticalMediaFeed({super.key});

  @override
  ConsumerState<VerticalMediaFeed> createState() => VerticalMediaFeedState();
}

class VerticalMediaFeedState extends ConsumerState<VerticalMediaFeed>
    with WidgetsBindingObserver {
  PageController? _pageController;
  /// Tracks which [BrowseSessionView.roundEpoch] [_pageController] was built
  /// for. Remount must recreate the controller at the landing index —
  /// [PageController.initialPage] is fixed at construction; reusing the
  /// old controller after a new PageView key would flash page 0.
  int? _pageControllerEpoch;
  StreamSubscription<PlaybackRestoreRequest>? _restoreSub;
  List<String> _ids = const [];
  bool _advancingRound = false;
  /// Cap 22.5 scheme A: placeholder page (index == session length) armed
  /// for ScrollEnd settle advance. Do not [setIndex] to the placeholder —
  /// feed-index listen would [PageController.jumpToPage] and truncate scroll.
  bool _endlessPlaceholderArmed = false;
  /// Cancels in-flight toast / post-advance work across dispose or re-advance.
  int _roundAdvanceGen = 0;
  /// Last still Layer 1 per asset (preheat / current) for remount seed so
  /// round landing does not flash bare feedBackground.
  final Map<String, FeedPageMedia> _layer1Seeds = <String, FeedPageMedia>{};
  /// Cap 22.5: after showing starting-over toast, dismiss when leaving
  /// feedIndex 0 (landing) or leave Browse.
  bool _newRoundToastDismissArmed = false;
  int? _newRoundToastLandingFeedIndex;
  AppLifecycleState? _lastLifecycle;
  String? _lastDataSourceId;

  /// Last build's ADR-039 source-switch center-label delay flag.
  /// Round advance must leave this false (same [feedDataSourceId]).
  @visibleForTesting
  bool debugLastDelayInitialLayer1CenterLabel = false;

  final FeedActivationCoordinator _activation = FeedActivationCoordinator();

  /// Cap 9.4 / F4: feed-scoped mutex for Live Host cancel/request (not per-page —
  /// PageView may recreate page State across leave/re-enter).
  final LiveHostOpSerial liveHostSerial = LiveHostOpSerial();
  final Map<String, PresentationOverlaySnapshot> _overlayCache =
      <String, PresentationOverlaySnapshot>{};

  String? _activeAssetId;
  int? _activeDisplayGeneration;
  PresentationOverlaySnapshot? _overlaySnapshot;

  /// Last [build] value of browse-tab active. Default true: first frame is Browse.
  /// Updated every build so the false→true edge cannot go stale.
  bool _browseWasActive = true;

  /// Set on Browse false→true; cleared only after [_beginCurrentItemActivation]
  /// runs. Must not clear on the same frame if session is loading/error/empty
  /// — that would drop the generation bump. Not a substitute for the shell
  /// Theme wrap.
  bool _browseResumeLatch = false;

  /// [currentDisplayGate] generation when [_browseResumeLatch] armed.
  /// Build skips a second [beginCurrentItem] if listen already bumped.
  int? _generationWhenLatchArmed;

  /// Cap 14.5: neighbour indices allowed to `requestPreview`. Never larger
  /// than the last release-safe window (phase A shrinks; phase B expands).
  Set<int> _allowedPreheatIndices = <int>{};

  /// Last fully applied current±1 index window (after release await).
  Set<int> _committedPreheatWindow = <int>{};

  int _preheatSyncGen = 0;
  int? _preheatTrackedIndex;
  bool? _preheatTrackedBrowse;
  int? _preheatTrackedLength;
  int? _preheatTrackedEpoch;
  List<String> _preheatIdSnapshot = const [];

  /// Bumped on foreground resume so current [MediaFeedPage] runs
  /// [PlaybackCoordinator.onForegroundResumeSync] via [didUpdateWidget].
  int _foregroundResumeSyncEpoch = 0;

  /// Scrubber peek hide — edge-triggered from scroll notifications only.
  /// Do not drive this from [PageController.addListener]: unconditional
  /// setState there rebuilds the whole feed every frame and breaks widget
  /// tests that depend on stable pump timing (Cap 18.5 follow-up).
  bool _scrubberVerticalFeedSettled = true;

  void _publishVerticalFeedSettled(bool settled) {
    if (_scrubberVerticalFeedSettled != settled) {
      _scrubberVerticalFeedSettled = settled;
      if (mounted) {
        // Remount / jumpToPage can deliver scroll metrics during layout;
        // never setState mid-frame (Cap 22.5 bridge commit).
        final phase = SchedulerBinding.instance.schedulerPhase;
        if (phase == SchedulerPhase.idle ||
            phase == SchedulerPhase.postFrameCallbacks) {
          setState(() {});
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {});
            }
          });
        }
      }
    }
    ref.read(mainBrowseVerticalFeedSettledProvider.notifier).setSettled(settled);
  }

  /// Leave current page / source / Browse: clear mag session + host mode so
  /// neighbours cannot inherit a stale still/video pinch matrix (Cap 20.4).
  void _clearMagnificationSession() {
    ref.read(browseMagnificationProvider.notifier).clearBecauseLeftCurrentOrBrowse();
    ref
        .read(magnificationHostModeProvider.notifier)
        .setMode(MagnificationHostMode.none);
    ref.read(nativeDisplayMagnificationPushProvider.notifier).setEnabled(false);
    ref.read(magnificationMatrixProvider.notifier).reset();
    ref.read(magnificationContentSizeProvider.notifier).clear();
    unawaited(
      ref.read(playbackRepositoryProvider).setDisplayMagnification(
        scale: kCap20MinScale,
        translationX: 0,
        translationY: 0,
      ),
    );
  }

  /// Two-finger lock rose while PageView was mid-drag: NeverScrollable alone
  /// does not cancel an in-flight scroll activity — jump back to the current
  /// index so the neighbour page cannot steal the pinch (Cap 20.4 device).
  void _snapVerticalFeedToCurrentIfMidScroll() {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    final page = controller.page;
    if (page == null) {
      return;
    }
    final feedIndex = ref.read(mainBrowseFeedIndexProvider);
    if ((page - feedIndex).abs() < 0.001) {
      return;
    }
    controller.jumpToPage(feedIndex);
    _publishVerticalFeedSettled(true);
  }

  void _maybeSyncScrubberVerticalFeedSettled(int feedIndex) {
    final controller = _pageController;
    var settled = true;
    if (controller != null && controller.hasClients) {
      final page = controller.page;
      if (page != null) {
        settled = verticalFeedPageSettled(pageOffset: page, feedIndex: feedIndex);
      }
    }
    if (_scrubberVerticalFeedSettled == settled) {
      // Keep provider aligned if leave-Browse reset raced ahead of feed.
      ref.read(mainBrowseVerticalFeedSettledProvider.notifier).setSettled(settled);
      return;
    }
    _publishVerticalFeedSettled(settled);
  }

  bool _handlePvTransitionScroll(ScrollNotification notification) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients || _ids.isEmpty) {
      return false;
    }
    final page = controller.page;
    if (page == null) {
      return false;
    }
    // Cap 15.11b: always read the live feed index — never use a build-time
    // captured value. After settle, ScrollUpdate can still arrive on the
    // pre-rebuild listener while page already sits on the new index; a stale
    // curIdx would re-arm toward the page we just settled on.
    final feedIndex = ref.read(mainBrowseFeedIndexProvider);
    if (notification is ScrollUpdateNotification ||
        notification is ScrollStartNotification ||
        notification is ScrollEndNotification) {
      _maybeSyncScrubberVerticalFeedSettled(feedIndex);
    }
    if (notification is ScrollEndNotification ||
        (notification is ScrollUpdateNotification &&
            (page - feedIndex).abs() < kVerticalFeedSettledPageEpsilon)) {
      if ((page - feedIndex).abs() < kVerticalFeedSettledPageEpsilon) {
        ref
            .read(pvTransitionGuardProvider.notifier)
            .maybeDisarmOnSettled(feedIndex);
      }
      return false;
    }
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollStartNotification) {
      return false;
    }
    final delta = page - feedIndex;
    if (delta.abs() < kVerticalFeedSettledPageEpsilon) {
      return false;
    }
    final targetIndex = delta > 0 ? feedIndex + 1 : feedIndex - 1;
    if (targetIndex < 0 || targetIndex >= _ids.length) {
      return false;
    }
    final displayGen = _activation.currentDisplayGate.generation;
    unawaited(
      ref
          .read(pvTransitionGuardProvider.notifier)
          .tryArmOnScroll(
            currentFeedIndex: feedIndex,
            targetFeedIndex: targetIndex,
            sourceAssetId: _ids[feedIndex],
            targetAssetId: _ids[targetIndex],
            displayGeneration: displayGen,
            displayGate: _activation.currentDisplayGate,
          ),
    );
    return false;
  }

  @visibleForTesting
  int get debugActivationBeginCount => _activation.debugBeginCount;

  @visibleForTesting
  PageController? get debugPageController => _pageController;

  @visibleForTesting
  FeedMediaRequestGate get debugCurrentDisplayGate =>
      _activation.currentDisplayGate;

  @visibleForTesting
  int get debugForegroundResumeSyncEpoch => _foregroundResumeSyncEpoch;

  /// Test seam: epoch-only rebuild path for foreground resume sync (W-18.4-E1).
  @visibleForTesting
  void debugBumpForegroundResumeSyncEpoch() {
    setState(() {
      _foregroundResumeSyncEpoch++;
    });
  }

  /// Invokes the same scroll arm path as [NotificationListener] (Cap 15.11 tests).
  ///
  /// [staleFeedIndexIgnored] is retained for call-site compatibility; arm/settle
  /// math always reads [mainBrowseFeedIndexProvider] live (15.11b stale-curIdx).
  @visibleForTesting
  void debugDispatchPvScrollArm(int staleFeedIndexIgnored) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    _handlePvTransitionScroll(
      ScrollUpdateNotification(
        metrics: controller.position,
        context: context,
        scrollDelta: 1,
      ),
    );
  }

  /// Scroll settled / end path → [PvTransitionGuardNotifier.maybeDisarmOnSettled].
  @visibleForTesting
  void debugDispatchPvScrollSettled(int settledFeedIndexIgnored) {
    final controller = _pageController;
    if (controller == null || !controller.hasClients) {
      return;
    }
    _handlePvTransitionScroll(
      ScrollEndNotification(metrics: controller.position, context: context),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Controller is created on first session build with the correct epoch /
    // landing page (see [_ensurePageControllerForEpoch]).
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachRestore());
  }

  void _ensurePageControllerForEpoch({
    required int roundEpoch,
    required int initialPage,
  }) {
    if (_pageController != null && _pageControllerEpoch == roundEpoch) {
      return;
    }
    final previous = _pageController;
    _pageControllerEpoch = roundEpoch;
    _pageController = PageController(initialPage: initialPage);
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous.dispose();
      });
    }
  }

  Future<void> _showNewRoundToastAfterAdvance({
    required AppLocalizations l10n,
    required int remountGen,
  }) async {
    // Slightly after jump/remount paint so toast is not same-frame as swap.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted || remountGen != _roundAdvanceGen) {
      return;
    }
    final enabled =
        await ref.read(newRoundToastPreferencesProvider).isNewRoundToastEnabled();
    if (!mounted || !enabled) {
      return;
    }
    // Scheme A always lands on feedIndex 0 after advance.
    if (ref.read(mainBrowseFeedIndexProvider) != 0) {
      return;
    }
    const toastKey = Key('mainBrowseNewRoundToast');
    _newRoundToastDismissArmed = true;
    _newRoundToastLandingFeedIndex = 0;
    showCap19BrowseToast(
      context,
      message: l10n.mainBrowseNewRoundToast,
      toastKey: toastKey,
    );
    Future<void>.delayed(kCap19BrowseToastDuration, () {
      if (mounted && _newRoundToastLandingFeedIndex == 0) {
        _newRoundToastDismissArmed = false;
        _newRoundToastLandingFeedIndex = null;
      }
    });
  }

  void _attachRestore() {
    final playback = ref.read(playbackRepositoryProvider);
    _restoreSub?.cancel();
    _restoreSub = playback.restoreRequests.listen((req) {
      final queueLen = _ids.length;
      if (queueLen <= 0) {
        return;
      }
      final notifier = ref.read(mainBrowseFeedIndexProvider.notifier);
      notifier.applyRestoreIndex(req.feedIndex, queueLen);
      final target = ref.read(mainBrowseFeedIndexProvider);
      final controller = _pageController;
      if (controller != null && controller.hasClients) {
        controller.jumpToPage(target);
      }
    });
  }

  @override
  void dispose() {
    _roundAdvanceGen++;
    WidgetsBinding.instance.removeObserver(this);
    _restoreSub?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _lastLifecycle;
    _lastLifecycle = state;

    final coordinator = ref.read(playbackCoordinatorProvider);
    final assetId = _activeAssetId;
    final displayGen = _activeDisplayGeneration;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (assetId != null && displayGen != null) {
        unawaited(
          coordinator.onLeaveForeground(
            assetIdentifier: assetId,
            displayGeneration: displayGen,
            displayGate: _activation.currentDisplayGate,
          ),
        );
      }
      return;
    }

    if (state != AppLifecycleState.resumed) {
      return;
    }

    // China-SKU wireless-data alert: typically inactive→resumed (app never
    // backgrounds). True background uses paused→resumed. Listen for both.
    if (previous == AppLifecycleState.inactive ||
        previous == AppLifecycleState.paused ||
        previous == AppLifecycleState.hidden) {
      setState(() {
        _foregroundResumeSyncEpoch++;
      });
    } else {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(browseL2ReadySessionProvider.notifier)
            .evictEntriesWithMissingPathsAsync(),
      );
    });
  }

  /// Hard constraint: metadata + current-display [begin] in one synchronous call.
  /// No [setState] — [build] assigns fields then reads them in the same frame.
  void _beginCurrentItemActivation(String assetId, {required String source}) {
    final gens = _activation.beginCurrentItem();
    final cached = _overlayCache[assetId];
    _activeAssetId = assetId;
    _activeDisplayGeneration = gens.display;
    _overlaySnapshot =
        cached ?? PresentationOverlaySnapshot(assetIdentifier: assetId);
    // Hydrate shared size from private cache when provider has no entry yet
    // (session restore / first read after Cap 26.4 wiring).
    final shared = ref.read(presentationSizeCacheProvider)[assetId];
    if (shared == null &&
        cached != null &&
        (cached.fileSizeBytes != null ||
            cached.fileSizeSemantics != null)) {
      ref.read(presentationSizeCacheProvider.notifier).apply(
            assetId,
            PresentationFileSize(
              assetIdentifier: assetId,
              fileSizeBytes: cached.fileSizeBytes,
              fileSizeSemantics: cached.fileSizeSemantics,
            ),
          );
    }
    _syncOverlaySizeFromSharedCache(assetId);
    unawaited(_loadOverlay(gens.metadata, assetId));
  }

  void _activateCurrentItem(String assetId) {
    if (_activeAssetId == assetId &&
        _activeDisplayGeneration == _activation.currentDisplayGate.generation) {
      return;
    }
    _beginCurrentItemActivation(assetId, source: 'page_changed');
    setState(() {});
  }

  /// Layer-2 (still) / video surface-ready. Does not bump [beginCurrentItem].
  void _onCurrentLayer2MediaReady(String assetId) {
    if (!mounted || _activeAssetId != assetId) {
      return;
    }
    if (_overlaySnapshot?.assetIdentifier == assetId &&
        _overlaySnapshot?.fileSizeBytes != null) {
      return;
    }
    final generation = _activation.metadataGate.generation;
    unawaited(_refreshOverlaySize(generation, assetId));
  }

  void _commitOverlaySize(String assetId, PresentationFileSize size) {
    ref.read(presentationSizeCacheProvider.notifier).apply(assetId, size);
    _syncOverlaySizeFromSharedCache(assetId);
  }

  /// Mirror shared size into the private Overlay snapshot (Cap 26.4).
  /// Authority is [presentationSizeCacheProvider]; this keeps MediaInfoOverlay
  /// props unchanged.
  void _syncOverlaySizeFromSharedCache(String assetId) {
    if (!mounted || assetId.isEmpty) {
      return;
    }
    final entry = ref.read(presentationSizeCacheProvider)[assetId];
    if (entry == null || !entry.resolved) {
      return;
    }
    final base = (_overlaySnapshot?.assetIdentifier == assetId)
        ? _overlaySnapshot!
        : PresentationOverlaySnapshot(assetIdentifier: assetId);
    if (base.fileSizeBytes == entry.fileSizeBytes &&
        base.fileSizeSemantics == entry.fileSizeSemantics) {
      return;
    }
    final next = PresentationOverlaySnapshot(
      assetIdentifier: base.assetIdentifier,
      createdAt: base.createdAt,
      mediaKind: base.mediaKind,
      isAnimated: base.isAnimated,
      fileSizeBytes: entry.fileSizeBytes,
      fileSizeSemantics: entry.fileSizeSemantics,
      locationLabel: base.locationLabel,
    );
    setState(() {
      _overlaySnapshot = next;
      _overlayCache[assetId] = next;
    });
  }

  Future<void> _refreshOverlaySize(
    int metadataGeneration,
    String assetId,
  ) async {
    final repo = ref.read(presentationMetadataRepositoryProvider);
    try {
      final size = await repo.requestPresentationFileSize(assetId);
      if (!mounted || !_activation.metadataGate.isCurrent(metadataGeneration)) {
        return;
      }
      if (_activeAssetId != assetId) {
        return;
      }
      _commitOverlaySize(assetId, size);
    } catch (_) {
      // Size stays blank.
    }
  }

  Future<void> _loadOverlay(int metadataGeneration, String assetId) async {
    final repo = ref.read(presentationMetadataRepositoryProvider);
    try {
      final meta = await repo.requestPresentationMetadata(assetId);
      if (!mounted || !_activation.metadataGate.isCurrent(metadataGeneration)) {
        return;
      }
      setState(() {
        final base = (_overlaySnapshot?.assetIdentifier == assetId)
            ? _overlaySnapshot!
            : PresentationOverlaySnapshot(assetIdentifier: assetId);
        final next = base.mergeBasics(meta);
        _overlaySnapshot = next;
        _overlayCache[assetId] = next;
      });
    } catch (_) {
      // Leave fields blank; do not block playback.
    }
    try {
      final size = await repo.requestPresentationFileSize(assetId);
      if (!mounted || !_activation.metadataGate.isCurrent(metadataGeneration)) {
        return;
      }
      _commitOverlaySize(assetId, size);
    } catch (_) {
      // Size stays blank.
    }
  }

  /// Cap 22.5 scheme A: clear Cap19 drag, leave current, reshuffle + remount
  /// at index 0, then toast. Shared by placeholder ScrollEnd settle and
  /// true trailing overscroll.
  void _advanceEndlessRound({required AppLocalizations l10n}) {
    if (_advancingRound) {
      return;
    }
    final queueLength =
        ref.read(browseSessionProvider).asData?.value.orderedAssetIds.length ??
            0;
    if (queueLength <= 1) {
      return;
    }
    _advancingRound = true;
    _endlessPlaceholderArmed = false;
    final remountGen = ++_roundAdvanceGen;
    _clearCap19LeftSwipeBeforeFeedRemount();
    unawaited(ref.read(playbackCoordinatorProvider).onLeaveCurrent());
    ref.read(browseSessionProvider.notifier).advanceToNextRound();
    ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || remountGen != _roundAdvanceGen) {
        return;
      }
      final controller = _pageController;
      if (controller != null && controller.hasClients) {
        controller.jumpToPage(0);
      }
      _advancingRound = false;
      unawaited(
        _showNewRoundToastAfterAdvance(
          l10n: l10n,
          remountGen: remountGen,
        ),
      );
    });
  }

  /// Cap 22.5: drop in-flight Cap 19 left-swipe drag before page tree
  /// swaps (roundEpoch remount). Complements mounted guards on
  /// [Cap19LeftSwipeGesture] — remount can dispose the Listener while a
  /// pointer is still tracked.
  void _clearCap19LeftSwipeBeforeFeedRemount() {
    ref.read(cap19LeftSwipeDragProvider.notifier).reset();
  }

  /// Test seam: arm + show starting-over toast (skips prefs / remount delay).
  @visibleForTesting
  void debugShowNewRoundToastArmed(AppLocalizations l10n, {int landingIndex = 0}) {
    _newRoundToastDismissArmed = true;
    _newRoundToastLandingFeedIndex = landingIndex;
    showCap19BrowseToast(
      context,
      message: l10n.mainBrowseNewRoundToast,
      toastKey: const Key('mainBrowseNewRoundToast'),
    );
  }

  @visibleForTesting
  bool get debugNewRoundToastDismissOnLeaveHead => _newRoundToastDismissArmed;

  @visibleForTesting
  int? get debugNewRoundToastLandingFeedIndex => _newRoundToastLandingFeedIndex;

  void _dismissNewRoundToastIfLeavingLanding(int previousIndex, int nextIndex) {
    if (!_newRoundToastDismissArmed) {
      return;
    }
    final landing = _newRoundToastLandingFeedIndex;
    if (landing == null) {
      return;
    }
    if (previousIndex == landing && nextIndex != landing) {
      _newRoundToastDismissArmed = false;
      _newRoundToastLandingFeedIndex = null;
      if (cap19BrowseToastActiveKey == const Key('mainBrowseNewRoundToast')) {
        hideCap19BrowseToast();
      }
    }
  }

  void _dismissNewRoundToastBecauseLeftBrowse() {
    if (!_newRoundToastDismissArmed) {
      return;
    }
    _newRoundToastDismissArmed = false;
    _newRoundToastLandingFeedIndex = null;
    if (cap19BrowseToastActiveKey == const Key('mainBrowseNewRoundToast')) {
      hideCap19BrowseToast();
    }
  }

  void _noteLayer1Seed(String assetId, FeedPageMedia media) {
    final display = media.display;
    if (display == null || display.assetIdentifier != assetId) {
      return;
    }
    // Still L1 or video poster — enough to cover remount for stills pools.
    if (media.kind != FeedPageMediaKind.still &&
        media.kind != FeedPageMediaKind.video) {
      return;
    }
    _layer1Seeds[assetId] = media;
  }

  @visibleForTesting
  void debugPutLayer1Seed(String assetId, FeedPageMedia media) {
    _noteLayer1Seed(assetId, media);
  }

  @visibleForTesting
  FeedPageMedia? debugLayer1Seed(String assetId) => _layer1Seeds[assetId];

  /// Cap 22.5 scheme A: advance only on true [ScrollEndNotification] while
  /// the placeholder page is settled ([verticalFeedPageSettled]).
  void _maybeAdvanceOnPlaceholderSettle({
    required ScrollNotification notification,
    required double page,
    required int sessionLength,
    required AppLocalizations l10n,
  }) {
    if (!_endlessPlaceholderArmed || _advancingRound) {
      return;
    }
    if (notification is! ScrollEndNotification) {
      return;
    }
    if (sessionLength <= 1) {
      return;
    }
    final placeholderIndex = sessionLength;
    if (!verticalFeedPageSettled(
      pageOffset: page,
      feedIndex: placeholderIndex,
    )) {
      return;
    }
    _advanceEndlessRound(l10n: l10n);
  }

  /// Test seam: Cap 22.5 scheme A advance (same as placeholder ScrollEnd /
  /// trailing overscroll). Prefer this when widget-test ScrollEnd settle is
  /// flaky.
  @visibleForTesting
  void debugAdvanceEndlessRound(AppLocalizations l10n) {
    _advanceEndlessRound(l10n: l10n);
  }

  Set<int> _preheatWindow(int feedIndex, int n, bool browseActive) {
    if (!browseActive || n <= 0 || feedIndex < 0) {
      return <int>{};
    }
    final window = <int>{feedIndex};
    if (feedIndex - 1 >= 0) {
      window.add(feedIndex - 1);
    }
    if (feedIndex + 1 < n) {
      window.add(feedIndex + 1);
    }
    return window;
  }

  /// Phase A: shrink flags this frame. Phase B (async): await [releasePreview]
  /// then expand [_allowedPreheatIndices].
  void _notePreheatInputs({
    required bool browseActive,
    required int feedIndex,
    required int queueLength,
    required int roundEpoch,
  }) {
    if (_preheatTrackedBrowse == browseActive &&
        _preheatTrackedIndex == feedIndex &&
        _preheatTrackedLength == queueLength &&
        _preheatTrackedEpoch == roundEpoch) {
      return;
    }
    _preheatTrackedBrowse = browseActive;
    _preheatTrackedIndex = feedIndex;
    _preheatTrackedLength = queueLength;
    _preheatTrackedEpoch = roundEpoch;
    final newWindow = _preheatWindow(feedIndex, queueLength, browseActive);
    final newNeighbors = newWindow.difference({feedIndex});
    _allowedPreheatIndices = _allowedPreheatIndices.intersection(newNeighbors);
    if (_ids.isNotEmpty) {
      _preheatIdSnapshot = List<String>.from(_ids);
    }
    unawaited(
      _syncPreheatWindow(
        plannedIndex: feedIndex,
        browseActive: browseActive,
        ids: _preheatIdSnapshot,
      ),
    );
  }

  Future<void> _syncPreheatWindow({
    required int plannedIndex,
    required bool browseActive,
    required List<String> ids,
  }) async {
    final gen = ++_preheatSyncGen;
    final newWindow = _preheatWindow(plannedIndex, ids.length, browseActive);
    final newNeighbors = newWindow.difference({plannedIndex});
    final leavingIds = <String>[];
    for (final i in _committedPreheatWindow.difference(newWindow)) {
      if (i >= 0 && i < ids.length) {
        leavingIds.add(ids[i]);
      }
    }
    if (leavingIds.isNotEmpty) {
      final display = ref.read(mediaDisplayRepositoryProvider);
      try {
        await Future.wait<void>(leavingIds.map(display.releasePreview));
      } catch (_) {}
    } else {
      // Yield so Phase B setState cannot run synchronously during build
      // (empty leaving has no await from Future.wait).
      await Future<void>.value();
    }
    if (!mounted || gen != _preheatSyncGen) {
      return;
    }
    if (ref.read(mainBrowseFeedIndexProvider) != plannedIndex) {
      return;
    }
    final nowBrowse =
        ref.read(mainBrowseDestinationProvider) == MainBrowseDestination.browse;
    if (nowBrowse != browseActive) {
      return;
    }
    setState(() {
      _allowedPreheatIndices = newNeighbors;
      _committedPreheatWindow = newWindow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncSession = ref.watch(browseSessionProvider);
    final chrome = ref.watch(browseChromeStateProvider);
    final feedDataSourceId = ref.watch(browseEffectiveFeedDataSourceIdProvider);
    final feedSourceKind = chrome.feedSourceKind;
    final feedIndex = ref.watch(mainBrowseFeedIndexProvider);
    final destination = ref.watch(mainBrowseDestinationProvider);
    // Cap 26.4: half-sheet (or any apply) updates shared size → mirror Overlay.
    ref.listen<Map<String, PresentationSizeEntry>>(
      presentationSizeCacheProvider,
      (previous, next) {
        final id = _activeAssetId;
        if (id == null || id.isEmpty) {
          return;
        }
        final prevEntry = previous?[id];
        final nextEntry = next[id];
        if (nextEntry == null || !nextEntry.resolved) {
          return;
        }
        if (prevEntry?.fileSizeBytes == nextEntry.fileSizeBytes &&
            prevEntry?.fileSizeSemantics == nextEntry.fileSizeSemantics &&
            prevEntry?.resolved == nextEntry.resolved) {
          return;
        }
        _syncOverlaySizeFromSharedCache(id);
      },
    );
    ref.listen(mainBrowseFeedIndexProvider, (previous, next) {
      if (previous != next) {
        ref.read(pvTransitionGuardProvider.notifier).onFeedIndexChanged(next);
      }
      if (previous != null && previous != next) {
        _dismissNewRoundToastIfLeavingLanding(previous, next);
      }
    });
    ref.listen(mainBrowseDestinationProvider, (previous, next) {
      if (previous == MainBrowseDestination.browse &&
          next != MainBrowseDestination.browse) {
        _clearMagnificationSession();
        _dismissNewRoundToastBecauseLeftBrowse();
        unawaited(
          ref
              .read(pvTransitionGuardProvider.notifier)
              .disarm(reason: 'leave-browse'),
        );
      }
    });
    ref.listen<BrowseMagnificationState>(browseMagnificationProvider, (
      previous,
      next,
    ) {
      if (previous != null &&
          !previous.locksVerticalPageView &&
          next.locksVerticalPageView) {
        _snapVerticalFeedToCurrentIfMidScroll();
      }
    });
    final browseActive = destination == MainBrowseDestination.browse;
    if (browseActive && !_browseWasActive) {
      _browseResumeLatch = true;
      _generationWhenLatchArmed = _activation.currentDisplayGate.generation;
    }
    _browseWasActive = browseActive;

    // Cap 21.4b: Build a Pool cover — user-intent pause so the center play
    // affordance is ready under the route and visible on pop (one tap to
    // resume). Do not auto-resume on close (that was empty-frame / double-tap).
    ref.listen<bool>(browseCoveringRouteOpenProvider, (previous, next) {
      if (next) {
        unawaited(ref.read(playbackCoordinatorProvider).onBrowseCoverOpened());
      }
    });

    // Cap 9.6: video host has no persisted mute — push preference on change.
    ref.listen<bool>(sharedMuteProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      unawaited(ref.read(playbackRepositoryProvider).setMute(next));
    });

    ref.listen<BrowseOrigin>(
      browseChromeStateProvider.select((s) => s.activeOrigin),
      (prev, next) {
        if (prev == null || prev == next) {
          return;
        }
        // ADR-057 D3: shared signal only — no private promote heuristic.
        if (ref
            .read(browseOriginSessionDeltaProvider)
            .isIdentityPreservingPromote) {
          return;
        }
        _clearMagnificationSession();
        unawaited(ref.read(playbackCoordinatorProvider).onLeaveCurrent());
      },
    );

    ref.listen<int>(mainBrowseFeedIndexProvider, (prev, next) {
      final controller = _pageController;
      if (controller == null || !controller.hasClients) {
        return;
      }
      if (controller.page?.round() != next) {
        controller.jumpToPage(next);
      }
      if (_ids.isNotEmpty && next >= 0 && next < _ids.length) {
        _activateCurrentItem(_ids[next]);
      }
    });

    return ColoredBox(
      key: const Key('mainBrowseFeed'),
      color: tokens.feedBackground,
      child: asyncSession.when(
        loading: () {
          _notePreheatInputs(
            browseActive: false,
            feedIndex: 0,
            queueLength: 0,
            roundEpoch: -1,
          );
          return Center(
            key: const Key('mainBrowseFeedLoading'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: tokens.brandGold),
                const SizedBox(height: 16),
                Text(l10n.mainBrowseFeedLoading, style: tokens.bodyOnMedia),
              ],
            ),
          );
        },
        error: (error, stackTrace) {
          _notePreheatInputs(
            browseActive: false,
            feedIndex: 0,
            queueLength: 0,
            roundEpoch: -1,
          );
          return _BrowseStatusPanel(
            // Resolve-level failure path (source could not load).
            panelKey: const Key('mainBrowseFeedResolveFailed'),
            message: l10n.mainBrowseFeedResolveFailed,
            actionLabel: l10n.mainBrowseFeedRetry,
            actionKey: const Key('mainBrowseFeedRetry'),
            onAction: () => ref.invalidate(browseSessionProvider),
          );
        },
        data: (view) {
          final snapshot = view.session.snapshot;
          final ids = view.orderedAssetIds;
          final previousDataSourceId = _lastDataSourceId;
          // ADR-039: delay only on All/Photos/Videos/pool origin change
          // ([feedDataSourceId]). roundEpoch remount from
          // [advanceToNextRound] keeps the same origin — must not arm.
          final delayInitialLayer1CenterLabel =
              previousDataSourceId != null &&
              previousDataSourceId != feedDataSourceId;
          debugLastDelayInitialLayer1CenterLabel =
              delayInitialLayer1CenterLabel;
          if (previousDataSourceId != null &&
              previousDataSourceId != feedDataSourceId) {
            // Build path — mutate local only; publish after frame (no setState).
            _scrubberVerticalFeedSettled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              ref
                  .read(mainBrowseVerticalFeedSettledProvider.notifier)
                  .setSettled(true);
            });
          }
          _lastDataSourceId = feedDataSourceId;
          _ids = ids;
          _notePreheatInputs(
            browseActive: browseActive,
            feedIndex: feedIndex,
            queueLength: ids.length,
            roundEpoch: view.roundEpoch,
          );
          if (ids.isEmpty) {
            final hardFailure = view.session.snapshot.sourceStatuses.any(
              (s) =>
                  s.availability == AssetSourceAvailability.unauthorized ||
                  s.availability == AssetSourceAvailability.unavailable,
            );
            if (hardFailure) {
              return _BrowseStatusPanel(
                panelKey: const Key('mainBrowseFeedResolveFailed'),
                message: l10n.mainBrowseFeedResolveFailed,
                actionLabel: l10n.mainBrowseFeedRetry,
                actionKey: const Key('mainBrowseFeedRetry'),
                onAction: () => ref.invalidate(browseSessionProvider),
              );
            }
            return _BrowseStatusPanel(
              // Resolve-level empty path (source resolved to zero items).
              panelKey: const Key('mainBrowseFeedEmpty'),
              message: l10n.mainBrowseFeedEmpty,
            );
          }
          if (feedIndex >= ids.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
            });
          }
          final safeIndex = feedIndex.clamp(0, ids.length - 1);
          // Cap 22.5 scheme A: recreate PageController when roundEpoch bumps
          // so remount lands on index 0, not a stale initialPage.
          _ensurePageControllerForEpoch(
            roundEpoch: view.roundEpoch,
            initialPage: safeIndex,
          );
          final currentId = ids[safeIndex];
          // Sync activate in this build so the current page receives
          // assignedDisplayGeneration before its first _startLoad.
          // _browseResumeLatch: Clips/Auto/Settings keep this State
          // (IndexedStack). Bump display+metadata together so in-flight
          // loads cannot share the pre-leave generation (14.4c A/C).
          // Recreate is covered by _activeDisplayGeneration == null.
          if (_browseResumeLatch) {
            _browseResumeLatch = false;
            final alreadyBumpedThisResume =
                _generationWhenLatchArmed != null &&
                _activation.currentDisplayGate.generation !=
                    _generationWhenLatchArmed;
            if (!alreadyBumpedThisResume) {
              _beginCurrentItemActivation(currentId, source: 'build_sync');
            }
          } else if (_activeAssetId != currentId ||
              _activeDisplayGeneration == null) {
            _beginCurrentItemActivation(currentId, source: 'build_sync');
          }
          final pageItemCount =
              ids.length > 1 ? ids.length + 1 : ids.length;
          return Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (_advancingRound) {
                    return false;
                  }
                  if (isEndlessRoundAdvanceScroll(notification)) {
                    _advanceEndlessRound(l10n: l10n);
                  }
                  final page = _pageController?.page;
                  if (page != null) {
                    _maybeAdvanceOnPlaceholderSettle(
                      notification: notification,
                      page: page,
                      sessionLength: ids.length,
                      l10n: l10n,
                    );
                  }
                  _handlePvTransitionScroll(notification);
                  return false;
                },
                child: MagnificationPointerHost(
                  child: PageView.builder(
                  key: ValueKey<String>(
                    'feed-$feedDataSourceId-r${view.roundEpoch}',
                  ),
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  physics: ref.watch(browseMagnificationProvider).locksVerticalPageView
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  // This SDK's PageView.builder has no cacheExtent; true sets
                  // Viewport cacheExtent to 1.0 viewport (±1 pages).
                  allowImplicitScrolling: true,
                  itemCount: pageItemCount,
                  onPageChanged: (i) {
                    _clearMagnificationSession();
                    if (ids.length > 1 &&
                        i == ids.length &&
                        !_advancingRound) {
                      // Scheme A: arm placeholder only — wait for ScrollEnd
                      // settle. Do not setIndex(placeholder).
                      _endlessPlaceholderArmed = true;
                      return;
                    }
                    _endlessPlaceholderArmed = false;
                    if (i >= ids.length) {
                      return;
                    }
                    ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(i);
                    _publishVerticalFeedSettled(true);
                  },
                  itemBuilder: (context, index) {
                    if (index >= ids.length) {
                      // Scheme A forge: center "Loading item" only — not a
                      // real Layer-1 miss/`_loading` page. Corner gold
                      // spinner would read as live work on a fake page.
                      return AbsorbPointer(
                        key: const Key('mainBrowseEndlessRoundPlaceholder'),
                        child: ColoredBox(
                          color: tokens.feedBackground,
                          child: _UsableRegionCenter(
                            child: ExcludeSemantics(
                              child: Text(
                                l10n.mainBrowseFeedLayer1Loading,
                                key: const Key(
                                  'mainBrowseFeedCoverlessWaitLabel',
                                ),
                                textAlign: TextAlign.center,
                                style: tokens.labelOnMedia.copyWith(
                                  color: tokens.onMedia,
                                  shadows: tokens.onMediaLabelShadows,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final isCurrent = browseActive && index == feedIndex;
                    final isPreheatNeighbor =
                        browseActive &&
                        !isCurrent &&
                        _allowedPreheatIndices.contains(index);
                    final verticalFeedSettled = _scrubberVerticalFeedSettled;
                    return MediaFeedPage(
                      key: ValueKey<String>(
                        'page-${ids[index]}-$index-r${view.roundEpoch}',
                      ),
                      assetIdentifier: ids[index],
                      feedIndex: index,
                      sourceKind: feedSourceKind,
                      listTimeAvailability: snapshot.availabilityFor(
                        ids[index],
                      ),
                      isCurrent: isCurrent,
                      showMediaInfoOverlay: isCurrent && browseActive,
                      overlaySnapshot: _overlaySnapshot,
                      verticalFeedSettled: verticalFeedSettled,
                      isPreheatNeighbor: isPreheatNeighbor,
                      liveHostSerial: liveHostSerial,
                      currentDisplayGate: isCurrent
                          ? _activation.currentDisplayGate
                          : null,
                      assignedDisplayGeneration: isCurrent
                          ? _activeDisplayGeneration
                          : null,
                      delayInitialLayer1CenterLabel:
                          isCurrent && delayInitialLayer1CenterLabel,
                      foregroundResumeSyncEpoch: _foregroundResumeSyncEpoch,
                      onCurrentLayer2MediaReady: isCurrent
                          ? _onCurrentLayer2MediaReady
                          : null,
                      initialLayer1: _layer1Seeds[ids[index]],
                      onLayer1Available: _noteLayer1Seed,
                    );
                  },
                ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BrowseStatusPanel extends StatelessWidget {
  /// Shared presentation shell for Browse status copy (+ optional Retry).
  ///
  /// Call sites stay separate: resolve-level empty/error vs per-page
  /// iCloud/failed decide *when* to show this panel and which ARB strings
  /// to pass — this widget only paints.
  const _BrowseStatusPanel({
    required this.message,
    this.panelKey,
    this.actionLabel,
    this.actionKey,
    this.onAction,
  });

  final Key? panelKey;
  final String message;
  final String? actionLabel;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Center(
      key: panelKey,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: tokens.bodyOnMedia,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              _BrowseRetryButton(
                buttonKey: actionKey,
                label: actionLabel!,
                onPressed: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Explicit Retry CTA: translucent white fill (does not fully occlude
/// media) + [WakeTokTokens.accent] label. Shared by resolve / page-fail
/// panels and the coverless Layer-2 fail slot.
class _BrowseRetryButton extends StatelessWidget {
  const _BrowseRetryButton({
    required this.label,
    required this.onPressed,
    this.buttonKey,
  });

  /// White fill opacity over feed media — readable chip, not an opaque slab.
  static const double _fillOpacity = 0.28;

  final Key? buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: tokens.accent,
        backgroundColor: tokens.onMedia.withValues(alpha: _fillOpacity),
        disabledForegroundColor: tokens.accent.withValues(alpha: 0.5),
        disabledBackgroundColor: tokens.onMedia.withValues(
          alpha: _fillOpacity * 0.5,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        minimumSize: const Size(88, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: tokens.labelOnMedia.copyWith(color: tokens.accent),
      ),
    );
  }
}

/// Feed-scoped serial queue for Live Host API calls (Cap 9.4 / F4).
///
/// Host `cancel` / `requestLivePhoto` have no independent mutex — Feed must
/// not invoke them concurrently. Scoped at the feed (not page) so leave on
/// one [MediaFeedPage] State cannot race request on a re-created State.
class LiveHostOpSerial {
  Future<void> _chain = Future<void>.value();

  Future<void> enqueue(Future<void> Function() op) {
    final next = _chain.then((_) => op());
    _chain = next.catchError((_) {});
    return next;
  }
}

/// One PageView child: still / video / error with generation-gated loads.
class MediaFeedPage extends ConsumerStatefulWidget {
  const MediaFeedPage({
    super.key,
    required this.assetIdentifier,
    required this.feedIndex,
    required this.sourceKind,
    this.listTimeAvailability,
    required this.isCurrent,
    required this.showMediaInfoOverlay,
    this.overlaySnapshot,
    required this.verticalFeedSettled,
    required this.isPreheatNeighbor,
    required this.liveHostSerial,
    this.currentDisplayGate,
    this.assignedDisplayGeneration,
    this.delayInitialLayer1CenterLabel = false,
    this.foregroundResumeSyncEpoch = 0,
    this.onCurrentLayer2MediaReady,
    this.initialLayer1,
    this.onLayer1Available,
  });

  final String assetIdentifier;
  final int feedIndex;
  final AssetSourceKind sourceKind;

  /// List-time availability from Session Snapshot resolve (Cap 15.12).
  final AssetAvailability? listTimeAvailability;
  final bool isCurrent;
  final bool showMediaInfoOverlay;
  final PresentationOverlaySnapshot? overlaySnapshot;
  final bool verticalFeedSettled;

  /// Cap 14.5: ±1 neighbour allowed to [requestPreview] after parent release.
  final bool isPreheatNeighbor;
  final LiveHostOpSerial liveHostSerial;

  /// When current: feed-owned gate already begun in [_activateCurrentItem].
  final FeedMediaRequestGate? currentDisplayGate;
  final int? assignedDisplayGeneration;

  /// ADR-039: only the first current page mounted after a source switch delays
  /// visible Layer-1 center copy. Corner spinner + semantics stay immediate.
  final bool delayInitialLayer1CenterLabel;

  /// Feed-owned nonce; bump on lifecycle foreground resume (Cap 18.4).
  final int foregroundResumeSyncEpoch;

  /// Current page only. Parent reads metadata generation at callback time.
  final void Function(String assetId)? onCurrentLayer2MediaReady;

  /// Cap 22.5: seed still/poster Layer 1 across roundEpoch remount.
  final FeedPageMedia? initialLayer1;

  /// Notifies parent when a still (or video poster) Layer 1 is available.
  final void Function(String assetId, FeedPageMedia media)? onLayer1Available;

  static const String playbackViewType = 'waketok/playback_surface';
  static const String livePhotoViewType = 'waketok/live_photo_surface';

  @override
  ConsumerState<MediaFeedPage> createState() => MediaFeedPageState();
}

/// Public for Cap 9.5 L-S6 `@visibleForTesting` seam ([debugSetLivePreparing]).
class MediaFeedPageState extends ConsumerState<MediaFeedPage>
    with WidgetsBindingObserver {
  /// Cap 9.4 / F4: per Live activation token (not assetId alone).
  final FeedMediaRequestGate _liveMotionGate = FeedMediaRequestGate();

  /// Cap 14.5: neighbour preheat [requestPreview] generation.
  final FeedMediaRequestGate _localGate = FeedMediaRequestGate();
  FeedPageMedia? _media;
  bool _loading = true;
  bool _surfaceReady = false;
  bool _layer2InFlight = false;

  /// Which display-gate generation last armed [_layer2InFlight].
  /// Abandon clears only when this still matches — never clobber a newer arm.
  int? _layer2InFlightGeneration;

  /// Cap 17.3: path-class for wait chrome (set before / at arm).
  WaitChromePathClass _layer2WaitPath = WaitChromePathClass.a2WaitToPlayable;
  DateTime? _layer2InFlightArmedAt;
  Timer? _a4ChromeRevealTimer;
  bool _layer2Failed = false;
  FeedFailureReason? _layer2FailureReason;

  /// Still/poster [Image] decode/read failed — hide Meta until a healthy
  /// cover is applied (orthogonal to [_layer2InFlight]).
  bool _stillCoverDecodeBroken = false;

  /// True after [Image.frameBuilder] reports a decoded frame for the current
  /// cover path. False while FileImage is still resolving (black shell) so
  /// Meta / gold spinner cannot paint over an empty cover before
  /// [errorBuilder] or a successful frame (device: deleted-item flash).
  bool _stillCoverReady = false;

  /// Path [_stillCoverReady] / broken tracking is armed for.
  String? _stillCoverTrackedPath;

  /// Cap 21.6: Host `assetUnavailable` fail chrome (page-failed or coverless).
  bool get _isAssetUnavailableFailure {
    if (_media?.kind == FeedPageMediaKind.failed &&
        _media!.failureReason == FeedFailureReason.assetUnavailable) {
      return true;
    }
    return _layer2Failed &&
        _layer2FailureReason == FeedFailureReason.assetUnavailable;
  }

  /// After Host Case B, next become-current must not [reuseLayer1] /
  /// `_retryLayer2Only` (neighbour preheat L1 can stick forever when Photos
  /// restores the asset). Cleared only on L2 success. Staying parked on B
  /// does not auto-retry (owner-accepted).
  bool _needsFullReloadAfterHostUnavailable = false;

  /// Hide Meta Overlay while a still/poster cover is mounted but unresolved
  /// or decode-broken. Cap 26.4b: does **not** gate corner wait spinner / LIVE
  /// (see [_suppressStillCoverWaitChrome]).
  bool get _suppressStillCoverMeta {
    if (_media?.display == null) {
      return false;
    }
    return !_stillCoverReady || _stillCoverDecodeBroken;
  }

  /// Hide corner wait spinner + LIVE badge only when still/poster decode is
  /// **broken**. Unresolved (path tracked, first frame not yet ready) keeps
  /// spinner/LIVE so Limited iCloud Live does not flash LIVE-alone (Cap 26.4b).
  /// Coverless / pendingVideo: no display → false (Cap 17 corner chrome stays).
  bool get _suppressStillCoverWaitChrome {
    if (_media?.display == null) {
      return false;
    }
    return _stillCoverDecodeBroken;
  }

  /// Hide Cap 8 Overlay while Host reports the asset is gone (contradicts
  /// date/size chrome). Also hide during page `_loading` ("Loading item") so
  /// a prior-visit Overlay cache cannot flash one frame before L2 fail.
  /// Hide while still/poster has no decoded frame yet or decode is broken —
  /// not tied to [_layer2InFlight] (normal L2 wait with a painted cover keeps
  /// Overlay + spinner). Download / generic fails (with media on screen) may
  /// still show Overlay.
  bool get _showMediaInfoOverlayEffective =>
      widget.showMediaInfoOverlay &&
      !_loading &&
      !_isAssetUnavailableFailure &&
      !_suppressStillCoverMeta;

  /// When [path] changes, mark cover unresolved until frameBuilder / broken.
  ///
  /// Cap 26.4a: same-page still (incl. Live static) L1→L2 cover upgrade keeps
  /// ready so Meta Overlay is not torn down while Cap 15.5 gaplessPlayback
  /// holds the prior frame — see layout notes §13.
  void _trackStillCoverPath(String? path, {bool clearBroken = true}) {
    if (path != _stillCoverTrackedPath) {
      final keepReadyAcrossStillCoverUpgrade = path != null &&
          _stillCoverTrackedPath != null &&
          _stillCoverReady &&
          !_stillCoverDecodeBroken &&
          _media?.kind == FeedPageMediaKind.still;

      _stillCoverTrackedPath = path;
      if (!keepReadyAcrossStillCoverUpgrade) {
        _stillCoverReady = false;
      }
    }
    if (clearBroken) {
      _stillCoverDecodeBroken = false;
    }
  }

  void _clearStillCoverTracking() {
    _stillCoverTrackedPath = null;
    _stillCoverReady = false;
    _stillCoverDecodeBroken = false;
  }

  void _onStillCoverFrameReady() {
    if (!mounted) {
      return;
    }
    final path = _media?.display?.localFilePath;
    if (path == null || path != _stillCoverTrackedPath) {
      return;
    }
    if (_stillCoverReady && !_stillCoverDecodeBroken) {
      return;
    }
    setState(() {
      _stillCoverReady = true;
      _stillCoverDecodeBroken = false;
    });
    _syncMediaCoverVisibleGate();
  }

  bool _computeMediaCoverVisible() {
    final media = _media;
    return mediaCoverVisiblePredicate(
      loading: _loading,
      liveMotionMounted: _liveMotionMounted,
      hasDisplay: media?.display != null,
      stillCoverReady: _stillCoverReady,
      stillCoverDecodeBroken: _stillCoverDecodeBroken,
      isVideo: media?.kind == FeedPageMediaKind.video,
      surfaceReady: _surfaceReady,
    );
  }

  /// Cap 26.4c / ADR-054: publish cover-visible to shell Action Column.
  ///
  /// Shared provider — **current page only**. Off-current callers (neighbour
  /// preheat [_onStillCoverFrameReady], etc.) must not write: previously
  /// `isCurrent && compute` published `false` and wiped the current page's
  /// `true` (Action Column dim-while-settled; Cap 26.5a / debt **475** probe).
  /// Leave-current clearing stays on [_clearMediaCoverVisibleGate].
  void _syncMediaCoverVisibleGate() {
    if (!mounted || !widget.isCurrent) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isCurrent) {
        return;
      }
      ref
          .read(mainBrowseCurrentAssetMediaCoverVisibleProvider.notifier)
          .setVisible(_computeMediaCoverVisible());
    });
  }

  void _clearMediaCoverVisibleGate() {
    if (!mounted) {
      return;
    }
    ref
        .read(mainBrowseCurrentAssetMediaCoverVisibleProvider.notifier)
        .setVisible(false);
  }

  void _publishHostUnavailableGate() {
    if (!mounted || !widget.isCurrent) {
      return;
    }
    ref
        .read(mainBrowseCurrentAssetHostUnavailableProvider.notifier)
        .setUnavailable(_isAssetUnavailableFailure);
  }

  void _publishLayer2DisplayReady(bool ready) {
    if (!mounted) {
      return;
    }
    // Defer: [_armLayer2InFlight] is often invoked inside setState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (ready && !widget.isCurrent) {
        return;
      }
      ref
          .read(mainBrowseCurrentAssetLayer2DisplayReadyProvider.notifier)
          .setReady(ready);
    });
  }

  void _clearLayer2DisplayReadyGate() {
    if (!mounted) {
      return;
    }
    ref
        .read(mainBrowseCurrentAssetLayer2DisplayReadyProvider.notifier)
        .setReady(false);
  }

  void _publishListAvailability(AssetAvailability? availability) {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(mainBrowseCurrentAssetListAvailabilityProvider.notifier)
          .setAvailability(availability);
    });
  }

  /// Cap 15.12 probe (or snapshot inject) → Share Decision 14 iCloud limb.
  Future<AssetAvailability?> _resolveAndPublishListAvailability({
    required FeedMediaRequestGate gate,
    required int generation,
  }) async {
    var avail = widget.listTimeAvailability;
    if (avail == null) {
      try {
        final probed = await ref
            .read(assetSourceRepositoryProvider)
            .getAssetAvailabilities([widget.assetIdentifier]);
        if (!mounted ||
            !gate.isCurrent(generation) ||
            !widget.isCurrent) {
          return null;
        }
        avail = probed[widget.assetIdentifier];
      } catch (_) {
        avail = null;
      }
    }
    if (mounted && widget.isCurrent) {
      _publishListAvailability(avail);
    }
    return avail;
  }

  /// When L2/page fail is not already Case B, re-check Photos existence
  /// (same predicate as Cap 23). Missing → [FeedFailureReason.assetUnavailable]
  /// so actionable dims and Retry is hidden (revisit A/B unification).
  Future<FeedFailureReason> _coerceUnavailableFeedFailure(
    FeedFailureReason reason,
  ) async {
    if (reason == FeedFailureReason.assetUnavailable) {
      return reason;
    }
    final id = widget.assetIdentifier;
    try {
      final map = await ref
          .read(assetSourceRepositoryProvider)
          .getAssetAvailabilities([id]);
      if (!mounted || widget.assetIdentifier != id) {
        return reason;
      }
      final availability = map[id] ?? AssetAvailability.unavailable;
      if (!isAssetStillInLibrary(availability)) {
        return FeedFailureReason.assetUnavailable;
      }
    } catch (_) {
      // Keep Host/Dart fail reason if the existence probe itself fails.
    }
    return reason;
  }

  void _clearHostUnavailableGate() {
    if (!mounted) {
      return;
    }
    ref
        .read(mainBrowseCurrentAssetHostUnavailableProvider.notifier)
        .setUnavailable(false);
  }

  /// Cap 15.11b: hide video slot (Opacity 0) until first frame; no Stack reorder.
  /// Armed only when the video child goes null→non-null (A→B relay), never on
  /// L2-complete while guard defer / [_layer2InFlight] keep the slot empty.
  bool _holdPosterUntilFirstFrame = false;
  int? _holdPoolEpoch;
  Timer? _holdPosterTimeout;

  /// Tracks whether build last emitted a non-null video child (slot mounted).
  bool _videoSlotMounted = false;
  StreamSubscription<PlaybackSurfaceReadyForDisplayEvent>? _readyForDisplaySub;

  /// Cap 16.4: [Timer] from became-current. Cancel on leave / dispose.
  Timer? _layer2DwellTimer;
  Completer<void>? _layer2DwellCompleter;

  /// Cap 17.5b: reveal corner reassure after [kLayer2CornerReassureAfter].
  Timer? _layer2ReassureTimer;
  Timer? _layer1CenterLabelRevealTimer;
  DateTime? _layer1CenterLabelDelayArmedAt;
  int? _layer1CenterLabelDelayGeneration;
  AppLifecycleState? _lastLifecycle;

  /// Test seam: paint LIVE badge on coverless corner chrome (rare combo).
  /// Production [liveBadgeVisible] also follows Live still display.
  @visibleForTesting
  bool debugForceLiveBadgeVisible = false;

  /// Test seam: hold [_teardownLiveMotion] when this page is off-current.
  @visibleForTesting
  Completer<void>? debugHoldOffCurrentTeardown;

  @visibleForTesting
  FeedPageMedia? get debugMedia => _media;

  @visibleForTesting
  bool get debugLoading => _loading;

  @visibleForTesting
  bool get debugSurfaceReady => _surfaceReady;

  /// When true, [_VideoPage]/[_StillPage] surface-ready callbacks are ignored
  /// so coverless ¬surfaceReady welds stay pinned in Cap 26.4c tests.
  bool _debugSuppressSurfaceReadyCallbacks = false;

  @visibleForTesting
  bool get debugHoldPosterUntilFirstFrame => _holdPosterUntilFirstFrame;

  @visibleForTesting
  int? get debugHoldPoolEpoch => _holdPoolEpoch;

  @visibleForTesting
  bool get debugLayer2InFlight => _layer2InFlight;

  @visibleForTesting
  bool get debugStillCoverDecodeBroken => _stillCoverDecodeBroken;

  @visibleForTesting
  bool get debugStillCoverReady => _stillCoverReady;

  @visibleForTesting
  bool get debugNeedsFullReloadAfterHostUnavailable =>
      _needsFullReloadAfterHostUnavailable;

  /// Test seam: set/clear still-cover decode-broken Overlay / wait-chrome hide.
  /// When [broken] is true, also arms [_previewReloadTriedPath] from the
  /// current cover so [debugRunReloadPreviewFile] exercises A-class clear.
  @visibleForTesting
  void debugForceStillCoverDecodeBroken(bool broken) {
    void apply() {
      _stillCoverDecodeBroken = broken;
      if (broken) {
        _stillCoverReady = false;
        _previewReloadTriedPath = _media?.display?.localFilePath;
        _previewReloadInFlight = false;
      } else {
        _stillCoverReady = true;
      }
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
    _syncMediaCoverVisibleGate();
  }

  /// Test seam: cover path tracked but first frame not ready (unresolved).
  ///
  /// Cap 26.4b: Meta suppressed; corner spinner + LIVE must stay when wait
  /// chrome would otherwise paint. Distinct from [debugForceStillCoverDecodeBroken].
  @visibleForTesting
  void debugForceStillCoverUnresolved() {
    void apply() {
      _stillCoverReady = false;
      _stillCoverDecodeBroken = false;
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
    _syncMediaCoverVisibleGate();
  }

  /// Test seam: production [_syncMediaCoverVisibleGate] (post-frame publish).
  @visibleForTesting
  void debugSyncMediaCoverVisibleGate() => _syncMediaCoverVisibleGate();

  /// Test seam: run production [_reloadPreviewFile] (A-class clear path).
  @visibleForTesting
  Future<void> debugRunReloadPreviewFile() => _reloadPreviewFile();

  @visibleForTesting
  int? get debugLayer2InFlightGeneration => _layer2InFlightGeneration;

  @visibleForTesting
  WaitChromePathClass get debugLayer2WaitPath => _layer2WaitPath;

  /// Test seam: override elapsed since arm (null = wall clock).
  @visibleForTesting
  Duration? debugInFlightElapsedOverride;

  /// Test seam: override a4 T (null = [kDefaultA4SuppressBelow]).
  @visibleForTesting
  Duration? debugA4SuppressBelowOverride;

  @visibleForTesting
  bool get debugLivePreparing => _livePreparing;

  @visibleForTesting
  bool get debugLayer2WaitChromeLatched => _layer2WaitChromeLatched;

  @visibleForTesting
  bool get debugLivePreparingSkipSuppressBelowT =>
      _livePreparingSkipSuppressBelowT;

  @visibleForTesting
  int get debugLiveMotionGeneration => _liveMotionGate.generation;

  /// Test seam: play-only entry (must not arm preparing / spinner).
  @visibleForTesting
  Future<void> debugPlayLiveMotionOnce(int generation) =>
      _playLiveMotionOnce(generation);

  /// Test seam: mark prepared + surface ready for play-only tests.
  @visibleForTesting
  void debugArmPreparedLiveForPlay({required int generation}) {
    assert(_liveMotionGate.isCurrent(generation));
    _livePhotoReady = true;
    _liveSurfaceReady = true;
    _liveStartIssued = false;
  }

  /// Test seam: Cap 26.4b watchdog timeout paths (C0 vs skip.add).
  @visibleForTesting
  bool get debugLiveStartIssued => _liveStartIssued;

  @visibleForTesting
  set debugLiveStartIssued(bool value) => _liveStartIssued = value;

  @visibleForTesting
  void debugSetLiveMotionMounted(bool value) {
    _liveMotionMounted = value;
  }

  @visibleForTesting
  void debugArmLiveEndedWatchdog() {
    _armLiveEndedWatchdog(widget.assetIdentifier);
  }

  /// Test seam: bump Live motion gate and return the new generation.
  @visibleForTesting
  int debugBeginLiveMotionGate() => _liveMotionGate.begin();

  /// Test seam: re-enter prepare (e.g. remount while binding still backgrounded
  /// so resume-heal can be exercised without a missed-leave flake).
  @visibleForTesting
  Future<void> debugPrepareLiveMotion() => _prepareLiveMotion();

  @visibleForTesting
  bool get debugLiveMotionMounted => _liveMotionMounted;

  @visibleForTesting
  bool get debugLiveHostPhotoRetained => _liveHostPhotoRetained;

  @visibleForTesting
  bool get debugLiveSilentReplayInFlight => _liveSilentReplayInFlight;

  @visibleForTesting
  set debugLiveHostPhotoRetained(bool value) => _liveHostPhotoRetained = value;

  /// Test seam: Cap 26 user long-press replay entry.
  @visibleForTesting
  Future<void> debugUserLongPressReplay() => _userLongPressReplay();

  /// Test seam: Cap 26.5a release-to-stop.
  @visibleForTesting
  Future<void> debugUserLongPressReleaseStop() => _userLongPressReleaseStop();

  @visibleForTesting
  bool get debugUserHoldReplayActive => _userHoldReplayActive;

  @visibleForTesting
  set debugUserHoldReplayActive(bool value) => _userHoldReplayActive = value;

  @visibleForTesting
  bool get debugLiveEndedWatchdogArmed => _liveEndedWatchdog != null;

  /// Test seam: force in-flight + path for widget chrome tests (W-17.3*).
  ///
  /// [mediaKind] overrides [_media] so G (still-only) vs video a2 can be locked.
  /// [stillPlaybackKind] selects image vs livePhoto when [mediaKind] is still.
  @visibleForTesting
  void debugForceLayer2WaitChrome({
    required WaitChromePathClass path,
    required Duration elapsed,
    int generation = 1,
    FeedPageMediaKind? mediaKind,
    PlaybackMediaKind stillPlaybackKind = PlaybackMediaKind.image,
  }) {
    void apply() {
      _layer2WaitPath = path;
      _layer2InFlight = true;
      _layer2InFlightGeneration = generation;
      _layer2InFlightArmedAt = DateTime.now();
      debugInFlightElapsedOverride = elapsed;
      _a4ChromeRevealTimer?.cancel();
      _a4ChromeRevealTimer = null;
      _loading = false;
      if (mediaKind == FeedPageMediaKind.video) {
        _media = FeedPageMedia.video(widget.assetIdentifier);
      } else if (mediaKind == FeedPageMediaKind.pendingVideo) {
        _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
      } else if (mediaKind == FeedPageMediaKind.still) {
        const stillPath = '/tmp/cap173_chrome_still.png';
        _media = FeedPageMedia.still(
          DisplayAsset(
            assetIdentifier: widget.assetIdentifier,
            mediaKind: stillPlaybackKind,
            localFilePath: stillPath,
          ),
          layer: FeedDisplayLayer.preview,
        );
        // Covered wait-chrome seams assume a painted cover; do not wait on
        // FileImage.frameBuilder (suppress would hide spinner/reassure).
        _stillCoverTrackedPath = stillPath;
        _stillCoverReady = true;
        _stillCoverDecodeBroken = false;
      }
      _scheduleLayer2ReassureIfNeeded();
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  /// Test seam: L2 success → Live prepare handoff (ADR-037 latch consume).
  @visibleForTesting
  void debugCompleteL2HandoffToLivePrepare() {
    void apply() {
      final latchedL2WaitChrome = _layer2WaitChromeLatched;
      _completeLayer2InFlightForSuccess();
      _livePreparingSkipSuppressBelowT = latchedL2WaitChrome;
      _livePreparing = true;
      _onLivePreparingChanged(true);
      _layer2WaitChromeLatched = false;
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  /// Test seam: simulate L2 data success (clears inFlight immediately).
  @visibleForTesting
  void debugCompleteLayer2InFlightForSuccess() {
    if (mounted) {
      setState(_completeLayer2InFlightForSuccess);
    } else {
      _completeLayer2InFlightForSuccess();
    }
  }

  /// Test seam: coverless L2 failed in the same center slot as wait copy.
  @visibleForTesting
  void debugForceCoverlessLayer2Failed() {
    void apply() {
      _loading = false;
      _layer2InFlight = false;
      _layer2Failed = true;
      _layer2FailureReason = FeedFailureReason.generic;
      _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
      _a4ChromeRevealTimer?.cancel();
      _a4ChromeRevealTimer = null;
      _cancelLayer2ReassureTimer();
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  /// Test seam: Cap 17.5b G1 — full-page failed chrome (no L1 cover).
  @visibleForTesting
  void debugForcePageFailed() {
    void apply() {
      _loading = false;
      _clearLayer2InFlightUnconditional();
      _layer2Failed = false;
      _layer2FailureReason = FeedFailureReason.generic;
      _media = FeedPageMedia.failed(reason: FeedFailureReason.generic);
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  /// Test seam: a4 + [_loading] (eviction remount / no peek) for chrome tests.
  @visibleForTesting
  void debugForceA4LoadingGate() {
    void apply() {
      _layer2WaitPath = WaitChromePathClass.a4L2ReadyEvict;
      _loading = true;
      _media = null;
      _layer2InFlight = false;
      _a4ChromeRevealTimer?.cancel();
      _a4ChromeRevealTimer = null;
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
    // Cap 26.4c: miss chrome must publish cover-visible=false (debt 473).
    _syncMediaCoverVisibleGate();
  }

  /// Test seam: coverless video page with/without surface ready (ADR-054).
  ///
  /// No poster → [mediaCoverVisiblePredicate] keys off [_surfaceReady] only
  /// (`_stillCoverReady` never becomes true). Also publishes L2-ready to
  /// match production [onSurfaceReady] (Share D14 limb).
  ///
  /// When [surfaceReady] is false, suppresses in-tree surface-ready callbacks
  /// (test [_VideoPage] fires them immediately on mount).
  @visibleForTesting
  void debugForceCoverlessVideoSurface({required bool surfaceReady}) {
    void apply() {
      // Invalidate in-flight L1/L2 so a late Fake display apply cannot
      // restore a still cover over this coverless weld.
      _localGate.begin();
      _debugSuppressSurfaceReadyCallbacks = !surfaceReady;
      _loading = false;
      _media = FeedPageMedia.video(widget.assetIdentifier);
      _surfaceReady = surfaceReady;
      _stillCoverReady = false;
      _stillCoverDecodeBroken = false;
      _stillCoverTrackedPath = null;
      _liveMotionMounted = false;
      _layer2InFlight = false;
      _a4ChromeRevealTimer?.cancel();
      _a4ChromeRevealTimer = null;
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
    _syncMediaCoverVisibleGate();
    if (widget.isCurrent) {
      _publishLayer2DisplayReady(surfaceReady);
    }
  }

  Duration get _a4SuppressBelow =>
      debugA4SuppressBelowOverride ?? kDefaultA4SuppressBelow;

  Duration get _inFlightElapsed {
    final override = debugInFlightElapsedOverride;
    if (override != null) {
      return override;
    }
    final armed = _layer2InFlightArmedAt;
    if (armed == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(armed);
  }

  /// Cap 17.3: whether Layer-2 wait corner chrome should paint.
  ///
  /// Promoted: G (still a2 &lt;T). Retained not promoted: E (`!isCurrent`).
  bool _evaluateShowLayer2WaitChrome() {
    // E: off-current hard gate (conservative; not Decision-2-promoted).
    if (!widget.isCurrent) {
      return false;
    }
    if (!_layer2InFlight) {
      return false;
    }
    final show = waitChromeShowsSpinner(
      resolveWaitChrome(
        path: _layer2WaitPath,
        elapsedInFlight: _inFlightElapsed,
        a4SuppressBelow: _a4SuppressBelow,
        isCurrent: widget.isCurrent,
      ),
    );
    if (!show) {
      return false;
    }
    // G: still a2 suppress-below-T (video a2 stays immediate).
    if (_media?.kind == FeedPageMediaKind.still &&
        _inFlightElapsed < _a4SuppressBelow) {
      return false;
    }
    return true;
  }

  /// Arm Layer-2-in-flight for [generation] (canMountVideo / spinner owner).
  void _armLayer2InFlight(int generation, {WaitChromePathClass? path}) {
    if (path != null) {
      _layer2WaitPath = path;
    }
    _layer2InFlight = true;
    _layer2InFlightGeneration = generation;
    _layer2InFlightArmedAt = DateTime.now();
    // New L2 attempt — do not inherit a prior activation's paint latch.
    _layer2WaitChromeLatched = false;
    debugInFlightElapsedOverride = null;
    _publishLayer2DisplayReady(false);
    _scheduleA4ChromeRevealIfNeeded();
    _scheduleLayer2ReassureIfNeeded();
  }

  void _scheduleA4ChromeRevealIfNeeded() {
    _a4ChromeRevealTimer?.cancel();
    _a4ChromeRevealTimer = null;
    if (!widget.isCurrent) {
      return;
    }
    // a4 band + still pages (G): tick at T so suppress-below-T can flip
    // visible without waiting for another rebuild. Video a2: no tick.
    final needsBandTick =
        _layer2WaitPath == WaitChromePathClass.a4L2ReadyEvict ||
        _media?.kind == FeedPageMediaKind.still;
    if (!needsBandTick) {
      return;
    }
    final remaining = _a4SuppressBelow - _inFlightElapsed;
    if (remaining <= Duration.zero) {
      return;
    }
    final armedGeneration = _layer2InFlightGeneration;
    _a4ChromeRevealTimer = Timer(remaining, () {
      if (!shouldApplyA4ChromeRevealTick(
        isMounted: mounted,
        layer2InFlight: _layer2InFlight,
        armedGeneration: armedGeneration,
        currentInFlightGeneration: _layer2InFlightGeneration,
      )) {
        return;
      }
      setState(() {});
    });
  }

  /// Cap 17.5b: rebuild when wall clock crosses [kLayer2CornerReassureAfter].
  void _scheduleLayer2ReassureIfNeeded() {
    _layer2ReassureTimer?.cancel();
    _layer2ReassureTimer = null;
    if (!widget.isCurrent || !_layer2InFlight || _loading) {
      return;
    }
    if (_layer2WaitPath == WaitChromePathClass.a4L2ReadyEvict) {
      return;
    }
    final remaining = kLayer2CornerReassureAfter - _inFlightElapsed;
    if (remaining <= Duration.zero) {
      return;
    }
    final armedGeneration = _layer2InFlightGeneration;
    _layer2ReassureTimer = Timer(remaining, () {
      if (!shouldApplyLayer2ReassureTick(
        isMounted: mounted,
        layer2InFlight: _layer2InFlight,
        armedGeneration: armedGeneration,
        currentInFlightGeneration: _layer2InFlightGeneration,
      )) {
        return;
      }
      setState(() {});
    });
  }

  void _cancelLayer2ReassureTimer() {
    _layer2ReassureTimer?.cancel();
    _layer2ReassureTimer = null;
  }

  /// L2 data success: clear inFlight so content can mount immediately.
  void _completeLayer2InFlightForSuccess() {
    _a4ChromeRevealTimer?.cancel();
    _a4ChromeRevealTimer = null;
    _cancelLayer2ReassureTimer();
    _layer2InFlight = false;
    _layer2InFlightGeneration = null;
    _layer2InFlightArmedAt = null;
    debugInFlightElapsedOverride = null;
  }

  /// Leave-current / abandon / fail / re-arm start: drop ownership.
  void _clearLayer2InFlightUnconditional() {
    _a4ChromeRevealTimer?.cancel();
    _a4ChromeRevealTimer = null;
    _cancelLayer2ReassureTimer();
    _layer2InFlight = false;
    _layer2InFlightGeneration = null;
    _layer2InFlightArmedAt = null;
    _layer2WaitChromeLatched = false;
    debugInFlightElapsedOverride = null;
  }

  /// Abandon **this** attempt only. Safe when gate/current/mounted failed
  /// after arming — does not clear a newer generation's in-flight arm.
  /// Also clears [_loading] (same early-return structural pair).
  void _abandonLayer2Attempt(int generation, {required String reason}) {
    if (_layer2InFlightGeneration != generation) {
      return;
    }
    if (!mounted) {
      _clearLayer2InFlightUnconditional();
      _loading = false;
      return;
    }
    setState(() {
      _clearLayer2InFlightUnconditional();
      _loading = false;
    });
  }

  bool _liveMotionMounted = false;
  /// Cap 25: cancel on normal ended unload; fire → skip-set + same unload path.
  Timer? _liveEndedWatchdog;
  bool _livePhotoReady = false;
  bool _liveSurfaceReady = false;
  bool _liveStartIssued = false;
  /// Serializes lifecycle leave/heal so inactive→hidden→paused cannot stack
  /// duplicate [stopPlayback] before the first unload clears dirty flags.
  bool _liveLifecycleInterruptInFlight = false;

  /// Cap 26.2 / ADR-052: Host [pendingLivePhoto] likely retained after Q7 /
  /// watchdog / lifecycle unload (no cancel). Cleared on cancel / failed /
  /// Path S request start.
  bool _liveHostPhotoRetained = false;

  /// Cap 26.2 / ADR-052: Path S in-flight (no prepare chrome). Cleared only on
  /// ready-mount / failed / cancelled — never on bare [requestLivePhoto] await.
  bool _liveSilentReplayInFlight = false;

  /// Cap 26.5a: finger that fired long-press is still down (hold-through).
  /// Keeps Cap 26 Listener mounted after `_liveMotionMounted` / Path S.
  bool _userHoldReplayActive = false;

  /// Cap 9.5 Q4=A: motion **prepare** spinner (generation-gated writes).
  ///
  /// Means "Live motion resource acquire in flight" only — **not** playback.
  /// Cap 14.6b ungated handoff keeps this true across L2 → serial-queue wait.
  /// Cap 17.6 / ADR-037: when L2 wait chrome already latched, skip F1 &lt;T
  /// suppress so the corner spinner does not dip between phases.
  /// Play-only ([_playLiveMotionOnce]) must never set this flag.
  bool _livePreparing = false;

  /// Cap 17.3: wall clock when [_livePreparing] became true (F1 suppress-T).
  DateTime? _livePreparingArmedAt;
  Timer? _livePreparingChromeRevealTimer;

  /// ADR-037: skip F1 &lt;T suppress for this prepare arm (L2 chrome latched).
  bool _livePreparingSkipSuppressBelowT = false;

  /// F1 reveal latched by Timer (fake-async safe; not DateTime alone).
  bool _livePreparingChromeRevealed = false;

  /// Cap 17.6 / ADR-037: true if L2 wait corner spinner painted this inFlight.
  ///
  /// Cleared on new [_armLayer2InFlight], leave/abandon clear, and after the
  /// L2→motion handoff consumes it. Not wall-clock ≥ T alone.
  bool _layer2WaitChromeLatched = false;

  bool get _showLiveLoadSpinner {
    // E: off-current hard gate (conservative; not Decision-2-promoted).
    if (!widget.isCurrent) {
      return false;
    }
    if (!_isLiveStillMedia(_media)) {
      return false;
    }
    if (_livePreparing) {
      // ADR-037: continuous handoff when L2 wait chrome already painted.
      if (_livePreparingSkipSuppressBelowT) {
        return true;
      }
      // F1(+D): suppress until reveal Timer (or real wall ≥ T as fallback).
      if (_livePreparingChromeRevealed) {
        return true;
      }
      final armed = _livePreparingArmedAt;
      if (armed == null) {
        return false;
      }
      return DateTime.now().difference(armed) >= _a4SuppressBelow;
    }
    if (!_layer2InFlight) {
      return false;
    }
    // C/F2: Live inFlight follows wait band (retained, not Decision-2-promoted).
    if (_layer2WaitPath == WaitChromePathClass.a4L2ReadyEvict ||
        _isLiveStillMedia(_media)) {
      return _evaluateShowLayer2WaitChrome();
    }
    return true;
  }

  void _onLivePreparingChanged(bool next) {
    _livePreparingChromeRevealTimer?.cancel();
    _livePreparingChromeRevealTimer = null;
    if (!next) {
      _livePreparingArmedAt = null;
      _livePreparingSkipSuppressBelowT = false;
      _livePreparingChromeRevealed = false;
      return;
    }
    _livePreparingArmedAt = DateTime.now();
    if (_livePreparingSkipSuppressBelowT) {
      // Spinner already continuous from L2 — treat as revealed.
      _livePreparingChromeRevealed = true;
      return;
    }
    _livePreparingChromeRevealed = false;
    final armedAt = _livePreparingArmedAt!;
    _livePreparingChromeRevealTimer = Timer(_a4SuppressBelow, () {
      if (!mounted || !_livePreparing || !widget.isCurrent) {
        return;
      }
      if (_livePreparingArmedAt != armedAt) {
        return;
      }
      setState(() => _livePreparingChromeRevealed = true);
    });
  }

  /// Cap 15.4: in-flight neighbour Layer 1; validity is [_localGate] only.
  Future<FeedPageMedia?>? _layer1Future;
  int? _layer1LocalGen;

  bool _previewReloadInFlight = false;
  String? _previewReloadTriedPath;
  StreamSubscription<LivePhotoReadyEvent>? _liveReadySub;
  StreamSubscription<LivePhotoFailedEvent>? _liveFailedSub;
  StreamSubscription<LivePhotoPlaybackEndedEvent>? _liveEndedSub;

  /// Cached for async teardown / dispose (Riverpod ref is unsafe after unmount).
  LivePhotoRepository? _liveRepo;
  PlaybackRepository? _playbackRepo;
  PlaybackCoordinator? _playbackCoordinator;
  MediaDisplayRepository? _displayRepo;
  PvTransitionGuardNotifier? _pvGuardNotifier;

  PvHandoffPageSnapshot _pvHandoffSnapshot() {
    final media = _media;
    final poster = media?.display;
    final isVideoWithPoster =
        media?.kind == FeedPageMediaKind.video && poster != null;
    final guard = ref.read(pvTransitionGuardProvider);
    final deferVideoForHandoff =
        widget.isCurrent && guard.isCovering(widget.assetIdentifier);
    return PvHandoffPageSnapshot(
      isVideoWithPoster: isVideoWithPoster,
      isCurrentSurfaceReady:
          widget.isCurrent &&
          isVideoWithPoster &&
          _surfaceReady &&
          !deferVideoForHandoff,
      posterPath: poster?.localFilePath,
    );
  }

  void _syncPvHandoffSnapshot() {
    _pvGuardNotifier ??= ref.read(pvTransitionGuardProvider.notifier);
    _pvGuardNotifier!.updatePageSnapshot(
      widget.assetIdentifier,
      _pvHandoffSnapshot(),
    );
  }

  void _clearPosterHold({required String reason}) {
    _holdPosterTimeout?.cancel();
    _holdPosterTimeout = null;
    if (!_holdPosterUntilFirstFrame && _holdPoolEpoch == null) {
      return;
    }
    _holdPosterUntilFirstFrame = false;
    _holdPoolEpoch = null;
    // Cap 15.11b: unmute only when THIS page's first-frame hold ends — not on
    // leave/unmount (that would clear a handoff suppress armed for the target).
    if (reason == 'ready-for-display' || reason == 'timeout') {
      unawaited(
        ref
            .read(pvTransitionGuardProvider.notifier)
            .releaseTransitionAudio(reason: 'poster-hold-$reason'),
      );
    }
  }

  /// Cap 15.11b A→B relay: sync-arm Opacity hold when the video slot is
  /// about to mount (null→non-null). Safe to call from [build] (no setState).
  /// Not [PvTransitionGuard]. Does **not** arm while defer / in-flight keep
  /// the slot empty — those callers must not invoke this.
  void _armPosterHoldOnVideoSlotMount() {
    if (_holdPosterUntilFirstFrame) {
      return;
    }
    if (!widget.isCurrent) {
      return;
    }
    if (_media?.kind != FeedPageMediaKind.video || _media?.display == null) {
      return;
    }
    _holdPosterUntilFirstFrame = true;
    _holdPoolEpoch = null;
    _holdPosterTimeout?.cancel();
    _holdPosterTimeout = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_holdPosterUntilFirstFrame) {
        return;
      }
      setState(() => _clearPosterHold(reason: 'timeout'));
    });
    unawaited(_fillPosterHoldEpoch());
  }

  Future<void> _fillPosterHoldEpoch() async {
    final epoch = await ref
        .read(playbackRepositoryProvider)
        .getPlaybackPoolEpoch();
    if (!mounted || !_holdPosterUntilFirstFrame) {
      return;
    }
    if (_media?.kind != FeedPageMediaKind.video || _media?.display == null) {
      return;
    }
    setState(() {
      _holdPoolEpoch = epoch;
    });
  }

  void _onSurfaceReadyForDisplay(PlaybackSurfaceReadyForDisplayEvent event) {
    if (!_holdPosterUntilFirstFrame) {
      if (event.assetIdentifier == widget.assetIdentifier) {}
      return;
    }
    if (event.assetIdentifier != widget.assetIdentifier) {
      return;
    }
    if (event.feedIndex != widget.feedIndex) {
      return;
    }
    // Epoch must be captured before matching — never accept with pending null.
    final holdEpoch = _holdPoolEpoch;
    if (holdEpoch == null) {
      return;
    }
    if (event.clearEpoch != holdEpoch) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _clearPosterHold(reason: 'ready-for-display'));
  }

  void _armInitialLayer1CenterLabelDelay() {
    if (!widget.delayInitialLayer1CenterLabel || !widget.isCurrent) {
      return;
    }
    _layer1CenterLabelDelayArmedAt = DateTime.now();
    _layer1CenterLabelDelayGeneration = widget.assignedDisplayGeneration;
    _layer1CenterLabelRevealTimer?.cancel();
    _layer1CenterLabelRevealTimer = Timer(
      kSourceSwitchLayer1CenterLabelDelay,
      () {
        _layer1CenterLabelRevealTimer = null;
        if (!mounted ||
            !widget.isCurrent ||
            widget.assignedDisplayGeneration !=
                _layer1CenterLabelDelayGeneration) {
          return;
        }
        _layer1CenterLabelDelayArmedAt = null;
        _layer1CenterLabelDelayGeneration = null;
        if (_loading) {
          setState(() {});
        }
      },
    );
  }

  void _cancelInitialLayer1CenterLabelDelay({required bool revealImmediately}) {
    _layer1CenterLabelRevealTimer?.cancel();
    _layer1CenterLabelRevealTimer = null;
    _layer1CenterLabelDelayGeneration = null;
    if (revealImmediately) {
      _layer1CenterLabelDelayArmedAt = null;
    }
  }

  Duration get _initialLayer1CenterLabelDelayElapsed {
    final armedAt = _layer1CenterLabelDelayArmedAt;
    if (armedAt == null) {
      return kSourceSwitchLayer1CenterLabelDelay;
    }
    return DateTime.now().difference(armedAt);
  }

  @override
  void initState() {
    super.initState();
    _lastLifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    _armInitialLayer1CenterLabelDelay();
    if (widget.isCurrent) {
      _armLayer2DwellTimer();
    }
    final seed = widget.initialLayer1;
    final seedDisplay = seed?.display;
    if (seedDisplay != null &&
        seedDisplay.assetIdentifier == widget.assetIdentifier) {
      // Cap 22.5: remount with prior still/poster so round-head does not
      // flash bare feedBackground between peek L1 and L2.
      _media = seed;
      _loading = false;
      _trackStillCoverPath(seedDisplay.localFilePath);
    }
    _startLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _lastLifecycle;
    _lastLifecycle = state;

    // Cap 9 lifecycle gap (debt 453): leave foreground is an authoritative
    // Live-motion interrupt — do not wait for PHLivePhotoView didEndPlayback.
    // Matches video onLeaveForeground timing (inactive | paused | hidden).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_interruptLiveMotionForAppLifecycle());
      return;
    }

    if (state != AppLifecycleState.resumed) {
      return;
    }

    // Resume heal: same cleanup if leave never finished (engine suspended,
    // serial lag, etc.). Trigger is dirty state — not the L2-retry previous
    // gate (inactive/paused only), so a missed leave cannot slip through.
    unawaited(_interruptLiveMotionForAppLifecycle());

    // China-SKU wireless-data alert: typically inactive→resumed (app never
    // backgrounds). True background uses paused→resumed. Listen for both.
    if (previous != AppLifecycleState.inactive &&
        previous != AppLifecycleState.paused) {
      return;
    }
    _retryFailedLayer2AfterResume();
  }

  /// True when Live motion / prepare / Cap 26 Path S still owns the page.
  bool get _liveMotionLifecycleDirty =>
      _liveMotionMounted ||
      _livePreparing ||
      _liveStartIssued ||
      _liveSilentReplayInFlight;

  /// Shared leave + resume-heal path: same Dart unload as [playbackEndedEvents]
  /// (Q7=A), plus best-effort [stopPlayback]. Idempotent under triple
  /// inactive→hidden→paused and under resume-when-already-clean.
  ///
  /// Unload runs **before** awaiting Host stop so stacked leave callbacks that
  /// arrive while stop is queued already see !dirty (inFlight alone is not
  /// enough if the first Future has yielded at enqueue).
  ///
  /// Cap 26.2: when Path S was in flight, also [cancel] (clears Host pending)
  /// and drop [_liveHostPhotoRetained] / [_liveSilentReplayInFlight].
  Future<void> _interruptLiveMotionForAppLifecycle() async {
    if (!mounted ||
        !widget.isCurrent ||
        !_liveMotionLifecycleDirty ||
        _liveLifecycleInterruptInFlight) {
      return;
    }
    _liveLifecycleInterruptInFlight = true;
    final wasSilentInFlight = _liveSilentReplayInFlight;
    try {
      final LivePhotoRepository live =
          _liveRepo ?? ref.read(livePhotoRepositoryProvider);
      _liveRepo = live;
      final id = widget.assetIdentifier;
      await _unloadLiveMotionSurface();
      if (!mounted) {
        return;
      }
      if (wasSilentInFlight) {
        _liveSilentReplayInFlight = false;
        _liveHostPhotoRetained = false;
        await _enqueueLiveOp(() async {
          try {
            await live.cancel(id);
            await live.stopPlayback();
          } catch (_) {
            // Best-effort — Host may already have stopped / surface gone.
          }
        });
      } else {
        await _enqueueLiveOp(() async {
          try {
            await live.stopPlayback();
          } catch (_) {
            // Best-effort — Host may already have stopped / surface gone.
          }
        });
      }
    } finally {
      _liveLifecycleInterruptInFlight = false;
    }
  }

  /// Auto-retry only when this current page is already in a fail state.
  void _retryFailedLayer2AfterResume() {
    if (!mounted || !widget.isCurrent || _layer2InFlight) {
      return;
    }
    if (_layer2Failed) {
      unawaited(_retryFromFailState(pageFailedMedia: false));
      return;
    }
    if (_media?.kind == FeedPageMediaKind.failed) {
      unawaited(_retryFromFailState(pageFailedMedia: true));
    }
  }

  /// Cap 17.5b: fail Retry / resume-fail must clear a hung same-id prepare
  /// before starting another load (Cap16 single networked path: serial
  /// await cancel → then load; does not add a Host prepare entry).
  Future<void> _cancelStalePrepareBeforeFailRetry() async {
    final playback = ref.read(playbackRepositoryProvider);
    _playbackRepo = playback;
    await playback.cancelInFlightPrepare(widget.assetIdentifier);
  }

  /// Manual Retry + resume-fail entry: cancel-before-retry then reload.
  Future<void> _retryFromFailState({required bool pageFailedMedia}) async {
    await _cancelStalePrepareBeforeFailRetry();
    if (!mounted || !widget.isCurrent) {
      return;
    }
    if (pageFailedMedia) {
      await _startLoad(bypassDwell: true);
    } else {
      await _retryLayer2Only(bypassDwell: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _liveRepo ??= ref.read(livePhotoRepositoryProvider);
    _playbackRepo ??= ref.read(playbackRepositoryProvider);
    _playbackCoordinator ??= ref.read(playbackCoordinatorProvider);
    _displayRepo ??= ref.read(mediaDisplayRepositoryProvider);
    _readyForDisplaySub ??= ref
        .read(playbackRepositoryProvider)
        .surfaceReadyForDisplayEvents
        .listen(_onSurfaceReadyForDisplay);
  }

  @override
  void didUpdateWidget(covariant MediaFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeSyncForegroundResumePlayback(oldWidget.foregroundResumeSyncEpoch);
    final leftCurrent = oldWidget.isCurrent && !widget.isCurrent;
    if (!oldWidget.isCurrent && widget.isCurrent) {
      _armLayer2DwellTimer();
      final gen = widget.assignedDisplayGeneration;
      if (gen != null) {
        _holdVideoSurfaceForL2ReloadIfNeeded(gen);
      }
      // Defer: feed-index rebuild can call didUpdateWidget during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isCurrent) {
          return;
        }
        _publishHostUnavailableGate();
        _syncMediaCoverVisibleGate();
      });
    }
    if (leftCurrent) {}
    if (oldWidget.isCurrent != widget.isCurrent ||
        oldWidget.isPreheatNeighbor != widget.isPreheatNeighbor) {}
    if (oldWidget.isPreheatNeighbor && !widget.isPreheatNeighbor) {
      if (!widget.isCurrent) {
        _localGate.begin();
        _layer1Future = null;
        _layer1LocalGen = null;
      }
    }
    // Leaving current must always pause — even when generation/asset props
    // change in the same update (parent clears assignedDisplayGeneration when
    // isCurrent becomes false). Otherwise video→still / video→iCloud never
    // pause because _startLoad runs and skips the isCurrent-only branch.
    if (leftCurrent) {
      _cancelLiveEndedWatchdog();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.isCurrent) {
          return;
        }
        _clearHostUnavailableGate();
        _clearLayer2DisplayReadyGate();
        _clearMediaCoverVisibleGate();
        _publishListAvailability(null);
      });
      _cancelInitialLayer1CenterLabelDelay(revealImmediately: true);
      final coordinator = ref.read(playbackCoordinatorProvider);
      _playbackRepo ??= ref.read(playbackRepositoryProvider);
      unawaited(coordinator.onLeaveCurrent());
      unawaited(
        _playbackRepo!.cancelInFlightPrepare(widget.assetIdentifier),
      );
      _cancelLayer2DwellTimer();
      _displayRepo ??= ref.read(mediaDisplayRepositoryProvider);
      // Shared currentDisplayGate is bumped by the parent
      // [_activateCurrentItem] when the new current page is assigned.
      // This branch does not bump that gate; G2 uses [widget.isCurrent].
      unawaited(_cancelCurrentItemPhotoKit(widget.assetIdentifier));
      // Cap 15.7: keep video+poster kind so [_StillPage] stays in the
      // same Stack slot. Do not flip to still (destroys Image State) or
      // pendingVideo when a poster already exists.
      if (_media?.kind == FeedPageMediaKind.video && _media?.display == null) {
        setState(() {
          _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
          _surfaceReady = false;
          _clearLayer2InFlightUnconditional();
          _layer2Failed = false;
          _layer2FailureReason = null;
          _loading = false;
          _videoSlotMounted = false;
          _clearPosterHold(reason: 'left-current');
        });
      } else {
        setState(() {
          // Cap 17.5b G1: do not leave FeedPageMediaKind.failed on peek —
          // PageFailed+Retry must not paint off-current.
          if (_media?.kind == FeedPageMediaKind.failed) {
            _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
          }
          _surfaceReady = false;
          _clearLayer2InFlightUnconditional();
          _layer2Failed = false;
          _layer2FailureReason = null;
          _loading = false;
          _videoSlotMounted = false;
          _clearPosterHold(reason: 'left-current');
        });
      }
      // Capture repo before async gaps; leave cancel must not depend on
      // `_liveRepo` having been cached (didChangeDependencies ordering).
      final live = ref.read(livePhotoRepositoryProvider);
      _liveRepo = live;
      final id = widget.assetIdentifier;
      final shouldCancelHost = _liveMotionMounted || _isLiveStillMedia(_media);
      // Leave invalidates generation first, then clears preparing (Cap 9.5).
      final leaveGeneration = _liveMotionGate.begin();
      unawaited(_cancelLiveSubscriptions());
      _livePhotoReady = false;
      _liveSurfaceReady = false;
      _liveStartIssued = false;
      _liveSilentReplayInFlight = false;
      if (shouldCancelHost) {
        _liveHostPhotoRetained = false;
      }
      if (_liveMotionMounted) {
        setState(() => _liveMotionMounted = false);
        ref
            .read(browseMagnificationProvider.notifier)
            .onLiveMotionMountedChanged(false);
      }
      _setLivePreparing(leaveGeneration, false);
      if (shouldCancelHost) {
        unawaited(
          _enqueueLiveOp(() async {
            try {
              await live.cancel(id);
              await live.stopPlayback();
            } catch (_) {}
          }),
        );
      }
    }

    if (oldWidget.assetIdentifier != widget.assetIdentifier ||
        oldWidget.assignedDisplayGeneration !=
            widget.assignedDisplayGeneration) {
      _previewReloadInFlight = false;
      _previewReloadTriedPath = null;
      if (oldWidget.assetIdentifier != widget.assetIdentifier) {
        _clearStillCoverTracking();
      }
    }

    if (oldWidget.assetIdentifier != widget.assetIdentifier ||
        oldWidget.feedIndex != widget.feedIndex ||
        oldWidget.sourceKind != widget.sourceKind ||
        oldWidget.assignedDisplayGeneration !=
            widget.assignedDisplayGeneration) {
      if (oldWidget.assetIdentifier != widget.assetIdentifier) {
        unawaited(_cancelCurrentItemPhotoKit(oldWidget.assetIdentifier));
      }
      _startLoad();
    } else if (!oldWidget.isPreheatNeighbor &&
        widget.isPreheatNeighbor &&
        !widget.isCurrent) {
      _startLoad();
    } else if (!leftCurrent && oldWidget.isCurrent != widget.isCurrent) {
      // Became current without identity/generation change (rare).
      if (widget.isCurrent) {
        if (_needsFullReloadAfterHostUnavailable ||
            _media?.kind == FeedPageMediaKind.pendingVideo ||
            _media?.kind == FeedPageMediaKind.video) {
          _startLoad();
        } else {
          unawaited(_syncPlaybackActive());
          if (_isLiveStillMedia(_media) && !_livePreparing) {
            setState(() {
              _livePreparingSkipSuppressBelowT = false;
              _livePreparing = true;
              _onLivePreparingChanged(true);
            });
          }
          unawaited(_prepareLiveMotion());
        }
      }
    }
  }

  @override
  void dispose() {
    _cancelLiveEndedWatchdog();
    _readyForDisplaySub?.cancel();
    _readyForDisplaySub = null;
    _holdPosterTimeout?.cancel();
    _cancelInitialLayer1CenterLabelDelay(revealImmediately: false);
    _a4ChromeRevealTimer?.cancel();
    _a4ChromeRevealTimer = null;
    _cancelLayer2ReassureTimer();
    _livePreparingChromeRevealTimer?.cancel();
    _livePreparingChromeRevealTimer = null;
    _pvGuardNotifier?.removePageSnapshot(widget.assetIdentifier);
    WidgetsBinding.instance.removeObserver(this);
    _cancelLayer2DwellTimer();
    _liveMotionGate.begin(); // invalidate Live activation
    _localGate.begin();
    unawaited(_cancelLiveSubscriptions());
    unawaited(_cancelCurrentItemPhotoKit(widget.assetIdentifier));
    final playback = _playbackRepo;
    if (widget.isCurrent && playback != null) {
      unawaited(playback.cancelInFlightPrepare(widget.assetIdentifier));
      unawaited(_playbackCoordinator?.onLeaveCurrent());
    }
    final live = _liveRepo;
    if (widget.isCurrent && _isLiveStillMedia(_media) && live != null) {
      // Best-effort host teardown; dispose cannot await.
      final id = widget.assetIdentifier;
      unawaited(live.cancel(id));
      unawaited(live.stopPlayback());
    }
    // Cap 21.6 host-unavailable gate: cleared in leave-current /
    // destination select — do not touch [ref] here (unsafe when unmounting).
    super.dispose();
  }

  bool _isLiveStillMedia(FeedPageMedia? media) {
    return media?.kind == FeedPageMediaKind.still &&
        media?.display?.mediaKind == PlaybackMediaKind.livePhoto;
  }

  Future<void> _cancelLiveSubscriptions() async {
    final ready = _liveReadySub;
    final failed = _liveFailedSub;
    final ended = _liveEndedSub;
    _liveReadySub = null;
    _liveFailedSub = null;
    _liveEndedSub = null;
    await Future.wait<void>([
      if (ready != null) ready.cancel(),
      if (failed != null) failed.cancel(),
      if (ended != null) ended.cancel(),
    ]);
  }

  Future<void> _enqueueLiveOp(Future<void> Function() op) {
    // Cap 9.4 / F4: sole cancel↔request mutex (feed-scoped [LiveHostOpSerial]).
    // Host has no independent lock (see LivePhotoApiHost doc comment). Do not
    // call LivePhotoRepository cancel/request/stop outside this chain from
    // Feed paths — if a future path bypasses it, re-evaluate host mutex.
    return widget.liveHostSerial.enqueue(op);
  }

  /// Cap 9.5: every `_livePreparing` write is generation-gated (L-S6).
  void _setLivePreparing(int generation, bool value) {
    if (!mounted) {
      return;
    }
    final next = gatedFlagUpdate(
      gate: _liveMotionGate,
      generation: generation,
      current: _livePreparing,
      next: value,
    );
    if (next == _livePreparing) {
      return;
    }
    setState(() {
      _livePreparing = next;
      _onLivePreparingChanged(next);
    });
  }

  /// Ungated clear for the 14.6b Layer 2 → motion handoff when
  /// [_liveMotionGate.begin] has not run yet for this activation.
  void _abandonLivePreparingHandoff() {
    if (!mounted || !_livePreparing) {
      return;
    }
    setState(() {
      _livePreparing = false;
      _onLivePreparingChanged(false);
    });
  }

  /// L-S6 test seam only: route a preparing write through [_setLivePreparing].
  ///
  /// Simulates a **defensive** "write carrying a stale generation" — not a race
  /// reproducible under today's stream subscription lifecycle. Leave tears down
  /// ready/failed/ended listeners before return re-subscribes (serialized by
  /// [LiveHostOpSerial]), so a late ready event cannot reach a current
  /// listener. This hook locks [gatedFlagUpdate] so a future change that breaks
  /// cancel-before-resubscribe cannot silently drop that last line of defense.
  @visibleForTesting
  void debugSetLivePreparing(int generation, bool value) {
    _setLivePreparing(generation, value);
  }

  void _cancelLiveEndedWatchdog() {
    _liveEndedWatchdog?.cancel();
    _liveEndedWatchdog = null;
  }

  /// Cap 25 / Cap 26.4b: if [playbackEnded] never arrives after
  /// `startPlayback` was issued, force the same unload as [live_ended_ok].
  /// Skip-set add only when [_liveStartIssued] (hung play); ¬startIssued →
  /// unload only (C0 — must not ban auto-play for pre-start delays).
  void _armLiveEndedWatchdog(String assetId) {
    _cancelLiveEndedWatchdog();
    final generation = _liveMotionGate.generation;
    _liveEndedWatchdog = Timer(kLiveMotionEndedWatchdog, () {
      if (!mounted ||
          !_liveMotionGate.isCurrent(generation) ||
          !widget.isCurrent ||
          widget.assetIdentifier != assetId ||
          !_liveMotionMounted) {
        return;
      }
      if (_liveStartIssued) {
        ref
            .read(browseLiveMotionWatchdogSkipIdsProvider.notifier)
            .add(assetId);
      }
      unawaited(_unloadLiveMotionSurface());
    });
  }

  /// Cap 9.4/9.5: **prepare** Live motion (may show gold spinner).
  ///
  /// Acquires the Host LivePhoto via [LivePhotoRepository.requestLivePhoto].
  /// Sets [_livePreparing] — the only path that may paint prepare chrome.
  /// Future long-press **replay** must not call this when Host already holds
  /// a prepared LivePhoto; use [_playLiveMotionOnce] instead (ADR-037).
  Future<void> _prepareLiveMotion() async {
    if (!widget.isCurrent || !_isLiveStillMedia(_media)) {
      _abandonLivePreparingHandoff();
      return;
    }
    final assetId = widget.assetIdentifier;
    if (ref.read(browseLiveMotionWatchdogSkipIdsProvider.notifier).contains(
          assetId,
        )) {
      _abandonLivePreparingHandoff();
      return;
    }
    final LivePhotoRepository live =
        _liveRepo ?? ref.read(livePhotoRepositoryProvider);
    final PlaybackRepository playback =
        _playbackRepo ?? ref.read(playbackRepositoryProvider);
    _liveRepo = live;
    _playbackRepo = playback;

    _livePhotoReady = false;
    _liveSurfaceReady = false;
    _liveStartIssued = false;

    await _enqueueLiveOp(() async {
      // Dart StreamSubscription only — not Host cancel. unawaited is
      // deliberate: awaiting cancel inside the serial stalls widget-test
      // pumps when ±1 keep-alive reuses this State. Native cancel/request
      // stay serialized by this queue; stale-ready safety is
      // [_liveMotionGate] generation, not this line completing first.
      unawaited(_cancelLiveSubscriptions());
      if (!mounted || !widget.isCurrent || !_isLiveStillMedia(_media)) {
        _abandonLivePreparingHandoff();
        return;
      }
      final generation = _liveMotionGate.begin();
      if (_liveMotionMounted) {
        setState(() => _liveMotionMounted = false);
      }
      _setLivePreparing(generation, true);

      _liveReadySub = live.readyEvents.listen((event) {
        if (!_liveMotionGate.isCurrent(generation)) {
          return;
        }
        if (event.assetIdentifier != assetId) {
          return;
        }
        _setLivePreparing(generation, false);
        _livePhotoReady = true;
        unawaited(_playLiveMotionOnce(generation));
      });
      _liveFailedSub = live.failedEvents.listen((event) {
        if (!_liveMotionGate.isCurrent(generation)) {
          return;
        }
        if (event.assetIdentifier != assetId) {
          return;
        }
        _liveHostPhotoRetained = false;
        _setLivePreparing(generation, false);
        unawaited(_unloadLiveMotionSurface());
      });
      _liveEndedSub = live.playbackEndedEvents.listen((event) {
        if (!_liveMotionGate.isCurrent(generation)) {
          return;
        }
        if (event.assetIdentifier != assetId) {
          return;
        }
        // Q7=A: unload PV → still Image.file.
        unawaited(_unloadLiveMotionSurface());
      });

      try {
        await playback.clearPlaybackPool();
        if (!mounted ||
            !_liveMotionGate.isCurrent(generation) ||
            !widget.isCurrent) {
          _setLivePreparing(generation, false);
          return;
        }
        await live.requestLivePhoto(assetId);
        if (!mounted ||
            !_liveMotionGate.isCurrent(generation) ||
            !widget.isCurrent) {
          _setLivePreparing(generation, false);
          return;
        }
        setState(() => _liveMotionMounted = true);
        // Cap 20.5 / ADR-043 D1: Live PV window — Host mode none rejects pinch.
        // Binders already deactivate (active && !_liveMotionMounted); explicit
        // none covers the gap while deactivate no longer clearIf's.
        // Contrast L1→L2 handoff (keep pointers): destination none cannot
        // continue magnification, so mode→none clears the pointer map.
        // Cap 26.4b: do **not** arm ended-watchdog here — arm only when
        // [_playLiveMotionOnce] issues Host startPlayback.
        _liveHostPhotoRetained = true;
        ref
            .read(magnificationHostModeProvider.notifier)
            .setMode(MagnificationHostMode.none);
        ref
            .read(browseMagnificationProvider.notifier)
            .onLiveMotionMountedChanged(true);
        _syncMediaCoverVisibleGate();
      } catch (_) {
        // Sync failure → keep still; no skip (Cap 9.5 static fallback).
        _liveHostPhotoRetained = false;
        _setLivePreparing(generation, false);
        if (mounted && _liveMotionGate.isCurrent(generation)) {
          setState(() => _liveMotionMounted = false);
          ref
              .read(browseMagnificationProvider.notifier)
              .onLiveMotionMountedChanged(false);
        }
      }
    });
  }

  /// Cap 26.2 / ADR-052 — user long-press replay (bypass skip set).
  Future<void> _userLongPressReplay() async {
    if (!mounted || !widget.isCurrent || !_isLiveStillMedia(_media)) {
      return;
    }
    if (_liveMotionMounted || _livePreparing || _liveSilentReplayInFlight) {
      return;
    }
    final mag = ref.read(browseMagnificationProvider);
    if (mag.hasActiveMagnification) {
      return;
    }
    if (_liveHostPhotoRetained) {
      final remounted = await _remountLiveMotionForUserReplay();
      if (remounted) {
        return;
      }
      _liveHostPhotoRetained = false;
    }
    await _silentReRequestLiveForUserReplay();
  }

  /// Cap 26.5a / ADR-052 Decision 3 — release-to-stop (Photos press-hold).
  ///
  /// Path S in-flight: immediate cancel (do not wait for ready). Path R /
  /// mounted: cancel ended-watchdog (never skip.add) + stop + unload; keep
  /// [_liveHostPhotoRetained]. Natural ended while finger still down: no-op
  /// Host work (already still). Idempotent.
  Future<void> _userLongPressReleaseStop() async {
    if (!mounted) {
      return;
    }
    final wasHolding = _userHoldReplayActive;
    if (wasHolding) {
      _userHoldReplayActive = false;
    }
    // Allow gesture release even if flag already cleared (double delivery).
    final wasSilentInFlight = _liveSilentReplayInFlight;
    if (wasSilentInFlight) {
      _liveSilentReplayInFlight = false;
      _liveHostPhotoRetained = false;
      final LivePhotoRepository live =
          _liveRepo ?? ref.read(livePhotoRepositoryProvider);
      _liveRepo = live;
      final id = widget.assetIdentifier;
      await _unloadLiveMotionSurface();
      if (!mounted) {
        return;
      }
      await _enqueueLiveOp(() async {
        try {
          await live.cancel(id);
          await live.stopPlayback();
        } catch (_) {
          // Best-effort — Host may already have stopped / surface gone.
        }
      });
      return;
    }

    if (_liveMotionMounted || _liveStartIssued || _livePreparing) {
      final LivePhotoRepository live =
          _liveRepo ?? ref.read(livePhotoRepositoryProvider);
      _liveRepo = live;
      // Watchdog cancel without skip.add (unload cancels timer; never add).
      _cancelLiveEndedWatchdog();
      await _unloadLiveMotionSurface();
      if (!mounted) {
        return;
      }
      // Keep [_liveHostPhotoRetained] — same as natural ended → Path R later.
      await _enqueueLiveOp(() async {
        try {
          await live.stopPlayback();
        } catch (_) {
          // Best-effort.
        }
      });
    }
  }

  /// Path R: remount PV + play-only while Host pending is retained (no request).
  /// Returns false when remount cannot proceed (caller may fall through to Path S).
  Future<bool> _remountLiveMotionForUserReplay() async {
    if (!mounted || !widget.isCurrent || !_isLiveStillMedia(_media)) {
      return false;
    }
    if (!_liveHostPhotoRetained || _liveMotionMounted || _livePreparing) {
      return false;
    }
    final LivePhotoRepository live =
        _liveRepo ?? ref.read(livePhotoRepositoryProvider);
    _liveRepo = live;
    final assetId = widget.assetIdentifier;
    unawaited(_cancelLiveSubscriptions());
    final generation = _liveMotionGate.begin();
    _livePhotoReady = true;
    _liveSurfaceReady = false;
    _liveStartIssued = false;
    _liveFailedSub = live.failedEvents.listen((event) {
      if (!_liveMotionGate.isCurrent(generation)) {
        return;
      }
      if (event.assetIdentifier != assetId) {
        return;
      }
      _liveHostPhotoRetained = false;
      unawaited(_unloadLiveMotionSurface());
    });
    _liveEndedSub = live.playbackEndedEvents.listen((event) {
      if (!_liveMotionGate.isCurrent(generation)) {
        return;
      }
      if (event.assetIdentifier != assetId) {
        return;
      }
      unawaited(_unloadLiveMotionSurface());
    });
    if (!mounted || !_liveMotionGate.isCurrent(generation)) {
      return false;
    }
    // Cap 26.4b: arm watchdog in [_playLiveMotionOnce], not at remount.
    setState(() => _liveMotionMounted = true);
    ref
        .read(magnificationHostModeProvider.notifier)
        .setMode(MagnificationHostMode.none);
    ref
        .read(browseMagnificationProvider.notifier)
        .onLiveMotionMountedChanged(true);
    _syncMediaCoverVisibleGate();
    return true;
  }

  /// Path S: silent re-request (no prepare chrome; no skip-set consult).
  Future<void> _silentReRequestLiveForUserReplay() async {
    if (!mounted || !widget.isCurrent || !_isLiveStillMedia(_media)) {
      return;
    }
    if (_liveSilentReplayInFlight || _liveMotionMounted || _livePreparing) {
      return;
    }
    _liveSilentReplayInFlight = true;
    _liveHostPhotoRetained = false;
    final assetId = widget.assetIdentifier;
    final LivePhotoRepository live =
        _liveRepo ?? ref.read(livePhotoRepositoryProvider);
    final PlaybackRepository playback =
        _playbackRepo ?? ref.read(playbackRepositoryProvider);
    _liveRepo = live;
    _playbackRepo = playback;
    _livePhotoReady = false;
    _liveSurfaceReady = false;
    _liveStartIssued = false;

    await _enqueueLiveOp(() async {
      unawaited(_cancelLiveSubscriptions());
      if (!mounted ||
          !widget.isCurrent ||
          !_isLiveStillMedia(_media) ||
          !_liveSilentReplayInFlight) {
        _liveSilentReplayInFlight = false;
        return;
      }
      final generation = _liveMotionGate.begin();
      if (_liveMotionMounted) {
        setState(() => _liveMotionMounted = false);
      }

      _liveReadySub = live.readyEvents.listen((event) {
        if (!_liveMotionGate.isCurrent(generation)) {
          return;
        }
        if (event.assetIdentifier != assetId) {
          return;
        }
        _livePhotoReady = true;
        _liveHostPhotoRetained = true;
        // Clear in-flight only once mounted (ready may race ahead of mount).
        if (_liveMotionMounted) {
          _liveSilentReplayInFlight = false;
        }
        unawaited(_playLiveMotionOnce(generation));
      });
      _liveFailedSub = live.failedEvents.listen((event) {
        if (!_liveMotionGate.isCurrent(generation)) {
          return;
        }
        if (event.assetIdentifier != assetId) {
          return;
        }
        _liveSilentReplayInFlight = false;
        _liveHostPhotoRetained = false;
        unawaited(_unloadLiveMotionSurface());
      });
      _liveEndedSub = live.playbackEndedEvents.listen((event) {
        if (!_liveMotionGate.isCurrent(generation)) {
          return;
        }
        if (event.assetIdentifier != assetId) {
          return;
        }
        unawaited(_unloadLiveMotionSurface());
      });

      try {
        await playback.clearPlaybackPool();
        if (!mounted ||
            !_liveMotionGate.isCurrent(generation) ||
            !widget.isCurrent ||
            !_liveSilentReplayInFlight) {
          _liveSilentReplayInFlight = false;
          return;
        }
        // Host clears pendingLivePhoto at sync entry (before PH async).
        await live.requestLivePhoto(assetId);
        if (!mounted ||
            !_liveMotionGate.isCurrent(generation) ||
            !widget.isCurrent ||
            !_liveSilentReplayInFlight) {
          _liveSilentReplayInFlight = false;
          return;
        }
        // Keep [_liveSilentReplayInFlight] true until ready∧mounted or failed —
        // do not clear on this await (Pigeon returns when sync Host returns).
        // Cap 26.4b: arm watchdog in [_playLiveMotionOnce], not at mount.
        setState(() => _liveMotionMounted = true);
        if (_livePhotoReady) {
          _liveSilentReplayInFlight = false;
        }
        ref
            .read(magnificationHostModeProvider.notifier)
            .setMode(MagnificationHostMode.none);
        ref
            .read(browseMagnificationProvider.notifier)
            .onLiveMotionMountedChanged(true);
        _syncMediaCoverVisibleGate();
      } catch (_) {
        _liveSilentReplayInFlight = false;
        _liveHostPhotoRetained = false;
        if (mounted && _liveMotionGate.isCurrent(generation)) {
          setState(() => _liveMotionMounted = false);
          ref
              .read(browseMagnificationProvider.notifier)
              .onLiveMotionMountedChanged(false);
        }
      }
    });
  }

  /// Play Live motion once — **never** arms [_livePreparing] / spinner.
  ///
  /// Requires ready + surface. Cap 26 long-press Path R / Path S ready enter
  /// here (or Path S silent re-request with prepare chrome off).
  /// Cap 26.4b: arms [kLiveMotionEndedWatchdog] immediately before Host
  /// `startPlayback` (after [_liveStartIssued] latch). Throw → cancel timer,
  /// clear issued, no skip.
  Future<void> _playLiveMotionOnce(int generation) async {
    if (!_liveMotionGate.isCurrent(generation) ||
        !_livePhotoReady ||
        !_liveSurfaceReady ||
        _liveStartIssued) {
      return;
    }
    // Latch before enqueue so concurrent playOnce calls do not double-start.
    _liveStartIssued = true;
    // Cap 9.6 / F4: setMute + startPlayback share LiveHostOpSerial with
    // cancel/request — do not call Live setMute outside this chain.
    await _enqueueLiveOp(() async {
      if (!mounted ||
          !_liveMotionGate.isCurrent(generation) ||
          !_livePhotoReady ||
          !_liveSurfaceReady) {
        return;
      }
      final LivePhotoRepository live =
          _liveRepo ?? ref.read(livePhotoRepositoryProvider);
      _liveRepo = live;
      final muted = ref.read(sharedMuteProvider);
      try {
        await live.setMute(muted);
        if (!mounted || !_liveMotionGate.isCurrent(generation)) {
          return;
        }
        // Cap 26.4b B: arm only once startPlayback is about to be issued
        // (_liveStartIssued already true). Not at PV mount / request return.
        _armLiveEndedWatchdog(widget.assetIdentifier);
        await live.startPlayback();
      } catch (_) {
        _cancelLiveEndedWatchdog();
        _liveStartIssued = false;
        // Keep still; do not skip.
      }
    });
  }

  /// Cap 9.6: preference change while this Live page is current → enqueue.
  void _listenSharedMuteForLive() {
    ref.listen<bool>(sharedMuteProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      if (!widget.isCurrent || !_isLiveStillMedia(_media)) {
        return;
      }
      final LivePhotoRepository live =
          _liveRepo ?? ref.read(livePhotoRepositoryProvider);
      _liveRepo = live;
      unawaited(
        _enqueueLiveOp(() async {
          try {
            await live.setMute(next);
          } catch (_) {}
        }),
      );
    });
  }

  Future<void> _unloadLiveMotionSurface() async {
    if (!mounted) {
      return;
    }
    _cancelLiveEndedWatchdog();
    final generation = _liveMotionGate.begin();
    if (_liveMotionMounted ||
        _livePhotoReady ||
        _liveSurfaceReady ||
        _liveStartIssued) {
      final wasMounted = _liveMotionMounted;
      setState(() {
        _liveMotionMounted = false;
        _livePhotoReady = false;
        _liveSurfaceReady = false;
        _liveStartIssued = false;
      });
      if (wasMounted && widget.isCurrent) {
        ref
            .read(browseMagnificationProvider.notifier)
            .onLiveMotionMountedChanged(false);
      }
    }
    _setLivePreparing(generation, false);
  }

  /// F4 leave path: invalidate token first, then await host cancel/stop.
  Future<void> _teardownLiveMotion({required bool cancelHost}) async {
    final hold = debugHoldOffCurrentTeardown;
    if (hold != null && !widget.isCurrent) {
      await hold.future;
    }
    final generation = _liveMotionGate.begin();
    await _cancelLiveSubscriptions();
    _livePhotoReady = false;
    _liveSurfaceReady = false;
    _liveStartIssued = false;
    _liveSilentReplayInFlight = false;
    if (cancelHost) {
      _liveHostPhotoRetained = false;
    }
    final wasMounted = _liveMotionMounted;
    if (mounted && wasMounted) {
      setState(() => _liveMotionMounted = false);
    }
    _setLivePreparing(generation, false);
    if (!cancelHost) {
      return;
    }
    final live =
        _liveRepo ?? (mounted ? ref.read(livePhotoRepositoryProvider) : null);
    if (live == null) {
      return;
    }
    _liveRepo = live;
    final id = widget.assetIdentifier;
    await _enqueueLiveOp(() async {
      try {
        await live.cancel(id);
        await live.stopPlayback();
      } catch (_) {
        // Best-effort leave teardown.
      }
    });
  }

  Future<void> _cancelCurrentItemPhotoKit(String assetIdentifier) async {
    final display = _displayRepo;
    if (display == null) {
      return;
    }
    try {
      await Future.wait<void>([
        display.cancelPreview(assetIdentifier),
        display.cancelDisplayAsset(assetIdentifier),
        display.cancelPlayableVideo(assetIdentifier),
      ]);
    } catch (_) {}
  }

  void _onPreviewFileBroken() {
    if (!mounted) {
      return;
    }
    final display = _media?.display;
    final path = display?.localFilePath;
    if (display == null || path == null) {
      return;
    }
    if (display.assetIdentifier != widget.assetIdentifier) {
      return;
    }
    if (_previewReloadInFlight || _previewReloadTriedPath == path) {
      return;
    }
    _previewReloadTriedPath = path;
    _previewReloadInFlight = true;
    // Sync Overlay/spinner hide — do not wait for requestPreview.
    setState(() {
      _stillCoverDecodeBroken = true;
      _stillCoverReady = false;
      _stillCoverTrackedPath = path;
    });
    if (widget.isCurrent) {
      unawaited(_reloadPreviewFile());
      return;
    }
    // Cap 15.13 F2: math ±1 off-current — same requestPreview Host path as
    // preheat Layer 1 (PreviewTempFileStore replace-by-id, not a bypass).
    if (_isMathPreheatNeighbor()) {
      unawaited(_reloadPreviewFileOffCurrent());
    } else {
      _previewReloadInFlight = false;
    }
  }

  /// Cap 15.13 F2: off-current neighbour preview reload via [_localGate] +
  /// [MediaDisplayRepository.requestPreview] (same Pigeon/Host LRU path as
  /// preheat [loadFeedPageLayer1]; replace-by-id, no releasePreview fan-out).
  Future<void> _reloadPreviewFileOffCurrent() async {
    final localGen = _localGate.begin();
    _layer1LocalGen = localGen;
    final assetId = widget.assetIdentifier;
    try {
      final preview = await ref
          .read(mediaDisplayRepositoryProvider)
          .requestPreview(assetId);
      if (!mounted ||
          !_localGate.isCurrent(localGen) ||
          widget.isCurrent ||
          !_isMathPreheatNeighbor() ||
          widget.assetIdentifier != assetId) {
        _previewReloadInFlight = false;
        return;
      }
      setState(() {
        final media = _media;
        if (media?.kind == FeedPageMediaKind.video) {
          _media = FeedPageMedia.video(
            media!.videoAssetId ?? assetId,
            poster: preview,
          );
        } else if (media?.kind == FeedPageMediaKind.still ||
            media?.display != null) {
          _media = FeedPageMedia.still(
            preview,
            layer: FeedDisplayLayer.preview,
          );
        } else {
          _media = FeedPageMedia.still(
            preview,
            layer: FeedDisplayLayer.preview,
          );
        }
        // Heal only when path actually changed (same missing path ≠ recover).
        if (preview.localFilePath != _previewReloadTriedPath) {
          _trackStillCoverPath(preview.localFilePath);
        }
        _previewReloadInFlight = false;
      });
    } catch (_) {
      if (mounted && _localGate.isCurrent(localGen)) {
        _previewReloadInFlight = false;
      }
    }
  }

  /// Cap 15.13: committed feedIndex ±1 (Cap 14.5 window), not [_allowedPreheatIndices]
  /// (Phase B lag). PhotoKit budget unchanged — same neighbour ring.
  bool _isMathPreheatNeighbor() {
    if (widget.isCurrent) {
      return false;
    }
    final cur = ref.read(mainBrowseFeedIndexProvider);
    return (widget.feedIndex - cur).abs() == 1;
  }

  Future<void> _reloadPreviewFile() async {
    final gate = widget.currentDisplayGate;
    final generation = widget.assignedDisplayGeneration;
    if (!mounted ||
        !widget.isCurrent ||
        gate == null ||
        generation == null ||
        !gate.isCurrent(generation)) {
      _previewReloadInFlight = false;
      return;
    }
    final assetId = widget.assetIdentifier;
    try {
      final preview = await ref
          .read(mediaDisplayRepositoryProvider)
          .requestPreview(assetId);
      if (!mounted ||
          !gate.isCurrent(generation) ||
          !widget.isCurrent ||
          widget.assignedDisplayGeneration != generation ||
          widget.assetIdentifier != assetId) {
        _previewReloadInFlight = false;
        return;
      }
      setState(() {
        final media = _media;
        if (media?.kind == FeedPageMediaKind.video) {
          _media = FeedPageMedia.video(
            media!.videoAssetId ?? assetId,
            poster: preview,
          );
        } else if (media?.kind == FeedPageMediaKind.still ||
            media?.display != null) {
          _media = FeedPageMedia.still(
            preview,
            layer: FeedDisplayLayer.preview,
          );
        }
        // Heal only when path actually changed (same missing path ≠ recover).
        if (preview.localFilePath != _previewReloadTriedPath) {
          _trackStillCoverPath(preview.localFilePath);
        }
        _previewReloadInFlight = false;
      });
    } catch (_) {
      if (mounted) {
        _previewReloadInFlight = false;
      }
    }
  }

  /// Cap 16.4: arm a cancelable timer when this page becomes current.
  /// Join with Layer 1: Layer 2 waits for this future (already complete if
  /// Layer 1 took longer than N). [dwell] defaults to production 300 ms;
  /// Cap 15.12 first-visit fast path passes [browseLocalFirstVisitDwellProvider].
  void _armLayer2DwellTimer({Duration? dwellDuration}) {
    _cancelLayer2DwellTimer();
    final Duration n = dwellDuration ?? ref.read(browseLayer2DwellProvider);
    if (n <= Duration.zero) {
      _layer2DwellCompleter = Completer<void>()..complete();
      return;
    }
    final done = Completer<void>();
    _layer2DwellCompleter = done;
    _layer2DwellTimer = Timer(n, () {
      _layer2DwellTimer = null;
      if (!done.isCompleted) {
        done.complete();
      }
    });
  }

  void _cancelLayer2DwellTimer() {
    _layer2DwellTimer?.cancel();
    _layer2DwellTimer = null;
    final pending = _layer2DwellCompleter;
    _layer2DwellCompleter = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  Future<void> _awaitLayer2Dwell({
    required bool bypassDwell,
    Duration? dwellDuration,
  }) async {
    if (bypassDwell) {
      return;
    }
    var pending = _layer2DwellCompleter;
    if (pending == null) {
      // Leave / dispose already cancelled. Do not start a new clock off-current
      // (a later become-current re-arm would complete that timer and skip N).
      if (!widget.isCurrent) {
        return;
      }
      _armLayer2DwellTimer(dwellDuration: dwellDuration);
      pending = _layer2DwellCompleter;
    }
    if (pending == null) {
      return;
    }
    await pending.future;
  }

  Future<void> _retryLayer2Only({bool bypassDwell = false}) async {
    final FeedMediaRequestGate gate;
    final int generation;
    if (widget.isCurrent) {
      final shared = widget.currentDisplayGate;
      final assigned = widget.assignedDisplayGeneration;
      if (shared == null || assigned == null) {
        return;
      }
      gate = shared;
      generation = assigned;
    } else {
      return;
    }
    setState(() {
      _layer2Failed = false;
      _layer2FailureReason = null;
      _armLayer2InFlight(
        generation,
        path: WaitChromePathClass.a2WaitToPlayable,
      );
    });
    await _awaitLayer2Dwell(bypassDwell: bypassDwell);
    if (!mounted || !widget.isCurrent || !gate.isCurrent(generation)) {
      // B: dwell (or role/gate) abandoned this retry — not still waiting.
      _abandonLayer2Attempt(generation, reason: 'retry-l2-early');
      return;
    }
    final layer1 = _media;
    final layer2 = await loadFeedPageLayer2(
      gate: gate,
      generation: generation,
      sourceKind: widget.sourceKind,
      assetIdentifier: widget.assetIdentifier,
      feedIndex: widget.feedIndex,
      isCurrent: widget.isCurrent,
      layer1: layer1,
      displayRepository: ref.read(mediaDisplayRepositoryProvider),
      playbackRepository: ref.read(playbackRepositoryProvider),
    );
    await _applyLayer2Result(
      gate: gate,
      generation: generation,
      layer1: layer1,
      layer2: layer2,
    );
  }

  bool _canJoinInFlightLayer1() {
    final gen = _layer1LocalGen;
    final future = _layer1Future;
    if (future == null || gen == null) {
      return false;
    }
    if (!_localGate.isCurrent(gen)) {
      return false;
    }
    final display = _media?.display;
    if (display != null && display.assetIdentifier == widget.assetIdentifier) {
      return false;
    }
    return true;
  }

  void _applyLayer1StillIdempotent(
    FeedPageMedia? layer1, {
    required bool layer2Follows,
    int? layer2Generation,
  }) {
    final display = layer1?.display;
    if (display == null) {
      if (layer2Follows && !_layer2InFlight && layer2Generation != null) {
        setState(() => _armLayer2InFlight(layer2Generation));
      }
      return;
    }
    // Cap 15.7: neighbour Layer 1 must not overwrite video+poster with a
    // still-kind [layer1]. Keep the leaving page as video; skip the write.
    if (_media?.kind == FeedPageMediaKind.video &&
        _media?.display != null &&
        !widget.isCurrent) {
      return;
    }
    final sameStill =
        _media?.display?.assetIdentifier == display.assetIdentifier &&
        _media?.display?.localFilePath == display.localFilePath &&
        !_loading;
    if (sameStill && (!layer2Follows || _layer2InFlight)) {
      return;
    }
    setState(() {
      _media = layer1;
      _loading = false;
      _trackStillCoverPath(layer1?.display?.localFilePath);
      if (layer2Follows && layer2Generation != null) {
        _armLayer2InFlight(layer2Generation);
      }
    });
    widget.onLayer1Available?.call(widget.assetIdentifier, layer1!);
  }

  Future<void> _runLayer2AfterJoinedLayer1({
    required FeedMediaRequestGate currentGate,
    required int currentGeneration,
    required FeedPageMedia? layer1,
    required bool bypassDwell,
  }) async {
    if (layer1 != null) {
      _applyLayer1StillIdempotent(
        layer1,
        layer2Follows: true,
        layer2Generation: currentGeneration,
      );
    } else {
      setState(() => _armLayer2InFlight(currentGeneration));
    }
    await _awaitLayer2Dwell(bypassDwell: bypassDwell);
    if (!mounted ||
        !currentGate.isCurrent(currentGeneration) ||
        !widget.isCurrent) {
      // C: join→L2 abandoned after arm (dwell / gate / leave).
      _abandonLayer2Attempt(currentGeneration, reason: 'join-l2-early');
      return;
    }
    final displayRepo = ref.read(mediaDisplayRepositoryProvider);
    final playbackRepo = ref.read(playbackRepositoryProvider);
    _displayRepo = displayRepo;
    final layer2 = await loadFeedPageLayer2(
      gate: currentGate,
      generation: currentGeneration,
      sourceKind: widget.sourceKind,
      assetIdentifier: widget.assetIdentifier,
      feedIndex: widget.feedIndex,
      isCurrent: widget.isCurrent,
      layer1: layer1,
      displayRepository: displayRepo,
      playbackRepository: playbackRepo,
    );
    await _applyLayer2Result(
      gate: currentGate,
      generation: currentGeneration,
      layer1: layer1,
      layer2: layer2,
    );
  }

  Future<void> _startLoad({
    bool bypassDwell = false,

    /// When true, skip the Cap 15.12 device-local fast path. Used only to
    /// prevent re-entering the fast path if fallback were routed through
    /// [_startLoad]; production fallback calls [_runFullLayer1BecomeCurrentPath]
    /// directly instead. No production caller sets this today.
    bool bypassDeviceLocalFastPath = false,
  }) async {
    final startedOffCurrent = !widget.isCurrent;
    FeedMediaRequestGate? gate;
    int? generation;
    if (!startedOffCurrent) {
      final shared = widget.currentDisplayGate;
      final assigned = widget.assignedDisplayGeneration;
      if (shared == null || assigned == null) {
        // Parent activation not ready yet. Keep a preheat still if we have one.
        final reuseLayer1 =
            _media?.display != null &&
            _media!.display!.assetIdentifier == widget.assetIdentifier;
        if (reuseLayer1) {
          return;
        }
        final liveGeneration = _liveMotionGate.begin();
        final sessionTok = ref
            .read(browseL2ReadySessionProvider.notifier)
            .lookup(widget.assetIdentifier);
        setState(() {
          _loading = true;
          _media = null;
          _clearStillCoverTracking();
          _surfaceReady = false;
          _liveMotionMounted = false;
          // Cap 17.3: avoid a1 miss gold during gate-not-ready if Session
          // already knows this id (a4 eviction revisit).
          if (sessionTok != null) {
            _layer2WaitPath = WaitChromePathClass.a4L2ReadyEvict;
          }
        });
        _setLivePreparing(liveGeneration, false);
        return;
      }
      gate = shared;
      generation = assigned;
    }

    if (!startedOffCurrent) {
      final forceFullAfterHostUnavailable =
          _needsFullReloadAfterHostUnavailable;
      // Share D14 iCloud limb: publish before any early L2-ready return.
      final listAvail = await _resolveAndPublishListAvailability(
        gate: gate!,
        generation: generation!,
      );
      if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
        return;
      }
      if (forceFullAfterHostUnavailable) {
        // Drop neighbour-preheat L1 / pendingVideo from Case B leave so we
        // cannot reuseLayer1 → `_retryLayer2Only` and stick on preview.
        setState(() {
          _layer2Failed = false;
          _layer2FailureReason = null;
          _clearLayer2InFlightUnconditional();
          _surfaceReady = false;
          _liveMotionMounted = false;
          _loading = true;
          _media = null;
          _clearStillCoverTracking();
        });
      }
      final sessionToken = ref
          .read(browseL2ReadySessionProvider.notifier)
          .lookup(widget.assetIdentifier);
      final hadSessionToken = sessionToken != null;
      // Cap 17.3: tag a4 before cover-on-disk await so a remount still on
      // [_loading] does not paint ADR-031 miss gold during the gap.
      if (hadSessionToken) {
        if (_loading && _layer2WaitPath != WaitChromePathClass.a4L2ReadyEvict) {
          setState(() {
            _layer2WaitPath = WaitChromePathClass.a4L2ReadyEvict;
          });
        } else {
          _layer2WaitPath = WaitChromePathClass.a4L2ReadyEvict;
        }
      }
      // After Case B, skip Session L2-ready even if a token reappears — force
      // Host path so a Photos restore is observed.
      if (!forceFullAfterHostUnavailable) {
        final l2Ready = await ref
            .read(browseL2ReadySessionProvider.notifier)
            .lookupIfCoverOnDisk(widget.assetIdentifier);
        if (l2Ready != null) {
          if (l2Ready.kind == FeedL2ReadyKind.stillFull ||
              l2Ready.kind == FeedL2ReadyKind.video) {
            // Video L2-ready-with-cover uses a4 band (a5 fold); still hit is a3.
            _layer2WaitPath = l2Ready.kind == FeedL2ReadyKind.video
                ? WaitChromePathClass.a4L2ReadyEvict
                : WaitChromePathClass.a3L2ReadyHit;
            await _startLoadFromL2Ready(
              l2Ready: l2Ready,
              gate: gate!,
              generation: generation!,
            );
            return;
          }
        }
      }

      // Cover missing after Session token → a4 eviction revisit band.
      _layer2WaitPath = hadSessionToken
          ? WaitChromePathClass.a4L2ReadyEvict
          : WaitChromePathClass.a2WaitToPlayable;

      if (!bypassDeviceLocalFastPath && !forceFullAfterHostUnavailable) {
        // Cap 15.15: prefer snapshot inject (tests); else on-demand Host probe
        // for the current id only. Probe failure / leave → conservative L1.
        // Availability already published above for Share (ADR-051 D14).
        final currentGate = gate!;
        final currentGeneration = generation!;
        final avail = listAvail;
        if (avail == AssetAvailability.deviceLocal) {
          await _startLoadFromDeviceLocalFirstVisit(
            gate: currentGate,
            generation: currentGeneration,
            bypassDwell: bypassDwell,
          );
          return;
        }
      }
    }

    if (startedOffCurrent) {
      setState(() {
        _clearLayer2InFlightUnconditional();
        _layer2Failed = false;
        _layer2FailureReason = null;
        _surfaceReady = false;
        _liveMotionMounted = false;
        if (_media?.display != null) {
          _loading = false;
        } else if (_media?.kind == FeedPageMediaKind.video ||
            _media?.kind == FeedPageMediaKind.pendingVideo ||
            widget.sourceKind == AssetSourceKind.mediaTypeVideos) {
          _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
          _loading = false;
        } else {
          _media = null;
          _loading = false;
        }
      });
      if (!widget.isPreheatNeighbor) {
        return;
      }
      if (_canJoinInFlightLayer1()) {
        final layer1 = await _layer1Future;
        if (!mounted || !_localGate.isCurrent(_layer1LocalGen!)) {
          return;
        }
        if (widget.isCurrent) {
          return;
        }
        if (!widget.isPreheatNeighbor) {
          return;
        }
        _applyLayer1StillIdempotent(layer1, layer2Follows: false);
        return;
      }
      final localGen = _localGate.begin();
      _layer1LocalGen = localGen;
      final displayRepo = ref.read(mediaDisplayRepositoryProvider);
      _displayRepo = displayRepo;
      final future = loadFeedPageLayer1(
        gate: _localGate,
        generation: localGen,
        assetIdentifier: widget.assetIdentifier,
        displayRepository: displayRepo,
      );
      _layer1Future = future;
      final layer1 = await future;
      if (!mounted || !_localGate.isCurrent(localGen)) {
        return;
      }
      if (widget.isCurrent) {
        return;
      }
      if (!widget.isPreheatNeighbor) {
        return;
      }
      _applyLayer1StillIdempotent(layer1, layer2Follows: false);
      return;
    }

    final reuseLayer1 =
        !_needsFullReloadAfterHostUnavailable &&
        widget.isCurrent &&
        _media?.display != null &&
        _media!.display!.assetIdentifier == widget.assetIdentifier;
    if (reuseLayer1) {
      await Future<void>.value();
      if (!mounted || !widget.isCurrent) {
        return;
      }
      // Neighbour promote normally never mounted Live; if flags are set,
      // a later _startLoad branch leaked state — tear down instead of skip.
      if (_liveMotionMounted || _livePreparing) {
        await _teardownLiveMotion(cancelHost: true);
        if (!mounted || !widget.isCurrent) {
          return;
        }
      }
      await _retryLayer2Only();
      return;
    }

    if (_canJoinInFlightLayer1()) {
      final joinGate = gate!;
      final joinGeneration = generation!;
      if (_media?.display == null) {
        setState(() {
          _layer2Failed = false;
          _layer2FailureReason = null;
          _clearLayer2InFlightUnconditional();
          _surfaceReady = false;
          _liveMotionMounted = false;
          _loading = true;
          _media = null;
          _clearStillCoverTracking();
        });
      }
      final joined = await _layer1Future;
      if (!mounted || !_localGate.isCurrent(_layer1LocalGen!)) {
        return;
      }
      if (!joinGate.isCurrent(joinGeneration) || !widget.isCurrent) {
        return;
      }
      await _runLayer2AfterJoinedLayer1(
        currentGate: joinGate,
        currentGeneration: joinGeneration,
        layer1: joined,
        bypassDwell: bypassDwell,
      );
      return;
    } // Current full reload: await host cancel so a new Live request cannot
    // race leave (F4 / ADR-006). Neighbour reuseLayer1 skips this unless
    // Live flags leaked (above). Leave already queued cancel; maybeBegin
    // shares LiveHostOpSerial with that cancel.
    await _runFullLayer1BecomeCurrentPath(
      gate: gate!,
      generation: generation!,
      bypassDwell: bypassDwell,
    );
  }

  /// ADR-025 full become-current path: L1 → production dwell → L2.
  Future<void> _runFullLayer1BecomeCurrentPath({
    required FeedMediaRequestGate gate,
    required int generation,
    required bool bypassDwell,
  }) async {
    final cancelHost = _liveMotionMounted || _isLiveStillMedia(_media);
    await _teardownLiveMotion(cancelHost: cancelHost);
    if (!mounted) {
      return;
    }

    final currentGate = gate;
    final currentGeneration = generation;

    setState(() {
      _layer2Failed = false;
      _layer2FailureReason = null;
      _clearLayer2InFlightUnconditional();
      _surfaceReady = false;
      _liveMotionMounted = false;
      if (_media?.display == null) {
        _loading = true;
        _media = null;
        _clearStillCoverTracking();
      }
    });

    final displayRepo = ref.read(mediaDisplayRepositoryProvider);
    final playbackRepo = ref.read(playbackRepositoryProvider);
    _displayRepo = displayRepo;

    final layer1 = await loadFeedPageLayer1(
      gate: currentGate,
      generation: currentGeneration,
      assetIdentifier: widget.assetIdentifier,
      displayRepository: displayRepo,
    );
    if (!mounted || !currentGate.isCurrent(currentGeneration)) {
      // L1 returned but this generation is already superseded — may not have
      // armed inFlight yet; still drop [_loading] so we do not spin forever.
      if (mounted) {
        setState(() => _loading = false);
      } else {
        _loading = false;
      }
      _abandonLayer2Attempt(
        currentGeneration,
        reason: 'full-l1-stale-after-l1',
      );
      return;
    }
    if (layer1 != null) {
      setState(() {
        _media = layer1;
        _loading = false;
        _trackStillCoverPath(layer1.display?.localFilePath);
        _armLayer2InFlight(currentGeneration);
      });
    } else {
      setState(() {
        _armLayer2InFlight(currentGeneration);
      });
    }

    await _awaitLayer2Dwell(bypassDwell: bypassDwell);
    if (!mounted ||
        !currentGate.isCurrent(currentGeneration) ||
        !widget.isCurrent) {
      // D: full-L1→dwell abandoned (gate / leave / unmount).
      _abandonLayer2Attempt(currentGeneration, reason: 'full-l1-dwell-early');
      return;
    }

    final layer2 = await loadFeedPageLayer2(
      gate: currentGate,
      generation: currentGeneration,
      sourceKind: widget.sourceKind,
      assetIdentifier: widget.assetIdentifier,
      feedIndex: widget.feedIndex,
      isCurrent: widget.isCurrent,
      layer1: layer1,
      displayRepository: displayRepo,
      playbackRepository: playbackRepo,
    );
    await _applyLayer2Result(
      gate: currentGate,
      generation: currentGeneration,
      layer1: layer1,
      layer2: layer2,
    );
  }

  /// Cap 15.12: device-local first visit — skip still blur L1; video V1 keeps
  /// local poster; N_local dwell before L2; false-positive L2 → full L1 fallback.
  ///
  /// Yield one event-loop turn, then [File.existsSync].
  ///
  /// Do not [await File.exists] here — it never completes under FakeAsync
  /// (same constraint as Cap 15.13 batch evict). Yielding first keeps
  /// [didUpdateWidget] off the stat.
  Future<bool> _previewFileExists(String path) async {
    await Future<void>.value();
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Cap 15.14 / 3A: immediate video promote only when the cover is known video
  /// (Videos tab, or All-tab item whose preview mediaKind is video).
  bool _isKnownVideoCover(DisplayAsset display) {
    return widget.sourceKind == AssetSourceKind.mediaTypeVideos ||
        display.mediaKind == PlaybackMediaKind.video;
  }

  Future<void> _startLoadFromDeviceLocalFirstVisit({
    required FeedMediaRequestGate gate,
    required int generation,
    bool bypassDwell = false,
  }) async {
    final nLocal = ref.read(browseLocalFirstVisitDwellProvider);
    _cancelLayer2DwellTimer();
    _armLayer2DwellTimer(dwellDuration: nLocal);

    final cancelHost = _liveMotionMounted || _isLiveStillMedia(_media);
    await _teardownLiveMotion(cancelHost: cancelHost);
    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      _abandonLayer2Attempt(generation, reason: 'local-first-teardown-early');
      return;
    }

    // Cap 15.14: paint retention (keepPeekCover) stays separate from skip-L1
    // (canReuseCover). Dead peek paths must not blank Photos (no L1 reload);
    // Videos/All still re-requestPreview when the file is gone (2B).
    final existingDisplay = _media?.display;
    final keepPeekCover =
        existingDisplay != null &&
        existingDisplay.assetIdentifier == widget.assetIdentifier;
    final canReuseCover =
        keepPeekCover &&
        await _previewFileExists(existingDisplay!.localFilePath);
    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      _abandonLayer2Attempt(generation, reason: 'local-first-exists-stale');
      return;
    }
    setState(() {
      _layer2Failed = false;
      _layer2FailureReason = null;
      _clearLayer2InFlightUnconditional();
      _surfaceReady = false;
      _liveMotionMounted = false;
      if (keepPeekCover) {
        _loading = false;
        // Decision 3A: promote known-video only when we also skip L1 (file
        // still exists). Otherwise wait for a fresh preview / L2.
        if (canReuseCover && _isKnownVideoCover(existingDisplay)) {
          _media = FeedPageMedia.video(
            widget.assetIdentifier,
            poster: existingDisplay,
          );
          _trackStillCoverPath(existingDisplay.localFilePath);
        }
      } else {
        _loading = true;
        _media = null;
        _clearStillCoverTracking();
      }
    });

    final displayRepo = ref.read(mediaDisplayRepositoryProvider);
    final playbackRepo = ref.read(playbackRepositoryProvider);
    _displayRepo = displayRepo;

    FeedPageMedia? layer1;
    final loadPoster =
        widget.sourceKind == AssetSourceKind.mediaTypeVideos ||
        widget.sourceKind == AssetSourceKind.entireLibrary;
    if (loadPoster) {
      if (canReuseCover) {
        // Skip second requestPreview (decision 1A). Mirror post-L1 branching
        // without a Host round-trip.
        if (widget.sourceKind == AssetSourceKind.entireLibrary &&
            existingDisplay!.mediaKind != PlaybackMediaKind.video) {
          layer1 = null;
        } else if (_isKnownVideoCover(existingDisplay!)) {
          layer1 = FeedPageMedia.video(
            widget.assetIdentifier,
            poster: existingDisplay,
          );
        } else {
          layer1 = FeedPageMedia.still(
            existingDisplay,
            layer: FeedDisplayLayer.preview,
          );
        }
        setState(() => _armLayer2InFlight(generation));
      } else {
        layer1 = await loadFeedPageLayer1(
          gate: gate,
          generation: generation,
          assetIdentifier: widget.assetIdentifier,
          displayRepository: displayRepo,
        );
        if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
          _abandonLayer2Attempt(generation, reason: 'local-first-l1-stale');
          return;
        }
        final preview = layer1?.display;
        if (widget.sourceKind == AssetSourceKind.entireLibrary &&
            preview?.mediaKind != PlaybackMediaKind.video) {
          layer1 = null;
        } else if (preview != null &&
            preview.mediaKind == PlaybackMediaKind.video) {
          setState(() {
            _loading = false;
            _media = FeedPageMedia.video(
              widget.assetIdentifier,
              poster: preview,
            );
            _trackStillCoverPath(preview.localFilePath);
            _armLayer2InFlight(generation);
          });
        } else if (layer1 != null) {
          final cover = layer1;
          setState(() {
            _loading = false;
            _media = cover;
            _trackStillCoverPath(cover.display?.localFilePath);
            _armLayer2InFlight(generation);
          });
        } else {
          setState(() => _armLayer2InFlight(generation));
        }
      }
    } else {
      setState(() => _armLayer2InFlight(generation));
    }

    await _awaitLayer2Dwell(bypassDwell: bypassDwell);
    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      _abandonLayer2Attempt(generation, reason: 'local-first-dwell-early');
      return;
    }

    final layer2 = await loadFeedPageLayer2(
      gate: gate,
      generation: generation,
      sourceKind: widget.sourceKind,
      assetIdentifier: widget.assetIdentifier,
      feedIndex: widget.feedIndex,
      isCurrent: widget.isCurrent,
      layer1: layer1 ?? _media,
      displayRepository: displayRepo,
      playbackRepository: playbackRepo,
    );

    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      _abandonLayer2Attempt(generation, reason: 'local-first-l2-stale');
      return;
    }

    if (layer2 == null || layer2.kind == FeedPageMediaKind.failed) {
      _cancelLayer2DwellTimer();
      _armLayer2DwellTimer();
      await _runFullLayer1BecomeCurrentPath(
        gate: gate,
        generation: generation,
        bypassDwell: false,
      );
      return;
    }

    await _applyLayer2Result(
      gate: gate,
      generation: generation,
      layer1: layer1,
      layer2: layer2,
      // Cap 15.14c: arm whenever DEVICE_LOCAL reaches video APPLY — independent
      // of canReuseCover (dead peek file still needs hold; align with L2_READY).
      armPosterHoldOnL2Apply: true,
    );
  }

  Future<void> _applyLayer2Result({
    required FeedMediaRequestGate gate,
    required int generation,
    required FeedPageMedia? layer1,
    required FeedPageMedia? layer2,

    /// Cap 15.14b/c: L2-ready + DEVICE_LOCAL arm poster-hold at L2 apply —
    /// not first-visit full L1→L2 (15.11b mount-time arm).
    bool armPosterHoldOnL2Apply = false,
  }) async {
    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      // A: drop — this attempt no longer owns the page; clear only if owner.
      _abandonLayer2Attempt(generation, reason: 'l2-result-stale');
      return;
    }
    if (layer2 == null) {
      setState(() {
        _clearLayer2InFlightUnconditional();
      });
      return;
    }
    if (layer2.kind == FeedPageMediaKind.failed) {
      // Revisit model: if Photos says not still-in-library, never leave the
      // page on Case A (generic + Retry + actionable). Coerce to Cap 21.6 B.
      final rawReason = layer2.failureReason ?? FeedFailureReason.generic;
      final reason = await _coerceUnavailableFeedFailure(rawReason);
      if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
        _abandonLayer2Attempt(generation, reason: 'l2-fail-coerce-stale');
        return;
      }
      setState(() {
        _clearLayer2InFlightUnconditional();
        _layer2FailureReason = reason;
        if (reason == FeedFailureReason.assetUnavailable) {
          // Case B: Host confirmed gone — drop residual cover / L1. Keep-cover
          // under unavailable copy contradicted Cap 21.6 B chrome (owner device).
          _media = FeedPageMedia.failed(reason: reason);
          _loading = false;
          _layer2Failed = false;
          _clearStillCoverTracking();
          // Next become-current (after leave) must full-reload — not
          // reuseLayer1. Parked-on-B restore without leave stays accepted.
          _needsFullReloadAfterHostUnavailable = true;
        } else if (_media?.display != null || layer1?.display != null) {
          // Recoverable fails: keep painted cover; Overlay may remain.
          _stillCoverDecodeBroken = false;
          _layer2Failed = true;
          _loading = false;
        } else {
          _media = FeedPageMedia.failed(reason: reason);
          _loading = false;
          _layer2Failed = false;
        }
      });
      if (reason == FeedFailureReason.assetUnavailable) {
        // Avoid Session L2-ready revisit re-painting the deleted JPEG (456a
        // limb after Host already told the truth this visit).
        ref
            .read(browseL2ReadySessionProvider.notifier)
            .evict(widget.assetIdentifier);
      }
      _publishHostUnavailableGate();
      _publishLayer2DisplayReady(false);
      return;
    }
    if (layer2.kind == FeedPageMediaKind.video) {
      setState(() {
        _media = FeedPageMedia.video(
          layer2.videoAssetId!,
          poster: layer1?.display ?? _media?.display,
        );
        _loading = false;
        _trackStillCoverPath(
          (layer1?.display ?? _media?.display)?.localFilePath,
        );
        // I: WIP — success clears inFlight so canMountVideo may mount.
        // Do NOT keep true until surface-ready (HEAD) — that deadlocks
        // canMountVideo. Cap 17.3: L2 success clears wait chrome with
        // inFlight (no min-show hold).
        _completeLayer2InFlightForSuccess();
        _layer2Failed = false;
        _layer2FailureReason = null;
        _needsFullReloadAfterHostUnavailable = false;
        // Cap 15.14b/c: DEVICE_LOCAL / L2-ready close the gap where canMount
        // becomes true before build's null→non-null hold arm.
        if (armPosterHoldOnL2Apply) {
          _armPosterHoldOnVideoSlotMount();
        }
      });
      _recordL2ReadySession(layer2: layer2, layer1: layer1);
      // Cap 15.11b: first-visit full L1→L2 still arms hold on video-slot
      // mount only (defer / in-flight ordering). DEVICE_LOCAL / L2-ready
      // use armPosterHoldOnL2Apply above (15.14b/c).
      _publishHostUnavailableGate();
      // Video: Share L2-ready waits for surface (Decision 14); keep false.
      await _syncPlaybackActive(requireSurfaceReady: false);
      return;
    }
    final liveStill =
        layer2.kind == FeedPageMediaKind.still &&
        layer2.display?.mediaKind == PlaybackMediaKind.livePhoto;
    setState(() {
      _media = layer2;
      _loading = false;
      _trackStillCoverPath(layer2.display?.localFilePath);
      // Capture before L2 clear — latch is for this inFlight only.
      final latchedL2WaitChrome = _layer2WaitChromeLatched;
      _completeLayer2InFlightForSuccess();
      _layer2Failed = false;
      _layer2FailureReason = null;
      _needsFullReloadAfterHostUnavailable = false;
      // 14.6b: same-frame handoff so the Live spinner does not drop while
      // [_prepareLiveMotion] awaits LiveHostOpSerial.
      // ADR-037: if L2 wait chrome already painted, skip F1 <T on motion.
      if (liveStill && widget.isCurrent) {
        _livePreparingSkipSuppressBelowT = latchedL2WaitChrome;
        _livePreparing = true;
        _onLivePreparingChanged(true);
      }
      _layer2WaitChromeLatched = false;
    });
    _recordL2ReadySession(layer2: layer2, layer1: layer1);
    widget.onCurrentLayer2MediaReady?.call(widget.assetIdentifier);
    _publishHostUnavailableGate();
    _publishLayer2DisplayReady(true);
    await _prepareLiveMotion();
  }

  void _recordL2ReadySession({
    required FeedPageMedia layer2,
    FeedPageMedia? layer1,
  }) {
    final id = widget.assetIdentifier;
    switch (layer2.kind) {
      case FeedPageMediaKind.still:
        if (layer2.displayLayer == FeedDisplayLayer.full &&
            layer2.display != null) {
          ref
              .read(browseL2ReadySessionProvider.notifier)
              .record(
                FeedL2ReadyEntry(
                  assetIdentifier: id,
                  kind: FeedL2ReadyKind.stillFull,
                  cover: layer2.display,
                ),
              );
        }
      case FeedPageMediaKind.video:
        final poster = layer1?.display ?? _media?.display;
        ref
            .read(browseL2ReadySessionProvider.notifier)
            .record(
              FeedL2ReadyEntry(
                assetIdentifier: id,
                kind: FeedL2ReadyKind.video,
                cover: poster,
              ),
            );
      case FeedPageMediaKind.pendingVideo:
      case FeedPageMediaKind.failed:
        break;
    }
  }

  void _holdVideoSurfaceForL2ReloadIfNeeded(int generation) {
    if (!widget.isCurrent) {
      return;
    }
    final l2Ready = ref
        .read(browseL2ReadySessionProvider.notifier)
        .lookup(widget.assetIdentifier);
    if (l2Ready?.kind != FeedL2ReadyKind.video) {
      return;
    }
    final kind = _media?.kind;
    if (kind != FeedPageMediaKind.video &&
        kind != FeedPageMediaKind.pendingVideo) {
      return;
    }
    // ADR-039: normalize the coverless re-enter page before in-flight arm.
    // `_startLoad` yields in lookupIfCoverOnDisk; arming first while
    // `_loading == false` exposed a transient center Layer2Waiting state.
    if (_media?.display == null) {
      _loading = true;
    }
    _armLayer2InFlight(generation);
    _surfaceReady = false;
  }

  /// Cap 15.10: Session L2-ready fast path — skip L1 (+ dwell); still shows
  /// sharp; video keeps poster until [onSurfaceReady].
  Future<void> _startLoadFromL2Ready({
    required FeedL2ReadyEntry l2Ready,
    required FeedMediaRequestGate gate,
    required int generation,
  }) async {
    final isVideoFastPath = l2Ready.kind == FeedL2ReadyKind.video;
    if (isVideoFastPath) {
      _holdVideoSurfaceForL2ReloadIfNeeded(generation);
      setState(() {
        _layer2Failed = false;
        _layer2FailureReason = null;
        _surfaceReady = false;
        _liveMotionMounted = false;
        _loading = false;
        _trackStillCoverPath(l2Ready.cover?.localFilePath);
        _armLayer2InFlight(generation);
        _media = FeedPageMedia.video(
          widget.assetIdentifier,
          poster: l2Ready.cover,
        );
      });
      // Cap 15.14b: poster-hold arms at L2 apply (see [_applyLayer2Result]).
    }

    // Still revisit must not await a held Live cancel chain — leave already
    // queued cancel; 14.6b needs preparing chrome while cancel is in flight.
    final cancelHost = l2Ready.kind == FeedL2ReadyKind.stillFull
        ? _liveMotionMounted
        : (_liveMotionMounted || _isLiveStillMedia(_media));
    await _teardownLiveMotion(cancelHost: cancelHost);
    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      // F1: teardown gap — attempt abandoned (unmount / gate bump / leave).
      // Clear→false only if this [generation] still owns inFlight (see
      // _abandonLayer2Attempt). canMountVideo still requires isCurrent, so
      // leave/off-current cannot mount; gate-stale leaves a newer arm intact.
      _abandonLayer2Attempt(generation, reason: 'l2-ready-teardown-early');
      return;
    }

    if (l2Ready.kind == FeedL2ReadyKind.stillFull && l2Ready.cover != null) {
      final liveStill = l2Ready.cover!.mediaKind == PlaybackMediaKind.livePhoto;
      setState(() {
        _layer2Failed = false;
        _layer2FailureReason = null;
        _needsFullReloadAfterHostUnavailable = false;
        _clearLayer2InFlightUnconditional();
        _surfaceReady = false;
        _liveMotionMounted = false;
        _loading = false;
        _trackStillCoverPath(l2Ready.cover!.localFilePath);
        _media = FeedPageMedia.still(
          l2Ready.cover!,
          layer: FeedDisplayLayer.full,
        );
        if (liveStill && widget.isCurrent) {
          _livePreparingSkipSuppressBelowT = false;
          _livePreparing = true;
          _onLivePreparingChanged(true);
        }
      });
      widget.onCurrentLayer2MediaReady?.call(widget.assetIdentifier);
      _publishHostUnavailableGate();
      _publishLayer2DisplayReady(true);
      await _prepareLiveMotion();
      return;
    }

    if (isVideoFastPath) {
      await _awaitLayer2Dwell(bypassDwell: true);
      if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
        // F2: post-dwell abandon — same ownership rule as F1.
        _abandonLayer2Attempt(generation, reason: 'l2-ready-dwell-early');
        return;
      }
      final displayRepo = ref.read(mediaDisplayRepositoryProvider);
      final playbackRepo = ref.read(playbackRepositoryProvider);
      _displayRepo = displayRepo;
      final layer1 = _media;
      final layer2 = await loadFeedPageLayer2(
        gate: gate,
        generation: generation,
        sourceKind: widget.sourceKind,
        assetIdentifier: widget.assetIdentifier,
        feedIndex: widget.feedIndex,
        isCurrent: widget.isCurrent,
        layer1: layer1,
        displayRepository: displayRepo,
        playbackRepository: playbackRepo,
      );
      await _applyLayer2Result(
        gate: gate,
        generation: generation,
        layer1: layer1,
        layer2: layer2,
        armPosterHoldOnL2Apply: true,
      );
    }
  }

  SystemPlaybackPermission _playbackPermission({
    bool requireSurfaceReady = true,
    bool assumeForegroundLifecycle = false,
  }) {
    final coordinator = ref.read(playbackCoordinatorProvider);
    final pvGuard = ref.read(pvTransitionGuardProvider);
    final media = _media;
    return SystemPlaybackPermission(
      isForegroundLifecycle:
          assumeForegroundLifecycle || coordinator.isForegroundLifecycle,
      isCurrentPage: widget.isCurrent,
      isL2ReadyVideo:
          media?.kind == FeedPageMediaKind.video && !_layer2InFlight,
      isSurfaceReady: !requireSurfaceReady || _surfaceReady,
      transitionBlocksPlayback: pvGuard.isCovering(widget.assetIdentifier),
      hasHardPlaybackFailure: _layer2Failed,
    );
  }

  /// Play when this page is current + surface ready. Never pause from here.
  Future<void> _syncPlaybackActive({bool requireSurfaceReady = true}) async {
    final media = _media;
    if (media == null || media.kind != FeedPageMediaKind.video) {
      return;
    }
    if (!widget.isCurrent) {
      return;
    }
    if (requireSurfaceReady && !_surfaceReady) {
      return;
    }
    final gate = widget.currentDisplayGate;
    final generation = widget.assignedDisplayGeneration;
    if (gate == null || generation == null) {
      return;
    }
    final coordinator = ref.read(playbackCoordinatorProvider);
    if (!coordinator.isForegroundLifecycle && _bindingLifecycleIsResumed()) {
      coordinator.reconcileAppForegroundResumed();
    }
    await coordinator.onVideoBecomeCurrent(
          assetIdentifier: widget.assetIdentifier,
          displayGeneration: generation,
          displayGate: gate,
          permission: _playbackPermission(
            requireSurfaceReady: requireSurfaceReady,
          ),
          muted: ref.read(sharedMuteProvider),
          browseCoverOpen: ref.read(browseCoveringRouteOpenProvider),
        );
  }

  bool _bindingLifecycleIsResumed() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Cap 18.4: lifecycle foreground resume sync (epoch via [didUpdateWidget]).
  void _maybeSyncForegroundResumePlayback(int oldEpoch) {
    if (oldEpoch == widget.foregroundResumeSyncEpoch) {
      return;
    }
    if (!widget.isCurrent) {
      return;
    }
    final media = _media;
    if (media == null || media.kind != FeedPageMediaKind.video) {
      return;
    }
    if (_layer2InFlight || !_surfaceReady || _layer2Failed) {
      return;
    }
    final gate = widget.currentDisplayGate;
    final generation = widget.assignedDisplayGeneration;
    if (gate == null || generation == null) {
      return;
    }
    unawaited(
      ref.read(playbackCoordinatorProvider).onForegroundResumeSync(
            assetIdentifier: widget.assetIdentifier,
            displayGeneration: generation,
            displayGate: gate,
            permission: _playbackPermission(assumeForegroundLifecycle: true),
            muted: ref.read(sharedMuteProvider),
          ),
    );
  }

  /// Cap 18.4 media-area tap — not a navigation activation.
  Future<void> _onMediaAreaTapToggle() async {
    final media = _media;
    if (media == null || media.kind != FeedPageMediaKind.video) {
      return;
    }
    if (!widget.isCurrent ||
        _layer2InFlight ||
        !_surfaceReady ||
        _layer2Failed) {
      return;
    }
    final gate = widget.currentDisplayGate;
    final generation = widget.assignedDisplayGeneration;
    if (gate == null || generation == null) {
      return;
    }
    if (ref
        .read(pvTransitionGuardProvider)
        .isCovering(widget.assetIdentifier)) {
      return;
    }
    await ref.read(playbackCoordinatorProvider).onUserTapTogglePlay(
          assetIdentifier: widget.assetIdentifier,
          displayGeneration: generation,
          displayGate: gate,
          permission: _playbackPermission(),
          muted: ref.read(sharedMuteProvider),
        );
  }

  Future<void> _onScrubComplete(double positionSeconds) async {
    final media = _media;
    if (media == null || media.kind != FeedPageMediaKind.video) {
      return;
    }
    if (!widget.isCurrent ||
        _layer2InFlight ||
        !_surfaceReady ||
        _layer2Failed) {
      return;
    }
    final gate = widget.currentDisplayGate;
    final generation = widget.assignedDisplayGeneration;
    if (gate == null || generation == null) {
      return;
    }
    await ref.read(playbackCoordinatorProvider).onUserScrubComplete(
          assetIdentifier: widget.assetIdentifier,
          displayGeneration: generation,
          displayGate: gate,
          positionSeconds: positionSeconds,
          permission: _playbackPermission(),
          muted: ref.read(sharedMuteProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    _syncPvHandoffSnapshot();
    _listenSharedMuteForLive();
    ref.listen<PvTransitionGuardState>(pvTransitionGuardProvider, (prev, next) {
      if (!mounted) {
        return;
      }
      final wasCovering = prev?.isCovering(widget.assetIdentifier) ?? false;
      final nowCovering = next.isCovering(widget.assetIdentifier);
      if (!wasCovering && nowCovering && widget.isCurrent) {
        if (_surfaceReady) {
          setState(() => _surfaceReady = false);
        }
      }
    });
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    // Cap 21.6: keep shell Cap19 gate aligned if fail chrome flipped without
    // an explicit publish (post-frame — never write providers during build).
    if (widget.isCurrent) {
      final wantUnavailable = _isAssetUnavailableFailure;
      final haveUnavailable =
          ref.read(mainBrowseCurrentAssetHostUnavailableProvider);
      if (wantUnavailable != haveUnavailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !widget.isCurrent) {
            return;
          }
          _publishHostUnavailableGate();
        });
      }
      // Cap 26.4c / ADR-054: keep shell cover-visible aligned with page paint.
      final wantCover = _computeMediaCoverVisible();
      final haveCover =
          ref.read(mainBrowseCurrentAssetMediaCoverVisibleProvider);
      if (wantCover != haveCover) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !widget.isCurrent) {
            return;
          }
          ref
              .read(mainBrowseCurrentAssetMediaCoverVisibleProvider.notifier)
              .setVisible(_computeMediaCoverVisible());
        });
      }
    }

    if (_loading) {
      // Layer 1 miss chrome (ADR-031 Q2): immediate corner spinner.
      // Cap 17.3 B: a4 eviction remount is not a true first-visit L1 miss —
      // no miss gold. E: peek (!isCurrent) — never miss gold (retained, not
      // Decision-2-promoted). After-band Layer3 owns in-flight chrome once
      // media exists.
      // ADR-039: source-switch remounts delay visible center copy only.
      // Corner spinner + VoiceOver semantics remain immediate.
      final a4Loading = _layer2WaitPath == WaitChromePathClass.a4L2ReadyEvict;
      final showLoadingSpinner = widget.isCurrent && !a4Loading;
      final showLayer1CenterLabel = shouldShowLayer1CenterLabel(
        showLoadingSpinner: showLoadingSpinner,
        sourceSwitchDelayArmed: _layer1CenterLabelDelayArmedAt != null,
        elapsedSinceArm: _initialLayer1CenterLabelDelayElapsed,
      );
      return ColoredBox(
        key: const Key('mainBrowseFeedPageLoading'),
        color: tokens.feedBackground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _FeedCornerChrome(
              color: tokens.brandGold,
              showSpinner: showLoadingSpinner,
              rowKey: const Key('mainBrowseFeedPageLoadingChrome'),
              spinnerKey: const Key('mainBrowseFeedPageLoadingSpinner'),
              semanticsLabel: showLoadingSpinner
                  ? l10n.mainBrowseFeedLayer1Loading
                  : null,
            ),
            _coverlessCenterStatus(
              showWaitLabel: showLayer1CenterLabel,
              waitLabel: l10n.mainBrowseFeedLayer1Loading,
              showFailed: false,
              l10n: l10n,
              tokens: tokens,
            ),
            if (_showMediaInfoOverlayEffective)
              MediaInfoOverlay(snapshot: widget.overlaySnapshot),
          ],
        ),
      );
    }

    final media = _media;
    if (media == null) {
      // Current without media — show miss chrome (never empty SizedBox under
      // current). Peek neighbours may stay empty expand.
      if (widget.isCurrent) {
        final l10nLoading = AppLocalizations.of(context)!;
        final tokensLoading = Theme.of(context).extension<WakeTokTokens>()!;
        return ColoredBox(
          key: const Key('mainBrowseFeedPageLoading'),
          color: tokensLoading.feedBackground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _FeedCornerChrome(
                color: tokensLoading.brandGold,
                showSpinner: true,
                rowKey: const Key('mainBrowseFeedPageLoadingChrome'),
                spinnerKey: const Key('mainBrowseFeedPageLoadingSpinner'),
                semanticsLabel: l10nLoading.mainBrowseFeedLayer1Loading,
              ),
            ],
          ),
        );
      }
      return const SizedBox.expand();
    }

    final pvGuard = ref.watch(pvTransitionGuardProvider);
    final deferVideoForHandoff =
        widget.isCurrent && pvGuard.isCovering(widget.assetIdentifier);

    // One wait-chrome evaluation per build. ADR-039 removed the separate
    // coverless center Layer2Waiting copy; corner feedback remains.
    // Decode-broken: hide Meta + corner spinner + LIVE. Unresolved: hide Meta
    // only (Cap 26.4b) — spinner/LIVE stay so Limited iCloud Live does not
    // flash LIVE-alone on black.
    //
    // Cap 26.4b A2a: when cover is unresolved but Host work is outstanding
    // (_layer2InFlight or _livePreparing), force corner spinner even if wait
    // chrome / Live F1 policy would suppress — so miss→media handoff does not
    // flash LIVE-alone. Unresolved with neither flag: no force (honesty).
    final coverUnresolved = media.display != null &&
        !_stillCoverReady &&
        !_stillCoverDecodeBroken;
    final hostWorkOutstanding = _layer2InFlight || _livePreparing;
    final forceUnresolvedHostWaitSpinner = widget.isCurrent &&
        coverUnresolved &&
        hostWorkOutstanding &&
        !_suppressStillCoverWaitChrome;
    final showLayer2WaitSpinner =
        !_suppressStillCoverWaitChrome && _evaluateShowLayer2WaitChrome();
    if (showLayer2WaitSpinner || forceUnresolvedHostWaitSpinner) {
      // ADR-037: latch real paint, not wall-clock ≥ T alone.
      _layer2WaitChromeLatched = true;
    }
    final showLayer2FailedSlot =
        widget.isCurrent && _layer2Failed && !_layer2InFlight;
    // LIVE: decode-broken hides; any active magnification (settled / pinch /
    // contact) hides. Motion *play* keeps LIVE visible (iOS Photos parity).
    // Preparing keeps LIVE beside the gold spinner (Cap 14.6b) when not
    // magnified.
    final mag = ref.watch(browseMagnificationProvider);
    final liveBadgeVisible =
        !_suppressStillCoverWaitChrome &&
        !mag.hasActiveMagnification &&
        (debugForceLiveBadgeVisible ||
            (media.kind == FeedPageMediaKind.still &&
                media.display?.mediaKind == PlaybackMediaKind.livePhoto));
    final showLoadSpinnerEffective = widget.isCurrent &&
        !_suppressStillCoverWaitChrome &&
        (showLayer2WaitSpinner ||
            _showLiveLoadSpinner ||
            forceUnresolvedHostWaitSpinner);
    final showCornerReassure = shouldShowLayer2CornerReassure(
      isCurrent: widget.isCurrent,
      layer2InFlight: _layer2InFlight,
      layer2Failed: _layer2Failed,
      loadingMissPage: false,
      path: _layer2WaitPath,
      elapsedInFlight: _inFlightElapsed,
      waitSpinnerVisible: showLayer2WaitSpinner,
    );
    final cornerReassureLabel =
        _suppressStillCoverMeta || !showCornerReassure
            ? null
            : l10n.mainBrowseFeedLayer2Reassure;
    final coverlessLiveBadgeLabel = liveBadgeVisible
        ? l10n.mainBrowseLiveBadge
        : null;
    final limitedCreateHelperBand =
        ref.watch(photosAuthorizationProvider).asData?.value ==
            PhotosAccess.limited;
    final liveBadgeTop = mainBrowseLiveBadgeTopInset(
      mediaQueryPaddingTop: MediaQuery.paddingOf(context).top,
      limitedCreateHelperBand: limitedCreateHelperBand,
    );

    // Cap 15.14 / 4A: still + video poster share one asset-stable key so
    // STILL→VIDEO promote can reuse the Image Element (path must not be in key).
    final coverKey = ValueKey<String>('feedCover_${widget.assetIdentifier}');
    return switch (media.kind) {
      FeedPageMediaKind.still => _mediaStack(
        still: _StillPage(
          key: coverKey,
          // Cap 20: L1 = transient; photo / Live-static L2 = persistent.
          // Cap 20 content-rect: letterbox outside Transform.
          mediaChild: StillFittedMagnificationShell(
            active: widget.isCurrent,
            backgroundColor: tokens.feedBackground,
            pixelWidth: media.display!.pixelWidth,
            pixelHeight: media.display!.pixelHeight,
            child: () {
              final binderActive =
                  widget.isCurrent && !_liveMotionMounted;
              final image = _ReloadableFileImage(
                path: media.display!.localFilePath,
                color: tokens.feedBackground,
                fit: BoxFit.fill,
                onFileBroken: _onPreviewFileBroken,
                onFileReady: _onStillCoverFrameReady,
              );
              // Always the same binder runtimeType — only [persistent] flips
              // on L1↔L2 (Cap 20 black-flash / debt 450).
              return MagnificationHostModeBinder(
                active: binderActive,
                persistent: usesPersistentMagnification(media),
                child: StillMagnificationTransform(
                  apply: binderActive,
                  child: image,
                ),
              );
            }(),
          ),
          assetIdentifier: media.display!.assetIdentifier,
          isLivePhoto:
              media.display!.mediaKind == PlaybackMediaKind.livePhoto,
          liveLabel: l10n.mainBrowseLiveBadge,
          liveLoadLabel: l10n.mainBrowseFeedLiveLoading,
          layer3LoadLabel: l10n.mainBrowseFeedLayer3Loading,
          showLoadSpinner: showLoadSpinnerEffective,
          showLiveBadge: liveBadgeVisible,
          liveBadgeTop: liveBadgeTop,
          reassureLabel: cornerReassureLabel,
          liveMotionOverlay: _liveMotionMounted
              ? _LiveMotionSurface(
                  assetIdentifier: widget.assetIdentifier,
                  onSurfaceReady: () async {
                    if (!mounted) {
                      return;
                    }
                    final generation = _liveMotionGate.generation;
                    setState(() => _liveSurfaceReady = true);
                    final live = _liveRepo;
                    if (live != null) {
                      await live.notifyLiveSurfaceReady(widget.assetIdentifier);
                    }
                    await _playLiveMotionOnce(generation);
                  },
                )
              : null,
        ),
        l10n: l10n,
        tokens: tokens,
        showLayer2WaitSpinner: showLayer2WaitSpinner,
        showLayer2FailedSlot: showLayer2FailedSlot,
        cornerReassureLabel: cornerReassureLabel,
        coverlessLiveBadgeLabel: coverlessLiveBadgeLabel,
        liveBadgeTop: liveBadgeTop,
        playbackTapIsCurrent: widget.isCurrent,
        showMediaInfoOverlay: _showMediaInfoOverlayEffective,
        overlaySnapshot: widget.overlaySnapshot,
      ),
      FeedPageMediaKind.pendingVideo => () {
        return ColoredBox(
          key: Key('mainBrowseFeedVideoPending_${widget.assetIdentifier}'),
          color: tokens.feedBackground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (coverlessLiveBadgeLabel != null)
                _LiveBadgeTopLeading(
                  top: liveBadgeTop,
                  label: coverlessLiveBadgeLabel!,
                ),
              if (showLayer2WaitSpinner)
                _FeedCornerChrome(
                  color: tokens.brandGold,
                  showSpinner: true,
                  reassureLabel: cornerReassureLabel,
                  rowKey: const Key('mainBrowseFeedLayer2CoverlessChrome'),
                  spinnerKey: const Key('mainBrowseFeedLayer3Spinner'),
                  semanticsLabel: l10n.mainBrowseFeedLayer3Loading,
                ),
              _coverlessCenterStatus(
                showWaitLabel: false,
                showFailed: showLayer2FailedSlot,
                l10n: l10n,
                tokens: tokens,
                onFailedRetry: _feedFailureShowsRetry(
                      _layer2FailureReason ?? FeedFailureReason.generic,
                    )
                    ? () {
                        unawaited(
                          _retryFromFailState(pageFailedMedia: false),
                        );
                      }
                    : null,
              ),
            ],
          ),
        );
      }(),
      FeedPageMediaKind.video => () {
        // Cap 15.11b A→B: arm hold on null→non-null only (not on L2-complete).
        final canMountVideo =
            widget.isCurrent && !deferVideoForHandoff && !_layer2InFlight;
        final Widget? videoChild;
        if (canMountVideo) {
          if (!_videoSlotMounted) {
            _armPosterHoldOnVideoSlotMount();
          }
          _videoSlotMounted = true;
        } else {
          if (_videoSlotMounted) {
            _clearPosterHold(reason: 'video-slot-unmounted');
            _videoSlotMounted = false;
          }
        }
        // After poster-hold arming: L2 owns pinch only when the player is
        // visually showing. Until then poster owns Q5-B non-persistent pinch.
        final l2VisualOwnsPinch =
            canMountVideo && !_holdPosterUntilFirstFrame;
        if (canMountVideo) {
          // Cap 20.4: video L2 is never persistent (policy helper).
          assert(!usesPersistentMagnification(media));
          // Cap 20.4 Q5-B / Q3: L2 arms transient host when visually ready;
          // scale via setDisplayMagnification — Flutter Transform apply false.
          videoChild = MagnificationContentSizeReporter(
            active: widget.isCurrent && l2VisualOwnsPinch,
            pixelWidth: media.display?.pixelWidth,
            pixelHeight: media.display?.pixelHeight,
            child: NativeDisplayMagnificationPushBinder(
              active: widget.isCurrent && l2VisualOwnsPinch,
              child: MagnificationHostModeBinder(
                active: widget.isCurrent && l2VisualOwnsPinch,
                persistent: false,
                child: VideoMagnificationTransform(
                  apply: false,
                  child: _VideoPage(
                    assetIdentifier: media.videoAssetId!,
                    guardCovering: ref
                        .read(pvTransitionGuardProvider)
                        .isCovering(widget.assetIdentifier),
                    hasPoster: media.display != null,
                    onSurfaceReady: () async {
                      if (!mounted) {
                        return;
                      }
                      if (_debugSuppressSurfaceReadyCallbacks) {
                        return;
                      }
                      setState(() {
                        _surfaceReady = true;
                      });
                      _syncMediaCoverVisibleGate();
                      if (widget.isCurrent) {
                        widget.onCurrentLayer2MediaReady?.call(
                          widget.assetIdentifier,
                        );
                        _publishLayer2DisplayReady(true);
                      }
                      await ref
                          .read(playbackRepositoryProvider)
                          .notifyDisplaySurfaceReady(media.videoAssetId!);
                      await _syncPlaybackActive();
                    },
                  ),
                ),
              ),
            ),
          );
        } else {
          videoChild = null;
        }
        final covering = ref
            .watch(pvTransitionGuardProvider)
            .isCovering(widget.assetIdentifier);
        final coordinator = canMountVideo && videoChild != null
            ? ref.watch(playbackCoordinatorProvider)
            : null;
        // Poster-only L1, or poster-hold while UiKitView is opacity-0.
        final posterOwnsPinch =
            widget.isCurrent &&
            media.display != null &&
            !l2VisualOwnsPinch;
        assert(
          media.display == null || !usesPersistentMagnification(media),
          'video page media must not use persistent magnification policy',
        );
        return _mediaStack(
          still: null,
          video: videoChild,
          poster: media.display != null
              ? _StillPage(
                  key: coverKey,
                  // Keep the same Binder→Transform→Image ancestry as the
                  // still path so Cap 15.14 STILL→VIDEO promote can reuse
                  // _ReloadableFileImage State (coverKey alone is not enough
                  // once Transform wraps the still mediaChild).
                  mediaChild: StillFittedMagnificationShell(
                    active: posterOwnsPinch,
                    backgroundColor: tokens.feedBackground,
                    pixelWidth: media.display!.pixelWidth,
                    pixelHeight: media.display!.pixelHeight,
                    child: MagnificationHostModeBinder(
                      active: posterOwnsPinch,
                      persistent: false,
                      child: StillMagnificationTransform(
                        apply: posterOwnsPinch,
                        child: _ReloadableFileImage(
                          path: media.display!.localFilePath,
                          color: tokens.feedBackground,
                          fit: BoxFit.fill,
                          onFileBroken: _onPreviewFileBroken,
                          onFileReady: _onStillCoverFrameReady,
                        ),
                      ),
                    ),
                  ),
                  assetIdentifier: media.display!.assetIdentifier,
                  isLivePhoto:
                      media.display!.mediaKind == PlaybackMediaKind.livePhoto,
                  liveLabel: l10n.mainBrowseLiveBadge,
                  layer3LoadLabel: l10n.mainBrowseFeedLayer3Loading,
                  showLoadSpinner:
                      showLayer2WaitSpinner && !deferVideoForHandoff,
                  showLiveBadge: liveBadgeVisible,
                  liveBadgeTop: liveBadgeTop,
                  reassureLabel: cornerReassureLabel,
                )
              : null,
          deferVideoForHandoff: deferVideoForHandoff,
          l10n: l10n,
          tokens: tokens,
          showLayer2WaitSpinner: showLayer2WaitSpinner,
          showLayer2FailedSlot: showLayer2FailedSlot,
          cornerReassureLabel: cornerReassureLabel,
          coverlessLiveBadgeLabel: coverlessLiveBadgeLabel,
          liveBadgeTop: liveBadgeTop,
          onPlaybackTapToggle: coordinator == null
              ? null
              : () {
                  unawaited(_onMediaAreaTapToggle());
                },
          playbackCoordinator: coordinator,
          playbackTapIsCurrent: widget.isCurrent,
          playbackTapSurfaceReady: _surfaceReady,
          playbackTapTransitionCovering: covering,
          playbackTapHardFailure: _layer2Failed,
          scrubberVerticalFeedSettled: widget.verticalFeedSettled,
          scrubberLayer2InFlight: _layer2InFlight,
          onScrubComplete: coordinator == null
              ? null
              : (seconds) {
                  unawaited(_onScrubComplete(seconds));
                },
          playbackRepository:
              coordinator == null ? null : (_playbackRepo ?? ref.read(playbackRepositoryProvider)),
          showMediaInfoOverlay: _showMediaInfoOverlayEffective,
          overlaySnapshot: widget.overlaySnapshot,
        );
      }(),
      FeedPageMediaKind.failed =>
        widget.isCurrent
            ? Stack(
                fit: StackFit.expand,
                children: [
                  _UsableRegionCenter(
                    child: () {
                      final reason =
                          media.failureReason ?? FeedFailureReason.generic;
                      final showRetry = _feedFailureShowsRetry(reason);
                      return _BrowseStatusPanel(
                        panelKey: const Key('mainBrowseFeedPageFailed'),
                        message: _failureCopy(l10n, reason),
                        actionLabel: showRetry
                            ? l10n.mainBrowseFeedRetry
                            : null,
                        actionKey: showRetry
                            ? const Key('mainBrowseFeedPageRetry')
                            : null,
                        onAction: showRetry
                            ? () {
                                unawaited(
                                  _retryFromFailState(pageFailedMedia: true),
                                );
                              }
                            : null,
                      );
                    }(),
                  ),
                  if (_showMediaInfoOverlayEffective)
                    MediaInfoOverlay(snapshot: widget.overlaySnapshot),
                ],
              )
            : const SizedBox.expand(),
    };
  }

  Widget _mediaStack({
    required AppLocalizations l10n,
    required WakeTokTokens tokens,
    required bool showLayer2WaitSpinner,
    required bool showLayer2FailedSlot,
    String? cornerReassureLabel,
    String? coverlessLiveBadgeLabel,
    double liveBadgeTop = 0,
    Widget? still,
    Widget? video,
    Widget? poster,
    bool deferVideoForHandoff = false,
    VoidCallback? onPlaybackTapToggle,
    PlaybackCoordinator? playbackCoordinator,
    bool playbackTapIsCurrent = false,
    bool playbackTapSurfaceReady = false,
    bool playbackTapTransitionCovering = false,
    bool playbackTapHardFailure = false,
    bool scrubberVerticalFeedSettled = true,
    bool scrubberLayer2InFlight = true,
    void Function(double positionSeconds)? onScrubComplete,
    PlaybackRepository? playbackRepository,
    bool showMediaInfoOverlay = false,
    PresentationOverlaySnapshot? overlaySnapshot,
  }) {
    final guard = ref.watch(pvTransitionGuardProvider);
    final coverPath = guard.isCovering(widget.assetIdentifier)
        ? guard.coverPosterPath
        : null;
    // Cap 15.11: residual cover only when UiKitView is in the Stack.
    final showGuardCover = coverPath != null && video != null;
    // Cap 15.11b probe: hide whole video slot (incl. ColoredBox) via Opacity;
    // Stack order stays Cap 15.7 — never reorder poster/video.
    final hideVideoUntilReady = _holdPosterUntilFirstFrame && video != null;
    if (hideVideoUntilReady) {}
    if (deferVideoForHandoff) {}
    if (showGuardCover) {
    } else if (coverPath != null) {}
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cap 15.7: poster at index 0 so leaving (video child dropped)
        // does not shift the Image Element. Cap 15.11b: never swap slots;
        // Opacity always wraps [video] so hold clear only changes opacity.
        if (poster != null) poster,
        if (still != null) still,
        if (video != null)
          Opacity(
            key: Key('feedVideoOpacity_${widget.assetIdentifier}'),
            opacity: hideVideoUntilReady ? 0.0 : 1.0,
            child: video,
          ),
        if (showGuardCover)
          _PvTransitionCover(
            key: Key('pvTransitionCover_${widget.assetIdentifier}'),
            path: coverPath,
            backgroundColor: tokens.feedBackground,
          ),
        // Cap 18.4: tap / affordance below chrome so retry + corner stay
        // hittable. ListenableBuilder is overlay-only so poster Image State
        // is not rebuilt on intent changes (W-15.7b).
        if (onPlaybackTapToggle != null && playbackCoordinator != null)
          ListenableBuilder(
            listenable: playbackCoordinator,
            builder: (context, _) {
              final showAffordance = showCenterPlaybackAffordance(
                isCurrent: playbackTapIsCurrent,
                isL2ReadyOrdinaryVideo: true,
                isSurfaceReady: playbackTapSurfaceReady,
                transitionCovering: playbackTapTransitionCovering,
                hardFailure: playbackTapHardFailure,
                isForegroundLifecycle:
                    playbackCoordinator.isForegroundLifecycle,
                userIntentWantsPlay: playbackCoordinator.userIntentWantsPlay,
              );
              return MediaPlaybackTapOverlay(
                onTapToggle: onPlaybackTapToggle,
                wantsPlay: playbackCoordinator.userIntentWantsPlay,
                l10n: l10n,
                showAffordance: showAffordance,
              );
            },
          ),
        if (showMediaInfoOverlay)
          MediaInfoOverlay(snapshot: overlaySnapshot),
        Cap19LeftSwipeAlbumReveal(isCurrent: playbackTapIsCurrent),
        if (onScrubComplete != null &&
            playbackRepository != null &&
            video != null &&
            scrubberChromeVisible(
              isCurrent: playbackTapIsCurrent,
              verticalFeedSettled: scrubberVerticalFeedSettled,
              transitionCovering: playbackTapTransitionCovering,
            ))
          VideoProgressScrubber(
            assetIdentifier: widget.assetIdentifier,
            frozen: scrubberFrozen(
              isCurrent: playbackTapIsCurrent,
              isOrdinaryVideo: true,
              layer2InFlight: scrubberLayer2InFlight,
              surfaceReady: playbackTapSurfaceReady,
              hardFailure: playbackTapHardFailure,
              transitionCovering: playbackTapTransitionCovering,
            ),
            runtimeEvents: playbackRepository.runtimeEvents,
            onScrubComplete: onScrubComplete,
            requestPreview: playbackRepository.requestScrubPreviewFrame,
          ),
        if (coverlessLiveBadgeLabel != null &&
            still == null &&
            poster == null)
          _LiveBadgeTopLeading(
            top: liveBadgeTop,
            label: coverlessLiveBadgeLabel!,
          ),
        if (showLayer2WaitSpinner && still == null && poster == null)
          _FeedCornerChrome(
            color: tokens.brandGold,
            showSpinner: true,
            reassureLabel: cornerReassureLabel,
            rowKey: const Key('mainBrowseFeedLayer2CoverlessChrome'),
            spinnerKey: const Key('mainBrowseFeedLayer3Spinner'),
            semanticsLabel: l10n.mainBrowseFeedLayer3Loading,
          ),
        _coverlessCenterStatus(
          showWaitLabel: false,
          showFailed: showLayer2FailedSlot,
          l10n: l10n,
          tokens: tokens,
          onFailedRetry: _feedFailureShowsRetry(
                _layer2FailureReason ?? FeedFailureReason.generic,
              )
              ? () {
                  unawaited(_retryFromFailState(pageFailedMedia: false));
                }
              : null,
        ),
        Cap19LeftSwipeGesture(
          isCurrent: playbackTapIsCurrent,
          excludeScrubberBand:
              onScrubComplete != null && video != null,
        ),
        Cap26LiveLongPressGesture(
          enabled: shouldMountLiveLongPressListener(
            mayFire: shouldArmLiveLongPress(
              isCurrent: playbackTapIsCurrent,
              isLiveStill: _isLiveStillMedia(_media),
              liveMotionMounted: _liveMotionMounted,
              livePreparing: _livePreparing,
              liveSilentReplayInFlight: _liveSilentReplayInFlight,
              isCurrentStillMagnified:
                  ref.watch(browseMagnificationProvider).isStillMagnified,
              transientPinchActive:
                  ref.watch(browseMagnificationProvider).transientPinchActive,
              stillPinchContact:
                  ref.watch(browseMagnificationProvider).stillPinchContact,
              cap19PanelOpen: ref.watch(cap19ActionsPanelOpenProvider),
              cap24MorePanelOpen: ref.watch(cap24MorePanelOpenProvider),
            ),
            holdingAfterFire: _userHoldReplayActive,
            isCurrent: playbackTapIsCurrent,
            cap19PanelOpen: ref.watch(cap19ActionsPanelOpenProvider),
            cap24MorePanelOpen: ref.watch(cap24MorePanelOpenProvider),
          ),
          onLongPressFire: () {
            _userHoldReplayActive = true;
            unawaited(_userLongPressReplay());
          },
          onLongPressRelease: () {
            unawaited(_userLongPressReleaseStop());
          },
        ),
        // Cap 20.3 D2-A: last layer (defensive); arming already shrinks swipe.
        MagnificationResetButton(overlaySnapshot: overlaySnapshot),
      ],
    );
  }

  String _failureCopy(AppLocalizations l10n, FeedFailureReason reason) {
    return switch (reason) {
      FeedFailureReason.network => l10n.mainBrowseFeedNetworkFailed,
      FeedFailureReason.download => l10n.mainBrowseFeedDownloadFailed,
      FeedFailureReason.generic => l10n.mainBrowseFeedMediaFailed,
      FeedFailureReason.assetUnavailable => l10n.mainBrowseFeedUnavailable,
    };
  }

  /// Cap 21.6 / ADR-044 D3: hide Retry when Host reports missing asset —
  /// Retry cannot recover a deleted / empty-id / unavailable PHAsset.
  bool _feedFailureShowsRetry(FeedFailureReason reason) {
    return reason != FeedFailureReason.assetUnavailable;
  }

  /// Center status shared by Layer-1 visible loading copy and coverless fail.
  Widget _coverlessCenterStatus({
    required bool showWaitLabel,
    String? waitLabel,
    required bool showFailed,
    required AppLocalizations l10n,
    required WakeTokTokens tokens,
    VoidCallback? onFailedRetry,
  }) {
    if (showFailed) {
      return _UsableRegionCenter(
        child: Column(
          key: const Key('mainBrowseFeedCoverlessFailedSlot'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _failureCopy(
                l10n,
                _layer2FailureReason ?? FeedFailureReason.generic,
              ),
              textAlign: TextAlign.center,
              style: tokens.bodyOnMedia,
            ),
            if (onFailedRetry != null) ...[
              const SizedBox(height: 16),
              _BrowseRetryButton(
                buttonKey: const Key('mainBrowseFeedLayer2Retry'),
                label: l10n.mainBrowseFeedRetry,
                onPressed: onFailedRetry,
              ),
            ],
          ],
        ),
      );
    }
    if (showWaitLabel) {
      assert(waitLabel != null);
      return _UsableRegionCenter(
        child: ExcludeSemantics(
          child: Text(
            waitLabel!,
            key: const Key('mainBrowseFeedCoverlessWaitLabel'),
            textAlign: TextAlign.center,
            style: tokens.labelOnMedia.copyWith(
              color: tokens.onMedia,
              shadows: tokens.onMediaLabelShadows,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Cap 17.4: geometric center of the feed usable region (below source tabs
/// / status, above Overlay rows 1–3). Dest bar is a Column sibling of the
/// browse pane — not overlaid on [MediaFeedPage], so it is not reserved here.
class _UsableRegionCenter extends StatelessWidget {
  const _UsableRegionCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final padding = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.only(
        top: padding.top + kCoverlessCenterTopChromeBody,
        bottom: mainBrowseCoverlessCenterOverlayReserve(tokens),
      ),
      child: Center(child: child),
    );
  }
}

class _StillPage extends StatelessWidget {
  const _StillPage({
    super.key,
    required this.mediaChild,
    required this.assetIdentifier,
    required this.isLivePhoto,
    required this.liveLabel,
    this.liveLoadLabel,
    this.layer3LoadLabel,
    this.showLoadSpinner = false,
    this.showLiveBadge = true,
    this.liveBadgeTop = 0,
    this.reassureLabel,
    this.liveMotionOverlay,
  });

  /// Cover / still visual (may already be wrapped in magnification [Transform]).
  final Widget mediaChild;

  final String assetIdentifier;
  final bool isLivePhoto;
  final String liveLabel;

  /// VoiceOver while Live Layer 2 / motion prepare spinner is shown.
  final String? liveLoadLabel;

  /// VoiceOver while non-Live Layer 2 spinner is shown.
  final String? layer3LoadLabel;

  /// Cap 14.6b: corner spinner for Layer 2 in-flight (any item) or Live prepare.
  final bool showLoadSpinner;

  /// Cap 26.4b: false when decode-broken wait-chrome gate hides LIVE.
  final bool showLiveBadge;

  /// Cap 26.4b: screen-top inset for top-leading LIVE (band bottom + gap).
  final double liveBadgeTop;

  /// Cap 17.5b: short copy left of spinner when Package B fires (rare on still).
  final String? reassureLabel;

  /// Cap 9.4 F1=A: motion-phase Live PV only (null when idle / after Q7 unload).
  final Widget? liveMotionOverlay;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final paintLiveBadge = isLivePhoto && showLiveBadge;
    final showCornerWait =
        showLoadSpinner ||
        (reassureLabel != null && reassureLabel!.isNotEmpty);
    final loadLabel = isLivePhoto ? liveLoadLabel : layer3LoadLabel;
    return Stack(
      key: Key('mainBrowseFeedStill_$assetIdentifier'),
      fit: StackFit.expand,
      children: [
        mediaChild,
        // Cap 26.4b: Live PV under chrome so LIVE stays fully visible during
        // motion play (iOS Photos parity — badge does not peek under PV).
        if (liveMotionOverlay != null) liveMotionOverlay!,
        if (showCornerWait)
          _FeedCornerChrome(
            color: tokens.brandGold,
            showSpinner: showLoadSpinner,
            reassureLabel: reassureLabel,
            rowKey: isLivePhoto
                ? Key('mainBrowseFeedLiveSpinnerRow_$assetIdentifier')
                : const Key('mainBrowseFeedLayer3Chrome'),
            spinnerKey: isLivePhoto
                ? Key('mainBrowseFeedLivePreparing_$assetIdentifier')
                : const Key('mainBrowseFeedLayer3Spinner'),
            semanticsLabel: showLoadSpinner ? loadLabel : null,
          ),
        if (paintLiveBadge)
          _LiveBadgeTopLeading(
            top: liveBadgeTop,
            label: liveLabel,
            chromeKey: Key('mainBrowseFeedLiveChrome_$assetIdentifier'),
          ),
      ],
    );
  }
}

/// Bottom-trailing wait chrome (spinner ± “Still loading”).
///
/// Cap 26.4b: LIVE moved to top-leading — this widget no longer paints the
/// badge or lifts above a badge row.
class _FeedCornerChrome extends StatelessWidget {
  const _FeedCornerChrome({
    required this.color,
    this.showSpinner = false,
    this.reassureLabel,
    this.rowKey,
    this.spinnerKey,
    this.semanticsLabel,
  });

  final Color color;
  final bool showSpinner;

  /// Cap 17.5b: short copy immediately left of the spinner (incremental).
  final String? reassureLabel;
  final Key? rowKey;
  final Key? spinnerKey;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final showReassure = reassureLabel != null && reassureLabel!.isNotEmpty;
    if (!showSpinner && !showReassure) {
      return const SizedBox.shrink();
    }
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final statusBottom = mainBrowseLiveStatusBottomInset(tokens);
    return Positioned(
      right: kMediaChromeTrailingInset,
      bottom: statusBottom,
      child: IgnorePointer(
        child: Semantics(
          container: true,
          excludeSemantics: showSpinner,
          label: showSpinner ? semanticsLabel : null,
          child: Row(
            key: rowKey,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showReassure) ...[
                // Intrinsic width — do not fade-clip EN
                // "Still loading" / zh-Hans reassure under a tight
                // maxWidth (device smoke).
                Text(
                  reassureLabel!,
                  key: const Key('mainBrowseFeedLayer2Reassure'),
                  maxLines: 1,
                  softWrap: false,
                  style: tokens.labelOnMedia.copyWith(
                    color: tokens.onMedia,
                    shadows: tokens.onMediaLabelShadows,
                  ),
                ),
                if (showSpinner) const SizedBox(width: 8),
              ],
              if (showSpinner)
                _FeedCornerSpinner(
                  spinnerKey: spinnerKey,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cap 26.4b: LIVE capsule below Browse top chrome; **left** with Temp chip.
class _LiveBadgeTopLeading extends StatelessWidget {
  const _LiveBadgeTopLeading({
    required this.top,
    required this.label,
    this.chromeKey,
  });

  final double top;
  final String label;
  final Key? chromeKey;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: chromeKey,
      left: kLiveBadgeLeadingInset,
      top: top,
      child: IgnorePointer(
        child: _LiveBadge(label: label),
      ),
    );
  }
}

/// 16px brand-gold spinner used at the bottom-right of a feed page.
class _FeedCornerSpinner extends StatelessWidget {
  const _FeedCornerSpinner({this.spinnerKey, required this.color});

  final Key? spinnerKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: spinnerKey,
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

/// [Image.file] errorBuilder must not [setState] or start I/O inline.
/// Post-frame + per-path latch; parent reloads preview under generation.
class _ReloadableFileImage extends StatefulWidget {
  const _ReloadableFileImage({
    required this.path,
    required this.color,
    this.onFileBroken,
    this.onFileReady,
    this.fit = BoxFit.contain,
  });

  final String path;
  final Color color;
  final VoidCallback? onFileBroken;
  final VoidCallback? onFileReady;
  final BoxFit fit;

  @override
  State<_ReloadableFileImage> createState() => _ReloadableFileImageState();
}

class _ReloadableFileImageState extends State<_ReloadableFileImage> {
  bool _postedBroken = false;
  bool _postedReady = false;

  @override
  void didUpdateWidget(covariant _ReloadableFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _postedBroken = false;
      _postedReady = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cap 15.5: no path ValueKey (reuse Element/State across L1→L2 path
    // swap) + gaplessPlayback so Flutter keeps the prior frame until the
    // new FileImage decodes (default false clears _imageInfo on provider
    // change even when State is retained). Viewport-sized decode via
    // ResizeImage + fit policy (Image.file cacheWidth/Height defaults to
    // ResizeImagePolicy.exact and would stretch non-matching aspect ratios).
    return LayoutBuilder(
      builder: (context, constraints) {
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final boxW = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final boxH = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final cacheWidth = (boxW * dpr).round().clamp(1, 0x7FFFFFFF);
        final cacheHeight = (boxH * dpr).round().clamp(1, 0x7FFFFFFF);
        return Image(
          image: ResizeImage(
            FileImage(File(widget.path)),
            width: cacheWidth,
            height: cacheHeight,
            policy: ResizeImagePolicy.fit,
            allowUpscaling: false,
          ),
          gaplessPlayback: true,
          fit: widget.fit,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (!_postedReady &&
                (wasSynchronouslyLoaded || frame != null)) {
              _postedReady = true;
              final readyPath = widget.path;
              final onReady = widget.onFileReady;
              if (onReady != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted || widget.path != readyPath) {
                    return;
                  }
                  onReady();
                });
              }
            }
            return child;
          },
          errorBuilder: (context, error, stackTrace) {
            if (!_postedBroken) {
              _postedBroken = true;
              final brokenPath = widget.path;
              final onBroken = widget.onFileBroken;
              if (onBroken != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // Stale: path already swapped (e.g. Cap 21.6 reload heal)
                  // before this callback ran — do not re-arm broken on the
                  // new cover.
                  if (!mounted || widget.path != brokenPath) {
                    return;
                  }
                  onBroken();
                });
              }
            }
            return ColoredBox(
              key: const Key('mainBrowseFeedStillBrokenPlaceholder'),
              color: widget.color,
            );
          },
        );
      },
    );
  }
}

class _LiveMotionSurface extends StatefulWidget {
  const _LiveMotionSurface({
    required this.assetIdentifier,
    required this.onSurfaceReady,
  });

  final String assetIdentifier;
  final Future<void> Function() onSurfaceReady;

  @override
  State<_LiveMotionSurface> createState() => _LiveMotionSurfaceState();
}

class _LiveMotionSurfaceState extends State<_LiveMotionSurface> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.onSurfaceReady());
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return ColoredBox(
      key: Key('mainBrowseFeedLiveMotion_${widget.assetIdentifier}'),
      color: tokens.feedBackground.withValues(alpha: 0),
      child: defaultTargetPlatform == TargetPlatform.iOS
          ? IgnorePointer(
              child: UiKitView(
                viewType: MediaFeedPage.livePhotoViewType,
                creationParams: widget.assetIdentifier,
                creationParamsCodec: const StandardMessageCodec(),
                gestureRecognizers:
                    const <Factory<OneSequenceGestureRecognizer>>{},
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label});

  final String label;

  /// Match Browse top-chrome optical centering for the label line box.
  static const TextHeightBehavior _textHeightBehavior = TextHeightBehavior(
    applyHeightToFirstAscent: false,
    applyHeightToLastDescent: false,
  );

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final labelStyle = tokens.labelOnMedia.copyWith(
      inherit: false,
      height: 1.0,
      shadows: tokens.onMediaLabelShadows,
    );
    // Cap 26.4b: Flutter ShapeDecoration stadium (not Material; not Temp
    // 32-tall / r16 shell). Left aligns with Temp/Saved via [_LiveBadgeTopLeading].
    return DecoratedBox(
      key: const Key('mainBrowseLiveBadge'),
      decoration: ShapeDecoration(
        color: tokens.mediaScrim.withValues(alpha: kStatusChromeScrimOpacity),
        shape: StadiumBorder(
          side: BorderSide(
            color: tokens.onMedia.withValues(alpha: kStatusChromeBorderOpacity),
            width: kStatusChromeBorderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kLiveBadgeHorizontalPad,
          vertical: kLiveBadgeVerticalPad,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: kLiveBadgeDotSize,
              height: kLiveBadgeDotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: tokens.onMedia, width: 1.25),
              ),
            ),
            const SizedBox(width: kLiveBadgeDotLabelGap),
            Text(
              label,
              textHeightBehavior: _textHeightBehavior,
              style: labelStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.assetIdentifier,
    required this.guardCovering,
    required this.hasPoster,
    required this.onSurfaceReady,
  });

  final String assetIdentifier;
  final bool guardCovering;
  final bool hasPoster;
  final Future<void> Function() onSurfaceReady;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.onSurfaceReady());
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    // Empty gestureRecognizers (same as library_smoke probe): do NOT use
    // EagerGestureRecognizer — it steals vertical drags and freezes PageView.
    // IgnorePointer keeps platform-view touches from competing with Manual swipe.
    return ColoredBox(
      key: Key('mainBrowseFeedVideo_${widget.assetIdentifier}'),
      color: tokens.feedBackground,
      child: defaultTargetPlatform == TargetPlatform.iOS
          ? IgnorePointer(
              child: UiKitView(
                viewType: MediaFeedPage.playbackViewType,
                creationParams: widget.assetIdentifier,
                creationParamsCodec: const StandardMessageCodec(),
                gestureRecognizers:
                    const <Factory<OneSequenceGestureRecognizer>>{},
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

/// Cap 15.11: opaque handoff cover above poster / Platform View during peek+settle.
class _PvTransitionCover extends StatelessWidget {
  const _PvTransitionCover({
    super.key,
    required this.path,
    required this.backgroundColor,
  });

  final String path;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
      ),
    );
  }
}
