import Foundation

/// Cap 25 Share: narrow Host-internal gate so `PhotoLibraryService` can
/// disable hit-testing on the bound video Platform View during
/// `UIActivityViewController` presentation without importing Playback pool
/// details.
///
/// Wired once in `AppDelegate` (composition root). Not a cross-language
/// boundary — Swift Host to Swift Host only.
protocol PlaybackSurfaceUserInteractionGate: AnyObject {
  /// H1 (leaf): `PlaybackSurfaceView.view().isUserInteractionEnabled`.
  /// Kept for Cap 25 Share present; does **not** touch engine wrapper views.
  func setBoundSurfaceUserInteractionEnabled(_ enabled: Bool)

  /// Bug#1 Option 1: temporarily disable Flutter engine Hybrid Composition
  /// wrapper hit-testing (`ChildClippingView` / `FlutterTouchInterceptingView`)
  /// for the **current** Share present only.
  ///
  /// Arm requires a verified `ChildClippingView` ancestor (outer layer).
  /// Finding only `FlutterTouchInterceptingView` → no-op (`armed=false`).
  /// State is single-present: cleared at begin; restored+cleared on end.
  ///
  /// **Engine-internal workaround** pinned to Flutter 3.41.9 /
  /// Engine `42d3d75a56` — re-verify on Flutter/Engine upgrade.
  func beginBoundPlatformViewWrapperShareGate()

  /// Restore wrapper `isUserInteractionEnabled` flags from the active present
  /// slot and clear the slot. Idempotent.
  func endBoundPlatformViewWrapperShareGate(phase: String)
}
