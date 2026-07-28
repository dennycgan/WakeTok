import AVFoundation
import Foundation
import Photos

/// POC-09: obtain current Photos representation and export to a temp file (Q1=A).
final class Poc09ExportEngine {
  static let shared = Poc09ExportEngine()

  private let exportDirName = "poc09_exports"

  private init() {}

  func listLocalVideos(limit: Int) throws -> [Poc09VideoAssetDto] {
    try ensureAuthorized()
    let capped = max(0, limit)
    guard capped > 0 else { return [] }

    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    options.includeHiddenAssets = false
    options.predicate = NSPredicate(
      format: "mediaType == %d",
      PHAssetMediaType.video.rawValue
    )

    let fetch = PHAsset.fetchAssets(with: options)
    var results: [Poc09VideoAssetDto] = []
    results.reserveCapacity(min(capped, fetch.count))

    fetch.enumerateObjects { asset, _, stop in
      if results.count >= capped {
        stop.pointee = true
        return
      }
      guard Self.isDeviceLocalVideo(asset) else { return }
      results.append(
        Poc09VideoAssetDto(
          assetId: asset.localIdentifier,
          durationSeconds: asset.duration,
          isHighFrameRate: asset.mediaSubtypes.contains(.videoHighFrameRate),
          pixelWidth: Int64(asset.pixelWidth),
          pixelHeight: Int64(asset.pixelHeight)
        )
      )
    }
    return results
  }

  func probeAndExport(
    assetId: String,
    networkAccessAllowed: Bool,
    completion: @escaping (Result<Poc09ProbeResultDto, Error>) -> Void
  ) {
    do {
      try ensureAuthorized()
    } catch {
      completion(.failure(error))
      return
    }

    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetch.firstObject, asset.mediaType == .video else {
      completion(
        .failure(
          NSError(
            domain: "Poc09Export",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: "Video PHAsset not found"]
          )
        )
      )
      return
    }

    let phDuration = asset.duration
    let isHfr = asset.mediaSubtypes.contains(.videoHighFrameRate)

    requestAVAsset(asset: asset, version: .current, network: networkAccessAllowed) {
      [weak self] currentAsset, currentError in
      guard let self else { return }

      if let currentError {
        completion(
          .success(
            self.failureDto(
              assetId: assetId,
              phDuration: phDuration,
              isHfr: isHfr,
              network: networkAccessAllowed,
              code: "currentObtainFailed",
              message: currentError
            )
          )
        )
        return
      }
      guard let currentAsset else {
        completion(
          .success(
            self.failureDto(
              assetId: assetId,
              phDuration: phDuration,
              isHfr: isHfr,
              network: networkAccessAllowed,
              code: "currentObtainFailed",
              message: "nil AVAsset for .current"
            )
          )
        )
        return
      }

      let currentDur = Self.durationSeconds(of: currentAsset)
      let audioCount = currentAsset.tracks(withMediaType: .audio).count
      let textCount = currentAsset.tracks(withMediaType: .text).count
        + currentAsset.tracks(withMediaType: .closedCaption).count

      self.requestAVAsset(asset: asset, version: .original, network: networkAccessAllowed) {
        originalAsset, _ in
        let originalDur = originalAsset.map { Self.durationSeconds(of: $0) }

        self.exportCurrent(currentAsset, assetId: assetId) { path, exportError in
          if let exportError {
            completion(
              .success(
                Poc09ProbeResultDto(
                  assetId: assetId,
                  phAssetDurationSec: phDuration,
                  isHighFrameRate: isHfr,
                  networkAccessAllowed: networkAccessAllowed,
                  currentAvDurationSec: currentDur,
                  originalAvDurationSec: originalDur,
                  exportDurationSec: nil,
                  exportPath: nil,
                  audioTrackCount: Int64(audioCount),
                  textTrackCount: Int64(textCount),
                  errorCode: "exportFailed",
                  errorMessage: exportError
                )
              )
            )
            return
          }
          guard let path else {
            completion(
              .success(
                self.failureDto(
                  assetId: assetId,
                  phDuration: phDuration,
                  isHfr: isHfr,
                  network: networkAccessAllowed,
                  code: "exportFailed",
                  message: "nil export path"
                )
              )
            )
            return
          }
          let exportDur = Self.fileDurationSeconds(path: path)
          if exportDur == nil || (exportDur ?? 0) <= 0.01 {
            completion(
              .success(
                Poc09ProbeResultDto(
                  assetId: assetId,
                  phAssetDurationSec: phDuration,
                  isHighFrameRate: isHfr,
                  networkAccessAllowed: networkAccessAllowed,
                  currentAvDurationSec: currentDur,
                  originalAvDurationSec: originalDur,
                  exportDurationSec: exportDur,
                  exportPath: path,
                  audioTrackCount: Int64(audioCount),
                  textTrackCount: Int64(textCount),
                  errorCode: "exportCorrupt",
                  errorMessage: "Export file missing or near-zero duration"
                )
              )
            )
            return
          }
          completion(
            .success(
              Poc09ProbeResultDto(
                assetId: assetId,
                phAssetDurationSec: phDuration,
                isHighFrameRate: isHfr,
                networkAccessAllowed: networkAccessAllowed,
                currentAvDurationSec: currentDur,
                originalAvDurationSec: originalDur,
                exportDurationSec: exportDur,
                exportPath: path,
                audioTrackCount: Int64(audioCount),
                textTrackCount: Int64(textCount),
                errorCode: nil,
                errorMessage: nil
              )
            )
          )
        }
      }
    }
  }

  func clearExportCache() {
    let dir = exportDirectory()
    try? FileManager.default.removeItem(at: dir)
  }

  // MARK: - Private

  private func failureDto(
    assetId: String,
    phDuration: Double,
    isHfr: Bool,
    network: Bool,
    code: String,
    message: String
  ) -> Poc09ProbeResultDto {
    Poc09ProbeResultDto(
      assetId: assetId,
      phAssetDurationSec: phDuration,
      isHighFrameRate: isHfr,
      networkAccessAllowed: network,
      currentAvDurationSec: nil,
      originalAvDurationSec: nil,
      exportDurationSec: nil,
      exportPath: nil,
      audioTrackCount: 0,
      textTrackCount: 0,
      errorCode: code,
      errorMessage: message
    )
  }

  private func requestAVAsset(
    asset: PHAsset,
    version: PHVideoRequestOptionsVersion,
    network: Bool,
    completion: @escaping (AVAsset?, String?) -> Void
  ) {
    let options = PHVideoRequestOptions()
    options.version = version
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = network

    PHImageManager.default().requestAVAsset(
      forVideo: asset,
      options: options
    ) { avAsset, _, info in
      if let error = info?[PHImageErrorKey] as? NSError {
        DispatchQueue.main.async {
          completion(nil, error.localizedDescription)
        }
        return
      }
      let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
      if avAsset == nil, inCloud, !network {
        DispatchQueue.main.async {
          completion(nil, "inCloudUnavailable")
        }
        return
      }
      DispatchQueue.main.async {
        completion(avAsset, avAsset == nil ? "nil AVAsset" : nil)
      }
    }
  }

  private func exportCurrent(
    _ asset: AVAsset,
    assetId: String,
    completion: @escaping (_ path: String?, _ error: String?) -> Void
  ) {
    let dir = exportDirectory()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let safeId = assetId
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: ":", with: "_")
    let out = dir.appendingPathComponent("\(safeId)-\(UUID().uuidString).mp4")

    guard let session = AVAssetExportSession(
      asset: asset,
      presetName: AVAssetExportPresetHighestQuality
    ) else {
      completion(nil, "AVAssetExportSession unavailable")
      return
    }
    session.outputURL = out
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true

    session.exportAsynchronously {
      DispatchQueue.main.async {
        switch session.status {
        case .completed:
          completion(out.path, nil)
        case .failed:
          completion(
            nil,
            session.error?.localizedDescription ?? "export failed"
          )
        case .cancelled:
          completion(nil, "export cancelled")
        default:
          completion(nil, "export status=\(session.status.rawValue)")
        }
      }
    }
  }

  private func exportDirectory() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(
      exportDirName,
      isDirectory: true
    )
  }

  private static func durationSeconds(of asset: AVAsset) -> Double {
    let t = asset.duration
    let s = CMTimeGetSeconds(t)
    return s.isFinite ? max(0, s) : 0
  }

  private static func fileDurationSeconds(path: String) -> Double? {
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)
    let s = CMTimeGetSeconds(asset.duration)
    guard s.isFinite else { return nil }
    return max(0, s)
  }

  private func ensureAuthorized() throws {
    let status: PHAuthorizationStatus
    if #available(iOS 14, *) {
      status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    } else {
      status = PHPhotoLibrary.authorizationStatus()
    }
    let ok: Bool
    if #available(iOS 14, *) {
      ok = status == .authorized || status == .limited
    } else {
      ok = status == .authorized
    }
    guard ok else {
      throw NSError(
        domain: "Poc09Export",
        code: 401,
        userInfo: [NSLocalizedDescriptionKey: "Photos authorization required"]
      )
    }
  }

  private static func isDeviceLocalVideo(_ asset: PHAsset) -> Bool {
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .fastFormat
    options.version = .current

    let sem = DispatchSemaphore(value: 0)
    var isLocal = false
    PHImageManager.default().requestAVAsset(
      forVideo: asset,
      options: options
    ) { avAsset, _, info in
      let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
      let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
      let error = info?[PHImageErrorKey]
      isLocal = avAsset != nil && !inCloud && !cancelled && error == nil
      sem.signal()
    }
    _ = sem.wait(timeout: .now() + 8)
    return isLocal
  }
}
