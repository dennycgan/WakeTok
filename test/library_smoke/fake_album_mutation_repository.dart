import 'package:waketok/domain/library/album_mutation_repository.dart';

class FakeAlbumMutationRepository implements AlbumMutationRepository {
  int createAlbumCalls = 0;
  int addCalls = 0;
  String? lastCreateName;
  String? lastAssetId;
  String? lastAlbumId;
  String createdAlbumId = 'fake-album-id';
  Exception? addException;

  @override
  Future<void> addAssetToAlbum(
    String assetIdentifier,
    String albumIdentifier,
  ) async {
    addCalls += 1;
    lastAssetId = assetIdentifier;
    lastAlbumId = albumIdentifier;
    final thrown = addException;
    if (thrown != null) {
      throw thrown;
    }
  }

  int containsCalls = 0;
  final Set<String> containedAssetIds = <String>{};

  @override
  Future<bool> albumContainsAsset(
    String albumIdentifier,
    String assetIdentifier,
  ) async {
    containsCalls += 1;
    lastAlbumId = albumIdentifier;
    return containedAssetIds.contains(assetIdentifier);
  }

  @override
  Future<String> createAlbum(String name) async {
    createAlbumCalls += 1;
    lastCreateName = name;
    return createdAlbumId;
  }
}
