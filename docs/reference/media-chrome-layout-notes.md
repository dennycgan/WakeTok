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
> - `lib/features/main_browse/cap25_share_entry_icon.dart` + `cap25_share_toast.dart`  
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
| **3 LIVE** | Live Photo status capsule trailing; Cap 26 long-press replay (no trailing button) | `vertical_media_feed.dart` `_LiveBadge` / `_FeedCornerChrome`; `Cap26LiveLongPressGesture` |
| **4 Action column** | Bottom-up: i=0 Cap 24 `"…"`; i=1 Cap 25 Share; i=2 Cap 19 album | `cap24_more_entry_icon.dart` / `cap25_share_entry_icon.dart` / `cap19_entry_icon.dart` |

**MVP exclusions (locked):**

- LIVE long-press replay (Cap 26 / ADR-052): media-area hold; **no** trailing
  control left of LIVE. Do not reserve horizontal space for a replay button.
- Overlay does **not** grow a Location (row 4). `locationLabel` may still exist on the snapshot for a **future** long-press half-sheet — do not re-enable Overlay row 4 without owner OK.

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

## 6. Zone 3 — LIVE status

Live Photo status pill (bottom-trailing). Cap 26 replay is **media-area
long-press** (ADR-052) — not a control leading of LIVE. Do **not** widen
`kStatusChromeReservedWidth` for a trailing replay button.

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
| Index 1 = Share | Cap 25 Share | `Cap25ShareEntryIcon` / `actionColumnBottomInsetForIndex(1, …)` |
| Index 2 = album | Cap 19 entry | `Cap19EntryIcon` / `actionColumnBottomInsetForIndex(2, …)` |
| Lowest **icon** bottom | = Reset visual bottom | see formula below |
| Index `i` bottom | `lowest + i×(48+16)` | `actionColumnBottomInsetForIndex` |

```
resetBottom = overlayBottom + 3×20 + kResetAboveMetaGap
iconCenterInset = (48 − 32) / 2 = 8
actionLowestBottom (Positioned) = resetBottom − 8
≈ 79.2 − 8 = 71.2   // with current overlayBottom ≈ 7.2
```

So the **visible** 32pt glyph bottom matches Reset; the 48pt hit extends 8pt below the icon.

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

## 12. Cap 24 / Cap 26 — "…" more half-sheet meta

> Not Overlay chrome. Lives in `cap24_more_half_sheet.dart` under the
> Cap 19-style sheet surface. Cap **26.5** Add-to-Album sits between
> Saved time and Delete (same outlined geometry as Delete; muted colors).

### 12.1 Row order (product)

| Order | Block | Behavior |
|------:|-------|-------------------|
| 0 | Grabber | Unchanged |
| 1 | **Location slot** | **Zero height** (`SizedBox.shrink`); content deferred (debt **401**). **Locked product home = this sheet, not Overlay row 4** — see **§12.6**. |
| 2 | **File size** | Title **always** shown. Value: blank while first request in flight; formatted bytes when known; em dash "—" when resolved ∧ nil/negative/failure. **Never omit** the row. |
| 3 | **Saved time** | Title + Cap 24 minute-landmark value + timezone `i`. Landmark miss / parse fail → **omit entire block** (title+value). |
| 4 | **Add to Album** | Cap **26.5**. Full-width `OutlinedButton` (48pt, radius 12) matching Delete geometry. Label = `cap19PanelAddToAlbumTitle`. Colors: `tokens.onMediaMuted` label; border `tokens.onMedia` × **0.4**. Typography: same `titleMedium` **size** as Delete, `FontWeight.w400` (Delete stays `titleChrome` w600) so the longer string does not dominate. Tap: Cap 23 gate → pop this sheet → next-frame `showCap19ActionsHalfSheet` (ADR-052 D9; `_addToAlbumLatch` anti-reentry). |
| 5 | Delete | Unchanged (destructive outline) |

### 12.2 Layout metrics (code constants)

| Symbol | Value | Role |
|--------|------:|------|
| Sheet padding | `fromLTRB(16, 8, 16, 24)` | Same as Cap 24.3 |
| Grabber → content | **16** bottom margin on grabber | Unchanged |
| `kCap24MoreSheetMetaBlockGap` | **16** | Between File size / Saved time / Add / Delete (and Location when it gains height) |
| `kCap24MoreSheetTitleValueGap` | **4** | Title → value inside a meta block (shared helper; same for File size + Saved time) |
| `kCap24MoreSheetTimezoneInfoHit` | **44** | Timezone `i` tap target; **OverflowBox** so it does not inflate the Saved-time value-line height (keeps optical title→value gap aligned with File size) |
| `kCap24MoreSheetTimezoneInfoLayoutWidth` | **36** | Width reserved in the value row for `i` |
| Title color | `tokens.onMediaMuted` via `bodySmall` | Meta titles |
| Value color | `tokens.onMedia` via `bodyMedium` | Size / Saved time values |
| Add to Album | `onMediaMuted` + `onMedia`×0.4 border | Cap 26.5; same min size / radius as Delete |
| Delete | `tokens.destructive` outline | Cap 24 |

### 12.3 File size reliability (Overlay parity + shared cache)

- Host: `presentationMetadataRepositoryProvider.requestPresentationFileSize`
  + `formatOverlayFileSize` (Overlay ARB size keys). Live = still-only
  (ADR-018). **Never** network solely for size.
- **Shared authority:** `presentationSizeCacheProvider` (per-asset
  `PresentationSizeEntry` with `resolved` + keepExisting `apply`). Overlay
  feed commits and the "…" sheet both read/write this map; Overlay UI still
  receives size via mirrored `_overlaySnapshot`.
- Open: request only when shared entry is missing / unresolved; if L2-ready
  is already true, may refresh when bytes are still null; listen `false→true`
  → refresh when bytes null; skip when non-null bytes already held.
- Differs from Overlay progressive blank join: half-sheet **keeps** title
  + reserved value slot from open (no spinner). `resolved ∧ nil` → "—".

### 12.4 Keys (tests)

| Key | Widget |
|-----|--------|
| `cap24MoreSheetLocationSlot` | Zero-height Location slot |
| `cap24MoreSheetFileSizeBlock` / `…Title` / `…Value` | File size |
| `cap24MoreSheetSavedTimeBlock` / `…Title` | Saved time chrome |
| `cap24SoftDeleteSheetMinuteLibrary` / `…Bare` | Landmark value (unchanged) |
| `cap24MoreSheetAddToAlbum` | Cap 26.5 Add to Album |
| `cap24SoftDeleteSheetDelete` | Delete |

### 12.5 Device check (after Cap 26.4 / 26.5)

1. Open "…" before L2 ready: File size title present; value blank then fills or "—".  
2. After L2 display ready (iCloud still): size refreshes to a non-empty SI label when local bytes exist.  
3. Missing landmark: no Saved time title; File size title still present.  
4. ZH: `文件大小` / `保存时间`; EN: `File size` / `Saved time`.  
5. Shared cache: after L2, Overlay row-3 size and half-sheet File size show the **same** formatted bytes.  
6. Cap **26.5**: Add sits above Delete, same size, muted outline (not red); tap closes "…" then opens Cap 19.  
7. `flutter test` Cap 24 / Cap 26.5 more-sheet tests + `test/architecture/`.

### 12.6 Location product home (locked — for a future implementer)

> Design note only. Cap 26.4 ships a **zero-height** slot (§12.1). This
> subsection records **where Location lives when content ships**, why, and
> what not to reopen. It is **not** a reverse-geocode implementation plan.

**Product home (locked):** Location belongs on the Cap 24 / Cap 26 **"…"
more half-sheet**, in the row-order slot already reserved first after the
grabber (ADR-052 **Decision 7** narrow amend: Location → File size →
Saved time → Add to Album → Delete). It does **not** belong on Overlay
row 4.

**Why half-sheet (and what the reason is not):**

- **Real blockers for Overlay:** (1) privacy disclosure for showing place
  names (Known debt **401** / kickoff ADR-X deferral); (2) Manual Browse
  **Bounded Visual Preheating** / passive look-ahead discipline (local
  kickoff: Manual doom-scroll may only use ADR-P.5 Bounded Visual
  Preheating; Auto-play is separately capped at One-item Lookahead Fetch).
  Overlay updates as the user swipes — a passive path. Putting reverse
  geocode there would fire a **network** place-name request for every
  geo-tagged asset the user merely scrolls past, which conflicts with
  that passive-preheat discipline. The half-sheet opens only on an
  explicit "…" tap, so geocode stays user-initiated and inside the safe
  zone of that discipline.
- **Not** “half-sheet was a fallback because Overlay was too hard.”
  Coordinate metadata on the asset is cheap; the expensive part is
  **reverse geocode** (a separate network call). That bottleneck is
  **not** the Cap 26.4 Size problem (whether local bytes exist at L1 /
  L2 for `requestPresentationFileSize`). Half-sheet does not inherit a
  Size-style “must be accurate the instant Browse opens” technical
  barrier for Location. Choosing the half-sheet is the stronger product
  fit, not a consolation prize.

**Do not move later:** Do **not** relocate Location content back to
Overlay row 4 because the half-sheet feels inconvenient, because geocode
UX is unfinished, or for “simpler” chrome alignment with Photos Info.
That Overlay home was considered and rejected; reopening it needs a new
owner decision that overturns ADR-052 D7 + this note — not a quiet
implementation shortcut.

**Cross-refs:** debt **401** (`docs/STATE.md` Known debt); ADR-052
Decision 7 (Location product home + zero-height slot + row order);
local kickoff Bounded Visual Preheating / One-item Lookahead Fetch
(Manual vs Auto-play fetch caps). Cap 8 Overlay still collapses empty
row 4 when `locationLabel` is unset — that remains presentation layout,
not a product claim that row 4 is Location’s home.

---

## 13. Cap 26.4a — Meta Overlay cover-gate (still L1→L2)

> Design note for feed still-cover ↔ Overlay mount gating.
> Not an ADR. Does **not** change Overlay MVP row count / field content
> (ADR-015 fixed three rows). Video poster→L2 is **Out** of this phase —
> debt **472** **Closed** (Kafka + i17): video L2 reuses L1 poster so the
> path-change clear-ready tear-down usually does not fire; keep-ready still
> excludes `kind == video`. Residual: if poster wiring later swaps files
> between L1 and L2, the same flash class can return (see STATE Known debt).

### 13.1 Problem

On iCloud stills, L2 often replaces the L1 cover **file path**. Cap 23.4
`_trackStillCoverPath` cleared `_stillCoverReady` on every path change, so
`_suppressStillCoverChrome` briefly removed the entire Meta Overlay
(row1–3 flash) even though Cap 15.5 `_ReloadableFileImage` already uses
`gaplessPlayback: true` (prior frame stays until the new decode).

### 13.2 Locked rule (Cap 26.4a)

When **all** of the following hold, do **not** clear `_stillCoverReady`
on path change:

- `_media?.kind == FeedPageMediaKind.still` (includes Live **static** frame)
- previous tracked path and new path are both non-null and different
- `_stillCoverReady` was already true
- `_stillCoverDecodeBroken` is false

Otherwise keep Cap 23.4 behaviour (clear ready → Overlay suppressed until
the next successful frame / broken handling).

**Explicitly unchanged:** decode-broken hide; first paint before any ready
frame; page / asset change; Overlay field progressive join; half-sheet §12;
video poster path tracking (debt **472** Closed — residual above).

**Do not** reopen Overlay row 4 or change Meta copy in this phase.

### 13.3 Code / tests

- Code: `vertical_media_feed.dart` `_trackStillCoverPath`
- Depends on: `_ReloadableFileImage` `gaplessPlayback: true` (Cap 15.5)
- Tests: `cap26_4a_meta_overlay_cover_upgrade_test.dart`
  (W-26.4a-keep / W-26.4a-switch / W-26.4a-broken)

---

*Update this file in the same docs commit whenever owner-visible chrome constants change.*
