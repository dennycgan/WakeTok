import 'package:flutter/services.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/asset_source_repository.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Test double for [AssetSourceRepository] (Cap 6.4 widget / provider tests).
class FakeAssetSourceRepository implements AssetSourceRepository {
  FakeAssetSourceRepository({
    this.allIds = const <String>[],
    this.photosIds = const <String>[],
    this.videosIds = const <String>[],
  });

  List<String> allIds;
  List<String> photosIds;
  List<String> videosIds;
  int listCalls = 0;
  int resolveCalls = 0;
  SourceReference? lastResolve;

  @override
  Future<List<AssetSource>> listBuiltInSources() async {
    listCalls += 1;
    return [
      AssetSource(
        kind: AssetSourceKind.entireLibrary,
        id: 'all',
        estimatedCount: allIds.length,
        availability: allIds.isEmpty
            ? AssetSourceAvailability.empty
            : AssetSourceAvailability.available,
        canAddContent: false,
      ),
      AssetSource(
        kind: AssetSourceKind.mediaTypePhotos,
        id: 'photos',
        estimatedCount: photosIds.length,
        availability: photosIds.isEmpty
            ? AssetSourceAvailability.empty
            : AssetSourceAvailability.available,
        canAddContent: false,
      ),
      AssetSource(
        kind: AssetSourceKind.mediaTypeVideos,
        id: 'videos',
        estimatedCount: videosIds.length,
        availability: videosIds.isEmpty
            ? AssetSourceAvailability.empty
            : AssetSourceAvailability.available,
        canAddContent: false,
      ),
    ];
  }

  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    resolveCalls += 1;
    lastResolve = reference;
    if (!reference.isLegalBuiltInPair) {
      throw PlatformException(code: AppError.assetUnavailable.name);
    }
    final ids = switch (reference.kind) {
      AssetSourceKind.entireLibrary => allIds,
      AssetSourceKind.mediaTypePhotos => photosIds,
      AssetSourceKind.mediaTypeVideos => videosIds,
    };
    return ResolvedSource(
      sourceId: reference.id,
      assetIdentifiers: List<String>.unmodifiable(ids),
    );
  }
}
