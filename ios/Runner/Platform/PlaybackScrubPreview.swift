import AVFoundation
import UIKit

/// Cap 18.5: best-effort scrub preview stills (ADR-040 Decision 13 supplement).
enum PlaybackScrubPreview {
  /// Machine-readable failure for Host logs and XCTest.
  enum Failure: Equatable {
    case assetKeysNotLoaded
    case generatorFailed
  }

  enum GenerateResult: Equatable {
    case success(Data)
    case failure(Failure)

    static func == (lhs: GenerateResult, rhs: GenerateResult) -> Bool {
      switch (lhs, rhs) {
      case (.success(let a), .success(let b)):
        return a == b
      case (.failure(let a), .failure(let b)):
        return a == b
      default:
        return false
      }
    }
  }

  static func isTimeSeekable(item: AVPlayerItem, time: CMTime) -> Bool {
    let target = CMTimeGetSeconds(time)
    guard target.isFinite, target >= 0 else { return false }
    for value in item.seekableTimeRanges {
      let range = value.timeRangeValue
      let start = CMTimeGetSeconds(range.start)
      let end = start + CMTimeGetSeconds(range.duration)
      if target >= start, target <= end {
        return true
      }
    }
    // PhotoKit / local items often play before seekableTimeRanges is populated.
    guard item.status == .readyToPlay else { return false }
    let duration = CMTimeGetSeconds(item.duration)
    guard duration.isFinite, duration > 0 else { return false }
    return target <= duration
  }

  static func generateJPEG(
    asset: AVAsset,
    time: CMTime,
    maximumSize: CGSize = CGSize(width: 160, height: 280)
  ) -> Data? {
    switch generateResult(asset: asset, time: time, maximumSize: maximumSize) {
    case .success(let data):
      return data
    case .failure:
      return nil
    }
  }

  static func generateResult(
    asset: AVAsset,
    time: CMTime,
    maximumSize: CGSize = CGSize(width: 160, height: 280)
  ) -> GenerateResult {
    guard loadRequiredAssetKeys(asset) else {
      return .failure(.assetKeysNotLoaded)
    }

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = maximumSize
    generator.requestedTimeToleranceBefore = .positiveInfinity
    generator.requestedTimeToleranceAfter = .positiveInfinity

    var actual = CMTime.zero
    do {
      let cgImage = try generator.copyCGImage(at: time, actualTime: &actual)
      guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.75)
      else {
        return .failure(.generatorFailed)
      }
      return .success(data)
    } catch {
      return .failure(.generatorFailed)
    }
  }

  private static func loadRequiredAssetKeys(_ asset: AVAsset) -> Bool {
    let keys = ["tracks", "duration"]
    for key in keys {
      var error: NSError?
      switch asset.statusOfValue(forKey: key, error: &error) {
      case .loaded:
        continue
      case .failed:
        return false
      case .unknown, .loading:
        let sem = DispatchSemaphore(value: 0)
        asset.loadValuesAsynchronously(forKeys: [key]) { sem.signal() }
        sem.wait()
        if asset.statusOfValue(forKey: key, error: &error) != .loaded {
          return false
        }
      @unknown default:
        return false
      }
    }
    return true
  }
}
