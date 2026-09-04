import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/magnification_arbitration.dart';

/// Cap 20 session-scoped magnification runtime state (ADR-043).
///
/// Scale/offset and pinch recognizers land in 20.3+; 20.2 owns the bool
/// signal that Cap 19 left-swipe and PageView physics already consume.
@immutable
class BrowseMagnificationState {
  const BrowseMagnificationState({
    this.isStillMagnified = false,
    this.videoPinchActive = false,
  });

  /// Persistent still (incl. Live static key frame) scale > fit.
  final bool isStillMagnified;

  /// Transient video pinch in progress (release → fit clears this).
  final bool videoPinchActive;

  bool get locksVerticalPageView => verticalPageViewScrollLocked(
    isCurrentStillMagnified: isStillMagnified,
    videoPinchActive: videoPinchActive,
  );

  bool get hasActiveMagnification => isStillMagnified || videoPinchActive;

  BrowseMagnificationState copyWith({
    bool? isStillMagnified,
    bool? videoPinchActive,
  }) {
    return BrowseMagnificationState(
      isStillMagnified: isStillMagnified ?? this.isStillMagnified,
      videoPinchActive: videoPinchActive ?? this.videoPinchActive,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BrowseMagnificationState &&
        other.isStillMagnified == isStillMagnified &&
        other.videoPinchActive == videoPinchActive;
  }

  @override
  int get hashCode => Object.hash(isStillMagnified, videoPinchActive);
}

final browseMagnificationProvider =
    NotifierProvider<BrowseMagnificationNotifier, BrowseMagnificationState>(
      BrowseMagnificationNotifier.new,
    );

/// Read-only still-magnified signal for Cap 19 Decision 20 arming.
final browseStillMagnifiedProvider = Provider<bool>((ref) {
  return ref.watch(browseMagnificationProvider).isStillMagnified;
});

class BrowseMagnificationNotifier extends Notifier<BrowseMagnificationState> {
  bool _liveMotionMounted = false;
  bool _panelOpen = false;

  @override
  BrowseMagnificationState build() {
    ref.listen<bool>(cap19ActionsPanelOpenProvider, (previous, next) {
      onActionsPanelOpenChanged(next);
    });
    return const BrowseMagnificationState();
  }

  /// Test / future pinch path: mark persistent still magnification.
  void setStillMagnified(bool magnified) {
    if (state.isStillMagnified == magnified) {
      return;
    }
    state = state.copyWith(isStillMagnified: magnified);
  }

  /// Video mid-pinch (20.4); unlocks PageView when false after release→fit.
  void setVideoPinchActive(bool active) {
    if (state.videoPinchActive == active) {
      return;
    }
    state = state.copyWith(videoPinchActive: active);
  }

  void forceFit() {
    if (!state.hasActiveMagnification) {
      return;
    }
    state = const BrowseMagnificationState();
  }

  /// Leave current feed item or leave Browse (ADR-043 D4).
  void clearBecauseLeftCurrentOrBrowse() {
    _liveMotionMounted = false;
    if (!shouldClearMagnificationOnLeaveCurrent(
      wasCurrentOrBrowseActive: true,
      isCurrentOrBrowseActive: false,
      hasActiveMagnification: state.hasActiveMagnification,
    )) {
      return;
    }
    forceFit();
  }

  /// Live `_liveMotionMounted` transitions — any rising edge force-fits.
  void onLiveMotionMountedChanged(bool mounted) {
    final previous = _liveMotionMounted;
    _liveMotionMounted = mounted;
    if (shouldForceFitOnLiveMotionRisingEdge(
      previouslyMounted: previous,
      currentlyMounted: mounted,
      isStillMagnified: state.isStillMagnified,
    )) {
      forceFit();
    }
  }

  void onActionsPanelOpenChanged(bool open) {
    final previous = _panelOpen;
    _panelOpen = open;
    if (shouldForceFitOnActionsPanelOpen(
      previouslyOpen: previous,
      currentlyOpen: open,
      isStillMagnified: state.isStillMagnified,
    )) {
      forceFit();
    }
  }
}
