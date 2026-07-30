/// Spike-only Photos + media bridge APIs for POC-04.
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/spikes/poc_04/generated/poc_04_photo_library.g.dart',
    swiftOut: 'ios/Runner/Spikes/POC04/Poc04PhotoLibrary.g.swift',
    dartPackageName: 'waketok',
  ),
)
enum Poc04MediaType {
  image,
  video,
}

enum Poc04AuthStatus {
  notDetermined,
  authorized,
  limited,
  denied,
  restricted,
}

class Poc04AssetDto {
  Poc04AssetDto({
    required this.assetId,
    required this.mediaType,
    this.pixelWidth,
    this.pixelHeight,
    this.durationSeconds,
  });

  String assetId;
  Poc04MediaType mediaType;
  int? pixelWidth;
  int? pixelHeight;
  double? durationSeconds;
}

class Poc04PoolDiagnostics {
  Poc04PoolDiagnostics({
    required this.activeCount,
    required this.warmingCount,
    required this.tempFileCount,
  });

  int activeCount;
  int warmingCount;
  int tempFileCount;
}

/// Video-only playback plan entry for lock-audio probe (images filtered in Dart).
class Poc04PlaybackPlanItem {
  Poc04PlaybackPlanItem({
    required this.assetId,
    required this.feedIndex,
  });

  String assetId;
  int feedIndex;
}

/// HUD / diagnostics for the lock-screen feed audio probe.
class Poc04LockProbeState {
  Poc04LockProbeState({
    required this.enabled,
    required this.layerDetached,
    required this.playing,
    required this.planIndex,
    required this.feedIndex,
    this.activeAssetId,
    this.lastEvent,
  });

  bool enabled;
  bool layerDetached;
  bool playing;
  /// Index into the video-only plan; -1 if unset.
  int planIndex;
  int feedIndex;
  String? activeAssetId;
  String? lastEvent;
}

@HostApi()
abstract class Poc04PhotoLibraryApi {
  /// Requests Photos read access (may show the system dialog).
  @async
  Poc04AuthStatus requestAuthorization();

  /// Current authorization without prompting.
  Poc04AuthStatus getAuthorizationStatus();

  /// Lists device-local image/video PHAssets only (skips iCloud-only).
  List<Poc04AssetDto> listLocalMixedAssets(int limit);
}

@HostApi()
abstract class Poc04MediaBridgeApi {
  /// Export a display image to a temp file (longest edge capped). Returns path.
  @async
  String resolveImageTempFile(String assetId, int maxLongEdge);

  void releaseImageTempFile(String path);

  void releaseAllImageTempFiles();

  /// Best-effort PHCachingImageManager prefetch for neighbor asset IDs.
  void prefetchNeighbors(List<String> assetIds);

  /// Prefer Texture surface when true; Platform View when false (T1=B).
  void setUseTextureSurface(bool enabled);

  /// Occupy the active player slot.
  ///
  /// Texture mode: returns textureId only AFTER FlutterTextureRegistry.register.
  /// Platform View mode: returns -1 (no texture).
  @async
  int attachActiveVideo(String assetId);

  /// Occupy the warming slot (does not play). Hard-capped with active at 2.
  /// Warming does not register a Flutter texture (T2=A).
  @async
  void attachWarmingVideo(String assetId);

  void playActive();

  void pauseActive();

  void releaseVideo(String assetId);

  void releaseAllVideos();

  Poc04PoolDiagnostics getPoolDiagnostics();

  /// Clears accumulated first-frame samples (ms).
  void clearFirstFrameSamples();

  /// Accumulated first-frame delays (ms) since last clear.
  List<double> getFirstFrameSamples();

  /// Waits until active AVPlayerLayer is ready for display since last attach,
  /// or until timeoutMs (timeout value is still recorded — H4=A).
  @async
  double waitActiveFirstFrameMs(int timeoutMs);

  /// Enables lock-screen feed audio probe (unmute + session + lifecycle).
  /// Completes only after active player is AVQueuePlayer and next item is enqueued.
  @async
  void setLockAudioProbeEnabled(bool enabled);

  /// Video-only plan (assetId + feed index). Images must be filtered in Dart.
  void setPlaybackPlan(List<Poc04PlaybackPlanItem> items);

  /// Sync plan cursor after foreground user scroll (asset must be in plan).
  void syncPlanPosition(String assetId, int feedIndex);

  /// After jumpToPage + Platform View created: adopt existing player onto layer.
  void notifyPlatformViewReady(String assetId);

  Poc04LockProbeState getLockProbeState();
}

/// Native → Dart events for lock-audio probe restore / plan end.
@FlutterApi()
abstract class Poc04LockProbeFlutterApi {
  /// willEnterForeground: Dart must jumpToPage(feedIndex) then notify ready.
  void onLockProbeForeground(int feedIndex, String assetId);

  /// Plan exhausted after background advance; playback stopped at last item.
  void onLockProbePlanEnded(int feedIndex, String assetId);
}
