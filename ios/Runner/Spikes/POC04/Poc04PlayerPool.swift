import AVFoundation
import Flutter
import Foundation
import Photos
import UIKit

/// Hard-capped AVPlayer pool for POC-04: ≤1 active + ≤1 warming.
final class Poc04PlayerPool {
  static let shared = Poc04PlayerPool()

  private let lock = NSLock()
  private var activeAssetId: String?
  private var warmingAssetId: String?
  private var activePlayer: AVPlayer?
  private var warmingPlayer: AVPlayer?
  private var activeItemRequestId: PHImageRequestID = PHInvalidImageRequestID
  private var warmingItemRequestId: PHImageRequestID = PHInvalidImageRequestID

  /// Views observe this to bind AVPlayerLayer when their asset becomes active (PV mode).
  private(set) var playersByAssetId: [String: AVPlayer] = [:]

  private var textureRegistry: FlutterTextureRegistry?
  /// T1=B default Texture (escape); toggle to false for Platform View A/B.
  private var useTextureSurface = true
  private var activeTexture: Poc04ActiveVideoTexture?

  /// Lock-probe only: unbound AVPlayerItems ready for replaceCurrentItem.
  /// Never attach these to the warming AVPlayer — moving items between players aborts.
  private var prefetchedItems: [String: AVPlayerItem] = [:]
  private var prefetchRequestId: PHImageRequestID = PHInvalidImageRequestID

  // MARK: - First-frame timing (phase 2.5 / Texture escape)
  private var firstFrameT0: CFTimeInterval?
  private var firstFrameAssetId: String?
  private var firstFrameMsResult: Double?
  private var firstFrameSamples: [Double] = []
  private var firstFrameWaiters: [(Result<Double, Error>) -> Void] = []
  private var readyObservation: NSKeyValueObservation?
  private var firstFrameTimeoutWork: DispatchWorkItem?

  var activeCount: Int {
    lock.lock(); defer { lock.unlock() }
    return activePlayer != nil ? 1 : 0
  }

  var warmingCount: Int {
    lock.lock(); defer { lock.unlock() }
    return warmingPlayer != nil ? 1 : 0
  }

  /// Active asset id for lock-probe plan sync (nil if no active slot).
  var activeAssetIdValue: String? {
    lock.lock(); defer { lock.unlock() }
    return activeAssetId
  }

  var isActivePlaying: Bool {
    lock.lock()
    let rate = activePlayer?.rate ?? 0
    lock.unlock()
    return rate > 0.01
  }

  var activePlayerItem: AVPlayerItem? {
    lock.lock(); defer { lock.unlock() }
    return activePlayer?.currentItem
  }

  func configure(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
  }

  /// Lock-audio probe: unmute active for audible background play.
  func applyLockProbeAudioPolicy(unmuted: Bool) {
    lock.lock()
    activePlayer?.isMuted = !unmuted
    if let q = activePlayer as? AVQueuePlayer {
      q.actionAtItemEnd = .advance
    }
    if !unmuted {
      warmingPlayer?.isMuted = true
    }
    lock.unlock()
  }

  /// Prefetch an unbound AVPlayerItem, then insert it into the active AVQueuePlayer
  /// (before current item ends) so lock-screen advance needs no background play().
  func prefetchLockProbeItem(
    assetId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let finishInsert: () -> Void = { [weak self] in
      guard let self else {
        completion(.failure(
          PigeonError(code: "exportFailed", message: "Pool deallocated", details: nil)
        ))
        return
      }
      let ok = self.insertPrefetchedIntoActiveQueueIfNeeded(assetId: assetId)
      if ok {
        completion(.success(()))
        return
      }
      // Active may have been downgraded to plain AVPlayer — upgrade and retry once.
      self.ensureActiveIsQueuePlayerForLockProbe {
        let retried = self.insertPrefetchedIntoActiveQueueIfNeeded(assetId: assetId)
        if retried {
          completion(.success(()))
        } else {
          completion(.failure(
            PigeonError(
              code: "exportFailed",
              message: "Queue insert failed for \(assetId)",
              details: nil
            )
          ))
        }
      }
    }

    lock.lock()
    if prefetchedItems[assetId] != nil {
      lock.unlock()
      finishInsert()
      return
    }
    // Already sitting in the active queue?
    if let q = activePlayer as? AVQueuePlayer,
       q.items().count >= 2 {
      lock.unlock()
      completion(.success(()))
      return
    }
    lock.unlock()

    requestPlayerItem(for: assetId) { [weak self] result in
      guard let self else { return }
      switch result {
      case .failure(let error):
        completion(.failure(error))
      case .success(let item):
        self.lock.lock()
        self.prefetchedItems[assetId] = item
        self.lock.unlock()
        finishInsert()
      }
    }
  }

  /// Ensure active player is AVQueuePlayer while lock probe is on (foreground upgrade OK).
  func ensureActiveIsQueuePlayerForLockProbe(completion: @escaping () -> Void) {
    lock.lock()
    if activePlayer is AVQueuePlayer || activePlayer == nil {
      lock.unlock()
      completion()
      return
    }
    guard let assetId = activeAssetId else {
      lock.unlock()
      completion()
      return
    }
    let old = activePlayer
    let t = old?.currentTime() ?? .zero
    let wasPlaying = (old?.rate ?? 0) > 0.01
    old?.pause()
    lock.unlock()

    requestPlayerItem(for: assetId) { [weak self] result in
      guard let self else {
        completion()
        return
      }
      switch result {
      case .failure:
        completion()
      case .success(let item):
        let q = AVQueuePlayer(playerItem: item)
        q.actionAtItemEnd = .advance
        q.isMuted = false
        self.lock.lock()
        if let oldId = self.activeAssetId {
          self.playersByAssetId.removeValue(forKey: oldId)
        }
        self.activePlayer = q
        self.activeAssetId = assetId
        self.playersByAssetId[assetId] = q
        self.lock.unlock()
        q.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
          if wasPlaying {
            q.play()
          }
          NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
          NSLog("[Poc04LockAudio] upgraded active to AVQueuePlayer")
          completion()
        }
      }
    }
  }

  /// Insert prefetched next item after current (queue must already be AVQueuePlayer).
  @discardableResult
  func insertPrefetchedIntoActiveQueueIfNeeded(assetId: String) -> Bool {
    lock.lock()
    guard let q = activePlayer as? AVQueuePlayer else {
      lock.unlock()
      return false
    }
    guard let item = prefetchedItems[assetId] else {
      lock.unlock()
      return false
    }
    // Already queued?
    if q.items().contains(where: { $0 === item }) {
      lock.unlock()
      return true
    }
    // Keep at most current + one lookahead.
    while q.items().count > 1 {
      if let last = q.items().last, last !== q.currentItem {
        q.remove(last)
      } else {
        break
      }
    }
    prefetchedItems.removeValue(forKey: assetId)
    if let current = q.currentItem {
      q.insert(item, after: current)
    } else {
      q.insert(item, after: nil)
    }
    let count = q.items().count
    lock.unlock()
    NSLog(
      "[Poc04LockAudio] queue insert %@ items=%d",
      assetId,
      count
    )
    return true
  }

  /// After AVQueuePlayer auto-advance: retarget activeAssetId without play()/replace.
  func adoptQueueCurrentItem(assetId: String) {
    lock.lock()
    let previousId = activeAssetId
    if let previousId, previousId != assetId {
      playersByAssetId.removeValue(forKey: previousId)
    }
    activeAssetId = assetId
    if let active = activePlayer {
      playersByAssetId[assetId] = active
    }
    lock.unlock()
    NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
  }

  var activeQueueItemCount: Int {
    lock.lock(); defer { lock.unlock() }
    return (activePlayer as? AVQueuePlayer)?.items().count ?? 0
  }

  var activePlayerIsQueue: Bool {
    lock.lock(); defer { lock.unlock() }
    return activePlayer is AVQueuePlayer
  }

  func setUseTextureSurface(_ enabled: Bool) {
    useTextureSurface = enabled
    if !enabled {
      DispatchQueue.main.async { self.detachActiveTexture() }
    }
  }

  var isUsingTextureSurface: Bool { useTextureSurface }

  func player(for assetId: String) -> AVPlayer? {
    lock.lock(); defer { lock.unlock() }
    return playersByAssetId[assetId]
  }

  func attachActive(
    assetId: String,
    completion: @escaping (Result<Int64, Error>) -> Void
  ) {
    beginFirstFrameMeasurement(assetId: assetId)

    lock.lock()
    // Foreground restore guard: adopt existing player — no stop/recreate.
    if Poc04LockAudioProbe.shared.isRestoreGuardActive, let player = activePlayer {
      let id = activeAssetId ?? assetId
      lock.unlock()
      finishActiveAttach(assetId: id, player: player, completion: completion)
      return
    }
    if activeAssetId == assetId, let player = activePlayer {
      lock.unlock()
      if Poc04LockAudioProbe.shared.isEnabled, !(player is AVQueuePlayer) {
        ensureActiveIsQueuePlayerForLockProbe { [weak self] in
          guard let self, let q = self.activePlayer else {
            completion(
              .failure(
                PigeonError(
                  code: "assetUnavailable",
                  message: "Queue upgrade failed",
                  details: nil
                )
              )
            )
            return
          }
          self.finishActiveAttach(assetId: assetId, player: q, completion: completion)
        }
        return
      }
      finishActiveAttach(assetId: assetId, player: player, completion: completion)
      return
    }
    // Warming promotion — disabled during lock probe (would replace AVQueuePlayer
    // with a single-item / plain player and wipe the lookahead queue).
    if !Poc04LockAudioProbe.shared.isEnabled,
       warmingAssetId == assetId,
       let warm = warmingPlayer {
      let previousActiveId = activeAssetId
      let previousActive = activePlayer
      activeAssetId = assetId
      activePlayer = warm
      warmingAssetId = nil
      warmingPlayer = nil
      if let previousActiveId, let previousActive, previousActiveId != assetId {
        previousActive.pause()
        playersByAssetId.removeValue(forKey: previousActiveId)
      }
      playersByAssetId[assetId] = warm
      lock.unlock()
      finishActiveAttach(assetId: assetId, player: warm, completion: completion)
      return
    }
    lock.unlock()

    releaseSlot(isActive: true)
    requestPlayer(for: assetId) { [weak self] result in
      guard let self else { return }
      switch result {
      case .failure(let error):
        completion(.failure(error))
      case .success(let player):
        self.lock.lock()
        if let oldId = self.activeAssetId, oldId != assetId, let old = self.activePlayer {
          old.pause()
          self.playersByAssetId.removeValue(forKey: oldId)
        }
        self.activeAssetId = assetId
        self.activePlayer = player
        player.isMuted = true
        self.playersByAssetId[assetId] = player
        self.lock.unlock()
        self.finishActiveAttach(assetId: assetId, player: player, completion: completion)
      }
    }
  }

  /// Completes attach only after texture register (Texture mode) or with -1 (PV).
  private func finishActiveAttach(
    assetId: String,
    player: AVPlayer,
    completion: @escaping (Result<Int64, Error>) -> Void
  ) {
    let run = { [weak self] in
      guard let self else { return }
      if self.useTextureSurface {
        guard let registry = self.textureRegistry else {
          completion(
            .failure(
              PigeonError(
                code: "exportFailed",
                message: "FlutterTextureRegistry not configured",
                details: nil
              )
            )
          )
          return
        }
        self.detachActiveTexture()
        let tex = Poc04ActiveVideoTexture(registry: registry)
        tex.onFirstFrame = { [weak self] in
          self?.completeFirstFrameIfNeeded()
        }
        // Ordering: register finishes inside attach before id is returned.
        let textureId = tex.attach(player: player)
        self.activeTexture = tex
        NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
        completion(.success(textureId))
      } else {
        self.detachActiveTexture()
        NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
        completion(.success(-1))
      }
      if Poc04LockAudioProbe.shared.isEnabled {
        Poc04LockAudioProbe.shared.onActiveAttached(assetId: assetId)
      }
    }
    if Thread.isMainThread {
      run()
    } else {
      DispatchQueue.main.async(execute: run)
    }
  }

  private func detachActiveTexture() {
    activeTexture?.detach()
    activeTexture = nil
  }

  func attachWarming(
    assetId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    // Lock probe owns lookahead via AVQueuePlayer.insert — a separate warming
    // AVPlayer would later be promoted and wipe the queue (queueItems→0).
    if Poc04LockAudioProbe.shared.isEnabled {
      completion(.success(()))
      return
    }
    lock.lock()
    if activeAssetId == assetId {
      lock.unlock()
      completion(.success(()))
      return
    }
    if warmingAssetId == assetId, warmingPlayer != nil {
      lock.unlock()
      completion(.success(()))
      return
    }
    lock.unlock()

    releaseSlot(isActive: false)
    requestPlayer(for: assetId) { [weak self] result in
      guard let self else { return }
      switch result {
      case .failure(let error):
        completion(.failure(error))
      case .success(let player):
        self.lock.lock()
        if let oldId = self.warmingAssetId, oldId != assetId {
          self.playersByAssetId.removeValue(forKey: oldId)
        }
        self.warmingAssetId = assetId
        self.warmingPlayer = player
        player.isMuted = true
        player.pause()
        self.playersByAssetId[assetId] = player
        self.lock.unlock()
        // T2=A: do not register Flutter texture for warming.
        NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
        completion(.success(()))
      }
    }
  }

  func playActive() {
    lock.lock()
    let player = activePlayer
    let rate = player?.rate ?? 0
    lock.unlock()
    let probeOn = Poc04LockAudioProbe.shared.isEnabled
    player?.isMuted = !probeOn
    // Restore window: do not restart an already-playing adopted player.
    if Poc04LockAudioProbe.shared.isRestoreGuardActive, rate > 0.01 {
      return
    }
    player?.play()
  }

  func pauseActive() {
    lock.lock()
    let player = activePlayer
    lock.unlock()
    player?.pause()
  }

  func releaseVideo(assetId: String) {
    // Foreground restore guard: never tear down the active adopted player.
    if Poc04LockAudioProbe.shared.isRestoreGuardActive {
      if activeAssetIdValue == assetId { return }
      // Also skip releasing non-active ids during restore — concurrent page
      // apply can race with jumpToPage and deallocate the queue mid-reattach.
      return
    }
    // While lock probe is on, never deallocate the active AVQueuePlayer via
    // release of a "stale" id — Dart page apply releases every other video.
    if Poc04LockAudioProbe.shared.isEnabled,
       activeAssetIdValue == assetId {
      return
    }
    lock.lock()
    let wasActive = activeAssetId == assetId
    if wasActive {
      activePlayer?.pause()
      activePlayer = nil
      activeAssetId = nil
      playersByAssetId.removeValue(forKey: assetId)
      cancelRequest(&activeItemRequestId)
    }
    if warmingAssetId == assetId {
      warmingPlayer?.pause()
      warmingPlayer = nil
      warmingAssetId = nil
      playersByAssetId.removeValue(forKey: assetId)
      cancelRequest(&warmingItemRequestId)
    }
    lock.unlock()
    if wasActive {
      DispatchQueue.main.async { self.detachActiveTexture() }
    }
    NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
  }

  func releaseAll() {
    lock.lock()
    activePlayer?.pause()
    warmingPlayer?.pause()
    activePlayer = nil
    warmingPlayer = nil
    activeAssetId = nil
    warmingAssetId = nil
    playersByAssetId.removeAll()
    prefetchedItems.removeAll()
    cancelRequest(&activeItemRequestId)
    cancelRequest(&warmingItemRequestId)
    cancelRequest(&prefetchRequestId)
    lock.unlock()
    DispatchQueue.main.async { self.detachActiveTexture() }
    NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: nil)
  }

  private func releaseSlot(isActive: Bool) {
    lock.lock()
    if isActive {
      if let id = activeAssetId {
        activePlayer?.pause()
        playersByAssetId.removeValue(forKey: id)
      }
      activePlayer = nil
      activeAssetId = nil
      cancelRequest(&activeItemRequestId)
    } else {
      if let id = warmingAssetId {
        warmingPlayer?.pause()
        if id != activeAssetId {
          playersByAssetId.removeValue(forKey: id)
        }
      }
      warmingPlayer = nil
      warmingAssetId = nil
      cancelRequest(&warmingItemRequestId)
    }
    lock.unlock()
    if isActive {
      DispatchQueue.main.async { self.detachActiveTexture() }
    }
  }

  private func cancelRequest(_ requestId: inout PHImageRequestID) {
    if requestId != PHInvalidImageRequestID {
      PHImageManager.default().cancelImageRequest(requestId)
      requestId = PHInvalidImageRequestID
    }
  }

  private func requestPlayer(
    for assetId: String,
    completion: @escaping (Result<AVPlayer, Error>) -> Void
  ) {
    requestPlayerItem(for: assetId) { result in
      switch result {
      case .failure(let error):
        completion(.failure(error))
      case .success(let item):
        let player: AVPlayer
        if Poc04LockAudioProbe.shared.isEnabled {
          let q = AVQueuePlayer(playerItem: item)
          q.actionAtItemEnd = .advance
          player = q
        } else {
          player = AVPlayer(playerItem: item)
        }
        player.isMuted = true
        completion(.success(player))
      }
    }
  }

  private func requestPlayerItem(
    for assetId: String,
    completion: @escaping (Result<AVPlayerItem, Error>) -> Void
  ) {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = assets.firstObject, asset.mediaType == .video else {
      completion(
        .failure(
          PigeonError(
            code: "assetUnavailable",
            message: "Video PHAsset not found for \(assetId)",
            details: nil
          )
        )
      )
      return
    }

    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .automatic

    PHImageManager.default().requestPlayerItem(
      forVideo: asset,
      options: options
    ) { item, info in
      let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
      let error = info?[PHImageErrorKey] as? Error
      let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
      if cancelled {
        completion(
          .failure(
            PigeonError(
              code: "assetUnavailable",
              message: "Video request cancelled",
              details: nil
            )
          )
        )
        return
      }
      if let error {
        completion(.failure(error))
        return
      }
      if inCloud && item == nil {
        completion(
          .failure(
            PigeonError(
              code: "assetUnavailable",
              message: "Video not local (iCloud)",
              details: nil
            )
          )
        )
        return
      }
      guard let item else {
        completion(
          .failure(
            PigeonError(
              code: "assetUnavailable",
              message: "No AVPlayerItem",
              details: nil
            )
          )
        )
        return
      }
      completion(.success(item))
    }
  }

  // MARK: First-frame measurement

  func clearFirstFrameSamples() {
    lock.lock()
    firstFrameSamples.removeAll()
    lock.unlock()
  }

  func getFirstFrameSamples() -> [Double] {
    lock.lock(); defer { lock.unlock() }
    return firstFrameSamples
  }

  func beginFirstFrameMeasurement(assetId: String) {
    lock.lock()
    firstFrameTimeoutWork?.cancel()
    firstFrameTimeoutWork = nil
    readyObservation?.invalidate()
    readyObservation = nil
    firstFrameT0 = CACurrentMediaTime()
    firstFrameAssetId = assetId
    firstFrameMsResult = nil
    lock.unlock()
  }

  /// PV mode: Platform View reports layer readiness.
  func noteActivePlayerLayer(assetId: String, layer: AVPlayerLayer) {
    guard !useTextureSurface else { return }
    lock.lock()
    guard assetId == firstFrameAssetId, firstFrameMsResult == nil else {
      lock.unlock()
      return
    }
    lock.unlock()

    if layer.isReadyForDisplay {
      completeFirstFrameIfNeeded()
      return
    }

    readyObservation?.invalidate()
    readyObservation = layer.observe(\.isReadyForDisplay, options: [.new]) {
      [weak self] layer, _ in
      guard let self else { return }
      if layer.isReadyForDisplay {
        self.completeFirstFrameIfNeeded()
      }
    }
  }

  func waitActiveFirstFrameMs(
    timeoutMs: Int64,
    completion: @escaping (Result<Double, Error>) -> Void
  ) {
    lock.lock()
    if let result = firstFrameMsResult {
      lock.unlock()
      completion(.success(result))
      return
    }
    firstFrameWaiters.append(completion)
    let timeout = max(1, Int(timeoutMs))
    lock.unlock()

    let work = DispatchWorkItem { [weak self] in
      self?.completeFirstFrame(ms: Double(timeout), fromTimeout: true)
    }
    lock.lock()
    firstFrameTimeoutWork?.cancel()
    firstFrameTimeoutWork = work
    lock.unlock()
    DispatchQueue.main.asyncAfter(
      deadline: .now() + .milliseconds(timeout),
      execute: work
    )
  }

  func completeFirstFrameIfNeeded() {
    lock.lock()
    guard firstFrameMsResult == nil, let t0 = firstFrameT0 else {
      lock.unlock()
      return
    }
    let ms = (CACurrentMediaTime() - t0) * 1000.0
    lock.unlock()
    completeFirstFrame(ms: ms, fromTimeout: false)
  }

  private func completeFirstFrame(ms: Double, fromTimeout: Bool) {
    lock.lock()
    if firstFrameMsResult != nil {
      lock.unlock()
      return
    }
    firstFrameTimeoutWork?.cancel()
    firstFrameTimeoutWork = nil
    readyObservation?.invalidate()
    readyObservation = nil
    firstFrameMsResult = ms
    firstFrameSamples.append(ms)
    let waiters = firstFrameWaiters
    firstFrameWaiters.removeAll()
    lock.unlock()

    for waiter in waiters {
      waiter(.success(ms))
    }
    _ = fromTimeout
  }
}

extension Notification.Name {
  static let poc04PlayerPoolDidChange = Notification.Name("poc04PlayerPoolDidChange")
}
