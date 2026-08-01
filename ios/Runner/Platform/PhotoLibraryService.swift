import Foundation
import Photos
import PhotosUI
import UIKit

/// Production PhotoLibraryApi host (Capability 5.2+).
///
/// Authorization and limited-picker use live PhotoKit reads at call time
/// (no Dart-cached status) to avoid TOCTOU. Library catalog helpers require
/// `.authorized` or `.limited` before returning data.
final class PhotoLibraryService: PhotoLibraryApi {
  /// Upper bound for [fetchLibraryPage] pageSize (host clamp).
  private static let maxPageSize: Int = 500

  private func fail(_ code: ErrorCode, message: String) -> PigeonError {
    PigeonError(code: codeName(code), message: message, details: nil)
  }

  private func codeName(_ code: ErrorCode) -> String {
    String(describing: code)
  }

  private func mapStatus(_ status: PHAuthorizationStatus) -> AuthStatus {
    switch status {
    case .notDetermined:
      return .notDetermined
    case .restricted:
      return .restricted
    case .denied:
      return .denied
    case .authorized:
      return .authorized
    case .limited:
      return .limited
    @unknown default:
      return .denied
    }
  }

  private func currentPhotoKitStatus() -> PHAuthorizationStatus {
    PHPhotoLibrary.authorizationStatus(for: .readWrite)
  }

  /// Live PhotoKit check — never trust a caller-supplied status.
  private func requireLibraryAccess() throws {
    switch currentPhotoKitStatus() {
    case .authorized, .limited:
      return
    case .notDetermined, .denied, .restricted:
      throw fail(
        .unauthorized,
        message: "Photo library access is not granted"
      )
    @unknown default:
      throw fail(
        .unauthorized,
        message: "Photo library access is not granted"
      )
    }
  }

  // MARK: - Shared catalog fetch options (Cap 5.4)

  /// Single construction site for library enumeration options.
  ///
  /// Used by both [libraryTotals] and [fetchLibraryPage] so inclusion / sort
  /// cannot drift. Default PhotoKit semantics (Hidden + Recently Deleted
  /// excluded). Sort: creationDate descending; nil dates sort last under
  /// Cocoa descending NSSortDescriptor. No device-local filter.
  private func makeLibraryFetchOptions() -> PHFetchOptions {
    let options = PHFetchOptions()
    options.sortDescriptors = [
      NSSortDescriptor(key: "creationDate", ascending: false),
    ]
    return options
  }

  /// Catalog universe matching totals: images (incl. Live) + videos only.
  private func fetchCatalogAssets() -> PHFetchResult<PHAsset> {
    let options = makeLibraryFetchOptions()
    options.predicate = NSPredicate(
      format: "mediaType == %d OR mediaType == %d",
      PHAssetMediaType.image.rawValue,
      PHAssetMediaType.video.rawValue
    )
    return PHAsset.fetchAssets(with: options)
  }

  private func mapMediaKind(_ asset: PHAsset) -> MediaKind {
    switch asset.mediaType {
    case .image:
      if asset.mediaSubtypes.contains(.photoLive) {
        return .livePhoto
      }
      return .image
    case .video:
      return .video
    default:
      return .unknown
    }
  }

  /// List-time availability only — never fabricates `.downloading` (2A).
  private func mapAvailability(_ asset: PHAsset) -> AssetAvailabilityDto {
    if asset.isLocallyAvailable {
      return .deviceLocal
    }
    return .iCloudNotDownloaded
  }

  private func mapAsset(_ asset: PHAsset) -> LibraryAssetDto {
    let ms: Int64?
    if let date = asset.creationDate {
      ms = Int64((date.timeIntervalSince1970 * 1000.0).rounded())
    } else {
      ms = nil
    }
    return LibraryAssetDto(
      assetIdentifier: asset.localIdentifier,
      mediaKind: mapMediaKind(asset),
      availability: mapAvailability(asset),
      creationDateMs: ms
    )
  }

  private func parseCursor(_ cursor: String?) throws -> Int {
    guard let cursor, !cursor.isEmpty else {
      return 0
    }
    guard let index = Int(cursor), index >= 0 else {
      throw fail(.unknown, message: "Invalid library page cursor")
    }
    return index
  }

  private func clampPageSize(_ pageSize: Int64) -> Int {
    let raw = Int(pageSize)
    if raw < 1 {
      return 1
    }
    if raw > Self.maxPageSize {
      return Self.maxPageSize
    }
    return raw
  }

  private func topViewController(
    from root: UIViewController
  ) -> UIViewController {
    if let presented = root.presentedViewController {
      return topViewController(from: presented)
    }
    if let nav = root as? UINavigationController, let visible = nav.visibleViewController {
      return topViewController(from: visible)
    }
    if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(from: selected)
    }
    return root
  }

  private func rootViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap {
      $0 as? UIWindowScene
    }
    for scene in scenes {
      let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
      if let root = window?.rootViewController {
        return topViewController(from: root)
      }
    }
    return nil
  }

  func authorizationStatus() throws -> AuthStatus {
    mapStatus(currentPhotoKitStatus())
  }

  func requestAuthorization(
    completion: @escaping (Result<AuthStatus, Error>) -> Void
  ) {
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      completion(.success(self.mapStatus(status)))
    }
  }

  func presentLimitedLibraryPicker(
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let status = currentPhotoKitStatus()
    guard status == .limited else {
      completion(.success(()))
      return
    }
    DispatchQueue.main.async {
      guard let host = self.rootViewController() else {
        completion(
          .failure(
            self.fail(
              .unknown,
              message: "No root view controller for limited library picker"
            )
          )
        )
        return
      }
      PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: host)
      completion(.success(()))
    }
  }

  func libraryTotals(
    completion: @escaping (Result<LibraryTotalsDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      let options = makeLibraryFetchOptions()
      let photos = PHAsset.fetchAssets(with: .image, options: options).count
      let videos = PHAsset.fetchAssets(with: .video, options: options).count
      completion(
        .success(
          LibraryTotalsDto(
            all: Int64(photos + videos),
            photos: Int64(photos),
            videos: Int64(videos)
          )
        )
      )
    } catch {
      completion(.failure(error))
    }
  }

  func fetchLibraryPage(
    cursor: String?,
    pageSize: Int64,
    completion: @escaping (Result<LibraryPageDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      let start = try parseCursor(cursor)
      let limit = clampPageSize(pageSize)
      let result = fetchCatalogAssets()
      let count = result.count
      if start >= count {
        completion(
          .success(LibraryPageDto(assets: [], nextCursor: nil))
        )
        return
      }
      let end = min(start + limit, count)
      var assets: [LibraryAssetDto] = []
      assets.reserveCapacity(end - start)
      for index in start..<end {
        assets.append(mapAsset(result.object(at: index)))
      }
      let next: String? = end < count ? String(end) : nil
      completion(
        .success(LibraryPageDto(assets: assets, nextCursor: next))
      )
    } catch {
      completion(.failure(error))
    }
  }

  func listAssetSources() throws -> [AssetSourceDto] {
    try requireLibraryAccess()
    // Album / source enumeration is the next capability — not Cap 5.4.
    return []
  }

  func resolveSource(
    sourceReference: SourceReferenceDto,
    completion: @escaping (Result<ResolvedSourceDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      completion(
        .success(
          ResolvedSourceDto(
            sourceIdentifier: sourceReference.sourceIdentifier,
            assetIdentifiers: []
          )
        )
      )
    } catch {
      completion(.failure(error))
    }
  }

  func requestDisplayAsset(
    assetIdentifier: String,
    completion: @escaping (Result<DisplayAssetDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      completion(
        .success(
          DisplayAssetDto(
            assetIdentifier: assetIdentifier,
            mediaKind: .unknown,
            pixelWidth: nil,
            pixelHeight: nil
          )
        )
      )
    } catch {
      completion(.failure(error))
    }
  }

  func requestPlayableVideo(
    assetIdentifier: String,
    completion: @escaping (Result<PlayableVideoDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      completion(
        .success(
          PlayableVideoDto(
            assetIdentifier: assetIdentifier,
            durationSeconds: nil
          )
        )
      )
    } catch {
      completion(.failure(error))
    }
  }

  func createAlbum(
    name: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    completion(
      .failure(
        fail(.albumUnavailable, message: "stub: createAlbum not implemented")
      )
    )
  }

  func importVideo(
    tempFilePath: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    completion(
      .failure(
        fail(
          .photosImportFailed,
          message: "stub: importVideo not implemented"
        )
      )
    )
  }

  func addAssetToAlbum(
    assetIdentifier: String,
    albumIdentifier: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    completion(
      .failure(
        fail(
          .albumNotWritable,
          message: "stub: addAssetToAlbum not implemented"
        )
      )
    )
  }
}
