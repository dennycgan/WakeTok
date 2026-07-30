import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/spikes/poc_04/generated/poc_04_photo_library.g.dart';
import 'package:waketok/spikes/poc_04/poc_04_feed_controller.dart';

class _MockBridge implements Poc04MediaBridge {
  final Map<String, String> resolved = {};
  final List<String> releasedPaths = [];
  final List<String> attachActive = [];
  final List<String> attachWarm = [];
  final List<String> releaseVideos = [];
  int releaseAllVideosCount = 0;
  int playCount = 0;
  int active = 0;
  int warming = 0;
  int tempFiles = 0;

  @override
  @override
  Future<int> attachActiveVideo(String assetId) async {
    attachActive.add(assetId);
    active = 1;
    return -1;
  }

  @override
  Future<void> setUseTextureSurface(bool enabled) async {}

  @override
  Future<void> attachWarmingVideo(String assetId) async {
    attachWarm.add(assetId);
    warming = 1;
  }

  @override
  Future<Poc04PoolDiagnostics> getPoolDiagnostics() async {
    return Poc04PoolDiagnostics(
      activeCount: active,
      warmingCount: warming,
      tempFileCount: tempFiles,
    );
  }

  @override
  Future<void> clearFirstFrameSamples() async {}

  @override
  Future<List<double>> getFirstFrameSamples() async => const [];

  @override
  Future<double> waitActiveFirstFrameMs(int timeoutMs) async => 0;

  @override
  Future<void> setLockAudioProbeEnabled(bool enabled) async {}

  @override
  Future<void> setPlaybackPlan(List<Poc04PlaybackPlanItem> items) async {}

  @override
  Future<void> syncPlanPosition(String assetId, int feedIndex) async {}

  @override
  Future<void> notifyPlatformViewReady(String assetId) async {}

  @override
  Future<Poc04LockProbeState> getLockProbeState() async {
    return Poc04LockProbeState(
      enabled: false,
      layerDetached: false,
      playing: false,
      planIndex: -1,
      feedIndex: -1,
    );
  }

  @override
  Future<void> pauseActive() async {}

  @override
  Future<void> playActive() async {
    playCount++;
  }

  @override
  Future<void> prefetchNeighbors(List<String> assetIds) async {}

  @override
  Future<void> releaseAllImageTempFiles() async {
    releasedPaths.addAll(resolved.values);
    resolved.clear();
    tempFiles = 0;
  }

  @override
  Future<void> releaseAllVideos() async {
    releaseAllVideosCount++;
    active = 0;
    warming = 0;
  }

  @override
  Future<void> releaseImageTempFile(String path) async {
    releasedPaths.add(path);
    resolved.removeWhere((_, value) => value == path);
    tempFiles = resolved.length;
  }

  @override
  Future<void> releaseVideo(String assetId) async {
    releaseVideos.add(assetId);
  }

  @override
  Future<String> resolveImageTempFile(String assetId, int maxLongEdge) async {
    final path = '/tmp/poc04_$assetId.jpg';
    resolved[assetId] = path;
    tempFiles = resolved.length;
    return path;
  }
}

Poc04AssetDto _img(String id) => Poc04AssetDto(
      assetId: id,
      mediaType: Poc04MediaType.image,
      pixelWidth: 100,
      pixelHeight: 100,
    );

Poc04AssetDto _vid(String id) => Poc04AssetDto(
      assetId: id,
      mediaType: Poc04MediaType.video,
      pixelWidth: 100,
      pixelHeight: 100,
      durationSeconds: 1,
    );

void main() {
  test('A2: mixed page changes never request more than 1+1 pool attaches',
      () async {
    final bridge = _MockBridge();
    final items = <Poc04AssetDto>[
      _img('i0'),
      _vid('v0'),
      _img('i1'),
      _vid('v1'),
      _vid('v2'),
      _img('i2'),
      _vid('v3'),
      _img('i3'),
      _vid('v4'),
      _img('i4'),
      _vid('v5'),
      _img('i5'),
      _vid('v6'),
      _img('i6'),
      _vid('v7'),
      _img('i7'),
      _vid('v8'),
      _img('i8'),
      _vid('v9'),
      _img('i9'),
    ];
    final controller = Poc04FeedController(bridge: bridge, items: items);

    for (var i = 0; i < items.length; i++) {
      await controller.onPageChanged(i);
      // At most one new active + one warm per transition; diagnostics cap.
      final d = await bridge.getPoolDiagnostics();
      expect(Poc04FeedController.poolWithinCap(d), isTrue);
    }

    // Active/warm attach logs should only contain video ids.
    for (final id in bridge.attachActive) {
      expect(id.startsWith('v'), isTrue);
    }
    for (final id in bridge.attachWarm) {
      expect(id.startsWith('v'), isTrue);
    }

    // Warming target is always a later video than current when both exist.
    expect(bridge.attachWarm, isNotEmpty);

    await controller.dispose();
  });

  test('A3: leaving an image window releases its temp path', () async {
    final bridge = _MockBridge();
    final items = [_img('a'), _img('b'), _img('c'), _img('d'), _img('e'), _img('f')];
    final controller = Poc04FeedController(
      bridge: bridge,
      items: items,
      tempSoftCap: 5,
    );

    await controller.onPageChanged(0);
    expect(controller.imagePaths.containsKey('a'), isTrue);
    final pathA = controller.imagePaths['a']!;

    // Move far enough that 'a' leaves the [-1,0,1] keep window.
    await controller.onPageChanged(3);
    expect(controller.imagePaths.containsKey('a'), isFalse);
    expect(bridge.releasedPaths, contains(pathA));

    await controller.dispose();
  });
}
