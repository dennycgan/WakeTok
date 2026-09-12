# Media chrome layout — zones & parameters

> **Status:** Working snapshot. Media-area visual lock (owner device, 2026-09-05,
> work `81904e1`). **Browse shell** top/bottom chrome metrics added Cap 22.5
> polish (see §11; keep in sync with `browse_top_chrome.dart` /
> `main_browse_shell_page.dart`).  
> **Scope:**  
> - §§1–10 — Main Browse **media-area** chrome (not top source / bottom tab).  
> - §11 — Browse **shell** chrome (top four-control row + bottom tab bar).  
> **Not** Cap 20–specific — shared visual system. Cap 20 Reset / magnification sit *inside* this layout.  
> **Not** an ADR. Do **not** fold into ADR-043.  
> **Code anchors:**  
> - `lib/features/main_browse/media_chrome_layout.dart`  
> - `lib/features/main_browse/center_playback_affordance.dart` (derived bottom insets)  
> - `lib/features/main_browse/media_info_overlay.dart`  
> - `lib/features/main_browse/magnification_reset_button.dart`  
> - `lib/features/main_browse/cap19_entry_icon.dart` + `cap19_entry_layout.dart`  
> - `lib/features/main_browse/cap24_more_entry_icon.dart` + `cap24_more_half_sheet.dart`  
> - Cap 25 Share widget path — added 25.3 (no path until chrome lands)  
> - `lib/features/main_browse/vertical_media_feed.dart` (`_LiveBadge` / `_FeedCornerChrome`)  
> - `lib/features/main_browse/browse_top_chrome.dart` (shell top; §11)  
> - `lib/features/main_browse/main_browse_shell_page.dart` (shell bottom; §11)  
> - `lib/core/theme/waketok_tokens.dart` (`labelOnMedia`, `onMediaPillFill`, `mediaScrim`)  
> - Goldens: `test/features/main_browse/goldens/media_chrome_preview/` — local-only, manual maintenance required (no CI; see debt **449** for the repo-wide CI gap). After any chrome visual tweak, re-run `flutter test --update-goldens` on this machine and eyeball the diff before committing

**How to retune:** change the named constant / token in the table, then reinstall Profile and re-check the alignment row in §3 (media) or §11 (shell). Prefer editing constants over hard-coding numbers in widgets.

---

## 1. Four fixed zones

```
┌─────────────────────────────────────────────┐
│                                             │
│                    media                    │
│                                             │
│  ┌ Reset pill ─┐              ┌ actions ┐   │
│  │             │              │  album  │   │  ← i=2
│  └─────────────┘              │  share  │   │  ← i=1
│  row1 relative                │   …     │   │  ← i=0 lowest
│  row2 exact                   └─────────┘   │
│  row3 characteristics    ┌ LIVE (+ replay) ┐│
│  ──────── meta (3 rows, MVP) ───────────────│
│              scrubber / chrome band         │
└─────────────────────────────────────────────┘
```

| Zone | Role (MVP) | Primary files |
|------|------------|---------------|
| **1 Meta** | Fixed **3** rows bottom-leading: relative / exact / characteristics | `media_info_overlay.dart` |
| **2 Reset** | Magnification force-fit pill; visible only while still magnified | `magnification_reset_button.dart` |
| **3 LIVE** | Live Photo status capsule trailing; **future:** replay control to the **left** of LIVE | `vertical_media_feed.dart` `_LiveBadge` / `_FeedCornerChrome` |
| **4 Action column** | Bottom-up: i=0 Cap 24 `"…"`; i=1 Cap 25 Share (chrome lands 25.3); i=2 Cap 19 album | `cap24_more_entry_icon.dart` / Cap 25 Share widget (25.3) / `cap19_entry_icon.dart` |

**MVP exclusions (locked):**

- Overlay does **not** grow a Location (row 4). `locationLabel` may still exist on the snapshot for a **future** long-press half-sheet — do not re-enable Overlay row 4 without owner OK.
- LIVE replay control: **not implemented**; reserve horizontal space conceptually left of LIVE when designing later.

---

## 2. Alignment contracts (read these before changing numbers)

All vertical positions below are **feed-bottom insets** unless noted (larger = higher on screen).

| Contract | Meaning | Formula / constant |
|----------|---------|-------------------|
| Meta column bottom | Overlay padding bottom | `mainBrowseMediaOverlayBottomInset(tokens)` |
| Meta row-3 **text** bottom | Same as column bottom (glyphs **bottom-aligned** in each 20pt row) | row box bottom |
| LIVE capsule **outer** bottom | Align with meta row-3 text bottom | `mainBrowseLiveStatusBottomInset` ≡ overlay bottom inset |
| Reset visual bottom | `overlayBottom + 3×rowHeight + gap` | see §5 |
| Lowest action **icon** bottom (Cap 24 `"…"`) | Align with Reset visual bottom | `mainBrowseActionColumnLowestBottomInset` (hit box bottom = that − 8; see §7) |
| Reset ↔ meta gap | Reset bottom → Overlay row-1 **top** | `kResetAboveMetaGap` (**12**) |
| Leading content | Meta text left; Reset pill outer left | `kMediaChromeLeadingInset` (**16**) |
| Trailing chrome | Action + LIVE | `kMediaChromeTrailingInset` (**12**) |

**Derived Overlay trailing inset** (keep meta clear of right chrome):

```
kMediaChromeOverlayTrailingInset
  = max(trailing + actionHit, trailing + LIVE reserve) + clearance
  = max(12+48, 12+80) + 16
  = 108   // with current constants
```

**Overlay bottom inset** (ties meta to scrubber timestamp geometry; Cap 18.x):

```
timestampBottom = kScrubProgressTrackHeight + kMainBrowseScrubberTimestampAboveTrackGap
                = 4 + 6 = 10
lineHeight      = labelOnMedia.fontSize × height = 12 × 1.2 = 14.4
timestampCenter = 10 + 14.4/2 = 17.2
overlayBottom   = timestampCenter − rowHeight/2 = 17.2 − 10 = 7.2
```

If scrubber track / label metrics change, meta + LIVE + Reset + actions all move together via the helpers — do not patch one zone with a magic number.

**Guard test:** `test/features/main_browse/live_badge_meta_align_test.dart`  
(LIVE outer bottom ≈ Overlay row-3 bottom in a sibling Stack).

---

## 3. Shared typography (zones 1–3 labels)

Meta / Reset label / LIVE label all use **`WakeTokTokens.labelOnMedia`** (+ `onMediaLabelShadows` where noted).

| Field | Value | File |
|-------|-------|------|
| `fontSize` | **12** (`_labelOnMediaSize`) | `waketok_tokens.dart` |
| `fontWeight` | **w600** | same |
| `height` | **1.2** (meta, Reset); LIVE text uses **`height: 1.0`** inside the pill for optical centering | overlay / reset / `_LiveBadge` |
| `color` | `onMedia` white | token |
| `fontFamily` | unset → iOS system (SF) | — |

Changing meta size without changing Reset/LIVE will break the “same chrome type” lock — update all three on purpose.

---

## 4. Zone 1 — Meta (3 rows)

| Parameter | Value | Symbol / notes |
|-----------|-------|----------------|
| Row count (MVP) | **3** | `MediaInfoOverlay.baseRowCount` |
| Row height | **20** | `MediaInfoOverlay.rowHeight` |
| Column height | **60** | `columnHeightFor` always `3×20` (ignores `locationLabel`) |
| Leading | **16** | `kMediaChromeLeadingInset` |
| Trailing | **108** (derived) | `kMediaChromeOverlayTrailingInset` |
| Bottom | **~7.2** (derived) | `mainBrowseMediaOverlayBottomInset` |
| Text align in row | **bottomLeft** | so text bottom = row bottom = LIVE bottom |
| Copy | relative / exact / characteristics | Cap 8.5 formatters |

**To adjust:**

- Tighter/looser line stack → `rowHeight` (also moves Reset / actions / LIVE math).  
- Move whole block up/down → scrubber geometry helpers or accept changing `overlayBottom` formula.

---

## 5. Zone 2 — Reset pill

| Parameter | Value | Symbol / notes |
|-----------|-------|----------------|
| Show when | Still magnified only | `browseStillMagnifiedProvider` |
| Above meta gap | **12** | `kResetAboveMetaGap` |
| Bottom (visual) | `overlayBottom + 60 + 12` ≈ **79.2** | Reset `Padding.bottom` |
| Fill | mid gray ~80% | `tokens.onMediaPillFill` = `Color(0xCC6E6E6E)` L=D |
| Border | **none** (owner lock) | — |
| Horizontal pad | **10** | `kResetPillHorizontalPad` |
| Vertical pad | **7** | `kResetPillVerticalPad` (pill height) |
| Icon↔label gap | **5** | `kResetIconLabelGap` |
| Icon | `CupertinoIcons.arrow_clockwise` | **no** CustomPaint |
| Icon size | `fontSize + 2` → **≈14** when `labelOnMedia` is 12 | relative link; see note below |
| Icon weight | micro-offset stack (`_BoldCupertinoIcon`) | hairline Cupertino reads thin |
| Label | l10n `mainBrowseMagnificationReset` | `labelOnMedia` + shadows |
| Hit min | **44×44** | `kResetMinHitEdge`; visual pill may be shorter; use `IntrinsicWidth/Height` so hit does **not** expand full-feed |
| Leading of pill | **16** | same as meta; icon sits **inside** horizontal pad (not flush to pill edge) |

**Reset icon size (confirmed):** code uses **`fontSize + 2`** (not a literal `14`) so the glyph stays coupled to `labelOnMedia` / meta / LIVE type. With today’s `fontSize = 12`, device-confirmed visual height is **≈14**. That **supersedes** the earlier layout-spec lock of **28** (`kResetIconSize`); 14 is the owner-confirmed current value, not an accidental leftover. Further tweaks are device-first — keep this notes file in sync with code.

**To adjust:**

| Want | Change |
|------|--------|
| More space above meta | ↑ `kResetAboveMetaGap` (also lifts action column) |
| Taller/shorter pill | ↑↓ `kResetPillVerticalPad` |
| Roomier capsule | ↑ `kResetPillHorizontalPad` |
| Gray shade | `onMediaPillFill` in tokens (keep Color in theme only) |
| Icon size | change the `+ N` in `magnification_reset_button.dart` (keep relative to `fontSize`) |

---

## 6. Zone 3 — LIVE status (+ future replay)

| Parameter | Value | Symbol / notes |
|-----------|-------|----------------|
| Trailing | **12** | `kMediaChromeTrailingInset` |
| Bottom | = Overlay bottom ≈ **7.2** | `mainBrowseLiveStatusBottomInset` |
| Fill | `mediaScrim` × **0.78** | `kStatusChromeScrimOpacity` |
| Border | `onMedia` × **0.45**, width **1** | `kStatusChromeBorderOpacity` |
| Corner radius | **12** | `_LiveBadge` |
| Pad H / V | **8** / **5** | `_LiveBadge` |
| Dot | **8×8**, stroke **1.5** | centered in `fontSize` box |
| Dot↔LIVE gap | **6** | |
| Label | l10n `mainBrowseLiveBadge` | `labelOnMedia` with `height: 1.0` |
| Width reserve (overlay clear) | **80** | `kStatusChromeReservedWidth` |
| Above spinner (when wait chrome) | badge lifts by **8 + 16** | `kStatusChromeBadgeAboveSpinnerGap` + `_spinnerSize` |

**Future replay:** place control **leading** of LIVE on the same baseline; widen `kStatusChromeReservedWidth` / trailing formula if Overlay would collide.

**To adjust:**

| Want | Change |
|------|--------|
| Stronger shell on black | ↑ scrim opacity and/or border opacity |
| Move with meta | do **not** hard-code bottom — keep helper ≡ overlay inset |
| Content centering | pad V, label `height`, dot box |

---

## 7. Zone 4 — Action column (bottom-up)

| Parameter | Value | Symbol / notes |
|-----------|-------|----------------|
| Icon size | **32** | `kActionColumnIconSize` (layout lock; not related to old Reset icon 28) |
| Hit size | **48** | `kActionColumnHitSize` |
| Item spacing | **16** | between hit boxes (lower top ↔ upper bottom) |
| Trailing | **12** | `kMediaChromeTrailingInset` |
| Lowest = `"…"` | Cap 24 more | `Cap24MoreEntryIcon` / `mainBrowseActionColumnLowestBottomInset` |
| Index 1 = Share | Cap 25 Share | widget lands 25.3; `actionColumnBottomInsetForIndex(1, …)` |
| Index 2 = album | Cap 19 entry | `Cap19EntryIcon` → `actionColumnBottomInsetForIndex(2, …)` after 25.3 |
| Lowest **icon** bottom | = Reset visual bottom | see formula below |
| Index `i` bottom | `lowest + i×(48+16)` | `actionColumnBottomInsetForIndex` |

```
resetBottom = overlayBottom + 3×20 + kResetAboveMetaGap
iconCenterInset = (48 − 32) / 2 = 8
actionLowestBottom (Positioned) = resetBottom − 8
≈ 79.2 − 8 = 71.2   // with current overlayBottom ≈ 7.2
```

So the **visible** 32pt glyph bottom matches Reset; the 48pt hit extends 8pt below the icon.

**Cap 25.1 contract vs code:** Indices above are the ADR-051 locked layout.
Until Cap 25.3, product code may still place Cap 19 album at index 1 (Cap 24
ship). Do not “fix” notes back to album@1 — code catches up in 25.3.

**Deviation from earlier “keep bottom inset = 88” lock:** an earlier layout decision point said keep Cap 19’s fixed **`kActionColumnBottomInset = 88`** and not micro-tune it. During final device polish, tying the lowest action **icon** bottom to Reset (`resetBottom − 8`, ≈71.2 today) read better and keeps the column moving with meta/Reset instead of a second magic number. **This notes file records that deliberate override** — it was not the original plan; owner accepted it after on-device review (“大概满意”). Do not “restore 88” without a new owner pass.

**To adjust:**

| Want | Change |
|------|--------|
| Bigger/smaller glyphs | `kActionColumnIconSize` (revisit hit 48 / centering) |
| Tighter stack | ↓ `kActionColumnItemSpacing` |
| Move with Reset | change `kResetAboveMetaGap` or overlay math — column follows helper |

---

## 8. Constant quick index

### `media_chrome_layout.dart`

| Constant | Current |
|----------|---------|
| `kMediaChromeLeadingInset` | 16 |
| `kMediaChromeTrailingInset` | 12 |
| `kMediaChromeOverlayClearance` | 16 |
| `kStatusChromeReservedWidth` | 80 |
| `kActionColumnIconSize` | 32 |
| `kActionColumnHitSize` | 48 |
| `kActionColumnItemSpacing` | 16 |
| `kStatusChromeScrimOpacity` | 0.78 |
| `kStatusChromeBorderOpacity` | 0.45 |
| `kStatusChromeBadgeAboveSpinnerGap` | 8 |
| `kResetMinHitEdge` | 44 |
| `kResetAboveMetaGap` | 12 |
| `kResetPillHorizontalPad` | 10 |
| `kResetPillVerticalPad` | 7 |
| `kResetIconLabelGap` | 5 |

### Theme tokens

| Token | Current |
|-------|---------|
| `labelOnMedia` | 12 / w600 / height 1.2 / white |
| `onMediaPillFill` | `0xCC6E6E6E` (Reset gray) |
| `mediaScrim` | `0x99000000` (LIVE fill base) |
| `onMedia` | `0xFFFFFFFF` |

### Scrubber-linked (meta vertical anchor)

| Constant | Current |
|----------|---------|
| `kScrubProgressTrackHeight` | 4 |
| `kMainBrowseScrubberTimestampAboveTrackGap` | 6 |
| `MediaInfoOverlay.rowHeight` | 20 |
| `MediaInfoOverlay.baseRowCount` | 3 |

---

## 9. Owner locks (do not silently reopen)

1. MVP Overlay = **exactly 3 rows**. Hiding Location on Overlay is an **intentional MVP product decision**, not a bug or unfinished feature: richer fields (Location, etc.) belong in a **future long-press half-sheet**. `PresentationOverlaySnapshot.locationLabel` may still exist for that future path — **its presence does not mean Overlay row 4 will return**. Guard: `T-20.3-1` asserts `columnHeightFor` stays `3×rowHeight` even when `locationLabel` is set.  
2. Reset↔meta gap = **12**.  
3. Reset fill = **gray** (`onMediaPillFill`), **no** border; LIVE keeps **scrim + border**.  
4. Reset icon = **Cupertino** clockwise at **`fontSize + 2`** (≈14 today; not the old layout lock of 28); no one-off CustomPaint unless owner asks again.  
5. Action column icon size **32** / hit **48** accepted (independent of Reset glyph size).  
6. LIVE bottom ↔ meta last-line text bottom (helpers + bottom-aligned rows).  
7. Action column lowest icon follows Reset (formula), **not** the retired fixed `88` inset — see §7 deviation note.  
8. Competitor naming in git/docs: **Video-App-B** / **Photo-App-A** only.

---

## 10. Device check checklist (after any retune)

1. Black still + light still: Reset gray shell readable; LIVE shell readable.  
2. Magnified: Reset gap above row 1 feels like 12.  
3. Album icon bottom vs Reset bottom.  
4. LIVE outer bottom vs row-3 text bottom (Live Photo).  
5. **Longest realistic row-3 copy** (e.g. Live Photo label + file size via `mediaInfoCharacteristicsJoined`) must **not** collide with trailing LIVE / action chrome under the derived trailing inset (**108** today: was a hard-coded ~123 reserve; formula + 32/48 action + LIVE reserve must still clear on device).  
6. Run: `live_badge_meta_align_test`, Cap 20 still Reset tests (`T-20.3-1` included), `test/architecture/`.  
7. If chrome layout goldens under `media_chrome_preview/` changed: re-run `flutter test --update-goldens` on this machine and eyeball the diff before committing. These goldens are local-only / manual (no CI). Debt **449** is the repo-wide “no push CI for `flutter test`” gap — not a chrome-only debt.

---

## 11. Browse shell chrome (top four-control + bottom tab)

> Separate from §§1–10 media-area chrome. Still on-media / immersive; lives in
> the shell above/below the feed, not in the per-item Stack.

### 11.1 Glossary

| Term | Meaning |
|------|---------|
| **Top chrome / four-control row** | Cap 21.3 row: leading chip · Built-in · Saved · Create (`BrowseTopChrome`). |
| **Chip** | Leading pill control. Either **Temp Pool** (`_TempPoolChip`, parked ephemeral) or **Saved Pool** (`_SavedPoolChip`, active saved preset name). Not the center Built-in/Saved menus. |
| **Temp Pool chip** | Fixed short ARB label (`mainBrowseTempPoolChip`). Accent + surface pill while ephemeral is active; muted / no pill while parked but Built-in/Saved is current. |
| **Saved Pool chip** | Shows active saved `displayName` (ellipsis). Always surface pill + accent when shown. |
| **Built-in control** | Center-left dropdown: All / Photos / Videos (`_BuiltInControl`). Selected → accent + surface pill. |
| **Saved pools menu** | Center-right dropdown opener (`_SavedControl`); lists presets in an overlay. |
| **Create** | Trailing control (`_CreateControl`); opens Build a Pool cover. Disabled + helper line under Limited access. |
| **Center pair** | Built-in + Saved, screen-centered (`mainBrowseChromeCenterPair`). Chip show/hide must **not** translate this pair (Stack overlay). |
| **Covering route** | Full-screen Build cover; `browseCoveringRouteOpenProvider` + `PlaybackCoordinator.onBrowseCoverOpened` (user-intent pause). |
| **Bottom tab bar** | Browse / Clips / Auto / Settings (`_MainBrowseBottomBar`). Custom row — not Material 3 `NavigationBar`. |

### 11.2 Shared typography (shell labels)

**Canonical token for shell chrome labels:** `WakeTokTokens.labelOnMedia` (**12 / w600**, token default `height: 1.2`).

| | Top chrome (All / Temp / Saved / Create) | Bottom tab (Browse / Clips / …) |
|--|------------------------------------------|--------------------------------|
| Token | `labelOnMedia` | `labelOnMedia` (same) |
| Size | **12** | **12** |
| Weight | **w600** | **w600** |
| Runtime `height` | **`1.0`** via `copyWith` (optical center in fixed hit) | **`1.0`** via `copyWith` |
| Shadows | `onMediaLabelShadows` | none |
| Color | `accent` (selected / active chip) or `onMediaMuted` | `accent` / `onMediaMuted` |

**Historical note:** bottom once used `labelChrome` (token **14 / w500**, then locally overridden toward 11). Cap 22.5 polish **aligned bottom → top** (`labelOnMedia` + `height: 1.0` only). Do **not** reintroduce `labelChrome` on the bottom bar without an owner pass. Token `labelChrome` remains for other chrome surfaces (theme `labelLarge`).

**Code:**

- Top: `browse_top_chrome.dart` → `_chromeOnMediaLabelStyle` = `labelOnMedia.copyWith(inherit: false, height: 1.0, shadows: onMediaLabelShadows, color: …)` plus `TextHeightBehavior` (no first ascent / last descent).
- Bottom: `main_browse_shell_page.dart` → `tokens.labelOnMedia.copyWith(height: 1.0)` then `copyWith(color: …)` in `_BottomNavCell`.

### 11.3 Top chrome layout metrics

Constants in `browse_top_chrome.dart` (file-private; change there, then update this table):

| Symbol | Value | Role |
|--------|-------|------|
| `_kChromeControlHeight` | **32** | Fixed hit / pill height for Temp, Saved chip, Built-in, Saved menu, Create label |
| `_kChromeControlHPad` | **10** | Horizontal padding inside the hit |
| `_kSavedChipMaxWidth` | **112** | Saved chip ellipsis budget (second line of defense vs naming weight) |
| `_kChromeDropdownIconSize` | **16** | `Icons.arrow_drop_down` next to Built-in / Saved labels |
| Chrome band height | **52** (Create enabled) / **70** (Limited + Create helper) | `SizedBox` under `SafeArea` |

**Layout model:** `Stack` — center pair `Align(center)`; leading chip / Create `Positioned` + `Align` vertically centered in the band. Equal H pad + `Center` inside `_chromeControlShell` keep label (+ dropdown) geometrically centered in the 32pt hit.

**Selected / active fill:** `tokens.surface` @ **0.92** alpha; `BorderRadius.circular(16)`.

**Do not:** push the center pair sideways when the leading chip appears (owner lock — chip show/hide must not shift Built-in/Saved).

### 11.4 Related product limits (naming → chip)

Saved preset **display names** use a visual weight budget (domain `saved_pool_display_name.dart`): wide (EAW W/F, ideograph/kana/Hangul/fullwidth) ×3, else ×1, max **32**. Chip `maxWidth` 112 is independent UI truncation. IME composing is not weighed; over-budget commit/paste truncates to the longest in-budget **prefix**.

### 11.5 Shell device check (after retune)

1. ZH + EN: Temp/Saved chip, Built-in, Saved, Create share one optical baseline; Create not lower than center pair.  
2. Selected Built-in / active chip: label + dropdown (if any) centered in the gray pill.  
3. Chip appear/disappear: center pair `dx` unchanged (`cap22_4` / `cap21_3` chrome tests).  
4. Bottom tab labels match top weight/size at a glance (both `labelOnMedia`).  
5. `flutter test test/features/main_browse/cap21_3_browse_chrome_test.dart test/features/main_browse/cap22_4_saved_chrome_test.dart test/features/main_browse/main_browse_shell_test.dart test/architecture/`.

---

*Update this file in the same docs commit whenever owner-visible chrome constants change.*
