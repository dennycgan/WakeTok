import Foundation

/// 4.3 empty PhotoLibraryApi host — signatures only; no Photos work.
final class PhotoLibraryApiHost: PhotoLibraryApi {
  private func fail(_ code: ErrorCode, message: String) -> PigeonError {
    PigeonError(code: codeName(code), message: message, details: nil)
  }

  private func codeName(_ code: ErrorCode) -> String {
    String(describing: code)
  }

  func requestAuthorization(
    completion: @escaping (Result<AuthStatus, Error>) -> Void
  ) {
    completion(.success(.notDetermined))
  }

  func listAssetSources() throws -> [AssetSourceDto] {
    []
  }

  func resolveSource(
    sourceReference: SourceReferenceDto,
    completion: @escaping (Result<ResolvedSourceDto, Error>) -> Void
  ) {
    completion(
      .success(
        ResolvedSourceDto(
          sourceIdentifier: sourceReference.sourceIdentifier,
          assetIdentifiers: []
        )
      )
    )
  }

  func requestDisplayAsset(
    assetIdentifier: String,
    completion: @escaping (Result<DisplayAssetDto, Error>) -> Void
  ) {
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
  }

  func requestPlayableVideo(
    assetIdentifier: String,
    completion: @escaping (Result<PlayableVideoDto, Error>) -> Void
  ) {
    completion(
      .success(
        PlayableVideoDto(
          assetIdentifier: assetIdentifier,
          durationSeconds: nil
        )
      )
    )
  }

  func createAlbum(
    name: String,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    completion(
      .failure(
        fail(.albumUnavailable, message: "4.3 stub: createAlbum not implemented")
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
          message: "4.3 stub: importVideo not implemented"
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
          message: "4.3 stub: addAssetToAlbum not implemented"
        )
      )
    )
  }
}
