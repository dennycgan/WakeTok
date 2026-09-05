/// Shared Main Browse media-area chrome layout (meta / Reset / LIVE / actions).
///
/// Cross-Cap visual system — not Cap 20–specific. Documented in
/// `docs/acceptance/media-chrome-layout-notes.md`.
library;

import 'dart:math' as math;

// --- Shared edges -----------------------------------------------------------

/// Content leading edge: Overlay glyph left == Reset **icon** left.
const double kMediaChromeLeadingInset = 16;

/// Trailing edge for action column + status (LIVE) chrome.
const double kMediaChromeTrailingInset = 12;

/// Gap between Overlay copy and the right-hand chrome reserve.
const double kMediaChromeOverlayClearance = 16;

/// Approximate LIVE pill width reserve (circle + gap + “LIVE” + pads).
///
/// Used so Overlay trailing inset clears status chrome even when the action
/// column is narrower than the badge.
const double kStatusChromeReservedWidth = 80;

/// Overlay `padding.right` — max(action column, LIVE reserve) + clearance.
double get kMediaChromeOverlayTrailingInset {
  final actionExtent = kMediaChromeTrailingInset + kActionColumnHitSize;
  final statusExtent = kMediaChromeTrailingInset + kStatusChromeReservedWidth;
  return math.max(actionExtent, statusExtent) + kMediaChromeOverlayClearance;
}

// --- Action column (album now; share later) ----------------------------------

/// Visible action icon edge (owner lock Cap 20.6 layout: 32).
const double kActionColumnIconSize = 32;

/// Square hit target; icon centered (owner lock: 48).
const double kActionColumnHitSize = 48;

/// Gap between consecutive hit boxes: lower hit top ← upper hit bottom.
const double kActionColumnItemSpacing = 16;

/// Bottom inset for action index [i] above [lowestBottomInset] (0 = album).
double actionColumnBottomInsetForIndex(int i, double lowestBottomInset) {
  assert(i >= 0);
  return lowestBottomInset +
      i * (kActionColumnHitSize + kActionColumnItemSpacing);
}

// --- Status (LIVE) ----------------------------------------------------------

/// Scrim opacity for LIVE / status pills on dark feed (owner lock).
const double kStatusChromeScrimOpacity = 0.78;

/// Hairline onMedia border opacity on status pills (owner lock).
const double kStatusChromeBorderOpacity = 0.45;

/// Gap between LIVE badge bottom and spinner row top when both show.
const double kStatusChromeBadgeAboveSpinnerGap = 8;

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
