import AVFoundation
import ImageIO
import Photos
import UniformTypeIdentifiers
import XCTest

@testable import Runner

final class PreviewTempFileStoreTests: XCTestCase {
  override func tearDown() {
    for id in ["a", "b", "c", "d", "x", "w"] {
      PreviewTempFileStore.shared.release(assetId: id)
      DisplayTempFileStore.shared.release(assetId: id)
    }
    super.tearDown()
  }

  func testLruEvictsOldestWhenCapExceeded() throws {
    let store = PreviewTempFileStore.shared
    let data = Data("preview".utf8)
    let pathA = try store.replace(assetId: "a", data: data)
    _ = try store.replace(assetId: "b", data: data)
    _ = try store.replace(assetId: "c", data: data)
    XCTAssertEqual(store.fileCountForTests, 3)
    _ = try store.replace(assetId: "d", data: data)
    XCTAssertEqual(store.fileCountForTests, 3)
    XCTAssertFalse(FileManager.default.fileExists(atPath: pathA))
    XCTAssertNil(store.pathForTests(assetId: "a"))
  }

  func testSameAssetIdDoesNotDeleteDisplayStoreFile() throws {
    let preview = PreviewTempFileStore.shared
    let display = DisplayTempFileStore.shared
    let previewData = Data("preview".utf8)
    let displayData = Data("display".utf8)
    let previewPath = try preview.replace(assetId: "x", data: previewData)
    let displayPath = try display.replace(assetId: "x", data: displayData)
    XCTAssertNotEqual(previewPath, displayPath)
    XCTAssertTrue(FileManager.default.fileExists(atPath: previewPath))
    XCTAssertTrue(FileManager.default.fileExists(atPath: displayPath))

    preview.release(assetId: "x")
    XCTAssertFalse(FileManager.default.fileExists(atPath: previewPath))
    XCTAssertTrue(FileManager.default.fileExists(atPath: displayPath))
    XCTAssertEqual(display.pathForTests(assetId: "x"), displayPath)
  }
}

final class PreviewImageRequestTableTests: XCTestCase {
  func testTakeRemovesIdSoLaterCancelReturnsNil() {
    let table = PreviewImageRequestTable()
    let start = table.registerStart(assetId: "a") { _ in }
    XCTAssertNil(
      table.bindRequestId(assetId: "a", generation: start.generation, requestId: 42)
    )
    let take = table.takeForDelivery(assetId: "a", generation: start.generation)
    XCTAssertTrue(take.accepted)
    XCTAssertEqual(take.requestIdToCancel, 42)
    let invalidated = table.invalidate(assetId: "a", releaseFile: false)
    XCTAssertNil(invalidated.requestId)
  }

  func testInvalidateMakesOldGenerationNotCurrent() {
    let table = PreviewImageRequestTable()
    let start = table.registerStart(assetId: "a") { _ in }
    XCTAssertTrue(table.isCurrent(assetId: "a", generation: start.generation))
    _ = table.invalidate(assetId: "a", releaseFile: false)
    XCTAssertFalse(table.isCurrent(assetId: "a", generation: start.generation))
  }

  func testSameIdRegisterReturnsPreviousIdAndBumpsGeneration() {
    let table = PreviewImageRequestTable()
    var superseded = false
    let firstCompletion: PreviewCompletion = { _ in superseded = true }
    let start1 = table.registerStart(assetId: "a", completion: firstCompletion)
    XCTAssertNil(
      table.bindRequestId(
        assetId: "a",
        generation: start1.generation,
        requestId: 9
      )
    )
    let start2 = table.registerStart(assetId: "a") { _ in }
    XCTAssertEqual(start2.previousRequestId, 9)
    XCTAssertGreaterThan(start2.generation, start1.generation)
    XCTAssertNotNil(start2.supersededCompletion)
    start2.supersededCompletion?(.failure(NSError(domain: "t", code: 1)))
    XCTAssertTrue(superseded)
    XCTAssertFalse(table.isCurrent(assetId: "a", generation: start1.generation))
    XCTAssertNil(
      table.takeCompletionIfCurrent(assetId: "a", generation: start1.generation)
    )
  }

  /// B7 at the table: the old completion is handed back so Host can complete
  /// the first Future. The table does not wrap ErrorCode; Host requestPreview
  /// maps that invocation to operationCancelled.
  func testSameIdReregisterCompletesOldFutureAndBlocksStaleSuccess() {
    let table = PreviewImageRequestTable()
    var oldResult: Result<DisplayAssetDto, Error>?
    let start1 = table.registerStart(assetId: "a") { oldResult = $0 }
    let start2 = table.registerStart(assetId: "a") { _ in }
    XCTAssertNotNil(start2.supersededCompletion)
    XCTAssertFalse(table.isCurrent(assetId: "a", generation: start1.generation))
    XCTAssertNil(
      table.takeCompletionIfCurrent(assetId: "a", generation: start1.generation)
    )
    start2.supersededCompletion?(
      .failure(NSError(domain: "t", code: 1))
    )
    guard case .failure = oldResult else {
      XCTFail("old Future must complete; got \(String(describing: oldResult))")
      return
    }
  }

  func testWriteIfCurrentAfterReleaseReturnsNilAndDoesNotRestoreFile() throws {
    let table = PreviewImageRequestTable()
    let start = table.registerStart(assetId: "w") { _ in }
    _ = table.invalidate(assetId: "w", releaseFile: true)
    let path = try table.writeIfCurrent(
      assetId: "w",
      generation: start.generation,
      data: Data("late".utf8)
    )
    XCTAssertNil(path)
    XCTAssertNil(PreviewTempFileStore.shared.pathForTests(assetId: "w"))
  }

  func testWriteIfCurrentAfterCancelKeepsFileAndRejectsStaleWrite() throws {
    let table = PreviewImageRequestTable()
    let start = table.registerStart(assetId: "w") { _ in }
    let first = try table.writeIfCurrent(
      assetId: "w",
      generation: start.generation,
      data: Data("keep".utf8)
    )
    XCTAssertNotNil(first)
    _ = table.invalidate(assetId: "w", releaseFile: false)
    let late = try table.writeIfCurrent(
      assetId: "w",
      generation: start.generation,
      data: Data("late".utf8)
    )
    XCTAssertNil(late)
    XCTAssertTrue(FileManager.default.fileExists(atPath: first!))
    PreviewTempFileStore.shared.release(assetId: "w")
  }

  func testMissingSlotTakeIsRejectedNotAsserted() {
    let table = PreviewImageRequestTable()
    let take = table.takeForDelivery(assetId: "missing", generation: 1)
    XCTAssertFalse(take.accepted)
    XCTAssertNil(take.requestIdToCancel)
  }

  func testSyncFirstFrameNilIdIsAccepted() {
    let table = PreviewImageRequestTable()
    let start = table.registerStart(assetId: "a") { _ in }
    let take = table.takeForDelivery(assetId: "a", generation: start.generation)
    XCTAssertTrue(take.accepted)
    XCTAssertNil(take.requestIdToCancel)
    let toCancel = table.bindRequestId(
      assetId: "a",
      generation: start.generation,
      requestId: 11
    )
    XCTAssertEqual(toCancel, 11)
  }

  func testConcurrentRegisterAndInvalidateDoNotCrash() {
    let table = PreviewImageRequestTable()
    let iterations = 200
    DispatchQueue.concurrentPerform(iterations: iterations) { i in
      if i % 2 == 0 {
        _ = table.registerStart(assetId: "a") { _ in }
      } else {
        _ = table.invalidate(assetId: "a", releaseFile: false)
      }
    }
  }
}

final class PhotoKitRequestTableLayer2Tests: XCTestCase {
  func testMarkTransferBeganIsGenerationScoped() {
    let table = PhotoKitRequestTable<PreviewCompletion>()
    let start = table.registerStart(assetId: "a") { _ in }
    table.markTransferBegan(assetId: "a", generation: start.generation)
    XCTAssertTrue(table.didTransferBegin(assetId: "a", generation: start.generation))
    XCTAssertFalse(
      table.didTransferBegin(assetId: "a", generation: start.generation &+ 1)
    )
  }
}

final class PlaybackCurrentItemReplaceTests: XCTestCase {
  func testSwitchingCurrentItemCancelsInFlightPrepareForPreviousAsset() {
    let host = PlaybackApiHost()
    host.debugRegisterInFlightCurrentPrepare(assetId: "A", requestId: 77)
    let toCancel = host.replaceCurrentItem("B")
    XCTAssertEqual(toCancel, 77)
  }

  func testReplaceCurrentItemSameIdDoesNotReturnPreviousRequestId() {
    let host = PlaybackApiHost()
    host.debugRegisterInFlightCurrentPrepare(assetId: "A", requestId: 77)
    XCTAssertNil(host.replaceCurrentItem("A"))
    let toCancel = host.replaceCurrentItem("B")
    XCTAssertEqual(toCancel, 77)
  }

  func testClearPlaybackPoolCompletesPendingLoad() {
    let host = PlaybackApiHost()
    let exp = expectation(description: "load Future must resolve")
    host.debugEnqueueLoadCompletion("v1") { result in
      guard case .failure(let error) = result else {
        XCTFail("expected cancelled, got \(result)")
        return
      }
      let pigeon = error as? PigeonError
      XCTAssertEqual(pigeon?.code, "operationCancelled")
      exp.fulfill()
    }
    XCTAssertNoThrow(try host.clearPlaybackPool())
    waitForExpectations(timeout: 1.0)
  }
}

final class VideoPlaybackPolicyTests: XCTestCase {
  func testForegroundCurrentItemEndLoops() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: false,
      isActiveCurrent: true,
      observedItemIsCurrentItem: true,
      trustedUserIntentWantsPlay: true
    )
    XCTAssertEqual(action, .loopSeekZeroAndPlay)
  }

  func testWarmingItemEndIsIgnored() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: false,
      isActiveCurrent: false,
      observedItemIsCurrentItem: true,
      trustedUserIntentWantsPlay: true
    )
    XCTAssertEqual(action, .ignore)
  }

  func testStaleObserverItemEndIsIgnored() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: false,
      isActiveCurrent: true,
      observedItemIsCurrentItem: false,
      trustedUserIntentWantsPlay: true
    )
    XCTAssertEqual(action, .ignore)
  }

  /// ADR-006 D4: background plan-advance at last item must stop and keep
  /// position — never loop, including a one-item Browse-shaped plan.
  func testAdr006D4BackgroundPlanAdvanceDoesNotLoop() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: true,
      isActiveCurrent: true,
      observedItemIsCurrentItem: true,
      trustedUserIntentWantsPlay: true
    )
    XCTAssertEqual(action, .stopKeepPosition)
  }

  /// U-18.3-P1: trusted new navigation activation seeks zero on mid-play re-enter.
  func testU18_3P1TrustedNavActivationSeeksZeroMidPlay() {
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: true,
        itemAtEnd: false,
        trustedStartsNewNavigationActivation: true
      ),
      .seekZeroAndPlay
    )
  }

  /// U-18.3-P2: foreground technical re-entry preserves playhead.
  func testU18_3P2TrustedNavFalseMidPlayPlayOnly() {
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: true,
        itemAtEnd: false,
        trustedStartsNewNavigationActivation: false
      ),
      .playOnly
    )
  }

  /// U-18.3-P3: item-end does not loop when trusted intent is false.
  func testU18_3P3ItemEndIntentFalseStops() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: false,
      isActiveCurrent: true,
      observedItemIsCurrentItem: true,
      trustedUserIntentWantsPlay: false
    )
    XCTAssertEqual(action, .stopKeepPosition)
  }

  /// U-18.3-P4: item-end loops when trusted intent is true (ADR-026 regression).
  func testU18_3P4ItemEndIntentTrueLoops() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: false,
      isActiveCurrent: true,
      observedItemIsCurrentItem: true,
      trustedUserIntentWantsPlay: true
    )
    XCTAssertEqual(action, .loopSeekZeroAndPlay)
  }

  func testReenterAtEndSeeksZeroAndPlays() {
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: true,
        itemAtEnd: true,
        trustedStartsNewNavigationActivation: false
      ),
      .seekZeroAndPlay
    )
  }

  func testReenterMidItemPlaysOnlyPreservingPlayhead() {
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: true,
        itemAtEnd: false,
        trustedStartsNewNavigationActivation: false
      ),
      .playOnly
    )
  }

  func testReenterWithoutPlayerPreparesNew() {
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: false,
        itemAtEnd: true,
        trustedStartsNewNavigationActivation: true
      ),
      .prepareNew
    )
  }
}

final class PlaybackIntentStateReducerTests: XCTestCase {
  private func dto(
    asset: String,
    wantsPlay: Bool,
    nav: Bool,
    clear: Bool
  ) -> PlaybackIntentDto {
    PlaybackIntentDto(
      assetIdentifier: asset,
      wantsPlay: wantsPlay,
      startsNewNavigationActivation: nav,
      clearsPendingNavigationActivation: clear
    )
  }

  /// S-18.3-R1: lifecycle clear drops pending; become-current is playOnly.
  func testS18_3R1LifecycleClearDropsPending() {
    var state = PlaybackIntentHostState(
      mirror: nil,
      pendingNavigationActivation: PendingNavigationActivation(
        assetIdentifier: "A",
        clearEpochAtArm: 7
      )
    )
    state = PlaybackIntentStateReducer.applyIntent(
      state: state,
      incoming: dto(asset: "A", wantsPlay: false, nav: false, clear: true),
      currentAssetIdentifier: "A",
      clearEpoch: 7
    )
    XCTAssertEqual(state.mirror?.wantsPlay, false)
    XCTAssertNil(state.pendingNavigationActivation)
    let trustedNav =
      PlaybackIntentStateReducer.validatedPendingNavigationActivation(
        state: state,
        currentAssetIdentifier: "A",
        clearEpoch: 7
      )
    XCTAssertNil(trustedNav)
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: true,
        itemAtEnd: false,
        trustedStartsNewNavigationActivation: false
      ),
      .playOnly
    )
  }

  /// S-18.3-R2: non-lifecycle wantsPlay=false must not clear pending nav.
  func testS18_3R2NonLifecyclePausePreservesPending() {
    var state = PlaybackIntentHostState(
      mirror: nil,
      pendingNavigationActivation: PendingNavigationActivation(
        assetIdentifier: "A",
        clearEpochAtArm: 7
      )
    )
    state = PlaybackIntentStateReducer.applyIntent(
      state: state,
      incoming: dto(asset: "A", wantsPlay: false, nav: false, clear: false),
      currentAssetIdentifier: "A",
      clearEpoch: 7
    )
    XCTAssertNotNil(state.pendingNavigationActivation)
    let trustedNav =
      PlaybackIntentStateReducer.validatedPendingNavigationActivation(
        state: state,
        currentAssetIdentifier: "A",
        clearEpoch: 7
      )
    XCTAssertNotNil(trustedNav)
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: true,
        itemAtEnd: false,
        trustedStartsNewNavigationActivation: true
      ),
      .seekZeroAndPlay
    )
  }

  /// S-18.3-R3: lifecycle clear for A must not clear pending on B.
  func testS18_3R3LifecycleClearDoesNotCrossAsset() {
    var state = PlaybackIntentHostState(
      mirror: nil,
      pendingNavigationActivation: PendingNavigationActivation(
        assetIdentifier: "B",
        clearEpochAtArm: 7
      )
    )
    state = PlaybackIntentStateReducer.applyIntent(
      state: state,
      incoming: dto(asset: "A", wantsPlay: false, nav: false, clear: true),
      currentAssetIdentifier: "A",
      clearEpoch: 7
    )
    XCTAssertEqual(state.pendingNavigationActivation?.assetIdentifier, "B")
  }

  /// S-18.3-R4: stale pending epoch is not cleared by lifecycle update.
  func testS18_3R4StalePendingEpochNotClearedByLifecycle() {
    var state = PlaybackIntentHostState(
      mirror: nil,
      pendingNavigationActivation: PendingNavigationActivation(
        assetIdentifier: "A",
        clearEpochAtArm: 6
      )
    )
    state = PlaybackIntentStateReducer.applyIntent(
      state: state,
      incoming: dto(asset: "A", wantsPlay: false, nav: false, clear: true),
      currentAssetIdentifier: "A",
      clearEpoch: 7
    )
    XCTAssertNotNil(state.pendingNavigationActivation)
    XCTAssertEqual(state.pendingNavigationActivation?.clearEpochAtArm, 6)
    let trustedNav =
      PlaybackIntentStateReducer.validatedPendingNavigationActivation(
        state: state,
        currentAssetIdentifier: "A",
        clearEpoch: 7
      )
    XCTAssertNil(trustedNav)
  }
}

final class PlaybackRuntimeObserveMapperTests: XCTestCase {
  func testM18_2_1_noPlayer_isIdle() {
    let dto = PlaybackRuntimeObserveMapper.makeEvent(from: .empty)
    XCTAssertEqual(dto.playbackState, .idle)
    XCTAssertEqual(dto.playbackPositionSeconds, 0)
  }

  func testM18_2_2_playing_mapsPosition() {
    let snapshot = PlaybackRuntimeSnapshot(
      planId: "p",
      currentAssetIdentifier: "v1",
      currentIndex: 2,
      playbackPositionSeconds: 12.3,
      activeAssetId: "v1",
      hasActivePlayer: true,
      timeControlStatus: .playing,
      rate: 1
    )
    let dto = PlaybackRuntimeObserveMapper.makeEvent(from: snapshot)
    XCTAssertEqual(dto.playbackState, .playing)
    XCTAssertEqual(dto.playbackPositionSeconds, 12.3, accuracy: 0.001)
    XCTAssertEqual(dto.currentItemIdentifier, "v1")
    XCTAssertEqual(dto.currentIndex, 2)
  }

  func testM18_2_3_paused_afterPause() {
    let snapshot = PlaybackRuntimeSnapshot(
      planId: "p",
      currentAssetIdentifier: "v1",
      currentIndex: 0,
      playbackPositionSeconds: 4.5,
      activeAssetId: "v1",
      hasActivePlayer: true,
      timeControlStatus: .paused,
      rate: 0
    )
    let dto = PlaybackRuntimeObserveMapper.makeEvent(from: snapshot)
    XCTAssertEqual(dto.playbackState, .paused)
    XCTAssertEqual(dto.playbackPositionSeconds, 4.5, accuracy: 0.001)
  }

  func testM18_2_4_waitingToPlayAtSpecifiedRate() {
    let snapshot = PlaybackRuntimeSnapshot(
      planId: "p",
      currentAssetIdentifier: "v1",
      currentIndex: 0,
      playbackPositionSeconds: 1,
      activeAssetId: "v1",
      hasActivePlayer: true,
      timeControlStatus: .waitingToPlayAtSpecifiedRate,
      rate: 1
    )
    let dto = PlaybackRuntimeObserveMapper.makeEvent(from: snapshot)
    XCTAssertEqual(dto.playbackState, .waitingForMedia)
  }

  func testM18_2_5_activeAssetMismatch_isIdle() {
    let snapshot = PlaybackRuntimeSnapshot(
      planId: "p",
      currentAssetIdentifier: "v2",
      currentIndex: 1,
      playbackPositionSeconds: 9,
      activeAssetId: "v1",
      hasActivePlayer: true,
      timeControlStatus: .playing,
      rate: 1
    )
    let dto = PlaybackRuntimeObserveMapper.makeEvent(from: snapshot)
    XCTAssertEqual(dto.playbackState, .idle)
    XCTAssertEqual(dto.playbackPositionSeconds, 0)
  }

  func testM18_2_6_itemAtEnd_isCompleted() {
    let snapshot = PlaybackRuntimeSnapshot(
      planId: "p",
      currentAssetIdentifier: "v1",
      currentIndex: 0,
      playbackPositionSeconds: 60,
      activeAssetId: "v1",
      hasActivePlayer: true,
      timeControlStatus: .paused,
      rate: 0,
      activeItemDidPlayToEnd: true
    )
    let dto = PlaybackRuntimeObserveMapper.makeEvent(from: snapshot)
    XCTAssertEqual(dto.playbackState, .completed)
  }

  func testM18_2_preparingCurrent_isLoading() {
    let snapshot = PlaybackRuntimeSnapshot(
      planId: "p",
      currentAssetIdentifier: "v1",
      currentIndex: 0,
      isPreparingCurrent: true
    )
    let dto = PlaybackRuntimeObserveMapper.makeEvent(from: snapshot)
    XCTAssertEqual(dto.playbackState, .loading)
  }
}

final class PlaybackRuntimeObserveHostTests: XCTestCase {
  private func waitForMainQueue(timeout: TimeInterval = 1.0) {
    let exp = expectation(description: "main queue")
    DispatchQueue.main.async { exp.fulfill() }
    waitForExpectations(timeout: timeout)
  }

  func testH18_2_1_play_emitsRuntimeEvent() {
    let host = PlaybackApiHost()
    host.debugSetRuntimeObserveContextForTests(
      planId: "p",
      currentAssetIdentifier: "v1",
      feedIndex: 0,
      activeAssetId: "v1",
      activePlayer: AVPlayer()
    )
    _ = host.debugDrainRuntimeEventsForTests()

    XCTAssertNoThrow(try host.play())
    waitForMainQueue()

    let events = host.debugDrainRuntimeEventsForTests()
    XCTAssertFalse(events.isEmpty)
    XCTAssertEqual(events.last?.planId, "p")
    XCTAssertEqual(events.last?.currentItemIdentifier, "v1")
  }

  func testH18_2_2_pause_emitsPaused() {
    let host = PlaybackApiHost()
    host.debugSetRuntimeObserveContextForTests(
      planId: "p",
      currentAssetIdentifier: "v1",
      feedIndex: 0,
      activeAssetId: "v1",
      activePlayer: AVPlayer()
    )
    _ = host.debugDrainRuntimeEventsForTests()

    XCTAssertNoThrow(try host.pause())
    waitForMainQueue()

    let events = host.debugDrainRuntimeEventsForTests()
    XCTAssertEqual(events.last?.playbackState, .paused)
  }

  func testH18_2_3_clearPlaybackPool_emitsIdle() {
    let host = PlaybackApiHost()
    host.debugSetRuntimeObserveContextForTests(
      planId: "p",
      currentAssetIdentifier: "v1",
      feedIndex: 0,
      activeAssetId: "v1",
      activePlayer: AVPlayer()
    )
    _ = host.debugDrainRuntimeEventsForTests()

    XCTAssertNoThrow(try host.clearPlaybackPool())
    waitForMainQueue()

    let events = host.debugDrainRuntimeEventsForTests()
    XCTAssertEqual(events.last?.playbackState, .idle)
  }

  func testH18_2_4_seek_emitsImmediateEvent() {
    let host = PlaybackApiHost()
    host.debugSetRuntimeObserveContextForTests(
      planId: "p",
      currentAssetIdentifier: "v1",
      feedIndex: 0,
      activeAssetId: "v1",
      activePlayer: AVPlayer()
    )
    _ = host.debugDrainRuntimeEventsForTests()

    let exp = expectation(description: "seek completes")
    host.seek(positionSeconds: 30) { result in
      if case .failure = result {
        XCTFail("seek failed")
      }
      exp.fulfill()
    }
    wait(for: [exp], timeout: 2)
    waitForMainQueue()

    let events = host.debugDrainRuntimeEventsForTests()
    XCTAssertFalse(events.isEmpty)
    XCTAssertEqual(events.last?.currentItemIdentifier, "v1")
  }
}

final class PlaybackScrubPreviewTests: XCTestCase {
  func testH18_5_1_isTimeSeekable_falseWhenEmptyRanges() {
    let item = AVPlayerItem(url: URL(fileURLWithPath: "/tmp/missing.mp4"))
    let time = CMTime(seconds: 1, preferredTimescale: 600)
    XCTAssertFalse(PlaybackScrubPreview.isTimeSeekable(item: item, time: time))
  }

  func testH18_5_3_generateResult_localFixture_returnsJPEG() throws {
    let url = try Self.makeTempVideoURL()
    addTeardownBlock {
      try? FileManager.default.removeItem(at: url)
    }
    let asset = AVURLAsset(url: url)
    let (result, _) = PlaybackScrubPreview.generateResult(
      asset: asset,
      time: CMTime(seconds: 0.1, preferredTimescale: 600)
    )
    switch result {
    case .success(let data):
      XCTAssertGreaterThan(data.count, 100)
      XCTAssertEqual(data.prefix(2), Data([0xFF, 0xD8]))
    case .failure(let reason):
      XCTFail("expected JPEG, got \(reason)")
    }
  }

  func testH18_5_E1_endCap_usesExactTolerance() {
    let mid = PlaybackScrubPreview.toleranceForRequest(
      positionSeconds: 4.0,
      durationSeconds: 15.8
    )
    XCTAssertEqual(mid.label, "zero")

    let endFrac = PlaybackScrubPreview.toleranceForRequest(
      positionSeconds: 15.75,
      durationSeconds: 15.8
    )
    XCTAssertEqual(endFrac.label, "zero")
    XCTAssertTrue(
      PlaybackScrubPreview.isEndCapRequest(
        positionSeconds: 15.75,
        durationSeconds: 15.8
      )
    )

    let endInt = PlaybackScrubPreview.toleranceForRequest(
      positionSeconds: 15.95,
      durationSeconds: 16.0
    )
    XCTAssertEqual(endInt.label, "zero")
    XCTAssertTrue(
      PlaybackScrubPreview.isEndCapRequest(
        positionSeconds: 15.95,
        durationSeconds: 16.0
      )
    )

    // Past asset duration must NOT force zero (Dart/Host duration skew).
    XCTAssertFalse(
      PlaybackScrubPreview.isEndCapRequest(
        positionSeconds: 50.0,
        durationSeconds: 40.0
      )
    )
    XCTAssertEqual(
      PlaybackScrubPreview.toleranceForRequest(
        positionSeconds: 50.0,
        durationSeconds: 40.0
      ).label,
      "infinite"
    )
  }

  func testH18_5_E2_midPath_usesExactTolerance() {
    let tol = PlaybackScrubPreview.toleranceForRequest(
      positionSeconds: 15.0,
      durationSeconds: 16.0
    )
    XCTAssertEqual(tol.label, "zero")
    XCTAssertFalse(
      PlaybackScrubPreview.isEndCapRequest(
        positionSeconds: 15.0,
        durationSeconds: 16.0
      )
    )
  }

  private static func makeTempVideoURL() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("wt185-preview-\(UUID().uuidString).mp4")
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: 320,
      AVVideoHeightKey: 240,
    ]
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: 320,
        kCVPixelBufferHeightKey as String: 240,
      ]
    )
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(
      kCFAllocatorDefault,
      320,
      240,
      kCVPixelFormatType_32ARGB,
      nil,
      &pixelBuffer
    )
    guard let pixelBuffer else {
      throw NSError(domain: "WT185", code: 1)
    }
    while !input.isReadyForMoreMediaData {
      Thread.sleep(forTimeInterval: 0.01)
    }
    adaptor.append(pixelBuffer, withPresentationTime: .zero)
    input.markAsFinished()
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting {
      sem.signal()
    }
    sem.wait()
    guard writer.status == .completed else {
      throw writer.error ?? NSError(domain: "WT185", code: 2)
    }
    return url
  }
}

final class PlaybackScrubPreviewHostTests: XCTestCase {
  private func waitForMainQueue(timeout: TimeInterval = 1.0) {
    let exp = expectation(description: "main queue")
    DispatchQueue.main.async { exp.fulfill() }
    waitForExpectations(timeout: timeout)
  }

  func testH18_5_2_noActivePlayer_returnsNil() {
    let host = PlaybackApiHost()
    let exp = expectation(description: "preview")
    host.requestScrubPreviewFrame(positionSeconds: 1) { result in
      if case .success(let data) = result {
        XCTAssertNil(data)
      } else {
        XCTFail("expected success nil")
      }
      exp.fulfill()
    }
    wait(for: [exp], timeout: 1.0)
  }
}


// MARK: - ADR-063 Live motion end

final class LiveMotionEndPolicyTests: XCTestCase {
  func testUneditedLivePhotoStyleIsEligible() {
    XCTAssertTrue(
      LiveMotionEndPolicy.isEligible(
        playbackStyle: .livePhoto,
        resourceTypes: [.photo, .pairedVideo]
      )
    )
  }

  func testLoopBounceAndLongExposureStylesAreNotEligible() {
    for style: PHAsset.PlaybackStyle in [.videoLooping, .image, .imageAnimated, .video] {
      XCTAssertFalse(
        LiveMotionEndPolicy.isEligible(playbackStyle: style, resourceTypes: [.photo, .pairedVideo]),
        "style \(style.rawValue)"
      )
    }
  }

  func testEditedLivePhotoIsNotEligible() {
    let markers: [PHAssetResourceType] = [
      .fullSizePairedVideo, .adjustmentData, .adjustmentBasePairedVideo,
    ]
    for marker in markers {
      XCTAssertFalse(
        LiveMotionEndPolicy.isEligible(
          playbackStyle: .livePhoto,
          resourceTypes: [.photo, .pairedVideo, marker]
        ),
        "marker \(marker.rawValue)"
      )
    }
  }

  func testMissingPairedVideoIsNotEligible() {
    XCTAssertFalse(LiveMotionEndPolicy.isEligible(playbackStyle: .livePhoto, resourceTypes: [.photo]))
  }

  func testDeadlineIsAnchoredOnWillBegin() {
    let deadline = LiveMotionEndPolicy.deadline(willBeginAt: 100, duration: 1.757, slack: 0.8)
    XCTAssertEqual(deadline, 102.557, accuracy: 1e-9)
    XCTAssertEqual(LiveMotionEndPolicy.delay(until: deadline, now: 100), 2.557, accuracy: 1e-9)
  }

  func testLateDurationArmsWithRemainingTime() {
    let deadline = LiveMotionEndPolicy.deadline(willBeginAt: 100, duration: 1.757, slack: 0.8)
    XCTAssertEqual(LiveMotionEndPolicy.delay(until: deadline, now: 101.5), 1.057, accuracy: 1e-9)
  }

  func testDurationAfterDeadlineFiresImmediately() {
    let deadline = LiveMotionEndPolicy.deadline(willBeginAt: 100, duration: 1.757, slack: 0.8)
    XCTAssertEqual(LiveMotionEndPolicy.delay(until: deadline, now: 110), 0)
  }

  private let surfaceA = NSObject()
  private let surfaceB = NSObject()

  private func play(willBeginAt: CFTimeInterval?) -> LiveMotionPlayTracker.Play {
    LiveMotionPlayTracker.Play(serial: 1, surface: ObjectIdentifier(surfaceA), willBeginAt: willBeginAt)
  }

  func testFallbackNotArmedWhenDurationArrivesAfterPlayClosed() {
    var tracker = LiveMotionPlayTracker()
    tracker.start(surface: ObjectIdentifier(surfaceA))
    XCTAssertTrue(tracker.willBegin(surface: ObjectIdentifier(surfaceA), at: 100))
    tracker.invalidate()
    XCTAssertNil(
      LiveMotionEndPolicy.fallbackDelay(
        play: tracker.currentPlay,
        surface: ObjectIdentifier(surfaceA),
        duration: 1.757,
        now: 101,
        slack: 0.8
      )
    )
  }

  func testFallbackNotArmedBeforeWillBegin() {
    XCTAssertNil(
      LiveMotionEndPolicy.fallbackDelay(
        play: play(willBeginAt: nil),
        surface: ObjectIdentifier(surfaceA),
        duration: 1.757,
        now: 101,
        slack: 0.8
      )
    )
  }

  func testFallbackNotArmedForOtherSurface() {
    XCTAssertNil(
      LiveMotionEndPolicy.fallbackDelay(
        play: play(willBeginAt: 100),
        surface: ObjectIdentifier(surfaceB),
        duration: 1.757,
        now: 101,
        slack: 0.8
      )
    )
  }

  func testFallbackNotArmedWhenDurationUnknown() {
    XCTAssertNil(
      LiveMotionEndPolicy.fallbackDelay(
        play: play(willBeginAt: 100),
        surface: ObjectIdentifier(surfaceA),
        duration: nil,
        now: 101,
        slack: 0.8
      )
    )
  }

  func testFallbackLateDurationArmsWithRemainingTime() {
    let delay = LiveMotionEndPolicy.fallbackDelay(
      play: play(willBeginAt: 100),
      surface: ObjectIdentifier(surfaceA),
      duration: 1.757,
      now: 101.5,
      slack: 0.8
    )
    XCTAssertEqual(try XCTUnwrap(delay), 1.057, accuracy: 1e-9)
  }

  func testFallbackPastDeadlineFiresImmediately() {
    let delay = LiveMotionEndPolicy.fallbackDelay(
      play: play(willBeginAt: 100),
      surface: ObjectIdentifier(surfaceA),
      duration: 1.757,
      now: 110,
      slack: 0.8
    )
    XCTAssertEqual(delay, 0)
  }
}

final class LiveMotionPlayTrackerTests: XCTestCase {
  private let surfaceA = NSObject()
  private let surfaceB = NSObject()
  private var a: ObjectIdentifier { ObjectIdentifier(surfaceA) }
  private var b: ObjectIdentifier { ObjectIdentifier(surfaceB) }

  func testFirstSystemEndIsForwardedOnce() {
    var tracker = LiveMotionPlayTracker()
    tracker.start(surface: a)
    XCTAssertTrue(tracker.willBegin(surface: a, at: 1))
    XCTAssertNotNil(tracker.endCurrentPlay(surface: a))
    XCTAssertNil(tracker.endCurrentPlay(surface: a))
  }

  func testFallbackEndBlocksLaterSystemEnd() {
    var tracker = LiveMotionPlayTracker()
    let serial = tracker.start(surface: a)
    XCTAssertTrue(tracker.endPlay(serial: serial, surface: a))
    XCTAssertNil(tracker.endCurrentPlay(surface: a))
  }

  func testSystemEndBlocksLaterFallback() {
    var tracker = LiveMotionPlayTracker()
    let serial = tracker.start(surface: a)
    XCTAssertNotNil(tracker.endCurrentPlay(surface: a))
    XCTAssertFalse(tracker.endPlay(serial: serial, surface: a))
  }

  func testInvalidateDropsLaterEnds() {
    var tracker = LiveMotionPlayTracker()
    let serial = tracker.start(surface: a)
    tracker.invalidate()
    XCTAssertNil(tracker.endCurrentPlay(surface: a))
    XCTAssertFalse(tracker.endPlay(serial: serial, surface: a))
    XCTAssertFalse(tracker.willBegin(surface: a, at: 1))
  }

  func testNewStartOnSameSurfaceSupersedesOldFallback() {
    var tracker = LiveMotionPlayTracker()
    let first = tracker.start(surface: a)
    let second = tracker.start(surface: a)
    XCTAssertNotEqual(first, second)
    XCTAssertFalse(tracker.endPlay(serial: first, surface: a))
    XCTAssertTrue(tracker.endPlay(serial: second, surface: a))
  }

  /// Path R: a late end from the previous surface must not end the replay.
  func testLateEndFromOldSurfaceDoesNotEndReplayOnNewSurface() {
    var tracker = LiveMotionPlayTracker()
    tracker.start(surface: a)
    tracker.invalidate()
    let replay = tracker.start(surface: b)
    XCTAssertNil(tracker.endCurrentPlay(surface: a))
    XCTAssertFalse(tracker.willBegin(surface: a, at: 5))
    XCTAssertEqual(tracker.currentPlay?.serial, replay)
    XCTAssertNotNil(tracker.endCurrentPlay(surface: b))
  }

  func testWillBeginRecordsAnchorOnCurrentPlay() {
    var tracker = LiveMotionPlayTracker()
    tracker.start(surface: a)
    XCTAssertNil(tracker.currentPlay?.willBeginAt)
    XCTAssertTrue(tracker.willBegin(surface: a, at: 42))
    XCTAssertEqual(tracker.currentPlay?.willBeginAt, 42)
  }
}

final class LiveMotionDurationCacheTests: XCTestCase {
  func testCacheIsBounded() {
    var cache = LiveMotionDurationCache()
    for i in 0..<(LiveMotionDurationCache.limit * 2 + 3) {
      cache.store(1, for: "id\(i)")
      XCTAssertLessThanOrEqual(cache.count, LiveMotionDurationCache.limit)
    }
  }

  func testRemoveDropsStaleValue() {
    var cache = LiveMotionDurationCache()
    cache.store(1.5, for: "a")
    cache.remove("a")
    XCTAssertNil(cache.duration(for: "a"))
  }
}

final class MovieDurationScannerTests: XCTestCase {
  private func be32(_ v: UInt32) -> [UInt8] {
    [UInt8(v >> 24 & 0xFF), UInt8(v >> 16 & 0xFF), UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]
  }

  private func be64(_ v: UInt64) -> [UInt8] {
    be32(UInt32(v >> 32)) + be32(UInt32(v & 0xFFFF_FFFF))
  }

  private func atom(_ type: String, _ body: [UInt8]) -> [UInt8] {
    be32(UInt32(8 + body.count)) + Array(type.utf8) + body
  }

  private func largeAtom(_ type: String, _ body: [UInt8]) -> [UInt8] {
    be32(1) + Array(type.utf8) + be64(UInt64(16 + body.count)) + body
  }

  private func mvhdV0(timescale: UInt32, duration: UInt32) -> [UInt8] {
    atom("mvhd", [0, 0, 0, 0] + be32(0) + be32(0) + be32(timescale) + be32(duration) + [UInt8](repeating: 0, count: 80))
  }

  private func mvhdV1(timescale: UInt32, duration: UInt64) -> [UInt8] {
    atom("mvhd", [1, 0, 0, 0] + be64(0) + be64(0) + be32(timescale) + be64(duration) + [UInt8](repeating: 0, count: 80))
  }

  private func scan(_ bytes: [UInt8], chunk: Int = .max) -> MovieDurationScanner {
    var scanner = MovieDurationScanner()
    var i = 0
    while i < bytes.count {
      let end = min(bytes.count, i + max(1, min(chunk, bytes.count)))
      scanner.feed(Data(bytes[i..<end]))
      i = end
    }
    scanner.finish()
    return scanner
  }

  func testMoovBeforeMdatV0() {
    let file = atom("ftyp", Array("qt  ".utf8) + be32(0)) + atom("moov", mvhdV0(timescale: 600, duration: 1054))
      + atom("mdat", [UInt8](repeating: 7, count: 1000))
    let s = scan(file)
    XCTAssertEqual(s.outcome, .found(1054.0 / 600.0, moovAfterMdat: false))
    XCTAssertLessThan(s.bytesConsumed, Int64(file.count))
  }

  func testMoovAfterMdatV1() {
    let file = atom("ftyp", Array("qt  ".utf8) + be32(0)) + atom("wide", [])
      + atom("mdat", [UInt8](repeating: 7, count: 5000))
      + atom("moov", mvhdV1(timescale: 44100, duration: 77_490))
    let s = scan(file)
    XCTAssertEqual(s.outcome, .found(77_490.0 / 44100.0, moovAfterMdat: true))
  }

  func testLargesizeMdatIsSkipped() {
    let file = atom("ftyp", []) + largeAtom("mdat", [UInt8](repeating: 1, count: 3000))
      + atom("moov", atom("trak", []) + mvhdV0(timescale: 1000, duration: 1757))
    let s = scan(file)
    XCTAssertEqual(s.outcome, .found(1.757, moovAfterMdat: true))
  }

  func testEveryChunkBoundaryGivesSameResult() {
    let file = atom("ftyp", []) + largeAtom("mdat", [UInt8](repeating: 1, count: 300))
      + atom("moov", mvhdV1(timescale: 600, duration: 1010))
    for chunk in [1, 2, 3, 7, 8, 15, 16, 17, 64, 333] {
      XCTAssertEqual(scan(file, chunk: chunk).outcome, .found(1010.0 / 600.0, moovAfterMdat: true), "chunk \(chunk)")
    }
  }

  func testTruncatedMoovIsUnknown() {
    let file = atom("ftyp", []) + atom("moov", mvhdV0(timescale: 600, duration: 1054))
    let s = scan(Array(file.dropLast(20)))
    XCTAssertEqual(s.outcome, .unknown)
  }

  func testMissingMoovIsUnknown() {
    let s = scan(atom("ftyp", []) + atom("mdat", [1, 2, 3]))
    XCTAssertEqual(s.outcome, .unknown)
  }

  func testTruncatedMvhdBodyIsUnknown() {
    let shortMvhd = atom("mvhd", [0, 0, 0, 0] + be32(0) + be32(0) + be32(600))
    XCTAssertEqual(scan(atom("moov", shortMvhd)).outcome, .unknown)
  }

  func testMalformedAtomSizesAreUnknown() {
    XCTAssertEqual(scan(be32(4) + Array("mdat".utf8) + [0, 0, 0, 0]).outcome, .unknown)
    XCTAssertEqual(scan(be32(1) + Array("mdat".utf8) + be64(3)).outcome, .unknown)
    XCTAssertEqual(scan(be32(1) + Array("mdat".utf8) + be64(UInt64.max)).outcome, .unknown)
    let badChild = be32(200) + Array("mvhd".utf8) + [0, 0, 0, 0]
    XCTAssertEqual(scan(atom("moov", badChild)).outcome, .unknown)
    XCTAssertEqual(scan([UInt8](repeating: 0xFF, count: 64)).outcome, .unknown)
  }

  func testOversizedMoovIsUnknown() {
    let header = be32(UInt32(MovieDurationScanner.maxMoovBytes + 9)) + Array("moov".utf8)
    XCTAssertEqual(scan(header + [0, 0, 0]).outcome, .unknown)
  }

  func testZeroTimescaleOrDurationIsUnknown() {
    XCTAssertEqual(scan(atom("moov", mvhdV0(timescale: 0, duration: 1054))).outcome, .unknown)
    XCTAssertEqual(scan(atom("moov", mvhdV0(timescale: 600, duration: 0))).outcome, .unknown)
    XCTAssertEqual(scan(atom("moov", mvhdV0(timescale: 600, duration: .max))).outcome, .unknown)
    XCTAssertEqual(scan(atom("moov", mvhdV1(timescale: 0, duration: 1054))).outcome, .unknown)
  }

  func testFeedAfterResultIsIgnored() {
    var scanner = MovieDurationScanner()
    scanner.feed(Data(atom("moov", mvhdV0(timescale: 600, duration: 600))))
    let consumed = scanner.bytesConsumed
    scanner.feed(Data([UInt8](repeating: 0, count: 100)))
    scanner.finish()
    XCTAssertEqual(scanner.outcome, .found(1, moovAfterMdat: false))
    XCTAssertEqual(scanner.bytesConsumed, consumed)
  }

  func testAppleWrittenMovMatchesAVFoundationDuration() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("wt312-mvhd-\(UUID().uuidString).mov")
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64,
      ]
    )
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: 64,
        kCVPixelBufferHeightKey as String: 64,
      ]
    )
    writer.add(input)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
    let buffer = try XCTUnwrap(pixelBuffer)
    for frame in 0..<10 {
      while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.01) }
      adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
    }
    input.markAsFinished()
    writer.endSession(atSourceTime: CMTime(value: 10, timescale: 30))
    let sem = DispatchSemaphore(value: 0)
    writer.finishWriting { sem.signal() }
    sem.wait()
    XCTAssertEqual(writer.status, .completed)

    let data = try Data(contentsOf: url)
    let s = scan([UInt8](data), chunk: 4096)
    guard case .found(let duration, _) = s.outcome else {
      return XCTFail("expected duration, got \(s.outcome)")
    }
    XCTAssertEqual(duration, AVURLAsset(url: url).duration.seconds, accuracy: 0.001)
  }
}

final class ShareStillFileTests: XCTestCase {
  private var root: URL!

  override func setUp() {
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("share-tests-\(UUID().uuidString)", isDirectory: true)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: root)
  }

  private func jpegFixture(withGPS: Bool) throws -> Data {
    let width = 64
    let height = 48
    let context = try XCTUnwrap(
      CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
      )
    )
    context.setFillColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = try XCTUnwrap(context.makeImage())
    var properties: [CFString: Any] = [
      kCGImagePropertyOrientation: 6,
      kCGImagePropertyExifDictionary: [
        kCGImagePropertyExifDateTimeOriginal: "2026:09:28 10:00:00"
      ],
      kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFModel: "iPhone 17"],
    ]
    if withGPS {
      properties[kCGImagePropertyGPSDictionary] = [
        kCGImagePropertyGPSLatitude: 36.85,
        kCGImagePropertyGPSLatitudeRef: "S",
        kCGImagePropertyGPSLongitude: 174.76,
        kCGImagePropertyGPSLongitudeRef: "E",
      ]
    }
    let output = NSMutableData()
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
    )
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return output as Data
  }

  private func properties(of data: Data) throws -> [CFString: Any] {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    return try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
  }

  func testFileExtensionFromTypeIdentifier() {
    XCTAssertEqual(ShareStillFile.fileExtension(forTypeIdentifier: "public.heic"), "heic")
    XCTAssertEqual(ShareStillFile.fileExtension(forTypeIdentifier: "public.jpeg"), "jpeg")
    XCTAssertEqual(ShareStillFile.fileExtension(forTypeIdentifier: "public.png"), "png")
    XCTAssertNil(ShareStillFile.fileExtension(forTypeIdentifier: "com.example.not-a-type"))
  }

  func testFileStemFromOriginalFilename() {
    XCTAssertEqual(ShareStillFile.fileStem(originalFilename: "IMG_1935.HEIC"), "IMG_1935")
    XCTAssertEqual(ShareStillFile.fileStem(originalFilename: "a/b.jpg"), "a_b")
    XCTAssertEqual(ShareStillFile.fileStem(originalFilename: nil), "Photo")
    XCTAssertEqual(ShareStillFile.fileStem(originalFilename: ""), "Photo")
  }

  func testDefaultRootIsShareDirectoryUnderTmp() {
    let defaultRoot = ShareStillFile.rootDirectory()
    XCTAssertEqual(defaultRoot.lastPathComponent, "share")
    XCTAssertEqual(
      defaultRoot.deletingLastPathComponent().standardizedFileURL.path,
      FileManager.default.temporaryDirectory.standardizedFileURL.path
    )
  }

  func testWritePlacesFileInOwnDirectoryUnderRoot() throws {
    let url = try XCTUnwrap(
      ShareStillFile.write(try jpegFixture(withGPS: true), fileStem: "IMG_0001", root: root)
    )
    XCTAssertEqual(url.lastPathComponent, "IMG_0001.jpeg")
    let directory = url.deletingLastPathComponent()
    XCTAssertEqual(
      directory.deletingLastPathComponent().standardizedFileURL.path,
      root.standardizedFileURL.path
    )
    XCTAssertNotNil(UUID(uuidString: directory.lastPathComponent))
    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

    try FileManager.default.removeItem(at: directory)
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }

  func testRemoveLeftoversDeletesRoot() throws {
    _ = try XCTUnwrap(
      ShareStillFile.write(try jpegFixture(withGPS: false), fileStem: "IMG_0002", root: root)
    )
    ShareStillFile.removeLeftovers(root: root)
    XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
  }

  func testWriteFailsForNonImageDataAndLeavesNothing() {
    XCTAssertNil(ShareStillFile.write(Data([0x00, 0x01, 0x02]), fileStem: "x", root: root))
    XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
  }

  func testJpegLocationRemovedLosslesslyKeepingOrientationDateAndModel() throws {
    let input = try jpegFixture(withGPS: true)
    XCTAssertNotNil(try properties(of: input)[kCGImagePropertyGPSDictionary])

    let prepared = try XCTUnwrap(ShareStillFile.removingLocation(from: input))
    XCTAssertEqual(prepared.locationRemoval, .lossless)
    XCTAssertEqual(prepared.typeIdentifier, UTType.jpeg.identifier)

    let output = try properties(of: prepared.data)
    XCTAssertNil(output[kCGImagePropertyGPSDictionary])
    XCTAssertEqual(output[kCGImagePropertyOrientation] as? Int, 6)
    XCTAssertEqual(
      (output[kCGImagePropertyExifDictionary] as? [CFString: Any])?[
        kCGImagePropertyExifDateTimeOriginal] as? String,
      "2026:09:28 10:00:00"
    )
    XCTAssertEqual(
      (output[kCGImagePropertyTIFFDictionary] as? [CFString: Any])?[kCGImagePropertyTIFFModel]
        as? String,
      "iPhone 17"
    )
    XCTAssertEqual(output[kCGImagePropertyPixelWidth] as? Int, 64)
    XCTAssertEqual(output[kCGImagePropertyPixelHeight] as? Int, 48)
  }

  func testDataWithoutLocationIsHandedOverUnchanged() throws {
    let input = try jpegFixture(withGPS: false)
    let prepared = try XCTUnwrap(ShareStillFile.removingLocation(from: input))
    XCTAssertEqual(prepared.locationRemoval, .notNeeded)
    XCTAssertEqual(prepared.data, input)
  }
}
