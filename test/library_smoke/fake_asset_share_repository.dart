import 'dart:async';

import 'package:waketok/domain/library/asset_share_repository.dart';

/// Test double for Cap 25 share (mirrors [FakeAssetSoftDeleteRepository]).
class FakeAssetShareRepository implements AssetShareRepository {
  int callCount = 0;
  String? lastAssetId;
  Exception? exception;

  /// When set, [presentShareSheet] awaits this before applying [exception].
  Completer<void>? hold;

  @override
  Future<void> presentShareSheet(String assetIdentifier) async {
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

  final _dismissController = StreamController<int>.broadcast();

  @override
  Stream<int> get shareSheetDismissedAtMs => _dismissController.stream;

  /// Test helper: emit a Host-stamped dismiss.
  void emitShareSheetDismissed(int dismissedAtMs) {
    _dismissController.add(dismissedAtMs);
  }
}
