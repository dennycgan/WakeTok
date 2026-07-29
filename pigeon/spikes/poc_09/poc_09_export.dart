/// Spike-only Current Photos Representation export API for POC-09.
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/spikes/poc_09/generated/poc_09_export.g.dart',
    swiftOut: 'ios/Runner/Spikes/POC09/Poc09Export.g.swift',
    dartPackageName: 'waketok',
    swiftOptions: SwiftOptions(
      errorClassName: 'Poc09PigeonError',
    ),
  ),
)
enum Poc09AuthStatus {
  notDetermined,
  authorized,
  limited,
  denied,
  restricted,
}

class Poc09VideoAssetDto {
  Poc09VideoAssetDto({
    required this.assetId,
    required this.durationSeconds,
    required this.isHighFrameRate,
    this.pixelWidth,
    this.pixelHeight,
  });

  String assetId;
  double durationSeconds;
  bool isHighFrameRate;
  int? pixelWidth;
  int? pixelHeight;
}

/// Dual probe + optional export of the **current** representation (Q1=A).
class Poc09ProbeResultDto {
  Poc09ProbeResultDto({
    required this.assetId,
    required this.phAssetDurationSec,
    required this.isHighFrameRate,
    required this.networkAccessAllowed,
    required this.audioTrackCount,
    required this.textTrackCount,
    this.currentAvDurationSec,
    this.originalAvDurationSec,
    this.exportDurationSec,
    this.exportPath,
    this.errorCode,
    this.errorMessage,
  });

  String assetId;
  double phAssetDurationSec;
  bool isHighFrameRate;
  bool networkAccessAllowed;

  double? currentAvDurationSec;
  double? originalAvDurationSec;
  double? exportDurationSec;
  String? exportPath;

  int audioTrackCount;
  int textTrackCount;

  String? errorCode;
  String? errorMessage;
}

@HostApi()
abstract class Poc09ExportApi {
  @async
  Poc09AuthStatus requestAuthorization();

  Poc09AuthStatus getAuthorizationStatus();

  /// Device-local video PHAssets only (Q7=A for gate fixtures).
  List<Poc09VideoAssetDto> listLocalVideos(int limit);

  /// Videos that are not device-local (9.6 F5 / iCloud-only candidates).
  List<Poc09VideoAssetDto> listCloudOnlyVideos(int limit);

  /// Probe `.current` vs `.original`, then export **current** to a temp file.
  @async
  Poc09ProbeResultDto probeAndExport(String assetId, bool networkAccessAllowed);

  /// Play a previously exported temp file (9.4 A3 — listen to export, not Photos).
  void playExport(String path);

  /// Stop export preview playback.
  void stopExportPlayback();

  /// Delete spike export temp files under the app temp directory.
  void clearExportCache();
}
