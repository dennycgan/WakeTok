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

  Future<void> attachActiveVideo(String assetId);

  Future<void> attachWarmingVideo(String assetId);

  Future<void> playActive();

  Future<void> pauseActive();

  Future<void> releaseVideo(String assetId);

  Future<void> releaseAllVideos();

  Future<Poc04PoolDiagnostics> getPoolDiagnostics();
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
  Future<void> attachActiveVideo(String assetId) =>
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
  final Map<String, String> imagePaths = {};
  final List<String> _releaseLog = [];
  final List<String> _attachActiveLog = [];
  final List<String> _attachWarmLog = [];

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

  Future<void> onPageChanged(int newIndex) async {
    if (items.isEmpty) return;
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

    final current = items[index];
    final activeVideo = activeVideoId;
    final warmVideo = warmingVideoId;

    if (activeVideo == null) {
      await _bridge.releaseAllVideos();
    } else {
      _attachActiveLog.add(activeVideo);
      await _bridge.attachActiveVideo(activeVideo);
      await _bridge.playActive();
      // Release any video that is neither active nor warm.
      for (final item in items) {
        if (item.mediaType != Poc04MediaType.video) continue;
        final id = item.assetId;
        if (id != activeVideo && id != warmVideo) {
          await _bridge.releaseVideo(id);
        }
      }
    }

    if (warmVideo != null && warmVideo != activeVideo) {
      _attachWarmLog.add(warmVideo);
      await _bridge.attachWarmingVideo(warmVideo);
    }

    if (current.mediaType == Poc04MediaType.image) {
      if (!imagePaths.containsKey(current.assetId)) {
        final path = await _bridge.resolveImageTempFile(
          current.assetId,
          maxLongEdge,
        );
        imagePaths[current.assetId] = path;
      }
    }

    // Prefetch neighbor ids (images + videos) for CachingImageManager / readiness.
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

    // Soft-trim oldest temps if over soft cap.
    while (imagePaths.length > tempSoftCap) {
      final oldest = imagePaths.keys.first;
      if (keepImageIds.contains(oldest) && imagePaths.length <= keepImageIds.length) {
        break;
      }
      final path = imagePaths.remove(oldest);
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
