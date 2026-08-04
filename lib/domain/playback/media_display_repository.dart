import 'package:waketok/domain/playback/playback_models.dart';

/// Local still/video presentation over PhotoLibraryApi (Cap 7.3).
///
/// Host is local-only: iCloud-only assets fail with channel
/// `iCloudDownloadRequired` (no host-initiated download).
abstract class MediaDisplayRepository {
  Future<DisplayAsset> requestDisplayAsset(String assetIdentifier);

  Future<PlayableVideo> requestPlayableVideo(String assetIdentifier);
}
