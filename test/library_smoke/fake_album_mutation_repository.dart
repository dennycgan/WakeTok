import 'package:waketok/domain/library/album_mutation_repository.dart';

class FakeAlbumMutationRepository implements AlbumMutationRepository {
  int createAlbumCalls = 0;
  String? lastCreateName;
  String createdAlbumId = 'fake-album-id';

  @override
  Future<void> addAssetToAlbum(
    String assetIdentifier,
    String albumIdentifier,
  ) async {}

  @override
  Future<String> createAlbum(String name) async {
    createAlbumCalls += 1;
    lastCreateName = name;
    return createdAlbumId;
  }
}
