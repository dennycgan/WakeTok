import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/saved_pool_repository.dart';

/// Bound at composition root to [DriftSavedPoolRepository] (Cap 22.2).
final savedPoolRepositoryProvider = Provider<SavedPoolRepository>(
  (ref) => throw UnimplementedError(
    'savedPoolRepositoryProvider must be overridden at the composition root',
  ),
);

/// Cached `loadAll` for Saved chrome (invalidate / [refresh] after mutations).
final savedPoolRecordsProvider =
    AsyncNotifierProvider<SavedPoolRecordsNotifier, List<SavedPoolRecord>>(
      SavedPoolRecordsNotifier.new,
    );

class SavedPoolRecordsNotifier extends AsyncNotifier<List<SavedPoolRecord>> {
  @override
  Future<List<SavedPoolRecord>> build() {
    return ref.read(savedPoolRepositoryProvider).loadAll();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(savedPoolRepositoryProvider).loadAll(),
    );
  }
}
