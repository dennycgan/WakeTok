import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/library_asset.dart';
import 'package:waketok/domain/library/library_catalog_repository.dart';
import 'package:waketok/domain/library/library_media_kind.dart';
import 'package:waketok/domain/library/library_page.dart';
import 'package:waketok/domain/library/library_totals.dart';
import 'package:waketok/domain/playback/media_display_repository.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/asset_source_repository.dart';
import 'package:waketok/domain/source/resolved_source.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/playback_gateway.dart';

/// Maps Pigeon [AuthStatus] → domain [PhotosAccess].
PhotosAccess photosAccessFromAuthStatus(pigeon.AuthStatus status) {
  switch (status) {
    case pigeon.AuthStatus.notDetermined:
      return PhotosAccess.notDetermined;
    case pigeon.AuthStatus.authorized:
      return PhotosAccess.full;
    case pigeon.AuthStatus.limited:
      return PhotosAccess.limited;
    case pigeon.AuthStatus.denied:
      return PhotosAccess.denied;
    case pigeon.AuthStatus.restricted:
      return PhotosAccess.restricted;
  }
}

LibraryMediaKind libraryMediaKindFromPigeon(pigeon.MediaKind kind) {
  switch (kind) {
    case pigeon.MediaKind.image:
      return LibraryMediaKind.image;
    case pigeon.MediaKind.video:
      return LibraryMediaKind.video;
    case pigeon.MediaKind.livePhoto:
      return LibraryMediaKind.livePhoto;
    case pigeon.MediaKind.unknown:
      return LibraryMediaKind.unknown;
  }
}

AssetAvailability assetAvailabilityFromPigeon(pigeon.AssetAvailabilityDto value) {
  switch (value) {
    case pigeon.AssetAvailabilityDto.deviceLocal:
      return AssetAvailability.deviceLocal;
    case pigeon.AssetAvailabilityDto.iCloudNotDownloaded:
      return AssetAvailability.iCloudNotDownloaded;
    case pigeon.AssetAvailabilityDto.downloading:
      return AssetAvailability.downloading;
    case pigeon.AssetAvailabilityDto.unavailable:
      return AssetAvailability.unavailable;
  }
}

/// Cap 6 domain kinds only — non-built-in wire kinds must not be coerced.
AssetSourceKind assetSourceKindFromPigeon(pigeon.AssetSourceKind kind) {
  switch (kind) {
    case pigeon.AssetSourceKind.entireLibrary:
      return AssetSourceKind.entireLibrary;
    case pigeon.AssetSourceKind.mediaTypePhotos:
      return AssetSourceKind.mediaTypePhotos;
    case pigeon.AssetSourceKind.mediaTypeVideos:
      return AssetSourceKind.mediaTypeVideos;
    case pigeon.AssetSourceKind.album:
    case pigeon.AssetSourceKind.smartAlbum:
    case pigeon.AssetSourceKind.other:
      throw StateError(
        'Unsupported AssetSourceKind for Cap 6 domain mapping: $kind',
      );
  }
}

AssetSourceAvailability assetSourceAvailabilityFromPigeon(
  pigeon.AssetSourceAvailabilityDto value,
) {
  switch (value) {
    case pigeon.AssetSourceAvailabilityDto.available:
      return AssetSourceAvailability.available;
    case pigeon.AssetSourceAvailabilityDto.empty:
      return AssetSourceAvailability.empty;
    case pigeon.AssetSourceAvailabilityDto.unavailable:
      return AssetSourceAvailability.unavailable;
    case pigeon.AssetSourceAvailabilityDto.unauthorized:
      return AssetSourceAvailability.unauthorized;
  }
}

AssetSource assetSourceFromDto(pigeon.AssetSourceDto dto) {
  final count = dto.estimatedCount;
  if (count == null) {
    throw StateError(
      'Built-in AssetSourceDto.estimatedCount must be present (ADR-013)',
    );
  }
  return AssetSource(
    kind: assetSourceKindFromPigeon(dto.kind),
    id: dto.sourceIdentifier,
    estimatedCount: count,
    availability: assetSourceAvailabilityFromPigeon(dto.availability),
    canAddContent: dto.canAddContent,
  );
}

ResolvedSource resolvedSourceFromDto(pigeon.ResolvedSourceDto dto) {
  return ResolvedSource(
    sourceId: dto.sourceIdentifier,
    assetIdentifiers: List<String>.unmodifiable(dto.assetIdentifiers),
  );
}

LibraryAsset libraryAssetFromDto(pigeon.LibraryAssetDto dto) {
  DateTime? createdAt;
  final ms = dto.creationDateMs;
  if (ms != null) {
    createdAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  return LibraryAsset(
    id: dto.assetIdentifier,
    kind: libraryMediaKindFromPigeon(dto.mediaKind),
    availability: assetAvailabilityFromPigeon(dto.availability),
    createdAt: createdAt,
  );
}

LibraryTotals libraryTotalsFromDto(pigeon.LibraryTotalsDto dto) {
  return LibraryTotals(
    all: dto.all,
    photos: dto.photos,
    videos: dto.videos,
  );
}

LibraryPage libraryPageFromDto(pigeon.LibraryPageDto dto) {
  return LibraryPage(
    assets: dto.assets.map(libraryAssetFromDto).toList(growable: false),
    nextCursor: dto.nextCursor,
  );
}

/// Pigeon [PhotoLibraryApi] adapter (ADR-009 platform layer).
class PhotoLibraryGateway
    implements
        PhotosAuthorizationRepository,
        LibraryCatalogRepository,
        AssetSourceRepository,
        MediaDisplayRepository {
  PhotoLibraryGateway({pigeon.PhotoLibraryApi? api})
      : _api = api ?? pigeon.PhotoLibraryApi();

  final pigeon.PhotoLibraryApi _api;

  @override
  Future<PhotosAccess> currentStatus() async {
    final status = await _api.authorizationStatus();
    return photosAccessFromAuthStatus(status);
  }

  @override
  Future<PhotosAccess> requestAccess() async {
    final status = await _api.requestAuthorization();
    return photosAccessFromAuthStatus(status);
  }

  @override
  Future<void> presentLimitedLibraryPicker() {
    return _api.presentLimitedLibraryPicker();
  }

  @override
  Future<LibraryTotals> totals() async {
    final dto = await _api.libraryTotals();
    return libraryTotalsFromDto(dto);
  }

  @override
  Future<LibraryPage> fetchPage({String? cursor, required int pageSize}) async {
    final dto = await _api.fetchLibraryPage(cursor, pageSize);
    return libraryPageFromDto(dto);
  }

  @override
  Future<List<AssetSource>> listBuiltInSources() async {
    final dtos = await _api.listAssetSources();
    return dtos.map(assetSourceFromDto).toList(growable: false);
  }

  @override
  Future<ResolvedSource> resolve(SourceReference reference) async {
    final dto = await _api.resolveSource(
      pigeon.SourceReferenceDto(
        sourceType: reference.kind.name,
        sourceIdentifier: reference.id,
      ),
    );
    return resolvedSourceFromDto(dto);
  }

  @override
  Future<DisplayAsset> requestDisplayAsset(String assetIdentifier) async {
    final dto = await _api.requestDisplayAsset(assetIdentifier);
    return DisplayAsset(
      assetIdentifier: dto.assetIdentifier,
      mediaKind: playbackMediaKindFromPigeon(dto.mediaKind),
      localFilePath: dto.localFilePath,
      pixelWidth: dto.pixelWidth,
      pixelHeight: dto.pixelHeight,
    );
  }

  @override
  Future<PlayableVideo> requestPlayableVideo(String assetIdentifier) async {
    final dto = await _api.requestPlayableVideo(assetIdentifier);
    return PlayableVideo(
      assetIdentifier: dto.assetIdentifier,
      durationSeconds: dto.durationSeconds,
    );
  }
}
