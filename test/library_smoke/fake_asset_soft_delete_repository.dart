import 'package:waketok/domain/library/asset_soft_delete_repository.dart';

/// Test double for Cap 24 soft-delete (mirrors [FakeAssetFavoriteRepository]).
class FakeAssetSoftDeleteRepository implements AssetSoftDeleteRepository {
  int callCount = 0;
  String? lastAssetId;
  Exception? exception;

  @override
  Future<void> softDeleteAsset(String assetIdentifier) async {
    callCount += 1;
    lastAssetId = assetIdentifier;
    final thrown = exception;
    if (thrown != null) {
      throw thrown;
    }
  }
}
