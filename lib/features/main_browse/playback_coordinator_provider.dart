import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/main_browse/playback_coordinator.dart';

/// Feature-owned coordinator (ADR-040). Bound at composition root via playback
/// repo. UI listens via [ListenableBuilder] on Cap 18.4 intent changes.
final playbackCoordinatorProvider = Provider<PlaybackCoordinator>((ref) {
  final coordinator = PlaybackCoordinator(
    playback: ref.watch(playbackRepositoryProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
