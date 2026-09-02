import 'package:waketok/features/main_browse/center_playback_affordance.dart';

/// Horizontal inset for Cap 19 entry icon (aligns with feed corner chrome).
const double kCap19EntryIconTrailingInset = 12;

/// Vertical gap above the scrubber reserve band for the entry icon.
///
/// Shell-fixed: does **not** vary by current feed page media type (video /
/// still / Live). The icon lives on [MainBrowseShellPage]'s overlay Stack
/// (Browse destination only), not inside a feed page — changing bottom per
/// page would make the icon jump while scrolling.
const double kCap19EntryIconAboveScrubberGap = 40;

/// Frosted tint over [BackdropFilter] — dark enough to crush bottom-left
/// [MediaInfoOverlay] glyphs under the sheet (readable bleed was overlap).
const double kCap19ActionsHalfSheetTintOpacity = 0.78;

/// Barrier dim behind the sheet (feed still visible; lighter than full scrim).
const double kCap19ActionsHalfSheetBarrierOpacity = 0.28;

/// Gaussian blur sigma for the sheet frosted glass (device-tunable in notes).
const double kCap19ActionsHalfSheetBlurSigma = 22;

/// Cap 19 panel max height as a fraction of screen (TikTok-class half-sheet).
const double kCap19ActionsHalfSheetMaxHeightFactor = 0.5;

/// Album / Favorites picker row thumbnail edge length.
const double kCap19PanelRowThumbnailSize = 52;

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
double cap19EntryIconBottomInset() {
  return kMainBrowseScrubberReserveHeight + kCap19EntryIconAboveScrubberGap;
}
