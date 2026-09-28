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
///
/// ADR-063 motion end: [LivePhotoFlutterApi.onLivePhotoPlaybackEnded] is sent
/// at most once per play ([LiveMotionPlayTracker]) — from `didEndPlaybackWith`
/// or from the duration fallback ([LiveMotionEndPolicy]).
final class LivePhotoApiHost: NSObject, LivePhotoApi {
  static let viewType = "waketok/live_photo_surface"

  private let flutterApi: LivePhotoFlutterApi
  private weak var surfaceView: LivePhotoSurfaceView?

  private var currentAssetId: String?
  private var pendingLivePhoto: PHLivePhoto?
  private var requestId: PHImageRequestID = PHInvalidImageRequestID
  private var requestGeneration: UInt64 = 0
  private var muted = false

  private var playTracker = LiveMotionPlayTracker()
  private var motionDurations = LiveMotionDurationCache()
  private var motionDurationReader: LiveMotionDurationReader?
  private var motionEndFallback: DispatchWorkItem?

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
    invalidatePlay()

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
        self.prepareMotionDuration(asset: asset)
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
      self.invalidatePlay()
      self.cancelMotionDurationRead()
      self.surfaceView?.stopPlayback()
      self.surfaceView?.setLivePhoto(nil)
    }
    runOnMainSync(work)
  }

  func startPlayback() throws {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.invalidatePlay()
      guard let view = self.surfaceView else {
        return
      }
      view.setMuted(self.muted)
      // Open the play before starting so a synchronous willBegin is not dropped.
      self.playTracker.start(surface: ObjectIdentifier(view))
      if !view.startPlaybackOnce() {
        self.playTracker.invalidate()
      }
    }
  }

  func stopPlayback() throws {
    // Cap 9.4 / F4: Dart awaits stop — surface must be stopped before reply.
    // Multi-statement body (not single-expression optional-chain) so the
    // closure is () -> Void, not () -> Void? — required by runOnMainSync.
    let work = { [weak self] in
      guard let self else { return }
      self.invalidatePlay()
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
    invalidatePlay()
    surfaceView = view
    view.setMuted(muted)
    // Cap 9 D3 hard gate: disable Photos-default long-press / 3D Touch replay
    // (Q6=A — no tap/gesture replay).
    view.disableDefaultPlaybackGesture()
    tryBindLivePhotoToSurface()
  }

  func unbindSurface(_ view: LivePhotoSurfaceView) {
    if surfaceView === view {
      invalidatePlay()
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

  // MARK: - Motion end (ADR-063)

  func handleSystemWillBegin(_ view: LivePhotoSurfaceView) {
    guard playTracker.willBegin(surface: ObjectIdentifier(view), at: CACurrentMediaTime()) else {
      return
    }
    armMotionEndFallback()
  }

  func handleSystemDidEnd(_ view: LivePhotoSurfaceView) {
    guard playTracker.endCurrentPlay(surface: ObjectIdentifier(view)) != nil else {
      return
    }
    cancelMotionEndFallback()
    flutterApi.onLivePhotoPlaybackEnded(assetIdentifier: view.boundAssetId) { _ in }
  }

  private func invalidatePlay() {
    playTracker.invalidate()
    cancelMotionEndFallback()
  }

  private func cancelMotionEndFallback() {
    motionEndFallback?.cancel()
    motionEndFallback = nil
  }

  /// Arms (or re-arms) the fallback for the current play. Deadline is anchored
  /// on `willBeginPlaybackWith`; a duration that arrives late only shortens the
  /// remaining delay, and one past the deadline fires on the next main turn.
  private func armMotionEndFallback() {
    cancelMotionEndFallback()
    guard let view = surfaceView,
      let delay = LiveMotionEndPolicy.fallbackDelay(
        play: playTracker.currentPlay,
        surface: ObjectIdentifier(view),
        duration: motionDurations.duration(for: view.boundAssetId),
        now: CACurrentMediaTime()
      ),
      let serial = playTracker.currentPlay?.serial
    else {
      return
    }
    let work = DispatchWorkItem { [weak self, weak view] in
      guard let self, let view, self.surfaceView === view else {
        return
      }
      guard self.playTracker.endPlay(serial: serial, surface: ObjectIdentifier(view)) else {
        return
      }
      self.motionEndFallback = nil
      view.stopPlayback()
      self.flutterApi.onLivePhotoPlaybackEnded(assetIdentifier: view.boundAssetId) { _ in }
    }
    motionEndFallback = work
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
  }

  /// Called once per ready. Never delays ready / `startPlayback`.
  private func prepareMotionDuration(asset: PHAsset) {
    let assetId = asset.localIdentifier
    let resources = PHAssetResource.assetResources(for: asset)
    guard LiveMotionEndPolicy.isEligible(
      playbackStyle: asset.playbackStyle,
      resourceTypes: resources.map(\.type)
    ) else {
      motionDurations.remove(assetId)
      return
    }
    guard motionDurations.duration(for: assetId) == nil,
      let video = resources.first(where: { $0.type == .pairedVideo })
    else { return }
    cancelMotionDurationRead()
    let reader = LiveMotionDurationReader(assetId: assetId, resource: video) { [weak self] result in
      DispatchQueue.main.async {
        guard let self else { return }
        if self.motionDurationReader?.assetId == assetId {
          self.motionDurationReader = nil
        }
        guard case .found(let duration, _) = result.outcome else { return }
        self.motionDurations.store(duration, for: assetId)
        if self.surfaceView?.boundAssetId == assetId, self.motionEndFallback == nil {
          self.armMotionEndFallback()
        }
      }
    }
    motionDurationReader = reader
    reader.start()
  }

  private func cancelMotionDurationRead() {
    motionDurationReader?.cancel()
    motionDurationReader = nil
  }
}

// MARK: - Motion end policy (ADR-063)

enum LiveMotionEndPolicy {
  /// Must stay above how late normal `.full` playback ends after willBegin +
  /// movie duration (up to ~0.76 s on device), or normal motion is cut short.
  static let slack: TimeInterval = 1.0

  /// Host fallback only when the played motion is the original paired video:
  /// `.livePhoto` style (not Loop / Bounce / Long Exposure) and unedited.
  static func isEligible(
    playbackStyle: PHAsset.PlaybackStyle,
    resourceTypes: [PHAssetResourceType]
  ) -> Bool {
    guard playbackStyle == .livePhoto, resourceTypes.contains(.pairedVideo) else {
      return false
    }
    let editedMarkers: [PHAssetResourceType] = [
      .fullSizePairedVideo, .adjustmentData, .adjustmentBasePairedVideo,
    ]
    return !resourceTypes.contains(where: editedMarkers.contains)
  }

  static func deadline(
    willBeginAt: CFTimeInterval,
    duration: TimeInterval,
    slack: TimeInterval = slack
  ) -> CFTimeInterval {
    willBeginAt + duration + slack
  }

  static func delay(until deadline: CFTimeInterval, now: CFTimeInterval) -> TimeInterval {
    max(0, deadline - now)
  }

  /// Delay for the fallback of the open [play] on [surface], or `nil` when it
  /// must not be armed: play closed, other surface, no willBegin yet, or
  /// duration unknown.
  static func fallbackDelay(
    play: LiveMotionPlayTracker.Play?,
    surface: ObjectIdentifier,
    duration: TimeInterval?,
    now: CFTimeInterval,
    slack: TimeInterval = slack
  ) -> TimeInterval? {
    guard let play, play.surface == surface, let willBeginAt = play.willBeginAt, let duration else {
      return nil
    }
    return delay(until: deadline(willBeginAt: willBeginAt, duration: duration, slack: slack), now: now)
  }
}

/// One play = one successful Host `startPlayback` on one surface. Only the
/// first end of the current play is forwarded; stop / cancel / new request /
/// new start / surface change close it, so later system ends are dropped.
struct LiveMotionPlayTracker {
  struct Play: Equatable {
    let serial: UInt64
    let surface: ObjectIdentifier
    var willBeginAt: CFTimeInterval?
  }

  private(set) var currentPlay: Play?
  private var lastSerial: UInt64 = 0

  @discardableResult
  mutating func start(surface: ObjectIdentifier) -> UInt64 {
    lastSerial &+= 1
    currentPlay = Play(serial: lastSerial, surface: surface, willBeginAt: nil)
    return lastSerial
  }

  /// Records willBegin for the open play on [surface]; false when stale.
  mutating func willBegin(surface: ObjectIdentifier, at time: CFTimeInterval) -> Bool {
    guard var play = currentPlay, play.surface == surface else { return false }
    play.willBeginAt = time
    currentPlay = play
    return true
  }

  /// System end: closes and returns the open play on [surface], else nil.
  mutating func endCurrentPlay(surface: ObjectIdentifier) -> Play? {
    guard let play = currentPlay, play.surface == surface else { return nil }
    currentPlay = nil
    return play
  }

  /// Fallback end: closes the play only if it is still [serial] on [surface].
  mutating func endPlay(serial: UInt64, surface: ObjectIdentifier) -> Bool {
    guard let play = currentPlay, play.serial == serial, play.surface == surface else {
      return false
    }
    currentPlay = nil
    return true
  }

  mutating func invalidate() {
    currentPlay = nil
  }
}

/// Successful paired-video durations only; bounded (cleared when full).
struct LiveMotionDurationCache {
  static let limit = 64

  private var storage: [String: TimeInterval] = [:]

  var count: Int { storage.count }

  func duration(for assetId: String) -> TimeInterval? {
    storage[assetId]
  }

  mutating func store(_ duration: TimeInterval, for assetId: String) {
    if storage[assetId] == nil, storage.count >= Self.limit {
      storage.removeAll()
    }
    storage[assetId] = duration
  }

  mutating func remove(_ assetId: String) {
    storage[assetId] = nil
  }
}

// MARK: - Paired-video duration (ADR-063)

/// Incremental QuickTime top-level atom walk that returns `moov/mvhd` movie
/// duration. Non-`moov` atoms are skipped without buffering; `moov` is
/// buffered up to [maxMoovBytes]. Malformed, truncated or zero-timescale
/// input yields `nil` (unknown), never a crash.
struct MovieDurationScanner {
  enum Outcome: Equatable {
    case needMore
    case found(TimeInterval, moovAfterMdat: Bool)
    case unknown
  }

  static let maxMoovBytes: Int64 = 4 << 20

  private(set) var outcome: Outcome = .needMore
  private(set) var bytesConsumed: Int64 = 0
  private var header: [UInt8] = []
  private var skipRemaining: Int64 = 0
  private var moov: [UInt8]?
  private var moovRemaining: Int64 = 0
  private var sawMdat = false

  mutating func feed(_ data: Data) {
    guard outcome == .needMore else { return }
    if moov == nil, header.isEmpty, skipRemaining >= Int64(data.count) {
      skipRemaining -= Int64(data.count)
      bytesConsumed += Int64(data.count)
      return
    }
    let bytes = [UInt8](data)
    var i = 0
    while i < bytes.count, outcome == .needMore {
      let available = Int64(bytes.count - i)
      if moov != nil {
        let n = Int(min(moovRemaining, available))
        moov?.append(contentsOf: bytes[i..<(i + n)])
        moovRemaining -= Int64(n)
        i += n
        if moovRemaining == 0 {
          if let duration = moov.flatMap(Self.movieDuration(moovBody:)) {
            outcome = .found(duration, moovAfterMdat: sawMdat)
          } else {
            outcome = .unknown
          }
        }
        continue
      }
      if skipRemaining > 0 {
        let n = Int(min(skipRemaining, available))
        skipRemaining -= Int64(n)
        i += n
        continue
      }
      header.append(bytes[i])
      i += 1
      guard header.count >= 8 else { continue }
      let size32 = Self.uint32(header, 0)
      if size32 == 1, header.count < 16 { continue }
      let headerLength: Int64 = size32 == 1 ? 16 : 8
      let rawSize = size32 == 1 ? Self.uint64(header, 8) : UInt64(size32)
      let type = String(bytes: header[4..<8], encoding: .ascii) ?? ""
      header.removeAll(keepingCapacity: true)
      guard rawSize <= UInt64(Int64.max), Int64(rawSize) >= headerLength else {
        outcome = .unknown
        break
      }
      let body = Int64(rawSize) - headerLength
      if type == "moov" {
        guard body > 0, body <= Self.maxMoovBytes else {
          outcome = .unknown
          break
        }
        moov = []
        moov?.reserveCapacity(Int(body))
        moovRemaining = body
      } else {
        if type == "mdat" {
          sawMdat = true
        }
        skipRemaining = body
      }
    }
    bytesConsumed += Int64(i)
  }

  /// End of stream without a complete `moov`.
  mutating func finish() {
    if outcome == .needMore {
      outcome = .unknown
    }
  }

  static func movieDuration(moovBody: [UInt8]) -> TimeInterval? {
    var offset = 0
    while offset + 8 <= moovBody.count {
      let size = Int(uint32(moovBody, offset))
      let type = String(bytes: moovBody[(offset + 4)..<(offset + 8)], encoding: .ascii)
      guard size >= 8, size <= moovBody.count - offset else { return nil }
      if type == "mvhd" {
        let body = offset + 8
        let end = offset + size
        guard body < end else { return nil }
        let version = moovBody[body]
        let timescale: UInt32
        let duration: UInt64
        if version == 1 {
          guard body + 32 <= end else { return nil }
          timescale = uint32(moovBody, body + 20)
          duration = uint64(moovBody, body + 24)
        } else {
          guard body + 20 <= end else { return nil }
          timescale = uint32(moovBody, body + 12)
          duration = UInt64(uint32(moovBody, body + 16))
        }
        guard timescale > 0, duration > 0, duration != UInt64.max, duration != UInt64(UInt32.max)
        else { return nil }
        return TimeInterval(duration) / TimeInterval(timescale)
      }
      offset += size
    }
    return nil
  }

  private static func uint32(_ b: [UInt8], _ o: Int) -> UInt32 {
    (UInt32(b[o]) << 24) | (UInt32(b[o + 1]) << 16) | (UInt32(b[o + 2]) << 8) | UInt32(b[o + 3])
  }

  private static func uint64(_ b: [UInt8], _ o: Int) -> UInt64 {
    (UInt64(uint32(b, o)) << 32) | UInt64(uint32(b, o + 4))
  }
}

/// Streams the paired-video resource through [MovieDurationScanner]: no file
/// copy, no network (non-local resources fail → unknown). Cancels the data
/// request as soon as `mvhd` is parsed.
final class LiveMotionDurationReader {
  struct Result {
    let outcome: MovieDurationScanner.Outcome
    let bytesConsumed: Int64
  }

  let assetId: String
  private let resource: PHAssetResource
  private let completion: (Result) -> Void
  private let queue = DispatchQueue(label: "com.dennycgan.waketok.liveMotionDuration")
  private var scanner = MovieDurationScanner()
  private var requestId: PHAssetResourceDataRequestID?
  private var finished = false

  init(assetId: String, resource: PHAssetResource, completion: @escaping (Result) -> Void) {
    self.assetId = assetId
    self.resource = resource
    self.completion = completion
  }

  func start() {
    let options = PHAssetResourceRequestOptions()
    options.isNetworkAccessAllowed = false
    let id = PHAssetResourceManager.default().requestData(
      for: resource,
      options: options,
      dataReceivedHandler: { [weak self] data in
        guard let self else { return }
        self.queue.async { self.consume(data) }
      },
      completionHandler: { [weak self] _ in
        guard let self else { return }
        self.queue.async {
          self.scanner.finish()
          self.complete()
        }
      }
    )
    queue.async {
      self.requestId = id
      if self.finished {
        self.cancelRequest()
      }
    }
  }

  func cancel() {
    queue.async {
      self.finished = true
      self.cancelRequest()
    }
  }

  private func consume(_ data: Data) {
    guard !finished else { return }
    scanner.feed(data)
    if scanner.outcome != .needMore {
      complete()
      cancelRequest()
    }
  }

  private func complete() {
    guard !finished else { return }
    finished = true
    completion(Result(outcome: scanner.outcome, bytesConsumed: scanner.bytesConsumed))
  }

  private func cancelRequest() {
    if let requestId {
      PHAssetResourceManager.default().cancelDataRequest(requestId)
      self.requestId = nil
    }
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
    liveView.contentMode = .scaleAspectFit
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

  /// Returns whether playback was actually requested from the view.
  @discardableResult
  func startPlaybackOnce() -> Bool {
    guard liveView.livePhoto != nil else { return false }
    liveView.startPlayback(with: .full)
    return true
  }

  func stopPlayback() {
    liveView.stopPlayback()
  }

  func livePhotoView(
    _ livePhotoView: PHLivePhotoView,
    willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle
  ) {
    host?.handleSystemWillBegin(self)
  }

  func livePhotoView(
    _ livePhotoView: PHLivePhotoView,
    didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle
  ) {
    host?.handleSystemDidEnd(self)
  }
}
