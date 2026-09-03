import Foundation
import os

/// Cap 18.5 live probe — visible in Profile via Console / `log stream`
/// (not `#if DEBUG`).
enum ScrubPreviewProbe {
  private static let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.dennycgan.waketok",
    category: "WT18.5.scrubPreview"
  )

  static func info(_ message: String) {
    log.info("\(message, privacy: .public)")
    NSLog("WT18.5.scrubPreview %@", message)
  }

  /// Cap 19.8 Bug B seek diagnostics — same Console filter as [info].
  static func seekDiag(_ message: String) {
    info("seekDiag \(message)")
  }
}
