import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';

/// Max bubble width; also clamped to overlay width − padding.
const double kCap24TimezoneNoteBubbleMaxWidth = 300;

/// Max bubble height; overflow scrolls inside the bubble.
const double kCap24TimezoneNoteBubbleMaxHeight = 280;

const double kCap24TimezoneNoteBubbleGap = 6;
const double _kBubbleEdgePad = 12;

/// Handle for an open Cap 24 timezone honesty bubble.
///
/// [dismiss] only removes the [OverlayEntry] — it must never call
/// [Navigator.pop] (sheet dismiss stays on the modal route / PopScope).
final class Cap24TimezoneNoteBubbleHandle {
  Cap24TimezoneNoteBubbleHandle._(this._entry, {this.onDismissed});

  OverlayEntry? _entry;
  final VoidCallback? onDismissed;

  bool get isShowing => _entry != null;

  /// Removes the overlay only — never pops a [Navigator] route.
  void dismiss() {
    if (_entry == null) {
      return;
    }
    _entry?.remove();
    _entry = null;
    onDismissed?.call();
  }
}

/// Shows a lightweight anchored bubble with [message] near the anchor.
///
/// Prefer [anchorKey]; for tests, [anchorOverlayRect] may supply a rect in
/// overlay coordinates when the production GlobalKey is inaccessible.
/// Prefer above the anchor; flip below if needed. Horizontal shift keeps the
/// bubble on-screen (may extend into the modal barrier above the sheet).
Cap24TimezoneNoteBubbleHandle showCap24TimezoneNoteBubble({
  required BuildContext context,
  required String message,
  GlobalKey? anchorKey,
  Rect? anchorOverlayRect,
  VoidCallback? onDismissed,
}) {
  assert(
    anchorKey != null || anchorOverlayRect != null,
    'showCap24TimezoneNoteBubble requires anchorKey or anchorOverlayRect',
  );

  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (overlayBox == null || !overlayBox.hasSize) {
    return Cap24TimezoneNoteBubbleHandle._(null, onDismissed: onDismissed);
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
      return Cap24TimezoneNoteBubbleHandle._(null, onDismissed: onDismissed);
    }
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.hasSize) {
      return Cap24TimezoneNoteBubbleHandle._(null, onDismissed: onDismissed);
    }
    anchorTopLeft = anchorBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    anchorSize = anchorBox.size;
  }

  final tokens = Theme.of(context).extension<WakeTokTokens>()!;
  final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
        color: tokens.onSurface,
        height: 1.35,
      );

  late Cap24TimezoneNoteBubbleHandle handle;

  void dismissOnly() => handle.dismiss();

  final entry = OverlayEntry(
    builder: (overlayContext) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('cap24SoftDeleteSheetMinuteTimezoneNoteBarrier'),
              behavior: HitTestBehavior.opaque,
              // Opaque: do not pass taps through to the modal sheet barrier
              // (would pop the half-sheet) or to Delete (first tap closes note).
              onTap: dismissOnly,
            ),
          ),
          _AnchoredTimezoneNoteBubble(
            overlaySize: overlaySize,
            anchorTopLeft: anchorTopLeft,
            anchorSize: anchorSize,
            message: message,
            textStyle: textStyle,
            surfaceColor: tokens.surface.withValues(alpha: 0.96),
          ),
        ],
      );
    },
  );

  handle = Cap24TimezoneNoteBubbleHandle._(entry, onDismissed: onDismissed);
  overlay.insert(entry);
  return handle;
}

class _AnchoredTimezoneNoteBubble extends StatelessWidget {
  const _AnchoredTimezoneNoteBubble({
    required this.overlaySize,
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.message,
    required this.textStyle,
    required this.surfaceColor,
  });

  final Size overlaySize;
  final Offset anchorTopLeft;
  final Size anchorSize;
  final String message;
  final TextStyle? textStyle;
  final Color surfaceColor;

  @override
  Widget build(BuildContext context) {
    final maxWidth = (overlaySize.width - (_kBubbleEdgePad * 2))
        .clamp(0.0, kCap24TimezoneNoteBubbleMaxWidth)
        .toDouble();
    final maxHeight = kCap24TimezoneNoteBubbleMaxHeight;

    final spaceAbove = anchorTopLeft.dy - _kBubbleEdgePad;
    final spaceBelow = overlaySize.height -
        (anchorTopLeft.dy + anchorSize.height) -
        _kBubbleEdgePad;
    // Prefer directly above the i; only flip below when above is too tight.
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
        key: const Key('cap24SoftDeleteSheetMinuteTimezoneNote'),
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
      // Pin the bubble's *bottom* just above the i — not top at -maxHeight
      // (that left a large empty gap when the copy was shorter than maxHeight).
      final heightBudget =
          spaceAbove.clamp(48.0, maxHeight).toDouble();
      return Positioned(
        left: left,
        width: maxWidth,
        bottom: overlaySize.height -
            (anchorTopLeft.dy - kCap24TimezoneNoteBubbleGap),
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
      top: anchorTopLeft.dy + anchorSize.height + kCap24TimezoneNoteBubbleGap,
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
