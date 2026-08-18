import 'package:waketok/domain/playback/playback_models.dart';

/// Still/video presentation over PhotoLibraryApi (Cap 7.3 + Cap 14.2/14.3).
///
/// [requestDisplayAsset] is Cap 14.3 Layer 2 (network allowed).
/// [requestPlayableVideo] is duration / type metadata only (Cap 16.3) —
/// it does not download; current-item video fetch is [PlaybackRepository.load].
/// Layer 2 never emits channel `iCloudDownloadRequired`.
/// Terminal download failure is `iCloudDownloadFailed`; abort / same-id
/// supersede is `operationCancelled` (non-terminal).
///
/// [requestPreview] is Layer 1 (local still / video poster). Its
/// `iCloudDownloadRequired` means Layer 1 is missing — not user-visible
/// chrome. [operationCancelled] on preview is non-terminal.
///
/// Preview and display [DisplayAsset] results must **not** share one cache
/// slot; callers store them separately by method.
abstract class MediaDisplayRepository {
  Future<DisplayAsset> requestDisplayAsset(String assetIdentifier);

  Future<void> cancelDisplayAsset(String assetIdentifier);

  Future<PlayableVideo> requestPlayableVideo(String assetIdentifier);

  Future<void> cancelPlayableVideo(String assetIdentifier);

  Future<DisplayAsset> requestPreview(String assetIdentifier);

  Future<void> cancelPreview(String assetIdentifier);

  Future<void> releasePreview(String assetIdentifier);
}
