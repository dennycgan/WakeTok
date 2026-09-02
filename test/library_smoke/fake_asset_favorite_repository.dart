import 'package:waketok/domain/library/asset_favorite_repository.dart';

class FakeAssetFavoriteRepository implements AssetFavoriteRepository {
  int statusCalls = 0;
  int setCalls = 0;
  String? lastAssetId;
  bool? lastFavorite;
  bool statusValue = false;
  Exception? statusException;
  Exception? setException;

  @override
  Future<bool> requestFavoriteStatus(String assetIdentifier) async {
    statusCalls += 1;
    lastAssetId = assetIdentifier;
    final thrown = statusException;
    if (thrown != null) {
      throw thrown;
    }
    return statusValue;
  }

  @override
  Future<void> setFavorite(
    String assetIdentifier, {
    required bool favorite,
  }) async {
    setCalls += 1;
    lastAssetId = assetIdentifier;
    lastFavorite = favorite;
    final thrown = setException;
    if (thrown != null) {
      throw thrown;
    }
    statusValue = favorite;
  }
}
