import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/album_mutation_repository.dart';

/// Bound at composition root to [PhotoLibraryGateway] (Cap 19.2a probe).
final albumMutationRepositoryProvider = Provider<AlbumMutationRepository>(
  (ref) => throw UnimplementedError(
    'albumMutationRepositoryProvider must be overridden at the composition root',
  ),
);
