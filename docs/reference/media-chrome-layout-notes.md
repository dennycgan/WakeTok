# Media chrome layout — zones & parameters

> **Status:** Working snapshot. Media-area visual lock (owner device, 2026-09-05,
> work `81904e1`). **Browse shell** top/bottom chrome metrics added Cap 22.5
> polish (see §11; keep in sync with `browse_top_chrome.dart` /
> `main_browse_shell_page.dart`). Cap **26.4b** selected-capsule standard:
> §**11.3.1**; action-column disabled opacity: §**7.1** (Share lock **0.22**);
> top chrome Scheme **A** + Limited Saved mute / Create helper **8pt**: §**11.3**;
> media-area **text-bottom** lock (Meta row-3 ≡ scrubber timestamp): §**2**;
> Cap **26.4b** LIVE **top-leading** under Browse band (not bottom-trailing): §**2** / §**6**;
> Cap **27.6** bottom-tab Destination / Action roles + Browse two-card
> glyph (color-only selected; no Action shell): §**11.4**.  
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
> - `lib/features/main_browse/main_browse_shell_page.dart` (shell bottom; §11 / §11.4)  
> - `lib/core/theme/waketok_tokens.dart` (`labelOnMedia`, `onMediaPillFill`, `mediaScrim`)  
> - Goldens: `test/features/main_browse/goldens/media_chrome_preview/` — local-only, manual maintenance required (no CI; see debt **449** for the repo-wide CI gap). After any chrome visual tweak, re-run `flutter test --update-goldens` on this machine and eyeball the diff before committing

**How to retune:** change the named constant / token in the table, then reinstall Profile and re-check the alignment row in §3 (media) or §11 (shell). Prefer editing constants over hard-coding numbers in widgets.

---

## 1. Four fixed zones

```
┌─────────────────────────────────────────────┐
│  ┌ LIVE ┐  ← top: padding.top + band(52|70) + gap 0; left 8 (= Temp chip)
│                    media                    │
│                                             │
│  ┌ Reset pill ─┐              ┌ actions ┐   │
│  │             │              │  album  │   │  ← i=2
│  └─────────────┘              │  share  │   │  ← i=1
│                               │   …     │   │  ← i=0 (= Reset bottom)
│  gap 12                       └─────────┘   │
│  row1 relative                              │
│  row2 exact                                 │
│  row3 characteristics          ┌ spinner ┐  │  ← bottom-trailing; no LIVE lift
│  ──────── meta (3 rows, MVP) ───────────────│  ← text-bottom ≡ timestamp (10)
│         scrubber / resident timestamp band  │
└─────────────────────────────────────────────┘
```

| Zone | Role (MVP) | Primary files |
|------|------------|---------------|
| **1 Meta** | Fixed **3** rows bottom-leading: relative / exact / characteristics | `media_info_overlay.dart` |
| **2 Reset** | Magnification force-fit pill; visible only while still magnified | `magnification_reset_button.dart` |
| **3 LIVE** | Live Photo status capsule (**top-leading** in media Stack). Replay = Cap 26 media-area long-press (ADR-052) | `vertical_media_feed.dart` `_LiveBadge` / `_LiveBadgeTopLeading`; `Cap26LiveLongPressGesture` |
| **4 Action column** | Bottom-up: i=0 Cap 24 `"…"`; i=1 Cap 25 Share; i=2 Cap 19 album | `cap24_more_entry_icon.dart` / `cap25_share_entry_icon.dart` / `cap19_entry_icon.dart` |

**MVP exclusions (locked):**

- Live Photo replay is **media-area long-press only** (Cap 26 / ADR-052). LIVE
  chrome is the status capsule; there is no separate replay control in this zone.
- Overlay does **not** grow a Location (row 4). `locationLabel` may still exist on the snapshot for a **future** long-press half-sheet — do not re-enable Overlay row 4 without owner OK.

---

## 2. Alignment contracts (read these before changing numbers)

All vertical positions below are **feed-bottom insets** unless noted (larger = higher on screen).

| Contract | Meaning | Formula / constant |
|----------|---------|-------------------|
| Meta column bottom | Overlay padding bottom = **row-3 text bottom** | `mainBrowseMediaOverlayBottomInset` ≡ `mainBrowseScrubberTimestampBottomInset` (**10** today) |
| Meta row-3 **text** bottom | Same as column bottom (glyphs **bottom-aligned** in each 20pt row) | row box bottom |
| Scrubber resident timestamp **text** bottom | Track height + gap above track | `kScrubProgressTrackHeight` + `kMainBrowseScrubberTimestampAboveTrackGap` = **4 + 6 = 10** |
| LIVE **top** | Top-chrome band bottom + gap | `mainBrowseLiveBadgeTopInset` = `padding.top` + `browseTopChromeBandHeight` (**52**\|**70**) + `kLiveBadgeBelowTopChromeGap` (**0**) |
| LIVE **left** | Align with Temp/Saved chip left | `kLiveBadgeLeadingInset` (**8**) |
| Chip show/hide | Does **not** move LIVE | Same top/left (chip presence does not change geometry) |
| Wait spinner / “Still loading” row bottom | Same edge as Overlay/timestamp (no LIVE lift) | `_FeedCornerChrome` `statusBottom` ≡ `mainBrowseLiveStatusBottomInset`. Cap 26.4b: spinner gated by `_suppressStillCoverWaitChrome` (broken-only); Meta by `_suppressStillCoverMeta` |
| Reset visual bottom | `overlayBottom + 3×rowHeight + gap` | see §5 |
| Lowest action **icon** bottom (Cap 24 `"…"`) | Align with Reset visual bottom | `mainBrowseActionColumnLowestBottomInset` (hit box bottom = that − 8; see §7) |
| Reset ↔ meta gap | Reset bottom → Overlay row-1 **top** | `kResetAboveMetaGap` (**12**) — **relative contract; does not change when overlayBottom moves** |
| Leading content | Meta text left; Reset pill outer left | `kMediaChromeLeadingInset` (**16**) |
| Trailing chrome | Action column only (LIVE left top) | `kMediaChromeTrailingInset` (**12**) |

**Derived Overlay trailing inset** (keep meta clear of right chrome):

```
kMediaChromeOverlayTrailingInset
  = trailing + actionHit + clearance
  = 12 + 48 + 16
  = 76   // Cap 26.4b: LIVE no longer in trailing max()
```

**Overlay bottom inset (Cap 26.4b text-bottom lock):**

```
timestampBottom = kScrubProgressTrackHeight + kMainBrowseScrubberTimestampAboveTrackGap
                = 4 + 6 = 10
overlayBottom   = timestampBottom = 10
```

**Supersedes** the Cap 18.x “row-3 **box center** = timestamp **center**” formula
(`timestampCenter − rowHeight/2` ≈ 7.2). That centered the 20pt row box on the
timestamp mid-line while Meta glyphs are bottom-aligned, so row-3 **text** sat
~2.8pt below the resident timestamp. Contract is now **text bottom = text bottom**.

If scrubber track / gap metrics change, meta + Reset + actions + corner
wait chrome all move together via the helpers — do not patch one zone with a
magic number. LIVE top uses Browse band helpers (`mainBrowseLiveBadgeTopInset`),
not the scrubber/meta bottom edge. Do **not** retune timestamp geometry in the
same pass as a pure inset lock unless the owner reopens that scope.

**Guard tests:** `U-18.5-F1` (overlay bottom ≡ timestamp bottom);
`live_badge_meta_align_test.dart` (LIVE top ≡ band+gap **0**; left ≡ Temp leading **8**).

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
| Trailing | **76** (derived) | `kMediaChromeOverlayTrailingInset` (action only) |
| Bottom | **10** (derived) | `mainBrowseMediaOverlayBottomInset` ≡ timestamp text bottom |
| Text align in row | **bottomLeft** | so text bottom = row bottom = timestamp text bottom |
| Copy | relative / exact / characteristics | Cap 8.5 formatters |

**To adjust:**

- Tighter/looser line stack → `rowHeight` (also moves Reset / actions / LIVE math).  
- Move whole block up/down → change scrubber **timestamp bottom** inputs (track height / gap) or accept a new owner lock on `overlayBottom`; do **not** reintroduce center-vs-text mismatch.

---

## 5. Zone 2 — Reset pill

| Parameter | Value | Symbol / notes |
|-----------|-------|----------------|
| Show when | Still magnified only | `browseStillMagnifiedProvider` |
| Above meta gap | **12** | `kResetAboveMetaGap` (Reset bottom → Overlay **row-1 top**; relative lock) |
| Bottom (visual) | `overlayBottom + 60 + 12` = **82** today | Reset `Padding.bottom` (moves with overlayBottom) |
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

Live Photo status pill (**top-leading** in the media Stack — **not** a
`browse_top_chrome` / shell child). Cap 26 replay is **media-area long-press**
on the still (ADR-052); this zone is status chrome only.

| Parameter | Value | Symbol / notes |
|-----------|-------|----------------|
| Top | `padding.top` + band (**52**\|**70**) + **0** | `mainBrowseLiveBadgeTopInset` / `kLiveBadgeBelowTopChromeGap` |
| Left | **8** | `kLiveBadgeLeadingInset` (= Temp/Saved chip left) |
| Horizontal | **left**-aligned with Temp chip | Content-sized capsule; not centerX on Temp pill width |
| Band height | **52** Full / **70** Limited+Create helper | `browseTopChromeBandHeight` — **same** predicate as `BrowseTopChrome` |
| Chip show/hide | Does **not** move LIVE | Stable top + left (even when chip hidden) |
| Height / width | **Content-sized** | Pad H **8** / V **3** (`kLiveBadgeHorizontalPad` / `kLiveBadgeVerticalPad`); stadium follows content — **not** Temp 32 shell |
| Corner radius | Stadium (½ height) | `ShapeDecoration` + `StadiumBorder` (not `Material`; not Temp r16 shell) |
| Dot | **6×6**, stroke **1.25** | `kLiveBadgeDotSize` |
| Dot↔LIVE gap | **6** | `kLiveBadgeDotLabelGap` |
| Width | Content-adaptive | Dot + gap + “LIVE”; **not** Temp fixed pill width |
| Fill | `mediaScrim` × **0.55** | `kStatusChromeScrimOpacity` — **not** `surface@0.92` |
| Border | `onMedia` × **0.45**, width **1.0** | `kStatusChromeBorderOpacity` / `kStatusChromeBorderWidth` |
| Label | l10n `mainBrowseLiveBadge` | `labelOnMedia` with `height: 1.0` |
| Motion play | **Visible**, painted **above** Live PV | Stack: still → PV → spinner → LIVE (no hide; no PV peek) |
| Magnification | **Hidden** | `BrowseMagnificationState.hasActiveMagnification` (settled / transient pinch / still contact) |

**Retired (Cap 26.4b move):** bottom-trailing pin; `kStatusChromeReservedWidth`
in Overlay trailing `max()`; `badgeAboveSpinner` lift.

**To adjust:**

| Want | Change |
|------|--------|
| Closer/farther under top chrome | `kLiveBadgeBelowTopChromeGap` (**0** today) |
| CenterX on Temp pill width (retire left) | owner pass — was briefly tried then reverted |
| Tighter/looser content pad | `kLiveBadgeHorizontalPad` / `kLiveBadgeVerticalPad` |
| Stronger shell on media | ↑ scrim / border opacity (fill recipe stays separate from Temp surface) |

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
| **Disabled opacity** | **0.22** | Cap **26.4b** — see §7.1 |

```
resetBottom = overlayBottom + 3×20 + kResetAboveMetaGap
iconCenterInset = (48 − 32) / 2 = 8
actionLowestBottom (Positioned) = resetBottom − 8
= 82 − 8 = 74   // with overlayBottom = 10 (text-bottom lock)
```

So the **visible** 32pt glyph bottom matches Reset; the 48pt hit extends 8pt below the icon.

#### 7.1 Disabled / not-actionable icon standard (Cap 26.4b)

> **Canon:** Cap 25 Share not-tappable dim.  
> **Empty / no-item / not-actionable chrome** must match across the column —
> owner device: Cap 19 + Cap 24 looked brighter than Share at the old **0.38**.

**Sibling recipe (do not confuse):** Top-chrome Limited mute for **text /
dropdown** controls (Create / Saved menu) uses `onMediaMuted` @ **0.35**
alpha on the glyph color — **not** this `Opacity` **0.22** lock. See §**11.3**
and the §**11.1** glossary row. Icon column ↔ text/capsule are **two
independent disabled languages**; Clips (or any new surface) must pick by
control type, not copy the nearest number.

| Parameter | Locked value | Notes |
|-----------|--------------|-------|
| **Opacity** | **0.22** (`kActionColumnEntryIconDisabledOpacity`) | Single column lock. Aliases: `kCap19EntryIconDisabledOpacity`, `kCap25ShareEntryIconDisabledOpacity` |
| **Icon color** | `tokens.onMedia` | Unchanged vs enabled — do **not** switch to `onMediaMuted` for disabled |
| **Shadows** | `tokens.onMediaLabelShadows` | Same as enabled |
| **Mechanism** | Wrap hit in `Opacity` | Enabled = `1.0`; not-actionable / not tap-enabled = `0.22` |
| **Who** | Cap 19 album, Cap 25 Share, Cap 24 `"…"` | All three — empty source / not-actionable must look identical |

**Do not:** keep a second “softer” dim for outline glyphs (former Cap 19/24 **0.38**). Glyph shape (fill Share vs outline stack / ellipsis) may still read slightly differently at the same opacity; that is acceptable — opacity/color/shadow must match.

**Code:** `cap19_entry_layout.dart` (`kActionColumnEntryIconDisabledOpacity`); consumers in `cap19_entry_icon.dart`, `cap25_share_entry_icon.dart`, `cap24_more_entry_icon.dart`.

**Deviation from earlier “keep bottom inset = 88” lock:** an earlier layout decision point said keep Cap 19’s fixed **`kActionColumnBottomInset = 88`** and not micro-tune it. During final device polish, tying the lowest action **icon** bottom to Reset (`resetBottom − 8`, **74** today with text-bottom overlay) read better and keeps the column moving with meta/Reset instead of a second magic number. **This notes file records that deliberate override** — it was not the original plan; owner accepted it after on-device review (“大概满意”). Do not “restore 88” without a new owner pass.

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
| `kMediaChromeOverlayTrailingInset` | **76** (derived: 12+48+16) |
| `kBrowseTopChromeControlHeight` | 32 |
| `kBrowseTopChromeControlHPad` | 10 |
| `kBrowseTopChromeControlCornerRadius` | 16 |
| `kBrowseTopChromeBandHeightFull` | 52 |
| `kBrowseTopChromeBandHeightLimited` | 70 |
| `kLiveBadgeBelowTopChromeGap` | **0** |
| `kLiveBadgeLeadingInset` | 8 |
| `kActionColumnIconSize` | 32 |
| `kActionColumnHitSize` | 48 |
| `kActionColumnItemSpacing` | 16 |
| `kStatusChromeScrimOpacity` | **0.55** |
| `kStatusChromeBorderOpacity` | 0.45 |
| `kStatusChromeBorderWidth` | **1.0** |
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
6. LIVE **top** lock: band bottom + gap **0**; **left** **8** with Temp chip; **content-sized** `ShapeDecoration` stadium (not Material; not Temp 32 shell); spinner independent bottom-trailing; A2a honesty residual still §13.  
7. Action column lowest icon follows Reset (formula), **not** the retired fixed `88` inset — see §7 deviation note.  
8. Competitor naming in git/docs: **Video-App-B** / **Photo-App-A** only.

---

## 10. Device check checklist (after any retune)

1. Black still + light still: Reset gray shell readable; LIVE shell readable (top-leading).  
2. Magnified: Reset gap above row 1 feels like 12.  
3. Album icon bottom vs Reset bottom.  
4. LIVE top vs Browse band bottom + **0**; left **8** with Temp; Limited band **70** does not bury LIVE in Create helper.  
5. **Longest realistic row-3 copy** must **not** collide with action chrome under trailing inset (**76**).  
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
| **Temp Pool chip** | Fixed short ARB label (`mainBrowseTempPoolChip`). Accent + surface pill while ephemeral is active; muted / no pill while parked but Built-in/Saved is current. **Pill width** = label intrinsic + `_kChromeControlHPad`×2 (Cap **26.4b** canon for selected capsules). |
| **Saved Pool chip** | Same **fixed** Temp-Pool pill width/height; `displayName` replaces the Temp label (centered, ellipsis). Always surface pill + accent when shown. |
| **Built-in control** | Center-left dropdown: All / Photos / Videos (`_BuiltInControl`). Selected → accent + surface pill. |
| **Saved pools menu** | Center-right dropdown opener (`_SavedControl`); lists presets in an overlay. |
| **Create** | Trailing control (`_CreateControl`); opens Build a Pool cover. Disabled + helper line under Limited access. |
| **Center pair** | Built-in + Saved, screen-centered (`mainBrowseChromeCenterPair`). Chip show/hide must **not** translate this pair (Stack overlay). |
| **Covering route** | Full-screen Build cover; `browseCoveringRouteOpenProvider` + `PlaybackCoordinator.onBrowseCoverOpened` (user-intent pause). |
| **Bottom tab bar** | Cap 27: **Browse \| Order (action) \| Settings** (`main_browse_shell_page.dart`). Custom row — not Material 3 `NavigationBar`. Future Destination cells (e.g. Clips) must follow §**11.4**. |
| **Disabled / not-actionable** (two recipes) | **Do not mix.** (1) **Icon column** — §**7.1**: keep `onMedia`, wrap in `Opacity` **0.22**. (2) **Top-chrome text / dropdown / Limited Create·Saved** — §**11.3**: paint `onMediaMuted` @ **0.35** alpha on the label (no `Opacity` wrapper). Pick by control type: glyph icon vs text/capsule. |

### 11.2 Shared typography (shell labels)

**Canonical token for shell chrome labels:** `WakeTokTokens.labelOnMedia` (**12 / w600**, token default `height: 1.2`).

| | Top chrome (All / Temp / Saved / Create) | Bottom tab (Browse / Order / Settings; §11.4) |
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

Constants for band height / control height / H pad / corner radius live in
`media_chrome_layout.dart` (**shared** with feed LIVE skeleton). Cap **26.4b**
freezes the **selected capsule** recipe below so later surfaces (e.g. Clips
chrome) can copy it without re-deriving. LIVE is **not** one of the four top
controls — it only **reads** these metrics for top-leading alignment.

| Symbol | Value | Role |
|--------|-------|------|
| `kBrowseTopChromeControlHeight` | **32** | Fixed hit / pill **height** (Temp, Saved chip, Built-in, Saved menu, Create label) |
| `kBrowseTopChromeControlHPad` | **10** | Horizontal padding inside the hit (left + right) |
| `kBrowseTopChromeControlCornerRadius` | **16** | Full-capsule radius for height-32 pills |
| `_chromeTempPoolPillWidth` / `browseTempPoolPillWidth` | see §11.3.1 | Cap **26.4b** fixed pill **width** (Temp/Saved/Built-in selected) |
| `_kChromeDropdownIconSize` | **16** | `Icons.arrow_drop_down` next to Built-in / Saved labels |
| `browseTopChromeBandHeight` | **52** (Full) / **70** (Limited + Create helper only) | `SizedBox` under `SafeArea`. **No** third tier — L1 dual-row + Open Settings deferred (debt **421**). Feed LIVE top uses the same helper. |
| Leading chip inset / `kLiveBadgeLeadingInset` | **8** | `Positioned(left: 8)` for Temp / Saved chip **and** LIVE |
| Create inset | **8** | `Positioned(right: 8)` |
| Center-pair gap | **12** | Between Built-in and Saved menu |
| Create Limited helper font | **8** | `_kCreateRequiresFullAccessFontSize` (Cap **26.4b** L2; was 9) |
| Limited mute (Create / Saved menu) | `onMediaMuted` @ **0.35** alpha | Text/dropdown recipe — **not** §7.1 icon `Opacity` **0.22**. Saved has **no** caption |

**Disabled-language cross-ref:** §**7.1** (action-column icons) and this Limited mute are **independent**. Do not apply 0.22 `Opacity` to top-chrome labels, and do not paint action icons with `onMediaMuted`@0.35. Glossary: §**11.1**.

**Layout model (Scheme A — Cap 26.4b lock):** `Stack` —

1. **Center pair** (Built-in + Saved): `Align(center)` — **screen geometric center**; gap **12**. Primary permanent controls.
2. **Leading chip** (Temp / Saved name): `Positioned(left: 8)` wing.
3. **Create**: `Positioned(right: 8)` wing.

Chip show/hide must **not** translate the center pair. Equal H pad + `Center` inside `_chromeControlShell` keep label (+ dropdown) geometrically centered in the 32pt hit. Fixed-width shells ellipsize overflow (`TextOverflow.ellipsis`); dropdown rows use `Flexible` on the label when the shell is fixed-width.

**Not a goal:** equal horizontal gaps among all four visible elements (wings pin to edges; center pair stays fixed).

**Limited Create helper (Cap 26.4b L2):** `_CreateControl` is a `Stack(clipBehavior: Clip.none)` whose **layout size is only the Create hit** (32). `Requires Full Access` is `Positioned(top: _kCreateRequiresFullAccessTop = **24**, right: 10)` under Create — **fontSize 8**, `TextAlign.end` so the helper’s **right edge matches the Create label** right edge. Longer EN copy may still extend left toward Saved; 8pt reduces intrusion but does **not** promise zero overlap. Band height stays **70**. Create label baseline matches Full Access / the center pair.

**Limited Saved pools menu (Cap 26.4b L2):** same mute as Create (`onMediaMuted` @ 0.35); **untappable**; **no** helper/caption under Saved (avoids a second long string fighting Create’s helper). Root cause for not browsing album-backed Saved under Limited: **ADR-021 Decision 3** (album/smartAlbum resolve → unauthorized). When access becomes Limited while origin is Saved, chrome calls `leaveSavedOriginForLimitedAccess()` → `lastRememberedBuiltIn`.

**Follow-up (out of scope this polish):** Temp / ephemeral pools that still contain album refs under Limited hit the same ADR-021 D3 failure mode — not disabled in this change; revisit with a dedicated Limited/pool honesty pass (not Misc polish).

**Do not:** push the center pair sideways when the leading chip appears (owner lock — chip show/hide must not shift Built-in/Saved). **Also do not:** let Built-in drop to intrinsic width when unselected — that is a different failure mode with the same product symptom (Built-in/Saved jump).

#### 11.3.1 Selected capsule standard (Cap 26.4b — copy for Clips / new chrome)

> **Canon name:** Temp-Pool selected pill.  
> **Code today:** `browse_top_chrome.dart` — `_chromeTempPoolPillWidth`,
> `_chromeControlShell(width:)`, `_chromeOnMediaLabelStyle`.  
> These identifiers are **Dart library-private** (leading `_`): they are
> visible **only inside** `browse_top_chrome.dart`. Clips / other features
> **cannot** import or call them. Until a shared helper exists, “reuse”
> means **re-implement from this table’s numbers/formula** (duplicate the
> recipe in the new file). True call-site reuse starts only after extraction.
>
> **Extraction target (when owned):** `lib/core/` (ADR-009: `core` must not
> import `features`; any feature may import `core`). The shared helper must
> stay **presentation-only** — tokens, strings, sizes, styles. It must **not**
> take Browse providers, Browse origin/chrome types, or other feature-domain
> dependencies (otherwise the extract fails architecture guards mid-flight).
> Prefer parameters like label `String` + `WakeTokTokens` / `TextStyle`, not
> `AppLocalizations` or `BrowseChromeState`.
>
> **Reuse scope:** this § freezes the **capsule component** only (geometry +
> typography + fill). It does **not** license copying top-chrome **Scheme A**
> (center-pair + pinned wings Stack) onto Clips or any new shell. Reusing that
> **layout mode** is a separate owner design call — do not treat Scheme A as
> part of this capsule contract.

| Parameter | Locked value / formula | Notes |
|-----------|------------------------|-------|
| **Height** | **32** (`_kChromeControlHeight`) | Outer hit = visual pill height |
| **Width** | `TextPainter(mainBrowseTempPoolChip).width + 2 × 10` | Locale-dependent. Reference EN ≈ **128** (`Temp Pool` text ≈ 108 + pad 20). Do **not** hard-code 128 — remeasure via the Temp ARB string + style. |
| **H pad** | **10** each side | Inside the 32pt shell |
| **Corner radius** | **16** (`BorderRadius.circular(16)`) | Full capsule |
| **Fill (selected / active)** | `tokens.surface` @ **0.92** alpha | Unselected Built-in / parked Temp: **transparent** (no fill) |
| **Label token** | `WakeTokTokens.labelOnMedia` | Size **12**, weight **w600** |
| **Label runtime** | `copyWith(inherit: false, height: 1.0, shadows: onMediaLabelShadows, color: …)` | + `TextHeightBehavior` (no first ascent / last descent) |
| **Label color** | `tokens.accent` when selected/active; `tokens.onMediaMuted` when parked/unselected | |
| **Overflow** | `TextOverflow.ellipsis`, `maxLines: 1`, **centered** (`TextAlign.center`) | Longer Saved names / Built-in+▾ stay inside the Temp width |
| **Dropdown icon** (Built-in only) | **16** pt, same color as label; label in `Flexible` when shell is fixed-width | EN Videos+▾ ≈ **108** &lt; Temp **128** — fits without ellipsis (owner-verified class) |

**Who must use this capsule today**

| Control | When filled | Width |
|---------|-------------|-------|
| Temp Pool chip | Ephemeral active | Fixed Temp width (**always** — parked unselected is transparent fill, same shell) |
| Saved Pool chip | Saved origin current | **Same** fixed width; string = `displayName` only |
| Built-in (All / Photos / Videos) | `highlightAsSelected` → fill; else transparent + muted | **Same** fixed Temp width **always** (selected **and** unselected). Do **not** use intrinsic / content-sized width when unselected — that shrinks the center-pair `Row` and shifts Built-in + Saved on screen while `Align` keeps the Row center fixed (owner-confirmed jump when opening Saved / leaving Built-in). Label+▾ stay **centered** in the shell (`expandLabel: true` + ellipsis). |

**Reuse checklist (Clips / future)**

1. Height **32**, H pad **10**, radius **16**, fill `surface@0.92`.  
2. Width = **Temp Pool ARB** (or equivalent width-budget string) intrinsic under the **label runtime recipe in the table** + **20** — not content-sized, not a magic constant. Do **not** call `_chromeOnMediaLabelStyle` / `_chromeTempPoolPillWidth` from another file (library-private).  
3. Label = `labelOnMedia` recipe above; replace text only; center + ellipsis.  
4. Do not invent a second “short name” pill geometry.  
5. Do **not** assume Scheme A top-chrome Stack is in scope — capsule only (§ above).  
6. When extracting to `lib/core/`: presentation-only API; update this §; keep ADR-009 green.

**Cap 26.4b lock:** Leading Saved name must not invent a different pill geometry than Temp — only the string changes (centered). Short names (e.g. `"W"`) stay in the Temp-sized capsule; they must not grow a wider pill that overlaps Built-in.

### 11.4 Bottom tab cell roles (Cap 27.6 — ADR-055)

> **Status:** Spec **re-locked** 2026-09-20 after device review of the
> first polish build (owner: Browse **A** / Action **no-shell** /
> selected = **color only**; candidates in
> `docs/reference/cap27-bottom-tab-candidates/`).  
> **Supersedes** the earlier §11.4 draft that specified Destination
> selected fill + Action hairline capsule (those produced a circular
> “sticker” on 32×radius-16 and failed aesthetic review).  
> **Code target:** `main_browse_shell_page.dart` +
> `browse_card_stack_icon.dart` + `bottom_tab_layout.dart`.  
> **Rule:** every bottom-bar cell declares **Destination** or **Action**
> before styling. New cells (e.g. future Clips) **must** reuse this
> section — no one-off metrics.

#### 11.4.1 Roles

| Role | Examples | Selected fill / shell? | How it differs |
|------|----------|------------------------|----------------|
| **Destination** | Browse, Settings; future Clips | **Neither** — selected = **color only** (`accent` vs `onMediaMuted`); glyph may switch outlined→filled | Equal **32** slot geometry; no capsule behind the icon |
| **Action** | Order (order sheet); future Layer-3 listen if it keeps this slot | **Never** selected fill (ADR-055 D2); **no** stroke capsule | Same **32** slot; glyph = thinner `swap_vert` (see §11.4.4) |

Action must remain readable as “not a third destination” via **glyph
language** (thinner swap + order label + expand), not via a wrapping
container. Do **not** reintroduce a 32×radius-16 stroke capsule (that
math draws a circle and read as ornament on device).

#### 11.4.2 Shared metrics

| Symbol | Value | Role |
|--------|-------|------|
| `kBottomTabIconSlot` | **32×32** | Visual icon slot (all cells). **Not** the tap target — the full `Expanded` cell / bar row remains the hit area (≥ system min). |
| `kBottomTabIconSize` | **24** | Glyph size inside the slot |
| `kBottomTabIconLabelGap` | **4** | Slot bottom → label top (all cells) |
| `kBottomTabLabelBandHeight` | **12** | Label baseline band (= `labelOnMedia` size @ height 1.0) |
| `kBottomTabLabelStyle` | `labelOnMedia` + `height: 1.0` | Same as §11.2 |
| `kBottomTabExpandIconSize` | **12** | Order expand chevron (same as label band) |
| `kBottomTabExpandGap` | **2** | Label ↔ chevron |
| `kBottomTabActionIconStroke` | **thinner than Destination** | Order `swap_vert` optical weight — see §11.4.4 |

**Removed from this lock:** `kBottomTabCapsuleRadius` / Destination
selected fill / Action hairline shell (owner 2026-09-20).

**Open layout note (do not “fix” in the UI polish pass):**  
`32 + 4 + 12 = 48` exactly equals `immersiveBottomBarHeight` (**48**), so
with a centered column the icon-slot **top is flush** with the content
band top (zero top/bottom inset). Recorded for a later retune
(shrink slot / raise bar / add inset) — **not** in scope of the glyph /
Action visual re-lock above.

#### 11.4.3 Destination appearance

| State | Behind icon | Icon / label |
|-------|-------------|--------------|
| Selected | **None** (no fill, no circle, no pill) | Color `accent`; Browse uses **filled** glyph; Settings uses filled Material settings |
| Unselected | **None** | Color `onMediaMuted`; Browse **outlined** glyph; Settings outlined |

Colors come only from `Theme.of` → `WakeTokTokens` (`accent` /
`onMediaMuted`). No hard-coded brand hex in the nav glyph.

#### 11.4.4 Action appearance (no shell)

| Property | Value |
|----------|-------|
| Slot | Same **32×32** as destinations (alignment only — empty chrome) |
| Container | **None** — no fill, no stroke capsule |
| Icon | Custom `swap_vert` at **24**, stroke **visibly thinner** than Browse outlined but raised toward Settings gear weight (implementation: `kBottomTabActionSwapStroke` ≈ **1.9** vs Browse outlined ≈ **2.25**; shaft gap `kBottomTabActionSwapShaftGap` ≈ **9**; tune on device) |
| Icon / label color | `onMediaMuted` always (never `accent` selected fill) |
| Label row | Order copy + expand **12** (§11.4.6) |

#### 11.4.5 Browse glyph (Browse **B** — vertical front + peek UL)

Replaces Material `home` / `home_outlined`. Motif from
`cap27-bottom-tab-candidates` **Browse B** (single + peek), corrected on
device: peek **upper-left** (brand-aligned; original B had peek UR), front
**larger + vertical**, outlined overlap **occluded** (front covers peek —
no crossed strokes in the overlap).

| | Spec |
|--|------|
| Motif | Large **vertical** front card + smaller peek card upper-left |
| **Omit** | Peek upper-right; third card; waveform; moon; doom-scroll arrows; Destination circular wash |
| Outlined (unselected) | Stroke-only; peek drawn **outside** front only (clip / occlusion); `kBottomTabBrowseOutlinedStroke` ≈ **2.25**; color `onMediaMuted` |
| Filled (selected) | Same geometry; front solid `accent`, peek same hue ~0.45 alpha under front; **no** circular wash |
| Forbidden | Multi-stop brand SVG (`#FC2555` / `#E0C590` baked in) as the nav glyph |

Order keeps thinner `swap_vert`. Browse = vertical front + UL peek only.

#### 11.4.6 Label row + expand

- One label baseline band under the slot for all cells (**12** high =
  `kBottomTabLabelBandHeight`).
- Order chevron sits **in the label row**, not the icon slot; size **12**
  (`kBottomTabExpandIconSize` — same as the band).
- Long order copy: `FittedBox.scaleDown` on the **label text only** (SE
  width). Do **not** wrap the whole label+chevron row in a vertical
  `FittedBox` — that squashes Order copy below Browse/Settings.

#### 11.4.7 Reuse (Clips / v2 listen)

1. Label the cell Destination or Action.  
2. Apply §11.4.3 or §11.4.4.  
3. Clips returns as **Destination** (color-only selected; no capsule).  
4. If Order’s **content** becomes Layer-3 listen, keep **Action** rules
   (no shell; distinct glyph weight); swap glyph/copy only.  
5. Change numbers here first, then code — no widget-local forks.

#### 11.4.8 Regression before Cap 27.6 matrix

| ID | Check |
|----|--------|
| R-SE | `COPY-1` SE width + chevron |
| R-DT | Large textScale sheet / bar |
| R-ALIGN | Device: slot centers + label baseline; Action has **no** circle/capsule; selected Destination = color only |
| R-GLYPH | Browse outlined readable as two cards (not scribble); Action swap thinner than Settings gear |

### 11.5 Related product limits (naming → chip)

Saved preset **display names** use a visual weight budget (domain `saved_pool_display_name.dart`): wide (EAW W/F, ideograph/kana/Hangul/fullwidth) ×3, else ×1, max **32**. Chip UI truncation is the fixed Temp-Pool pill width (Cap 26.4b), independent of that naming budget. IME composing is not weighed; over-budget commit/paste truncates to the longest in-budget **prefix**.

### 11.6 Shell device check (after retune)

1. ZH + EN: Temp/Saved chip, Built-in, Saved, Create share one optical baseline; Create not lower than center pair. **Limited:** Create still shares that baseline; helper sits under Create without shifting it (**W-26.4b-2**).  
2. Selected Built-in / active chip: label + dropdown (if any) centered in the gray pill; All / Photos / Videos pills **same width** as Temp.  
3. Saved short name (e.g. `"W"`): pill width equals Temp; does not cover Built-in.  
4. Chip appear/disappear: center pair `dx` unchanged (`cap22_4` / `cap21_3` chrome tests).  
5. Bottom tab labels match top weight/size at a glance (both `labelOnMedia`); after Cap 27.6 polish also check §**11.4** (two-card Browse, Action **no** shell, selected = color only; flush-top note still open).  
6. `flutter test test/features/main_browse/cap21_3_browse_chrome_test.dart test/features/main_browse/cap22_4_saved_chrome_test.dart test/features/main_browse/main_browse_shell_test.dart test/architecture/` (includes **W-26.4b-1**, **W-26.4b-2**).

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
`_suppressStillCoverMeta` briefly removed the entire Meta Overlay
(row1–3 flash) even though Cap 15.5 `_ReloadableFileImage` already uses
`gaplessPlayback: true` (prior frame stays until the new decode).

**Cap 26.4b:** corner wait spinner + LIVE use a **separate** gate
`_suppressStillCoverWaitChrome` (decode-**broken** only). Unresolved cover
(no first frame yet) still hides Meta but **keeps** spinner/LIVE when wait
policy would already show them — avoids suppress tearing the spinner off LIVE.

**Cap 26.4b A2a (force spinner):** when cover is unresolved **and** Host work
is outstanding (`_layer2InFlight || _livePreparing`), force the corner spinner
even if wait-chrome &lt;T (still a2 G) or Live prepare F1 would suppress. This
closes the miss→media “LIVE-alone on black” handoff when a real request is
in flight. **Known accepted residual (honesty):** `unresolved ∧ !_layer2InFlight
∧ !_livePreparing` deliberately does **not** force a spinner — no Host work,
no fake busy chrome (same attitude as ADR-015 nil honesty). Not an oversight;
revisit only if that narrow combo is seen as product-visible without either
flag.

### 13.2 Locked rule (Cap 26.4a)

When **all** of the following hold, do **not** clear `_stillCoverReady`
on path change:

- `_media?.kind == FeedPageMediaKind.still` (includes Live **static** frame)
- previous tracked path and new path are both non-null and different
- `_stillCoverReady` was already true
- `_stillCoverDecodeBroken` is false

Otherwise keep Cap 23.4 behaviour for **Meta** (clear ready → Overlay
suppressed until the next successful frame / broken handling). Wait chrome
follows Cap 26.4b (broken-only).

**Explicitly unchanged:** decode-broken hide of Meta + wait chrome + LIVE;
first paint before any ready frame (Meta only); page / asset change; Overlay
field progressive join; half-sheet §12; video poster path tracking (debt
**472** Closed — residual above). F1 &lt;T Live-prepare suppress (ADR-034/037)
is out of Cap 26.4b gate split.

**Do not** reopen Overlay row 4 or change Meta copy in this phase.

### 13.3 Code / tests

- Code: `vertical_media_feed.dart` `_trackStillCoverPath`
- Depends on: `_ReloadableFileImage` `gaplessPlayback: true` (Cap 15.5)
- Tests: `cap26_4a_meta_overlay_cover_upgrade_test.dart`
  (W-26.4a-keep / W-26.4a-switch / W-26.4a-broken)

---

*Update this file in the same docs commit whenever owner-visible chrome constants change.*
