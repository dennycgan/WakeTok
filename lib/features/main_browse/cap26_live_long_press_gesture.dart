import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waketok/features/main_browse/cap26_live_long_press_arbitration.dart';

/// Cap 26.2 / ADR-052 — media-area long-press for Live replay.
///
/// Uses [Listener] (not [GestureDetector]) so vertical [PageView] and Cap 19
/// left-swipe keep receiving the same pointer stream (same discipline as
/// [Cap19LeftSwipeGesture]).
class Cap26LiveLongPressGesture extends StatefulWidget {
  const Cap26LiveLongPressGesture({
    super.key,
    required this.enabled,
    required this.onLongPressFire,
  });

  /// When false, shrinks to nothing (do not leave a dead Listener mounted).
  final bool enabled;

  final VoidCallback onLongPressFire;

  @override
  State<Cap26LiveLongPressGesture> createState() =>
      _Cap26LiveLongPressGestureState();
}

class _Cap26LiveLongPressGestureState extends State<Cap26LiveLongPressGesture> {
  Offset _pointerStart = Offset.zero;
  Offset _lastDelta = Offset.zero;
  bool _tracking = false;
  bool _fired = false;
  Timer? _holdTimer;

  @override
  void didUpdateWidget(Cap26LiveLongPressGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && _tracking) {
      _reset();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _reset() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _tracking = false;
    _fired = false;
    _lastDelta = Offset.zero;
  }

  void _onDown(PointerDownEvent event) {
    if (!widget.enabled) {
      return;
    }
    _reset();
    _tracking = true;
    _pointerStart = event.position;
    _lastDelta = Offset.zero;
    _holdTimer = Timer(kLiveLongPressHoldDuration, _onHoldElapsed);
  }

  void _onHoldElapsed() {
    if (!mounted || !_tracking || _fired || !widget.enabled) {
      return;
    }
    // Timer is the hold-duration authority (FakeAsync-safe; do not re-check
    // DateTime.now() — wall clock does not advance with tester.pump).
    if (_lastDelta.distance > kLiveLongPressMaxSlopPx) {
      _reset();
      return;
    }
    _fired = true;
    _tracking = false;
    _holdTimer = null;
    HapticFeedback.lightImpact();
    widget.onLongPressFire();
  }

  void _onMove(PointerMoveEvent event) {
    if (!_tracking || _fired) {
      return;
    }
    _lastDelta = event.position - _pointerStart;
    if (_lastDelta.distance > kLiveLongPressMaxSlopPx) {
      _reset();
    }
  }

  void _onUpOrCancel(PointerEvent event) {
    if (_fired) {
      _reset();
      return;
    }
    _reset();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: Listener(
        key: const Key('cap26LiveLongPressGesture'),
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUpOrCancel,
        onPointerCancel: _onUpOrCancel,
        child: const SizedBox.expand(),
      ),
    );
  }
}
