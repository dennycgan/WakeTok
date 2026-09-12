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

/// Frosted chrome tint for Cap 19 toast / left-swipe guide (not half-sheets).
const double kCap19FrostChromeTintOpacity = 0.78;

/// Barrier dim behind the sheet (feed still visible; lighter than full scrim).
const double kCap19ActionsHalfSheetBarrierOpacity = 0.28;

/// Gaussian blur sigma for frosted chrome that still uses [BackdropFilter]
/// (toast / left-swipe guide). Half-sheets no longer blur.
const double kCap19ActionsHalfSheetBlurSigma = 22;

/// Cap 19 panel max height as a fraction of screen (Video-App-B–class half-sheet).
const double kCap19ActionsHalfSheetMaxHeightFactor = 0.5;

/// Album / Favorites picker row thumbnail edge length.
const double kCap19PanelRowThumbnailSize = 52;

/// Opacity for Cap 19 entry (and future share) when current asset is not actionable.
const double kCap19EntryIconDisabledOpacity = 0.38;

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
/// Cap 24.3: Cap 19 moves to action-column index 1; `"…"` owns index 0.
/// Aligns Cap 19's **visible** icon bottom one slot above Reset-aligned
/// lowest (hit box still extends below the glyph).
double cap19EntryIconBottomInset(WakeTokTokens tokens) =>
    actionColumnBottomInsetForIndex(
      1,
      mainBrowseActionColumnLowestBottomInset(tokens),
    );
