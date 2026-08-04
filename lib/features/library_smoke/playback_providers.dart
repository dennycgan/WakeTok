import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/playback/media_display_repository.dart';
import 'package:waketok/domain/playback/playback_repository.dart';

/// Bound at composition root ([main.dart]). Features must not construct gateways.
final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  throw StateError(
    'playbackRepositoryProvider must be overridden at the composition root',
  );
});

final mediaDisplayRepositoryProvider = Provider<MediaDisplayRepository>((ref) {
  throw StateError(
    'mediaDisplayRepositoryProvider must be overridden at the composition root',
  );
});
