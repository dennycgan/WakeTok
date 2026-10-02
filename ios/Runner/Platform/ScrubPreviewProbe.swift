import Foundation
import os

/// Cap 18.5 live probe — visible in Debug and Profile via Console /
/// `log stream`; compiled out of Release. Profile has no `DEBUG`, so the
/// Runner Profile configuration defines `WAKETOK_PROBE`.
enum ScrubPreviewProbe {
  #if DEBUG || WAKETOK_PROBE
  private static let log = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.dennycgan.waketok",
    category: "WT18.5.scrubPreview"
  )
  #endif

  static func info(_ message: @autoclosure () -> String) {
    #if DEBUG || WAKETOK_PROBE
    let text = message()
    log.info("\(text, privacy: .public)")
    NSLog("WT18.5.scrubPreview %@", text)
    #endif
  }

  /// Cap 19.8 Bug B seek diagnostics — same Console filter as [info].
  static func seekDiag(_ message: @autoclosure () -> String) {
    #if DEBUG || WAKETOK_PROBE
    info("seekDiag \(message())")
    #endif
  }
}
