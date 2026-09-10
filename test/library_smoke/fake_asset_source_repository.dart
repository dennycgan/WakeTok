import 'package:flutter/services.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/library/asset_availability.dart';
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
    this.beforeEachResolve,
    this.allIdsForCall,
    Map<String, AssetAvailability>? availabilityById,
    this.smartAlbumsWithContentIds,
  }) : availabilityById = availabilityById ?? const {};

  /// Cap 15.12: per-id list-time availability for resolve (default deviceLocal).
  final Map<String, AssetAvailability> availabilityById;

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

  /// Cap 14.6: awaited after the call is recorded, before returning/throwing.
  Future<void> Function(int callIndex)? beforeEachResolve;

  /// Cap 14.6: per-call All ids (overrides [allIds] when set).
  List<String> Function(int callIndex)? allIdsForCall;

  int listCalls = 0;
  int resolveCalls = 0;
  int getAssetAvailabilitiesCalls = 0;
  SourceReference? lastResolve;
  final List<SourceReference> resolveHistory = <SourceReference>[];
  final List<List<String>> getAssetAvailabilitiesHistory = <List<String>>[];

  /// Cap 23.2: awaited after the call is recorded, before returning.
  Future<void> Function(int callIndex)? beforeEachGetAssetAvailabilities;

  /// When set, [getAssetAvailabilities] throws after the optional before-hook.
  Exception? getAssetAvailabilitiesException;

  /// Cap 15.15: when true, [resolve] returns an empty availability map
  /// (production Host contract). Tests that need become-current probe
  /// coverage set this; default false keeps W-15.12* inject-at-resolve.
  bool resolveOmitsAvailability = false;

  /// Cap 21.4b: ids treated as non-empty for [smartAlbumsWithContent].
  /// When null, any id with a non-empty [albumResolveIds] entry is non-empty.
  Set<String>? smartAlbumsWithContentIds;

  int smartAlbumsWithContentCalls = 0;
  final List<List<String>> smartAlbumsWithContentHistory = <List<String>>[];

  /// When set, [listAssetSources] throws after incrementing [listCalls].
  Exception? listException;

  @override
  Future<List<AssetSource>> listAssetSources() async {
    listCalls += 1;
    final thrown = listException;
    if (thrown != null) {
      throw thrown;
    }
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
  Future<List<String>> smartAlbumsWithContent(
    List<String> albumIdentifiers,
  ) async {
    smartAlbumsWithContentCalls += 1;
    smartAlbumsWithContentHistory.add(
      List<String>.unmodifiable(albumIdentifiers),
    );
    final allow = smartAlbumsWithContentIds;
    return [
      for (final id in albumIdentifiers)
        if (allow != null
            ? allow.contains(id)
            : (albumResolveIds[id]?.isNotEmpty ?? false))
          id,
    ];
  }

  Map<String, AssetAvailability> _availabilityForIds(List<String> ids) {
    return {
      for (final id in ids)
        if (availabilityById.containsKey(id)) id: availabilityById[id]!,
    };
  }

  ResolvedSource _resolved(String sourceId, List<String> ids) {
    return ResolvedSource(
      sourceId: sourceId,
      assetIdentifiers: List<String>.unmodifiable(ids),
      assetAvailabilityById: resolveOmitsAvailability
          ? const {}
          : _availabilityForIds(ids),
    );
  }

  @override
  Future<Map<String, AssetAvailability>> getAssetAvailabilities(
    List<String> ids,
  ) async {
    getAssetAvailabilitiesCalls += 1;
    getAssetAvailabilitiesHistory.add(List<String>.unmodifiable(ids));
    final callIndex = getAssetAvailabilitiesCalls - 1;
    await beforeEachGetAssetAvailabilities?.call(callIndex);
    final thrown = getAssetAvailabilitiesException;
    if (thrown != null) {
      throw thrown;
    }
    return {
      for (final id in ids)
        id: availabilityById[id] ?? AssetAvailability.unavailable,
    };
  }

  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    resolveCalls += 1;
    lastResolve = reference;
    resolveHistory.add(reference);
    final callIndex = resolveCalls - 1;
    await beforeEachResolve?.call(callIndex);

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
      return _resolved(reference.id, ids);
    }

    if (!reference.isLegalBuiltInPair) {
      throw PlatformException(code: AppError.assetUnavailable.name);
    }
    final ids = switch (reference.kind) {
      AssetSourceKind.entireLibrary => allIdsForCall?.call(callIndex) ?? allIds,
      AssetSourceKind.mediaTypePhotos => photosIds,
      AssetSourceKind.mediaTypeVideos => videosIds,
      AssetSourceKind.album || AssetSourceKind.smartAlbum => throw StateError(
        'unreachable after album branch',
      ),
    };
    return _resolved(reference.id, ids);
  }
}
