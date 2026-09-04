import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';

/// Provisional MVP max scale (ADR-043 D5). Cap 20.6 may pick 3× vs 4×.
const double kCap20StillMaxScale = 4.0;

/// Magnification floor — clamp-to-fit; no smaller-than-fit (ADR-043).
const double kCap20StillMinScale = 1.0;

/// Epsilon above fit before treating the still as magnified.
const double kCap20StillMagnifiedEpsilon = 0.02;

/// Session matrix for the current still (read by [StillMagnificationTransform]).
@immutable
class StillMagnificationMatrix {
  const StillMagnificationMatrix({
    this.scale = kCap20StillMinScale,
    this.translation = Offset.zero,
  });

  final double scale;
  final Offset translation;

  bool get isMagnified =>
      scale > kCap20StillMinScale + kCap20StillMagnifiedEpsilon;

  Matrix4 get matrix {
    return Matrix4.identity()
      ..translateByDouble(translation.dx, translation.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  static const StillMagnificationMatrix identity = StillMagnificationMatrix();
}

/// Live matrix for the current still page transform.
final stillMagnificationMatrixProvider =
    NotifierProvider<StillMagnificationMatrixNotifier, StillMagnificationMatrix>(
      StillMagnificationMatrixNotifier.new,
    );

class StillMagnificationMatrixNotifier
    extends Notifier<StillMagnificationMatrix> {
  @override
  StillMagnificationMatrix build() => StillMagnificationMatrix.identity;

  void setMatrix({required double scale, required Offset translation}) {
    final next = StillMagnificationMatrix(scale: scale, translation: translation);
    if (state.scale == next.scale && state.translation == next.translation) {
      return;
    }
    state = next;
  }

  void reset() {
    if (state == StillMagnificationMatrix.identity) {
      return;
    }
    state = StillMagnificationMatrix.identity;
  }
}

/// Whether the current feed page should accept still pinch (still + current +
/// not Live motion). Written by the current [MediaFeedPage] still path.
final stillMagnificationSurfaceActiveProvider =
    NotifierProvider<StillMagnificationSurfaceActive, bool>(
      StillMagnificationSurfaceActive.new,
    );

class StillMagnificationSurfaceActive extends Notifier<bool> {
  @override
  bool build() => false;

  void setActive(bool active) {
    if (state == active) {
      return;
    }
    state = active;
  }
}

/// Wraps [PageView] so multi-touch reaches pinch tracking.
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
/// Do **not** explain this as "Flutter never hit-tests a 2nd pointer into a
/// Scrollable's child tree by design" (hit-test is still per-pointer /
/// geometric) — record the observed path change + outer-Listener fix.
/// Cap 20.4 video pinch should reuse this host's gating, not stack another
/// parent [Listener].
///
/// Plan A: lock PageView only while ≥2 fingers ([stillPinchContact]).
class StillMagnificationPointerHost extends ConsumerStatefulWidget {
  const StillMagnificationPointerHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StillMagnificationPointerHost> createState() =>
      _StillMagnificationPointerHostState();
}

class _StillMagnificationPointerHostState
    extends ConsumerState<StillMagnificationPointerHost> {
  final Map<int, Offset> _pointers = <int, Offset>{};

  double _scale = kCap20StillMinScale;
  Offset _translation = Offset.zero;

  double? _pinchStartSpan;
  double _pinchStartScale = kCap20StillMinScale;
  Offset? _pinchStartFocal;
  Offset _pinchStartTranslation = Offset.zero;

  Offset? _panLastLocal;

  bool get _enabled => ref.read(stillMagnificationSurfaceActiveProvider);

  bool get _isMagnified =>
      _scale > kCap20StillMinScale + kCap20StillMagnifiedEpsilon;

  void _publishMatrix() {
    ref.read(stillMagnificationMatrixProvider.notifier).setMatrix(
      scale: _scale,
      translation: _translation,
    );
  }

  void _publishMagnified(bool magnified) {
    if (!_enabled) {
      return;
    }
    ref.read(browseMagnificationProvider.notifier).setStillMagnified(magnified);
  }

  void _publishContact(bool active) {
    if (!_enabled && !active) {
      ref.read(browseMagnificationProvider.notifier).setStillPinchContact(false);
      return;
    }
    if (!_enabled) {
      return;
    }
    ref.read(browseMagnificationProvider.notifier).setStillPinchContact(active);
  }

  void _syncContactFlag() {
    _publishContact(_pointers.length >= 2);
  }

  void _resetToFitTransform() {
    _scale = kCap20StillMinScale;
    _translation = Offset.zero;
    _pinchStartSpan = null;
    _panLastLocal = null;
    _publishMatrix();
  }

  void _beginPinch() {
    if (_pointers.length < 2) {
      return;
    }
    final points = _pointers.values.toList(growable: false);
    _pinchStartSpan = (points[0] - points[1]).distance;
    _pinchStartScale = _scale;
    _pinchStartFocal = (points[0] + points[1]) / 2;
    _pinchStartTranslation = _translation;
    _panLastLocal = null;
    _syncContactFlag();
  }

  void _updatePinch() {
    if (_pointers.length < 2 || _pinchStartSpan == null) {
      return;
    }
    final points = _pointers.values.toList(growable: false);
    final span = (points[0] - points[1]).distance;
    if (_pinchStartSpan! < 1) {
      return;
    }
    final nextScale = (_pinchStartScale * span / _pinchStartSpan!).clamp(
      kCap20StillMinScale,
      kCap20StillMaxScale,
    );
    final focal = (points[0] + points[1]) / 2;
    final focalDelta = focal - (_pinchStartFocal ?? focal);
    _scale = nextScale;
    _translation = _pinchStartTranslation + focalDelta;
    _publishMatrix();
    _publishMagnified(_isMagnified);
    _syncContactFlag();
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
    _translation += delta;
    _publishMatrix();
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
    _syncContactFlag();
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
      if (!_isMagnified) {
        _resetToFitTransform();
        _publishMagnified(false);
      } else {
        _publishMagnified(true);
      }
      _panLastLocal = null;
    }
    _syncContactFlag();
  }

  void _hardReset() {
    _pointers.clear();
    _resetToFitTransform();
    _publishContact(false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(browseStillMagnifiedProvider, (previous, next) {
      if (previous == true && next == false) {
        _hardReset();
      }
    });
    ref.listen<bool>(stillMagnificationSurfaceActiveProvider, (previous, next) {
      if (previous == true && next == false) {
        _hardReset();
        _publishMagnified(false);
      }
    });

    return Listener(
      key: const Key('stillMagnificationSurface'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (e) => _onPointerUpOrCancel(e.pointer),
      onPointerCancel: (e) => _onPointerUpOrCancel(e.pointer),
      child: widget.child,
    );
  }
}

/// Applies [stillMagnificationMatrixProvider] to the still image only.
class StillMagnificationTransform extends ConsumerWidget {
  const StillMagnificationTransform({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(stillMagnificationMatrixProvider);
    return Transform(
      key: const Key('stillMagnificationTransform'),
      transform: matrix.matrix,
      alignment: Alignment.center,
      filterQuality: FilterQuality.medium,
      child: child,
    );
  }
}

/// Binds "current still accepts pinch" into [stillMagnificationSurfaceActiveProvider].
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
    // Inactive binders must not clear the flag — neighbor pages also build
    // with active:false under allowImplicitScrolling and would race the
    // current page's true.
    if (!active) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) {
        return;
      }
      ref.read(stillMagnificationSurfaceActiveProvider.notifier).setActive(true);
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
      if (!widget.active && oldWidget.active) {
        _lastSyncedActive = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          ref
              .read(stillMagnificationSurfaceActiveProvider.notifier)
              .setActive(false);
        });
      } else {
        _sync(widget.active);
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
