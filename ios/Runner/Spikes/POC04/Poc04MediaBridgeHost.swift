import Flutter
import Foundation
import Photos
import UIKit

/// POC-04 spike host: image temp export + AVPlayer pool bridge.
final class Poc04MediaBridgeHost: Poc04MediaBridgeApi {
  private let imageManager = PHCachingImageManager()
  private var tempPaths = Set<String>()
  private let tempLock = NSLock()
  private let tempDirectory: URL = {
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("poc04_img", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    // Best-effort cleanup of prior spike leftovers.
    if let files = try? FileManager.default.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: nil
    ) {
      for file in files {
        try? FileManager.default.removeItem(at: file)
      }
    }
    return root
  }()

  func resolveImageTempFile(
    assetId: String,
    maxLongEdge: Int64,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = assets.firstObject, asset.mediaType == .image else {
      completion(
        .failure(
          PigeonError(
            code: "assetUnavailable",
            message: "Image PHAsset not found for \(assetId)",
            details: nil
          )
        )
      )
      return
    }

    let edge = max(1, Int(maxLongEdge))
    let target = Self.targetSize(for: asset, maxLongEdge: edge)
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    options.isSynchronous = false

    imageManager.requestImage(
      for: asset,
      targetSize: target,
      contentMode: .aspectFit,
      options: options
    ) { [weak self] image, info in
      guard let self else { return }
      let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
      let error = info?[PHImageErrorKey] as? Error
      let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
      if cancelled {
        completion(
          .failure(
            PigeonError(
              code: "exportFailed",
              message: "Image request cancelled",
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
      // Wait for full-quality delivery when possible.
      if degraded {
        return
      }
      guard let image else {
        completion(
          .failure(
            PigeonError(
              code: "exportFailed",
              message: "No UIImage from Photos",
              details: nil
            )
          )
        )
        return
      }

      guard let data = image.jpegData(compressionQuality: 0.9) else {
        completion(
          .failure(
            PigeonError(
              code: "exportFailed",
              message: "JPEG encode failed",
              details: nil
            )
          )
        )
        return
      }

      let filename = "\(UUID().uuidString).jpg"
      let url = self.tempDirectory.appendingPathComponent(filename)
      do {
        try data.write(to: url, options: .atomic)
        let path = url.path
        self.tempLock.lock()
        self.tempPaths.insert(path)
        self.tempLock.unlock()
        completion(.success(path))
      } catch {
        completion(
          .failure(
            PigeonError(
              code: "exportFailed",
              message: "Temp write failed: \(error.localizedDescription)",
              details: nil
            )
          )
        )
      }
    }
  }

  func releaseImageTempFile(path: String) throws {
    tempLock.lock()
    tempPaths.remove(path)
    tempLock.unlock()
    try? FileManager.default.removeItem(atPath: path)
  }

  func releaseAllImageTempFiles() throws {
    tempLock.lock()
    let paths = tempPaths
    tempPaths.removeAll()
    tempLock.unlock()
    for path in paths {
      try? FileManager.default.removeItem(atPath: path)
    }
  }

  func prefetchNeighbors(assetIds: [String]) throws {
    guard !assetIds.isEmpty else { return }
    let result = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
    var assets: [PHAsset] = []
    result.enumerateObjects { asset, _, _ in
      assets.append(asset)
    }
    let target = CGSize(width: 1080, height: 1080)
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.resizeMode = .fast
    imageManager.startCachingImages(
      for: assets,
      targetSize: target,
      contentMode: .aspectFit,
      options: options
    )
  }

  func attachActiveVideo(
    assetId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    Poc04PlayerPool.shared.attachActive(assetId: assetId, completion: completion)
  }

  func attachWarmingVideo(
    assetId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    Poc04PlayerPool.shared.attachWarming(assetId: assetId, completion: completion)
  }

  func playActive() throws {
    Poc04PlayerPool.shared.playActive()
  }

  func pauseActive() throws {
    Poc04PlayerPool.shared.pauseActive()
  }

  func releaseVideo(assetId: String) throws {
    Poc04PlayerPool.shared.releaseVideo(assetId: assetId)
  }

  func releaseAllVideos() throws {
    Poc04PlayerPool.shared.releaseAll()
  }

  func getPoolDiagnostics() throws -> Poc04PoolDiagnostics {
    tempLock.lock()
    let tempCount = tempPaths.count
    tempLock.unlock()
    return Poc04PoolDiagnostics(
      activeCount: Int64(Poc04PlayerPool.shared.activeCount),
      warmingCount: Int64(Poc04PlayerPool.shared.warmingCount),
      tempFileCount: Int64(tempCount)
    )
  }

  private static func targetSize(for asset: PHAsset, maxLongEdge: Int) -> CGSize {
    let w = max(asset.pixelWidth, 1)
    let h = max(asset.pixelHeight, 1)
    let longEdge = max(w, h)
    if longEdge <= maxLongEdge {
      return CGSize(width: w, height: h)
    }
    let scale = CGFloat(maxLongEdge) / CGFloat(longEdge)
    return CGSize(
      width: CGFloat(w) * scale,
      height: CGFloat(h) * scale
    )
  }
}
