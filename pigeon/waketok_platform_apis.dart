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

  /// User albums: PhotoKit canPerform(.addContent). Smart albums and
  /// built-ins: false (Cap 19.2).
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
    required this.assetAvailabilities,
  });

  String sourceIdentifier;
  List<String> assetIdentifiers;

  /// Parallel to [assetIdentifiers]. Cap 15.15: resolve returns **empty**;
  /// become-current probes via [PhotoLibraryApi.getAssetAvailabilities].
  List<AssetAvailabilityDto> assetAvailabilities;
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
    this.durationSeconds,
    this.errorCode,
  });

  String planId;
  String currentItemIdentifier;
  int currentIndex;
  double playbackPositionSeconds;
  PlaybackState playbackState;

  /// Active item duration when known; null when indefinite / unavailable.
  double? durationSeconds;
  ErrorCode? errorCode;
}

/// Cap 15.11: Host → Dart after [PlaybackApiHost] attaches [activePlayer]
/// to the shared Platform View for [currentAssetIdentifier].
class PlaybackSurfaceAttachedDto {
  PlaybackSurfaceAttachedDto({
    required this.assetIdentifier,
    required this.feedIndex,
    required this.clearEpoch,
  });

  String assetIdentifier;
  int feedIndex;
  int clearEpoch;
}

/// Cap 18.3 / ADR-040: Dart-owned user intent + one-shot navigation activation.
class PlaybackIntentDto {
  PlaybackIntentDto({
    required this.assetIdentifier,
    required this.wantsPlay,
    required this.startsNewNavigationActivation,
    required this.clearsPendingNavigationActivation,
  });

  String assetIdentifier;
  bool wantsPlay;
  bool startsNewNavigationActivation;

  /// Lifecycle leave-foreground sets true to clear a matching pending activation.
  bool clearsPendingNavigationActivation;
}

/// Cap 18.5 scrub preview still + Host actual presentation time
/// (ADR-040 Decision 13 Option B drift gate).
class ScrubPreviewFrameDto {
  ScrubPreviewFrameDto({
    this.jpegBytes,
    this.actualSeconds,
  });

  /// Null when preview unavailable.
  Uint8List? jpegBytes;

  /// AVAssetImageGenerator `actualTime` in seconds. Required when
  /// [jpegBytes] is non-null; Dart treats missing actual as failure.
  double? actualSeconds;
}

/// Cap 19.5: User Album list cover (Photos-style). [jpegBytes] null when the
/// album is empty or no local-only thumbnail is available (not an error).
class AlbumCoverThumbnailDto {
  AlbumCoverThumbnailDto({this.jpegBytes});

  Uint8List? jpegBytes;
}

/// Cap 19.5b: per-asset Favorites flag for panel toggle.
class AssetFavoriteStatusDto {
  AssetFavoriteStatusDto({
    required this.assetIdentifier,
    required this.isFavorite,
  });

  String assetIdentifier;
  bool isFavorite;
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

  /// Cap 15.12 / 15.15: on-demand list-time availability for specific ids.
  ///
  /// Parallel [AssetAvailabilityDto] values; unknown ids → unavailable.
  /// Resolve returns empty [ResolvedSourceDto.assetAvailabilities]; feed
  /// become-current probes here (do not scan the full library at resolve).
  @async
  List<AssetAvailabilityDto> getAssetAvailabilities(
    List<String> assetIdentifiers,
  );

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

  /// Duration / type metadata only (Cap 16.3). Fetches the PHAsset and
  /// returns [PlayableVideoDto.durationSeconds] from `PHAsset.duration`.
  /// Does **not** call `requestAVAsset` (no download). Production feed
  /// current-item video fetch is [PlaybackApi.load]. Debug probe may
  /// still call this. Same missing / non-video codes as before
  /// ([ErrorCode.assetUnavailable] / [ErrorCode.unsupportedMedia]).
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

  /// Cap 19.5: most-recent member thumbnail for a User Album list row.
  /// Local-only (`isNetworkAccessAllowed` false). Empty album → null
  /// [AlbumCoverThumbnailDto.jpegBytes]. Missing album →
  /// [ErrorCode.albumUnavailable].
  @async
  AlbumCoverThumbnailDto requestAlbumCoverThumbnail(
    String albumIdentifier,
    int targetSizePx,
  );

  /// Cap 19.5b: read [PHAsset.isFavorite] for the panel toggle (Full Access).
  @async
  AssetFavoriteStatusDto requestAssetFavoriteStatus(String assetIdentifier);

  /// Cap 19.5b: set [PHAssetChangeRequest.isFavorite] on the current asset.
  @async
  void setAssetFavorite(String assetIdentifier, bool favorite);

  /// Cap 19.5b: Favorites smart-album mosaic (subtype favorites; not current asset).
  @async
  AlbumCoverThumbnailDto requestFavoritesSmartAlbumCoverThumbnail(
    int targetSizePx,
  );

  /// Cap 19.7: whether [assetIdentifier] is already a member of the User
  /// Album [albumIdentifier]. Single-asset fetch (not User Album enumerate).
  /// Missing album → [ErrorCode.albumUnavailable]. Missing asset is still
  /// a valid `false` (not an error) when the album exists.
  @async
  bool albumContainsAsset(String albumIdentifier, String assetIdentifier);

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
  /// Cap 16.3 / ADR-029: current-item video prepare. Completes when
  /// playable, failed, or cancelled. The single networked `requestAVAsset`.
  /// Must not return without completing (including cancel / pool clear).
  @async
  void load(PlaybackItemDto item);

  void play();

  /// Resume from the current playhead without re-enter seek-to-zero policy
  /// (Cap 18.5 scrub release — must follow a completed [seek]).
  void playFromCurrentPosition();

  void pause();

  /// Completes when the active player seek finishes (or no-op when idle).
  @async
  void seek(double positionSeconds);

  void setRate(double rate);

  void setMute(bool muted);

  /// Video-oriented plan with feed indices (ADR-006). Fulfills kickoff
  /// configureQueue. Cap 16.3: plan bookkeeping only — must **not**
  /// `prepareActive` / `replaceCurrentItem`.
  void setPlaybackPlan(PlaybackPlanDto plan);

  /// Dart-to-native only; Swift does not ack. Cap 16.3: feed index only;
  /// must **not** `prepareActive` / `replaceCurrentItem`.
  void syncPlanPosition(String assetIdentifier, int feedIndex);

  /// PV ready: native adopts existing player (no stop/recreate) and
  /// clears restore guard. Cap 16.3: attach only — must **not**
  /// `prepareActive` (that would be a second download).
  void notifyDisplaySurfaceReady(String assetIdentifier);

  /// Stub until Production Background Audio (ADR-002).
  void updateNowPlayingMetadata();

  /// Cap 9 / ADR-019: release active+warming AVPlayers and clear plan.
  /// Completes only after the pool is safe for the caller (Dart awaits before
  /// LivePhotoApi). Idempotent. Does not reset mute preference.
  /// Cap 16.3: must complete any in-flight [load] (do not only bump epoch
  /// and drop the Pigeon completion).
  void clearPlaybackPool();

  /// Cap 16.2 / ADR-029: cancel in-flight `prepareActive` for
  /// [assetIdentifier] even when it is still the current id (leave
  /// Browse / same-id). Does not wait for the next [load]. No-op if none.
  /// Cap 16.3: must also complete that id's pending [load] Future
  /// ([ErrorCode.operationCancelled]). Id-keyed — never cancels a
  /// different asset's in-flight [load].
  void cancelInFlightPrepare(String assetIdentifier);

  /// Cap 15.11: temporary mute during shared-PV handoff guard. Does **not**
  /// change persisted user mute ([setMute]); cleared by Dart after
  /// [PlaybackFlutterApi.onPlaybackSurfaceReadyForDisplay] (first frame).
  void setTransitionAudioSuppressed(bool suppressed);

  /// Cap 15.11: snapshot of Host [clearEpoch] at guard arm time (pool invalidation
  /// generation — not Dart [FeedMediaRequestGate] display generation).
  int getPlaybackPoolEpoch();

  /// Cap 18.3 / ADR-040: sync user intent + optional navigation activation mirror.
  /// Host must apply mirror synchronously before replying.
  void setPlaybackIntent(PlaybackIntentDto intent);

  /// Cap 18.5 / ADR-040 Decision 13 supplement: best-effort scrub preview still
  /// (JPEG + Host actual time). Null when no active player or generation failed.
  /// Must not seek the active [AVPlayer] — preview only.
  /// Success requires both [ScrubPreviewFrameDto.jpegBytes] and
  /// [ScrubPreviewFrameDto.actualSeconds]; Dart rejects oversized
  /// |requested − actual| drift as equivalent failure.
  @async
  ScrubPreviewFrameDto? requestScrubPreviewFrame(double positionSeconds);
}

/// Native → Dart playback events (ADR-006 restore / plan end + runtime observe).
@FlutterApi()
abstract class PlaybackFlutterApi {
  void onPlaybackRuntimeEvent(PlaybackRuntimeEventDto event);

  void onPlaybackRestoreRequired(int feedIndex, String assetIdentifier);

  void onPlaybackPlanEnded(int feedIndex, String assetIdentifier);

  /// Cap 15.11: [activePlayer] attached to Platform View for [assetIdentifier].
  /// Attach ≠ first displayable frame — do not use as cover unwrap alone.
  void onPlaybackSurfaceAttached(PlaybackSurfaceAttachedDto event);

  /// Cap 15.11b: [AVPlayerLayer.isReadyForDisplay] became true for the current
  /// plan id. Same DTO triple as attach-ack (assetId + feedIndex + clearEpoch).
  void onPlaybackSurfaceReadyForDisplay(PlaybackSurfaceAttachedDto event);
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
