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
    required this.isInterrupted,
    required this.interruptionCount,
    required this.lastInterruptionSummary,
    required this.lastRemoteCommand,
  });

  bool isPlaying;
  int currentIndex;
  int queueLength;
  int positionMs;
  String currentClipId;

  /// True while an AVAudioSession interruption is active (3.3).
  bool isInterrupted;

  /// Count of interruption began/ended events observed this process.
  int interruptionCount;

  /// Last interruption note for HUD (e.g. ended shouldResume → auto play).
  String lastInterruptionSummary;

  /// Last Control Center / headphone remote command (3.4), e.g. play / next.
  String lastRemoteCommand;
}

/// Spike SessionCheckpoint for cold-start Restore? (P5=A / phase 3.5).
class Poc03SessionCheckpointDto {
  Poc03SessionCheckpointDto({
    required this.clipId,
    required this.positionMs,
    required this.currentIndex,
    required this.wasPlaying,
    required this.savedAtEpochMs,
  });

  String clipId;
  int positionMs;
  int currentIndex;
  bool wasPlaying;
  int savedAtEpochMs;
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

  /// Pending disk checkpoint after process kill (null if none / already configured).
  Poc03SessionCheckpointDto? getPendingCheckpoint();

  /// P5=A: user confirmed Restore — seek + play (does not auto-run on launch).
  void restoreFromCheckpoint();

  /// User dismissed Restore? — clear disk checkpoint without playing.
  void dismissCheckpoint();
}
