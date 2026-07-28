import Foundation

/// POC-03 spike host: background queue playback independent of Flutter widgets.
final class Poc03PlaybackHost: Poc03PlaybackApi {
  func configureBundleQueue() throws {
    do {
      try Poc03PlaybackEngine.shared.configureBundleQueue()
    } catch {
      throw Poc03PigeonError(
        code: "configureFailed",
        message: error.localizedDescription,
        details: nil
      )
    }
  }

  func play() throws {
    do {
      try Poc03PlaybackEngine.shared.play()
    } catch {
      throw Poc03PigeonError(
        code: "playFailed",
        message: error.localizedDescription,
        details: nil
      )
    }
  }

  func pause() throws {
    Poc03PlaybackEngine.shared.pause()
  }

  func stop() throws {
    Poc03PlaybackEngine.shared.stop()
  }

  func getPlaybackState() throws -> Poc03PlaybackStateDto {
    let s = Poc03PlaybackEngine.shared.playbackState()
    return Poc03PlaybackStateDto(
      isPlaying: s.isPlaying,
      currentIndex: Int64(s.currentIndex),
      queueLength: Int64(s.queueLength),
      positionMs: Int64(s.positionMs),
      currentClipId: s.currentClipId
    )
  }

  func listBundleClipIds() throws -> [String] {
    Poc03PlaybackEngine.shared.listBundleClipIds()
  }
}
