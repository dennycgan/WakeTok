# First-launch Browse guidance — logic & UI parameters

> **Status:** Working snapshot (Cap 30 + Cap 19 left-swipe coach).  
> **Not an ADR.** Contract freeze lives in ADR-060 +
> `docs/acceptance/cap30-30.1-notes.md`. This file is the day-to-day
> maintenance sheet for chrome logic and visual knobs.  
> **Keep in sync with code** when retuning icons / surface / placement.

## Scope

| ID | Role | Code |
|----|------|------|
| `<1>` | Vertical up/down coach (install once, chain start) | `cap30_vertical_hint_guide.dart` |
| `<2>` | Create Pool anchored tip (chain middle) | `cap30_create_pool_tip.dart` |
| `<3>` | Left-swipe coach (every cold start when Cap 30 allows) | `cap19_left_swipe_guide.dart` |

Shared icons: `browse_first_launch_coach_icons.dart`.  
Shared surface + **swipe-direction arrow size**: `cap19_entry_layout.dart`
(`browseCoachSheetFill`, `kBrowseFirstLaunchSwipeDirectionArrowSize`).

## Architecture — what is bound, what is independent

### Cap 30 install-once chain (`<1>` + `<2>` …)

**Product:** one **first-install** guidance chain (ADR-060). Steps run in
order, never stacked, progress persisted on disk until the v1 chain
completes.

**Implementation:** still **one step = one chrome Host + one duration
constant**. The binding is the shared orchestrator + disk step index —
not a single mega-widget.

| Piece | Role |
|-------|------|
| Disk step | `waketok.cap30.firstLaunchGuideStep` → `0\|1\|2\|3` today (D5) |
| Orchestrator | `Cap30FirstLaunchGuideOrchestrator` — begins / ends chrome, serial queue |
| Step order list | `kCap30FirstLaunchStepOrder` — ordered chrome kinds |
| Chrome enum | `Cap30GuideChromeKind` — which tip may paint |
| Duration map | `cap30GuideChromeDuration` + per-step `kCap30*Duration` constants (**P3**) |
| Ready sync | **Only** `Cap30VerticalHintGuideHost` calls `syncCap30BrowseReady` |

Today: `<1>` = `verticalHint`, `<2>` = `createPoolTip`. Completing `<2>`
writes disk **`3`** (`kCap30GuideStepComplete`).

### Cap 19 left-swipe (`<3>`) — independent

| | Cap 30 chain | `<3>` left-swipe |
|-|--------------|------------------|
| Cadence | Once per **install** (SP) | Once per **cold start** (process memory) |
| Storage | Cap 30 step KV | Cap 19 Settings toggles + `Cap19LeftSwipeGuideSession` |
| Orchestrator | Cap 30 orch | Cap 19 Host + arbitration |
| Duration | Cap 30 per-step constants | `kCap19LeftSwipeGuideDuration` (**2.5s**) |

**Link only via D6 gate:** while Cap 30 chain is active / armed, `<3>` is
blocked. After disk `3` (and arm cleared for the path), Cap 19 may show.
Do **not** put `<3>` into `kCap30FirstLaunchStepOrder`.

**Not `<3>`:** Cap 22.5 “starting over” Browse toast (**1.5s**,
`kCap19BrowseToastDuration`) — Settings Browse-notifications copy; unrelated
coach.

### Where to add a future first-launch step (e.g. clips)

ADR-060 **D8**: ordered step list; clips tip **reserved, not built**. When
a new **install-once** Browse tip ships:

1. **Append** a new `Cap30GuideChromeKind` value (e.g. `clipsTip`).
2. **Append** it to `kCap30FirstLaunchStepOrder` in the product order
   (default after Create tip unless owner reorders).
3. Add **`kCap30…Duration`** + a branch in `cap30GuideChromeDuration` (**P3**).
4. Add a Host under `lib/features/main_browse/` that **observes** orch /
   epoch only — **must not** call `syncCap30BrowseReady`.
5. Wire `_maybeBeginStep` / `_completeActiveStepAndAdvance` for the new
   chrome (same pattern as `<1>` → `<2>`).
6. Apply **P1** / **P2** if the tip uses swipe-direction arrows / coach
   fill; document knobs in this file.
7. **Revisit disk complete value:** today `3` means “v1 `<1>+<2>`
   finished”, **not** “all future tips finished”. Adding clips needs an
   explicit migration plan (bump complete watermark and/or remap stored
   `3`) — called out in `cap30_first_launch_guide_logic.dart` header.

### Uninstall → App Store reinstall (persistence)

**Yes — the Cap 30 chain runs again** after the user deletes WakeTok and
reinstalls from the App Store (or TestFlight).

| Fact | Detail |
|------|--------|
| Store | `SharedPreferences` only — key `waketok.cap30.firstLaunchGuideStep` (`Cap30FirstLaunchGuidePreferencesStore`) |
| Missing key | `getStep()` → **`0`** → `_maybeBeginStep` starts `<1>` |
| Survive delete? | **No.** iOS removes the app container (UserDefaults / SP). No Keychain, no iCloud KVS, no other durable store for this step |
| Arm flag | `chainArmedThisLaunch` is process memory — also gone |

**Not the same as:** updating the app in place (SP kept → if disk already
`3`, chain does **not** replay).  
**Edge (rare):** full-device backup/restore can bring SP back with the
backup; that is not “delete app → reinstall”.

**Do not** fold every-cold-start or Settings-gated tips into this chain
unless product explicitly reclassifies them as install-once Cap 30 steps.

## Principles

### P1 — One size for all swipe-direction arrows

Any arrow in First-launch Browse guidance that means **“swipe this
way”** (direction affordance) shares **one** size parameter:

| Knob | Constant | Value |
|------|----------|-------|
| **Size (the parameter)** | `kBrowseFirstLaunchSwipeDirectionArrowSize` | **32** |
| Stroke (faux bold only) | `kBrowseFirstLaunchSwipeDirectionArrowStrokeWidth` | 1.75 |

**In scope today:** `<1>` up + down, `<3>` left.  
**In scope later:** any new tip in this guidance family that shows a
swipe-direction glyph — must call `BrowseFirstLaunchCoachArrowIcon` (no
hard-coded `Icon(size: …)`).

**Out of scope:** `<2>` Create-aim **caret** (points at chrome, not a
swipe direction). That uses `kCap30CreatePoolTipArrowHeight` /
`kCap30CreatePoolTipArrowHalfWidth` — do not fold it into P1.

**Retune rule:** change `kBrowseFirstLaunchSwipeDirectionArrowSize` only.
Do not give `<1>` and `<3>` different sizes.

### P2 — Coach fill = action-column half-sheet surface

**Parent principle:** action-column half-sheets (Cap 19 / Cap 24 `"…"` /
Order) share one fill — `mediaSheetSurface` @
`kCap19ActionsHalfSheetTintOpacity` (**0.96**), **no** blur. Canon in
`docs/reference/media-chrome-layout-notes.md` **§12.0** (Cap **24.5.1**).

**This file’s extension:** First-launch Browse coaches `<1>` / `<2>` /
`<3>` are the **same surface family**, not a third frost language.

| Knob | Value | Code |
|------|-------|------|
| Fill | Same as §12.0 | `browseCoachSheetFill(tokens)` |
| Blur | **None** | — |

**Do not:** reuse Cap 19 toast frost (`feedBackground` @
`kCap19FrostChromeTintOpacity` + blur) for these coaches.  
**Retune rule:** change half-sheet tint / `mediaSheetSurface` once; coaches
follow via `browseCoachSheetFill`. Do not give `<1>`/`<2>`/`<3>` a private
fill constant.

### P3 — Per-step display duration (independent constants)

Each first-launch chain step owns its **own** duration constant. Importance
differs by tip; future clips (D8) adds another constant — do **not** revive
a single shared `kCap30GuideStepDuration`.

| Step | Duration | Constant |
|------|----------|----------|
| `<1>` vertical | **2.0s** | `kCap30VerticalHintGuideDuration` |
| `<2>` Create tip | **3.5s** | `kCap30CreatePoolTipDuration` |
| Future clips | TBD | New constant + branch in `cap30GuideChromeDuration` |

Lookup helper: `cap30GuideChromeDuration(Cap30GuideChromeKind)`.  
Hosts arm timers with their step constant directly.  
`<3>` Cap 19 left-swipe stays on `kCap19LeftSwipeGuideDuration` (**2.5s**)
— out of Cap 30 per-step family.

### P4 — Coach text size tokens only (not card outer size)

Browse coaches `<1>` / `<2>` / `<3>` share **two** text roles. Values match
`waketok_tokens.dart` (`titleChrome` / `bodyOnMedia`).

| Role | TextTheme → token | Size | Used for |
|------|-------------------|------|----------|
| Coach **title** | `titleMedium` → `titleChrome` | **20** | `<1>` title, `<3>` title |
| Coach **body** | `bodySmall` → `bodyOnMedia` | **13** | `<3>` subtitle, `<2>` tip message |

**Do not** use `labelSmall` / `labelOnMedia` (**12**) for any Browse
first-launch guidance copy.

**Scope boundary:** P4 locks **text tokens (font size) only**. It does
**not** resize coach **card outer frames**. Card outer size for `<1>` vs
`<3>` remains **Open — deferred** (see **Card size** below). Do not treat
“unify size” as permission to change padding, maxWidth, or intrinsic
card dimensions in the same pass.

## Chain logic (Cap 30) — short ops view

See **Architecture** above for binding / extension. Ops summary:

- Step index on disk: `0 → 1 → 2 → 3` (ADR-060 D5). Reinstall clears SP.
- Order: `<1>` then `<2>`; never stacked. **Per-step durations** (**P3**).
- Sole Browse ready-sync owner: **`Cap30VerticalHintGuideHost`** (must
  stay mounted; tip Host must **not** call `syncCap30BrowseReady`).
- D6: Cap 19 `<3>` blocked while Cap 30 chain is active / armed
  (process memory `chainArmedThisLaunch` + step `1|2`).
- Full = Limited for `<2>` visibility (Create may be disabled under
  Limited; tip still shows). Arrow aim does **not** change by access.

## Gesture availability at `<1>`

**Baseline (code-verified, Cap 30.7):** When the library has **more than
one** item, at the moment `<1>` appears, **vertical PageView swipe is
functionally available**. This does **not** depend on Layer 1 (current
item image / “Loading item”) having finished decoding.

Evidence checked in code:

1. Showing `<1>` requires `assetId != null` → `browseSession` is already
   in `data` → the vertical `PageView` is mounted.
2. `<1>` chrome is wrapped in `IgnorePointer` — it does not absorb
   touches.
3. Center **Loading item** chrome does **not** use `AbsorbPointer` — it
   does not intercept vertical drags.
4. The only path that truly disables vertical scroll is magnification
   lock (`NeverScrollableScrollPhysics`). A cold first-install show of
   `<1>` is practically never in that state.

**Separate exception (content, not gesture failure):** If the library
has **exactly one** item, the user can still drag, but there is no
“next” page to land on. That is a content limit — do **not** describe
it as “swipe broken at `<1>`.”

Layer 1 paint and `<1>` are **not** bound: coach timing follows
`browseItemReady` (has current asset id), not first-frame decode.

## UI surface (see **P2**)

| Param | Value | Constant / helper |
|-------|-------|-------------------|
| Fill color | `mediaSheetSurface` @ **0.96** (= half-sheet §12.0) | `browseCoachSheetFill` |
| Blur | **None** | — |
| Corner radius `<1>` / `<3>` | 16 | inline |
| Corner radius `<2>` | 10 | inline |

## Icons / caret

| Chrome | Glyph | Size source | Weight |
|--------|-------|-------------|--------|
| `<1>` | Cupertino up + down | **P1** `kBrowseFirstLaunchSwipeDirectionArrowSize` | Stroke via `BrowseFirstLaunchCoachArrowIcon` |
| `<3>` | Cupertino left | **P1** (same constant) | Same helper |
| `<2>` | Outward upward triangle | `kCap30CreatePoolTipArrowHeight` **14** / half-width **11** (working; size polish open) | Filled `CustomPaint`; `tokens.accent`; **outside** bubble |

`<1>` / `<2>` label + caret use `tokens.accent` + `onMediaLabelShadows`.  
`<3>` keeps `onMedia` / `onMediaMuted` (Cap 19 copy); icon also gets
`onMediaLabelShadows` for media behind the opaque sheet edge cases.
Text sizes: **P4** (title 20 / body 13).

## Copy (Cap 30.6 / ADR-060 D7) — Browse vs Settings

| Surface | Key | Role |
|---------|-----|------|
| Browse `<3>` subtitle | `cap19LeftSwipeGuideSubtitle` | Short Settings redirect (not safety) |
| Settings **master** left-swipe add subtitle | `cap19SettingsLeftSwipeAddSubtitle` | Safety / bookmark explanation |
| Settings tip toggle subtitle | `cap19SettingsLeftSwipeGuideSubtitle` | Unchanged (“once per launch…”) |

EN Browse redirect (locked): *You can turn this feature and tip off in
Settings*.  
zh Browse redirect (owner draft, no further polish this Cap): *可在设置中关闭此功能和提示*.

`<1>` / `<2>` ARB strings are **final** as of Cap 30.6 (declarative; D3).

## Card size (`<1>` vs `<3>`)

**Open — deferred.** Both cards are still **intrinsic**
(`mainAxisSize: min`): height/width follow copy + padding. `<3>` is
usually taller (title + subtitle). Owner has **not** locked equal outer
frames yet; do not invent a shared fixed box until a later pass.

## `<2>` placement

Create Pool tip (`cap30_create_pool_tip.dart`). Horizontal: tip **right**
edge = Create stadium **right** edge. Max width
`min(180, create.right − 8)`.

### Vertical stack (top → bottom)

```
Create stadium bottom  (or Limited helper bottom, if present)
  │  kCap30CreatePoolTipClearance          = 4
caret tip (vertex) — aims at Create horizontal center
  │  kCap30CreatePoolTipArrowHeight        = 14  (working; size polish open)
caret base
  │  kCap30CreatePoolTipCaretBubbleGap     = 4
bubble top
  │  Material bubble (radius 10, copy + pad)
```

Bubble top offset from anchor bottom =
**clearance + arrowHeight + caretBubbleGap** = **4 + 14 + 4 = 22**
(with current arrow height).

The two **4** gaps are **independent** constants that currently share the
same value; retune either without assuming they stay equal.

### Parameter table

| Constant | Value | Role |
|----------|------:|------|
| `kCap30CreatePoolTipClearance` | **4** | Create/helper bottom → caret **tip** |
| `kCap30CreatePoolTipArrowHeight` | **14** | Outward caret height (working) |
| `kCap30CreatePoolTipArrowHalfWidth` | **11** | Outward caret half-base (working) |
| `kCap30CreatePoolTipCaretBubbleGap` | **4** | Caret **base** → bubble top |
| `kCap30CreatePoolTipMaxWidth` | **180** | Ceiling; also clamped by `create.right − 8` |
| Edge pad (private) | **8** | Left clamp for max width vs screen |

### Caret aim + layout

| Rule | Detail |
|------|--------|
| Aim | Triangle **vertex** on Create stadium **absolute horizontal center** (`mainBrowseCreatePool`), **not** tip center. Same Full / Limited. |
| Structure | Outer **Column** = vertical only (caret row → gap → Material bubble). Caret X via caret-row **Stack + Positioned** (`createCenter − tipLeft`). |
| Width order | Measure **laid** tip width from intrinsic copy first (EN/zh differ), **then** compute arrow X. Never place caret from `maxWidth` alone. |
| Clamp | Only if tip too narrow to keep caret above the bubble footprint. |
| Outside | Caret is **above** the bubble (not painted inside Material). |

### Why this replaced the inward-caret lock

Earlier lock: “Caret stays inside tip (no outward overhang)” with host
gap **8** (caret consumed space inside the dark card). That read as a
notch/wedge, not a pointer. Reversed to **outward** caret + the vertical
stack above. Tests: `T-30.4-W5` / `W5n` (zh@390) / `W5n-en` (EN@390) —
caret outside bubble, caret–bubble gap, no Create/helper intrusion, aim
within Create stadium.

## Duration / early end

| Step | Duration | Early end |
|------|----------|-----------|
| `<1>` | **2.0s** (`kCap30VerticalHintGuideDuration`) | Feed **page index** change only |
| `<2>` | **3.5s** (`kCap30CreatePoolTipDuration`) | None (feed swipe does not cancel) |
| `<3>` | 2.5s (`kCap19LeftSwipeGuideDuration`) | Cap 19 session rules (unchanged) |

## Related docs

- ADR-060 — contract (D1–D10)
- `docs/acceptance/cap30-30.*.md` — phase notes
- `docs/reference/media-chrome-layout-notes.md` — Browse chrome; **§12.0**
  is the parent half-sheet surface principle (P2 extends it). Coaches are
  **not** folded into that file’s media-area zones.
