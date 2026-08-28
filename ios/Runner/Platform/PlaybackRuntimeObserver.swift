import AVFoundation
import Foundation

/// Cap 18.2: periodic + immediate runtime observe. No dedupe — every tick forwards.
final class PlaybackRuntimeObserver {
  private let intervalSeconds: Double
  private var snapshotProvider: (() -> PlaybackRuntimeSnapshot)?
  private var emitHandler: ((PlaybackRuntimeEventDto) -> Void)?
  private var periodicToken: Any?
  private weak var observedPlayer: AVPlayer?

  init(intervalSeconds: Double = 0.25) {
    self.intervalSeconds = intervalSeconds
  }

  func configure(
    snapshot: @escaping () -> PlaybackRuntimeSnapshot,
    emit: @escaping (PlaybackRuntimeEventDto) -> Void
  ) {
    snapshotProvider = snapshot
    emitHandler = emit
  }

  /// Attach periodic observer to [player], or stop when nil.
  func sync(to player: AVPlayer?) {
    stopPeriodic()
    observedPlayer = player
    guard let player else { return }
    let interval = CMTime(
      seconds: intervalSeconds,
      preferredTimescale: 600
    )
    periodicToken = player.addPeriodicTimeObserver(
      forInterval: interval,
      queue: .main
    ) { [weak self] _ in
      self?.emitImmediate()
    }
  }

  func emitImmediate() {
    guard let snapshotProvider, let emitHandler else { return }
    let dto = PlaybackRuntimeObserveMapper.makeEvent(from: snapshotProvider())
    emitHandler(dto)
  }

  func stop() {
    stopPeriodic()
  }

  private func stopPeriodic() {
    if let token = periodicToken, let player = observedPlayer {
      player.removeTimeObserver(token)
    }
    periodicToken = nil
    observedPlayer = nil
  }

  deinit {
    stopPeriodic()
  }
}
