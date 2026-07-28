import AVFoundation
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

  /// Views observe this to bind AVPlayerLayer when their asset becomes active.
  private(set) var playersByAssetId: [String: AVPlayer] = [:]

  var activeCount: Int {
    lock.lock(); defer { lock.unlock() }
    return activePlayer != nil ? 1 : 0
  }

  var warmingCount: Int {
    lock.lock(); defer { lock.unlock() }
    return warmingPlayer != nil ? 1 : 0
  }

  func player(for assetId: String) -> AVPlayer? {
    lock.lock(); defer { lock.unlock() }
    return playersByAssetId[assetId]
  }

  func attachActive(
    assetId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    lock.lock()
    if activeAssetId == assetId, activePlayer != nil {
      lock.unlock()
      completion(.success(()))
      return
    }
    // Warming promotion.
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
      NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
      completion(.success(()))
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
        // Drop previous active if any raced in.
        if let oldId = self.activeAssetId, oldId != assetId, let old = self.activePlayer {
          old.pause()
          self.playersByAssetId.removeValue(forKey: oldId)
        }
        self.activeAssetId = assetId
        self.activePlayer = player
        player.isMuted = true
        self.playersByAssetId[assetId] = player
        self.lock.unlock()
        NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
        completion(.success(()))
      }
    }
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
        // Never exceed 1+1: if somehow active missing still ok.
        self.warmingAssetId = assetId
        self.warmingPlayer = player
        player.isMuted = true
        player.pause()
        self.playersByAssetId[assetId] = player
        self.lock.unlock()
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
    if activeAssetId == assetId {
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
        // Keep in map only if also active (shouldn't happen).
        if id != activeAssetId {
          playersByAssetId.removeValue(forKey: id)
        }
      }
      warmingPlayer = nil
      warmingAssetId = nil
      cancelRequest(&warmingItemRequestId)
    }
    lock.unlock()
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
}

extension Notification.Name {
  static let poc04PlayerPoolDidChange = Notification.Name("poc04PlayerPoolDidChange")
}
