import 'package:waketok/core/errors/app_error.dart';

/// Cap 9 Live Photo motion intents (ADR-019). Errors: sync throws on channel;
/// async failures arrive on [failedEvents].
abstract class LivePhotoRepository {
  /// Starts a PHLivePhoto request. Sync-detectable failures throw a platform
  /// channel error (code = ErrorCode name). Do not also expect [failedEvents]
  /// for the same call.
  Future<void> requestLivePhoto(String assetIdentifier);

  Future<void> cancel(String assetIdentifier);

  /// Full motion once after ready + surface (Dart-driven; Cap 9 D2=A).
  Future<void> startPlayback();

  Future<void> stopPlayback();

  Future<void> setMute(bool muted);

  Future<void> notifyLiveSurfaceReady(String assetIdentifier);

  Stream<LivePhotoReadyEvent> get readyEvents;

  Stream<LivePhotoFailedEvent> get failedEvents;

  Stream<LivePhotoPlaybackEndedEvent> get playbackEndedEvents;
}

final class LivePhotoReadyEvent {
  const LivePhotoReadyEvent({required this.assetIdentifier});

  final String assetIdentifier;
}

final class LivePhotoFailedEvent {
  const LivePhotoFailedEvent({
    required this.assetIdentifier,
    required this.error,
  });

  final String assetIdentifier;
  final AppError error;
}

final class LivePhotoPlaybackEndedEvent {
  const LivePhotoPlaybackEndedEvent({required this.assetIdentifier});

  final String assetIdentifier;
}
