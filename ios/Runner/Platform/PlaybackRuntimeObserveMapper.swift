import AVFoundation
import Foundation

/// Cap 18.2: pure snapshot → Pigeon DTO (unit-tested without AVPlayer).
struct PlaybackRuntimeSnapshot: Equatable {
  var planId: String = ""
  var currentAssetIdentifier: String?
  var currentIndex: Int64 = 0
  var playbackPositionSeconds: Double = 0
  var activeAssetId: String?
  var hasActivePlayer: Bool = false
  var isPreparingCurrent: Bool = false
  var timeControlStatus: AVPlayer.TimeControlStatus?
  var rate: Float = 0
  var activeItemDidPlayToEnd: Bool = false
  var durationSeconds: Double? = nil

  static let empty = PlaybackRuntimeSnapshot()
}

enum PlaybackRuntimeObserveMapper {
  static func makeEvent(from snapshot: PlaybackRuntimeSnapshot) -> PlaybackRuntimeEventDto {
    let planId = snapshot.planId
    let itemId = snapshot.currentAssetIdentifier ?? ""
    let index = snapshot.currentIndex

    if snapshot.isPreparingCurrent, snapshot.currentAssetIdentifier != nil {
      return dto(
        snapshot,
        position: max(0, snapshot.playbackPositionSeconds),
        state: .loading
      )
    }

    guard snapshot.hasActivePlayer,
      let currentId = snapshot.currentAssetIdentifier,
      snapshot.activeAssetId == currentId
    else {
      return PlaybackRuntimeEventDto(
        planId: planId,
        currentItemIdentifier: itemId,
        currentIndex: index,
        playbackPositionSeconds: 0,
        playbackState: .idle,
        durationSeconds: nil,
        errorCode: nil
      )
    }

    let position = max(0, snapshot.playbackPositionSeconds)

    if snapshot.activeItemDidPlayToEnd {
      return dto(
        snapshot,
        position: position,
        state: .completed
      )
    }

    if snapshot.timeControlStatus == .waitingToPlayAtSpecifiedRate {
      return dto(
        snapshot,
        position: position,
        state: .waitingForMedia
      )
    }

    if snapshot.rate > 0, snapshot.timeControlStatus == .playing {
      return dto(
        snapshot,
        position: position,
        state: .playing
      )
    }

    return dto(
      snapshot,
      position: position,
      state: .paused
    )
  }

  private static func dto(
    _ snapshot: PlaybackRuntimeSnapshot,
    position: Double,
    state: PlaybackState
  ) -> PlaybackRuntimeEventDto {
    PlaybackRuntimeEventDto(
      planId: snapshot.planId,
      currentItemIdentifier: snapshot.currentAssetIdentifier ?? "",
      currentIndex: snapshot.currentIndex,
      playbackPositionSeconds: position,
      playbackState: state,
      durationSeconds: snapshot.durationSeconds,
      errorCode: nil
    )
  }
}
