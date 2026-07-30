import Flutter
import Foundation
import Photos

/// POC-04 spike host for Photos authorization and local asset listing.
final class Poc04PhotoLibraryHost: Poc04PhotoLibraryApi {
  func requestAuthorization(completion: @escaping (Result<Poc04AuthStatus, Error>) -> Void) {
    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        DispatchQueue.main.async {
          completion(.success(Self.mapAuthStatus(status)))
        }
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        DispatchQueue.main.async {
          completion(.success(Self.mapAuthStatus(status)))
        }
      }
    }
  }

  func getAuthorizationStatus() throws -> Poc04AuthStatus {
    if #available(iOS 14, *) {
      return Self.mapAuthStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }
    return Self.mapAuthStatus(PHPhotoLibrary.authorizationStatus())
  }

  func listLocalMixedAssets(limit: Int64) throws -> [Poc04AssetDto] {
    let authorized: Bool
    if #available(iOS 14, *) {
      let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
      authorized = status == .authorized || status == .limited
    } else {
      authorized = PHPhotoLibrary.authorizationStatus() == .authorized
    }
    guard authorized else {
      throw PigeonError(
        code: "unauthorized",
        message: "Photos authorization required before listing assets",
        details: nil
      )
    }

    let cappedLimit = max(0, Int(limit))
    guard cappedLimit > 0 else { return [] }

    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    options.includeHiddenAssets = false
    options.predicate = NSPredicate(
      format: "mediaType == %d OR mediaType == %d",
      PHAssetMediaType.image.rawValue,
      PHAssetMediaType.video.rawValue
    )

    let fetchResult = PHAsset.fetchAssets(with: options)
    var results: [Poc04AssetDto] = []
    results.reserveCapacity(min(cappedLimit, fetchResult.count))

    fetchResult.enumerateObjects { asset, _, stop in
      if results.count >= cappedLimit {
        stop.pointee = true
        return
      }
      guard Self.isDeviceLocal(asset) else { return }
      guard let mediaType = Self.mapMediaType(asset.mediaType) else { return }

      let durationSeconds: Double? =
        mediaType == .video ? asset.duration : nil

      results.append(
        Poc04AssetDto(
          assetId: asset.localIdentifier,
          mediaType: mediaType,
          pixelWidth: Int64(asset.pixelWidth),
          pixelHeight: Int64(asset.pixelHeight),
          durationSeconds: durationSeconds
        )
      )
    }

    return results
  }

  private static func mapAuthStatus(_ status: PHAuthorizationStatus) -> Poc04AuthStatus {
    switch status {
    case .notDetermined:
      return .notDetermined
    case .authorized:
      return .authorized
    case .denied:
      return .denied
    case .restricted:
      return .restricted
    default:
      if #available(iOS 14, *), status == .limited {
        return .limited
      }
      return .denied
    }
  }

  private static func mapMediaType(_ type: PHAssetMediaType) -> Poc04MediaType? {
    switch type {
    case .image:
      return .image
    case .video:
      return .video
    default:
      return nil
    }
  }

  /// Skip iCloud-only assets: probe with `isNetworkAccessAllowed = false`.
  /// (Avoids `PHAssetResource.isLocallyAvailable`, which is SDK/OS gated.)
  private static func isDeviceLocal(_ asset: PHAsset) -> Bool {
    if asset.mediaType == .image {
      // Prefer image data probe — 1×1 requestImage often false-negatives on
      // HEIC / optimized libraries even when a local representation exists.
      let dataOptions = PHImageRequestOptions()
      dataOptions.isSynchronous = true
      dataOptions.isNetworkAccessAllowed = false
      dataOptions.deliveryMode = .fastFormat

      var isLocal = false
      PHImageManager.default().requestImageDataAndOrientation(
        for: asset,
        options: dataOptions
      ) { data, _, _, info in
        let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
        let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
        let error = info?[PHImageErrorKey]
        isLocal = data != nil && !inCloud && !cancelled && error == nil
      }
      if isLocal { return true }

      let options = PHImageRequestOptions()
      options.isSynchronous = true
      options.isNetworkAccessAllowed = false
      options.deliveryMode = .fastFormat
      options.resizeMode = .fast

      PHImageManager.default().requestImage(
        for: asset,
        targetSize: CGSize(width: 32, height: 32),
        contentMode: .aspectFit,
        options: options
      ) { image, info in
        let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
        let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
        let error = info?[PHImageErrorKey]
        isLocal = image != nil && !inCloud && !cancelled && error == nil
      }
      return isLocal
    }

    if asset.mediaType == .video {
      let options = PHVideoRequestOptions()
      options.isNetworkAccessAllowed = false
      let semaphore = DispatchSemaphore(value: 0)
      var isLocal = false
      PHImageManager.default().requestAVAsset(
        forVideo: asset,
        options: options
      ) { avAsset, _, info in
        let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
        isLocal = avAsset != nil && !inCloud
        semaphore.signal()
      }
      _ = semaphore.wait(timeout: .now() + 2.0)
      return isLocal
    }

    return false
  }
}
