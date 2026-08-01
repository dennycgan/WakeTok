import 'package:waketok/domain/library/library_asset.dart';

/// One page of catalog assets plus an opaque resume cursor.
class LibraryPage {
  const LibraryPage({
    required this.assets,
    this.nextCursor,
  });

  final List<LibraryAsset> assets;

  /// Opaque host token; null when there is no further page.
  final String? nextCursor;
}
