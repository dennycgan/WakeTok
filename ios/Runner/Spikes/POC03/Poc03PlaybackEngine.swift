import AVFoundation
import Foundation

/// App-scoped AVQueuePlayer for POC-03. Lifetime is independent of Flutter widgets.
final class Poc03PlaybackEngine {
  static let shared = Poc03PlaybackEngine()

  private let queuePlayer = AVQueuePlayer()
  private var clipIds: [String] = []
  private var itemToClipId: [ObjectIdentifier: String] = [:]
  private var configured = false

  private init() {
    queuePlayer.actionAtItemEnd = .advance
  }

  func listBundleClipIds() -> [String] {
    ["clip_a", "clip_b", "clip_c"]
  }

  func configureBundleQueue() throws {
    try activateSession()
    queuePlayer.pause()
    queuePlayer.removeAllItems()
    itemToClipId.removeAll()
    clipIds = listBundleClipIds()

    for id in clipIds {
      guard let url = Bundle.main.url(
        forResource: id,
        withExtension: "wav",
        subdirectory: "Fixtures"
      ) ?? Bundle.main.url(forResource: id, withExtension: "wav") else {
        throw NSError(
          domain: "Poc03Playback",
          code: 1,
          userInfo: [NSLocalizedDescriptionKey: "Missing fixture \(id).wav"]
        )
      }
      let item = AVPlayerItem(url: url)
      itemToClipId[ObjectIdentifier(item)] = id
      queuePlayer.insert(item, after: nil)
    }
    configured = true
  }

  func play() throws {
    if !configured {
      try configureBundleQueue()
    }
    try activateSession()
    queuePlayer.play()
  }

  func pause() {
    queuePlayer.pause()
  }

  func stop() {
    queuePlayer.pause()
    queuePlayer.removeAllItems()
    itemToClipId.removeAll()
    configured = false
  }

  func playbackState() -> (
    isPlaying: Bool,
    currentIndex: Int,
    queueLength: Int,
    positionMs: Int,
    currentClipId: String
  ) {
    let current = queuePlayer.currentItem
    let clipId = current.flatMap { itemToClipId[ObjectIdentifier($0)] } ?? ""
    let index = clipIds.firstIndex(of: clipId) ?? 0
    let seconds = current.map { CMTimeGetSeconds($0.currentTime()) } ?? 0
    let positionMs = Int((seconds.isFinite ? max(0, seconds) : 0) * 1000.0)
    return (
      isPlaying: queuePlayer.rate > 0.01,
      currentIndex: index,
      queueLength: clipIds.count,
      positionMs: positionMs,
      currentClipId: clipId
    )
  }

  private func activateSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setActive(true)
  }
}
