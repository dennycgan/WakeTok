import Foundation

/// 4.3 empty PlaybackApi host — ADR-006 ownership surface; no AVPlayer yet.
///
/// Restore guard (D4):
/// Guard raised by native on willEnterForeground; cleared by native on
/// notifyDisplaySurfaceReady.
final class PlaybackApiHost: PlaybackApi {
  /// Placeholder for future restore-guard flag (cleared in notifyDisplaySurfaceReady).
  private var restoreGuardActive = false

  func load(item: PlaybackItemDto) throws {}

  func play() throws {}

  func pause() throws {}

  func seek(positionSeconds: Double) throws {}

  func setRate(rate: Double) throws {}

  func setMute(muted: Bool) throws {}

  func setPlaybackPlan(plan: PlaybackPlanDto) throws {}

  /// Dart-to-native only; Swift does not ack.
  func syncPlanPosition(assetIdentifier: String, feedIndex: Int64) throws {}

  func notifyDisplaySurfaceReady(assetIdentifier: String) throws {
    // Guard raised by native on willEnterForeground; cleared by native on
    // notifyDisplaySurfaceReady.
    restoreGuardActive = false
  }

  func updateNowPlayingMetadata() throws {}

  #if DEBUG
  /// Test/observability hook for the restore-guard placeholder.
  var isRestoreGuardActiveForTests: Bool { restoreGuardActive }
  #endif
}
