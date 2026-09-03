import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/library_smoke/asset_favorite_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

enum Cap19FavoritesPhase {
  loading,
  mediaNotReady,
  loaded,
  loadError,
  toggling,
}


class Cap19FavoritesState {
  const Cap19FavoritesState({
    this.phase = Cap19FavoritesPhase.loading,
    this.isFavorite = false,
  });

  final Cap19FavoritesPhase phase;
  final bool isFavorite;

  Cap19FavoritesState copyWith({
    Cap19FavoritesPhase? phase,
    bool? isFavorite,
  }) {
    return Cap19FavoritesState(
      phase: phase ?? this.phase,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

final cap19FavoritesProvider =
    NotifierProvider<Cap19FavoritesNotifier, Cap19FavoritesState>(
      Cap19FavoritesNotifier.new,
    );

class Cap19FavoritesNotifier extends Notifier<Cap19FavoritesState> {
  @override
  Cap19FavoritesState build() => const Cap19FavoritesState();

  Future<void> loadStatus() async {
    state = const Cap19FavoritesState();
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      state = const Cap19FavoritesState(phase: Cap19FavoritesPhase.mediaNotReady);
      return;
    }
    try {
      final isFavorite = await ref
          .read(assetFavoriteRepositoryProvider)
          .requestFavoriteStatus(assetId);
      state = Cap19FavoritesState(
        phase: Cap19FavoritesPhase.loaded,
        isFavorite: isFavorite,
      );
    } catch (_) {
      state = const Cap19FavoritesState(phase: Cap19FavoritesPhase.loadError);
    }
  }

  /// Returns `true` when toggle succeeds. Does not touch Session/Snapshot.
  Future<bool> toggleFavorite() async {
    if (state.phase != Cap19FavoritesPhase.loaded) {
      return false;
    }
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      return false;
    }
    final previousFavorite = state.isFavorite;
    final targetFavorite = !previousFavorite;
    state = state.copyWith(phase: Cap19FavoritesPhase.toggling);
    try {
      await ref.read(assetFavoriteRepositoryProvider).setFavorite(
            assetId,
            favorite: targetFavorite,
          );
      state = Cap19FavoritesState(
        phase: Cap19FavoritesPhase.loaded,
        isFavorite: targetFavorite,
      );
      return true;
    } on PlatformException {
      state = Cap19FavoritesState(
        phase: Cap19FavoritesPhase.loaded,
        isFavorite: previousFavorite,
      );
      return false;
    } catch (_) {
      state = Cap19FavoritesState(
        phase: Cap19FavoritesPhase.loaded,
        isFavorite: previousFavorite,
      );
      return false;
    }
  }
}
