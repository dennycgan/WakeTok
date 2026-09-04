import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/magnification_geometry.dart';

export 'package:waketok/features/main_browse/magnification_geometry.dart'
    show kCap20MaxScale, kCap20MinScale;

/// Epsilon above fit before treating the surface as magnified.
const double kCap20MagnifiedEpsilon = 0.02;

/// Video release → fit animation (Cap 20.4 Q1-A).
const Duration kCap20VideoReleaseToFitDuration = Duration(milliseconds: 180);

/// Fitted content size at scale=1 for the current page (null = unknown →
/// treat as full viewport; no letterbox-aware clamp).
final magnificationContentSizeProvider =
    NotifierProvider<MagnificationContentSizeNotifier, Size?>(
      MagnificationContentSizeNotifier.new,
    );

class MagnificationContentSizeNotifier extends Notifier<Size?> {
  @override
  Size? build() => null;

  void setContentSize(Size? size) {
    if (state == size) {
      return;
    }
    if (size != null &&
        state != null &&
        (state!.width - size.width).abs() < 0.5 &&
        (state!.height - size.height).abs() < 0.5) {
      return;
    }
    state = size;
  }

  void clear() {
    if (state == null) {
      return;
    }
    state = null;
  }
}

/// Which media path currently owns the PageView-outer pinch host.
///
/// [still] = persistent pinch + Reset (photo / Live-static L2).
/// [transient] = non-persistent release→fit (all L1 + video L2).
enum MagnificationHostMode { none, still, transient }

/// When true, Host pushes the session matrix to native AVPlayer via
/// [PlaybackRepository.setDisplayMagnification]. Independent of
/// [MagnificationHostMode.transient] — photo L1 is also transient but must
/// not drive the player.
final nativeDisplayMagnificationPushProvider =
    NotifierProvider<NativeDisplayMagnificationPushNotifier, bool>(
      NativeDisplayMagnificationPushNotifier.new,
    );

class NativeDisplayMagnificationPushNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    if (state == enabled) {
      return;
    }
    state = enabled;
  }
}

/// Session matrix for the current page transform (still persistent or
/// transient release→fit).
@immutable
class MagnificationMatrix {
  const MagnificationMatrix({
    this.scale = kCap20MinScale,
    this.translation = Offset.zero,
  });

  final double scale;
  final Offset translation;

  bool get isMagnified => scale > kCap20MinScale + kCap20MagnifiedEpsilon;

  Matrix4 get matrix {
    return Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  static const MagnificationMatrix identity = MagnificationMatrix();
}

final magnificationMatrixProvider =
    NotifierProvider<MagnificationMatrixNotifier, MagnificationMatrix>(
      MagnificationMatrixNotifier.new,
    );

class MagnificationMatrixNotifier extends Notifier<MagnificationMatrix> {
  @override
  MagnificationMatrix build() => MagnificationMatrix.identity;

  void setMatrix({required double scale, required Offset translation}) {
    final next = MagnificationMatrix(scale: scale, translation: translation);
    if (state.scale == next.scale && state.translation == next.translation) {
      return;
    }
    state = next;
  }

  void reset() {
    if (state == MagnificationMatrix.identity) {
      return;
    }
    state = MagnificationMatrix.identity;
  }
}

/// Current host mode — written by still / video binders on the current page.
final magnificationHostModeProvider =
    NotifierProvider<MagnificationHostModeNotifier, MagnificationHostMode>(
      MagnificationHostModeNotifier.new,
    );

class MagnificationHostModeNotifier extends Notifier<MagnificationHostMode> {
  @override
  MagnificationHostMode build() => MagnificationHostMode.none;

  void setMode(MagnificationHostMode mode) {
    if (state == mode) {
      return;
    }
    state = mode;
  }

  /// Neighbor pages must not clear another mode; only clear when [expected]
  /// still owns the host.
  void clearIf(MagnificationHostMode expected) {
    if (state != expected) {
      return;
    }
    state = MagnificationHostMode.none;
  }
}

/// Wraps [PageView] so multi-touch reaches pinch tracking (still + video).
///
/// **Why outside the page (not inside the per-page Stack):**
/// After the first finger's [PointerDownEvent] on a vertical [PageView], a
/// subsequent finger's hit-test path no longer includes [RenderViewport] /
/// page children — reproduced with an empty per-page [Listener] that wrote
/// **no** `setState` / provider updates (Cap 20.3 isolation). So this is
/// **not** "our pinch onPointerDown rebuild poisoned the tree"; it is a
/// Scrollable-side hit-test path change once a pointer is down (Scrollable's
/// [IgnorePointer] under `_ScrollableScope` participates; exact activity
/// timing may be Hold vs Drag). A translucent [Listener] **parent** of
/// [PageView] still receives the 2nd down because hit-test reaches the
/// scrollable chrome even when it no longer descends into the viewport.
///
/// Cap 20.4 reuses this single host for video (non-persistent release→fit);
/// do **not** stack another parent [Listener].
///
/// Plan A: lock PageView only while ≥2 fingers (still contact / video pinch)
/// or while still persistently magnified / video release animation runs.
class MagnificationPointerHost extends ConsumerStatefulWidget {
  const MagnificationPointerHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MagnificationPointerHost> createState() =>
      _MagnificationPointerHostState();
}

class _MagnificationPointerHostState extends ConsumerState<MagnificationPointerHost>
    with SingleTickerProviderStateMixin {
  final Map<int, Offset> _pointers = <int, Offset>{};

  double _scale = kCap20MinScale;
  Offset _translation = Offset.zero;

  double? _pinchStartSpan;
  double _pinchStartScale = kCap20MinScale;
  Offset? _pinchStartFocal;
  Offset _pinchStartTranslation = Offset.zero;

  Size _viewportSize = Size.zero;

  Size get _contentAtFit {
    final reported = ref.read(magnificationContentSizeProvider);
    if (reported != null &&
        reported.width > 0 &&
        reported.height > 0) {
      return reported;
    }
    if (_viewportSize.width > 0 && _viewportSize.height > 0) {
      return _viewportSize;
    }
    return const Size(1, 1);
  }

  Offset _focalFromLayoutCenter(Offset local) {
    return Offset(
      local.dx - _viewportSize.width / 2,
      local.dy - _viewportSize.height / 2,
    );
  }

  void _applyClampedTranslation(Offset raw) {
    _translation = clampMagnificationTranslation(
      translation: raw,
      scale: _scale,
      viewport: _viewportSize.width > 0
          ? _viewportSize
          : _contentAtFit,
      contentAtFit: _contentAtFit,
    );
  }

  Offset? _panLastLocal;

  late final AnimationController _releaseController;
  double _releaseFromScale = kCap20MinScale;
  Offset _releaseFromTranslation = Offset.zero;

  MagnificationHostMode get _mode => ref.read(magnificationHostModeProvider);

  bool get _enabled => _mode != MagnificationHostMode.none;

  bool get _isMagnified => _scale > kCap20MinScale + kCap20MagnifiedEpsilon;

  bool get _isTransient => _mode == MagnificationHostMode.transient;

  bool get _isStill => _mode == MagnificationHostMode.still;

  @override
  void initState() {
    super.initState();
    _releaseController = AnimationController(
      vsync: this,
      duration: kCap20VideoReleaseToFitDuration,
    )..addListener(_onReleaseTick);
  }

  @override
  void dispose() {
    _releaseController
      ..removeListener(_onReleaseTick)
      ..dispose();
    super.dispose();
  }

  void _onReleaseTick() {
    final t = Curves.easeOut.transform(_releaseController.value);
    _scale = _releaseFromScale + (kCap20MinScale - _releaseFromScale) * t;
    _translation =
        Offset.lerp(_releaseFromTranslation, Offset.zero, t) ?? Offset.zero;
    _applyClampedTranslation(_translation);
    _publishMatrix();
  }

  void _finishTransientReleaseToFit() {
    if (_releaseController.isAnimating) {
      _releaseController.stop();
    }
    _releaseController.value = 0;
    _resetToFitTransform();
    ref.read(browseMagnificationProvider.notifier).setTransientPinchActive(false);
  }

  void _startTransientReleaseToFit() {
    if (!_isMagnified) {
      _finishTransientReleaseToFit();
      return;
    }
    _releaseFromScale = _scale;
    _releaseFromTranslation = _translation;
    // Keep lock during animation.
    ref.read(browseMagnificationProvider.notifier).setTransientPinchActive(true);
    _releaseController.forward(from: 0).whenComplete(() {
      if (!mounted) {
        return;
      }
      // Completed or interrupted — only finish when we reached the end.
      if (_releaseController.status == AnimationStatus.completed) {
        _finishTransientReleaseToFit();
      }
    });
  }

  void _publishMatrix() {
    ref.read(magnificationMatrixProvider.notifier).setMatrix(
      scale: _scale,
      translation: _translation,
    );
    _pushNativeVideoMagnification();
  }

  /// Cap 20.4 Q3: UiKitView ignores Flutter [Transform]; push to AVPlayer
  /// only while [nativeDisplayMagnificationPushProvider] is armed (video L2
  /// visual owner). Transient photo/Live L1 must not drive the player.
  void _pushNativeVideoMagnification() {
    if (!ref.read(nativeDisplayMagnificationPushProvider)) {
      return;
    }
    unawaited(
      ref.read(playbackRepositoryProvider).setDisplayMagnification(
        scale: _scale,
        translationX: _translation.dx,
        translationY: _translation.dy,
      ),
    );
  }

  void _publishStillMagnified(bool magnified) {
    if (!_isStill) {
      return;
    }
    ref.read(browseMagnificationProvider.notifier).setStillMagnified(magnified);
  }

  void _publishStillContact(bool active) {
    if (!_isStill && !active) {
      ref.read(browseMagnificationProvider.notifier).setStillPinchContact(false);
      return;
    }
    if (!_isStill) {
      return;
    }
    ref.read(browseMagnificationProvider.notifier).setStillPinchContact(active);
  }

  void _publishTransientPinchActive(bool active) {
    if (!_isTransient && !active) {
      ref.read(browseMagnificationProvider.notifier).setTransientPinchActive(false);
      return;
    }
    if (!_isTransient) {
      return;
    }
    ref.read(browseMagnificationProvider.notifier).setTransientPinchActive(active);
  }

  void _syncContactFlags() {
    if (_isStill) {
      _publishStillContact(_pointers.length >= 2);
    } else if (_isTransient) {
      // Lock while two fingers are down, while transiently magnified, or
      // while release→fit animation is running.
      final active =
          _pointers.length >= 2 ||
          _isMagnified ||
          _releaseController.isAnimating;
      _publishTransientPinchActive(active);
    }
  }

  void _resetToFitTransform() {
    _scale = kCap20MinScale;
    _translation = Offset.zero;
    _pinchStartSpan = null;
    _panLastLocal = null;
    _publishMatrix();
  }

  /// Immediate local identity — interrupts any in-flight release animation (Q1).
  ///
  /// Does **not** write [browseMagnificationProvider] — callers that already
  /// cleared flags (forceFit / leave-current) must only reset locals. Writing
  /// multiple `setX` flags here caused Riverpod debug crashes:
  /// "Tried to rebuild Provider multiple times in the same frame".
  ///
  /// [clearPointers]: true for mode→none / leave (gesture must die). False when
  /// responding to forceFit while fingers may still be down (L1→L2 handoff),
  /// otherwise the browse listen would wipe the map before re-baseline.
  void _resetLocalTransformState({bool clearPointers = true}) {
    if (_releaseController.isAnimating || _releaseController.value > 0) {
      _releaseController.stop();
      _releaseController.value = 0;
    }
    if (clearPointers) {
      _pointers.clear();
    }
    _pinchStartSpan = null;
    _panLastLocal = null;
    _resetToFitTransform();
  }

  /// Same-page host mode switch (transient L1 → persistent L2): fit matrix
  /// without dropping live pointers; re-baseline pinch from current span.
  void _handoffModeKeepPointers() {
    if (_releaseController.isAnimating || _releaseController.value > 0) {
      _releaseController.stop();
      _releaseController.value = 0;
    }
    _pinchStartSpan = null;
    _panLastLocal = null;
    _scale = kCap20MinScale;
    _translation = Offset.zero;
    _publishMatrix();
    // Clear session flags. Prefer not calling [forceFit] alone before
    // re-baseline: the browse listen must not clearPointers (see above).
    ref.read(browseMagnificationProvider.notifier).forceFit();
    if (_pointers.length >= 2) {
      _beginPinch();
    } else {
      _syncContactFlags();
    }
  }

  /// Mode dropped to [none]: clear browse flags once, then locals.
  void _interruptBecauseHostModeCleared() {
    _resetLocalTransformState();
    ref.read(browseMagnificationProvider.notifier).forceFit();
  }

  void _beginPinch() {
    if (_pointers.length < 2) {
      return;
    }
    if (_releaseController.isAnimating) {
      _releaseController.stop();
      _releaseController.value = 0;
    }
    final points = _pointers.values.toList(growable: false);
    _pinchStartSpan = (points[0] - points[1]).distance;
    _pinchStartScale = _scale;
    _pinchStartFocal = (points[0] + points[1]) / 2;
    _pinchStartTranslation = _translation;
    _panLastLocal = null;
    _syncContactFlags();
  }

  void _updatePinch() {
    if (_pointers.length < 2 ||
        _pinchStartSpan == null ||
        _pinchStartFocal == null) {
      return;
    }
    final points = _pointers.values.toList(growable: false);
    final span = (points[0] - points[1]).distance;
    final focal = (points[0] + points[1]) / 2;
    if (_pinchStartSpan! < 1) {
      return;
    }
    final nextScale = (_pinchStartScale * span / _pinchStartSpan!).clamp(
      kCap20MinScale,
      kCap20MaxScale,
    );
    final startFocalC = _focalFromLayoutCenter(_pinchStartFocal!);
    final focalC = _focalFromLayoutCenter(focal);
    final scaled = focalZoomTranslation(
      translation: _pinchStartTranslation,
      scale: _pinchStartScale,
      nextScale: nextScale,
      focalFromLayoutCenter: startFocalC,
    );
    // Midpoint travel (Photos-style pan while pinching).
    final raw = scaled + (focalC - startFocalC);
    _scale = nextScale;
    _applyClampedTranslation(raw);
    _publishMatrix();
    if (_isStill) {
      _publishStillMagnified(_isMagnified);
    }
    _syncContactFlags();
  }

  void _updatePan(Offset local) {
    if (!_isMagnified) {
      return;
    }
    if (_panLastLocal == null) {
      _panLastLocal = local;
      return;
    }
    final delta = local - _panLastLocal!;
    _panLastLocal = local;
    _applyClampedTranslation(_translation + delta);
    _publishMatrix();
    _syncContactFlags();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!_enabled) {
      return;
    }
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length >= 2) {
      _beginPinch();
    } else if (_pointers.length == 1 && _isMagnified) {
      _panLastLocal = event.localPosition;
    }
    _syncContactFlags();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_enabled || !_pointers.containsKey(event.pointer)) {
      return;
    }
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length >= 2) {
      if (_pinchStartSpan == null) {
        _beginPinch();
      }
      _updatePinch();
    } else if (_pointers.length == 1 && _isMagnified) {
      _updatePan(event.localPosition);
    }
  }

  void _onPointerUpOrCancel(int pointer) {
    if (!_enabled && _pointers.isEmpty) {
      return;
    }
    _pointers.remove(pointer);
    if (_pointers.length < 2) {
      _pinchStartSpan = null;
    }
    if (_pointers.length == 1 && _isMagnified) {
      _panLastLocal = _pointers.values.first;
    }
    if (_pointers.isEmpty) {
      if (_isStill) {
        if (!_isMagnified) {
          _resetToFitTransform();
          _publishStillMagnified(false);
        } else {
          _publishStillMagnified(true);
        }
      } else if (_isTransient) {
        _startTransientReleaseToFit();
      }
      _panLastLocal = null;
    }
    _syncContactFlags();
  }

  @override
  Widget build(BuildContext context) {
    // Single listen on the notifier state — do not also listen
    // [browseStillMagnifiedProvider] (derived): both would fire on forceFit and
    // re-enter interrupt in the same frame.
    ref.listen<BrowseMagnificationState>(browseMagnificationProvider, (
      previous,
      next,
    ) {
      // forceFit / leave-current / panel: drop mid-release animation immediately.
      if (previous != null &&
          previous.hasActiveMagnification &&
          !next.hasActiveMagnification) {
        // Stop release anim / fit matrix — keep pointers so L1→L2 handoff
        // (forceFit mid-gesture) can re-baseline. Mode→none still clears
        // pointers via [_interruptBecauseHostModeCleared].
        _resetLocalTransformState(clearPointers: false);
      }
    });
    ref.listen<MagnificationHostMode>(magnificationHostModeProvider, (
      previous,
      next,
    ) {
      if (previous != MagnificationHostMode.none &&
          next == MagnificationHostMode.none) {
        _interruptBecauseHostModeCleared();
      } else if (previous != null &&
          previous != MagnificationHostMode.none &&
          next != MagnificationHostMode.none &&
          previous != next) {
        // Same-page L1→L2 (transient → still): fit without clearing pointers.
        _handoffModeKeepPointers();
      }
    });
    ref.listen<bool>(nativeDisplayMagnificationPushProvider, (previous, next) {
      if (previous == true && next == false) {
        // Disarming video L2 push must clear any leftover native transform.
        unawaited(
          ref.read(playbackRepositoryProvider).setDisplayMagnification(
            scale: kCap20MinScale,
            translationX: 0,
            translationY: 0,
          ),
        );
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          key: const Key('magnificationPointerHost'),
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: (e) => _onPointerUpOrCancel(e.pointer),
          onPointerCancel: (e) => _onPointerUpOrCancel(e.pointer),
          child: widget.child,
        );
      },
    );
  }
}

/// Applies [magnificationMatrixProvider] to still image content.
///
/// [apply] must be true only for the **current** page — otherwise every
/// prefetched neighbour that mounts a Transform would share the session
/// matrix and appear to zoom during another page's pinch (Cap 20.4 device).
class StillMagnificationTransform extends ConsumerWidget {
  const StillMagnificationTransform({
    super.key,
    required this.child,
    this.apply = true,
  });

  final Widget child;
  final bool apply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = apply
        ? ref.watch(magnificationMatrixProvider)
        : MagnificationMatrix.identity;
    return Transform(
      key: const Key('stillMagnificationTransform'),
      transform: matrix.matrix,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      child: child,
    );
  }
}

/// Applies [magnificationMatrixProvider] to the video surface subtree.
///
/// Cap 20.4: L2 UiKitView does not follow Flutter [Transform] on iOS —
/// visual scale is [PlaybackRepository.setDisplayMagnification]. Keep
/// [apply] false for L2; L1 video posters use [StillMagnificationTransform].
class VideoMagnificationTransform extends ConsumerWidget {
  const VideoMagnificationTransform({
    super.key,
    required this.child,
    this.apply = true,
  });

  final Widget child;
  final bool apply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = apply
        ? ref.watch(magnificationMatrixProvider)
        : MagnificationMatrix.identity;
    return Transform(
      key: const Key('videoMagnificationTransform'),
      transform: matrix.matrix,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      child: child,
    );
  }
}

/// Binds current still → [MagnificationHostMode.still] (persistent path).
///
/// Cap 20 L1 unify: photo / Live static browse images use
/// [TransientMagnificationActiveBinder] (non-persistent) instead. This binder
/// remains for any future persistent-only surface.
class StillMagnificationActiveBinder extends ConsumerStatefulWidget {
  const StillMagnificationActiveBinder({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  ConsumerState<StillMagnificationActiveBinder> createState() =>
      _StillMagnificationActiveBinderState();
}

class _StillMagnificationActiveBinderState
    extends ConsumerState<StillMagnificationActiveBinder> {
  bool? _lastSyncedActive;

  void _sync(bool active) {
    if (_lastSyncedActive == active) {
      return;
    }
    _lastSyncedActive = active;
    if (!active) {
      // Never clearIf here — neighbour deactivate racing the new current's
      // setMode left Host mode [none] and dead pinch until revisit (Kafka).
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) {
        return;
      }
      ref
          .read(magnificationHostModeProvider.notifier)
          .setMode(MagnificationHostMode.still);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(widget.active);
  }

  @override
  void didUpdateWidget(StillMagnificationActiveBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _sync(widget.active);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Binds current page → [MagnificationHostMode.transient] (non-persistent).
///
/// Cap 20: video L1/L2 and photo / Live-static **L1 (preview)** use this mode —
/// release→fit, no Reset. Photo L2 uses [StillMagnificationActiveBinder].
/// Binders only [setMode]; page leave clears mode.
class TransientMagnificationActiveBinder extends ConsumerStatefulWidget {
  const TransientMagnificationActiveBinder({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  ConsumerState<TransientMagnificationActiveBinder> createState() =>
      _TransientMagnificationActiveBinderState();
}

class _TransientMagnificationActiveBinderState
    extends ConsumerState<TransientMagnificationActiveBinder> {
  bool? _lastSyncedActive;

  void _sync(bool active) {
    if (_lastSyncedActive == active) {
      return;
    }
    _lastSyncedActive = active;
    if (!active) {
      // See StillMagnificationActiveBinder — no clearIf on deactivate.
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) {
        return;
      }
      ref
          .read(magnificationHostModeProvider.notifier)
          .setMode(MagnificationHostMode.transient);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(widget.active);
  }

  @override
  void didUpdateWidget(TransientMagnificationActiveBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _sync(widget.active);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Arms [nativeDisplayMagnificationPushProvider] only while video L2 visually
/// owns pinch. Must not follow [MagnificationHostMode.transient] (photo L1).
class NativeDisplayMagnificationPushBinder extends ConsumerStatefulWidget {
  const NativeDisplayMagnificationPushBinder({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  ConsumerState<NativeDisplayMagnificationPushBinder> createState() =>
      _NativeDisplayMagnificationPushBinderState();
}

class _NativeDisplayMagnificationPushBinderState
    extends ConsumerState<NativeDisplayMagnificationPushBinder> {
  bool? _lastSyncedActive;

  void _sync(bool active) {
    if (_lastSyncedActive == active) {
      return;
    }
    _lastSyncedActive = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      // Always write — deactivate must clear even when widget.active flipped.
      if (!widget.active) {
        ref.read(nativeDisplayMagnificationPushProvider.notifier).setEnabled(false);
        return;
      }
      ref.read(nativeDisplayMagnificationPushProvider.notifier).setEnabled(true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(widget.active);
  }

  @override
  void didUpdateWidget(NativeDisplayMagnificationPushBinder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _sync(widget.active);
    }
  }

  @override
  void dispose() {
    if (_lastSyncedActive == true) {
      try {
        ref.read(nativeDisplayMagnificationPushProvider.notifier).setEnabled(false);
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Full-bleed letterbox chrome outside the Transform; fitted content inside.
///
/// Reports [magnificationContentSizeProvider] while [active] so the Host can
/// clamp pan to the photo (not the black bars).
class StillFittedMagnificationShell extends ConsumerStatefulWidget {
  const StillFittedMagnificationShell({
    super.key,
    required this.active,
    required this.backgroundColor,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.child,
  });

  final bool active;
  final Color backgroundColor;
  final int? pixelWidth;
  final int? pixelHeight;

  /// Binder → Transform → Image (fills the fitted [SizedBox]).
  final Widget child;

  @override
  ConsumerState<StillFittedMagnificationShell> createState() =>
      _StillFittedMagnificationShellState();
}

class _StillFittedMagnificationShellState
    extends ConsumerState<StillFittedMagnificationShell> {
  Size? _lastReported;

  void _report(Size fitted) {
    if (!widget.active) {
      return;
    }
    if (_lastReported != null &&
        (_lastReported!.width - fitted.width).abs() < 0.5 &&
        (_lastReported!.height - fitted.height).abs() < 0.5) {
      return;
    }
    _lastReported = fitted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) {
        return;
      }
      ref.read(magnificationContentSizeProvider.notifier).setContentSize(fitted);
    });
  }

  void _clearIfNeeded() {
    _lastReported = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(magnificationContentSizeProvider.notifier).clear();
    });
  }

  @override
  void didUpdateWidget(StillFittedMagnificationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _clearIfNeeded();
    }
  }

  @override
  void dispose() {
    if (widget.active) {
      try {
        ref.read(magnificationContentSizeProvider.notifier).clear();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final pw = widget.pixelWidth;
        final ph = widget.pixelHeight;
        final Size fitted;
        if (pw != null && ph != null && pw > 0 && ph > 0) {
          fitted = fittedContainSize(
            imageSize: Size(pw.toDouble(), ph.toDouble()),
            viewport: viewport,
          );
        } else {
          fitted = viewport;
        }
        _report(fitted);
        return ColoredBox(
          color: widget.backgroundColor,
          child: Center(
            child: SizedBox(
              key: const Key('stillMagnificationContentBox'),
              width: fitted.width,
              height: fitted.height,
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// Reports fitted contain size for L2 video clamp without changing layout.
class MagnificationContentSizeReporter extends ConsumerStatefulWidget {
  const MagnificationContentSizeReporter({
    super.key,
    required this.active,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.child,
  });

  final bool active;
  final int? pixelWidth;
  final int? pixelHeight;
  final Widget child;

  @override
  ConsumerState<MagnificationContentSizeReporter> createState() =>
      _MagnificationContentSizeReporterState();
}

class _MagnificationContentSizeReporterState
    extends ConsumerState<MagnificationContentSizeReporter> {
  Size? _lastReported;

  void _report(Size fitted) {
    if (!widget.active) {
      return;
    }
    if (_lastReported != null &&
        (_lastReported!.width - fitted.width).abs() < 0.5 &&
        (_lastReported!.height - fitted.height).abs() < 0.5) {
      return;
    }
    _lastReported = fitted;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) {
        return;
      }
      ref.read(magnificationContentSizeProvider.notifier).setContentSize(fitted);
    });
  }

  @override
  void didUpdateWidget(MagnificationContentSizeReporter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _lastReported = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(magnificationContentSizeProvider.notifier).clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final pw = widget.pixelWidth;
        final ph = widget.pixelHeight;
        final Size fitted;
        if (pw != null && ph != null && pw > 0 && ph > 0) {
          fitted = fittedContainSize(
            imageSize: Size(pw.toDouble(), ph.toDouble()),
            viewport: viewport,
          );
        } else {
          fitted = viewport;
        }
        _report(fitted);
        return widget.child;
      },
    );
  }
}
