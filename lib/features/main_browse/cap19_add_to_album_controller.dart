import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/writable_user_albums.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/features/library_smoke/album_mutation_providers.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

enum Cap19AlbumPickerPhase { loading, loaded, empty, listError }

class Cap19AlbumPickerState {
  const Cap19AlbumPickerState({
    this.phase = Cap19AlbumPickerPhase.loading,
    this.albums = const <AssetSource>[],
    this.appendingAlbumId,
  });

  final Cap19AlbumPickerPhase phase;
  final List<AssetSource> albums;
  final String? appendingAlbumId;

  Cap19AlbumPickerState copyWith({
    Cap19AlbumPickerPhase? phase,
    List<AssetSource>? albums,
    String? appendingAlbumId,
    bool clearAppendingAlbumId = false,
  }) {
    return Cap19AlbumPickerState(
      phase: phase ?? this.phase,
      albums: albums ?? this.albums,
      appendingAlbumId:
          clearAppendingAlbumId ? null : appendingAlbumId ?? this.appendingAlbumId,
    );
  }
}

final cap19AlbumPickerProvider =
    NotifierProvider<Cap19AlbumPickerNotifier, Cap19AlbumPickerState>(
      Cap19AlbumPickerNotifier.new,
    );

class Cap19AlbumPickerNotifier extends Notifier<Cap19AlbumPickerState> {
  @override
  Cap19AlbumPickerState build() => const Cap19AlbumPickerState();

  Future<void> loadAlbums() async {
    state = const Cap19AlbumPickerState();
    try {
      final sources =
          await ref.read(assetSourceRepositoryProvider).listAssetSources();
      final albums = filterAndSortWritableUserAlbums(sources);
      if (albums.isEmpty) {
        state = const Cap19AlbumPickerState(phase: Cap19AlbumPickerPhase.empty);
        return;
      }
      state = Cap19AlbumPickerState(
        phase: Cap19AlbumPickerPhase.loaded,
        albums: albums,
      );
    } catch (_) {
      state = const Cap19AlbumPickerState(phase: Cap19AlbumPickerPhase.listError);
    }
  }

  /// Returns `true` when append succeeds. Does not touch Session/Snapshot.
  Future<bool> appendToAlbum(String albumId) async {
    final assetId = ref.read(mainBrowseCurrentAssetIdProvider);
    if (assetId == null || assetId.isEmpty) {
      return false;
    }
    state = state.copyWith(appendingAlbumId: albumId);
    try {
      await ref.read(albumMutationRepositoryProvider).addAssetToAlbum(
            assetId,
            albumId,
          );
      return true;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    } finally {
      state = state.copyWith(clearAppendingAlbumId: true);
    }
  }
}
