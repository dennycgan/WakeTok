import 'package:waketok/domain/library/album_mutation_repository.dart';

class FakeAlbumMutationRepository implements AlbumMutationRepository {
  @override
  Future<void> addAssetToAlbum(
    String assetIdentifier,
    String albumIdentifier,
  ) async {}

  @override
  Future<String> createAlbum(String name) async => 'fake-album-id';
}
