import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/library_smoke/presentation_providers.dart';
import 'package:waketok/features/main_browse/feed_activation_coordinator.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/feed_page_media.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/presentation_overlay_snapshot.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Vertical Manual feed over Cap 6 resolve ids (Cap 7.5 / ADR-014).
class VerticalMediaFeed extends ConsumerStatefulWidget {
  const VerticalMediaFeed({super.key});

  @override
  ConsumerState<VerticalMediaFeed> createState() => _VerticalMediaFeedState();
}

class _VerticalMediaFeedState extends ConsumerState<VerticalMediaFeed> {
  PageController? _pageController;
  StreamSubscription<PlaybackRestoreRequest>? _restoreSub;
  List<String> _ids = const [];

  final FeedActivationCoordinator _activation = FeedActivationCoordinator();
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
        _activeDisplayGeneration ==
            _activation.currentDisplayGate.generation) {
      return;
    }
    final gens = _activation.beginCurrentItem();
    final cached = _overlayCache[assetId];
    setState(() {
      _activeAssetId = assetId;
      _activeDisplayGeneration = gens.display;
      _overlaySnapshot = cached ??
          PresentationOverlaySnapshot(assetIdentifier: assetId);
    });
    unawaited(_loadOverlay(gens.metadata, assetId));
  }

  Future<void> _loadOverlay(int metadataGeneration, String assetId) async {
    final repo = ref.read(presentationMetadataRepositoryProvider);
    try {
      final meta = await repo.requestPresentationMetadata(assetId);
      if (!mounted ||
          !_activation.metadataGate.isCurrent(metadataGeneration)) {
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
      if (!mounted ||
          !_activation.metadataGate.isCurrent(metadataGeneration)) {
        return;
      }
      setState(() {
        final base = (_overlaySnapshot?.assetIdentifier == assetId)
            ? _overlaySnapshot!
            : PresentationOverlaySnapshot(assetIdentifier: assetId);
        final next = base.mergeSize(size);
        _overlaySnapshot = next;
        _overlayCache[assetId] = next;
      });
    } catch (_) {
      // Size stays blank.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    final asyncQueue = ref.watch(mainBrowseFeedQueueProvider);
    final source = ref.watch(mainBrowseSelectedSourceProvider);
    final feedIndex = ref.watch(mainBrowseFeedIndexProvider);
    final destination = ref.watch(mainBrowseDestinationProvider);
    final browseActive = destination == MainBrowseDestination.browse;

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
      child: asyncQueue.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: tokens.brandGold),
              const SizedBox(height: 16),
              Text(
                l10n.mainBrowseFeedLoading,
                style: tokens.bodyOnMedia,
              ),
            ],
          ),
        ),
        error: (error, stackTrace) => _FeedMessage(
          message: l10n.mainBrowseFeedResolveFailed,
          actionLabel: l10n.mainBrowseFeedRetry,
          onAction: () => ref.invalidate(mainBrowseFeedQueueProvider),
        ),
        data: (resolved) {
          final ids = resolved.assetIdentifiers;
          _ids = ids;
          if (ids.isEmpty) {
            return _FeedMessage(message: l10n.mainBrowseFeedEmpty);
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
          if (_activeAssetId != currentId ||
              _activeDisplayGeneration == null) {
            final gens = _activation.beginCurrentItem();
            _activeAssetId = currentId;
            _activeDisplayGeneration = gens.display;
            _overlaySnapshot = _overlayCache[currentId] ??
                PresentationOverlaySnapshot(assetIdentifier: currentId);
            unawaited(_loadOverlay(gens.metadata, currentId));
          }
          return Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                key: ValueKey<String>('feed-${source.id}-${ids.length}'),
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
                    key: ValueKey<String>('page-${ids[index]}-$index'),
                    assetIdentifier: ids[index],
                    feedIndex: index,
                    sourceKind: source.kind,
                    isCurrent: isCurrent,
                    currentDisplayGate:
                        isCurrent ? _activation.currentDisplayGate : null,
                    assignedDisplayGeneration:
                        isCurrent ? _activeDisplayGeneration : null,
                  );
                },
              ),
              if (browseActive) MediaInfoOverlay(snapshot: _overlaySnapshot),
            ],
          );
        },
      ),
    );
  }
}

class _FeedMessage extends StatelessWidget {
  const _FeedMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Center(
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
                key: const Key('mainBrowseFeedRetry'),
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

/// One PageView child: still / video / error with generation-gated loads.
class MediaFeedPage extends ConsumerStatefulWidget {
  const MediaFeedPage({
    super.key,
    required this.assetIdentifier,
    required this.feedIndex,
    required this.sourceKind,
    required this.isCurrent,
    this.currentDisplayGate,
    this.assignedDisplayGeneration,
  });

  final String assetIdentifier;
  final int feedIndex;
  final AssetSourceKind sourceKind;
  final bool isCurrent;

  /// When current: feed-owned gate already begun in [_activateCurrentItem].
  final FeedMediaRequestGate? currentDisplayGate;
  final int? assignedDisplayGeneration;

  static const String playbackViewType = 'waketok/playback_surface';

  @override
  ConsumerState<MediaFeedPage> createState() => _MediaFeedPageState();
}

class _MediaFeedPageState extends ConsumerState<MediaFeedPage> {
  final FeedMediaRequestGate _localGate = FeedMediaRequestGate();
  FeedPageMedia? _media;
  bool _loading = true;
  bool _surfaceReady = false;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant MediaFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetIdentifier != widget.assetIdentifier ||
        oldWidget.feedIndex != widget.feedIndex ||
        oldWidget.sourceKind != widget.sourceKind ||
        oldWidget.assignedDisplayGeneration !=
            widget.assignedDisplayGeneration) {
      _startLoad();
    } else if (oldWidget.isCurrent != widget.isCurrent) {
      if (oldWidget.isCurrent && !widget.isCurrent) {
        unawaited(ref.read(playbackRepositoryProvider).pause());
        // Drop ownership of the shared player; keep a pending placeholder.
        if (_media?.kind == FeedPageMediaKind.video) {
          setState(() {
            _media = FeedPageMedia.pendingVideo(widget.assetIdentifier);
            _surfaceReady = false;
          });
        }
      } else if (widget.isCurrent) {
        if (_media?.kind == FeedPageMediaKind.pendingVideo ||
            _media?.kind == FeedPageMediaKind.video) {
          _startLoad();
        } else {
          unawaited(_syncPlaybackActive());
        }
      }
    }
  }

  @override
  void dispose() {
    _localGate.begin(); // invalidate in-flight local loads
    if (_media?.kind == FeedPageMediaKind.video && widget.isCurrent) {
      unawaited(ref.read(playbackRepositoryProvider).pause());
    }
    super.dispose();
  }

  Future<void> _startLoad() async {
    final FeedMediaRequestGate gate;
    final int generation;
    if (widget.isCurrent) {
      final shared = widget.currentDisplayGate;
      final assigned = widget.assignedDisplayGeneration;
      if (shared == null || assigned == null) {
        // Parent activation not ready yet — keep spinner; reload on assign.
        setState(() {
          _loading = true;
          _media = null;
          _surfaceReady = false;
        });
        return;
      }
      gate = shared;
      generation = assigned;
    } else {
      gate = _localGate;
      generation = _localGate.begin();
    }
    setState(() {
      _loading = true;
      _media = null;
      _surfaceReady = false;
    });
    final result = await loadFeedPageMedia(
      gate: gate,
      generation: generation,
      sourceKind: widget.sourceKind,
      assetIdentifier: widget.assetIdentifier,
      feedIndex: widget.feedIndex,
      isCurrent: widget.isCurrent,
      displayRepository: ref.read(mediaDisplayRepositoryProvider),
      playbackRepository: ref.read(playbackRepositoryProvider),
    );
    if (!mounted || !gate.isCurrent(generation) || result == null) {
      return;
    }
    setState(() {
      _media = result;
      _loading = false;
    });
    await _syncPlaybackActive();
  }

  /// Play when this page is current + surface ready. Never pause from here.
  Future<void> _syncPlaybackActive() async {
    final media = _media;
    if (media == null || media.kind != FeedPageMediaKind.video) {
      return;
    }
    if (widget.isCurrent && _surfaceReady) {
      await ref.read(playbackRepositoryProvider).play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: tokens.brandGold),
      );
    }

    final media = _media;
    if (media == null) {
      return const SizedBox.expand();
    }

    return switch (media.kind) {
      FeedPageMediaKind.still => _StillPage(
          display: media.display!,
          liveLabel: l10n.mainBrowseLiveBadge,
        ),
      FeedPageMediaKind.pendingVideo => ColoredBox(
          key: Key('mainBrowseFeedVideoPending_${widget.assetIdentifier}'),
          color: tokens.feedBackground,
        ),
      FeedPageMediaKind.video => _VideoPage(
          assetIdentifier: media.videoAssetId!,
          onSurfaceReady: () async {
            if (!mounted) {
              return;
            }
            setState(() => _surfaceReady = true);
            await ref
                .read(playbackRepositoryProvider)
                .notifyDisplaySurfaceReady(media.videoAssetId!);
            await _syncPlaybackActive();
          },
        ),
      FeedPageMediaKind.iCloudOnly => _FeedPageStatus(
          message: l10n.mainBrowseFeedICloudOnly,
          onRetry: _startLoad,
          retryLabel: l10n.mainBrowseFeedRetry,
        ),
      FeedPageMediaKind.failed => _FeedPageStatus(
          message: l10n.mainBrowseFeedMediaFailed,
          onRetry: _startLoad,
          retryLabel: l10n.mainBrowseFeedRetry,
        ),
    };
  }
}

class _StillPage extends StatelessWidget {
  const _StillPage({
    required this.display,
    required this.liveLabel,
  });

  final DisplayAsset display;
  final String liveLabel;

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
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: tokens.feedBackground,
          ),
        ),
        if (display.mediaKind == PlaybackMediaKind.livePhoto)
          Positioned(
            top: 12,
            left: 12,
            child: _LiveBadge(label: liveLabel),
          ),
      ],
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
          Text(
            label,
            style: tokens.labelOnMedia,
          ),
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

class _FeedPageStatus extends StatelessWidget {
  const _FeedPageStatus({
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Center(
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
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRetry,
              child: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
