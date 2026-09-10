import AVFoundation
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

  /// Layer 1 preview: `PHImageManager` targetSize bounding box (pixels).
  /// Cap 15.6 / ADR-031 Q1=A1: 512×512 (was 1080; local-only hit rate).
  private static let previewTargetSize = CGSize(width: 512, height: 512)
  private static let previewJpegQuality: CGFloat = 0.8

  private let previewRequests = PreviewImageRequestTable()
  private let displayRequests = PhotoKitRequestTable<PreviewCompletion>()
  private let playableRequests = PhotoKitRequestTable<PlayableCompletion>()
  private let previewEncodeQueue = DispatchQueue(
    label: "com.dennycgan.waketok.preview.encode"
  )
  private let displayWriteQueue = DispatchQueue(
    label: "com.dennycgan.waketok.display.write"
  )

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

  // MARK: - Shared library fetch (Cap 5.4 + Cap 6)

  /// Single construction site for library enumeration options.
  ///
  /// Used by totals, paging, built-in list, and resolve so inclusion / sort
  /// cannot drift. Default PhotoKit semantics (Hidden + Recently Deleted
  /// excluded — `includeHiddenAssets` remains false). Sort: creationDate
  /// descending; nil dates sort last under Cocoa descending
  /// NSSortDescriptor. No device-local filter.
  private func makeLibraryFetchOptions() -> PHFetchOptions {
    let options = PHFetchOptions()
    options.sortDescriptors = [
      NSSortDescriptor(key: "creationDate", ascending: false),
    ]
    return options
  }

  /// Cap 11.3 album/smartAlbum resolve: same sort + Hidden default as
  /// [makeLibraryFetchOptions], plus image|video predicate (All universe).
  private func makeAlbumAssetFetchOptions() -> PHFetchOptions {
    let options = makeLibraryFetchOptions()
    options.predicate = NSPredicate(
      format: "mediaType == %d OR mediaType == %d",
      PHAssetMediaType.image.rawValue,
      PHAssetMediaType.video.rawValue
    )
    return options
  }

  /// Photos universe: still images + Live Photos (matches libraryTotals.photos).
  private func photosFetchResult() -> PHFetchResult<PHAsset> {
    PHAsset.fetchAssets(with: .image, options: makeLibraryFetchOptions())
  }

  /// Videos universe (matches libraryTotals.videos).
  private func videosFetchResult() -> PHFetchResult<PHAsset> {
    PHAsset.fetchAssets(with: .video, options: makeLibraryFetchOptions())
  }

  /// All = image OR video (matches libraryTotals.all / catalog paging).
  private func allFetchResult() -> PHFetchResult<PHAsset> {
    let options = makeLibraryFetchOptions()
    options.predicate = NSPredicate(
      format: "mediaType == %d OR mediaType == %d",
      PHAssetMediaType.image.rawValue,
      PHAssetMediaType.video.rawValue
    )
    return PHAsset.fetchAssets(with: options)
  }

  /// Catalog universe matching totals: images (incl. Live) + videos only.
  private func fetchCatalogAssets() -> PHFetchResult<PHAsset> {
    allFetchResult()
  }

  // MARK: - Built-in source resolution (Cap 6 / ADR-013)

  private static let builtinIdAll = "all"
  private static let builtinIdPhotos = "photos"
  private static let builtinIdVideos = "videos"

  private enum BuiltinSource {
    case entireLibrary
    case mediaTypePhotos
    case mediaTypeVideos

    var kind: AssetSourceKind {
      switch self {
      case .entireLibrary: return .entireLibrary
      case .mediaTypePhotos: return .mediaTypePhotos
      case .mediaTypeVideos: return .mediaTypeVideos
      }
    }

    var sourceType: String {
      switch self {
      case .entireLibrary: return "entireLibrary"
      case .mediaTypePhotos: return "mediaTypePhotos"
      case .mediaTypeVideos: return "mediaTypeVideos"
      }
    }

    var sourceIdentifier: String {
      switch self {
      case .entireLibrary: return PhotoLibraryService.builtinIdAll
      case .mediaTypePhotos: return PhotoLibraryService.builtinIdPhotos
      case .mediaTypeVideos: return PhotoLibraryService.builtinIdVideos
      }
    }
  }

  /// Exactly three legal (sourceType, sourceIdentifier) pairs.
  private func builtinSource(
    from reference: SourceReferenceDto
  ) -> BuiltinSource? {
    switch (reference.sourceType, reference.sourceIdentifier) {
    case (BuiltinSource.entireLibrary.sourceType, BuiltinSource.entireLibrary.sourceIdentifier):
      return .entireLibrary
    case (BuiltinSource.mediaTypePhotos.sourceType, BuiltinSource.mediaTypePhotos.sourceIdentifier):
      return .mediaTypePhotos
    case (BuiltinSource.mediaTypeVideos.sourceType, BuiltinSource.mediaTypeVideos.sourceIdentifier):
      return .mediaTypeVideos
    default:
      return nil
    }
  }

  private func fetchResult(for source: BuiltinSource) -> PHFetchResult<PHAsset> {
    switch source {
    case .entireLibrary:
      return allFetchResult()
    case .mediaTypePhotos:
      return photosFetchResult()
    case .mediaTypeVideos:
      return videosFetchResult()
    }
  }

  private func makeBuiltinSourceDto(
    _ source: BuiltinSource,
    count: Int
  ) -> AssetSourceDto {
    AssetSourceDto(
      sourceIdentifier: source.sourceIdentifier,
      displayName: "",
      kind: source.kind,
      estimatedCount: Int64(count),
      availability: count > 0 ? .available : .empty,
      canAddContent: false,
      collectionSubtype: nil
    )
  }

  /// Cap 11.2 / ADR-021: map PhotoKit estimatedAssetCount without treating
  /// `NSNotFound` as zero (must not mark empty when count is unknown).
  private func albumListCountAndAvailability(
    _ collection: PHAssetCollection
  ) -> (Int64?, AssetSourceAvailabilityDto) {
    let raw = collection.estimatedAssetCount
    if raw == NSNotFound {
      return (nil, .available)
    }
    let count = Int64(raw)
    if count > 0 {
      return (count, .available)
    }
    return (count, .empty)
  }

  private func makeAlbumSourceDto(
    _ collection: PHAssetCollection,
    kind: AssetSourceKind
  ) -> AssetSourceDto {
    let (count, availability) = albumListCountAndAvailability(collection)
    let canAddContent: Bool
    switch kind {
    case .album:
      canAddContent = collection.canPerform(.addContent)
    case .smartAlbum:
      canAddContent = false
    default:
      canAddContent = false
    }
    return AssetSourceDto(
      sourceIdentifier: collection.localIdentifier,
      displayName: collection.localizedTitle ?? "",
      kind: kind,
      estimatedCount: count,
      availability: availability,
      canAddContent: canAddContent,
      collectionSubtype: kind == .smartAlbum
        ? Int64(collection.assetCollectionSubtype.rawValue)
        : nil
    )
  }

  /// Title ascending; empty titles last (deterministic Cap 11.2 D1=A).
  private func sortedByDisplayName(
    _ sources: [AssetSourceDto]
  ) -> [AssetSourceDto] {
    sources.sorted { lhs, rhs in
      let leftEmpty = lhs.displayName.isEmpty
      let rightEmpty = rhs.displayName.isEmpty
      if leftEmpty != rightEmpty {
        return !leftEmpty
      }
      return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
        == .orderedAscending
    }
  }

  /// User albums: `albumRegular` only (Cap 11.2 D2=A).
  private func listUserAlbumSources() -> [AssetSourceDto] {
    let result = PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .albumRegular,
      options: nil
    )
    var albums: [AssetSourceDto] = []
    albums.reserveCapacity(result.count)
    result.enumerateObjects { collection, _, _ in
      albums.append(self.makeAlbumSourceDto(collection, kind: .album))
    }
    return sortedByDisplayName(albums)
  }

  /// Reuse an existing user album with the same title (Cap 19.6 reinstall /
  /// Limited create-only bootstrap).
  private func findUserAlbumId(byTitle title: String) -> String? {
    let result = PHAssetCollection.fetchAssetCollections(
      with: .album,
      subtype: .albumRegular,
      options: nil
    )
    var matches: [String] = []
    matches.reserveCapacity(2)
    result.enumerateObjects { collection, _, _ in
      let albumTitle = collection.localizedTitle ?? ""
      if albumTitle.compare(title, options: .caseInsensitive) == .orderedSame {
        matches.append(collection.localIdentifier)
      }
    }
    guard !matches.isEmpty else {
      return nil
    }
    return matches.sorted().first
  }

  /// Smart albums excluding Hidden / Recently Deleted (Cap 11.2 D3=A).
  ///
  /// Cap 21.4b: brute-force subtype raw values — do **not** rely on
  /// `subtype: .any` alone (omits Recently Added / Unable to Upload).
  /// PhotoKit has no public `smartAlbumRecentlyDeleted` member. Recently
  /// Deleted appears as smartAlbum with undocumented rawValue `1000000201`.
  private static let smartAlbumRecentlyDeletedRawValue: Int = 1_000_000_201

  /// Raw subtypes scanned for listing (public band + known undocumented).
  private static let smartAlbumBruteRawValues: [Int] = Array(200...240) + [
    1_000_000_201, 1_000_000_218, 1_000_000_219, 1_000_000_220, 1_000_000_221,
  ]

  private func listSmartAlbumSources() -> [AssetSourceDto] {
    var seenIds = Set<String>()
    var albums: [AssetSourceDto] = []
    for raw in Self.smartAlbumBruteRawValues {
      guard let subtype = PHAssetCollectionSubtype(rawValue: raw) else {
        continue
      }
      if subtype == .smartAlbumAllHidden {
        continue
      }
      if raw == Self.smartAlbumRecentlyDeletedRawValue {
        continue
      }
      let result = PHAssetCollection.fetchAssetCollections(
        with: .smartAlbum,
        subtype: subtype,
        options: nil
      )
      result.enumerateObjects { collection, _, _ in
        let id = collection.localIdentifier
        if seenIds.contains(id) {
          return
        }
        seenIds.insert(id)
        albums.append(self.makeAlbumSourceDto(collection, kind: .smartAlbum))
      }
    }
    return sortedByDisplayName(albums)
  }

  /// Cap 21.4b: presence probe (image|video, fetchLimit=1).
  private func smartAlbumHasContent(_ collection: PHAssetCollection) -> Bool {
    let options = makeAlbumAssetFetchOptions()
    options.fetchLimit = 1
    let assets = PHAsset.fetchAssets(in: collection, options: options)
    return assets.firstObject != nil
  }

  private func collectLocalIdentifiers(
    from result: PHFetchResult<PHAsset>
  ) -> [String] {
    collectResolvedAssets(from: result).ids
  }

  /// Cap 15.12 / 15.15: ids only at resolve. Availability is probed on demand
  /// via [getAssetAvailabilities] (become-current), not a full-library scan.
  private func collectResolvedAssets(
    from result: PHFetchResult<PHAsset>
  ) -> (ids: [String], availabilities: [AssetAvailabilityDto]) {
    var ids: [String] = []
    ids.reserveCapacity(result.count)
    result.enumerateObjects { asset, _, _ in
      ids.append(asset.localIdentifier)
    }
    // Cap 15.15: always empty — do not call mapAvailability per asset here
    // (O(n) PHAssetResource KVC stalls "Loading library…" on large libraries).
    return (ids, [])
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
  ///
  /// PhotoKit does not expose a public `isLocallyAvailable` on `PHAsset` /
  /// `PHAssetResource` in the iOS SDK. The boolean is available via KVC key
  /// `locallyAvailable` (undocumented but stable for list-time probes). Do not
  /// use synchronous `PHImageManager` requests here — too heavy for page map.
  private func mapAvailability(_ asset: PHAsset) -> AssetAvailabilityDto {
    let resources = PHAssetResource.assetResources(for: asset)
    if resources.isEmpty {
      return .unavailable
    }
    let allLocal = resources.allSatisfy { resource in
      (resource.value(forKey: "locallyAvailable") as? Bool) ?? false
    }
    return allLocal ? .deviceLocal : .iCloudNotDownloaded
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
      // iOS 15+ completion runs when the picker is dismissed (selection may
      // have changed). Completing at present-time left Dart unable to refresh
      // totals because the modal often never toggles app lifecycle.
      PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: host) { _ in
        completion(.success(()))
      }
    }
  }

  func libraryTotals(
    completion: @escaping (Result<LibraryTotalsDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      let photos = photosFetchResult().count
      let videos = videosFetchResult().count
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
    let photosCount = photosFetchResult().count
    let videosCount = videosFetchResult().count
    let allCount = photosCount + videosCount
    var sources: [AssetSourceDto] = [
      makeBuiltinSourceDto(.entireLibrary, count: allCount),
      makeBuiltinSourceDto(.mediaTypePhotos, count: photosCount),
      makeBuiltinSourceDto(.mediaTypeVideos, count: videosCount),
    ]
    // Cap 11.2 / ADR-021 / ADR-K: Limited omits Album/Smart entirely
    // (do not emit unauthorized rows). Full Access appends User then Smart.
    if currentPhotoKitStatus() == .authorized {
      sources.append(contentsOf: listUserAlbumSources())
      sources.append(contentsOf: listSmartAlbumSources())
    }
    return sources
  }

  func smartAlbumsWithContent(
    albumIdentifiers: [String],
    completion: @escaping (Result<[String], Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
    } catch {
      completion(.failure(error))
      return
    }
    if albumIdentifiers.isEmpty {
      completion(.success([]))
      return
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let collections = PHAssetCollection.fetchAssetCollections(
        withLocalIdentifiers: albumIdentifiers,
        options: nil
      )
      var nonEmpty: [String] = []
      nonEmpty.reserveCapacity(albumIdentifiers.count)
      // Preserve caller order.
      var byId: [String: PHAssetCollection] = [:]
      collections.enumerateObjects { collection, _, _ in
        byId[collection.localIdentifier] = collection
      }
      for id in albumIdentifiers {
        guard let collection = byId[id] else {
          continue
        }
        if self.smartAlbumHasContent(collection) {
          nonEmpty.append(id)
        }
      }
      DispatchQueue.main.async {
        completion(.success(nonEmpty))
      }
    }
  }

  func resolveSource(
    sourceReference: SourceReferenceDto,
    completion: @escaping (Result<ResolvedSourceDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      if let builtin = builtinSource(from: sourceReference) {
        let shortId = builtin.sourceIdentifier
        DispatchQueue.global(qos: .userInitiated).async {
          let result = self.fetchResult(for: builtin)
          let resolved = self.collectResolvedAssets(from: result)
          DispatchQueue.main.async {
            completion(
              .success(
                ResolvedSourceDto(
                  sourceIdentifier: shortId,
                  assetIdentifiers: resolved.ids,
                  assetAvailabilities: resolved.availabilities
                )
              )
            )
          }
        }
        return
      }

      let sourceType = sourceReference.sourceType
      let isAlbum = sourceType == "album"
      let isSmartAlbum = sourceType == "smartAlbum"
      guard isAlbum || isSmartAlbum else {
        completion(
          .failure(
            fail(
              .assetUnavailable,
              message: "Unsupported source reference type: \(sourceType)"
            )
          )
        )
        return
      }

      // Cap 11.3 / ADR-021 / ADR-K: Limited must not resolve Album/Smart.
      if currentPhotoKitStatus() == .limited {
        completion(
          .failure(
            fail(
              .unauthorized,
              message: "Album/Smart Album resolve requires Full Access"
            )
          )
        )
        return
      }

      let collectionId = sourceReference.sourceIdentifier
      guard !collectionId.isEmpty else {
        completion(
          .failure(
            fail(.albumUnavailable, message: "Empty album sourceIdentifier")
          )
        )
        return
      }

      DispatchQueue.global(qos: .userInitiated).async {
        let fetch = PHAssetCollection.fetchAssetCollections(
          withLocalIdentifiers: [collectionId],
          options: nil
        )
        guard let collection = fetch.firstObject else {
          DispatchQueue.main.async {
            completion(
              .failure(
                self.fail(
                  .albumUnavailable,
                  message: "Album not found: \(collectionId)"
                )
              )
            )
          }
          return
        }

        let typeOk: Bool
        if isAlbum {
          typeOk = collection.assetCollectionType == .album
        } else {
          typeOk = collection.assetCollectionType == .smartAlbum
        }
        if !typeOk {
          DispatchQueue.main.async {
            completion(
              .failure(
                self.fail(
                  .albumUnavailable,
                  message:
                    "Source kind mismatch for collection: \(collectionId)"
                )
              )
            )
          }
          return
        }

        let assets = PHAsset.fetchAssets(
          in: collection,
          options: self.makeAlbumAssetFetchOptions()
        )
        let resolved = self.collectResolvedAssets(from: assets)
        DispatchQueue.main.async {
          completion(
            .success(
              ResolvedSourceDto(
                sourceIdentifier: collectionId,
                assetIdentifiers: resolved.ids,
                assetAvailabilities: resolved.availabilities
              )
            )
          )
        }
      }
    } catch {
      completion(.failure(error))
    }
  }

  /// Cap 15.12 / 15.15: on-demand KVC probe for specific ids (become-current
  /// and Cap 23 still-in-library mutation gate).
  ///
  /// Work runs on a background queue (same pattern as [resolveSource] id
  /// enumeration), then completes on main — never blocks the UI isolate with
  /// `PHAssetResource.assetResources` / KVC.
  ///
  /// Id fetch uses `PHAsset.fetchAssets(withLocalIdentifiers:options:)` with
  /// default options — unlike [makeLibraryFetchOptions] catalog/paging paths,
  /// that API still returns assets in **Recently Deleted**. Cap 23 / ADR-049
  /// treat soft-deleted assets as not still-in-library (mutation must not
  /// proceed to Host and fail with late "Couldn't add…" copy). Before
  /// [mapAvailability], membership in the Recently Deleted smart album
  /// (`smartAlbumRecentlyDeletedRawValue`) maps to `.unavailable`. **Hidden**
  /// is intentionally not excluded here — Hidden means default-timeline
  /// visibility, not absence from the library (unlike Cap 11.2 album-catalog
  /// exclusion).
  func getAssetAvailabilities(
    assetIdentifiers: [String],
    completion: @escaping (Result<[AssetAvailabilityDto], Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      DispatchQueue.global(qos: .userInitiated).async {
        var availabilities: [AssetAvailabilityDto] = []
        availabilities.reserveCapacity(assetIdentifiers.count)
        for id in assetIdentifiers {
          let fetch = PHAsset.fetchAssets(
            withLocalIdentifiers: [id],
            options: nil
          )
          guard let asset = fetch.firstObject else {
            availabilities.append(.unavailable)
            continue
          }
          // Cap 23.4: RD pre-check owns soft-delete → unavailable. Do not fold
          // into [mapAvailability] (kept as resource/locality mapping only).
          if self.isInRecentlyDeletedSmartAlbum(asset) {
            availabilities.append(.unavailable)
            continue
          }
          availabilities.append(self.mapAvailability(asset))
        }
        DispatchQueue.main.async {
          completion(.success(availabilities))
        }
      }
    } catch {
      completion(.failure(error))
    }
  }

  /// True when [asset] is in the Recently Deleted smart album.
  ///
  /// Soft-delete gate for [getAssetAvailabilities], [requestDisplayAsset],
  /// and [requestPreview] (revisit Case B / Cap 23 alignment). Does not
  /// change [mapAvailability] or Hidden handling.
  private func isInRecentlyDeletedSmartAlbum(_ asset: PHAsset) -> Bool {
    let collections = PHAssetCollection.fetchAssetCollectionsContaining(
      asset,
      with: .smartAlbum,
      options: nil
    )
    var inRecentlyDeleted = false
    collections.enumerateObjects { collection, _, stop in
      if collection.assetCollectionSubtype.rawValue
        == Self.smartAlbumRecentlyDeletedRawValue
      {
        inRecentlyDeleted = true
        stop.pointee = true
      }
    }
    return inRecentlyDeleted
  }

  func requestDisplayAsset(
    assetIdentifier: String,
    completion: @escaping (Result<DisplayAssetDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      let fetch = PHAsset.fetchAssets(
        withLocalIdentifiers: [assetIdentifier],
        options: nil
      )
      guard let asset = fetch.firstObject else {
        completion(
          .failure(
            fail(.assetUnavailable, message: "Asset not found: \(assetIdentifier)")
          )
        )
        return
      }
      // Soft-delete (Recently Deleted): still fetchable by id, but not
      // still-in-library — same Case B as hard-missing (revisit model).
      if isInRecentlyDeletedSmartAlbum(asset) {
        completion(
          .failure(
            fail(
              .assetUnavailable,
              message: "Asset in Recently Deleted: \(assetIdentifier)"
            )
          )
        )
        return
      }
      if asset.mediaType == .video {
        completion(
          .failure(
            fail(
              .unsupportedMedia,
              message: "requestDisplayAsset is for stills / Live Photo key frames"
            )
          )
        )
        return
      }

      let start = displayRequests.registerStart(
        assetId: assetIdentifier,
        completion: completion
      )
      if let previousId = start.previousRequestId {
        PHImageManager.default().cancelImageRequest(previousId)
      }
      if let superseded = start.supersededCompletion {
        DispatchQueue.main.async {
          superseded(
            .failure(
              self.fail(
                .operationCancelled,
                message: "Display request replaced"
              )
            )
          )
        }
      }

      let generation = start.generation
      let options = PHImageRequestOptions()
      options.isNetworkAccessAllowed = true
      options.deliveryMode = .highQualityFormat
      options.resizeMode = .fast
      options.isSynchronous = false
      options.progressHandler = { [weak self] _, _, _, _ in
        self?.displayRequests.markTransferBegan(
          assetId: assetIdentifier,
          generation: generation
        )
      }

      let kind = mapMediaKind(asset)
      let requestId = PHImageManager.default().requestImageDataAndOrientation(
        for: asset,
        options: options
      ) { [weak self] data, _, _, info in
        self?.handleDisplayResult(
          assetIdentifier: assetIdentifier,
          generation: generation,
          mediaKind: kind,
          pixelWidth: Int64(asset.pixelWidth),
          pixelHeight: Int64(asset.pixelHeight),
          data: data,
          info: info
        )
      }

      if let toCancel = displayRequests.bindRequestId(
        assetId: assetIdentifier,
        generation: generation,
        requestId: requestId
      ) {
        PHImageManager.default().cancelImageRequest(toCancel)
      }
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
      let fetch = PHAsset.fetchAssets(
        withLocalIdentifiers: [assetIdentifier],
        options: nil
      )
      guard let asset = fetch.firstObject else {
        completion(
          .failure(
            fail(.assetUnavailable, message: "Asset not found: \(assetIdentifier)")
          )
        )
        return
      }
      guard asset.mediaType == .video else {
        completion(
          .failure(
            fail(.unsupportedMedia, message: "Not a video asset")
          )
        )
        return
      }
      // Cap 16.3: duration / type only. No requestAVAsset (no download).
      completion(
        .success(
          PlayableVideoDto(
            assetIdentifier: assetIdentifier,
            durationSeconds: Double(asset.duration)
          )
        )
      )
    } catch {
      completion(.failure(error))
    }
  }

  // MARK: - Layer 1 preview (Cap 14.2 / ADR-025)

  func requestPreview(
    assetIdentifier: String,
    completion: @escaping (Result<DisplayAssetDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      let fetch = PHAsset.fetchAssets(
        withLocalIdentifiers: [assetIdentifier],
        options: nil
      )
      guard let asset = fetch.firstObject else {
        completion(
          .failure(
            fail(.assetUnavailable, message: "Asset not found: \(assetIdentifier)")
          )
        )
        return
      }
      if isInRecentlyDeletedSmartAlbum(asset) {
        completion(
          .failure(
            fail(
              .assetUnavailable,
              message: "Asset in Recently Deleted: \(assetIdentifier)"
            )
          )
        )
        return
      }

      let start = previewRequests.registerStart(
        assetId: assetIdentifier,
        completion: completion
      )
      if let previousId = start.previousRequestId {
        PHImageManager.default().cancelImageRequest(previousId)
      }
      if let superseded = start.supersededCompletion {
        DispatchQueue.main.async {
          superseded(
            .failure(
              self.fail(
                .operationCancelled,
                message: "Preview request replaced"
              )
            )
          )
        }
      }

      let options = PHImageRequestOptions()
      options.isNetworkAccessAllowed = false
      options.deliveryMode = .opportunistic
      options.resizeMode = .fast
      options.isSynchronous = false

      let generation = start.generation
      let kind = mapMediaKind(asset)
      let requestId = PHImageManager.default().requestImage(
        for: asset,
        targetSize: Self.previewTargetSize,
        contentMode: .aspectFit,
        options: options
      ) { [weak self] image, info in
        self?.handlePreviewResult(
          assetIdentifier: assetIdentifier,
          generation: generation,
          mediaKind: kind,
          image: image,
          info: info
        )
      }

      if let toCancel = previewRequests.bindRequestId(
        assetId: assetIdentifier,
        generation: generation,
        requestId: requestId
      ) {
        PHImageManager.default().cancelImageRequest(toCancel)
      }
    } catch {
      completion(.failure(error))
    }
  }

  func cancelPreview(assetIdentifier: String) throws {
    abortPreview(assetIdentifier: assetIdentifier, releaseFile: false)
  }

  func releasePreview(assetIdentifier: String) throws {
    abortPreview(assetIdentifier: assetIdentifier, releaseFile: true)
  }

  func cancelDisplayAsset(assetIdentifier: String) throws {
    abortDisplay(assetIdentifier: assetIdentifier)
  }

  func cancelPlayableVideo(assetIdentifier: String) throws {
    abortPlayable(assetIdentifier: assetIdentifier)
  }

  private func abortPreview(assetIdentifier: String, releaseFile: Bool) {
    let result = previewRequests.invalidate(
      assetId: assetIdentifier,
      releaseFile: releaseFile
    )
    if let requestId = result.requestId {
      PHImageManager.default().cancelImageRequest(requestId)
    }
    if let completion = result.completion {
      DispatchQueue.main.async {
        completion(
          .failure(
            self.fail(
              .operationCancelled,
              message: releaseFile
                ? "Preview released"
                : "Preview request cancelled"
            )
          )
        )
      }
    }
  }

  private func handlePreviewResult(
    assetIdentifier: String,
    generation: UInt64,
    mediaKind: MediaKind,
    image: UIImage?,
    info: [AnyHashable: Any]?
  ) {
    let infoDict = info ?? [:]
    let cancelled = (infoDict[PHImageCancelledKey] as? Bool) == true

    if let image, !cancelled {
      let take = previewRequests.takeForDelivery(
        assetId: assetIdentifier,
        generation: generation
      )
      if !take.accepted {
        return
      }
      if let requestId = take.requestIdToCancel {
        PHImageManager.default().cancelImageRequest(requestId)
      }
      encodeAndCompletePreview(
        assetIdentifier: assetIdentifier,
        generation: generation,
        mediaKind: mediaKind,
        image: image
      )
      return
    }

    if previewRequests.shouldDropCallback(
      assetId: assetIdentifier,
      generation: generation
    ) {
      return
    }

    if cancelled {
      finishPreview(
        assetIdentifier: assetIdentifier,
        generation: generation,
        result: .failure(
          fail(.operationCancelled, message: "Preview request cancelled")
        )
      )
      return
    }

    let inCloud = (infoDict[PHImageResultIsInCloudKey] as? Bool) == true
    finishPreview(
      assetIdentifier: assetIdentifier,
      generation: generation,
      result: .failure(
        fail(
          inCloud ? .iCloudDownloadRequired : .assetUnavailable,
          message: inCloud
            ? "No local preview; Layer 1 unavailable"
            : "No preview image for asset"
        )
      )
    )
  }

  private func encodeAndCompletePreview(
    assetIdentifier: String,
    generation: UInt64,
    mediaKind: MediaKind,
    image: UIImage
  ) {
    previewEncodeQueue.async { [weak self] in
      guard let self else { return }
      guard self.previewRequests.isCurrent(
        assetId: assetIdentifier,
        generation: generation
      ) else {
        self.finishPreview(
          assetIdentifier: assetIdentifier,
          generation: generation,
          result: .failure(
            self.fail(.operationCancelled, message: "Preview request cancelled")
          )
        )
        return
      }
      guard let data = image.jpegData(compressionQuality: Self.previewJpegQuality)
      else {
        self.finishPreview(
          assetIdentifier: assetIdentifier,
          generation: generation,
          result: .failure(
            self.fail(.assetUnavailable, message: "Failed to encode preview JPEG")
          )
        )
        return
      }
      let pixelWidth = Int64((image.size.width * image.scale).rounded())
      let pixelHeight = Int64((image.size.height * image.scale).rounded())
      do {
        guard let path = try self.previewRequests.writeIfCurrent(
          assetId: assetIdentifier,
          generation: generation,
          data: data
        ) else {
          self.finishPreview(
            assetIdentifier: assetIdentifier,
            generation: generation,
            result: .failure(
              self.fail(.operationCancelled, message: "Preview request cancelled")
            )
          )
          return
        }
        let dto = DisplayAssetDto(
          assetIdentifier: assetIdentifier,
          mediaKind: mediaKind,
          localFilePath: path,
          pixelWidth: pixelWidth,
          pixelHeight: pixelHeight
        )
        self.finishPreview(
          assetIdentifier: assetIdentifier,
          generation: generation,
          result: .success(dto)
        )
      } catch {
        self.finishPreview(
          assetIdentifier: assetIdentifier,
          generation: generation,
          result: .failure(
            self.fail(
              .insufficientStorage,
              message: "Failed to write preview temp file"
            )
          )
        )
      }
    }
  }

  private func finishPreview(
    assetIdentifier: String,
    generation: UInt64,
    result: Result<DisplayAssetDto, Error>
  ) {
    DispatchQueue.main.async {
      guard let completion = self.previewRequests.takeCompletionIfCurrent(
        assetId: assetIdentifier,
        generation: generation
      ) else {
        return
      }
      completion(result)
    }
  }

  private func abortDisplay(assetIdentifier: String) {
    let result = displayRequests.invalidate(assetId: assetIdentifier)
    if let requestId = result.requestId {
      PHImageManager.default().cancelImageRequest(requestId)
    }
    if let completion = result.completion {
      DispatchQueue.main.async {
        completion(
          .failure(
            self.fail(.operationCancelled, message: "Display request cancelled")
          )
        )
      }
    }
  }

  private func abortPlayable(assetIdentifier: String) {
    let result = playableRequests.invalidate(assetId: assetIdentifier)
    if let requestId = result.requestId {
      PHImageManager.default().cancelImageRequest(requestId)
    }
    if let completion = result.completion {
      DispatchQueue.main.async {
        completion(
          .failure(
            self.fail(
              .operationCancelled,
              message: "Playable video request cancelled"
            )
          )
        )
      }
    }
  }

  private func layer2Failure(
    cancelled: Bool,
    transferBegan: Bool,
    cancelledMessage: String,
    failedMessage: String,
    unavailableMessage: String
  ) -> PigeonError {
    if cancelled {
      return fail(.operationCancelled, message: cancelledMessage)
    }
    if transferBegan {
      return fail(.iCloudDownloadFailed, message: failedMessage)
    }
    return fail(.assetUnavailable, message: unavailableMessage)
  }

  /// Cap 17.5b: developer diagnosis before user-facing three-bucket collapse.
  /// Prints PhotoKit `info` detail (Profile/Debug Console) — not user copy.
  private func logLayer2PhotoKitFail(
    assetId: String,
    info: [AnyHashable: Any]?,
    cancelled: Bool,
    transferBegan: Bool,
    mappedCode: String
  ) {
    let dict = info ?? [:]
    let inCloud = dict[PHImageResultIsInCloudKey] as? Bool
    let phErrorDesc: String
    if let err = dict[PHImageErrorKey] as? NSError {
      phErrorDesc =
        "domain=\(err.domain) code=\(err.code) desc=\(err.localizedDescription)"
    } else if let raw = dict[PHImageErrorKey] {
      phErrorDesc = String(describing: raw)
    } else {
      phErrorDesc = "nil"
    }
    print(
      "[WakeTok][Layer2] fail id=\(String(assetId.prefix(8))) "
        + "cancelled=\(cancelled) transferBegan=\(transferBegan) "
        + "inCloud=\(String(describing: inCloud)) phError=\(phErrorDesc) "
        + "mapped=\(mappedCode)"
    )
  }

  private func handleDisplayResult(
    assetIdentifier: String,
    generation: UInt64,
    mediaKind: MediaKind,
    pixelWidth: Int64,
    pixelHeight: Int64,
    data: Data?,
    info: [AnyHashable: Any]?
  ) {
    let infoDict = info ?? [:]
    let cancelled = (infoDict[PHImageCancelledKey] as? Bool) == true

    if let data, !cancelled {
      let take = displayRequests.takeForDelivery(
        assetId: assetIdentifier,
        generation: generation
      )
      if !take.accepted {
        return
      }
      if let requestId = take.requestIdToCancel {
        PHImageManager.default().cancelImageRequest(requestId)
      }
      displayWriteQueue.async { [weak self] in
        guard let self else { return }
        do {
          let path = try self.displayRequests.commitIfCurrent(
            assetId: assetIdentifier,
            generation: generation
          ) {
            try DisplayTempFileStore.shared.replace(
              assetId: assetIdentifier,
              data: data
            )
          }
          guard let path else {
            self.finishDisplay(
              assetIdentifier: assetIdentifier,
              generation: generation,
              result: .failure(
                self.fail(
                  .operationCancelled,
                  message: "Display request cancelled"
                )
              )
            )
            return
          }
          let dto = DisplayAssetDto(
            assetIdentifier: assetIdentifier,
            mediaKind: mediaKind,
            localFilePath: path,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight
          )
          self.finishDisplay(
            assetIdentifier: assetIdentifier,
            generation: generation,
            result: .success(dto)
          )
        } catch {
          self.finishDisplay(
            assetIdentifier: assetIdentifier,
            generation: generation,
            result: .failure(
              self.fail(
                .insufficientStorage,
                message: "Failed to write display temp file"
              )
            )
          )
        }
      }
      return
    }

    if displayRequests.shouldDropCallback(
      assetId: assetIdentifier,
      generation: generation
    ) {
      return
    }

    let transferBegan = displayRequests.didTransferBegin(
      assetId: assetIdentifier,
      generation: generation
    )
    let pigeon = layer2Failure(
      cancelled: cancelled,
      transferBegan: transferBegan,
      cancelledMessage: "Display request cancelled",
      failedMessage: "Display download failed",
      unavailableMessage: "No display data for asset"
    )
    logLayer2PhotoKitFail(
      assetId: assetIdentifier,
      info: info,
      cancelled: cancelled,
      transferBegan: transferBegan,
      mappedCode: pigeon.code
    )
    finishDisplay(
      assetIdentifier: assetIdentifier,
      generation: generation,
      result: .failure(pigeon)
    )
  }

  private func finishDisplay(
    assetIdentifier: String,
    generation: UInt64,
    result: Result<DisplayAssetDto, Error>
  ) {
    DispatchQueue.main.async {
      guard let completion = self.displayRequests.takeCompletionIfCurrent(
        assetId: assetIdentifier,
        generation: generation
      ) else {
        return
      }
      completion(result)
    }
  }

  // MARK: - Presentation Metadata (Cap 8.3 / ADR-015)

  func requestPresentationMetadata(
    assetIdentifier: String,
    completion: @escaping (Result<PresentationMetadataDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      let fetch = PHAsset.fetchAssets(
        withLocalIdentifiers: [assetIdentifier],
        options: nil
      )
      guard let asset = fetch.firstObject else {
        completion(
          .failure(
            fail(.assetUnavailable, message: "Asset not found: \(assetIdentifier)")
          )
        )
        return
      }
      let ms: Int64?
      if let date = asset.creationDate {
        ms = Int64((date.timeIntervalSince1970 * 1000.0).rounded())
      } else {
        ms = nil
      }
      completion(
        .success(
          PresentationMetadataDto(
            assetIdentifier: assetIdentifier,
            mediaKind: mapMediaKind(asset),
            creationDateMs: ms
          )
        )
      )
    } catch {
      completion(.failure(error))
    }
  }

  func requestPresentationFileSize(
    assetIdentifier: String,
    completion: @escaping (Result<PresentationFileSizeDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
      let fetch = PHAsset.fetchAssets(
        withLocalIdentifiers: [assetIdentifier],
        options: nil
      )
      guard let asset = fetch.firstObject else {
        completion(
          .failure(
            fail(.assetUnavailable, message: "Asset not found: \(assetIdentifier)")
          )
        )
        return
      }

      let kind = mapMediaKind(asset)
      switch kind {
      case .unknown:
        // Ambiguous media kind → blank (ADR-015), not an error.
        completion(
          .success(
            PresentationFileSizeDto(
              assetIdentifier: assetIdentifier,
              fileSizeBytes: nil,
              fileSizeSemantics: nil
            )
          )
        )
      case .video:
        resolveLocalVideoFileSize(asset: asset, completion: completion)
      case .image, .livePhoto:
        // Live Photo: Tier 4 still only (ADR-018) — same path as ordinary image.
        // Does not sum .pairedVideo. Paired motion size is out of scope here.
        resolveLocalImageFileSize(asset: asset, completion: completion)
      }
    } catch {
      completion(.failure(error))
    }
  }

  /// POC-10 Tier 3: local video URL byte count (`networkAccessAllowed = false`).
  private func resolveLocalVideoFileSize(
    asset: PHAsset,
    completion: @escaping (Result<PresentationFileSizeDto, Error>) -> Void
  ) {
    let assetIdentifier = asset.localIdentifier
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .highQualityFormat

    PHImageManager.default().requestAVAsset(
      forVideo: asset,
      options: options
    ) { avAsset, _, info in
      let infoDict = info ?? [:]
      if (infoDict[PHImageCancelledKey] as? Bool) == true {
        completion(
          .failure(
            self.fail(.operationCancelled, message: "File size request cancelled")
          )
        )
        return
      }

      let blank = PresentationFileSizeDto(
        assetIdentifier: assetIdentifier,
        fileSizeBytes: nil,
        fileSizeSemantics: nil
      )

      // iCloud-only / unavailable → blank size (never download for size).
      guard let urlAsset = avAsset as? AVURLAsset else {
        DispatchQueue.main.async { completion(.success(blank)) }
        return
      }

      let url = urlAsset.url
      guard url.isFileURL else {
        DispatchQueue.main.async { completion(.success(blank)) }
        return
      }

      do {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let size = values.fileSize, size >= 0 else {
          DispatchQueue.main.async { completion(.success(blank)) }
          return
        }
        DispatchQueue.main.async {
          completion(
            .success(
              PresentationFileSizeDto(
                assetIdentifier: assetIdentifier,
                fileSizeBytes: Int64(size),
                fileSizeSemantics: .localVideoUrl
              )
            )
          )
        }
      } catch {
        DispatchQueue.main.async { completion(.success(blank)) }
      }
    }
  }

  /// POC-10 Tier 4: current local image representation byte count.
  private func resolveLocalImageFileSize(
    asset: PHAsset,
    completion: @escaping (Result<PresentationFileSizeDto, Error>) -> Void
  ) {
    let assetIdentifier = asset.localIdentifier
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .none
    options.isSynchronous = false

    PHImageManager.default().requestImageDataAndOrientation(
      for: asset,
      options: options
    ) { data, _, _, info in
      let infoDict = info ?? [:]
      if (infoDict[PHImageCancelledKey] as? Bool) == true {
        completion(
          .failure(
            self.fail(.operationCancelled, message: "File size request cancelled")
          )
        )
        return
      }

      let blank = PresentationFileSizeDto(
        assetIdentifier: assetIdentifier,
        fileSizeBytes: nil,
        fileSizeSemantics: nil
      )

      guard let data, !data.isEmpty else {
        DispatchQueue.main.async { completion(.success(blank)) }
        return
      }

      DispatchQueue.main.async {
        completion(
          .success(
            PresentationFileSizeDto(
              assetIdentifier: assetIdentifier,
              fileSizeBytes: Int64(data.count),
              fileSizeSemantics: .currentImageRepresentation
            )
          )
        )
      }
    }
  }

  func createAlbum(
    name: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
    } catch {
      completion(.failure(error))
      return
    }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      completion(
        .failure(
          fail(.albumUnavailable, message: "Album name is empty")
        )
      )
      return
    }
    if let existingId = self.findUserAlbumId(byTitle: trimmed) {
      completion(.success(existingId))
      return
    }
    var createdId: String?
    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
        withTitle: trimmed
      )
      createdId = request.placeholderForCreatedAssetCollection.localIdentifier
    }) { success, error in
      DispatchQueue.main.async {
        if success, let id = createdId, !id.isEmpty {
          completion(.success(id))
          return
        }
        if let error {
          completion(
            .failure(
              self.mapPhotoKitAlbumMutationError(
                error,
                fallback: .albumUnavailable
              )
            )
          )
          return
        }
        completion(
          .failure(
            self.fail(.albumUnavailable, message: "Failed to create album")
          )
        )
      }
    }
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

  func requestAlbumCoverThumbnail(
    albumIdentifier: String,
    targetSizePx: Int64,
    completion: @escaping (Result<AlbumCoverThumbnailDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
    } catch {
      completion(.failure(error))
      return
    }
    guard !albumIdentifier.isEmpty else {
      completion(
        .failure(
          fail(.albumUnavailable, message: "Album identifier is empty")
        )
      )
      return
    }
    let collections = PHAssetCollection.fetchAssetCollections(
      withLocalIdentifiers: [albumIdentifier],
      options: nil
    )
    guard let collection = collections.firstObject else {
      completion(
        .failure(
          fail(.albumUnavailable, message: "Album not found")
        )
      )
      return
    }
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [
      NSSortDescriptor(key: "creationDate", ascending: false),
    ]
    fetchOptions.fetchLimit = 1
    let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
    guard let asset = assets.firstObject else {
      completion(.success(AlbumCoverThumbnailDto(jpegBytes: nil)))
      return
    }

    let px = CGFloat(max(1, targetSizePx))
    let targetSize = CGSize(width: px, height: px)
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .opportunistic
    options.resizeMode = .fast
    options.isSynchronous = false

    PHImageManager.default().requestImage(
      for: asset,
      targetSize: targetSize,
      contentMode: .aspectFill,
      options: options
    ) { image, info in
      DispatchQueue.main.async {
        let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
        if cancelled {
          completion(.success(AlbumCoverThumbnailDto(jpegBytes: nil)))
          return
        }
        guard let image,
              let data = image.jpegData(compressionQuality: Self.previewJpegQuality)
        else {
          completion(.success(AlbumCoverThumbnailDto(jpegBytes: nil)))
          return
        }
        completion(
          .success(
            AlbumCoverThumbnailDto(
              jpegBytes: FlutterStandardTypedData(bytes: data)
            )
          )
        )
      }
    }
  }

  func requestFavoritesSmartAlbumCoverThumbnail(
    targetSizePx: Int64,
    completion: @escaping (Result<AlbumCoverThumbnailDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
    } catch {
      completion(.failure(error))
      return
    }
    let collections = PHAssetCollection.fetchAssetCollections(
      with: .smartAlbum,
      subtype: .smartAlbumFavorites,
      options: nil
    )
    guard let collection = collections.firstObject else {
      completion(.success(AlbumCoverThumbnailDto(jpegBytes: nil)))
      return
    }
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [
      NSSortDescriptor(key: "creationDate", ascending: false),
    ]
    fetchOptions.fetchLimit = 1
    let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
    guard let asset = assets.firstObject else {
      completion(.success(AlbumCoverThumbnailDto(jpegBytes: nil)))
      return
    }

    let px = CGFloat(max(1, targetSizePx))
    let targetSize = CGSize(width: px, height: px)
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .opportunistic
    options.resizeMode = .fast
    options.isSynchronous = false

    PHImageManager.default().requestImage(
      for: asset,
      targetSize: targetSize,
      contentMode: .aspectFill,
      options: options
    ) { image, info in
      DispatchQueue.main.async {
        let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
        if cancelled {
          completion(.success(AlbumCoverThumbnailDto(jpegBytes: nil)))
          return
        }
        guard let image,
              let data = image.jpegData(compressionQuality: Self.previewJpegQuality)
        else {
          completion(.success(AlbumCoverThumbnailDto(jpegBytes: nil)))
          return
        }
        completion(
          .success(
            AlbumCoverThumbnailDto(
              jpegBytes: FlutterStandardTypedData(bytes: data)
            )
          )
        )
      }
    }
  }

  func albumContainsAsset(
    albumIdentifier: String,
    assetIdentifier: String,
    completion: @escaping (Result<Bool, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
    } catch {
      completion(.failure(error))
      return
    }
    guard !albumIdentifier.isEmpty else {
      completion(
        .failure(
          fail(.albumUnavailable, message: "Album identifier is empty")
        )
      )
      return
    }
    guard !assetIdentifier.isEmpty else {
      completion(.success(false))
      return
    }
    let collections = PHAssetCollection.fetchAssetCollections(
      withLocalIdentifiers: [albumIdentifier],
      options: nil
    )
    guard let collection = collections.firstObject else {
      completion(
        .failure(
          fail(.albumUnavailable, message: "Album not found")
        )
      )
      return
    }
    let options = PHFetchOptions()
    options.predicate = NSPredicate(
      format: "localIdentifier == %@",
      assetIdentifier
    )
    let assets = PHAsset.fetchAssets(in: collection, options: options)
    completion(.success(assets.count > 0))
  }

  func addAssetToAlbum(
    assetIdentifier: String,
    albumIdentifier: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
    } catch {
      completion(.failure(error))
      return
    }
    guard !assetIdentifier.isEmpty else {
      completion(
        .failure(
          fail(.assetUnavailable, message: "Asset identifier is empty")
        )
      )
      return
    }
    guard !albumIdentifier.isEmpty else {
      completion(
        .failure(
          fail(.albumUnavailable, message: "Album identifier is empty")
        )
      )
      return
    }
    let assets = PHAsset.fetchAssets(
      withLocalIdentifiers: [assetIdentifier],
      options: nil
    )
    guard let asset = assets.firstObject else {
      completion(
        .failure(
          fail(.assetUnavailable, message: "Asset not found")
        )
      )
      return
    }
    let collections = PHAssetCollection.fetchAssetCollections(
      withLocalIdentifiers: [albumIdentifier],
      options: nil
    )
    guard let collection = collections.firstObject else {
      completion(
        .failure(
          fail(.albumUnavailable, message: "Album not found")
        )
      )
      return
    }
    guard collection.canPerform(.addContent) else {
      completion(
        .failure(
          fail(.albumNotWritable, message: "Album does not allow addContent")
        )
      )
      return
    }
    // Race-condition safety net: the canPerform check above and performChanges
    // are not atomic — the album may be deleted or lose write permission in
    // between, yielding a nil change request. Do not treat that as success.
    var changeRequestUnavailable = false
    PHPhotoLibrary.shared().performChanges({
      guard let request = PHAssetCollectionChangeRequest(for: collection) else {
        changeRequestUnavailable = true
        return
      }
      request.addAssets([asset] as NSFastEnumeration)
    }) { success, error in
      DispatchQueue.main.async {
        if changeRequestUnavailable {
          completion(
            .failure(
              self.fail(
                .albumNotWritable,
                message: "Album change request unavailable"
              )
            )
          )
          return
        }
        if success {
          completion(.success(()))
          return
        }
        if let error {
          completion(
            .failure(
              self.mapPhotoKitAlbumMutationError(
                error,
                fallback: .albumNotWritable
              )
            )
          )
          return
        }
        completion(
          .failure(
            self.fail(.albumNotWritable, message: "Failed to add asset to album")
          )
        )
      }
    }
  }

  func requestAssetFavoriteStatus(
    assetIdentifier: String,
    completion: @escaping (Result<AssetFavoriteStatusDto, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
    } catch {
      completion(.failure(error))
      return
    }
    guard !assetIdentifier.isEmpty else {
      completion(
        .failure(
          fail(.assetUnavailable, message: "Asset identifier is empty")
        )
      )
      return
    }
    let assets = PHAsset.fetchAssets(
      withLocalIdentifiers: [assetIdentifier],
      options: nil
    )
    guard let asset = assets.firstObject else {
      completion(
        .failure(
          fail(.assetUnavailable, message: "Asset not found")
        )
      )
      return
    }
    completion(
      .success(
        AssetFavoriteStatusDto(
          assetIdentifier: assetIdentifier,
          isFavorite: asset.isFavorite
        )
      )
    )
  }

  func setAssetFavorite(
    assetIdentifier: String,
    favorite: Bool,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    do {
      try requireLibraryAccess()
    } catch {
      completion(.failure(error))
      return
    }
    guard !assetIdentifier.isEmpty else {
      completion(
        .failure(
          fail(.assetUnavailable, message: "Asset identifier is empty")
        )
      )
      return
    }
    let assets = PHAsset.fetchAssets(
      withLocalIdentifiers: [assetIdentifier],
      options: nil
    )
    guard let asset = assets.firstObject else {
      completion(
        .failure(
          fail(.assetUnavailable, message: "Asset not found")
        )
      )
      return
    }
    PHPhotoLibrary.shared().performChanges({
      let request = PHAssetChangeRequest(for: asset)
      request.isFavorite = favorite
    }) { success, error in
      DispatchQueue.main.async {
        if success {
          completion(.success(()))
          return
        }
        if let error {
          completion(
            .failure(
              self.mapPhotoKitAlbumMutationError(
                error,
                fallback: .assetUnavailable
              )
            )
          )
          return
        }
        completion(
          .failure(
            self.fail(
              .assetUnavailable,
              message: "Failed to update favorite status"
            )
          )
        )
      }
    }
  }

  /// Maps PhotoKit write failures to stable Pigeon [ErrorCode] values.
  private func mapPhotoKitAlbumMutationError(
    _ error: Error,
    fallback: ErrorCode
  ) -> PigeonError {
    let nsError = error as NSError
    if nsError.domain == PHPhotosErrorDomain {
      switch nsError.code {
      case PHPhotosError.accessUserDenied.rawValue,
        PHPhotosError.accessRestricted.rawValue:
        return fail(.unauthorized, message: nsError.localizedDescription)
      case PHPhotosError.userCancelled.rawValue:
        return fail(.operationCancelled, message: nsError.localizedDescription)
      // Best-effort: notEnoughSpace is difficult to trigger on device safely.
      case PHPhotosError.notEnoughSpace.rawValue:
        return fail(.insufficientStorage, message: nsError.localizedDescription)
      default:
        break
      }
    }
    return fail(fallback, message: nsError.localizedDescription)
  }
}

// MARK: - Display temp files (≤1+1, Cap 7.3 / POC-04)

/// Host-managed JPEG temps for [requestDisplayAsset]. Max two files; inserting
/// a third evicts the oldest unused entry (same bound as display-pool 1+1).
final class DisplayTempFileStore {
  static let shared = DisplayTempFileStore()

  private let maxFiles = 2
  private var order: [String] = []
  private var paths: [String: URL] = [:]
  private let lock = NSLock()

  /// Writes/replaces the temp for [assetId]; evicts LRU others beyond maxFiles.
  func replace(assetId: String, data: Data) throws -> String {
    lock.lock()
    defer { lock.unlock() }

    if let existing = paths[assetId] {
      try? FileManager.default.removeItem(at: existing)
      paths.removeValue(forKey: assetId)
      order.removeAll { $0 == assetId }
    }

    while order.count >= maxFiles {
      let evictId = order.removeFirst()
      if let url = paths.removeValue(forKey: evictId) {
        try? FileManager.default.removeItem(at: url)
      }
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("waketok_display_\(UUID().uuidString).jpg")
    try data.write(to: url, options: .atomic)
    paths[assetId] = url
    order.append(assetId)
    return url.path
  }

  func release(assetId: String) {
    lock.lock()
    defer { lock.unlock() }
    if let url = paths.removeValue(forKey: assetId) {
      try? FileManager.default.removeItem(at: url)
    }
    order.removeAll { $0 == assetId }
  }

  var fileCountForTests: Int {
    lock.lock()
    defer { lock.unlock() }
    return paths.count
  }

  func pathForTests(assetId: String) -> String? {
    lock.lock()
    defer { lock.unlock() }
    return paths[assetId]?.path
  }
}

// MARK: - Preview temp files (cap 3 = current ±1)

/// Host-managed JPEG temps for [requestPreview]. Max three files.
///
/// Invariant: callers must [releasePreview] an old neighbour **before**
/// [requestPreview] on a new neighbour. Cap 3 is the working set
/// (current + ±1), not headroom for preheat-then-release overflow.
/// Prefix `waketok_preview_` must not collide with display temps.
final class PreviewTempFileStore {
  static let shared = PreviewTempFileStore()

  private let maxFiles = 3
  private var order: [String] = []
  private var paths: [String: URL] = [:]
  private let lock = NSLock()

  /// Writes/replaces the temp for [assetId]; evicts LRU others beyond maxFiles.
  func replace(assetId: String, data: Data) throws -> String {
    lock.lock()
    defer { lock.unlock() }

    if let existing = paths[assetId] {
      try? FileManager.default.removeItem(at: existing)
      paths.removeValue(forKey: assetId)
      order.removeAll { $0 == assetId }
    }

    while order.count >= maxFiles {
      let evictId = order.removeFirst()
      if let url = paths.removeValue(forKey: evictId) {
        try? FileManager.default.removeItem(at: url)
      }
    }

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("waketok_preview_\(UUID().uuidString).jpg")
    try data.write(to: url, options: .atomic)
    paths[assetId] = url
    order.append(assetId)
    return url.path
  }

  func release(assetId: String) {
    lock.lock()
    defer { lock.unlock() }
    if let url = paths.removeValue(forKey: assetId) {
      try? FileManager.default.removeItem(at: url)
    }
    order.removeAll { $0 == assetId }
  }

  var fileCountForTests: Int {
    lock.lock()
    defer { lock.unlock() }
    return paths.count
  }

  func pathForTests(assetId: String) -> String? {
    lock.lock()
    defer { lock.unlock() }
    return paths[assetId]?.path
  }
}
