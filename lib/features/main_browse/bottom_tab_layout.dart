/// Cap 27.6 / §11.4 bottom-tab shared metrics.
///
/// Change numbers here (and in `media-chrome-layout-notes.md` §11.4) before
/// forking values inside widgets.

/// Visual icon slot (all cells). Not the tap target — the full [Expanded]
/// cell / bar row remains the hit area.
const double kBottomTabIconSlot = 32;

/// Glyph size inside [kBottomTabIconSlot].
const double kBottomTabIconSize = 24;

/// Slot bottom → label top (all cells).
const double kBottomTabIconLabelGap = 4;

/// Label baseline band height (matches `labelOnMedia` size @ height 1.0).
/// Keeps 32 + 4 + 12 ≤ [WakeTokTokens.immersiveBottomBarHeight] (48).
/// Open note: that equality leaves zero **top** inset (flush icon top).
/// Bottom flush on zero-safe-area devices is handled separately by
/// [kBottomTabContentBottomPadWhenNoSafeArea] — do **not** raise the
/// global 48 content band for that.
const double kBottomTabLabelBandHeight = 12;

/// Extra pad under the 48pt content band when [MediaQuery.padding.bottom]
/// is 0 (home-button / SE class). Notched devices keep pad 0 — Home
/// Indicator already supplies visual clearance. Do **not** fold into
/// [WakeTokTokens.immersiveBottomBarHeight].
const double kBottomTabContentBottomPadWhenNoSafeArea = 6;

/// Order expand chevron size (matches [kBottomTabLabelBandHeight]).
const double kBottomTabExpandIconSize = 12;

/// Label ↔ chevron gap in the Order label row.
const double kBottomTabExpandGap = 2;

/// Browse outlined card stroke (24-design space). Must stay **>**
/// [kBottomTabActionSwapStroke].
const double kBottomTabBrowseOutlinedStroke = 1.65;

/// Order swap custom-paint stroke — thinner than Browse outlined
/// (Action vs Destination).
const double kBottomTabActionSwapStroke = 1.45;

/// Order swap shafts: distance between left/right centers in 24-design space.
/// Wider than a tight Material `swap_vert` so the glyph fills the slot more
/// like Settings.
const double kBottomTabActionSwapShaftGap = 9.0;
