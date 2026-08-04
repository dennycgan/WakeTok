import AVFoundation
import Flutter
import Foundation
import Photos
import UIKit

/// Cap 7.3 production foreground PlaybackApi host (ADR-006).
///
/// Owns a bounded 1+1 AVPlayer display pool. Platform View attaches/detaches
/// the picture only. Background: detach + pause (no Now Playing / queue advance).
/// Restore guard raised on willEnterForeground; cleared on notifyDisplaySurfaceReady.
final class PlaybackApiHost: PlaybackApi {
  static let viewType = "waketok/playback_surface"

  private var plan: PlaybackPlanDto?
  private var currentAssetIdentifier: String?
  private var currentFeedIndex: Int64 = 0

  private var activePlayer: AVPlayer?
  private var activeAssetId: String?
  private var warmingPlayer: AVPlayer?
  private var warmingAssetId: String?

  private weak var surfaceView: PlaybackSurfaceView?

  /// Guard raised by native on willEnterForeground; cleared on notifyDisplaySurfaceReady.
  private var restoreGuardActive = false

  private var bgObserver: NSObjectProtocol?
  private var fgObserver: NSObjectProtocol?
  private let prepareQueue = DispatchQueue(label: "com.dennycgan.waketok.playback.prepare")

  init() {
    bgObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didEnterBackgroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleDidEnterBackground()
    }
    fgObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleWillEnterForeground()
    }
  }

  deinit {
    if let bgObserver {
      NotificationCenter.default.removeObserver(bgObserver)
    }
    if let fgObserver {
      NotificationCenter.default.removeObserver(fgObserver)
    }
  }

  // MARK: - PlaybackApi

  func load(item: PlaybackItemDto) throws {
    currentAssetIdentifier = item.assetIdentifier
    currentFeedIndex = item.feedIndex
    prepareActive(assetId: item.assetIdentifier)
    warmNextIfPossible()
  }

  func play() throws {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      // After background detach, layer may still be nil — re-adopt before play.
      self.adoptActivePlayerOntoSurface()
      self.activePlayer?.play()
    }
  }

  func pause() throws {
    DispatchQueue.main.async { [weak self] in
      self?.activePlayer?.pause()
    }
  }

  func seek(positionSeconds: Double) throws {
    let time = CMTime(seconds: positionSeconds, preferredTimescale: 600)
    DispatchQueue.main.async { [weak self] in
      self?.activePlayer?.seek(to: time)
    }
  }

  func setRate(rate: Double) throws {
    DispatchQueue.main.async { [weak self] in
      self?.activePlayer?.rate = Float(rate)
    }
  }

  func setMute(muted: Bool) throws {
    DispatchQueue.main.async { [weak self] in
      self?.activePlayer?.isMuted = muted
    }
  }

  func setPlaybackPlan(plan: PlaybackPlanDto) throws {
    self.plan = plan
    let idx = Int(plan.currentIndex)
    guard idx >= 0, idx < plan.orderedItems.count else {
      return
    }
    let item = plan.orderedItems[idx]
    currentAssetIdentifier = item.assetIdentifier
    currentFeedIndex = item.feedIndex
    prepareActive(assetId: item.assetIdentifier)
    warmNextIfPossible()
  }

  func syncPlanPosition(assetIdentifier: String, feedIndex: Int64) throws {
    if restoreGuardActive {
      currentAssetIdentifier = assetIdentifier
      currentFeedIndex = feedIndex
      return
    }
    currentAssetIdentifier = assetIdentifier
    currentFeedIndex = feedIndex
    if let plan {
      self.plan = PlaybackPlanDto(
        planId: plan.planId,
        orderedItems: plan.orderedItems,
        currentIndex: feedIndex
      )
    }
    prepareActive(assetId: assetIdentifier)
    warmNextIfPossible()
  }

  func notifyDisplaySurfaceReady(assetIdentifier: String) throws {
    restoreGuardActive = false
    if activeAssetId != assetIdentifier {
      prepareActive(assetId: assetIdentifier)
    } else {
      DispatchQueue.main.async { [weak self] in
        self?.adoptActivePlayerOntoSurface()
      }
    }
  }

  func updateNowPlayingMetadata() throws {
    // Stub until Production Background Audio (ADR-002).
  }

  // MARK: - Surface / pool

  func bindSurface(_ view: PlaybackSurfaceView) {
    surfaceView = view
    if view.boundAssetId == activeAssetId || view.boundAssetId == currentAssetIdentifier {
      adoptActivePlayerOntoSurface()
    }
  }

  func unbindSurface(_ view: PlaybackSurfaceView) {
    if surfaceView === view {
      view.attach(player: nil)
      surfaceView = nil
    }
  }

  private func handleDidEnterBackground() {
    // Detach picture only; keep AVPlayer alive (ADR-006 surface model).
    surfaceView?.attach(player: nil)
    activePlayer?.pause()
  }

  private func handleWillEnterForeground() {
    restoreGuardActive = true
    // Cap 7.3: surface often survives; Dart may not re-call notifyDisplaySurfaceReady.
    // Re-adopt existing player so Play is not audio-only / black frame.
    adoptActivePlayerOntoSurface()
    if surfaceView != nil, activePlayer != nil {
      restoreGuardActive = false
    }
  }

  /// Puts [activePlayer] back on the Platform View layer and nudges a frame.
  private func adoptActivePlayerOntoSurface() {
    guard let surfaceView else { return }
    surfaceView.attach(player: activePlayer)
    restoreGuardActive = false
  }

  private func prepareActive(assetId: String) {
    if activeAssetId == assetId, activePlayer != nil {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.surfaceView?.attach(player: self.activePlayer)
      }
      return
    }
    if warmingAssetId == assetId, let warming = warmingPlayer {
      activePlayer?.pause()
      activePlayer = warming
      activeAssetId = assetId
      warmingPlayer = nil
      warmingAssetId = nil
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.surfaceView?.attach(player: self.activePlayer)
      }
      return
    }

    let token = assetId
    prepareQueue.async { [weak self] in
      let player = Self.makePlayer(assetId: token)
      DispatchQueue.main.async {
        guard let self else { return }
        guard self.currentAssetIdentifier == token || self.activeAssetId == token
          || self.currentAssetIdentifier == nil
        else { return }
        // Re-check intent: still want this asset as active.
        if self.currentAssetIdentifier != nil, self.currentAssetIdentifier != token {
          return
        }
        self.activePlayer?.pause()
        self.activePlayer = player
        self.activeAssetId = token
        self.surfaceView?.attach(player: player)
      }
    }
  }

  private func warmNextIfPossible() {
    guard let plan else {
      clearWarming()
      return
    }
    let nextIndex = Int(currentFeedIndex) + 1
    guard nextIndex >= 0, nextIndex < plan.orderedItems.count else {
      clearWarming()
      return
    }
    let nextId = plan.orderedItems[nextIndex].assetIdentifier
    if nextId == activeAssetId || nextId == currentAssetIdentifier {
      clearWarming()
      return
    }
    if warmingAssetId == nextId, warmingPlayer != nil {
      return
    }
    clearWarming()
    let token = nextId
    prepareQueue.async { [weak self] in
      let player = Self.makePlayer(assetId: token)
      DispatchQueue.main.async {
        guard let self else { return }
        // Still the intended warming target?
        let expectedNext = Int(self.currentFeedIndex) + 1
        guard let plan = self.plan,
          expectedNext < plan.orderedItems.count,
          plan.orderedItems[expectedNext].assetIdentifier == token
        else { return }
        self.warmingPlayer = player
        self.warmingAssetId = token
      }
    }
  }

  private func clearWarming() {
    warmingPlayer?.pause()
    warmingPlayer = nil
    warmingAssetId = nil
  }

  /// Local-only AVPlayer create. Returns nil for iCloud-only / non-video.
  private static func makePlayer(assetId: String) -> AVPlayer? {
    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
    guard let asset = fetch.firstObject, asset.mediaType == .video else {
      return nil
    }
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .highQualityFormat

    var player: AVPlayer?
    let sem = DispatchSemaphore(value: 0)
    PHImageManager.default().requestAVAsset(
      forVideo: asset,
      options: options
    ) { avAsset, _, info in
      defer { sem.signal() }
      let inCloud = ((info ?? [:])[PHImageResultIsInCloudKey] as? Bool) == true
      if inCloud, avAsset == nil {
        return
      }
      guard let avAsset else { return }
      player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
    }
    _ = sem.wait(timeout: .now() + 8)
    return player
  }

  #if DEBUG
  var isRestoreGuardActiveForTests: Bool { restoreGuardActive }
  var poolCountsForTests: (active: Bool, warming: Bool) {
    (activePlayer != nil, warmingPlayer != nil)
  }
  #endif
}

// MARK: - Platform View

final class PlaybackPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private weak var host: PlaybackApiHost?

  init(host: PlaybackApiHost) {
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
    return PlaybackSurfaceView(
      frame: frame,
      assetId: assetId,
      host: host
    )
  }
}

private final class PlaybackSurfaceContainer: UIView {
  var playerLayer: AVPlayerLayer?

  override func layoutSubviews() {
    super.layoutSubviews()
    playerLayer?.frame = bounds
  }
}

final class PlaybackSurfaceView: NSObject, FlutterPlatformView {
  private let container: PlaybackSurfaceContainer
  private let playerLayer = AVPlayerLayer()
  let boundAssetId: String
  private weak var host: PlaybackApiHost?

  init(frame: CGRect, assetId: String, host: PlaybackApiHost?) {
    boundAssetId = assetId
    self.host = host
    container = PlaybackSurfaceContainer(frame: frame)
    container.backgroundColor = .black
    playerLayer.videoGravity = .resizeAspectFill
    container.playerLayer = playerLayer
    container.layer.addSublayer(playerLayer)
    super.init()
    host?.bindSurface(self)
  }

  deinit {
    host?.unbindSurface(self)
  }

  func view() -> UIView {
    container
  }

  func attach(player: AVPlayer?) {
    playerLayer.player = player
    playerLayer.frame = container.bounds
    // After background detach, force a compositor refresh so Play is not
    // audio-only with a stuck black layer.
    if let player {
      let t = player.currentTime()
      player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }
  }
}
