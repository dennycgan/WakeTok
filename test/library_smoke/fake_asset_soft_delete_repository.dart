import 'dart:async';

import 'package:waketok/domain/library/asset_soft_delete_repository.dart';

/// Test double for Cap 24 soft-delete (mirrors [FakeAssetFavoriteRepository]).
class FakeAssetSoftDeleteRepository implements AssetSoftDeleteRepository {
  int callCount = 0;
  String? lastAssetId;
  Exception? exception;

  /// When set, [softDeleteAsset] awaits this before applying [exception].
  Completer<void>? hold;

  @override
  Future<void> softDeleteAsset(String assetIdentifier) async {
    callCount += 1;
    lastAssetId = assetIdentifier;
    final gate = hold;
    if (gate != null) {
      await gate.future;
    }
    final thrown = exception;
    if (thrown != null) {
      throw thrown;
    }
  }
}
