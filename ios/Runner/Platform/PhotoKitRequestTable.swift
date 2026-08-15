import Foundation
import Photos

typealias PreviewCompletion = (Result<DisplayAssetDto, Error>) -> Void
typealias PlayableCompletion = (Result<PlayableVideoDto, Error>) -> Void
typealias PreviewImageRequestTable = PhotoKitRequestTable<PreviewCompletion>
typealias PreviewRegisterStart = PhotoKitRegisterStart<PreviewCompletion>
typealias PreviewInvalidateResult = PhotoKitInvalidateResult<PreviewCompletion>
typealias PreviewDeliveryTake = PhotoKitDeliveryTake

struct PhotoKitRegisterStart<Completion> {
  let generation: UInt64
  let previousRequestId: PHImageRequestID?
  let supersededCompletion: Completion?
}

struct PhotoKitInvalidateResult<Completion> {
  let requestId: PHImageRequestID?
  let completion: Completion?
}

struct PhotoKitDeliveryTake {
  let accepted: Bool
  let requestIdToCancel: PHImageRequestID?
}

/// Per-asset PhotoKit request ids + generation (Cap 14.2/14.3).
///
/// Store writes are optional via [commitIfCurrent]. Playback prepare uses
/// this table with no store. Three Host sites hold **separate instances**.
///
/// PhotoKit may invoke the result handler before `requestImage` /
/// `requestAVAsset` returns an id. Call [registerStart] first, then
/// [bindRequestId]. A current slot with a nil id is a legal first
/// delivery; a missing slot is stale.
final class PhotoKitRequestTable<Completion> {
  private struct Slot {
    var generation: UInt64
    var requestId: PHImageRequestID?
    var delivered: Bool
    var transferBegan: Bool
    var completion: Completion?
  }

  private let lock = NSLock()
  private var slots: [String: Slot] = [:]

  func registerStart(
    assetId: String,
    completion: Completion?
  ) -> PhotoKitRegisterStart<Completion> {
    lock.lock()
    defer { lock.unlock() }
    let previous = slots[assetId]
    let nextGen = (previous?.generation ?? 0) &+ 1
    slots[assetId] = Slot(
      generation: nextGen,
      requestId: nil,
      delivered: false,
      transferBegan: false,
      completion: completion
    )
    return PhotoKitRegisterStart(
      generation: nextGen,
      previousRequestId: previous?.requestId,
      supersededCompletion: previous?.completion
    )
  }

  /// Bind the PhotoKit id. Returns an id the caller must cancel when the
  /// first delivery already ran (sync handler) or the generation is stale.
  func bindRequestId(
    assetId: String,
    generation: UInt64,
    requestId: PHImageRequestID
  ) -> PHImageRequestID? {
    lock.lock()
    defer { lock.unlock() }
    guard var slot = slots[assetId], slot.generation == generation else {
      return requestId
    }
    if slot.delivered {
      return requestId
    }
    slot.requestId = requestId
    slots[assetId] = slot
    return nil
  }

  func takeForDelivery(
    assetId: String,
    generation: UInt64
  ) -> PhotoKitDeliveryTake {
    lock.lock()
    defer { lock.unlock() }
    guard var slot = slots[assetId], slot.generation == generation else {
      return PhotoKitDeliveryTake(accepted: false, requestIdToCancel: nil)
    }
    if slot.delivered {
      return PhotoKitDeliveryTake(accepted: false, requestIdToCancel: nil)
    }
    slot.delivered = true
    let id = slot.requestId
    slot.requestId = nil
    slots[assetId] = slot
    return PhotoKitDeliveryTake(accepted: true, requestIdToCancel: id)
  }

  func shouldDropCallback(assetId: String, generation: UInt64) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard let slot = slots[assetId], slot.generation == generation else {
      return true
    }
    return slot.delivered
  }

  func isCurrent(assetId: String, generation: UInt64) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return slots[assetId]?.generation == generation
  }

  func markTransferBegan(assetId: String, generation: UInt64) {
    lock.lock()
    defer { lock.unlock() }
    guard var slot = slots[assetId], slot.generation == generation else {
      return
    }
    slot.transferBegan = true
    slots[assetId] = slot
  }

  func didTransferBegin(assetId: String, generation: UInt64) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    guard let slot = slots[assetId], slot.generation == generation else {
      return false
    }
    return slot.transferBegan
  }

  func takeCompletionIfCurrent(
    assetId: String,
    generation: UInt64
  ) -> Completion? {
    lock.lock()
    defer { lock.unlock() }
    guard var slot = slots[assetId], slot.generation == generation else {
      return nil
    }
    let completion = slot.completion
    slot.completion = nil
    slots[assetId] = slot
    return completion
  }

  /// Runs [body] only if [generation] is still current (holds the table lock).
  func commitIfCurrent<T>(
    assetId: String,
    generation: UInt64,
    _ body: () throws -> T
  ) rethrows -> T? {
    lock.lock()
    defer { lock.unlock() }
    guard slots[assetId]?.generation == generation else {
      return nil
    }
    return try body()
  }

  func invalidate(assetId: String) -> PhotoKitInvalidateResult<Completion> {
    lock.lock()
    defer { lock.unlock() }
    let previous = slots.removeValue(forKey: assetId)
    return PhotoKitInvalidateResult(
      requestId: previous?.requestId,
      completion: previous?.completion
    )
  }
}

extension PhotoKitRequestTable where Completion == PreviewCompletion {
  /// Preview JPEG write; atomic vs invalidate (Cap 14.2 tests).
  func writeIfCurrent(
    assetId: String,
    generation: UInt64,
    data: Data
  ) throws -> String? {
    try commitIfCurrent(assetId: assetId, generation: generation) {
      try PreviewTempFileStore.shared.replace(assetId: assetId, data: data)
    }
  }

  func invalidate(
    assetId: String,
    releaseFile: Bool
  ) -> PhotoKitInvalidateResult<Completion> {
    let result = invalidate(assetId: assetId)
    if releaseFile {
      PreviewTempFileStore.shared.release(assetId: assetId)
    }
    return result
  }
}
