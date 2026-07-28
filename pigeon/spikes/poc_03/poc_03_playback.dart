/// Spike-only background playback API for POC-03.
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/spikes/poc_03/generated/poc_03_playback.g.dart',
    swiftOut: 'ios/Runner/Spikes/POC03/Poc03Playback.g.swift',
    dartPackageName: 'waketok',
    swiftOptions: SwiftOptions(
      // Avoid colliding with POC-04 generated `PigeonError`.
      errorClassName: 'Poc03PigeonError',
    ),
  ),
)
class Poc03PlaybackStateDto {
  Poc03PlaybackStateDto({
    required this.isPlaying,
    required this.currentIndex,
    required this.queueLength,
    required this.positionMs,
    required this.currentClipId,
  });

  bool isPlaying;
  int currentIndex;
  int queueLength;
  int positionMs;
  String currentClipId;
}

@HostApi()
abstract class Poc03PlaybackApi {
  /// Load bundled clip fixtures into AVQueuePlayer (P1=A). Does not start playback.
  void configureBundleQueue();

  void play();

  void pause();

  /// Stops playback and clears the queue engine state (explicit stop only).
  void stop();

  /// Current native playback state (survives Flutter route dispose).
  Poc03PlaybackStateDto getPlaybackState();

  /// Ids of bundled clips in queue order (for HUD / tests).
  List<String> listBundleClipIds();

  /// Clear clip-boundary gap samples (P3=B foreground probe).
  void clearGapSamples();

  /// Gap ms from AVPlayerItem end → next currentItem (P3=B).
  List<double> getGapSamplesMs();
}
