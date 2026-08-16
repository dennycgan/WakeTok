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
}

final class VideoPlaybackPolicyTests: XCTestCase {
  func testForegroundCurrentItemEndLoops() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: false,
      isActiveCurrent: true,
      observedItemIsCurrentItem: true
    )
    XCTAssertEqual(action, .loopSeekZeroAndPlay)
  }

  func testWarmingItemEndIsIgnored() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: false,
      isActiveCurrent: false,
      observedItemIsCurrentItem: true
    )
    XCTAssertEqual(action, .ignore)
  }

  func testStaleObserverItemEndIsIgnored() {
    let action = VideoPlaybackPolicy.actionOnItemEnd(
      isForegroundPageDriven: true,
      isBackgroundPlanAdvance: false,
      isActiveCurrent: true,
      observedItemIsCurrentItem: false
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
      observedItemIsCurrentItem: true
    )
    XCTAssertEqual(action, .stopKeepPosition)
  }

  func testReenterAtEndSeeksZeroAndPlays() {
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: true,
        itemAtEnd: true
      ),
      .seekZeroAndPlay
    )
  }

  func testReenterMidItemPlaysOnlyPreservingPlayhead() {
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: true,
        itemAtEnd: false
      ),
      .playOnly
    )
  }

  func testReenterWithoutPlayerPreparesNew() {
    XCTAssertEqual(
      VideoPlaybackPolicy.actionOnBecomeCurrent(
        playerExists: false,
        itemAtEnd: true
      ),
      .prepareNew
    )
  }
}

