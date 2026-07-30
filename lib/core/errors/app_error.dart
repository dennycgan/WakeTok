/// Production domain / platform error codes.
///
/// 1:1 with kickoff Data Contract error codes, plus [unknown] as the
/// wire and channel-layer fallback. Spike-era names (e.g.
/// `inCloudUnavailable`) must not appear as members.
enum AppError {
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
