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
final class PlaybackApiHost: PlaybackApi, PlaybackSurfaceUserInteractionGate {
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

  /// Cap 18.2 / ADR-040 Decision 13: periodic runtime observe for scrubber (18.5).
  private let runtimeObserver = PlaybackRuntimeObserver()
  private let scrubPreviewQueue = DispatchQueue(
    label: "com.dennycgan.waketok.playback.scrubpreview",
    qos: .userInitiated
  )
  /// Single-flight guard: one generate at a time; newer calls coalesce.
  private var scrubPreviewInFlight = false
  private var scrubPreviewPendingSeconds: Double?
  private var scrubPreviewPendingCompletion:
    ((Result<ScrubPreviewFrameDto?, Error>) -> Void)?
#if DEBUG
  private(set) var debugRuntimeEventsForTests: [PlaybackRuntimeEventDto] = []
#endif

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
  /// Supersedes stale `AVPlayer.seek` completions (scrub vs loop seek-zero).
  private var playbackSeekEpoch: UInt64 = 0
  /// Zero-tolerance scrub seeks on short local clips may never call back.
  private let scrubSeekWallClockTimeoutSeconds: TimeInterval = 0.45
  /// Cap 19.8 Bug B probe — in-flight until the real AVPlayer seek callback.
  private var scrubSeekProbeSeq: UInt64 = 0
  private var scrubSeekInFlight = false
  private var scrubSeekStartedAtMs: Int64 = 0
  private var scrubSeekTargetSeconds: Double = 0

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
    runtimeObserver.configure(
      snapshot: { [weak self] in
        self?.makeRuntimeSnapshot() ?? .empty
      },
      emit: { [weak self] dto in
        self?.emitRuntimeEvent(dto)
      }
    )
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
      self.syncRuntimeObserve()
      self.emitRuntimeObserveNow()
    }
  }

  func playFromCurrentPosition() throws {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.adoptActivePlayerOntoSurface()
      self.playActiveFromCurrentPosition()
      self.syncRuntimeObserve()
      self.emitRuntimeObserveNow()
    }
  }

  func pause() throws {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      if self.scrubSeekInFlight {
        ScrubPreviewProbe.seekDiag(
          "host pause seq=\(self.scrubSeekProbeSeq) "
            + "targetSec=\(String(format: "%.2f", self.scrubSeekTargetSeconds)) "
            + "playerTime=\(self.scrubProbePlayerTimeLabel()) "
            + "seekInFlightAtPause=true"
        )
      }
      self.pendingPlay = false
      self.activePlayer?.pause()
      self.syncRuntimeObserve()
      self.emitRuntimeObserveNow()
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

  func seek(
    positionSeconds: Double,
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
      guard let player = self.activePlayer,
        self.activeAssetId == self.currentAssetIdentifier
      else {
        completion(.success(()))
        return
      }
      // User chose an explicit position — cancel loop seek-zero and end state.
      self.activeItemDidPlayToEnd = false
      self.endSeekInFlight = false
      let seekEpoch = self.bumpPlaybackSeekEpoch()
      let time = CMTime(seconds: positionSeconds, preferredTimescale: 600)
      var completionSent = false
      let finishSeek: (Result<Void, Error>) -> Void = { result in
        guard !completionSent else { return }
        completionSent = true
        completion(result)
      }
      self.scrubSeekProbeSeq &+= 1
      let probeSeq = self.scrubSeekProbeSeq
      self.scrubSeekInFlight = true
      self.scrubSeekTargetSeconds = positionSeconds
      self.scrubSeekStartedAtMs = self.scrubProbeNowMs()
      ScrubPreviewProbe.seekDiag(
        "host start seq=\(probeSeq) "
          + "targetSec=\(String(format: "%.2f", positionSeconds)) "
          + "playerTime=\(self.scrubProbePlayerTimeLabel()) "
          + "inFlight=true"
      )
      player.seek(
        to: time,
        toleranceBefore: .zero,
        toleranceAfter: .zero
      ) { [weak self] finished in
        guard let self else {
          finishSeek(.success(()))
          return
        }
        let elapsedMs = self.scrubProbeNowMs() - self.scrubSeekStartedAtMs
        let afterTimeout = completionSent
        let stillCurrentSeek = seekEpoch == self.playbackSeekEpoch
        if stillCurrentSeek {
          self.scrubSeekInFlight = false
        }
        ScrubPreviewProbe.seekDiag(
          "host realComplete seq=\(probeSeq) "
            + "targetSec=\(String(format: "%.2f", positionSeconds)) "
            + "elapsedMs=\(elapsedMs) "
            + "playerTime=\(self.scrubProbePlayerTimeLabel()) "
            + "finished=\(finished) "
            + "completedAfterTimeout=\(afterTimeout) "
            + "superseded=\(!stillCurrentSeek)"
        )
        guard stillCurrentSeek else {
          finishSeek(
            .failure(
              PigeonError(
                code: String(describing: ErrorCode.unknown),
                message: "Playback seek superseded",
                details: nil
              )
            )
          )
          return
        }
        self.syncRuntimeObserve()
        self.emitRuntimeObserveNow()
        finishSeek(.success(()))
      }
      DispatchQueue.main.asyncAfter(
        deadline: .now() + self.scrubSeekWallClockTimeoutSeconds
      ) { [weak self] in
        guard let self, !completionSent else { return }
        guard seekEpoch == self.playbackSeekEpoch else {
          finishSeek(
            .failure(
              PigeonError(
                code: String(describing: ErrorCode.unknown),
                message: "Playback seek superseded",
                details: nil
              )
            )
          )
          return
        }
        let elapsedMs = self.scrubProbeNowMs() - self.scrubSeekStartedAtMs
        ScrubPreviewProbe.seekDiag(
          "host timeout seq=\(probeSeq) "
            + "targetSec=\(String(format: "%.2f", positionSeconds)) "
            + "elapsedMs=\(elapsedMs) "
            + "playerTime=\(self.scrubProbePlayerTimeLabel()) "
            + "timedOut=true "
            + "wouldHaveFailedHonestTimeout=true "
            + "seekInFlight=\(self.scrubSeekInFlight)"
        )
        self.syncRuntimeObserve()
        self.emitRuntimeObserveNow()
        finishSeek(.success(()))
      }
    }
    runOnMain(work)
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

  /// Cap 20.4: Flutter pinch matrix → bound Platform View container.
  /// Identity (1,0,0) restores fit. No-op without a surface. Does not pause.
  func setDisplayMagnification(
    scale: Double,
    translationX: Double,
    translationY: Double
  ) throws {
    runOnMain { [weak self] in
      self?.surfaceView?.applyDisplayMagnification(
        scale: CGFloat(scale),
        translationX: CGFloat(translationX),
        translationY: CGFloat(translationY)
      )
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

  func requestScrubPreviewFrame(
    positionSeconds: Double,
    completion: @escaping (Result<ScrubPreviewFrameDto?, Error>) -> Void
  ) {
    runOnMain { [weak self] in
      guard let self else {
        completion(.success(nil))
        return
      }
      guard let player = self.activePlayer,
        self.activeAssetId == self.currentAssetIdentifier,
        let item = player.currentItem
      else {
        ScrubPreviewProbe.info(
          "nil position=\(String(format: "%.2f", positionSeconds)) reason=noActivePlayer"
        )
        completion(.success(nil))
        return
      }
      if self.scrubPreviewInFlight {
        self.scrubPreviewPendingCompletion?(.success(nil))
        self.scrubPreviewPendingSeconds = positionSeconds
        self.scrubPreviewPendingCompletion = completion
        ScrubPreviewProbe.info(
          "coalesced position=\(String(format: "%.2f", positionSeconds)) reason=inFlight"
        )
        return
      }
      self.startScrubPreviewWork(
        positionSeconds: positionSeconds,
        asset: item.asset,
        completion: completion
      )
    }
  }

  private func startScrubPreviewWork(
    positionSeconds: Double,
    asset: AVAsset,
    completion: @escaping (Result<ScrubPreviewFrameDto?, Error>) -> Void
  ) {
    scrubPreviewInFlight = true
    scrubPreviewPendingSeconds = nil
    scrubPreviewPendingCompletion = nil
    let time = CMTime(seconds: positionSeconds, preferredTimescale: 600)
    let started = CFAbsoluteTimeGetCurrent()
    // Duration from the same AVAsset used for generation (PhotoKit-backed).
    let durationSeconds = CMTimeGetSeconds(asset.duration)
    let tolerance = PlaybackScrubPreview.toleranceForRequest(
      positionSeconds: positionSeconds,
      durationSeconds: durationSeconds
    )
    ScrubPreviewProbe.info(
      "start position=\(String(format: "%.2f", positionSeconds)) "
        + "duration=\(String(format: "%.2f", durationSeconds)) "
        + "tol=\(tolerance.label) endCap=\(PlaybackScrubPreview.isEndCapRequest(positionSeconds: positionSeconds, durationSeconds: durationSeconds))"
    )
    scrubPreviewQueue.async { [weak self] in
      let (previewResult, actualTime) = PlaybackScrubPreview.generateResult(
        asset: asset,
        time: time,
        tolerance: tolerance
      )
      let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - started) * 1000)
      let actualSeconds = CMTimeGetSeconds(actualTime)
      DispatchQueue.main.async { [weak self] in
        guard let self else {
          completion(.success(nil))
          return
        }
        self.scrubPreviewInFlight = false
        switch previewResult {
        case .success(let data):
          let actualFinite = actualSeconds.isFinite
          ScrubPreviewProbe.info(
            "ok position=\(String(format: "%.2f", positionSeconds)) "
              + "actual=\(String(format: "%.2f", actualFinite ? actualSeconds : -1)) "
              + "tol=\(tolerance.label) bytes=\(data.count) ms=\(elapsedMs)"
          )
          if actualFinite {
            completion(
              .success(
                ScrubPreviewFrameDto(
                  jpegBytes: FlutterStandardTypedData(bytes: data),
                  actualSeconds: actualSeconds
                )
              )
            )
          } else {
            // Missing/invalid actual — Dart treats as equivalent failure.
            completion(.success(nil))
          }
        case .failure(let reason):
          ScrubPreviewProbe.info(
            "nil position=\(String(format: "%.2f", positionSeconds)) "
              + "tol=\(tolerance.label) reason=\(reason) ms=\(elapsedMs)"
          )
          completion(.success(nil))
        }
        if let pendingSeconds = self.scrubPreviewPendingSeconds,
          let pendingCompletion = self.scrubPreviewPendingCompletion,
          let player = self.activePlayer,
          self.activeAssetId == self.currentAssetIdentifier,
          let item = player.currentItem
        {
          self.scrubPreviewPendingSeconds = nil
          self.scrubPreviewPendingCompletion = nil
          self.startScrubPreviewWork(
            positionSeconds: pendingSeconds,
            asset: item.asset,
            completion: pendingCompletion
          )
        }
      }
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
      // If Share still holds wrapper gate state, restore before dropping the
      // bound surface (idempotent when idle).
      endBoundPlatformViewWrapperShareGate(phase: "unbind")
      view.applyDisplayMagnification(scale: 1, translationX: 0, translationY: 0)
      view.attach(player: nil)
      surfaceView = nil
    }
  }

  /// Cap 25 Share: toggle UIKit hit-testing on the single bound
  /// `PlaybackSurfaceView` only (`nil` → no-op). Does not touch the 1+1
  /// AVPlayer pool or Live Photo surface.
  func setBoundSurfaceUserInteractionEnabled(_ enabled: Bool) {
    surfaceView?.view().isUserInteractionEnabled = enabled
  }

  // MARK: - Cap 25 Bug#1 Option 1 (engine wrapper hit-test gate)

  /// Single-present slot for wrapper `isUserInteractionEnabled` restore.
  /// Cleared at every `begin` and after every `end` — never retained across
  /// Share presents.
  private struct ShareWrapperGateEntry {
    weak var view: UIView?
    let previousEnabled: Bool
  }

  private var shareWrapperGateEntries: [ShareWrapperGateEntry] = []
  private var shareWrapperGateHitLabel: String = "none"
  private var shareWrapperGateArmed: Bool = false

  /// Exact class-name whitelist (Flutter 3.41.9 / Engine `42d3d75a56`).
  /// Do not use fuzzy `isKindOf` against private base classes.
  private static let shareWrapperClassNames: Set<String> = [
    "ChildClippingView",
    "FlutterTouchInterceptingView",
  ]
  private static let shareWrapperEngineRevision = "42d3d75a56"
  private static let shareWrapperWalkMaxDepth = 4

  func beginBoundPlatformViewWrapperShareGate() {
    // Single-present slot: if a prior present leaked state, restore then rebuild.
    if !shareWrapperGateEntries.isEmpty || shareWrapperGateArmed {
      endBoundPlatformViewWrapperShareGate(phase: "present_reenter_clear")
    }
    shareWrapperGateEntries.removeAll(keepingCapacity: false)
    shareWrapperGateHitLabel = "none"
    shareWrapperGateArmed = false

    guard let embedded = surfaceView?.view() else {
      emitShareWrapperGateProbe(
        phase: "present",
        armed: false,
        hit: "none",
        note: "no_bound_surface"
      )
      return
    }

    var foundClipping = false
    var foundIntercepting = false
    var matched: [(UIView, String)] = []

    var current: UIView? = embedded.superview
    var depth = 0
    while let view = current, depth < Self.shareWrapperWalkMaxDepth {
      let name = NSStringFromClass(type(of: view))
      if Self.shareWrapperClassNames.contains(name) {
        matched.append((view, name))
        if name == "ChildClippingView" {
          foundClipping = true
        } else if name == "FlutterTouchInterceptingView" {
          foundIntercepting = true
        }
      }
      current = view.superview
      depth += 1
    }

    let hitLabel =
      matched.isEmpty ? "none" : matched.map(\.1).joined(separator: "+")
    shareWrapperGateHitLabel = hitLabel

    // Outer layer is required. Intercepting-only is known-insufficient → no-op.
    guard foundClipping else {
      let note =
        foundIntercepting
        ? "missing_ChildClippingView_only_Intercepting" : "wrapper_not_found"
      emitShareWrapperGateProbe(
        phase: "present",
        armed: false,
        hit: hitLabel,
        note: note
      )
      return
    }

    for (view, _) in matched {
      shareWrapperGateEntries.append(
        ShareWrapperGateEntry(
          view: view,
          previousEnabled: view.isUserInteractionEnabled
        )
      )
      view.isUserInteractionEnabled = false
    }
    shareWrapperGateArmed = true
    emitShareWrapperGateProbe(
      phase: "present",
      armed: true,
      hit: hitLabel,
      note: nil
    )
  }

  func endBoundPlatformViewWrapperShareGate(phase: String) {
    let hitLabel = shareWrapperGateHitLabel
    let wasArmed = shareWrapperGateArmed
    for entry in shareWrapperGateEntries {
      if let view = entry.view {
        view.isUserInteractionEnabled = entry.previousEnabled
      }
    }
    shareWrapperGateEntries.removeAll(keepingCapacity: false)
    shareWrapperGateHitLabel = "none"
    shareWrapperGateArmed = false
    emitShareWrapperGateProbe(
      phase: phase,
      armed: wasArmed,
      hit: hitLabel,
      note: wasArmed ? "restored" : "noop"
    )
  }

  private func emitShareWrapperGateProbe(
    phase: String,
    armed: Bool,
    hit: String,
    note: String?
  ) {
    var parts = [
      "WT_CAP25_PROBE|share_pv_wrapper_gate",
      "phase=\(phase)",
      "armed=\(armed)",
      "hit=\(hit)",
      "engine=\(Self.shareWrapperEngineRevision)",
    ]
    if let note, !note.isEmpty {
      parts.append("note=\(note)")
    }
    let line = parts.joined(separator: "|")
    // ignore: print — Profile device capture via flutter run / logs
    print(line)
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
    runtimeObserver.stop()
    emitRuntimeObserveNow()
    // Do not reset `muted` — Dart preference remains; next player re-applies.
  }

  private func handleDidEnterBackground() {
    // Detach picture only; keep AVPlayer alive (ADR-006 surface model).
    surfaceView?.attach(player: nil)
    activePlayer?.pause()
    emitRuntimeObserveNow()
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
    emitRuntimeObserveNow()

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
      syncRuntimeObserve()
      emitRuntimeObserveNow()
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
    syncRuntimeObserve()
    emitRuntimeObserveNow()
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
        pendingPlay = true
        return
      }
      endSeekInFlight = true
      seekZeroAndPlay(player)
    case .playOnly:
      player.play()
      syncRuntimeObserve()
      emitRuntimeObserveNow()
    case .prepareNew:
      break
    }
  }

  /// Cap 18.5 scrub release — resume without re-enter seek-to-zero policy.
  private func playActiveFromCurrentPosition() {
    guard let player = activePlayer,
      activeAssetId == currentAssetIdentifier
    else {
      pendingPlay = true
      return
    }
    ScrubPreviewProbe.seekDiag(
      "host play seq=\(scrubSeekProbeSeq) "
        + "targetSec=\(String(format: "%.2f", scrubSeekTargetSeconds)) "
        + "playerTime=\(scrubProbePlayerTimeLabel()) "
        + "seekInFlightAtPlay=\(scrubSeekInFlight)"
    )
    pendingPlay = false
    applyMuteToPlayers()
    player.play()
  }

  private func scrubProbeNowMs() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1000)
  }

  private func scrubProbePlayerTimeLabel() -> String {
    guard let seconds = activePlayer?.currentTime().seconds, seconds.isFinite else {
      return "na"
    }
    return String(format: "%.2f", seconds)
  }

  private func bumpPlaybackSeekEpoch() -> UInt64 {
    playbackSeekEpoch &+= 1
    return playbackSeekEpoch
  }

  private func seekZeroAndPlay(_ player: AVPlayer?) {
    guard let player else {
      endSeekInFlight = false
      return
    }
    let token = activeAssetId
    // Capture epoch without bumping — user scrub seek bumps to invalidate this.
    let seekEpoch = playbackSeekEpoch
    player.seek(to: .zero) { [weak self] finished in
      guard let self else { return }
      self.endSeekInFlight = false
      guard seekEpoch == self.playbackSeekEpoch else {
        return
      }
      guard finished else { return }
      guard self.activePlayer === player,
        self.activeAssetId == token,
        self.currentAssetIdentifier == token
      else { return }
      self.activeItemDidPlayToEnd = false
      player.play()
      self.syncRuntimeObserve()
      self.emitRuntimeObserveNow()
    }
  }

  private func makeRuntimeSnapshot() -> PlaybackRuntimeSnapshot {
    var position: Double = 0
    if let player = activePlayer,
      activeAssetId == currentAssetIdentifier
    {
      let time = player.currentTime()
      if time.isNumeric {
        position = time.seconds
      }
    }
    let preparing =
      currentAssetIdentifier.map { preparingAssetIds.contains($0) } ?? false
    return PlaybackRuntimeSnapshot(
      planId: plan?.planId ?? "",
      currentAssetIdentifier: currentAssetIdentifier,
      currentIndex: currentFeedIndex,
      playbackPositionSeconds: position,
      activeAssetId: activeAssetId,
      hasActivePlayer: activePlayer != nil,
      isPreparingCurrent: preparing,
      timeControlStatus: activePlayer?.timeControlStatus,
      rate: activePlayer?.rate ?? 0,
      activeItemDidPlayToEnd: activeItemDidPlayToEnd,
      durationSeconds: Self.durationSeconds(for: activePlayer)
    )
  }

  private static func durationSeconds(for player: AVPlayer?) -> Double? {
    guard let item = player?.currentItem else { return nil }
    let duration = item.duration
    guard duration.isNumeric, !duration.isIndefinite else { return nil }
    let seconds = duration.seconds
    guard seconds.isFinite, seconds > 0 else { return nil }
    return seconds
  }

  private func emitRuntimeEvent(_ dto: PlaybackRuntimeEventDto) {
#if DEBUG
    debugRuntimeEventsForTests.append(dto)
#endif
    flutterApi.onPlaybackRuntimeEvent(event: dto) { _ in }
  }

  private func syncRuntimeObserve() {
    if activePlayer != nil, activeAssetId == currentAssetIdentifier {
      runtimeObserver.sync(to: activePlayer)
    } else {
      runtimeObserver.sync(to: nil)
    }
  }

  private func emitRuntimeObserveNow() {
    runtimeObserver.emitImmediate()
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

  func debugDrainRuntimeEventsForTests() -> [PlaybackRuntimeEventDto] {
    defer { debugRuntimeEventsForTests.removeAll() }
    return debugRuntimeEventsForTests
  }

  func debugSetRuntimeObserveContextForTests(
    planId: String,
    currentAssetIdentifier: String?,
    feedIndex: Int64,
    activeAssetId: String?,
    activePlayer: AVPlayer?,
    activeItemDidPlayToEnd: Bool = false
  ) {
    if planId.isEmpty {
      plan = nil
    } else {
      plan = PlaybackPlanDto(
        planId: planId,
        orderedItems: [],
        currentIndex: feedIndex
      )
    }
    self.currentAssetIdentifier = currentAssetIdentifier
    currentFeedIndex = feedIndex
    self.activeAssetId = activeAssetId
    self.activePlayer = activePlayer
    self.activeItemDidPlayToEnd = activeItemDidPlayToEnd
    syncRuntimeObserve()
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
  /// Inner leaf that receives display magnification. Flutter embedding may
  /// `setFrame` on this outer container at any time; keeping outer transform
  /// identity prevents UIKit from folding scale into `bounds` (Cap 20 shrink).
  let magnificationContent = UIView()
  var playerLayer: AVPlayerLayer?

  override init(frame: CGRect) {
    super.init(frame: frame)
    clipsToBounds = true
    magnificationContent.backgroundColor = .clear
    addSubview(magnificationContent)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    clipsToBounds = true
    magnificationContent.backgroundColor = .clear
    addSubview(magnificationContent)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    // bounds + center are safe while [magnificationContent] has a non-identity
    // transform; assigning `frame` would reintroduce the shrink bug.
    magnificationContent.bounds = CGRect(origin: .zero, size: bounds.size)
    magnificationContent.center = CGPoint(x: bounds.midX, y: bounds.midY)
    playerLayer?.frame = magnificationContent.bounds
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
    container.magnificationContent.layer.addSublayer(playerLayer)
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
    playerLayer.frame = container.magnificationContent.bounds
    noteReadyForDisplayEdge(force: true)
  }

  /// Cap 20.4 / Decision 13: apply scale/translation on the **inner**
  /// magnification content view only. The Flutter-owned outer container stays
  /// at identity so Platform View `setFrame` cannot fold scale into bounds.
  ///
  /// Do **not** mutate [AVPlayerLayer] anchorPoint / bounds / affineTransform
  /// each pinch frame — layout resets `playerLayer.frame = bounds`.
  func applyDisplayMagnification(
    scale: CGFloat,
    translationX: CGFloat,
    translationY: CGFloat
  ) {
    let content = container.magnificationContent
    let s = max(scale, 0.01)
    if abs(s - 1) < 0.001, abs(translationX) < 0.5, abs(translationY) < 0.5 {
      content.transform = .identity
      return
    }
    // Default layer anchor (0.5, 0.5) → scale about view center, then
    // translate in logical pixels (matches Flutter Transform alignment.center).
    content.transform = CGAffineTransform(scaleX: s, y: s)
      .translatedBy(x: translationX / s, y: translationY / s)
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
