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

  /// Play intent that arrived while the active player was still preparing.
  /// Without this, an early Dart play() is silently dropped (frozen first frame).
  private var pendingPlay = false
  /// Cap 9.6 / ADR-019: shared mute preference mirrored on the host.
  /// `setMute` must survive nil `activePlayer` and later `pendingPlay` /
  /// `prepareActive` completion — applying only to `activePlayer?.isMuted`
  /// loses mute when Dart setMute races before the AVPlayer exists.
  /// `clearPlaybackPool` does **not** reset this (preference stays).
  private var muted = false
  /// Asset ids with an in-flight prepareActive, so a second request for the
  /// same asset does not build a duplicate player that pauses the first one.
  private var preparingAssetIds = Set<String>()
  /// Cap 9 / ADR-019: bumped on each [clearPlaybackPool]. In-flight prepare /
  /// warm callbacks must drop results when their captured epoch is stale.
  private var clearEpoch: UInt64 = 0

  /// TEMPORARY default `false`. Browse does not wire native plan-advance yet.
  /// Background Audio / lock-screen queue **must** set this from real mode
  /// state — do not leave it stuck false, or ADR-006 D4 (plan end: no loop)
  /// is unenforced on one-item plans.
  private var backgroundPlanAdvanceActive = false

  private var itemEndObserver: NSObjectProtocol?
  private weak var observedEndItem: AVPlayerItem?
  /// Discrete: this active item has received `AVPlayerItemDidPlayToEndTime`.
  /// Not a currentTime/duration float compare.
  private var activeItemDidPlayToEnd = false
  /// Ignore overlapping end notifications while `seek(to: .zero)` is in flight.
  private var endSeekInFlight = false

  private weak var surfaceView: PlaybackSurfaceView?

  /// Guard raised by native on willEnterForeground; cleared on notifyDisplaySurfaceReady.
  private var restoreGuardActive = false

  private var bgObserver: NSObjectProtocol?
  private var fgObserver: NSObjectProtocol?
  private let activePrepareQueue = DispatchQueue(
    label: "com.dennycgan.waketok.playback.prepare.active"
  )
  private let warmPrepareQueue = DispatchQueue(
    label: "com.dennycgan.waketok.playback.prepare.warm"
  )
  private let currentPrepareTable = PhotoKitRequestTable<() -> Void>()

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
    unregisterItemEndObserver()
    if let bgObserver {
      NotificationCenter.default.removeObserver(bgObserver)
    }
    if let fgObserver {
      NotificationCenter.default.removeObserver(fgObserver)
    }
  }

  // MARK: - PlaybackApi

  func load(item: PlaybackItemDto) throws {
    cancelImageRequestIfNeeded(replaceCurrentItem(item.assetIdentifier))
    currentFeedIndex = item.feedIndex
    prepareActive(assetId: item.assetIdentifier)
    warmNextIfPossible()
  }

  func play() throws {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      // After background detach, layer may still be nil — re-adopt before play.
      self.adoptActivePlayerOntoSurface()
      self.playActiveApplyingReenterPolicy()
    }
  }

  func pause() throws {
    DispatchQueue.main.async { [weak self] in
      self?.pendingPlay = false
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
    self.muted = muted
    DispatchQueue.main.async { [weak self] in
      self?.applyMuteToPlayers()
    }
  }

  func setPlaybackPlan(plan: PlaybackPlanDto) throws {
    self.plan = plan
    let idx = Int(plan.currentIndex)
    guard idx >= 0, idx < plan.orderedItems.count else {
      return
    }
    let item = plan.orderedItems[idx]
    cancelImageRequestIfNeeded(replaceCurrentItem(item.assetIdentifier))
    currentFeedIndex = item.feedIndex
    prepareActive(assetId: item.assetIdentifier)
    warmNextIfPossible()
  }

  func syncPlanPosition(assetIdentifier: String, feedIndex: Int64) throws {
    cancelImageRequestIfNeeded(replaceCurrentItem(assetIdentifier))
    if restoreGuardActive {
      currentFeedIndex = feedIndex
      return
    }
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

  func clearPlaybackPool() throws {
    // Dart awaits this Future before LivePhotoApi.requestLivePhoto (ADR-019).
    // Must finish pool teardown before returning so the await window is real.
    //
    // Background ∩ clear: handleDidEnterBackground only detaches/pauses; it
    // does not bump clearEpoch. clearPlaybackPool still invalidates in-flight
    // prepare/warm via epoch — stale callbacks must no-op after clear.
    let work = { [weak self] in
      self?.performClearPlaybackPool()
    }
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.sync(execute: work)
    }
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

  /// Applies persisted [muted] to active + warming players (Cap 9.6).
  private func applyMuteToPlayers() {
    activePlayer?.isMuted = muted
    warmingPlayer?.isMuted = muted
  }

  private func performClearPlaybackPool() {
    unregisterItemEndObserver()
    clearEpoch &+= 1
    pendingPlay = false
    preparingAssetIds.removeAll()
    if let current = currentAssetIdentifier {
      let result = currentPrepareTable.invalidate(assetId: current)
      cancelImageRequestIfNeeded(result.requestId)
    }
    clearWarming()
    activePlayer?.pause()
    activePlayer = nil
    activeAssetId = nil
    activeItemDidPlayToEnd = false
    endSeekInFlight = false
    plan = nil
    currentAssetIdentifier = nil
    currentFeedIndex = 0
    surfaceView?.attach(player: nil)
    // Do not reset `muted` — Dart preference remains; next player re-applies.
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

  /// Reads the previous current id, invalidates/cancels that slot when the
  /// id actually changes, then writes [newId]. Callers must not assign
  /// [currentAssetIdentifier] themselves.
  @discardableResult
  func replaceCurrentItem(_ newId: String) -> PHImageRequestID? {
    let previousId = currentAssetIdentifier
    var requestIdToCancel: PHImageRequestID?
    if let previousId, previousId != newId {
      let result = currentPrepareTable.invalidate(assetId: previousId)
      requestIdToCancel = result.requestId
      preparingAssetIds.remove(previousId)
    }
    currentAssetIdentifier = newId
    return requestIdToCancel
  }

  private func cancelImageRequestIfNeeded(_ requestId: PHImageRequestID?) {
    guard let requestId, requestId != PHInvalidImageRequestID else { return }
    PHImageManager.default().cancelImageRequest(requestId)
  }

  private func prepareActive(assetId: String) {
    if activeAssetId == assetId, activePlayer != nil {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.surfaceView?.attach(player: self.activePlayer)
        self.registerItemEndObserverIfNeeded()
        self.consumePendingPlayIfNeeded()
      }
      return
    }
    if warmingAssetId == assetId, let warming = warmingPlayer {
      unregisterItemEndObserver()
      activePlayer?.pause()
      activePlayer = warming
      activeAssetId = assetId
      activeItemDidPlayToEnd = false
      endSeekInFlight = false
      warmingPlayer = nil
      warmingAssetId = nil
      applyMuteToPlayers()
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.surfaceView?.attach(player: self.activePlayer)
        self.registerItemEndObserverIfNeeded()
        self.consumePendingPlayIfNeeded()
      }
      return
    }
    // Same asset already being prepared (e.g. load then
    // notifyDisplaySurfaceReady) — do not build a duplicate player that
    // would pause/replace the first one mid-playback.
    if preparingAssetIds.contains(assetId) {
      return
    }
    preparingAssetIds.insert(assetId)

    let token = assetId
    let epoch = clearEpoch
    let start = currentPrepareTable.registerStart(assetId: token, completion: {})
    cancelImageRequestIfNeeded(start.previousRequestId)
    let generation = start.generation

    activePrepareQueue.async { [weak self] in
      guard let self else { return }
      let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [token], options: nil)
      guard let asset = fetch.firstObject, asset.mediaType == .video else {
        _ = self.currentPrepareTable.invalidate(assetId: token)
        DispatchQueue.main.async {
          self.preparingAssetIds.remove(token)
          guard self.clearEpoch == epoch else { return }
          self.adoptPreparedPlayer(nil, token: token)
        }
        return
      }

      let options = PHVideoRequestOptions()
      options.isNetworkAccessAllowed = true
      options.deliveryMode = .highQualityFormat
      options.progressHandler = { [weak self] _, _, _, _ in
        self?.currentPrepareTable.markTransferBegan(
          assetId: token,
          generation: generation
        )
      }

      let requestId = PHImageManager.default().requestAVAsset(
        forVideo: asset,
        options: options
      ) { [weak self] avAsset, _, info in
        guard let self else { return }
        let take = self.currentPrepareTable.takeForDelivery(
          assetId: token,
          generation: generation
        )
        guard take.accepted else { return }
        if let toCancel = take.requestIdToCancel {
          PHImageManager.default().cancelImageRequest(toCancel)
        }
        let cancelled = ((info ?? [:])[PHImageCancelledKey] as? Bool) == true
        DispatchQueue.main.async {
          self.preparingAssetIds.remove(token)
          guard self.clearEpoch == epoch else { return }
          guard !cancelled, let avAsset else { return }
          let player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
          self.adoptPreparedPlayer(player, token: token)
        }
      }

      if let toCancel = self.currentPrepareTable.bindRequestId(
        assetId: token,
        generation: generation,
        requestId: requestId
      ) {
        PHImageManager.default().cancelImageRequest(toCancel)
      }
    }
  }

  private func adoptPreparedPlayer(_ player: AVPlayer?, token: String) {
    // Stale completions must not attach: only the current plan item.
    guard currentAssetIdentifier == token else { return }
    if activeAssetId == token, activePlayer != nil {
      surfaceView?.attach(player: activePlayer)
      registerItemEndObserverIfNeeded()
      consumePendingPlayIfNeeded()
      return
    }
    unregisterItemEndObserver()
    activePlayer?.pause()
    activePlayer = player
    activeAssetId = token
    activeItemDidPlayToEnd = false
    endSeekInFlight = false
    applyMuteToPlayers()
    surfaceView?.attach(player: player)
    registerItemEndObserverIfNeeded()
    consumePendingPlayIfNeeded()
  }

  /// Fires a play() intent that arrived before the current asset's player
  /// was ready (or while activePlayer still pointed at the previous video).
  private func consumePendingPlayIfNeeded() {
    guard pendingPlay else { return }
    playActiveApplyingReenterPolicy()
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
    let epoch = clearEpoch
    warmPrepareQueue.async { [weak self] in
      let player = Self.makeLocalPlayer(assetId: token)
      DispatchQueue.main.async {
        guard let self else { return }
        guard self.clearEpoch == epoch else { return }
        // Still the intended warming target?
        let expectedNext = Int(self.currentFeedIndex) + 1
        guard let plan = self.plan,
          expectedNext < plan.orderedItems.count,
          plan.orderedItems[expectedNext].assetIdentifier == token
        else { return }
        self.warmingPlayer = player
        self.warmingAssetId = token
        self.applyMuteToPlayers()
      }
    }
  }

  private func clearWarming() {
    // Warming must never own the item-end observer (no loop on ±1).
    warmingPlayer?.pause()
    warmingPlayer = nil
    warmingAssetId = nil
  }

  private func unregisterItemEndObserver() {
    if let itemEndObserver {
      NotificationCenter.default.removeObserver(itemEndObserver)
    }
    itemEndObserver = nil
    observedEndItem = nil
  }

  /// Registers [AVPlayerItemDidPlayToEndTime] only on the active current item.
  private func registerItemEndObserverIfNeeded() {
    unregisterItemEndObserver()
    guard let player = activePlayer,
      let item = player.currentItem,
      activeAssetId == currentAssetIdentifier
    else { return }
    observedEndItem = item
    itemEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak self] note in
      self?.handleItemDidPlayToEnd(note)
    }
  }

  private func handleItemDidPlayToEnd(_ note: Notification) {
    let ended = note.object as? AVPlayerItem
    let observedIsCurrentItem =
      ended != nil
      && ended === observedEndItem
      && ended === activePlayer?.currentItem
    let isActiveCurrent = activeAssetId == currentAssetIdentifier
    // ADR-006 D4: background plan-advance must stopKeepPosition (no item loop).
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: !backgroundPlanAdvanceActive,
      isBackgroundPlanAdvance: backgroundPlanAdvanceActive,
      isActiveCurrent: isActiveCurrent,
      observedItemIsCurrentItem: observedIsCurrentItem
    )
    switch action {
    case .loopSeekZeroAndPlay:
      if endSeekInFlight {
        return
      }
      activeItemDidPlayToEnd = true
      endSeekInFlight = true
      seekZeroAndPlay(activePlayer)
    case .stopKeepPosition:
      activeItemDidPlayToEnd = true
    case .ignore:
      break
    }
  }

  private func playActiveApplyingReenterPolicy() {
    // Only play when the active player is already the *current* asset.
    // After a swipe, activePlayer may still be the previous video until
    // prepareActive finishes — playing that would clear pendingPlay and
    // leave the newly prepared player paused at frame 0.
    guard let player = activePlayer,
      activeAssetId == currentAssetIdentifier
    else {
      pendingPlay = true
      return
    }
    pendingPlay = false
    applyMuteToPlayers()
    switch VideoPlaybackPolicy.actionOnBecomeCurrent(
      playerExists: true,
      itemAtEnd: activeItemDidPlayToEnd
    ) {
    case .seekZeroAndPlay:
      if endSeekInFlight {
        return
      }
      endSeekInFlight = true
      seekZeroAndPlay(player)
    case .playOnly:
      player.play()
    case .prepareNew:
      break
    }
  }

  private func seekZeroAndPlay(_ player: AVPlayer?) {
    guard let player else {
      endSeekInFlight = false
      return
    }
    let token = activeAssetId
    player.seek(to: .zero) { [weak self] finished in
      guard let self else { return }
      self.endSeekInFlight = false
      guard finished else { return }
      guard self.activePlayer === player,
        self.activeAssetId == token,
        self.currentAssetIdentifier == token
      else { return }
      self.activeItemDidPlayToEnd = false
      player.play()
    }
  }

  /// Local-only AVPlayer create for ±1 warming. Returns nil for iCloud-only
  /// / non-video. Current-item prepare uses networked [requestAVAsset]
  /// instead (no semaphore).
  private static func makeLocalPlayer(assetId: String) -> AVPlayer? {
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
  var clearEpochForTests: UInt64 { clearEpoch }

  func debugRegisterInFlightCurrentPrepare(
    assetId: String,
    requestId: PHImageRequestID
  ) {
    currentAssetIdentifier = assetId
    let start = currentPrepareTable.registerStart(assetId: assetId, completion: {})
    _ = currentPrepareTable.bindRequestId(
      assetId: assetId,
      generation: start.generation,
      requestId: requestId
    )
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
