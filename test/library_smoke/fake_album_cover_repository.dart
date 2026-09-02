import 'dart:typed_data';

import 'package:waketok/domain/library/album_cover_repository.dart';

class FakeAlbumCoverRepository implements AlbumCoverRepository {
  FakeAlbumCoverRepository({this.covers = const {}});

  final Map<String, Uint8List?> covers;
  int requestCalls = 0;
  String? lastAlbumId;
  int? lastTargetSizePx;

  @override
  Future<Uint8List?> requestCoverThumbnail(
    String albumIdentifier, {
    required int targetSizePx,
  }) async {
    requestCalls += 1;
    lastAlbumId = albumIdentifier;
    lastTargetSizePx = targetSizePx;
    return covers[albumIdentifier];
  }
}
