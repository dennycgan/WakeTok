/// Production Pigeon baseline (App Foundation 4.3+).
///
/// PhotoLibraryApi + PlaybackApi + LivePhotoApi (Cap 9). ClipExportApi is
/// deferred. Spike contracts under pigeon/spikes/ are reference-only — never
/// copy here.
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

/// Still JPEG on disk for Flutter [Image.file] (display still **or** preview).
///
/// [localFilePath] is always a static JPEG, including when [mediaKind] is
/// [MediaKind.video] (poster). [mediaKind] describes the PHAsset, not the
/// file type at [localFilePath].
///
/// Which Host store owns the file depends on the API that returned this DTO:
/// [PhotoLibraryApi.requestDisplayAsset] → display store (≤1+1, Cap 7.3);
/// [PhotoLibraryApi.requestPreview] → preview store (cap 3, Cap 14.2).
/// Callers must not share one cache slot across those two methods.
///
/// Error semantics are **per method**, not per DTO. Cap 14.3 Layer 2
/// [PhotoLibraryApi.requestDisplayAsset] / [PhotoLibraryApi.requestPlayableVideo]
/// never emit [ErrorCode.iCloudDownloadRequired] (that code remains Layer 1
/// preview / local-only miss only). Layer 2 terminal download failure is
/// [ErrorCode.iCloudDownloadFailed].
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

  /// Absolute path to a host-managed temp JPEG. Bound depends on the API
  /// that wrote the file (display ≤1+1 vs preview cap 3).
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

  /// Cap 14.3 Layer 2 still (current item). `isNetworkAccessAllowed` is
  /// true. Videos remain [ErrorCode.unsupportedMedia] here.
  ///
  /// Never emits [ErrorCode.iCloudDownloadRequired]. Terminal failure after
  /// a transfer began → [ErrorCode.iCloudDownloadFailed]; failure with no
  /// transfer (and not cancel) → [ErrorCode.assetUnavailable]; abort or
  /// same-id supersede → [ErrorCode.operationCancelled] (non-terminal).
  /// Transfer progress is Host-internal (not a FlutterApi stream).
  @async
  DisplayAssetDto requestDisplayAsset(String assetIdentifier);

  /// Aborts an in-flight [requestDisplayAsset]. No-op if none. Does **not**
  /// delete a display JPEG already on disk.
  void cancelDisplayAsset(String assetIdentifier);

  /// Cap 14.3 Layer 2 playable video (current item).
  /// `isNetworkAccessAllowed` is true. Same Layer 2 error mapping as
  /// [requestDisplayAsset].
  @async
  PlayableVideoDto requestPlayableVideo(String assetIdentifier);

  /// Aborts an in-flight [requestPlayableVideo]. No-op if none.
  void cancelPlayableVideo(String assetIdentifier);

  /// Cap 14.2 Layer 1: local-only degraded still / Live key frame / video
  /// poster. [isNetworkAccessAllowed] is false. Uses `PHImageManager.requestImage`
  /// (not [requestDisplayAsset] — videos remain `unsupportedMedia` there).
  ///
  /// One Pigeon completion. Opportunistic delivery: the first non-nil
  /// `UIImage` is Layer 1 from PhotoKit; Host then `cancelImageRequest` so
  /// preview does **not** upgrade to a later high-quality decode. Later
  /// callbacks (including `PHImageCancelledKey` from that cancel) are dropped.
  ///
  /// [DisplayAssetDto.localFilePath] is always a static JPEG.
  /// [DisplayAssetDto.mediaKind] is the PHAsset kind (video → [MediaKind.video]
  /// + JPEG poster). Do not use [mediaKind] to decide whether to attach a
  /// player; that is [requestPlayableVideo] only.
  ///
  /// [ErrorCode.iCloudDownloadRequired] on **this** method is not a
  /// user-visible failure: it means Layer 1 is unavailable, so the caller
  /// should start Layer 2. Failure / blank chrome is allowed only when
  /// Layer 1 is missing **and** Layer 2 has failed (ADR-025 D2). Do not
  /// revive the Cap 8 iCloud-only copy panel from this code.
  /// Cap 14.3 [requestDisplayAsset] / [requestPlayableVideo] never emit
  /// this code; their download failure is [ErrorCode.iCloudDownloadFailed].
  ///
  /// [ErrorCode.operationCancelled] is non-terminal for the caller: the
  /// request may have been replaced by a newer [requestPreview] for the
  /// same id, or aborted by [cancelPreview] / [releasePreview]. Do not
  /// show failed chrome.
  @async
  DisplayAssetDto requestPreview(String assetIdentifier);

  /// Aborts an in-flight [requestPreview] for [assetIdentifier] (PhotoKit +
  /// encode). No-op if none. Does **not** delete a JPEG already on disk
  /// (current-page Layer 1 may still display it).
  void cancelPreview(String assetIdentifier);

  /// Aborts in-flight preview (same as [cancelPreview]) **and** deletes the
  /// preview JPEG for [assetIdentifier]. No-op if none.
  ///
  /// Invariant (Cap 14.5): callers must [releasePreview] an old neighbour
  /// before [requestPreview] on a new neighbour. Cap 3 is current ±1, not
  /// a slot for preheat-then-release overflow.
  void releasePreview(String assetIdentifier);

  /// Cap 8.3: current-page Presentation Metadata basics (date + kind).
  ///
  /// Does not compute file size. Missing asset → [ErrorCode.assetUnavailable].
  @async
  PresentationMetadataDto requestPresentationMetadata(String assetIdentifier);

  /// Cap 8.3: best-effort local file size (POC-10 Tier 3/4).
  ///
  /// Network access disallowed. Live Photo uses Tier 4 still-only
  /// ([FileSizeSemantics.currentImageRepresentation], ADR-018) — same path as
  /// ordinary images; does not sum paired video. Ambiguous / unavailable →
  /// null bytes and null semantics (not an error). Missing asset →
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

  /// Cap 9 / ADR-019: release active+warming AVPlayers and clear plan.
  /// Completes only after the pool is safe for the caller (Dart awaits before
  /// LivePhotoApi). Idempotent. Does not reset mute preference.
  void clearPlaybackPool();

  /// Cap 16.2 / ADR-029: cancel in-flight `prepareActive` for
  /// [assetIdentifier] even when it is still the current id (leave
  /// Browse / same-id). Does not wait for the next [load]. No-op if none.
  void cancelInFlightPrepare(String assetIdentifier);
}

/// Native → Dart playback events (ADR-006 restore / plan end + runtime observe).
@FlutterApi()
abstract class PlaybackFlutterApi {
  void onPlaybackRuntimeEvent(PlaybackRuntimeEventDto event);

  void onPlaybackRestoreRequired(int feedIndex, String assetIdentifier);

  void onPlaybackPlanEnded(int feedIndex, String assetIdentifier);
}

/// Cap 9 Live Photo motion (ADR-019 / POC-08). Independent of [PlaybackApi]
/// video pool. Dart awaits [PlaybackApi.clearPlaybackPool] before calling
/// [requestLivePhoto] when a Live item becomes current.
///
/// Failure split (9.3 gateway must mirror):
/// - Sync-detectable (missing asset, not photoLive, …) → throw; code =
///   [ErrorCode] member name.
/// - Async request failure (incl. iCloud after network allowed) →
///   [LivePhotoFlutterApi.onLivePhotoFailed] only; do not also throw.
@HostApi()
abstract class LivePhotoApi {
  /// Starts a PHLivePhoto request (network allowed). Sync failures throw.
  void requestLivePhoto(String assetIdentifier);

  /// Cancels an in-flight request for [assetIdentifier] (or no-ops).
  void cancel(String assetIdentifier);

  /// Full motion once; Dart calls after [LivePhotoFlutterApi.onLivePhotoReady]
  /// and surface ready (D2=A).
  void startPlayback();

  void stopPlayback();

  void setMute(bool muted);

  /// Live Platform View created; host binds PHLivePhoto when ready.
  void notifyLiveSurfaceReady(String assetIdentifier);
}

/// Native → Dart Live Photo events (Cap 9).
@FlutterApi()
abstract class LivePhotoFlutterApi {
  void onLivePhotoReady(String assetIdentifier);

  void onLivePhotoFailed(String assetIdentifier, ErrorCode errorCode);

  void onLivePhotoPlaybackEnded(String assetIdentifier);
}
