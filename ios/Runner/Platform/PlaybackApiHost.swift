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

  private let flutterApi: PlaybackFlutterApi
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
  /// Cap 15.11: temporary handoff mute — does not overwrite [muted].
  private var transitionAudioSuppressed = false
  /// Asset ids with an in-flight prepareActive, so a second request for the
  /// same asset does not build a duplicate player that pauses the first one.
  private var preparingAssetIds = Set<String>()
  /// Cap 9 / ADR-019: bumped on each [clearPlaybackPool]. In-flight prepare /
  /// warm callbacks must drop results when their captured epoch is stale.
  private var clearEpoch: UInt64 = 0
  /// Cap 18.3 / ADR-040: persistent intent mirror + one-shot nav activation.
  private var playbackIntentHostState = PlaybackIntentHostState()

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
  /// Cap 16.3: pending Pigeon `load` completions, keyed by asset id.
  /// Fan-out when a second `load` arrives while the same id is preparing.
  /// Main-thread only.
  private var loadCompletions: [String: [(Result<Void, Error>) -> Void]] = [:]

  init(binaryMessenger: FlutterBinaryMessenger) {
    flutterApi = PlaybackFlutterApi(binaryMessenger: binaryMessenger)
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

  #if DEBUG
  /// XCTest-only — Flutter attach-ack callbacks are discarded.
  convenience init() {
    self.init(binaryMessenger: NullFlutterBinaryMessenger())
  }
  #endif

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

  /// Cap 16.3: the single networked current-item fetch. Completes the
  /// Pigeon Future on playable / mapped failure / cancel.
  ///
  /// Timing vs `cancelInFlightPrepare(A)` then `load(B)` (Dart may
  /// `unawaited` cancel): Host API bodies run on the iOS platform (main)
  /// thread. Dart sends cancel(A) before load(B) on the same isolate, so
  /// cancel's synchronous work (table invalidate, `cancelImageRequest`,
  /// `preparingAssetIds.remove`, complete A's `load`) typically finishes
  /// before B starts. Different Pigeon methods are different channels —
  /// we do **not** rely on cross-channel FIFO alone.
  ///
  /// What this guarantees: no hanging `load` Future; id-keyed cancel never
  /// cancels B; stale A deliveries are dropped (generation +
  /// `currentAssetIdentifier == token`). `prepareActive` has no global
  /// "slot occupied by another id" mutex. Dart does not need to await
  /// cancel before `load(B)`.
  ///
  /// What it does **not** claim: the two arrival orders are equivalent.
  /// A late cancel(A) still completes A's Future, but A may have briefly
  /// entered `prepareActive` / PhotoKit transfer before being cancelled.
  /// 16.3 does not close that tail window; 16.5 observes whether it shows
  /// up in storage numbers.
  func load(
    item: PlaybackItemDto,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    let work = { [weak self] in
      guard let self else {
        completion(
          .failure(
            PigeonError(
              code: String(describing: ErrorCode.unknown),
              message: "Playback host deallocated",
              details: nil
            )
          )
        )
        return
      }
      let id = item.assetIdentifier
      let previousId = self.currentAssetIdentifier
            self.enqueueLoadCompletion(assetId: id, completion: completion)
      self.cancelImageRequestIfNeeded(self.replaceCurrentItem(id))
      if let previousId, previousId != id {
        self.finishLoad(
          assetId: previousId,
          result: .failure(
            self.fail(
              .operationCancelled,
              message: "Playback load superseded"
            )
          )
        )
      }
      self.currentFeedIndex = item.feedIndex
            if self.activeAssetId == id, self.activePlayer != nil {
        self.attachPlayerToSurface(self.activePlayer)
        self.registerItemEndObserverIfNeeded()
        self.consumePendingPlayIfNeeded()
        self.finishLoad(assetId: id, result: .success(()))
        self.warmNextIfPossible()
        return
      }
      self.prepareActive(assetId: id)
      self.warmNextIfPossible()
    }
    self.runOnMain(work)
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

  /// Cap 16.2 / ADR-029: cancel in-flight prepare for [assetIdentifier]
  /// even when it is still `currentAssetIdentifier` (no next `load()`).
  /// Cap 16.3: also completes that id's pending `load` with
  /// `operationCancelled`. Id-keyed — a late cancel(A) after `load(B)`
  /// does not cancel B.
  func cancelInFlightPrepare(assetIdentifier: String) throws {
    let work = { [weak self] in
      guard let self else { return }
      let result = self.currentPrepareTable.invalidate(assetId: assetIdentifier)
      self.cancelImageRequestIfNeeded(result.requestId)
      self.preparingAssetIds.remove(assetIdentifier)
      self.finishLoad(
        assetId: assetIdentifier,
        result: .failure(
          self.fail(
            .operationCancelled,
            message: "Playback load cancelled"
          )
        )
      )
    }
    runOnMain(work)
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

  func setTransitionAudioSuppressed(suppressed: Bool) throws {
    transitionAudioSuppressed = suppressed
        DispatchQueue.main.async { [weak self] in
      self?.applyMuteToPlayers()
    }
  }

  func getPlaybackPoolEpoch() throws -> Int64 {
    Int64(clearEpoch)
  }

  func setPlaybackPlan(plan: PlaybackPlanDto) throws {
    // Cap 16.3: plan bookkeeping only. Must not prepareActive / replace.
    self.plan = plan
  }

  func setPlaybackIntent(intent: PlaybackIntentDto) throws {
    runOnMain { [weak self] in
      guard let self else { return }
      self.playbackIntentHostState = PlaybackIntentStateReducer.applyIntent(
        state: self.playbackIntentHostState,
        incoming: intent,
        currentAssetIdentifier: self.currentAssetIdentifier,
        clearEpoch: self.clearEpoch
      )
    }
  }

  func syncPlanPosition(assetIdentifier: String, feedIndex: Int64) throws {
    // Cap 16.3: index only. Must not prepareActive / replaceCurrentItem.
    let idxBefore = currentFeedIndex
        currentFeedIndex = feedIndex
        if let plan {
      self.plan = PlaybackPlanDto(
        planId: plan.planId,
        orderedItems: plan.orderedItems,
        currentIndex: feedIndex
      )
    }
    _ = assetIdentifier
  }

  func notifyDisplaySurfaceReady(assetIdentifier: String) throws {
    restoreGuardActive = false
    // Cap 16.3: attach only. prepareActive here would be a second download.
    guard activeAssetId == assetIdentifier else { return }
    DispatchQueue.main.async { [weak self] in
      self?.adoptActivePlayerOntoSurface()
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
      guard let self else { return }
      self.performClearPlaybackPool()
    }
    runOnMain(work)
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

  /// Applies persisted [muted] and Cap 15.11 transition guard suppression.
  private func applyMuteToPlayers() {
    if transitionAudioSuppressed {
      activePlayer?.isMuted = true
      warmingPlayer?.isMuted = true
      return
    }
    activePlayer?.isMuted = muted
    warmingPlayer?.isMuted = muted
  }

  /// Single attach entry for all active-player → surface paths (Cap 15.11).
  /// Covers: [adoptPreparedPlayer], [adoptActivePlayerOntoSurface], warming
  /// promotion in [prepareActive], and [load] fast-path reattach.
  private func attachPlayerToSurface(_ player: AVPlayer?) {
        surfaceView?.attach(player: player)
    emitSurfaceAttachedAckIfNeeded(player: player)
  }

  /// Host → Dart attach-ack. Fires only when a non-nil [activePlayer] for
  /// [currentAssetIdentifier] is bound to the shared Platform View.
  private func emitSurfaceAttachedAckIfNeeded(player: AVPlayer?) {
    guard let player,
      player === activePlayer,
      let assetId = activeAssetId,
      assetId == currentAssetIdentifier
    else {
            return
    }
        flutterApi.onPlaybackSurfaceAttached(
      event: PlaybackSurfaceAttachedDto(
        assetIdentifier: assetId,
        feedIndex: currentFeedIndex,
        clearEpoch: Int64(clearEpoch)
      )
    ) { _ in }
  }

  /// Cap 15.11b: Host → Dart when [AVPlayerLayer.isReadyForDisplay] is true
  /// for the current active player. Same identity triple as attach-ack.
  func emitSurfaceReadyForDisplayIfNeeded() {
    guard let player = activePlayer,
      let assetId = activeAssetId,
      assetId == currentAssetIdentifier,
      let surfaceView,
      surfaceView.boundAssetId == assetId,
      surfaceView.playerLayerIsReadyForDisplay
    else {
            return
    }
        flutterApi.onPlaybackSurfaceReadyForDisplay(
      event: PlaybackSurfaceAttachedDto(
        assetIdentifier: assetId,
        feedIndex: currentFeedIndex,
        clearEpoch: Int64(clearEpoch)
      )
    ) { _ in }
  }

  private func performClearPlaybackPool() {
    unregisterItemEndObserver()
    transitionAudioSuppressed = false
    clearEpoch &+= 1
    pendingPlay = false
    preparingAssetIds.removeAll()
    // Cap 16.3: complete in-flight load Futures. Do not only bump epoch
    // and drop the Pigeon completion (Live Photo pre-empt would hang
    // `await load()` / `_layer2InFlight`).
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
    finishAllLoadsCancelled()
    playbackIntentHostState = PlaybackIntentStateReducer.clearIntentStateOnPoolClear()
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
    guard surfaceView != nil else { return }
    attachPlayerToSurface(activePlayer)
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

  private func runOnMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.sync(execute: work)
    }
  }

  private func fail(_ code: ErrorCode, message: String) -> PigeonError {
    PigeonError(code: String(describing: code), message: message, details: nil)
  }

  /// Same mapping as `PhotoLibraryService.layer2Failure` (do not invent codes).
  private func layer2Failure(
    cancelled: Bool,
    transferBegan: Bool,
    cancelledMessage: String,
    failedMessage: String,
    unavailableMessage: String
  ) -> PigeonError {
    if cancelled {
      return fail(.operationCancelled, message: cancelledMessage)
    }
    if transferBegan {
      return fail(.iCloudDownloadFailed, message: failedMessage)
    }
    return fail(.assetUnavailable, message: unavailableMessage)
  }

  /// Cap 17.5b: developer diagnosis before user-facing three-bucket collapse.
  /// Prints PhotoKit `info` detail (Profile/Debug Console) — not user copy.
  private func logLayer2PhotoKitFail(
    assetId: String,
    info: [AnyHashable: Any]?,
    cancelled: Bool,
    transferBegan: Bool,
    mappedCode: String
  ) {
    let dict = info ?? [:]
    let inCloud = dict[PHImageResultIsInCloudKey] as? Bool
    let phErrorDesc: String
    if let err = dict[PHImageErrorKey] as? NSError {
      phErrorDesc =
        "domain=\(err.domain) code=\(err.code) desc=\(err.localizedDescription)"
    } else if let raw = dict[PHImageErrorKey] {
      phErrorDesc = String(describing: raw)
    } else {
      phErrorDesc = "nil"
    }
    print(
      "[WakeTok][Layer2] fail id=\(String(assetId.prefix(8))) "
        + "cancelled=\(cancelled) transferBegan=\(transferBegan) "
        + "inCloud=\(String(describing: inCloud)) phError=\(phErrorDesc) "
        + "mapped=\(mappedCode)"
    )
  }

  private func enqueueLoadCompletion(
    assetId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    loadCompletions[assetId, default: []].append(completion)
  }

  private func finishLoad(assetId: String, result: Result<Void, Error>) {
    let ok: Bool
    let err: String
    if case .success = result {
      ok = true
      err = "ok"
    } else if case .failure(let error) = result {
      ok = false
      if let pigeon = error as? PigeonError {
        err = pigeon.code
      } else {
        err = String(describing: error)
      }
    } else {
      ok = false
      err = "unknown"
    }
        let comps = loadCompletions.removeValue(forKey: assetId) ?? []
    for completion in comps {
      completion(result)
    }
  }

  private func finishAllLoadsCancelled() {
    let ids = Array(loadCompletions.keys)
    for id in ids {
      finishLoad(
        assetId: id,
        result: .failure(
          fail(.operationCancelled, message: "Playback load cancelled")
        )
      )
    }
  }

  private func prepareActive(assetId: String) {
    if activeAssetId == assetId, activePlayer != nil {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.attachPlayerToSurface(self.activePlayer)
        self.registerItemEndObserverIfNeeded()
        self.consumePendingPlayIfNeeded()
      }
      finishLoad(assetId: assetId, result: .success(()))
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
        self.attachPlayerToSurface(self.activePlayer)
        self.registerItemEndObserverIfNeeded()
        self.consumePendingPlayIfNeeded()
      }
      finishLoad(assetId: assetId, result: .success(()))
      return
    }
    // Same asset already being prepared — wait on that prepare's
    // completion list. Do not early-return the new Pigeon Future.
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
          self.finishLoad(
            assetId: token,
            result: .failure(
              self.fail(
                .unsupportedMedia,
                message: "Not a video asset"
              )
            )
          )
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
        let transferBegan = self.currentPrepareTable.didTransferBegin(
          assetId: token,
          generation: generation
        )
        DispatchQueue.main.async {
          self.preparingAssetIds.remove(token)
          guard self.clearEpoch == epoch else { return }
          if cancelled || avAsset == nil {
            let pigeon = self.layer2Failure(
              cancelled: cancelled,
              transferBegan: transferBegan,
              cancelledMessage: "Playback load cancelled",
              failedMessage: "Playback download failed",
              unavailableMessage: "Failed to load playable video"
            )
            self.logLayer2PhotoKitFail(
              assetId: token,
              info: info,
              cancelled: cancelled,
              transferBegan: transferBegan,
              mappedCode: pigeon.code
            )
            self.finishLoad(
              assetId: token,
              result: .failure(pigeon)
            )
            return
          }
          guard let avAsset else { return }
          let player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
          self.adoptPreparedPlayer(player, token: token)
          self.finishLoad(assetId: token, result: .success(()))
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
      attachPlayerToSurface(activePlayer)
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
    attachPlayerToSurface(player)
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

  private func trustedUserIntentWantsPlay() -> Bool {
    PlaybackIntentStateReducer.trustedWantsPlay(
      state: playbackIntentHostState,
      currentAssetIdentifier: currentAssetIdentifier,
      clearEpoch: clearEpoch
    )
  }

  /// One-shot: validated pending navigation activation is consumed here.
  private func consumeTrustedStartsNewNavigationActivation() -> Bool {
    let pending = PlaybackIntentStateReducer.validatedPendingNavigationActivation(
      state: playbackIntentHostState,
      currentAssetIdentifier: currentAssetIdentifier,
      clearEpoch: clearEpoch
    )
    guard pending != nil else {
      return false
    }
    playbackIntentHostState.pendingNavigationActivation = nil
    return true
  }

  private func handleItemDidPlayToEnd(_ note: Notification) {
    let ended = note.object as? AVPlayerItem
    let observedIsCurrentItem =
      ended != nil
      && ended === observedEndItem
      && ended === activePlayer?.currentItem
    let isActiveCurrent = activeAssetId == currentAssetIdentifier
    // ADR-006 D4: background plan-advance must stopKeepPosition (no item loop).
    let trustedIntent = trustedUserIntentWantsPlay()
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: !backgroundPlanAdvanceActive,
      isBackgroundPlanAdvance: backgroundPlanAdvanceActive,
      isActiveCurrent: isActiveCurrent,
      observedItemIsCurrentItem: observedIsCurrentItem,
      trustedUserIntentWantsPlay: trustedIntent
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
    let trustedNav = consumeTrustedStartsNewNavigationActivation()
    switch VideoPlaybackPolicy.actionOnBecomeCurrent(
      playerExists: true,
      itemAtEnd: activeItemDidPlayToEnd,
      trustedStartsNewNavigationActivation: trustedNav
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

  func debugEnqueueLoadCompletion(
    _ assetId: String,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    enqueueLoadCompletion(assetId: assetId, completion: completion)
  }
  #endif
}

#if DEBUG
private final class NullFlutterBinaryMessenger: NSObject, FlutterBinaryMessenger {
  func send(onChannel channel: String, message: Data?) {}

  func send(
    onChannel channel: String,
    message: Data?,
    binaryReply callback: FlutterBinaryReply?
  ) {
    callback?(nil)
  }

  func setMessageHandlerOnChannel(
    _ channel: String,
    binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection {
    0
  }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
#endif

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
  /// Cap 15.11b: KVO edge → product ready-for-display event.
  private var readyForDisplayObservation: NSKeyValueObservation?
  private var lastReadyForDisplay: Bool?
  private var didEmitReadyForDisplay = false

  var playerLayerIsReadyForDisplay: Bool { playerLayer.isReadyForDisplay }

  init(frame: CGRect, assetId: String, host: PlaybackApiHost?) {
    boundAssetId = assetId
    self.host = host
    container = PlaybackSurfaceContainer(frame: frame)
    container.backgroundColor = .black
    playerLayer.videoGravity = .resizeAspect
    container.playerLayer = playerLayer
    container.layer.addSublayer(playerLayer)
    super.init()
    host?.bindSurface(self)
    startReadyForDisplayProbe()
  }

  deinit {
    readyForDisplayObservation?.invalidate()
    host?.unbindSurface(self)
  }

  func view() -> UIView {
    container
  }

  func attach(player: AVPlayer?) {
    // New player bind → allow a fresh ready-for-display emit.
    didEmitReadyForDisplay = false
    playerLayer.player = player
    playerLayer.frame = container.bounds
    noteReadyForDisplayEdge(force: true)
  }

  private func startReadyForDisplayProbe() {
    readyForDisplayObservation?.invalidate()
    lastReadyForDisplay = playerLayer.isReadyForDisplay
    readyForDisplayObservation = playerLayer.observe(
      \.isReadyForDisplay,
      options: [.new, .old]
    ) { [weak self] _, change in
      guard let self else { return }
      let next = change.newValue ?? self.playerLayer.isReadyForDisplay
      self.noteReadyForDisplayEdge(force: false, next: next)
    }
  }

  private func noteReadyForDisplayEdge(
    force: Bool,
    next: Bool? = nil
  ) {
    let value = next ?? playerLayer.isReadyForDisplay
    if !force, let prev = lastReadyForDisplay, prev == value {
      return
    }
    lastReadyForDisplay = value
    if value, !didEmitReadyForDisplay {
      didEmitReadyForDisplay = true
      host?.emitSurfaceReadyForDisplayIfNeeded()
    }
    if !value {
      didEmitReadyForDisplay = false
    }
  }
}
