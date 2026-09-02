import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';

/// Writable User Albums for Cap 19.5 Add-to-Album picker (kickoff §14).
List<AssetSource> filterAndSortWritableUserAlbums(List<AssetSource> sources) {
  final writable = sources
      .where(
        (source) =>
            source.kind == AssetSourceKind.album && source.canAddContent,
      )
      .toList();
  writable.sort((a, b) => a.displayName.compareTo(b.displayName));
  return writable;
}
