/// Shared Main Browse media-area chrome layout (meta / Reset / LIVE / actions)
/// and Browse shell top-chrome metrics that media chrome must align to.
///
/// Cross-Cap visual system — not Cap 20–specific. Documented in
/// `docs/reference/media-chrome-layout-notes.md`.
library;

import 'package:flutter/material.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/l10n/app_localizations.dart';

// --- Shared edges -----------------------------------------------------------

/// Content leading edge: Overlay glyph left == Reset **icon** left.
const double kMediaChromeLeadingInset = 16;

/// Trailing edge for action column (+ former bottom-trailing status).
const double kMediaChromeTrailingInset = 12;

/// Gap between Overlay copy and the right-hand chrome reserve.
const double kMediaChromeOverlayClearance = 16;

/// Overlay `padding.right` — action column + clearance.
///
/// Cap 26.4b: LIVE moved top-leading; no longer reserves trailing LIVE width.
/// Was `max(12+48, 12+80)+16 = 108`; now **76**.
double get kMediaChromeOverlayTrailingInset =>
    kMediaChromeTrailingInset +
    kActionColumnHitSize +
    kMediaChromeOverlayClearance;

// --- Browse shell top chrome (shared with feed LIVE top-leading) ------------

/// Cap 21.3 / 26.4b: fixed hit / pill height (Temp, Saved, Built-in, Create).
///
/// Also LIVE capsule skeleton height (media Stack top-leading).
const double kBrowseTopChromeControlHeight = 32;

/// Horizontal pad inside top-chrome control shells and LIVE capsule.
const double kBrowseTopChromeControlHPad = 10;

/// Full-capsule corner radius for height-[kBrowseTopChromeControlHeight] pills.
const double kBrowseTopChromeControlCornerRadius = 16;

/// Full Access top chrome band under [SafeArea] (no Create helper).
const double kBrowseTopChromeBandHeightFull = 52;

/// Limited + Create helper top chrome band under [SafeArea].
const double kBrowseTopChromeBandHeightLimited = 70;

/// LIVE top = [SafeArea] top + band height + this gap (band-bottom anchor).
const double kLiveBadgeBelowTopChromeGap = 0;

/// LIVE / Temp·Saved chip leading edge (`Positioned(left: …)`).
///
/// Cap 26.4b: LIVE **left** aligns with Temp/Saved chip left (content-sized
/// capsule; not centerX on the Temp pill width).
const double kLiveBadgeLeadingInset = 8;

/// Drop font leading so glyphs sit in the geometric middle of fixed chrome hits.
const TextHeightBehavior kBrowseTopChromeTextHeightBehavior =
    TextHeightBehavior(
  applyHeightToFirstAscent: false,
  applyHeightToLastDescent: false,
);

/// Band height matching [BrowseTopChrome] (`createEnabled` ↔ not Limited).
double browseTopChromeBandHeight({required bool limitedCreateHelper}) {
  return limitedCreateHelper
      ? kBrowseTopChromeBandHeightLimited
      : kBrowseTopChromeBandHeightFull;
}

/// Feed-bottom-independent LIVE [Positioned.top] from screen top.
double mainBrowseLiveBadgeTopInset({
  required double mediaQueryPaddingTop,
  required bool limitedCreateHelperBand,
}) {
  return mediaQueryPaddingTop +
      browseTopChromeBandHeight(
        limitedCreateHelper: limitedCreateHelperBand,
      ) +
      kLiveBadgeBelowTopChromeGap;
}

/// Cap 26.4b Temp-Pool selected pill **width**.
///
/// Locale-dependent (`mainBrowseTempPoolChip` ARB) + 2×[kBrowseTopChromeControlHPad].
/// Single source for shell Temp/Saved/Built-in selected width.
double browseTempPoolPillWidth(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  final tokens = Theme.of(context).extension<WakeTokTokens>()!;
  final style = tokens.labelOnMedia.copyWith(
    color: tokens.accent,
    inherit: false,
    height: 1.0,
    shadows: tokens.onMediaLabelShadows,
  );
  final painter = TextPainter(
    text: TextSpan(text: l10n.mainBrowseTempPoolChip, style: style),
    textDirection: Directionality.of(context),
    maxLines: 1,
    textHeightBehavior: kBrowseTopChromeTextHeightBehavior,
  )..layout();
  return painter.width + 2 * kBrowseTopChromeControlHPad;
}

// --- Action column (…=0, Share=1, Album=2) -----------------------------------

/// Visible action icon edge (owner lock Cap 20.6 layout: 32).
const double kActionColumnIconSize = 32;

/// Square hit target; icon centered (owner lock: 48).
const double kActionColumnHitSize = 48;

/// Gap between consecutive hit boxes: lower hit top ← upper hit bottom.
const double kActionColumnItemSpacing = 16;

/// Bottom inset for action index [i] above [lowestBottomInset]
/// (0 = Cap 24 `"…"`, 1 = Cap 25 Share, 2 = Cap 19 album).
double actionColumnBottomInsetForIndex(int i, double lowestBottomInset) {
  assert(i >= 0);
  return lowestBottomInset +
      i * (kActionColumnHitSize + kActionColumnItemSpacing);
}

// --- Status (LIVE fill / spinner) -------------------------------------------

/// Scrim opacity for LIVE pills on media (owner lock).
///
/// Cap 26.4b device: **0.55** — was 0.88 / 0.78; lowered so the capsule does
/// not block still / Live motion under the badge.
const double kStatusChromeScrimOpacity = 0.55;

/// Hairline onMedia border opacity on LIVE pills (owner lock).
const double kStatusChromeBorderOpacity = 0.45;

/// LIVE capsule border stroke (logical px). Cap 26.4b device: **1.0** —
/// was **0.5** (read soft next to Material AA); restored after dropping
/// `Material` for Flutter `ShapeDecoration` + `StadiumBorder`.
const double kStatusChromeBorderWidth = 1.0;

/// Horizontal pad inside the content-sized LIVE capsule (tighter than Temp 10).
const double kLiveBadgeHorizontalPad = 8;

/// Vertical pad inside the content-sized LIVE capsule.
///
/// Cap 26.4b device: **3** — was 4; slight trim so the stadium reads shorter.
const double kLiveBadgeVerticalPad = 3;

/// Gap between LIVE dot and label.
const double kLiveBadgeDotLabelGap = 6;

/// LIVE status dot diameter.
const double kLiveBadgeDotSize = 6;

/// Cap 31.4a center "!" on a failed Live long-press replay (= action icon).
const double kLiveReplayFailIconSize = 32;

/// Cap 31.4a gap from the "!" to the failure line below it.
const double kLiveReplayFailIconLabelGap = 8;

/// Cap 31.4a failure line max width (two lines max).
const double kLiveReplayFailLabelMaxWidth = 240;

/// Cap 31.4a fallback hide for the "!" — not the main hide (release is).
/// Needed because a second finger landing during the hold resets the Cap 26
/// long-press gesture without sending release, so release may never come.
const Duration kLiveReplayFailSafetyTimeout = Duration(seconds: 10);

// --- Reset ------------------------------------------------------------------

/// Minimum Reset hit edge (iOS HIG). Visual pill may be shorter; hit expands.
const double kResetMinHitEdge = 44;

/// Reset bottom → Overlay row-1 top (owner lock: 12).
const double kResetAboveMetaGap = 12;

/// Horizontal pad inside the Reset pill (both sides — capsule must wrap content).
const double kResetPillHorizontalPad = 10;

/// Vertical pad inside the Reset visual pill (slightly taller than compact).
const double kResetPillVerticalPad = 7;

/// Gap between Reset glyph and label.
const double kResetIconLabelGap = 5;
