/// Spike-only Photos library API for POC-04.
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
