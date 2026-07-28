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

  /// Occupy the active player slot (releases previous active if needed).
  @async
  void attachActiveVideo(String assetId);

  /// Occupy the warming slot (does not play). Hard-capped with active at 2.
  @async
  void attachWarmingVideo(String assetId);

  void playActive();

  void pauseActive();

  void releaseVideo(String assetId);

  void releaseAllVideos();

  Poc04PoolDiagnostics getPoolDiagnostics();
}
