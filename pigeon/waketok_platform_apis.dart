/// Production Pigeon baseline (App Foundation 4.3).
///
/// PhotoLibraryApi + PlaybackApi only. ClipExportApi is deferred.
/// Spike contracts under pigeon/spikes/ are reference-only — never copy here.
library;

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/generated/waketok_platform_apis.g.dart',
    swiftOut: 'ios/Runner/Platform/Generated/WaketokPlatformApis.g.swift',
    dartPackageName: 'waketok',
  ),
)

/// Wire error codes — 1:1 with Dart [AppError] (including unknown).
/// PlatformException.code / PigeonError.code MUST equal the enum member name.
enum ErrorCode {
  unauthorized,
  assetUnavailable,
  iCloudDownloadRequired,
  iCloudDownloadFailed,
  unsupportedMedia,
  noPlayableAudioTrack,
  insufficientStorage,
  exportFailed,
  photosImportFailed,
  albumUnavailable,
  albumNotWritable,
  operationCancelled,
  unknown,
}

enum AuthStatus {
  notDetermined,
  authorized,
  limited,
  denied,
  restricted,
}

enum AssetSourceKind {
  album,
  smartAlbum,
  /// Built-in All / Entire Library Source (Cap 6).
  entireLibrary,
  /// Built-in Photos Media Type Source (image + Live Photo).
  mediaTypePhotos,
  /// Built-in Videos Media Type Source.
  mediaTypeVideos,
  other,
}

enum MediaKind {
  image,
  video,
  livePhoto,
  unknown,
}

/// Cap 8 file-size provenance (ADR-015). Not a kickoff/GLOSSARY term.
///
/// Tier 1 (`primaryResource`) is unavailable on the formal SDK; the wire value
/// is retained for stability. Cap 8 host paths use [localVideoUrl] /
/// [currentImageRepresentation] only. [unknownUnavailable] is reserved.
enum FileSizeSemantics {
  primaryResource,
  localVideoUrl,
  currentImageRepresentation,
  unknownUnavailable,
}

/// List-time / catalog availability wire enum (Cap 5.4).
///
/// `downloading` is reserved for in-flight resource requests; catalog
/// enumeration must not fabricate it. Domain twin: `AssetAvailability`.
enum AssetAvailabilityDto {
  deviceLocal,
  iCloudNotDownloaded,
  downloading,
  unavailable,
}

/// Asset Source availability at list/resolve time (Glossary §16).
///
/// Distinct from asset-level [AssetAvailabilityDto]. Name avoids clash.
enum AssetSourceAvailabilityDto {
  available,
  empty,
  unavailable,
  unauthorized,
}

enum PlaybackState {
  idle,
  loading,
  playing,
  paused,
  waitingForMedia,
  failed,
  completed,
}

class AssetSourceDto {
  AssetSourceDto({
    required this.sourceIdentifier,
    required this.displayName,
    required this.kind,
    required this.availability,
    required this.canAddContent,
    this.estimatedCount,
  });

  String sourceIdentifier;

  /// Not an l10n source for built-ins — Cap 6 uses empty string; UI uses ARB.
  String displayName;
  AssetSourceKind kind;

  /// For built-ins: always present and exactly equals the matching
  /// [LibraryTotalsDto] component. Approximate semantics reserved for
  /// future Album / Smart Album sources.
  int? estimatedCount;

  AssetSourceAvailabilityDto availability;

  /// Built-ins and non-writable sources: false. User albums may be true later.
  bool canAddContent;
}

class SourceReferenceDto {
  SourceReferenceDto({
    required this.sourceType,
    required this.sourceIdentifier,
  });

  String sourceType;
  String sourceIdentifier;
}

class ResolvedSourceDto {
  ResolvedSourceDto({
    required this.sourceIdentifier,
    required this.assetIdentifiers,
  });

  String sourceIdentifier;
  List<String> assetIdentifiers;
}

/// Displayable still (incl. Live Photo key photo) for Flutter [Image.file].
///
/// Cap 7.3: [localFilePath] is a host temp JPEG/PNG; count bounded ≤1+1 with
/// the display pool (ADR-001 / POC-04). Local-only request — iCloud-only →
/// [ErrorCode.iCloudDownloadRequired] (no host-initiated download).
class DisplayAssetDto {
  DisplayAssetDto({
    required this.assetIdentifier,
    required this.mediaKind,
    required this.localFilePath,
    this.pixelWidth,
    this.pixelHeight,
  });

  String assetIdentifier;
  MediaKind mediaKind;

  /// Absolute path to a host-managed temp file (JPEG). Bounded ≤1+1.
  String localFilePath;
  int? pixelWidth;
  int? pixelHeight;
}

class PlayableVideoDto {
  PlayableVideoDto({
    required this.assetIdentifier,
    this.durationSeconds,
  });

  String assetIdentifier;
  double? durationSeconds;
}

/// One PHAsset row for catalog paging (Cap 5.4).
class LibraryAssetDto {
  LibraryAssetDto({
    required this.assetIdentifier,
    required this.mediaKind,
    required this.availability,
    this.creationDateMs,
  });

  String assetIdentifier;
  MediaKind mediaKind;
  AssetAvailabilityDto availability;

  /// Epoch milliseconds; null when PhotoKit `creationDate` is nil.
  int? creationDateMs;
}

class LibraryPageDto {
  LibraryPageDto({
    required this.assets,
    this.nextCursor,
  });

  List<LibraryAssetDto> assets;

  /// Opaque resume token; null when no further pages.
  String? nextCursor;
}

class LibraryTotalsDto {
  LibraryTotalsDto({
    required this.all,
    required this.photos,
    required this.videos,
  });

  int all;
  int photos;
  int videos;
}

/// Cap 8.3: fast Presentation Metadata fields (date + kind).
///
/// [mediaKind] is always set when the asset exists (incl. [MediaKind.unknown]).
/// [creationDateMs] stays null when PhotoKit `creationDate` is nil.
/// File size is a separate call — [requestPresentationFileSize].
class PresentationMetadataDto {
  PresentationMetadataDto({
    required this.assetIdentifier,
    required this.mediaKind,
    this.creationDateMs,
  });

  String assetIdentifier;
  MediaKind mediaKind;

  /// Epoch milliseconds; null when PhotoKit `creationDate` is nil.
  int? creationDateMs;
}

/// Cap 8.3: optional file size for Overlay row 3 (ADR-015 / POC-10 Tier 3/4).
///
/// Null [fileSizeBytes] means blank UI (not zero). Never download solely for
/// size. Multi-resource / ambiguous assets return nulls.
class PresentationFileSizeDto {
  PresentationFileSizeDto({
    required this.assetIdentifier,
    this.fileSizeBytes,
    this.fileSizeSemantics,
  });

  String assetIdentifier;
  int? fileSizeBytes;
  FileSizeSemantics? fileSizeSemantics;
}

/// One plan item: Photos asset + feed index for PageView sync (ADR-006).
class PlaybackItemDto {
  PlaybackItemDto({
    required this.assetIdentifier,
    required this.feedIndex,
    required this.mediaKind,
  });

  String assetIdentifier;
  int feedIndex;
  MediaKind mediaKind;
}

/// Production playback plan (kickoff PlaybackPlanDTO subset + ADR-006).
///
/// Replaces kickoff `configureQueue(items)` — callers use [PlaybackApi.setPlaybackPlan].
class PlaybackPlanDto {
  PlaybackPlanDto({
    required this.planId,
    required this.orderedItems,
    required this.currentIndex,
  });

  String planId;
  List<PlaybackItemDto> orderedItems;
  int currentIndex;
}

class PlaybackRuntimeEventDto {
  PlaybackRuntimeEventDto({
    required this.planId,
    required this.currentItemIdentifier,
    required this.currentIndex,
    required this.playbackPositionSeconds,
    required this.playbackState,
    this.errorCode,
  });

  String planId;
  String currentItemIdentifier;
  int currentIndex;
  double playbackPositionSeconds;
  PlaybackState playbackState;
  ErrorCode? errorCode;
}

/// Photos library gateway (kickoff PhotoLibraryGateway → production Api name).
@HostApi()
abstract class PhotoLibraryApi {
  /// Pure read of PhotoKit authorization status for `.readWrite`.
  /// MUST NOT present any system prompt or UI.
  AuthStatus authorizationStatus();

  @async
  AuthStatus requestAuthorization();

  /// Presents the system limited-library picker when status is `.limited`.
  /// When status is not limited, completes successfully as a no-op.
  @async
  void presentLimitedLibraryPicker();

  /// Per-type counts for the authorized library (Cap 5.4).
  ///
  /// Uses the same shared [PHFetchOptions] construction as
  /// [fetchLibraryPage]. Photos = image + Live Photo; does not download.
  @async
  LibraryTotalsDto libraryTotals();

  /// Paged PHAsset metadata (id / kind / creationDate / availability).
  ///
  /// [cursor] null starts at the first page. [pageSize] is clamped on host.
  /// Sort: creationDate descending; nil creationDate at end. No album
  /// enumeration; no device-local filter.
  @async
  LibraryPageDto fetchLibraryPage(String? cursor, int pageSize);

  /// Cap 6: returns only the three built-in sources (All / Photos / Videos).
  /// Synchronous — counts use PHFetchResult.count only (no network).
  /// Album / Smart Album listing is deferred.
  List<AssetSourceDto> listAssetSources();

  /// Cap 6: resolves a built-in source to the full ordered id list (D1=A).
  /// [SourceReferenceDto.sourceType] must equal [AssetSourceKind] member name;
  /// pair must match frozen built-in ids (all / photos / videos).
  /// Mismatch → [ErrorCode.assetUnavailable].
  @async
  ResolvedSourceDto resolveSource(SourceReferenceDto sourceReference);

  @async
  DisplayAssetDto requestDisplayAsset(String assetIdentifier);

  @async
  PlayableVideoDto requestPlayableVideo(String assetIdentifier);

  /// Cap 8.3: current-page Presentation Metadata basics (date + kind).
  ///
  /// Does not compute file size. Missing asset → [ErrorCode.assetUnavailable].
  @async
  PresentationMetadataDto requestPresentationMetadata(String assetIdentifier);

  /// Cap 8.3: best-effort local file size (POC-10 Tier 3/4).
  ///
  /// Network access disallowed. Ambiguous / Live Photo / unavailable → null
  /// bytes and null semantics (not an error). Missing asset →
  /// [ErrorCode.assetUnavailable].
  @async
  PresentationFileSizeDto requestPresentationFileSize(String assetIdentifier);

  /// 4.3 empty stub MUST fail with [ErrorCode.albumUnavailable].
  @async
  String createAlbum(String name);

  /// 4.3 empty stub MUST fail with [ErrorCode.photosImportFailed].
  @async
  String importVideo(String tempFilePath);

  /// 4.3 empty stub MUST fail with [ErrorCode.albumNotWritable].
  @async
  void addAssetToAlbum(String assetIdentifier, String albumIdentifier);
}

/// App-scoped playback service contract (ADR-006).
///
/// Ownership: Swift owns AVPlayer lifetime; Dart sends intent only.
/// Platform View is a detachable display surface — not the player owner.
///
/// Restore guard (D4):
/// Guard raised by native on willEnterForeground; cleared by native on
/// notifyDisplaySurfaceReady.
///
/// Detach: native lifecycle (`didEnterBackground`); not a HostApi method.
///
/// Kickoff PlaybackGateway mapping:
/// load/play/pause/seek/setRate/setMute → same names;
/// configureQueue → [setPlaybackPlan];
/// updateNowPlayingMetadata → same (stub until Background Audio);
/// observePlaybackState → [PlaybackFlutterApi.onPlaybackRuntimeEvent].
@HostApi()
abstract class PlaybackApi {
  void load(PlaybackItemDto item);

  void play();

  void pause();

  void seek(double positionSeconds);

  void setRate(double rate);

  void setMute(bool muted);

  /// Video-oriented plan with feed indices (ADR-006). Fulfills kickoff configureQueue.
  void setPlaybackPlan(PlaybackPlanDto plan);

  /// Dart-to-native only; Swift does not ack.
  void syncPlanPosition(String assetIdentifier, int feedIndex);

  /// PV ready: native adopts existing player (no stop/recreate) and clears restore guard.
  void notifyDisplaySurfaceReady(String assetIdentifier);

  /// Stub until Production Background Audio (ADR-002).
  void updateNowPlayingMetadata();
}

/// Native → Dart playback events (ADR-006 restore / plan end + runtime observe).
@FlutterApi()
abstract class PlaybackFlutterApi {
  void onPlaybackRuntimeEvent(PlaybackRuntimeEventDto event);

  void onPlaybackRestoreRequired(int feedIndex, String assetIdentifier);

  void onPlaybackPlanEnded(int feedIndex, String assetIdentifier);
}
