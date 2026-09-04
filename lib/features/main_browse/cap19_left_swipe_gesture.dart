import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_append_controller.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_arbitration.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_drag.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Full-width left-swipe append overlay (Cap 19.6 / ADR-041 D2=B).
///
/// Uses [Listener] (not [GestureDetector]) so vertical [PageView] drags are
/// not blocked in the gesture arena.
class Cap19LeftSwipeGesture extends ConsumerStatefulWidget {
  const Cap19LeftSwipeGesture({
    super.key,
    required this.isCurrent,
    required this.excludeScrubberBand,
  });

  final bool isCurrent;
  final bool excludeScrubberBand;

  @override
  ConsumerState<Cap19LeftSwipeGesture> createState() =>
      _Cap19LeftSwipeGestureState();
}

class _Cap19LeftSwipeGestureState extends ConsumerState<Cap19LeftSwipeGesture>
    with SingleTickerProviderStateMixin {
  Offset _pointerStart = Offset.zero;
  Offset _dragDelta = Offset.zero;
  bool _tracking = false;
  bool _horizontalDragActive = false;
  bool _releaseAnimating = false;
  bool _thresholdHapticFired = false;
  late final AnimationController _releaseController;
  Animation<double>? _releaseAnimation;

  @override
  void initState() {
    super.initState();
    _releaseController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _releaseController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(Cap19LeftSwipeGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCurrent && !widget.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(cap19LeftSwipeDragProvider.notifier).reset();
        _horizontalDragActive = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent) {
      return const SizedBox.shrink();
    }
    final armed = ref.watch(cap19LeftSwipeArmingProvider);
    ref.listen<bool>(cap19LeftSwipeArmingProvider, (previous, next) {
      if (previous == true && next == false && _tracking) {
        // Magnification pinch armed PageView lock — drop in-flight swipe
        // tracking so two-finger pinch is not classified as left-swipe.
        _resetPointerTracking();
        ref.read(cap19LeftSwipeDragProvider.notifier).reset();
      }
    });
    if (!armed) {
      return const SizedBox.shrink();
    }

    final bottomInset =
        widget.excludeScrubberBand ? kMainBrowseScrubberReserveHeight : 0.0;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: bottomInset,
      child: Listener(
        key: const Key('cap19LeftSwipeGesture'),
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (_releaseAnimating) {
            return;
          }
          _tracking = true;
          _horizontalDragActive = false;
          _thresholdHapticFired = false;
          _pointerStart = event.position;
          _dragDelta = Offset.zero;
        },
        onPointerMove: (event) {
          if (!_tracking || _releaseAnimating) {
            return;
          }
          _dragDelta = event.position - _pointerStart;
          if (!_horizontalDragActive) {
            if (!cap19LeftSwipeDragShouldCommit(_dragDelta)) {
              return;
            }
            _horizontalDragActive = true;
          }
          final width = MediaQuery.sizeOf(context).width;
          final offset = cap19LeftSwipeClampedOffset(
            dx: _dragDelta.dx,
            viewportWidth: width,
          );
          ref.read(cap19LeftSwipeDragProvider.notifier).updateOffset(offset);
          if (!_thresholdHapticFired &&
              cap19LeftSwipeDragIsArmed(offset)) {
            _thresholdHapticFired = true;
            HapticFeedback.lightImpact();
          }
        },
        onPointerUp: (_) => _finishPointer(context),
        onPointerCancel: (_) => _cancelPointer(context),
        child: const SizedBox.expand(),
      ),
    );
  }

  void _resetPointerTracking() {
    _tracking = false;
    _horizontalDragActive = false;
    _dragDelta = Offset.zero;
  }

  Future<void> _cancelPointer(BuildContext context) async {
    if (!_tracking || _releaseAnimating) {
      return;
    }
    _resetPointerTracking();
    await _animateOffsetTo(0, kCap19LeftSwipeCancelDuration);
  }

  Future<void> _animateOffsetTo(double target, Duration duration) async {
    final notifier = ref.read(cap19LeftSwipeDragProvider.notifier);
    final begin = ref.read(cap19LeftSwipeDragProvider).offsetX;
    if (begin == target) {
      notifier.reset();
      return;
    }
    setState(() => _releaseAnimating = true);
    _releaseController.duration = duration;
    _releaseAnimation = Tween<double>(begin: begin, end: target).animate(
      CurvedAnimation(parent: _releaseController, curve: Curves.easeOutCubic),
    );
    void listener() {
      notifier.updateOffset(_releaseAnimation!.value);
    }

    _releaseAnimation!.addListener(listener);
    await _releaseController.forward(from: 0);
    _releaseAnimation!.removeListener(listener);
    _releaseController.reset();
    if (target == 0) {
      notifier.reset();
    }
    if (mounted) {
      setState(() => _releaseAnimating = false);
    }
  }

  Future<void> _finishPointer(BuildContext context) async {
    if (!_tracking || _releaseAnimating) {
      return;
    }
    final delta = _dragDelta;
    _resetPointerTracking();

    if (!shouldTriggerLeftSwipeAppend(totalDelta: delta)) {
      await _animateOffsetTo(0, kCap19LeftSwipeCancelDuration);
      return;
    }

    Cap19LeftSwipeGuideSession.markGuideShown();
    ref.read(cap19LeftSwipeDragProvider.notifier).reset();

    final l10n = AppLocalizations.of(context)!;
    final outcome = await ref
        .read(cap19LeftSwipeAppendProvider.notifier)
        .appendCurrentAssetToWakeTokAlbum();
    if (!context.mounted) {
      return;
    }
    switch (outcome) {
      case Cap19LeftSwipeAppendOutcome.success:
        showCap19LeftSwipeAppendSuccessToast(context, l10n);
      case Cap19LeftSwipeAppendOutcome.alreadyInAlbum:
        showCap19LeftSwipeAlreadyInAlbumToast(context, l10n);
      case Cap19LeftSwipeAppendOutcome.mediaNotReady:
        showCap19CurrentMediaNotReadyToast(context, l10n);
      case Cap19LeftSwipeAppendOutcome.failed:
        showCap19LeftSwipeAppendErrorToast(context, l10n);
    }
  }
}
