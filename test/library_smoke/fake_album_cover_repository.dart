import 'dart:async';
import 'dart:typed_data';

import 'package:waketok/domain/library/album_cover_repository.dart';

class FakeAlbumCoverRepository implements AlbumCoverRepository {
  FakeAlbumCoverRepository({
    this.covers = const {},
    this.favoritesCover,
    this.hangCoverRequests = false,
  });

  final Map<String, Uint8List?> covers;
  final Uint8List? favoritesCover;

  /// When true, [requestCoverThumbnail] never completes (Cap 21.5 P4 tests).
  bool hangCoverRequests;

  int requestCalls = 0;
  int favoritesRequestCalls = 0;
  String? lastAlbumId;
  int? lastTargetSizePx;
  int? lastFavoritesTargetSizePx;

  @override
  Future<Uint8List?> requestCoverThumbnail(
    String albumIdentifier, {
    required int targetSizePx,
  }) async {
    requestCalls += 1;
    lastAlbumId = albumIdentifier;
    lastTargetSizePx = targetSizePx;
    if (hangCoverRequests) {
      return Completer<Uint8List?>().future;
    }
    return covers[albumIdentifier];
  }

  @override
  Future<Uint8List?> requestFavoritesSmartAlbumCoverThumbnail({
    required int targetSizePx,
  }) async {
    favoritesRequestCalls += 1;
    lastFavoritesTargetSizePx = targetSizePx;
    return favoritesCover;
  }
}
