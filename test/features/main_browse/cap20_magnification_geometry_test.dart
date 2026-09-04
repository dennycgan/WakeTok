import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/magnification_geometry.dart';

void main() {
  test('fittedContainSize letterboxes portrait in landscape viewport', () {
    final fitted = fittedContainSize(
      imageSize: const Size(1000, 2000),
      viewport: const Size(400, 800),
    );
    expect(fitted.width, 400);
    expect(fitted.height, 800);
  });

  test('fittedContainSize letterboxes landscape in portrait viewport', () {
    final fitted = fittedContainSize(
      imageSize: const Size(2000, 1000),
      viewport: const Size(400, 800),
    );
    expect(fitted.width, 400);
    expect(fitted.height, 200);
  });

  test('focalZoomTranslation keeps focal point fixed when scale changes', () {
    // Content center offset 0; focal 100px right of center; scale 1→2.
    // Point under focal was at +100; after 2× it would be at +200 without
    // compensation — translation must pull back by 100.
    final next = focalZoomTranslation(
      translation: Offset.zero,
      scale: 1,
      nextScale: 2,
      focalFromLayoutCenter: const Offset(100, 0),
    );
    expect(next.dx, closeTo(-100, 0.01));
    expect(next.dy, closeTo(0, 0.01));
  });

  test('clampMagnificationTranslation blocks letterbox pan when undersized', () {
    final clamped = clampMagnificationTranslation(
      translation: const Offset(40, 50),
      scale: 1,
      viewport: const Size(400, 800),
      contentAtFit: const Size(400, 200),
    );
    expect(clamped.dx, 0);
    expect(clamped.dy, 0);
  });

  test('clampMagnificationTranslation limits pan when oversized', () {
    final clamped = clampMagnificationTranslation(
      translation: const Offset(500, 0),
      scale: 2,
      viewport: const Size(400, 800),
      contentAtFit: const Size(400, 200),
    );
    // scaledW=800, maxT=(800-400)/2=200
    expect(clamped.dx, closeTo(200, 0.01));
    expect(clamped.dy, 0);
  });

  test('applyFocalPinch scales about start focal then applies midpoint travel', () {
    final result = applyFocalPinch(
      startScale: 1,
      startTranslation: Offset.zero,
      startSpan: 100,
      currentSpan: 200,
      startFocalFromLayoutCenter: const Offset(80, 0),
      currentFocalFromLayoutCenter: const Offset(80, 0),
      viewport: const Size(400, 800),
      contentAtFit: const Size(400, 800),
    );
    expect(result.scale, 2);
    // Focal fixed at +80 from center → translation -80 before clamp;
    // at 2× full-bleed content, maxT=(800-400)/2=200 on x? scaledW=800.
    expect(result.translation.dx, closeTo(-80, 0.01));
  });
}
