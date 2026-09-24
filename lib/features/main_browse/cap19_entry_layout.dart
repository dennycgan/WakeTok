import 'package:flutter/painting.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';

/// Horizontal inset for Cap 19 entry icon (aligns with feed corner chrome).
const double kCap19EntryIconTrailingInset = 12;

/// Vertical gap above the scrubber reserve band for the entry icon.
///
/// Shell-fixed: does **not** vary by current feed page media type (video /
/// still / Live). The icon lives on [MainBrowseShellPage]'s overlay Stack
/// (Browse destination only), not inside a feed page — changing bottom per
/// page would make the icon jump while scrolling.
const double kCap19EntryIconAboveScrubberGap = 40;

/// Panel fill opacity for Cap 19 / Cap 24 half-sheets ([mediaSheetSurface]).
/// Cap 24.5.1: no BackdropFilter — crush under-sheet Meta without relying on
/// blur (which does not apply over Platform View backdrops). Aligned with
/// top-chrome expanded menu panel alpha (`browse_top_chrome` 0.96).
const double kCap19ActionsHalfSheetTintOpacity = 0.96;

/// Frosted chrome tint for Cap 19 toast only (not half-sheets / not Cap 30
/// + Cap 19 left-swipe coaches — those use [browseCoachSheetFill]).
const double kCap19FrostChromeTintOpacity = 0.78;

/// Shared fill for Browse coaches `<1>` / `<2>` / `<3>`.
///
/// **Principle (P2):** same recipe as action-column half-sheets
/// (`mediaSheetSurface` @ [kCap19ActionsHalfSheetTintOpacity]) — extension
/// of media-chrome §12.0. See
/// `docs/reference/first-launch-browse-guidance.md`.
Color browseCoachSheetFill(WakeTokTokens tokens) =>
    tokens.mediaSheetSurface.withValues(
      alpha: kCap19ActionsHalfSheetTintOpacity,
    );

/// **Principle — one size for all First-launch Browse swipe-direction arrows.**
///
/// Every coach glyph that means “swipe this way” (`<1>` up/down, `<3>` left,
/// and any future tip in this guidance family) **must** use this constant
/// via [BrowseFirstLaunchCoachArrowIcon]. Do **not** hard-code a per-tip
/// size. Retune here only. Not the `<2>` Create-aim caret (different role;
/// see `kCap30CreatePoolTipArrowHeight`).
///
/// Documented in `docs/reference/first-launch-browse-guidance.md`.
const double kBrowseFirstLaunchSwipeDirectionArrowSize = 32;

/// Stroke width under the swipe-direction glyph (faux bold). Paired with
/// [kBrowseFirstLaunchSwipeDirectionArrowSize] — not a second size knob.
const double kBrowseFirstLaunchSwipeDirectionArrowStrokeWidth = 1.75;

/// Barrier dim behind the sheet (feed still visible; lighter than full scrim).
const double kCap19ActionsHalfSheetBarrierOpacity = 0.28;

/// Gaussian blur sigma for frosted chrome that still uses [BackdropFilter]
/// (toast / left-swipe guide). Half-sheets no longer blur.
const double kCap19ActionsHalfSheetBlurSigma = 22;

/// Cap 19 panel max height as a fraction of screen (Video-App-B–class half-sheet).
const double kCap19ActionsHalfSheetMaxHeightFactor = 0.5;

/// Album / Favorites picker row thumbnail edge length.
const double kCap19PanelRowThumbnailSize = 52;

/// Cap 26.4b action-column not-actionable dim (Share lock).
///
/// Cap 19 album / Cap 24 `"…"` / Cap 25 Share all use this when the current
/// asset is not tappable. Color stays `tokens.onMedia` +
/// `onMediaLabelShadows`; only [Opacity] changes. Do not invent a second
/// disabled gray or alpha per icon.
const double kActionColumnEntryIconDisabledOpacity = 0.22;

/// Alias — Cap 19 / Cap 24 entry icons (same value as action-column lock).
const double kCap19EntryIconDisabledOpacity =
    kActionColumnEntryIconDisabledOpacity;

/// Alias — Cap 25 Share historical name (same value as action-column lock).
const double kCap25ShareEntryIconDisabledOpacity =
    kActionColumnEntryIconDisabledOpacity;

/// Top chrome body below [MediaQuery.padding.top] (SafeArea + cells; ADR-016).
const double kCap19BrowseTopChromeBodyHeight = 56;

/// Gap between top source chrome and Cap 19 browse toast.
const double kCap19BrowseToastBelowTopChromeGap = 8;

/// Cap 19 browse toast visible duration (replace-on-show; no queue).
///
/// Material default SnackBar is ~4s — too long for rapid panel toggles.
/// iOS transient banners are ~2s; 1.5s fits short action copy without stacking.
const Duration kCap19BrowseToastDuration = Duration(milliseconds: 1500);

/// Bottom inset for [Cap19EntryIcon] on the Browse pane Stack.
///
/// Cap 25.3: Cap 19 moves to action-column index 2; Share owns index 1;
/// `"…"` remains index 0. Aligns Cap 19's **visible** icon bottom two slots
/// above Reset-aligned lowest (hit box still extends below the glyph).
double cap19EntryIconBottomInset(WakeTokTokens tokens) =>
    actionColumnBottomInsetForIndex(
      2,
      mainBrowseActionColumnLowestBottomInset(tokens),
    );
