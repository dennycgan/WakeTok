import AVFoundation
import Foundation

/// App-scoped AVQueuePlayer for POC-03. Lifetime is independent of Flutter widgets.
///
/// 3.2: keeps ≥1 pre-queued item ahead; records clip-boundary gaps (P3=B probe).
final class Poc03PlaybackEngine {
  static let shared = Poc03PlaybackEngine()

  private let queuePlayer = AVQueuePlayer()
  private var clipIds: [String] = []
  private var itemToClipId: [ObjectIdentifier: String] = [:]
  private var configured = false
  private var nextInsertIndex = 0
  private var gapT0: CFTimeInterval?
  private var gapSamplesMs: [Double] = []
  private var endObserver: NSObjectProtocol?
  private var itemObservation: NSKeyValueObservation?

  private init() {
    queuePlayer.actionAtItemEnd = .advance
    endObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: nil,
      queue: .main
    ) { [weak self] note in
      self?.handleItemDidPlayToEnd(note)
    }
    itemObservation = queuePlayer.observe(\.currentItem, options: [.new]) {
      [weak self] _, _ in
      self?.handleCurrentItemChanged()
    }
  }

  deinit {
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
    itemObservation?.invalidate()
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
    nextInsertIndex = 0
    gapT0 = nil
    // Seed current + at least one ahead (pre-queue contract).
    try enqueueNextClip()
    try enqueueNextClip()
    configured = true
  }

  func play() throws {
    if !configured {
      try configureBundleQueue()
    }
    try activateSession()
    ensurePrequeue()
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
    nextInsertIndex = 0
    gapT0 = nil
  }

  func clearGapSamples() {
    gapSamplesMs.removeAll()
    gapT0 = nil
  }

  func getGapSamplesMs() -> [Double] {
    gapSamplesMs
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
    // items() is remaining after current in some OS versions; report logical clip count.
    return (
      isPlaying: queuePlayer.rate > 0.01,
      currentIndex: index,
      queueLength: clipIds.count,
      positionMs: positionMs,
      currentClipId: clipId
    )
  }

  private func handleItemDidPlayToEnd(_ note: Notification) {
    guard let item = note.object as? AVPlayerItem else { return }
    guard itemToClipId[ObjectIdentifier(item)] != nil else { return }
    gapT0 = CACurrentMediaTime()
    ensurePrequeue()
  }

  private func handleCurrentItemChanged() {
    guard let t0 = gapT0 else { return }
    guard queuePlayer.currentItem != nil else { return }
    let ms = (CACurrentMediaTime() - t0) * 1000.0
    if ms >= 0, ms < 5000 {
      gapSamplesMs.append(ms)
    }
    gapT0 = nil
    ensurePrequeue()
  }

  /// Maintain ≥1 AVPlayerItem after the current one (pre-queue).
  private func ensurePrequeue() {
    // items() includes current on modern iOS; keep count ≥ 2 while configured.
    while configured, queuePlayer.items().count < 2 {
      do {
        try enqueueNextClip()
      } catch {
        break
      }
    }
  }

  private func enqueueNextClip() throws {
    guard !clipIds.isEmpty else { return }
    let id = clipIds[nextInsertIndex % clipIds.count]
    nextInsertIndex += 1
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

  private func activateSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: [])
    try session.setActive(true)
  }
}
