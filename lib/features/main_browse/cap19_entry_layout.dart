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

/// Frosted tint over [BackdropFilter] — TikTok-class panels show feed through.
const double kCap19ActionsHalfSheetTintOpacity = 0.52;

/// Barrier dim behind the sheet (feed still visible; lighter than full scrim).
const double kCap19ActionsHalfSheetBarrierOpacity = 0.28;

/// Gaussian blur sigma for the sheet frosted glass (device-tunable in notes).
const double kCap19ActionsHalfSheetBlurSigma = 22;

/// Bottom inset for [Cap19EntryIcon] on the Browse pane Stack.
double cap19EntryIconBottomInset() {
  return kMainBrowseScrubberReserveHeight + kCap19EntryIconAboveScrubberGap;
}
