import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
import 'package:waketok/features/main_browse/scrubber_policy.dart';
import 'package:waketok/l10n/app_localizations.dart';

/// Cap 18.4 placeholder height for the Cap 18.5 scrubber band.
///
/// 18.4 freezes “taps inside this band are no-op for play/pause,” not the
/// numeric value. Adjusting the height in 18.5 is not a breaking change to
/// the 18.4 hit contract.
const double kMainBrowseScrubberReserveHeight = 48;

/// Vertical gap between scrubber track and timestamp (matches scrubber UI).
const double kMainBrowseScrubberTimestampAboveTrackGap = 6;

/// Line box height for the scrubber timestamp label.
double mainBrowseScrubberTimestampLineHeight(WakeTokTokens tokens) {
  final style = tokens.labelOnMedia;
  final fontSize = style.fontSize ?? 12;
  final height = style.height ?? 1.0;
  return fontSize * height;
}

/// Feed-bottom inset of scrubber timestamp text (above track + gap).
double mainBrowseScrubberTimestampBottomInset() {
  return kScrubProgressTrackHeight + kMainBrowseScrubberTimestampAboveTrackGap;
}

/// Vertical center of scrubber timestamp line measured from feed bottom.
double mainBrowseScrubberTimestampCenterFromFeedBottom(WakeTokTokens tokens) {
  return mainBrowseScrubberTimestampBottomInset() +
      mainBrowseScrubberTimestampLineHeight(tokens) / 2;
}

/// Positions overlay row 3 center on scrubber timestamp center (rows 1–2 keep
/// uniform [MediaInfoOverlay.rowHeight] spacing above).
double mainBrowseMediaOverlayBottomInset(WakeTokTokens tokens) {
  return mainBrowseScrubberTimestampCenterFromFeedBottom(tokens) -
      MediaInfoOverlay.rowHeight / 2;
}

/// LIVE / status chrome bottom — same feed-bottom edge as Overlay column.
///
/// Overlay last-row glyphs are bottom-aligned in their row box, so this inset
/// matches the **text bottom** of row 3 (not a guessed mid-row pad).
double mainBrowseLiveStatusBottomInset(WakeTokTokens tokens) {
  return mainBrowseMediaOverlayBottomInset(tokens);
}

/// Lowest action-column **icon** bottom — aligns with Reset visual bottom.
///
/// [Cap19EntryIcon] uses a [kActionColumnHitSize] box with a centered
/// [kActionColumnIconSize] glyph; the Positioned `bottom` is therefore this
/// value minus the vertical centering inset so the **icon** (not the hit box)
/// shares Reset’s bottom edge. That edge sits [kResetAboveMetaGap] above
/// Overlay row-1 top.
double mainBrowseActionColumnLowestBottomInset(WakeTokTokens tokens) {
  final resetBottom = mainBrowseMediaOverlayBottomInset(tokens) +
      MediaInfoOverlay.rowHeight * MediaInfoOverlay.baseRowCount +
      kResetAboveMetaGap;
  final iconCenterInset =
      (kActionColumnHitSize - kActionColumnIconSize) / 2;
  return resetBottom - iconCenterInset;
}

/// Cap 17.4 usable-region reserve above overlay rows 1–3 (all asset sources).
double mainBrowseCoverlessCenterOverlayReserve(WakeTokTokens tokens) {
  return MediaInfoOverlay.rowHeight * MediaInfoOverlay.baseRowCount +
      mainBrowseMediaOverlayBottomInset(tokens);
}

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
