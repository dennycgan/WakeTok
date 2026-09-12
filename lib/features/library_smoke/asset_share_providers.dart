import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/asset_share_repository.dart';

/// Bound at composition root to [PhotoLibraryGateway] (Cap 25.2).
final assetShareRepositoryProvider = Provider<AssetShareRepository>(
  (ref) => throw UnimplementedError(
    'assetShareRepositoryProvider must be overridden at the composition root',
  ),
);
