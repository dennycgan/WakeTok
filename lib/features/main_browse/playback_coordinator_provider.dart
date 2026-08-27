import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/main_browse/playback_coordinator.dart';

/// Feature-owned coordinator (ADR-040). Bound at composition root via playback repo.
final playbackCoordinatorProvider = Provider<PlaybackCoordinator>((ref) {
  return PlaybackCoordinator(playback: ref.watch(playbackRepositoryProvider));
});
