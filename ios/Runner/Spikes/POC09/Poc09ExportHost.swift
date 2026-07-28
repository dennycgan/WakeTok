import Foundation
import Photos

/// POC-09 spike host: Current Photos Representation probe + export.
final class Poc09ExportHost: Poc09ExportApi {
  func requestAuthorization(
    completion: @escaping (Result<Poc09AuthStatus, Error>) -> Void
  ) {
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

  func getAuthorizationStatus() throws -> Poc09AuthStatus {
    if #available(iOS 14, *) {
      return Self.mapAuthStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }
    return Self.mapAuthStatus(PHPhotoLibrary.authorizationStatus())
  }

  func listLocalVideos(limit: Int64) throws -> [Poc09VideoAssetDto] {
    do {
      return try Poc09ExportEngine.shared.listLocalVideos(limit: Int(limit))
    } catch {
      throw Poc09PigeonError(
        code: "listFailed",
        message: error.localizedDescription,
        details: nil
      )
    }
  }

  func probeAndExport(
    assetId: String,
    networkAccessAllowed: Bool,
    completion: @escaping (Result<Poc09ProbeResultDto, Error>) -> Void
  ) {
    Poc09ExportEngine.shared.probeAndExport(
      assetId: assetId,
      networkAccessAllowed: networkAccessAllowed
    ) { result in
      switch result {
      case .success(let dto):
        completion(.success(dto))
      case .failure(let error):
        completion(
          .failure(
            Poc09PigeonError(
              code: "probeFailed",
              message: error.localizedDescription,
              details: nil
            )
          )
        )
      }
    }
  }

  func clearExportCache() throws {
    Poc09ExportEngine.shared.clearExportCache()
  }

  private static func mapAuthStatus(_ status: PHAuthorizationStatus) -> Poc09AuthStatus {
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
}
