import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/live_photo/live_photo_repository.dart';
import 'package:waketok/domain/playback/media_display_repository.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/playback/playback_repository.dart';
import 'package:waketok/domain/presentation/presentation_metadata.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/live_photo_providers.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/library_smoke/shared_mute_provider.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';
import 'package:waketok/features/main_browse/feed_activation_coordinator.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// True when a vertical feed scroll is past the trailing edge (next-item
/// direction). Used for Endless last-page round advance.
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

class VerticalMediaFeedState extends ConsumerState<VerticalMediaFeed> {
  PageController? _pageController;
  StreamSubscription<PlaybackRestoreRequest>? _restoreSub;
  List<String> _ids = const [];
  bool _advancingRound = false;

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

  @visibleForTesting
  int get debugActivationBeginCount => _activation.debugBeginCount;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      // Second line of defense if Feed State is ever recreated. Primary
      // fix is the unconditional IndexedStack Theme wrap in the shell.
      initialPage: ref.read(mainBrowseFeedIndexProvider),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachRestore());
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
    _restoreSub?.cancel();
    _pageController?.dispose();
    super.dispose();
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
    setState(() {
      final base = (_overlaySnapshot?.assetIdentifier == assetId)
          ? _overlaySnapshot!
          : PresentationOverlaySnapshot(assetIdentifier: assetId);
      final next = base.mergeSize(size);
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

  void _tryAdvanceEndlessRound({
    required int feedIndex,
    required int queueLength,
  }) {
    if (_advancingRound || queueLength <= 1 || feedIndex != queueLength - 1) {
      return;
    }
    _advancingRound = true;
    unawaited(ref.read(playbackRepositoryProvider).pause());
    ref.read(browseSessionProvider.notifier).advanceToNextRound();
    ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _advancingRound = false;
      final controller = _pageController;
      if (controller != null && controller.hasClients) {
        controller.jumpToPage(0);
      }
    });
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
    final source = ref.watch(mainBrowseSelectedSourceProvider);
    final feedIndex = ref.watch(mainBrowseFeedIndexProvider);
    final destination = ref.watch(mainBrowseDestinationProvider);
    final browseActive = destination == MainBrowseDestination.browse;
    if (browseActive && !_browseWasActive) {
      _browseResumeLatch = true;
      _generationWhenLatchArmed =
          _activation.currentDisplayGate.generation;
    }
    _browseWasActive = browseActive;

    // Cap 9.6: video host has no persisted mute — push preference on change.
    ref.listen<bool>(sharedMuteProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      unawaited(ref.read(playbackRepositoryProvider).setMute(next));
    });

    ref.listen<SourceReference>(mainBrowseSelectedSourceProvider, (prev, next) {
      if (prev != next) {
        unawaited(ref.read(playbackRepositoryProvider).pause());
      }
    });

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
          final ids = view.orderedAssetIds;
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
          return Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (isEndlessRoundAdvanceScroll(notification)) {
                    _tryAdvanceEndlessRound(
                      feedIndex: feedIndex,
                      queueLength: ids.length,
                    );
                  }
                  return false;
                },
                child: PageView.builder(
                  key: ValueKey<String>(
                    'feed-${source.id}-r${view.roundEpoch}',
                  ),
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  // This SDK's PageView.builder has no cacheExtent; true sets
                  // Viewport cacheExtent to 1.0 viewport (±1 pages).
                  allowImplicitScrolling: true,
                  itemCount: ids.length,
                  onPageChanged: (i) {
                    ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(i);
                  },
                  itemBuilder: (context, index) {
                    final isCurrent = browseActive && index == feedIndex;
                    final isPreheatNeighbor =
                        browseActive &&
                        !isCurrent &&
                        _allowedPreheatIndices.contains(index);
                    return MediaFeedPage(
                      key: ValueKey<String>(
                        'page-${ids[index]}-$index-r${view.roundEpoch}',
                      ),
                      assetIdentifier: ids[index],
                      feedIndex: index,
                      sourceKind: source.kind,
                      isCurrent: isCurrent,
                      isPreheatNeighbor: isPreheatNeighbor,
                      liveHostSerial: liveHostSerial,
                      currentDisplayGate: isCurrent
                          ? _activation.currentDisplayGate
                          : null,
                      assignedDisplayGeneration: isCurrent
                          ? _activeDisplayGeneration
                          : null,
                      onCurrentLayer2MediaReady: isCurrent
                          ? _onCurrentLayer2MediaReady
                          : null,
                    );
                  },
                ),
              ),
              if (browseActive) MediaInfoOverlay(snapshot: _overlaySnapshot),
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
              TextButton(
                key: actionKey,
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
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
    required this.isCurrent,
    required this.isPreheatNeighbor,
    required this.liveHostSerial,
    this.currentDisplayGate,
    this.assignedDisplayGeneration,
    this.onCurrentLayer2MediaReady,
  });

  final String assetIdentifier;
  final int feedIndex;
  final AssetSourceKind sourceKind;
  final bool isCurrent;

  /// Cap 14.5: ±1 neighbour allowed to [requestPreview] after parent release.
  final bool isPreheatNeighbor;
  final LiveHostOpSerial liveHostSerial;

  /// When current: feed-owned gate already begun in [_activateCurrentItem].
  final FeedMediaRequestGate? currentDisplayGate;
  final int? assignedDisplayGeneration;

  /// Current page only. Parent reads metadata generation at callback time.
  final void Function(String assetId)? onCurrentLayer2MediaReady;

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
  bool _layer2Failed = false;
  FeedFailureReason? _layer2FailureReason;
  /// Cap 16.4: [Timer] from became-current. Cancel on leave / dispose.
  Timer? _layer2DwellTimer;
  Completer<void>? _layer2DwellCompleter;
  AppLifecycleState? _lastLifecycle;

  /// Test seam: hold [_teardownLiveMotion] when this page is off-current.
  @visibleForTesting
  Completer<void>? debugHoldOffCurrentTeardown;

  @visibleForTesting
  FeedPageMedia? get debugMedia => _media;

  bool _liveMotionMounted = false;
  bool _livePhotoReady = false;
  bool _liveSurfaceReady = false;
  bool _liveStartIssued = false;

  /// Cap 9.5 Q4=A: motion prepare spinner (generation-gated writes).
  /// Cap 14.6b also uses an ungated handoff write so the Live load spinner
  /// stays up across `_layer2InFlight` → serial-queue wait.
  bool _livePreparing = false;

  bool get _showLiveLoadSpinner =>
      _isLiveStillMedia(_media) && (_layer2InFlight || _livePreparing);

  /// Layer 2 in-flight (any item) or Live motion prepare — corner spinner.
  bool get _showItemLoadSpinner => _layer2InFlight || _showLiveLoadSpinner;

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
  MediaDisplayRepository? _displayRepo;

  @override
  void initState() {
    super.initState();
    _lastLifecycle = WidgetsBinding.instance.lifecycleState;
    WidgetsBinding.instance.addObserver(this);
    if (widget.isCurrent) {
      _armLayer2DwellTimer();
    }
    _startLoad();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previous = _lastLifecycle;
    _lastLifecycle = state;
    if (state != AppLifecycleState.resumed) {
      return;
    }
    // China-SKU wireless-data alert: typically inactive→resumed (app never
    // backgrounds). True background uses paused→resumed. Listen for both.
    if (previous != AppLifecycleState.inactive &&
        previous != AppLifecycleState.paused) {
      return;
    }
    _retryFailedLayer2AfterResume();
  }

  /// Auto-retry only when this current page is already in a fail state.
  void _retryFailedLayer2AfterResume() {
    if (!mounted || !widget.isCurrent || _layer2InFlight) {
      return;
    }
    if (_layer2Failed) {
      unawaited(_retryLayer2Only(bypassDwell: true));
      return;
    }
    if (_media?.kind == FeedPageMediaKind.failed) {
      unawaited(_startLoad(bypassDwell: true));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _liveRepo ??= ref.read(livePhotoRepositoryProvider);
    _playbackRepo ??= ref.read(playbackRepositoryProvider);
    _displayRepo ??= ref.read(mediaDisplayRepositoryProvider);
  }

  @override
  void didUpdateWidget(covariant MediaFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isCurrent && widget.isCurrent) {
      _armLayer2DwellTimer();
    }
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
    final leftCurrent = oldWidget.isCurrent && !widget.isCurrent;
    if (leftCurrent) {
      final playback = ref.read(playbackRepositoryProvider);
      _playbackRepo = playback;
      unawaited(playback.pause());
      unawaited(playback.cancelInFlightPrepare(widget.assetIdentifier));
      _cancelLayer2DwellTimer();
      _displayRepo ??= ref.read(mediaDisplayRepositoryProvider);
      // Shared currentDisplayGate is bumped by the parent
      // [_activateCurrentItem] when the new current page is assigned.
      // This branch does not bump that gate; G2 uses [widget.isCurrent].
      unawaited(_cancelCurrentItemPhotoKit(widget.assetIdentifier));
      // Cap 15.7: keep video+poster kind so [_StillPage] stays in the
      // same Stack slot. Do not flip to still (destroys Image State) or
      // pendingVideo when a poster already exists.
      if (_media?.kind == FeedPageMediaKind.video &&
          _media?.display == null) {
        setState(() {
          _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
          _surfaceReady = false;
          _layer2InFlight = false;
          _layer2Failed = false;
          _layer2FailureReason = null;
        });
      } else {
        setState(() {
          _surfaceReady = false;
          _layer2InFlight = false;
          _layer2Failed = false;
          _layer2FailureReason = null;
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
      if (_liveMotionMounted) {
        setState(() => _liveMotionMounted = false);
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
        if (_media?.kind == FeedPageMediaKind.pendingVideo ||
            _media?.kind == FeedPageMediaKind.video) {
          _startLoad();
        } else {
          unawaited(_syncPlaybackActive());
          if (_isLiveStillMedia(_media) && !_livePreparing) {
            setState(() => _livePreparing = true);
          }
          unawaited(_maybeBeginLiveMotion());
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelLayer2DwellTimer();
    _liveMotionGate.begin(); // invalidate Live activation
    _localGate.begin();
    unawaited(_cancelLiveSubscriptions());
    unawaited(_cancelCurrentItemPhotoKit(widget.assetIdentifier));
    final playback = _playbackRepo;
    if (widget.isCurrent && playback != null) {
      unawaited(playback.cancelInFlightPrepare(widget.assetIdentifier));
      unawaited(playback.pause());
    }
    final live = _liveRepo;
    if (widget.isCurrent && _isLiveStillMedia(_media) && live != null) {
      // Best-effort host teardown; dispose cannot await.
      final id = widget.assetIdentifier;
      unawaited(live.cancel(id));
      unawaited(live.stopPlayback());
    }
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
    setState(() => _livePreparing = next);
  }

  /// Ungated clear for the 14.6b Layer 2 → motion handoff when
  /// [_liveMotionGate.begin] has not run yet for this activation.
  void _abandonLivePreparingHandoff() {
    if (!mounted || !_livePreparing) {
      return;
    }
    setState(() => _livePreparing = false);
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

  /// Cap 9.4 Live play-once + Cap 9.5 Q4=A spinner-only while preparing.
  Future<void> _maybeBeginLiveMotion() async {
    if (!widget.isCurrent || !_isLiveStillMedia(_media)) {
      _abandonLivePreparingHandoff();
      return;
    }
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
        unawaited(_tryStartLivePlayback(generation));
      });
      _liveFailedSub = live.failedEvents.listen((event) {
        if (!_liveMotionGate.isCurrent(generation)) {
          return;
        }
        if (event.assetIdentifier != assetId) {
          return;
        }
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
      } catch (_) {
        // Sync failure → keep still; no skip (Cap 9.5 static fallback).
        _setLivePreparing(generation, false);
        if (mounted && _liveMotionGate.isCurrent(generation)) {
          setState(() => _liveMotionMounted = false);
        }
      }
    });
  }

  Future<void> _tryStartLivePlayback(int generation) async {
    if (!_liveMotionGate.isCurrent(generation) ||
        !_livePhotoReady ||
        !_liveSurfaceReady ||
        _liveStartIssued) {
      return;
    }
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
        await live.startPlayback();
      } catch (_) {
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
    final generation = _liveMotionGate.begin();
    if (_liveMotionMounted ||
        _livePhotoReady ||
        _liveSurfaceReady ||
        _liveStartIssued) {
      setState(() {
        _liveMotionMounted = false;
        _livePhotoReady = false;
        _liveSurfaceReady = false;
        _liveStartIssued = false;
      });
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
    if (!mounted || !widget.isCurrent) {
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
    unawaited(_reloadPreviewFile());
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
  /// Layer 1 took longer than N).
  void _armLayer2DwellTimer() {
    _cancelLayer2DwellTimer();
    final n = ref.read(browseLayer2DwellProvider);
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

  Future<void> _awaitLayer2Dwell({required bool bypassDwell}) async {
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
      _armLayer2DwellTimer();
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
      _layer2InFlight = true;
    });
    await _awaitLayer2Dwell(bypassDwell: bypassDwell);
    if (!mounted || !widget.isCurrent || !gate.isCurrent(generation)) {
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
  }) {
    final display = layer1?.display;
    if (display == null) {
      if (layer2Follows && !_layer2InFlight) {
        setState(() => _layer2InFlight = true);
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
      if (layer2Follows) {
        _layer2InFlight = true;
      }
    });
  }

  Future<void> _runLayer2AfterJoinedLayer1({
    required FeedMediaRequestGate currentGate,
    required int currentGeneration,
    required FeedPageMedia? layer1,
    required bool bypassDwell,
  }) async {
    if (layer1 != null) {
      _applyLayer1StillIdempotent(layer1, layer2Follows: true);
    } else {
      setState(() => _layer2InFlight = true);
    }
    await _awaitLayer2Dwell(bypassDwell: bypassDwell);
    if (!mounted ||
        !currentGate.isCurrent(currentGeneration) ||
        !widget.isCurrent) {
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

  Future<void> _startLoad({bool bypassDwell = false}) async {
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
        setState(() {
          _loading = true;
          _media = null;
          _surfaceReady = false;
          _liveMotionMounted = false;
        });
        _setLivePreparing(liveGeneration, false);
        return;
      }
      gate = shared;
      generation = assigned;
    }

    if (!startedOffCurrent) {
      final l2Ready = ref.read(browseL2ReadySessionProvider)[widget.assetIdentifier];
      if (l2Ready != null) {
        final reusePageLayer1 =
            _media?.display != null &&
            _media!.display!.assetIdentifier == widget.assetIdentifier;
        if (l2Ready.kind == FeedL2ReadyKind.stillFull ||
            (l2Ready.kind == FeedL2ReadyKind.video && !reusePageLayer1)) {
          await _startLoadFromL2Ready(
            l2Ready: l2Ready,
            gate: gate!,
            generation: generation!,
          );
          return;
        }
      }
    }

    if (startedOffCurrent) {
      setState(() {
        _layer2InFlight = false;
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
          _layer2InFlight = false;
          _surfaceReady = false;
          _liveMotionMounted = false;
          _loading = true;
          _media = null;
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
    }

    // Current full reload: await host cancel so a new Live request cannot
    // race leave (F4 / ADR-006). Neighbour reuseLayer1 skips this unless
    // Live flags leaked (above). Leave already queued cancel; maybeBegin
    // shares LiveHostOpSerial with that cancel.
    final cancelHost = _liveMotionMounted || _isLiveStillMedia(_media);
    await _teardownLiveMotion(cancelHost: cancelHost);
    if (!mounted) {
      return;
    }

    final currentGate = gate!;
    final currentGeneration = generation!;

    setState(() {
      _layer2Failed = false;
      _layer2FailureReason = null;
      _layer2InFlight = false;
      _surfaceReady = false;
      _liveMotionMounted = false;
      if (_media?.display == null) {
        _loading = true;
        _media = null;
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
      return;
    }
    if (layer1 != null) {
      setState(() {
        _media = layer1;
        _loading = false;
        _layer2InFlight = true;
      });
    } else {
      setState(() {
        _layer2InFlight = true;
      });
    }

    await _awaitLayer2Dwell(bypassDwell: bypassDwell);
    if (!mounted ||
        !currentGate.isCurrent(currentGeneration) ||
        !widget.isCurrent) {
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

  Future<void> _applyLayer2Result({
    required FeedMediaRequestGate gate,
    required int generation,
    required FeedPageMedia? layer1,
    required FeedPageMedia? layer2,
  }) async {
    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      return;
    }
    if (layer2 == null) {
      setState(() => _layer2InFlight = false);
      return;
    }
    if (layer2.kind == FeedPageMediaKind.failed) {
      setState(() {
        _layer2InFlight = false;
        _layer2FailureReason =
            layer2.failureReason ?? FeedFailureReason.generic;
        if (_media?.display != null || layer1?.display != null) {
          _layer2Failed = true;
          _loading = false;
        } else {
          _media = layer2;
          _loading = false;
          _layer2Failed = false;
        }
      });
      return;
    }
    if (layer2.kind == FeedPageMediaKind.video) {
      setState(() {
        _media = FeedPageMedia.video(
          layer2.videoAssetId!,
          poster: layer1?.display ?? _media?.display,
        );
        _loading = false;
        _layer2InFlight = true;
        _layer2Failed = false;
        _layer2FailureReason = null;
      });
      _recordL2ReadySession(layer2: layer2, layer1: layer1);
      await _syncPlaybackActive();
      return;
    }
    final liveStill =
        layer2.kind == FeedPageMediaKind.still &&
        layer2.display?.mediaKind == PlaybackMediaKind.livePhoto;
    setState(() {
      _media = layer2;
      _loading = false;
      _layer2InFlight = false;
      _layer2Failed = false;
      _layer2FailureReason = null;
      // 14.6b: same-frame handoff so the Live spinner does not drop while
      // [_maybeBeginLiveMotion] awaits LiveHostOpSerial.
      if (liveStill && widget.isCurrent) {
        _livePreparing = true;
      }
    });
    _recordL2ReadySession(layer2: layer2, layer1: layer1);
    widget.onCurrentLayer2MediaReady?.call(widget.assetIdentifier);
    await _maybeBeginLiveMotion();
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
          ref.read(browseL2ReadySessionProvider.notifier).record(
            FeedL2ReadyEntry(
              assetIdentifier: id,
              kind: FeedL2ReadyKind.stillFull,
              cover: layer2.display,
            ),
          );
        }
      case FeedPageMediaKind.video:
        final poster = layer1?.display ?? _media?.display;
        ref.read(browseL2ReadySessionProvider.notifier).record(
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

  /// Cap 15.10: Session L2-ready fast path — skip L1 (+ dwell); still shows
  /// sharp; video keeps poster until [onSurfaceReady].
  Future<void> _startLoadFromL2Ready({
    required FeedL2ReadyEntry l2Ready,
    required FeedMediaRequestGate gate,
    required int generation,
  }) async {
    // Still revisit must not await a held Live cancel chain — leave already
    // queued cancel; 14.6b needs preparing chrome while cancel is in flight.
    final cancelHost = l2Ready.kind == FeedL2ReadyKind.stillFull
        ? _liveMotionMounted
        : (_liveMotionMounted || _isLiveStillMedia(_media));
    await _teardownLiveMotion(cancelHost: cancelHost);
    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      return;
    }

    if (l2Ready.kind == FeedL2ReadyKind.stillFull && l2Ready.cover != null) {
      final liveStill =
          l2Ready.cover!.mediaKind == PlaybackMediaKind.livePhoto;
      setState(() {
        _layer2Failed = false;
        _layer2FailureReason = null;
        _layer2InFlight = false;
        _surfaceReady = false;
        _liveMotionMounted = false;
        _loading = false;
        _media = FeedPageMedia.still(
          l2Ready.cover!,
          layer: FeedDisplayLayer.full,
        );
        if (liveStill && widget.isCurrent) {
          _livePreparing = true;
        }
      });
      widget.onCurrentLayer2MediaReady?.call(widget.assetIdentifier);
      await _maybeBeginLiveMotion();
      return;
    }

    if (l2Ready.kind == FeedL2ReadyKind.video) {
      setState(() {
        _layer2Failed = false;
        _layer2FailureReason = null;
        _surfaceReady = false;
        _liveMotionMounted = false;
        _loading = false;
        _layer2InFlight = true;
        _media = FeedPageMedia.video(
          widget.assetIdentifier,
          poster: l2Ready.cover,
        );
      });
      await _awaitLayer2Dwell(bypassDwell: true);
      if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
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
      );
    }
  }

  /// Play when this page is current + surface ready. Never pause from here.
  Future<void> _syncPlaybackActive() async {
    final media = _media;
    if (media == null || media.kind != FeedPageMediaKind.video) {
      return;
    }
    if (widget.isCurrent && _surfaceReady) {
      final playback = ref.read(playbackRepositoryProvider);
      // Cap 9.6 G3=A: re-apply shared mute before play (pool rebuild / clear).
      await playback.setMute(ref.read(sharedMuteProvider));
      await playback.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    _listenSharedMuteForLive();
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;

    if (_loading) {
      // Layer 1 miss only. Library resolve uses when(loading:) +
      // mainBrowseFeedLoading and stays centered. Do not merge this
      // branch into _mediaStack (off-current empty / pendingVideo).
      return ColoredBox(
        key: const Key('mainBrowseFeedPageLoading'),
        color: tokens.feedBackground,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _FeedCornerChrome(
              color: tokens.brandGold,
              strutBadgeLabel: l10n.mainBrowseLiveBadge,
              showSpinner: true,
              rowKey: const Key('mainBrowseFeedPageLoadingChrome'),
              spinnerKey: const Key('mainBrowseFeedPageLoadingSpinner'),
              semanticsLabel: l10n.mainBrowseFeedLayer1Loading,
            ),
          ],
        ),
      );
    }

    final media = _media;
    if (media == null) {
      return const SizedBox.expand();
    }

    return switch (media.kind) {
      FeedPageMediaKind.still => _mediaStack(
        still: _StillPage(
          display: media.display!,
          liveLabel: l10n.mainBrowseLiveBadge,
          liveLoadLabel: l10n.mainBrowseFeedLiveLoading,
          layer3LoadLabel: l10n.mainBrowseFeedLayer3Loading,
          showLoadSpinner: _showItemLoadSpinner,
          onPreviewFileBroken: _onPreviewFileBroken,
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
                    await _tryStartLivePlayback(generation);
                  },
                )
              : null,
        ),
        l10n: l10n,
        tokens: tokens,
      ),
      FeedPageMediaKind.pendingVideo => ColoredBox(
        key: Key('mainBrowseFeedVideoPending_${widget.assetIdentifier}'),
        color: tokens.feedBackground,
      ),
      FeedPageMediaKind.video => _mediaStack(
        still: null,
        video: widget.isCurrent
            ? _VideoPage(
                assetIdentifier: media.videoAssetId!,
                onSurfaceReady: () async {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _surfaceReady = true;
                    _layer2InFlight = false;
                  });
                  if (widget.isCurrent) {
                    widget.onCurrentLayer2MediaReady?.call(
                      widget.assetIdentifier,
                    );
                  }
                  await ref
                      .read(playbackRepositoryProvider)
                      .notifyDisplaySurfaceReady(media.videoAssetId!);
                  await _syncPlaybackActive();
                },
              )
            : null,
        poster: media.display != null
            ? _StillPage(
                display: media.display!,
                liveLabel: l10n.mainBrowseLiveBadge,
                layer3LoadLabel: l10n.mainBrowseFeedLayer3Loading,
                showLoadSpinner: widget.isCurrent && _layer2InFlight,
                onPreviewFileBroken: _onPreviewFileBroken,
              )
            : null,
        l10n: l10n,
        tokens: tokens,
      ),
      FeedPageMediaKind.failed => _BrowseStatusPanel(
        panelKey: const Key('mainBrowseFeedPageFailed'),
        message: _failureCopy(
          l10n,
          media.failureReason ?? FeedFailureReason.generic,
        ),
        actionLabel: l10n.mainBrowseFeedRetry,
        actionKey: const Key('mainBrowseFeedPageRetry'),
        onAction: () {
          unawaited(_startLoad(bypassDwell: true));
        },
      ),
    };
  }

  Widget _mediaStack({
    required AppLocalizations l10n,
    required WakeTokTokens tokens,
    Widget? still,
    Widget? video,
    Widget? poster,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Cap 15.7: poster at index 0 so leaving (video child dropped)
        // does not shift the Image Element. Video paints after = on top.
        if (poster != null) poster,
        if (still != null) still,
        if (video != null) video,
        if (_layer2InFlight && still == null && poster == null)
          _FeedCornerChrome(
            color: tokens.brandGold,
            strutBadgeLabel: l10n.mainBrowseLiveBadge,
            showSpinner: true,
            rowKey: const Key('mainBrowseFeedLayer3Chrome'),
            spinnerKey: const Key('mainBrowseFeedLayer3Spinner'),
            semanticsLabel: l10n.mainBrowseFeedLayer3Loading,
          ),
        if (_layer2Failed && !_layer2InFlight)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
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
                  TextButton(
                    key: const Key('mainBrowseFeedLayer2Retry'),
                    onPressed: () {
                      unawaited(_retryLayer2Only(bypassDwell: true));
                    },
                    child: Text(
                      l10n.mainBrowseFeedRetry,
                      style: tokens.labelOnMedia,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _failureCopy(AppLocalizations l10n, FeedFailureReason reason) {
    return switch (reason) {
      FeedFailureReason.network => l10n.mainBrowseFeedNetworkFailed,
      FeedFailureReason.download => l10n.mainBrowseFeedDownloadFailed,
      FeedFailureReason.generic => l10n.mainBrowseFeedMediaFailed,
    };
  }
}

class _StillPage extends StatelessWidget {
  const _StillPage({
    required this.display,
    required this.liveLabel,
    this.liveLoadLabel,
    this.layer3LoadLabel,
    this.showLoadSpinner = false,
    this.liveMotionOverlay,
    this.onPreviewFileBroken,
  });

  final DisplayAsset display;
  final String liveLabel;

  /// VoiceOver while Live Layer 2 / motion prepare spinner is shown.
  final String? liveLoadLabel;

  /// VoiceOver while non-Live Layer 2 spinner is shown.
  final String? layer3LoadLabel;

  /// Cap 14.6b: corner spinner for Layer 2 in-flight (any item) or Live prepare.
  final bool showLoadSpinner;

  /// Cap 9.4 F1=A: motion-phase Live PV only (null when idle / after Q7 unload).
  final Widget? liveMotionOverlay;

  final VoidCallback? onPreviewFileBroken;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final isLive = display.mediaKind == PlaybackMediaKind.livePhoto;
    final showChrome = isLive || showLoadSpinner;
    final loadLabel = isLive ? liveLoadLabel : layer3LoadLabel;
    return Stack(
      key: Key('mainBrowseFeedStill_${display.assetIdentifier}'),
      fit: StackFit.expand,
      children: [
        _ReloadableFileImage(
          path: display.localFilePath,
          color: tokens.feedBackground,
          onFileBroken: onPreviewFileBroken,
        ),
        if (showChrome)
          _FeedCornerChrome(
            color: tokens.brandGold,
            badgeLabel: isLive ? liveLabel : null,
            strutBadgeLabel: liveLabel,
            showSpinner: showLoadSpinner,
            rowKey: isLive
                ? Key('mainBrowseFeedLiveChrome_${display.assetIdentifier}')
                : const Key('mainBrowseFeedLayer3Chrome'),
            spinnerKey: isLive
                ? Key('mainBrowseFeedLivePreparing_${display.assetIdentifier}')
                : const Key('mainBrowseFeedLayer3Spinner'),
            semanticsLabel: showLoadSpinner ? loadLabel : null,
          ),
        if (liveMotionOverlay != null) liveMotionOverlay!,
      ],
    );
  }
}

/// Bottom-right load chrome for every feed item (Live badge ± spinner).
///
/// Live lays the spinner out in a [Row] with the taller LIVE badge
/// (`CrossAxisAlignment.center`), so the spinner sits higher than a
/// 16px-only `Positioned(bottom: 12)`. Non-Live uses a zero-width badge
/// strut with the same height so the spinner matches that vertical slot.
class _FeedCornerChrome extends StatelessWidget {
  const _FeedCornerChrome({
    required this.color,
    this.badgeLabel,
    this.strutBadgeLabel,
    this.showSpinner = false,
    this.rowKey,
    this.spinnerKey,
    this.semanticsLabel,
  });

  static const double inset = 12;

  final Color color;
  final String? badgeLabel;
  final String? strutBadgeLabel;
  final bool showSpinner;
  final Key? rowKey;
  final Key? spinnerKey;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final showBadge = badgeLabel != null;
    if (!showBadge && !showSpinner) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: inset,
      bottom: inset,
      child: IgnorePointer(
        child: Semantics(
          container: true,
          // Spinner rows (Layer 1 miss, Layer 2, Live prepare) own the
          // label; this drops descendant Text including the zero-width
          // LIVE strut so VoiceOver does not announce "LIVE".
          excludeSemantics: showSpinner,
          label: showSpinner ? semanticsLabel : null,
          child: Row(
            key: rowKey,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showBadge) ...[
                _LiveBadge(label: badgeLabel!),
                if (showSpinner) const SizedBox(width: 8),
              ] else if (showSpinner && strutBadgeLabel != null)
                Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0,
                  child: Opacity(
                    opacity: 0,
                    child: _LiveBadge(label: strutBadgeLabel!),
                  ),
                ),
              if (showSpinner)
                _FeedCornerSpinner(spinnerKey: spinnerKey, color: color),
            ],
          ),
        ),
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
  });

  final String path;
  final Color color;
  final VoidCallback? onFileBroken;

  @override
  State<_ReloadableFileImage> createState() => _ReloadableFileImageState();
}

class _ReloadableFileImageState extends State<_ReloadableFileImage> {
  bool _postedBroken = false;

  @override
  void didUpdateWidget(covariant _ReloadableFileImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _postedBroken = false;
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
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            if (!_postedBroken) {
              _postedBroken = true;
              final onBroken = widget.onFileBroken;
              if (onBroken != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    onBroken();
                  }
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

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Container(
      key: const Key('mainBrowseLiveBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.mediaScrim.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tokens.onMedia, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: tokens.labelOnMedia),
        ],
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.assetIdentifier,
    required this.onSurfaceReady,
  });

  final String assetIdentifier;
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
