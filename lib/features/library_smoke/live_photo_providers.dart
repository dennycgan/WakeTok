import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/live_photo/live_photo_repository.dart';

/// Bound at composition root ([main.dart]). Features must not construct gateways.
final livePhotoRepositoryProvider = Provider<LivePhotoRepository>((ref) {
  throw StateError(
    'livePhotoRepositoryProvider must be overridden at the composition root',
  );
});
