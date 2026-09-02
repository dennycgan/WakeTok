import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/album_cover_repository.dart';

/// Bound at composition root to [PhotoLibraryGateway] (Cap 19.5).
final albumCoverRepositoryProvider = Provider<AlbumCoverRepository>(
  (ref) => throw UnimplementedError(
    'albumCoverRepositoryProvider must be overridden at the composition root',
  ),
);
