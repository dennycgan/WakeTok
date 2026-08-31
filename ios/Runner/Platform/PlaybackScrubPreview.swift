import AVFoundation
import UIKit

/// Cap 18.5: best-effort scrub preview stills (ADR-040 Decision 13 supplement).
enum PlaybackScrubPreview {
  /// Matches Dart `kScrubPreviewEndEpsilonSeconds`.
  static let endEpsilonSeconds: Double = 0.05

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

  /// Tolerance pair applied to `AVAssetImageGenerator`.
  struct TimeTolerance: Equatable {
    let before: CMTime
    let after: CMTime
    let label: String

    static let keyframeSnap = TimeTolerance(
      before: .positiveInfinity,
      after: .positiveInfinity,
      label: "infinite"
    )

    static let exact = TimeTolerance(
      before: .zero,
      after: .zero,
      label: "zero"
    )

    /// Fallback if device gate rejects zero on sparse-GOP assets.
    static let nearFrame = TimeTolerance(
      before: CMTime(seconds: 0.033, preferredTimescale: 600),
      after: CMTime(seconds: 0.033, preferredTimescale: 600),
      label: "pm33ms"
    )
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

  /// End-cap only for requests inside the asset's last incomplete second
  /// (or the Dart `duration − ε` shot). Requests **past** asset duration must
  /// not force zero tolerance — PhotoKit duration can be shorter than Dart
  /// observe duration; zero-tol past EOS fails/starves the single-flight queue
  /// and presents as "dragged several seconds, preview stuck".
  static func isEndCapRequest(
    positionSeconds: Double,
    durationSeconds: Double
  ) -> Bool {
    guard positionSeconds.isFinite, durationSeconds.isFinite, durationSeconds > 0
    else {
      return false
    }
    // Past the asset: keep keyframe snap (generator may clamp); never exact.
    if positionSeconds > durationSeconds + 0.05 {
      return false
    }
    if positionSeconds >= floor(durationSeconds) {
      return true
    }
    return positionSeconds >= durationSeconds - endEpsilonSeconds - 0.001
  }

  /// Mid-path and end-cap: exact (zero) tolerance. Past asset duration keeps
  /// keyframe snap so PhotoKit duration skew does not starve the single-flight
  /// queue (ADR-040 Decision 13 supplement).
  static func toleranceForRequest(
    positionSeconds: Double,
    durationSeconds: Double
  ) -> TimeTolerance {
    if positionSeconds > durationSeconds + 0.05 {
      return .keyframeSnap
    }
    return .exact
  }

  static func generateResult(
    asset: AVAsset,
    time: CMTime,
    maximumSize: CGSize = CGSize(width: 160, height: 280),
    tolerance: TimeTolerance = .keyframeSnap
  ) -> (GenerateResult, CMTime) {
    guard loadRequiredAssetKeys(asset) else {
      return (.failure(.assetKeysNotLoaded), .invalid)
    }

    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = maximumSize
    generator.requestedTimeToleranceBefore = tolerance.before
    generator.requestedTimeToleranceAfter = tolerance.after

    var actual = CMTime.zero
    do {
      let cgImage = try generator.copyCGImage(at: time, actualTime: &actual)
      guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.75)
      else {
        return (.failure(.generatorFailed), actual)
      }
      return (.success(data), actual)
    } catch {
      return (.failure(.generatorFailed), actual)
    }
  }

  static func generateJPEG(
    asset: AVAsset,
    time: CMTime,
    maximumSize: CGSize = CGSize(width: 160, height: 280),
    tolerance: TimeTolerance = .keyframeSnap
  ) -> Data? {
    switch generateResult(
      asset: asset,
      time: time,
      maximumSize: maximumSize,
      tolerance: tolerance
    ).0 {
    case .success(let data):
      return data
    case .failure:
      return nil
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
