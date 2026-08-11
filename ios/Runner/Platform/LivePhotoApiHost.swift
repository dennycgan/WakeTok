import Flutter
import Foundation
import Photos
import PhotosUI
import UIKit

/// Cap 9 Live Photo native host (ADR-019 / POC-08).
///
/// Owns PHLivePhoto requests and a detachable PHLivePhotoView Platform View.
/// Independent of [PlaybackApiHost] video pool — Dart awaits
/// `clearPlaybackPool` before [requestLivePhoto] when Live becomes current.
///
/// Cap 9.4 / F4 — known single-layer mutex: there is **no** host-side lock
/// between [cancel] and [requestLivePhoto]. `requestGeneration` only drops
/// stale PH callbacks; it does not serialize cancel↔request against each
/// other. Feed must call Host only via Dart `LiveHostOpSerial` /
/// `_enqueueLiveOp` (feed-scoped, not per-page). If a future path
/// (e.g. Cap 9.5/9.6) invokes Host APIs outside that chain, re-evaluate
/// host mutual exclusion before shipping.
///
/// Failure split:
/// - Sync-detectable → throw PigeonError (ErrorCode member name).
/// - Async request failure → [LivePhotoFlutterApi.onLivePhotoFailed] only.
final class LivePhotoApiHost: NSObject, LivePhotoApi {
  static let viewType = "waketok/live_photo_surface"

  private let flutterApi: LivePhotoFlutterApi
  private weak var surfaceView: LivePhotoSurfaceView?

  private var currentAssetId: String?
  private var pendingLivePhoto: PHLivePhoto?
  private var requestId: PHImageRequestID = PHInvalidImageRequestID
  private var requestGeneration: UInt64 = 0
  private var muted = false

  init(binaryMessenger: FlutterBinaryMessenger) {
    flutterApi = LivePhotoFlutterApi(binaryMessenger: binaryMessenger)
    super.init()
  }

  private func fail(_ code: ErrorCode, message: String) -> PigeonError {
    PigeonError(code: String(describing: code), message: message, details: nil)
  }

  // MARK: - LivePhotoApi

  func requestLivePhoto(assetIdentifier: String) throws {
    // Not runOnMainSync: identity/generation updates here are not mutually
    // exclusive with [cancel] at the host layer (see type-level F4 note).
    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = fetch.firstObject else {
      throw fail(.assetUnavailable, message: "No PHAsset for \(assetIdentifier)")
    }
    guard asset.mediaSubtypes.contains(.photoLive) else {
      throw fail(.unsupportedMedia, message: "Asset is not a Live Photo")
    }

    cancelInFlightRequest()
    requestGeneration &+= 1
    let generation = requestGeneration
    currentAssetId = assetIdentifier
    pendingLivePhoto = nil

    let options = PHLivePhotoRequestOptions()
    options.isNetworkAccessAllowed = true
    options.deliveryMode = .highQualityFormat

    let targetSize = CGSize(
      width: CGFloat(max(asset.pixelWidth, 1)),
      height: CGFloat(max(asset.pixelHeight, 1))
    )

    requestId = PHImageManager.default().requestLivePhoto(
      for: asset,
      targetSize: targetSize,
      contentMode: .aspectFill,
      options: options
    ) { [weak self] livePhoto, info in
      guard let self else { return }
      DispatchQueue.main.async {
        guard self.requestGeneration == generation else { return }
        guard self.currentAssetId == assetIdentifier else { return }

        let infoDict = info ?? [:]
        if (infoDict[PHImageCancelledKey] as? Bool) == true {
          self.emitFailed(assetIdentifier: assetIdentifier, code: .operationCancelled)
          return
        }
        if infoDict[PHImageErrorKey] != nil, livePhoto == nil {
          // Network was allowed; reuse ADR-008 R2 iCloudDownloadFailed (not Required).
          self.emitFailed(assetIdentifier: assetIdentifier, code: .iCloudDownloadFailed)
          return
        }
        guard let livePhoto else {
          self.emitFailed(assetIdentifier: assetIdentifier, code: .unknown)
          return
        }

        self.pendingLivePhoto = livePhoto
        self.flutterApi.onLivePhotoReady(assetIdentifier: assetIdentifier) { _ in }
        self.tryBindLivePhotoToSurface()
      }
    }
  }

  func cancel(assetIdentifier: String) throws {
    guard currentAssetId == assetIdentifier || currentAssetId == nil else {
      return
    }
    // Cap 9.4 / F4: Dart awaits cancel — must finish teardown before reply
    // (same shape as PlaybackApiHost.clearPlaybackPool).
    // Order on main: bump requestGeneration first so in-flight PH callbacks
    // drop, then clear pending state and stop/unload the surface.
    let work = { [weak self] in
      guard let self else { return }
      self.cancelInFlightRequest()
      self.requestGeneration &+= 1
      self.pendingLivePhoto = nil
      self.currentAssetId = nil
      self.surfaceView?.stopPlayback()
      self.surfaceView?.setLivePhoto(nil)
    }
    runOnMainSync(work)
  }

  func startPlayback() throws {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.surfaceView?.setMuted(self.muted)
      self.surfaceView?.startPlaybackOnce()
    }
  }

  func stopPlayback() throws {
    // Cap 9.4 / F4: Dart awaits stop — surface must be stopped before reply.
    // Multi-statement body (not single-expression optional-chain) so the
    // closure is () -> Void, not () -> Void? — required by runOnMainSync.
    let work = { [weak self] in
      guard let self else { return }
      self.surfaceView?.stopPlayback()
    }
    runOnMainSync(work)
  }

  func setMute(muted: Bool) throws {
    self.muted = muted
    DispatchQueue.main.async { [weak self] in
      self?.surfaceView?.setMuted(muted)
    }
  }

  func notifyLiveSurfaceReady(assetIdentifier: String) throws {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      if self.currentAssetId == nil {
        self.currentAssetId = assetIdentifier
      }
      self.tryBindLivePhotoToSurface()
    }
  }

  // MARK: - Surface binding

  func bindSurface(_ view: LivePhotoSurfaceView) {
    surfaceView = view
    view.setMuted(muted)
    // Cap 9 D3 hard gate: disable Photos-default long-press / 3D Touch replay
    // (Q6=A — no tap/gesture replay).
    view.disableDefaultPlaybackGesture()
    tryBindLivePhotoToSurface()
  }

  func unbindSurface(_ view: LivePhotoSurfaceView) {
    if surfaceView === view {
      view.stopPlayback()
      view.setLivePhoto(nil)
      surfaceView = nil
    }
  }

  private func tryBindLivePhotoToSurface() {
    guard let livePhoto = pendingLivePhoto, let surfaceView else { return }
    surfaceView.setLivePhoto(livePhoto)
    surfaceView.setMuted(muted)
  }

  private func runOnMainSync(_ work: () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.sync(execute: work)
    }
  }

  private func cancelInFlightRequest() {
    if requestId != PHInvalidImageRequestID {
      PHImageManager.default().cancelImageRequest(requestId)
      requestId = PHInvalidImageRequestID
    }
  }

  private func emitFailed(assetIdentifier: String, code: ErrorCode) {
    pendingLivePhoto = nil
    flutterApi.onLivePhotoFailed(assetIdentifier: assetIdentifier, errorCode: code) { _ in }
  }

  func handlePlaybackEnded(assetIdentifier: String?) {
    let id = assetIdentifier ?? currentAssetId ?? ""
    guard !id.isEmpty else { return }
    flutterApi.onLivePhotoPlaybackEnded(assetIdentifier: id) { _ in }
  }
}

// MARK: - Platform View

final class LivePhotoPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private weak var host: LivePhotoApiHost?

  init(host: LivePhotoApiHost) {
    self.host = host
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let assetId = args as? String ?? ""
    return LivePhotoSurfaceView(
      frame: frame,
      assetId: assetId,
      host: host
    )
  }
}

final class LivePhotoSurfaceView: NSObject, FlutterPlatformView, PHLivePhotoViewDelegate {
  private let liveView = PHLivePhotoView(frame: .zero)
  let boundAssetId: String
  private weak var host: LivePhotoApiHost?

  init(frame: CGRect, assetId: String, host: LivePhotoApiHost?) {
    boundAssetId = assetId
    self.host = host
    super.init()
    liveView.frame = frame
    liveView.contentMode = .scaleAspectFill
    liveView.clipsToBounds = true
    liveView.delegate = self
    disableDefaultPlaybackGesture()
    host?.bindSurface(self)
  }

  deinit {
    host?.unbindSurface(self)
  }

  func view() -> UIView {
    liveView
  }

  func disableDefaultPlaybackGesture() {
    liveView.playbackGestureRecognizer.isEnabled = false
  }

  func setLivePhoto(_ livePhoto: PHLivePhoto?) {
    liveView.livePhoto = livePhoto
  }

  func setMuted(_ muted: Bool) {
    liveView.isMuted = muted
  }

  func startPlaybackOnce() {
    guard liveView.livePhoto != nil else { return }
    liveView.startPlayback(with: .full)
  }

  func stopPlayback() {
    liveView.stopPlayback()
  }

  func livePhotoView(
    _ livePhotoView: PHLivePhotoView,
    didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle
  ) {
    host?.handlePlaybackEnded(assetIdentifier: boundAssetId)
  }
}
