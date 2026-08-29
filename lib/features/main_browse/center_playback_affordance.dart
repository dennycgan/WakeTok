import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 18.4 placeholder height for the Cap 18.5 scrubber band.
///
/// 18.4 freezes “taps inside this band are no-op for play/pause,” not the
/// numeric value. Adjusting the height in 18.5 is not a breaking change to
/// the 18.4 hit contract.
const double kMainBrowseScrubberReserveHeight = 48;

/// Pure UI predicate for the centered play affordance (ADR-040 Decision 12).
bool showCenterPlaybackAffordance({
  required bool isCurrent,
  required bool isL2ReadyOrdinaryVideo,
  required bool isSurfaceReady,
  required bool transitionCovering,
  required bool hardFailure,
  required bool isForegroundLifecycle,
  required bool userIntentWantsPlay,
}) {
  return isCurrent &&
      isL2ReadyOrdinaryVideo &&
      isSurfaceReady &&
      !transitionCovering &&
      !hardFailure &&
      isForegroundLifecycle &&
      !userIntentWantsPlay;
}

/// Centered play disc shown when [showCenterPlaybackAffordance] is true.
class CenterPlaybackAffordance extends StatelessWidget {
  const CenterPlaybackAffordance({
    super.key,
    required this.semanticsLabel,
  });

  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<WakeTokTokens>()!;
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.mediaScrim,
          shape: BoxShape.circle,
          border: Border.all(color: tokens.onMedia, width: 1.5),
        ),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Icon(
            Icons.play_arrow_rounded,
            size: 44,
            color: tokens.onMedia,
          ),
        ),
      ),
    );
  }
}

/// Full-bleed tap + affordance overlay (placed under corner / fail chrome).
///
/// Uses [Listener] (not [GestureDetector]) so vertical [PageView] drags are
/// not competed in the gesture arena; tap is inferred from small pointer
/// travel within [kTouchSlop].
class MediaPlaybackTapOverlay extends StatefulWidget {
  const MediaPlaybackTapOverlay({
    super.key,
    required this.onTapToggle,
    required this.wantsPlay,
    required this.l10n,
    required this.showAffordance,
    this.scrubberReserveHeight = kMainBrowseScrubberReserveHeight,
  });

  final VoidCallback onTapToggle;
  final bool wantsPlay;
  final AppLocalizations l10n;
  final bool showAffordance;
  final double scrubberReserveHeight;

  @override
  State<MediaPlaybackTapOverlay> createState() =>
      _MediaPlaybackTapOverlayState();
}

class _MediaPlaybackTapOverlayState extends State<MediaPlaybackTapOverlay> {
  Offset? _pointerDown;

  void _handlePointerUp(PointerUpEvent event) {
    final start = _pointerDown;
    _pointerDown = null;
    if (start == null) {
      return;
    }
    if ((event.localPosition - start).distance > kTouchSlop) {
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    if (event.localPosition.dy >=
        box.size.height - widget.scrubberReserveHeight) {
      return;
    }
    widget.onTapToggle();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Listener(
            key: const Key('mainBrowsePlaybackTapTarget'),
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) {
              _pointerDown = event.localPosition;
            },
            onPointerUp: _handlePointerUp,
            onPointerCancel: (_) {
              _pointerDown = null;
            },
            child: Semantics(
              button: true,
              label: widget.wantsPlay
                  ? widget.l10n.mainBrowseVideoTapToPause
                  : widget.l10n.mainBrowseVideoTapToPlay,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        if (widget.showAffordance)
          IgnorePointer(
            child: Center(
              child: CenterPlaybackAffordance(
                key: const Key('mainBrowseCenterPlayAffordance'),
                semanticsLabel: widget.l10n.mainBrowseVideoTapToPlay,
              ),
            ),
          ),
      ],
    );
  }
}
