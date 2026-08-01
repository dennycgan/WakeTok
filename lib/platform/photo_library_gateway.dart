import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/library_asset.dart';
import 'package:waketok/domain/library/library_catalog_repository.dart';
import 'package:waketok/domain/library/library_media_kind.dart';
import 'package:waketok/domain/library/library_page.dart';
import 'package:waketok/domain/library/library_totals.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;

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
    implements PhotosAuthorizationRepository, LibraryCatalogRepository {
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
}
