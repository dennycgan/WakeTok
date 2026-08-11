import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_repository.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Overridden at the composition root with [PhotoLibraryGateway].
final assetSourceRepositoryProvider = Provider<AssetSourceRepository>((ref) {
  throw StateError(
    'assetSourceRepositoryProvider must be overridden at '
    'the composition root (lib/main.dart / lib/app)',
  );
});

/// Cap 11.2: full `listAssetSources` (built-ins + albums when Full Access).
final assetSourcesProvider = FutureProvider<List<AssetSource>>((ref) {
  return ref.watch(assetSourceRepositoryProvider).listAssetSources();
});

/// Resolves a built-in source to the full ordered id list (D1=A / ~40k ok).
///
/// Prefer invalidate over long-lived watch when the list is only needed briefly.
final resolveBuiltInSourceProvider =
    FutureProvider.family<ResolvedSource, SourceReference>((ref, reference) {
  return ref.watch(assetSourceRepositoryProvider).resolve(reference);
});
