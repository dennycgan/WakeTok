import AVFoundation
import Flutter
import Foundation
import UIKit

/// Lock-screen feed audio probe: lifecycle detach/attach + plan advance.
///
/// Uses AVQueuePlayer lookahead (insert next before current ends). Background
/// replaceCurrentItem/play() is intentionally avoided — it yields silent rate=1.
final class Poc04LockAudioProbe {
  static let shared = Poc04LockAudioProbe()

  private var enabled = false
  private var plan: [(assetId: String, feedIndex: Int)] = []
  private var planIndex = -1
  private var layerDetached = false
  private var restoreGuard = false
  private var lastEvent: String = ""
  private var lifecycleObservers: [NSObjectProtocol] = []
  private var itemEndObserver: NSObjectProtocol?
  private var flutterApi: Poc04LockProbeFlutterApi?
  private var advanceTask: UIBackgroundTaskIdentifier = .invalid
  private var advancing = false

  private init() {}

  private func log(_ message: String) {
    NSLog("[Poc04LockAudio] %@", message)
  }

  func configure(flutterApi: Poc04LockProbeFlutterApi) {
    self.flutterApi = flutterApi
  }

  var isEnabled: Bool { enabled }
  var isLayerDetached: Bool { layerDetached }
  var isRestoreGuardActive: Bool { restoreGuard }

  func setEnabled(_ value: Bool, completion: @escaping () -> Void) {
    if value == enabled {
      if value {
        primeQueue(reason: "reenable") { completion() }
      } else {
        completion()
      }
      return
    }
    enabled = value
    if value {
      Poc04PlayerPool.shared.setUseTextureSurface(false)
      installLifecycleObservers()
      installItemEndObserver()
      activateSession()
      Poc04PlayerPool.shared.applyLockProbeAudioPolicy(unmuted: true)
      lastEvent = "enabled"
      log("lock probe enabled")
      primeQueue(reason: "enable") { completion() }
    } else {
      removeLifecycleObservers()
      removeItemEndObserver()
      endAdvanceTask()
      advancing = false
      layerDetached = false
      restoreGuard = false
      Poc04PlayerPool.shared.applyLockProbeAudioPolicy(unmuted: false)
      NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: nil)
      lastEvent = "disabled"
      log("lock probe disabled")
      completion()
    }
  }

  func setPlaybackPlan(_ items: [Poc04PlaybackPlanItem]) {
    plan = items.map { ($0.assetId, Int($0.feedIndex)) }
    if let active = Poc04PlayerPool.shared.activeAssetIdValue {
      if let idx = plan.firstIndex(where: { $0.assetId == active }) {
        planIndex = idx
      }
    }
    lastEvent = "plan:\(plan.count)"
    log("plan count=\(self.plan.count) index=\(self.planIndex)")
    if enabled {
      enqueueNext(reason: "plan")
    }
  }

  func syncPlanPosition(assetId: String, feedIndex: Int) {
    if let idx = plan.firstIndex(where: {
      $0.assetId == assetId && $0.feedIndex == feedIndex
    }) {
      planIndex = idx
    } else if let idx = plan.firstIndex(where: { $0.assetId == assetId }) {
      planIndex = idx
    }
    lastEvent = "sync:\(planIndex)"
    if enabled {
      enqueueNext(reason: "sync")
    }
  }

  /// Called after pool attachActive finishes while probe is on.
  func onActiveAttached(assetId: String) {
    if let idx = plan.firstIndex(where: { $0.assetId == assetId }) {
      planIndex = idx
    }
    enqueueNext(reason: "attach")
  }

  func notifyPlatformViewReady(assetId: String) {
    guard enabled else { return }
    layerDetached = false
    restoreGuard = false
    NotificationCenter.default.post(name: .poc04PlayerPoolDidChange, object: assetId)
    lastEvent = "reattach"
    enqueueNext(reason: "reattach")
    log("reattach asset=\(assetId)")
  }

  func snapshotState() -> Poc04LockProbeState {
    let playing = Poc04PlayerPool.shared.isActivePlaying
    let activeId = Poc04PlayerPool.shared.activeAssetIdValue
    let feed: Int64
    if planIndex >= 0, planIndex < plan.count {
      feed = Int64(plan[planIndex].feedIndex)
    } else {
      feed = -1
    }
    return Poc04LockProbeState(
      enabled: enabled,
      layerDetached: layerDetached,
      playing: playing,
      planIndex: Int64(planIndex),
      feedIndex: feed,
      activeAssetId: activeId,
      lastEvent: lastEvent.isEmpty ? nil : lastEvent
    )
  }

  // MARK: - Queue priming

  /// Upgrade to AVQueuePlayer if needed, then enqueue plan[planIndex+1].
  private func primeQueue(reason: String, completion: @escaping () -> Void) {
    Poc04PlayerPool.shared.ensureActiveIsQueuePlayerForLockProbe { [weak self] in
      guard let self else {
        completion()
        return
      }
      self.enqueueNext(reason: reason) {
        let n = Poc04PlayerPool.shared.activeQueueItemCount
        self.log("prime(\(reason)) done queueItems=\(n)")
        completion()
      }
    }
  }

  private func enqueueNext(reason: String, completion: (() -> Void)? = nil) {
    guard enabled else {
      completion?()
      return
    }
    guard !plan.isEmpty else {
      completion?()
      return
    }
    let warmIdx = planIndex + 1
    guard warmIdx >= 0, warmIdx < plan.count else {
      log("enqueue(\(reason)) no next (planIndex=\(planIndex))")
      completion?()
      return
    }
    let assetId = plan[warmIdx].assetId
    Poc04PlayerPool.shared.prefetchLockProbeItem(assetId: assetId) { [weak self] result in
      guard let self else {
        completion?()
        return
      }
      switch result {
      case .failure(let error):
        self.log("enqueue(\(reason)) fail \(error.localizedDescription)")
      case .success:
        let n = Poc04PlayerPool.shared.activeQueueItemCount
        let isQueue = Poc04PlayerPool.shared.activePlayerIsQueue
        self.log(
          "enqueue(\(reason)) \(assetId) queueItems=\(n) isQueue=\(isQueue)"
        )
      }
      completion?()
    }
  }

  // MARK: - Lifecycle

  private func installLifecycleObservers() {
    removeLifecycleObservers()
    let center = NotificationCenter.default
    lifecycleObservers.append(
      center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.handleDidEnterBackground()
      }
    )
    lifecycleObservers.append(
      center.addObserver(
        forName: UIApplication.willEnterForegroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.handleWillEnterForeground()
      }
    )
  }

  private func removeLifecycleObservers() {
    for observer in lifecycleObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    lifecycleObservers.removeAll()
  }

  private func handleDidEnterBackground() {
    guard enabled else { return }
    layerDetached = true
    activateSession()
    NotificationCenter.default.post(name: .poc04DetachLayers, object: nil)
    beginAdvanceTask()
    // Last chance: must have current+next in queue before suspension.
    primeQueue(reason: "background") { [weak self] in
      guard let self else { return }
      let n = Poc04PlayerPool.shared.activeQueueItemCount
      self.lastEvent = "detached"
      self.log(
        "didEnterBackground det=Y planIndex=\(self.planIndex) queueItems=\(n)"
      )
      if n < 2 {
        self.log("WARNING background queueItems<\(2) — P2 will fail")
      }
      self.endAdvanceTask()
    }
  }

  private func handleWillEnterForeground() {
    guard enabled else { return }
    restoreGuard = true
    let feedIndex: Int64
    let assetId: String
    if planIndex >= 0, planIndex < plan.count {
      feedIndex = Int64(plan[planIndex].feedIndex)
      assetId = plan[planIndex].assetId
    } else if let active = Poc04PlayerPool.shared.activeAssetIdValue {
      feedIndex = 0
      assetId = active
    } else {
      lastEvent = "fg:noActive"
      restoreGuard = false
      return
    }
    lastEvent = "fg:\(feedIndex)"
    log("willEnterForeground feed=\(feedIndex)")
    flutterApi?.onLockProbeForeground(
      feedIndex: feedIndex,
      assetId: assetId
    ) { _ in }
  }

  // MARK: - Item end

  private func installItemEndObserver() {
    removeItemEndObserver()
    itemEndObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: nil,
      queue: .main
    ) { [weak self] note in
      self?.handleItemDidPlayToEnd(note)
    }
  }

  private func removeItemEndObserver() {
    if let itemEndObserver {
      NotificationCenter.default.removeObserver(itemEndObserver)
    }
    itemEndObserver = nil
  }

  private func handleItemDidPlayToEnd(_ note: Notification) {
    guard enabled else { return }
    guard note.object is AVPlayerItem else { return }

    let inBackground = UIApplication.shared.applicationState == .background
    guard layerDetached || inBackground else {
      log("itemEnd ignored (foreground, det=N)")
      return
    }
    if !layerDetached {
      layerDetached = true
    }

    let n = Poc04PlayerPool.shared.activeQueueItemCount
    let playing = Poc04PlayerPool.shared.isActivePlaying
    log("itemEnd queueItems=\(n) playing=\(playing)")
    DispatchQueue.main.async { [weak self] in
      self?.noteQueueAutoAdvanced()
    }
  }

  private func noteQueueAutoAdvanced() {
    guard !advancing else { return }
    guard !plan.isEmpty else { return }

    let next = planIndex + 1
    if next >= plan.count {
      lastEvent = "planEnded"
      log("planEnded at index=\(self.planIndex)")
      let feed = planIndex >= 0 ? Int64(plan[planIndex].feedIndex) : Int64(-1)
      let id = planIndex >= 0 ? plan[planIndex].assetId : ""
      flutterApi?.onLockProbePlanEnded(feedIndex: feed, assetId: id) { _ in }
      return
    }

    advancing = true
    activateSession()
    planIndex = next
    let target = plan[next]
    Poc04PlayerPool.shared.adoptQueueCurrentItem(assetId: target.assetId)

    let playing = Poc04PlayerPool.shared.isActivePlaying
    let qCount = Poc04PlayerPool.shared.activeQueueItemCount
    lastEvent = "queueAdv:\(next)"
    log(
      "queue auto-advanced planIndex=\(next) feed=\(target.feedIndex) playing=\(playing) queueItems=\(qCount)"
    )
    enqueueNext(reason: "afterAdv")
    advancing = false
  }

  private func beginAdvanceTask() {
    endAdvanceTask()
    advanceTask = UIApplication.shared.beginBackgroundTask(
      withName: "poc04.lockAdvance"
    ) { [weak self] in
      self?.log("advance background task expired")
      self?.endAdvanceTask()
    }
  }

  private func endAdvanceTask() {
    guard advanceTask != .invalid else { return }
    UIApplication.shared.endBackgroundTask(advanceTask)
    advanceTask = .invalid
  }

  private func activateSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true)
    } catch {
      lastEvent = "sessionFail"
      log("sessionFail \(error.localizedDescription)")
    }
  }
}

extension Notification.Name {
  static let poc04DetachLayers = Notification.Name("poc04DetachLayers")
}
