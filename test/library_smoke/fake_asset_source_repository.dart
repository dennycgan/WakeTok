import 'package:flutter/services.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/asset_source_repository.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';

/// Test double for [AssetSourceRepository] (Cap 6.4 / Cap 11.2–11.3 tests).
class FakeAssetSourceRepository implements AssetSourceRepository {
  FakeAssetSourceRepository({
    this.allIds = const <String>[],
    this.photosIds = const <String>[],
    this.videosIds = const <String>[],
    this.extraSources = const <AssetSource>[],
    this.albumResolveIds = const <String, List<String>>{},
    this.albumResolveUnauthorized = false,
    this.resolveException,
  });

  List<String> allIds;
  List<String> photosIds;
  List<String> videosIds;

  /// Appended after the three built-ins (Cap 11.2 list diagnostic tests).
  List<AssetSource> extraSources;

  /// Cap 11.3: id → ordered asset ids for album/smartAlbum resolve.
  Map<String, List<String>> albumResolveIds;

  /// When true, album/smartAlbum resolve throws [AppError.unauthorized].
  bool albumResolveUnauthorized;

  /// When set, [resolve] throws after recording history (Cap 11.5 W-P3).
  Exception? resolveException;

  int listCalls = 0;
  int resolveCalls = 0;
  SourceReference? lastResolve;
  final List<SourceReference> resolveHistory = <SourceReference>[];

  @override
  Future<List<AssetSource>> listAssetSources() async {
    listCalls += 1;
    return [
      AssetSource(
        kind: AssetSourceKind.entireLibrary,
        id: 'all',
        displayName: '',
        estimatedCount: allIds.length,
        availability: allIds.isEmpty
            ? AssetSourceAvailability.empty
            : AssetSourceAvailability.available,
        canAddContent: false,
      ),
      AssetSource(
        kind: AssetSourceKind.mediaTypePhotos,
        id: 'photos',
        displayName: '',
        estimatedCount: photosIds.length,
        availability: photosIds.isEmpty
            ? AssetSourceAvailability.empty
            : AssetSourceAvailability.available,
        canAddContent: false,
      ),
      AssetSource(
        kind: AssetSourceKind.mediaTypeVideos,
        id: 'videos',
        displayName: '',
        estimatedCount: videosIds.length,
        availability: videosIds.isEmpty
            ? AssetSourceAvailability.empty
            : AssetSourceAvailability.available,
        canAddContent: false,
      ),
      ...extraSources,
    ];
  }

  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    resolveCalls += 1;
    lastResolve = reference;
    resolveHistory.add(reference);

    final thrown = resolveException;
    if (thrown != null) {
      throw thrown;
    }

    if (reference.kind == AssetSourceKind.album ||
        reference.kind == AssetSourceKind.smartAlbum) {
      if (albumResolveUnauthorized) {
        throw PlatformException(code: AppError.unauthorized.name);
      }
      final ids = albumResolveIds[reference.id] ?? const <String>[];
      return ResolvedSource(
        sourceId: reference.id,
        assetIdentifiers: List<String>.unmodifiable(ids),
      );
    }

    if (!reference.isLegalBuiltInPair) {
      throw PlatformException(code: AppError.assetUnavailable.name);
    }
    final ids = switch (reference.kind) {
      AssetSourceKind.entireLibrary => allIds,
      AssetSourceKind.mediaTypePhotos => photosIds,
      AssetSourceKind.mediaTypeVideos => videosIds,
      AssetSourceKind.album || AssetSourceKind.smartAlbum =>
        throw StateError('unreachable after album branch'),
    };
    return ResolvedSource(
      sourceId: reference.id,
      assetIdentifiers: List<String>.unmodifiable(ids),
    );
  }
}
