import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/asset_soft_delete_repository.dart';

/// Bound at composition root to [PhotoLibraryGateway] (Cap 24.2).
final assetSoftDeleteRepositoryProvider = Provider<AssetSoftDeleteRepository>(
  (ref) => throw UnimplementedError(
    'assetSoftDeleteRepositoryProvider must be overridden at the composition root',
  ),
);
