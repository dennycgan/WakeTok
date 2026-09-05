import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Cap 20 max scale — owner-locked **4×** (ADR-043 Decision 5; Cap 20.6).
const double kCap20MaxScale = 4.0;

/// Magnification floor — clamp-to-fit; no smaller-than-fit (ADR-043).
const double kCap20MinScale = 1.0;

/// BoxFit.contain destination size for [imageSize] inside [viewport].
Size fittedContainSize({
  required Size imageSize,
  required Size viewport,
}) {
  if (imageSize.width <= 0 ||
      imageSize.height <= 0 ||
      viewport.width <= 0 ||
      viewport.height <= 0) {
    return viewport;
  }
  return applyBoxFitContain(imageSize, viewport);
}

/// Same math as [BoxFit.contain] without a [BuildContext].
Size applyBoxFitContain(Size source, Size destination) {
  final scale = math.min(
    destination.width / source.width,
    destination.height / source.height,
  );
  return Size(source.width * scale, source.height * scale);
}

/// Focal pinch: keep the content point under the focal fixed while scale changes.
///
/// [translation] and [focalFromLayoutCenter] are in the same parent space as a
/// center-aligned [Transform] (offset of the content center from layout center).
Offset focalZoomTranslation({
  required Offset translation,
  required double scale,
  required double nextScale,
  required Offset focalFromLayoutCenter,
}) {
  if (scale.abs() < 1e-6) {
    return translation;
  }
  final ratio = nextScale / scale;
  return focalFromLayoutCenter -
      (focalFromLayoutCenter - translation) * ratio;
}

/// When scaled content is smaller than the viewport on an axis, lock that axis
/// to center (no letterbox pan); otherwise keep scaled content edges from
/// exposing empty feed chrome.
Offset clampMagnificationTranslation({
  required Offset translation,
  required double scale,
  required Size viewport,
  required Size contentAtFit,
}) {
  final s = scale.clamp(kCap20MinScale, kCap20MaxScale);
  final scaledW = contentAtFit.width * s;
  final scaledH = contentAtFit.height * s;

  double clampAxis(double t, double scaled, double view) {
    if (scaled <= view + 0.5) {
      return 0;
    }
    final maxT = (scaled - view) / 2;
    return t.clamp(-maxT, maxT);
  }

  return Offset(
    clampAxis(translation.dx, scaledW, viewport.width),
    clampAxis(translation.dy, scaledH, viewport.height),
  );
}

/// Full pinch step from a gesture baseline: focal scale about start focal,
/// plus midpoint travel, then clamp.
({double scale, Offset translation}) applyFocalPinch({
  required double startScale,
  required Offset startTranslation,
  required double startSpan,
  required double currentSpan,
  required Offset startFocalFromLayoutCenter,
  required Offset currentFocalFromLayoutCenter,
  required Size viewport,
  required Size contentAtFit,
  double minScale = kCap20MinScale,
  double maxScale = kCap20MaxScale,
}) {
  if (startSpan < 1) {
    return (scale: startScale, translation: startTranslation);
  }
  final nextScale = (startScale * currentSpan / startSpan).clamp(
    minScale,
    maxScale,
  );
  final scaled = focalZoomTranslation(
    translation: startTranslation,
    scale: startScale,
    nextScale: nextScale,
    focalFromLayoutCenter: startFocalFromLayoutCenter,
  );
  final raw =
      scaled + (currentFocalFromLayoutCenter - startFocalFromLayoutCenter);
  final clamped = clampMagnificationTranslation(
    translation: raw,
    scale: nextScale,
    viewport: viewport,
    contentAtFit: contentAtFit,
  );
  return (scale: nextScale, translation: clamped);
}
