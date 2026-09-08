import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/source/saved_pool_repository.dart';

/// Bound at composition root to [DriftSavedPoolRepository] (Cap 22.2).
final savedPoolRepositoryProvider = Provider<SavedPoolRepository>(
  (ref) => throw UnimplementedError(
    'savedPoolRepositoryProvider must be overridden at the composition root',
  ),
);
