import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/magnification_arbitration.dart';

/// Cap 20 session-scoped magnification runtime state (ADR-043).
@immutable
class BrowseMagnificationState {
  const BrowseMagnificationState({
    this.isStillMagnified = false,
    this.videoPinchActive = false,
    this.stillPinchContact = false,
  });

  /// Persistent still (incl. Live static key frame) scale > fit.
  final bool isStillMagnified;

  /// Transient video pinch in progress (release → fit clears this).
  final bool videoPinchActive;

  /// Still: two-finger contact in progress (locks PageView). Single-finger
  /// never sets this — Plan A / Cap 20.3 (no pinch-candidate round-trip).
  final bool stillPinchContact;

  bool get locksVerticalPageView => verticalPageViewScrollLocked(
    isCurrentStillMagnified: isStillMagnified,
    videoPinchActive: videoPinchActive,
    stillPinchContact: stillPinchContact,
  );

  bool get hasActiveMagnification =>
      isStillMagnified || videoPinchActive || stillPinchContact;

  BrowseMagnificationState copyWith({
    bool? isStillMagnified,
    bool? videoPinchActive,
    bool? stillPinchContact,
  }) {
    return BrowseMagnificationState(
      isStillMagnified: isStillMagnified ?? this.isStillMagnified,
      videoPinchActive: videoPinchActive ?? this.videoPinchActive,
      stillPinchContact: stillPinchContact ?? this.stillPinchContact,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BrowseMagnificationState &&
        other.isStillMagnified == isStillMagnified &&
        other.videoPinchActive == videoPinchActive &&
        other.stillPinchContact == stillPinchContact;
  }

  @override
  int get hashCode =>
      Object.hash(isStillMagnified, videoPinchActive, stillPinchContact);
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

  void setStillMagnified(bool magnified) {
    if (state.isStillMagnified == magnified) {
      return;
    }
    state = state.copyWith(isStillMagnified: magnified);
  }

  void setVideoPinchActive(bool active) {
    if (state.videoPinchActive == active) {
      return;
    }
    state = state.copyWith(videoPinchActive: active);
  }

  /// Two-finger contact — locks PageView without requiring scale > 1 yet.
  void setStillPinchContact(bool active) {
    if (state.stillPinchContact == active) {
      return;
    }
    state = state.copyWith(stillPinchContact: active);
  }

  void forceFit() {
    if (!state.hasActiveMagnification) {
      return;
    }
    state = const BrowseMagnificationState();
  }

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
