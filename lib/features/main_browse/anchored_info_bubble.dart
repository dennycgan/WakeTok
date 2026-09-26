import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';

/// Max bubble width; also clamped to overlay width − padding.
const double kAnchoredInfoBubbleMaxWidth = 300;

/// Max bubble height; overflow scrolls inside the bubble.
const double kAnchoredInfoBubbleMaxHeight = 280;

/// Gap between the anchor and the bubble edge.
const double kAnchoredInfoBubbleGap = 6;

const double _kBubbleEdgePad = 12;

/// Default surface alpha (Cap 24 / Settings shared recipe).
const double kAnchoredInfoBubbleSurfaceAlpha = 0.96;

/// Handle for an open anchored info bubble.
///
/// [dismiss] only removes the [OverlayEntry] — it must never call
/// [Navigator.pop] (modal sheet dismiss stays on the route / PopScope).
final class AnchoredInfoBubbleHandle {
  AnchoredInfoBubbleHandle._(this._entry, {this.onDismissed});

  OverlayEntry? _entry;
  final VoidCallback? onDismissed;

  bool get isShowing => _entry != null;

  /// Removes the overlay only — never pops a [Navigator] route.
  ///
  /// Pass [notify] false when disposing the host widget so [onDismissed]
  /// cannot [State.setState] on a defunct element.
  void dismiss({bool notify = true}) {
    if (_entry == null) {
      return;
    }
    _entry?.remove();
    _entry = null;
    if (notify) {
      onDismissed?.call();
    }
  }
}

/// Shows a lightweight anchored bubble with [message] near the anchor.
///
/// Prefer [anchorKey]; for tests, [anchorOverlayRect] may supply a rect in
/// overlay coordinates when the production GlobalKey is inaccessible.
/// Prefer above the anchor; flip below if needed. Horizontal shift keeps the
/// bubble on-screen (may extend into a modal barrier above a sheet).
///
/// [bubbleKey] / [barrierKey] let callers keep Cap-specific finder keys
/// (e.g. Cap 24 timezone note) without baking Cap names into this API.
AnchoredInfoBubbleHandle showAnchoredInfoBubble({
  required BuildContext context,
  required String message,
  GlobalKey? anchorKey,
  Rect? anchorOverlayRect,
  Key? bubbleKey,
  Key? barrierKey,
  TextStyle? textStyle,
  Color? surfaceColor,
  VoidCallback? onDismissed,
}) {
  assert(
    anchorKey != null || anchorOverlayRect != null,
    'showAnchoredInfoBubble requires anchorKey or anchorOverlayRect',
  );

  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (overlayBox == null || !overlayBox.hasSize) {
    return AnchoredInfoBubbleHandle._(null, onDismissed: onDismissed);
  }
  final overlaySize = overlayBox.size;

  late final Offset anchorTopLeft;
  late final Size anchorSize;
  if (anchorOverlayRect != null) {
    anchorTopLeft = anchorOverlayRect.topLeft;
    anchorSize = anchorOverlayRect.size;
  } else {
    final anchorContext = anchorKey!.currentContext;
    if (anchorContext == null) {
      return AnchoredInfoBubbleHandle._(null, onDismissed: onDismissed);
    }
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) {
      return AnchoredInfoBubbleHandle._(null, onDismissed: onDismissed);
    }
    anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    anchorSize = anchorBox.size;
  }

  final tokens = Theme.of(context).extension<WakeTokTokens>()!;
  final resolvedTextStyle = textStyle ??
      tokens.bodyChrome.copyWith(
        color: tokens.onSurface,
        height: 1.35,
      );
  final resolvedSurface = surfaceColor ??
      tokens.surface.withValues(alpha: kAnchoredInfoBubbleSurfaceAlpha);

  late AnchoredInfoBubbleHandle handle;

  void dismissOnly() => handle.dismiss();

  final entry = OverlayEntry(
    builder: (overlayContext) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: barrierKey,
              behavior: HitTestBehavior.opaque,
              // Opaque: do not pass taps through to a modal sheet barrier
              // (would pop a half-sheet) or to controls under the bubble.
              onTap: dismissOnly,
            ),
          ),
          _AnchoredInfoBubble(
            overlaySize: overlaySize,
            anchorTopLeft: anchorTopLeft,
            anchorSize: anchorSize,
            message: message,
            textStyle: resolvedTextStyle,
            surfaceColor: resolvedSurface,
            bubbleKey: bubbleKey,
          ),
        ],
      );
    },
  );

  handle = AnchoredInfoBubbleHandle._(entry, onDismissed: onDismissed);
  overlay.insert(entry);
  return handle;
}

class _AnchoredInfoBubble extends StatelessWidget {
  const _AnchoredInfoBubble({
    required this.overlaySize,
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.message,
    required this.textStyle,
    required this.surfaceColor,
    this.bubbleKey,
  });

  final Size overlaySize;
  final Offset anchorTopLeft;
  final Size anchorSize;
  final String message;
  final TextStyle textStyle;
  final Color surfaceColor;
  final Key? bubbleKey;

  @override
  Widget build(BuildContext context) {
    final maxWidth = (overlaySize.width - (_kBubbleEdgePad * 2))
        .clamp(0.0, kAnchoredInfoBubbleMaxWidth)
        .toDouble();
    final maxHeight = kAnchoredInfoBubbleMaxHeight;

    final spaceAbove = anchorTopLeft.dy - _kBubbleEdgePad;
    final spaceBelow = overlaySize.height -
        (anchorTopLeft.dy + anchorSize.height) -
        _kBubbleEdgePad;
    // Prefer directly above the anchor; only flip below when above is too tight.
    final placeAbove = spaceAbove >= 96 || spaceAbove >= spaceBelow;

    final anchorCenterX = anchorTopLeft.dx + anchorSize.width / 2;
    var left = anchorCenterX - maxWidth / 2;
    if (left + maxWidth > overlaySize.width - _kBubbleEdgePad) {
      left = overlaySize.width - _kBubbleEdgePad - maxWidth;
    }
    if (left < _kBubbleEdgePad) {
      left = _kBubbleEdgePad;
    }

    final bubble = GestureDetector(
      // Absorb taps so the barrier underneath does not dismiss.
      onTap: () {},
      child: Material(
        key: bubbleKey,
        color: surfaceColor,
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Text(message, style: textStyle),
        ),
      ),
    );

    if (placeAbove) {
      // Pin the bubble's *bottom* just above the anchor — not top at -maxHeight
      // (that left a large empty gap when the copy was shorter than maxHeight).
      final heightBudget = spaceAbove.clamp(48.0, maxHeight).toDouble();
      return Positioned(
        left: left,
        width: maxWidth,
        bottom: overlaySize.height -
            (anchorTopLeft.dy - kAnchoredInfoBubbleGap),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: heightBudget,
          ),
          child: bubble,
        ),
      );
    }

    final heightBudget = spaceBelow.clamp(48.0, maxHeight).toDouble();
    return Positioned(
      left: left,
      top: anchorTopLeft.dy + anchorSize.height + kAnchoredInfoBubbleGap,
      width: maxWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: heightBudget,
        ),
        child: bubble,
      ),
    );
  }
}
