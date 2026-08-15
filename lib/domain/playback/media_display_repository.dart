import 'package:waketok/domain/playback/playback_models.dart';

/// Still/video presentation over PhotoLibraryApi (Cap 7.3 + Cap 14.2).
///
/// [requestDisplayAsset] / [requestPlayableVideo] remain Cap 7.3 local-only:
/// iCloud-only assets fail with channel `iCloudDownloadRequired` as a
/// **user-visible** failure until Cap 14.3.
///
/// [requestPreview] is Layer 1 (local still / video poster). Its
/// `iCloudDownloadRequired` means Layer 1 is missing — not user-visible
/// chrome. [operationCancelled] on preview is non-terminal.
///
/// Preview and display [DisplayAsset] results must **not** share one cache
/// slot; callers store them separately by method.
abstract class MediaDisplayRepository {
  Future<DisplayAsset> requestDisplayAsset(String assetIdentifier);

  Future<PlayableVideo> requestPlayableVideo(String assetIdentifier);

  Future<DisplayAsset> requestPreview(String assetIdentifier);

  Future<void> cancelPreview(String assetIdentifier);

  Future<void> releasePreview(String assetIdentifier);
}
