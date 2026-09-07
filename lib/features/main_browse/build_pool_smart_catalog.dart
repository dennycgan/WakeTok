import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/smart_album_boundary.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';

/// Cap 21.4b: whitelist ∩ non-empty smart albums, product-sorted.
///
/// Independent of the user-album list path so Build can show albums while
/// this Future is still loading.
final buildPoolSmartCatalogProvider =
    FutureProvider<List<AssetSource>>((ref) async {
  final sources = await ref.watch(assetSourcesProvider.future);
  final candidates = <AssetSource>[
    for (final source in sources)
      if (source.kind == AssetSourceKind.smartAlbum &&
          source.collectionSubtype != null &&
          SmartAlbumBoundary.isWhitelisted(source.collectionSubtype!))
        source,
  ];
  if (candidates.isEmpty) {
    return const [];
  }
  final ids = [for (final source in candidates) source.id];
  final nonEmpty = await ref
      .read(assetSourceRepositoryProvider)
      .smartAlbumsWithContent(ids);
  final allow = nonEmpty.toSet();
  final visible = <AssetSource>[
    for (final source in candidates)
      if (allow.contains(source.id)) source,
  ];
  return SmartAlbumBoundary.sortForDisplay(
    visible,
    subtypeOf: (source) => source.collectionSubtype!,
  );
});
