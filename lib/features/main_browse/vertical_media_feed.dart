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
  ConsumerState<VerticalMediaFeed> createState() => _VerticalMediaFeedState();
}

class _VerticalMediaFeedState extends ConsumerState<VerticalMediaFeed> {
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
  void _activateCurrentItem(String assetId) {
    if (_activeAssetId == assetId &&
        _activeDisplayGeneration == _activation.currentDisplayGate.generation) {
      return;
    }
    final gens = _activation.beginCurrentItem();
    final cached = _overlayCache[assetId];
    setState(() {
      _activeAssetId = assetId;
      _activeDisplayGeneration = gens.display;
      _overlaySnapshot =
          cached ?? PresentationOverlaySnapshot(assetIdentifier: assetId);
    });
    unawaited(_loadOverlay(gens.metadata, assetId));
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncSession = ref.watch(browseSessionProvider);
    final source = ref.watch(mainBrowseSelectedSourceProvider);
    final feedIndex = ref.watch(mainBrowseFeedIndexProvider);
    final destination = ref.watch(mainBrowseDestinationProvider);
    final browseActive = destination == MainBrowseDestination.browse;

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
        loading: () => Center(
          key: const Key('mainBrowseFeedLoading'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: tokens.brandGold),
              const SizedBox(height: 16),
              Text(l10n.mainBrowseFeedLoading, style: tokens.bodyOnMedia),
            ],
          ),
        ),
        error: (error, stackTrace) => _BrowseStatusPanel(
          // Resolve-level failure path (source could not load).
          panelKey: const Key('mainBrowseFeedResolveFailed'),
          message: l10n.mainBrowseFeedResolveFailed,
          actionLabel: l10n.mainBrowseFeedRetry,
          actionKey: const Key('mainBrowseFeedRetry'),
          onAction: () => ref.invalidate(browseSessionProvider),
        ),
        data: (view) {
          final ids = view.orderedAssetIds;
          _ids = ids;
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
          if (_activeAssetId != currentId || _activeDisplayGeneration == null) {
            final gens = _activation.beginCurrentItem();
            _activeAssetId = currentId;
            _activeDisplayGeneration = gens.display;
            _overlaySnapshot =
                _overlayCache[currentId] ??
                PresentationOverlaySnapshot(assetIdentifier: currentId);
            unawaited(_loadOverlay(gens.metadata, currentId));
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
                  itemCount: ids.length,
                  onPageChanged: (i) {
                    ref.read(mainBrowseFeedIndexProvider.notifier).setIndex(i);
                    _activateCurrentItem(ids[i]);
                  },
                  itemBuilder: (context, index) {
                    final isCurrent = browseActive && index == feedIndex;
                    return MediaFeedPage(
                      key: ValueKey<String>(
                        'page-${ids[index]}-$index-r${view.roundEpoch}',
                      ),
                      assetIdentifier: ids[index],
                      feedIndex: index,
                      sourceKind: source.kind,
                      isCurrent: isCurrent,
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
    required this.liveHostSerial,
    this.currentDisplayGate,
    this.assignedDisplayGeneration,
    this.onCurrentLayer2MediaReady,
  });

  final String assetIdentifier;
  final int feedIndex;
  final AssetSourceKind sourceKind;
  final bool isCurrent;
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
  final FeedMediaRequestGate _localGate = FeedMediaRequestGate();

  /// Cap 9.4 / F4: per Live activation token (not assetId alone).
  final FeedMediaRequestGate _liveMotionGate = FeedMediaRequestGate();
  FeedPageMedia? _media;
  bool _loading = true;
  bool _surfaceReady = false;
  bool _layer2InFlight = false;
  bool _layer2Failed = false;
  FeedFailureReason? _layer2FailureReason;
  AppLifecycleState? _lastLifecycle;

  bool _liveMotionMounted = false;
  bool _livePhotoReady = false;
  bool _liveSurfaceReady = false;
  bool _liveStartIssued = false;

  /// Cap 9.5 Q4=A: motion prepare spinner (generation-gated writes).
  bool _livePreparing = false;
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
      unawaited(_retryLayer2Only());
      return;
    }
    if (_media?.kind == FeedPageMediaKind.failed) {
      unawaited(_startLoad());
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
    // Leaving current must always pause — even when generation/asset props
    // change in the same update (parent clears assignedDisplayGeneration when
    // isCurrent becomes false). Otherwise video→still / video→iCloud never
    // pause because _startLoad runs and skips the isCurrent-only branch.
    final leftCurrent = oldWidget.isCurrent && !widget.isCurrent;
    if (leftCurrent) {
      unawaited(ref.read(playbackRepositoryProvider).pause());
      _displayRepo ??= ref.read(mediaDisplayRepositoryProvider);
      // Shared currentDisplayGate is bumped by the parent
      // [_activateCurrentItem] when the new current page is assigned.
      // This branch does not bump that gate; G2 uses [widget.isCurrent].
      unawaited(_cancelCurrentItemPhotoKit(widget.assetIdentifier));
      if (_media?.display != null) {
        setState(() {
          _media = FeedPageMedia.still(
            _media!.display!,
            layer: _media!.displayLayer ?? FeedDisplayLayer.preview,
          );
          _surfaceReady = false;
          _layer2InFlight = false;
          _layer2Failed = false;
          _layer2FailureReason = null;
        });
      } else if (_media?.kind == FeedPageMediaKind.video) {
        setState(() {
          _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
          _surfaceReady = false;
          _layer2InFlight = false;
          _layer2Failed = false;
          _layer2FailureReason = null;
        });
      } else {
        setState(() {
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
        oldWidget.feedIndex != widget.feedIndex ||
        oldWidget.sourceKind != widget.sourceKind ||
        oldWidget.assignedDisplayGeneration !=
            widget.assignedDisplayGeneration) {
      if (oldWidget.assetIdentifier != widget.assetIdentifier) {
        unawaited(_cancelCurrentItemPhotoKit(oldWidget.assetIdentifier));
      }
      _startLoad();
    } else if (!leftCurrent && oldWidget.isCurrent != widget.isCurrent) {
      // Became current without identity/generation change (rare).
      if (widget.isCurrent) {
        if (_media?.kind == FeedPageMediaKind.pendingVideo ||
            _media?.kind == FeedPageMediaKind.video) {
          _startLoad();
        } else {
          unawaited(_syncPlaybackActive());
          unawaited(_maybeBeginLiveMotion());
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _localGate.begin(); // invalidate in-flight local loads
    _liveMotionGate.begin(); // invalidate Live activation
    unawaited(_cancelLiveSubscriptions());
    unawaited(_cancelCurrentItemPhotoKit(widget.assetIdentifier));
    final playback = _playbackRepo;
    if (_media?.kind == FeedPageMediaKind.video &&
        widget.isCurrent &&
        playback != null) {
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
    await _liveReadySub?.cancel();
    await _liveFailedSub?.cancel();
    await _liveEndedSub?.cancel();
    _liveReadySub = null;
    _liveFailedSub = null;
    _liveEndedSub = null;
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
      return;
    }
    final assetId = widget.assetIdentifier;
    final LivePhotoRepository live =
        _liveRepo ?? ref.read(livePhotoRepositoryProvider);
    final PlaybackRepository playback =
        _playbackRepo ?? ref.read(playbackRepositoryProvider);
    _liveRepo = live;
    _playbackRepo = playback;

    await _enqueueLiveOp(() async {
      if (!mounted || !widget.isCurrent || !_isLiveStillMedia(_media)) {
        return;
      }
      final generation = _liveMotionGate.begin();
      await _cancelLiveSubscriptions();
      _livePhotoReady = false;
      _liveSurfaceReady = false;
      _liveStartIssued = false;
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
          return;
        }
        await live.requestLivePhoto(assetId);
        if (!mounted ||
            !_liveMotionGate.isCurrent(generation) ||
            !widget.isCurrent) {
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

  Future<void> _retryLayer2Only() async {
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

  Future<void> _startLoad() async {
    final FeedMediaRequestGate gate;
    final int generation;
    if (widget.isCurrent) {
      final shared = widget.currentDisplayGate;
      final assigned = widget.assignedDisplayGeneration;
      if (shared == null || assigned == null) {
        // Parent activation not ready yet — keep spinner; reload on assign.
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
    } else {
      gate = _localGate;
      generation = _localGate.begin();
    }
    // Await teardown so cancel cannot race a later request (F4 / ADR-006).
    // Off-current pages must still cancelHost when this page had Live motion /
    // a Live still — leave must not rely solely on unawaited leftCurrent.
    // Teardown already begin()s the live gate and clears preparing via
    // [_setLivePreparing] — do not bump again here.
    final cancelHost =
        widget.isCurrent || _liveMotionMounted || _isLiveStillMedia(_media);
    await _teardownLiveMotion(cancelHost: cancelHost);
    if (!mounted) {
      return;
    }

    if (!widget.isCurrent) {
      setState(() {
        _layer2InFlight = false;
        _layer2Failed = false;
        _layer2FailureReason = null;
        _surfaceReady = false;
        _liveMotionMounted = false;
        if (_media?.display != null) {
          _loading = false;
        } else if (widget.sourceKind == AssetSourceKind.mediaTypeVideos) {
          _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
          _loading = false;
        } else {
          _media = null;
          _loading = true;
        }
      });
      return;
    }

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
      gate: gate,
      generation: generation,
      assetIdentifier: widget.assetIdentifier,
      displayRepository: displayRepo,
    );
    if (!mounted || !gate.isCurrent(generation)) {
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

    if (!mounted || !gate.isCurrent(generation) || !widget.isCurrent) {
      return;
    }

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
      await _syncPlaybackActive();
      return;
    }
    setState(() {
      _media = layer2;
      _loading = false;
      _layer2InFlight = false;
      _layer2Failed = false;
      _layer2FailureReason = null;
    });
    widget.onCurrentLayer2MediaReady?.call(widget.assetIdentifier);
    await _maybeBeginLiveMotion();
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
      return Center(
        key: const Key('mainBrowseFeedPageLoading'),
        child: CircularProgressIndicator(color: tokens.brandGold),
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
          livePreparing: _livePreparing,
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
        video: _VideoPage(
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
              widget.onCurrentLayer2MediaReady?.call(widget.assetIdentifier);
            }
            await ref
                .read(playbackRepositoryProvider)
                .notifyDisplaySurfaceReady(media.videoAssetId!);
            await _syncPlaybackActive();
          },
        ),
        poster: (!_surfaceReady && media.display != null)
            ? _StillPage(
                display: media.display!,
                liveLabel: l10n.mainBrowseLiveBadge,
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
        onAction: _startLoad,
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
        if (video != null) video,
        if (still != null) still,
        if (poster != null) poster,
        if (_layer2InFlight)
          IgnorePointer(
            child: Center(
              child: Semantics(
                key: const Key('mainBrowseFeedLayer3Spinner'),
                label: l10n.mainBrowseFeedLayer3Loading,
                child: CircularProgressIndicator(color: tokens.brandGold),
              ),
            ),
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
                      unawaited(_retryLayer2Only());
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
    this.livePreparing = false,
    this.liveMotionOverlay,
  });

  final DisplayAsset display;
  final String liveLabel;

  /// Cap 9.5 Q4=A: spinner-only beside LIVE badge while motion prepares.
  final bool livePreparing;

  /// Cap 9.4 F1=A: motion-phase Live PV only (null when idle / after Q7 unload).
  final Widget? liveMotionOverlay;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Stack(
      key: Key('mainBrowseFeedStill_${display.assetIdentifier}'),
      fit: StackFit.expand,
      children: [
        Image.file(
          File(display.localFilePath),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              ColoredBox(color: tokens.feedBackground),
        ),
        if (display.mediaKind == PlaybackMediaKind.livePhoto)
          Positioned(
            top: 12,
            left: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveBadge(label: liveLabel),
                if (livePreparing) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    key: Key(
                      'mainBrowseFeedLivePreparing_${display.assetIdentifier}',
                    ),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: tokens.brandGold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (liveMotionOverlay != null) liveMotionOverlay!,
      ],
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
