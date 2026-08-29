import AVFoundation
import Photos
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

    XCTAssertNoThrow(try host.seek(positionSeconds: 30))
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
    let result = PlaybackScrubPreview.generateResult(
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

