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

  func configure(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
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
    if activeAssetId == assetId, let player = activePlayer {
      lock.unlock()
      finishActiveAttach(assetId: assetId, player: player, completion: completion)
      return
    }
    // Warming promotion (T2=A: warming had no texture).
    if warmingAssetId == assetId, let warm = warmingPlayer {
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
    lock.unlock()
    player?.isMuted = true
    player?.play()
  }

  func pauseActive() {
    lock.lock()
    let player = activePlayer
    lock.unlock()
    player?.pause()
  }

  func releaseVideo(assetId: String) {
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
    cancelRequest(&activeItemRequestId)
    cancelRequest(&warmingItemRequestId)
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
      let player = AVPlayer(playerItem: item)
      player.isMuted = true
      completion(.success(player))
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
