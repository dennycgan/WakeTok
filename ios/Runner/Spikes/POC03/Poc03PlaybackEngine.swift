import AVFoundation
import Foundation
import UIKit

/// App-scoped AVQueuePlayer for POC-03. Lifetime is independent of Flutter widgets.
///
/// 3.2: keeps ≥1 pre-queued item ahead; records clip-boundary gaps (P3=B probe).
/// 3.3: AVAudioSession interruption; P4=A shouldResume → auto play.
///      After VoIP (WeChat), setActive often fails until the other app releases;
///      keep the process awake briefly with beginBackgroundTask and poll resume
///      so lock-screen / home-screen can recover without opening the Flutter UI.
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
  private var interruptionObserver: NSObjectProtocol?
  private var foregroundObserver: NSObjectProtocol?
  private var itemObservation: NSKeyValueObservation?

  private var isInterrupted = false
  private var wasPlayingBeforeInterruption = false
  private var pendingShouldResume = false
  private var interruptionCount = 0
  private var lastInterruptionSummary = ""
  private var resumePollTimer: Timer?
  private var resumePollTicks = 0
  private var resumeBackgroundTask = UIBackgroundTaskIdentifier.invalid

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
    interruptionObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.interruptionNotification,
      object: AVAudioSession.sharedInstance(),
      queue: .main
    ) { [weak self] note in
      self?.handleInterruption(note)
    }
    foregroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.attemptResume(label: "foreground")
    }
  }

  deinit {
    if let endObserver {
      NotificationCenter.default.removeObserver(endObserver)
    }
    if let interruptionObserver {
      NotificationCenter.default.removeObserver(interruptionObserver)
    }
    if let foregroundObserver {
      NotificationCenter.default.removeObserver(foregroundObserver)
    }
    itemObservation?.invalidate()
    stopResumePolling()
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
    isInterrupted = false
    wasPlayingBeforeInterruption = false
    pendingShouldResume = false
    stopResumePolling()
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
    currentClipId: String,
    isInterrupted: Bool,
    interruptionCount: Int,
    lastInterruptionSummary: String
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
      currentClipId: clipId,
      isInterrupted: isInterrupted,
      interruptionCount: interruptionCount,
      lastInterruptionSummary: lastInterruptionSummary
    )
  }

  private func handleInterruption(_ note: Notification) {
    guard let info = note.userInfo,
          let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue)
    else {
      return
    }

    switch type {
    case .began:
      stopResumePolling()
      pendingShouldResume = false
      wasPlayingBeforeInterruption = queuePlayer.rate > 0.01
      isInterrupted = true
      interruptionCount += 1
      lastInterruptionSummary =
        "began wasPlaying=\(wasPlayingBeforeInterruption)"
      queuePlayer.pause()

    case .ended:
      isInterrupted = false
      interruptionCount += 1
      var shouldResume = false
      if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
        shouldResume = options.contains(.shouldResume)
      }
      lastInterruptionSummary = "ended shouldResume=\(shouldResume)"
      // P4=A. VoIP often holds the session past the ended callback; poll in a
      // short background task so lock-screen/home can recover without UI.
      if shouldResume, wasPlayingBeforeInterruption, configured {
        pendingShouldResume = true
        startResumePolling()
      } else {
        pendingShouldResume = false
        wasPlayingBeforeInterruption = false
        stopResumePolling()
      }

    @unknown default:
      interruptionCount += 1
      lastInterruptionSummary = "unknown interruption type"
    }
  }

  private func startResumePolling() {
    stopResumePolling()
    beginResumeBackgroundTask()
    resumePollTicks = 0
    attemptResume(label: "immediate")
    let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
      self?.resumePollTick()
    }
    RunLoop.main.add(timer, forMode: .common)
    resumePollTimer = timer
  }

  private func resumePollTick() {
    resumePollTicks += 1
    // ~25s of polling (0.5s * 50).
    if resumePollTicks > 50 {
      lastInterruptionSummary =
        "ended shouldResume=true → resume gave up after ~25s"
      pendingShouldResume = false
      wasPlayingBeforeInterruption = false
      stopResumePolling()
      return
    }
    attemptResume(label: "poll \(resumePollTicks)")
  }

  private func stopResumePolling() {
    resumePollTimer?.invalidate()
    resumePollTimer = nil
    endResumeBackgroundTask()
  }

  private func beginResumeBackgroundTask() {
    guard resumeBackgroundTask == .invalid else { return }
    resumeBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "poc03-interrupt-resume"
    ) { [weak self] in
      self?.endResumeBackgroundTask()
    }
  }

  private func endResumeBackgroundTask() {
    guard resumeBackgroundTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(resumeBackgroundTask)
    resumeBackgroundTask = .invalid
  }

  private func attemptResume(label: String) {
    guard pendingShouldResume, configured else { return }
    if queuePlayer.rate > 0.01 {
      pendingShouldResume = false
      wasPlayingBeforeInterruption = false
      stopResumePolling()
      return
    }
    do {
      try activateSession()
      ensurePrequeue()
      queuePlayer.play()
      pendingShouldResume = false
      wasPlayingBeforeInterruption = false
      lastInterruptionSummary =
        "ended shouldResume=true → auto play (\(label))"
      stopResumePolling()
    } catch {
      lastInterruptionSummary =
        "ended shouldResume=true → resume failed (\(label)): "
        + error.localizedDescription
      // Keep polling / pending until success, give-up, or stop.
    }
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

  private func ensurePrequeue() {
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
