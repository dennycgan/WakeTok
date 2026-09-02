import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/asset_favorite_repository.dart';

/// Bound at composition root to [PhotoLibraryGateway] (Cap 19.5b).
final assetFavoriteRepositoryProvider = Provider<AssetFavoriteRepository>(
  (ref) => throw UnimplementedError(
    'assetFavoriteRepositoryProvider must be overridden at the composition root',
  ),
);
