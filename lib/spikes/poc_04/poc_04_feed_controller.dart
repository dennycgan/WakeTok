import 'package:waketok/spikes/poc_04/generated/poc_04_photo_library.g.dart';

/// View-type id registered in AppDelegate for POC-04 AVPlayer Platform Views.
const String kPoc04AvPlayerViewType = 'poc04_av_player';

/// Default longest-edge cap for image temp export (E3=A).
const int kPoc04ImageMaxLongEdge = 1080;

/// Soft cap for tracked image temp files in the feed window.
const int kPoc04TempFileSoftCap = 5;

/// Abstraction over [Poc04MediaBridgeApi] for unit tests.
abstract class Poc04MediaBridge {
  Future<String> resolveImageTempFile(String assetId, int maxLongEdge);

  Future<void> releaseImageTempFile(String path);

  Future<void> releaseAllImageTempFiles();

  Future<void> prefetchNeighbors(List<String> assetIds);

  Future<void> setUseTextureSurface(bool enabled);

  /// Texture mode: valid textureId after native register. PV mode: -1.
  Future<int> attachActiveVideo(String assetId);

  Future<void> attachWarmingVideo(String assetId);

  Future<void> playActive();

  Future<void> pauseActive();

  Future<void> releaseVideo(String assetId);

  Future<void> releaseAllVideos();

  Future<Poc04PoolDiagnostics> getPoolDiagnostics();

  Future<void> clearFirstFrameSamples();

  Future<List<double>> getFirstFrameSamples();

  Future<double> waitActiveFirstFrameMs(int timeoutMs);

  Future<void> setLockAudioProbeEnabled(bool enabled);

  Future<void> setPlaybackPlan(List<Poc04PlaybackPlanItem> items);

  Future<void> syncPlanPosition(String assetId, int feedIndex);

  Future<void> notifyPlatformViewReady(String assetId);

  Future<Poc04LockProbeState> getLockProbeState();
}

/// Production bridge wrapping generated Pigeon host API.
class Poc04PigeonMediaBridge implements Poc04MediaBridge {
  Poc04PigeonMediaBridge([Poc04MediaBridgeApi? api])
      : _api = api ?? Poc04MediaBridgeApi();

  final Poc04MediaBridgeApi _api;

  @override
  Future<String> resolveImageTempFile(String assetId, int maxLongEdge) =>
      _api.resolveImageTempFile(assetId, maxLongEdge);

  @override
  Future<void> releaseImageTempFile(String path) =>
      _api.releaseImageTempFile(path);

  @override
  Future<void> releaseAllImageTempFiles() => _api.releaseAllImageTempFiles();

  @override
  Future<void> prefetchNeighbors(List<String> assetIds) =>
      _api.prefetchNeighbors(assetIds);

  @override
  Future<void> setUseTextureSurface(bool enabled) =>
      _api.setUseTextureSurface(enabled);

  @override
  Future<int> attachActiveVideo(String assetId) =>
      _api.attachActiveVideo(assetId);

  @override
  Future<void> attachWarmingVideo(String assetId) =>
      _api.attachWarmingVideo(assetId);

  @override
  Future<void> playActive() => _api.playActive();

  @override
  Future<void> pauseActive() => _api.pauseActive();

  @override
  Future<void> releaseVideo(String assetId) => _api.releaseVideo(assetId);

  @override
  Future<void> releaseAllVideos() => _api.releaseAllVideos();

  @override
  Future<Poc04PoolDiagnostics> getPoolDiagnostics() =>
      _api.getPoolDiagnostics();

  @override
  Future<void> clearFirstFrameSamples() => _api.clearFirstFrameSamples();

  @override
  Future<List<double>> getFirstFrameSamples() => _api.getFirstFrameSamples();

  @override
  Future<double> waitActiveFirstFrameMs(int timeoutMs) =>
      _api.waitActiveFirstFrameMs(timeoutMs);

  @override
  Future<void> setLockAudioProbeEnabled(bool enabled) =>
      _api.setLockAudioProbeEnabled(enabled);

  @override
  Future<void> setPlaybackPlan(List<Poc04PlaybackPlanItem> items) =>
      _api.setPlaybackPlan(items);

  @override
  Future<void> syncPlanPosition(String assetId, int feedIndex) =>
      _api.syncPlanPosition(assetId, feedIndex);

  @override
  Future<void> notifyPlatformViewReady(String assetId) =>
      _api.notifyPlatformViewReady(assetId);

  @override
  Future<Poc04LockProbeState> getLockProbeState() => _api.getLockProbeState();
}

/// Pure feed orchestration: pool intents + image temp lifecycle (testable).
class Poc04FeedController {
  Poc04FeedController({
    required Poc04MediaBridge bridge,
    required List<Poc04AssetDto> items,
    this.maxLongEdge = kPoc04ImageMaxLongEdge,
    this.tempSoftCap = kPoc04TempFileSoftCap,
  })  : _bridge = bridge,
        items = List.unmodifiable(items);

  final Poc04MediaBridge _bridge;
  final List<Poc04AssetDto> items;
  final int maxLongEdge;
  final int tempSoftCap;

  int index = 0;
  /// Texture id for the active video after attach returns (>=0). -1 = PV / none.
  int activeTextureId = -1;
  final Map<String, String> imagePaths = {};
  final List<String> _releaseLog = [];
  final List<String> _attachActiveLog = [];
  final List<String> _attachWarmLog = [];

  /// Serializes page changes so Probe + PageView cannot interleave resolves.
  Future<void> _pageChain = Future<void>.value();
  int _pageEpoch = 0;

  /// Test/observability: released temp paths in order.
  List<String> get releaseLog => List.unmodifiable(_releaseLog);

  List<String> get attachActiveLog => List.unmodifiable(_attachActiveLog);

  List<String> get attachWarmLog => List.unmodifiable(_attachWarmLog);

  String? get activeVideoId {
    if (items.isEmpty) return null;
    final item = items[index];
    return item.mediaType == Poc04MediaType.video ? item.assetId : null;
  }

  String? get warmingVideoId {
    for (var i = index + 1; i < items.length; i++) {
      if (items[i].mediaType == Poc04MediaType.video) {
        return items[i].assetId;
      }
    }
    return null;
  }

  Future<void> onPageChanged(int newIndex) {
    final run = _pageChain.then((_) => _onPageChangedImpl(newIndex));
    _pageChain = run.catchError((_) {});
    return run;
  }

  Future<void> _onPageChangedImpl(int newIndex) async {
    if (items.isEmpty) return;
    final epoch = ++_pageEpoch;
    index = newIndex.clamp(0, items.length - 1);

    final keepImageIds = <String>{};
    for (final offset in [-1, 0, 1]) {
      final i = index + offset;
      if (i < 0 || i >= items.length) continue;
      if (items[i].mediaType == Poc04MediaType.image) {
        keepImageIds.add(items[i].assetId);
      }
    }

    final toRelease = <String>[];
    imagePaths.forEach((assetId, path) {
      if (!keepImageIds.contains(assetId)) {
        toRelease.add(assetId);
      }
    });
    for (final assetId in toRelease) {
      final path = imagePaths.remove(assetId);
      if (path != null) {
        await _bridge.releaseImageTempFile(path);
        _releaseLog.add(path);
      }
    }
    if (epoch != _pageEpoch) return;

    final current = items[index];
    final activeVideo = activeVideoId;
    final warmVideo = warmingVideoId;

    if (activeVideo == null) {
      await _bridge.releaseAllVideos();
      activeTextureId = -1;
    } else {
      _attachActiveLog.add(activeVideo);
      // Ordering: await returns only after native register (Texture) or -1 (PV).
      activeTextureId = await _bridge.attachActiveVideo(activeVideo);
      await _bridge.playActive();
      for (final item in items) {
        if (item.mediaType != Poc04MediaType.video) continue;
        final id = item.assetId;
        if (id != activeVideo && id != warmVideo) {
          await _bridge.releaseVideo(id);
        }
      }
    }
    if (epoch != _pageEpoch) return;

    if (warmVideo != null && warmVideo != activeVideo) {
      _attachWarmLog.add(warmVideo);
      await _bridge.attachWarmingVideo(warmVideo);
    }
    if (epoch != _pageEpoch) return;

    if (activeVideo != null) {
      await _bridge.syncPlanPosition(activeVideo, index);
    }

    if (current.mediaType == Poc04MediaType.image) {
      if (!imagePaths.containsKey(current.assetId)) {
        final path = await _bridge.resolveImageTempFile(
          current.assetId,
          maxLongEdge,
        );
        if (epoch != _pageEpoch) {
          await _bridge.releaseImageTempFile(path);
          _releaseLog.add(path);
          return;
        }
        imagePaths[current.assetId] = path;
      }
    }

    final neighborIds = <String>[];
    for (final offset in [1, 2]) {
      final i = index + offset;
      if (i >= 0 && i < items.length) {
        neighborIds.add(items[i].assetId);
      }
    }
    if (neighborIds.isNotEmpty) {
      await _bridge.prefetchNeighbors(neighborIds);
    }
    if (epoch != _pageEpoch) return;

    while (imagePaths.length > tempSoftCap) {
      final dropId = imagePaths.keys.firstWhere(
        (id) => !keepImageIds.contains(id),
        orElse: () => imagePaths.keys.first,
      );
      if (keepImageIds.contains(dropId) &&
          imagePaths.length <= keepImageIds.length) {
        break;
      }
      final path = imagePaths.remove(dropId);
      if (path != null) {
        await _bridge.releaseImageTempFile(path);
        _releaseLog.add(path);
      } else {
        break;
      }
    }
  }

  Future<void> dispose() async {
    await _bridge.releaseAllVideos();
    await _bridge.releaseAllImageTempFiles();
    imagePaths.clear();
  }

  /// Asserts pool invariants using host diagnostics (device probe / tests).
  static bool poolWithinCap(Poc04PoolDiagnostics d) {
    return d.activeCount <= 1 &&
        d.warmingCount <= 1 &&
        (d.activeCount + d.warmingCount) <= 2;
  }
}
