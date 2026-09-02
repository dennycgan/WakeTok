import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/album_mutation_repository.dart';
import 'package:waketok/domain/library/waketok_album_constants.dart';
import 'package:waketok/domain/library/waketok_album_store.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/asset_source_repository.dart';

enum WakeTokAlbumBootstrapSource {
  kv,
  listFind,
  create,
}

class WakeTokAlbumBootstrapResult {
  const WakeTokAlbumBootstrapResult({
    required this.albumId,
    required this.source,
  });

  final String albumId;
  final WakeTokAlbumBootstrapSource source;
}

/// D1 bootstrap: KV hit → cached id; Full miss → list find (min
/// [AssetSource.id]); Limited miss → create-only (no list).
Future<WakeTokAlbumBootstrapResult> bootstrapWakeTokAlbum({
  required PhotosAccess access,
  required WakeTokAlbumStore store,
  required AssetSourceRepository assetSources,
  required AlbumMutationRepository albumMutations,
}) async {
  final cached = await store.loadAlbumId();
  if (cached != null && cached.isNotEmpty) {
    if (access == PhotosAccess.full) {
      final sources = await assetSources.listAssetSources();
      final stillExists = sources.any(
        (source) =>
            source.kind == AssetSourceKind.album && source.id == cached,
      );
      if (stillExists) {
        return WakeTokAlbumBootstrapResult(
          albumId: cached,
          source: WakeTokAlbumBootstrapSource.kv,
        );
      }
      await store.clearAlbumId();
    } else {
      return WakeTokAlbumBootstrapResult(
        albumId: cached,
        source: WakeTokAlbumBootstrapSource.kv,
      );
    }
  }

  if (access == PhotosAccess.full) {
    final matches = (await assetSources.listAssetSources())
        .where(
          (source) =>
              source.kind == AssetSourceKind.album &&
              source.displayName == waketokAlbumTitle,
        )
        .toList();
    if (matches.isNotEmpty) {
      matches.sort((a, b) => a.id.compareTo(b.id));
      final chosen = matches.first;
      await store.saveAlbumId(chosen.id);
      return WakeTokAlbumBootstrapResult(
        albumId: chosen.id,
        source: WakeTokAlbumBootstrapSource.listFind,
      );
    }
  }

  final createdId = await albumMutations.createAlbum(waketokAlbumTitle);
  await store.saveAlbumId(createdId);
  return WakeTokAlbumBootstrapResult(
    albumId: createdId,
    source: WakeTokAlbumBootstrapSource.create,
  );
}
