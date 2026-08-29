import Foundation
import os

/// Cap 18.5 live probe — visible in Profile via `log stream` (not `#if DEBUG`).
enum ScrubPreviewProbe {
  private static let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.dennycgan.waketok",
    category: "WT18.5.scrubPreview"
  )

  static func info(_ message: String) {
    log.info("\(message, privacy: .public)")
  }
}
