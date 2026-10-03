# Settings layout — hierarchy, rows & info bubbles

> **Status:** Cap 31.1 working snapshot (hierarchy: weight-only section/row;
> hug-title `i`; muted Photos status; row gap = switch layout height +
> `kSettingsRowGap` — do not OverflowBox the switch).  
> **Not** an ADR. Do **not** fold into post-v1 Settings / localisation Cap.  
> **Scope:** Main Browse **Settings pane** (`_SettingsStubPane` in
> `main_browse_shell_page.dart`) — section hierarchy, toggle rows, and
> anchored info bubbles.  
> **Not** bottom-tab chrome (always dark — ADR-016 / shell). Settings *pane*
> follows system Appearance (`ThemeMode.system`).  
> **Not** privacy / about screens (post-v1 Settings Cap). The Cap 32 About
> section is one external link row (Privacy Policy, ADR-072), not a screen.  
> **Code anchors:**  
> - `lib/features/main_browse/settings_layout.dart`  
> - `lib/features/main_browse/anchored_info_bubble.dart`  
> - `lib/features/main_browse/cap19_gestures_settings_section.dart`  
> - `lib/features/main_browse/browse_notifications_settings_section.dart`  
> - `lib/features/main_browse/browse_display_settings_section.dart`  
> - `lib/features/authorization/photos_access_settings_section.dart`  
> - `lib/features/main_browse/about_settings_section.dart`  
> - Cap 24 half-sheet reuses the bubble API:
>   `cap24_more_half_sheet.dart` → `showAnchoredInfoBubble`

**How to retune:** change the named constant / token helper in the table,
then reinstall Profile and re-check Light **and** Dark (system Appearance).
Prefer editing constants over hard-coding numbers in section widgets.

**Hard constraint (Cap 31.1):** no cards, no divider lines. Hierarchy uses
**weight**, **muted color**, and **spacing** only — not accent, not a second
font-size ladder between section and row.

---

## 1. Visual hierarchy (Cap 31.1)

| Role | Token / helper | Size / weight / color | Notes |
|------|----------------|-----------------------|-------|
| Page title | `tokens.titlePage` | **24 / w700** | Page-level heading (`mainBrowseNavSettings`); future page titles (e.g. Clips) use the same token. **Not** `titleChrome` — see **Title token roles** below |
| Section title | `settingsSectionTitleStyle` | **14 / w400** / `onSurface` | Same size as row; **not** bold; **never** `tokens.accent`; display via `settingsSectionTitleWithColon` (EN `:` / zh `：`) |
| Row title | `settingsRowTitleStyle` | **14 / w600** / `onSurface` | Same size as section; **bold** is the only section↔row axis |
| Photos Access label | `settingsRowTitleStyle` | **14 / w600** / `onSurface` | **Special (Photos only):** copy = Photo Library Access / 照片访问权限; uses **row** chrome (bold) — not section chrome; **no** trailing colon |
| Photos status body | `settingsRowTitleStyle` | **14 / w600** / `onSurface` | **Special (Photos only):** live Full/Limited status; same **row** chrome as the label; stays on list (not a bubble) |
| Row subtitle | `settingsRowSubtitleStyle` | muted | **Rare** — Cap 31.1 product rows use bubble instead |
| Info bubble body | `settingsInfoBubbleTextStyle` | 14 / w400 / `onSurface` | Chrome role — **not** `labelOnMedia` |

**Section vs row rule:** one shared chrome size (`kSettingsChromeTitleFontSize`
= **14**, from `bodyChrome`). Differentiate **only** with weight (row bold,
section regular). Do not also enlarge the section.

**Accent ban:** `tokens.accent` already means selected / coach focus (bottom
nav, Cap 30 guidance). Do not paint static section labels with accent.

### Title token roles (Cap 31.1)

Two title tokens in `waketok_tokens.dart` (Light + Dark). Do not use one for
the other's role.

| Token | Value | Bound to | Role |
|-------|-------|----------|------|
| `titlePage` | **24 / w700** | nothing (read directly) | Page-level heading only: Settings today, future page titles |
| `titleChrome` | **20 / w600** | `textTheme.titleMedium` + `AppBarTheme.titleTextStyle` | AppBar / sheet / guide titles (Cap 7.2 role) |

**`titlePage` consumers:** Settings page title
(`main_browse_shell_page.dart`). Retuning it moves page headings only.

**`titleChrome` consumers** (6 `titleMedium` surfaces; no AppBar title
reads it since Cap 31.4): canonical list in `media-chrome-layout-notes.md`
**§14**. Retuning
`titleChrome` moves all of them; re-check each on device. A new surface that
uses `titlePage` must be added here; one that uses `titleMedium` /
`titleChrome` goes in §14.

**Not in this pass:** sheet titles and sheet button labels
(Delete / Add to Album) still borrow `titleMedium` rather than having their
own roles. Splitting them is a separate, device-accepted pass.

### Photos Access special treatment (Cap 31.1)

Unlike other Settings sections (label = **section** chrome / w400; rows =
**row** chrome / w600), Photos Access paints **both** the section label and
the live status line with **row** title chrome:

| Element | Copy (EN / zh_Hans) | Style helper |
|---------|---------------------|--------------|
| Section label | Photo Library Access / 照片访问权限 | `settingsRowTitleStyle` (w600); **no** trailing colon |
| Status line | e.g. Full access… / Limited banner message | `settingsRowTitleStyle` (w600) |

Code: `photos_access_settings_section.dart` (not `SettingsSectionHeader`).
Do **not** use muted `settingsStatusBodyStyle` here — that helper is for
probe / debug helpers only.

Cap 24 honesty note on the forced-dark half-sheet may still pass
`labelSmall` + `onSurface` into `showAnchoredInfoBubble` (historical
on-media size). Settings must use chrome helpers above.

---

## 2. Spacing

| Constant | Value | Use |
|----------|------:|-----|
| `kSettingsSectionGap` | **28** | Between sections in the Settings `ListView` |
| `kSettingsSectionTitleToRowGap` | **12** | Under section title |
| `kSettingsRowGap` | **8** | Between stacked toggle **layout** rows |
| `kSettingsTitleSubtitleGap` | **2** | Title → short subtitle (if any) |
| `kSettingsRowTrailingGap` | **12** | Text column → switch |
| `kSettingsTitleInfoGap` | **2** | Title glyphs → info `i` (hug) |
| `kSettingsInfoLayoutWidth` | **22** | Non-inline `i` slots only |
| `kSettingsInfoHit` | **44** | Min tap target (overflow) |
| `kSettingsInfoIconSize` | **18** | `Icons.info_outline` glyph / WidgetSpan box |
| `kSettingsChromeTitleFontSize` | **14** | Shared section + row size |
| `kSettingsStatusBodyOpacity` | **0.55** | Probe / helper muted body only (not Photos Access) |

**Photos Access exception:** label **and** status = `settingsRowTitleStyle`
(see §1 “Photos Access special treatment”).

### Row gap root cause (Gestures pair)

`kSettingsRowGap` **is** applied between the two Gestures `SettingsToggleRow`s.
Optical title↔title is still larger than that constant because:

1. **`CupertinoSwitch` intrinsic height (~31)** participates in the row’s
   layout height; titles are vertically centered in that band, so
   title↔title ≈ `kSettingsRowGap` + `(switchH − lineH)`.
2. Info `i` uses a **44** hit via `OverflowBox` (layout box stays **18**) —
   that does **not** inflate layout height.

**Rejected fix:** shrink row height to the title line and `OverflowBox` the
switch. Device showed Gestures switches stacked into a figure-8 — switch
must keep its layout height. Related rows stay near via `kSettingsRowGap`
only (no grouping card/background).

---

## 3. Toggle row + info bubble

**Shared widget:** `SettingsToggleRow` in `settings_layout.dart`.

**List chrome:** `title` + hugging `i` + switch. Explanatory “once per /
turn off to / a short message …” tier **always** in the info bubble — not
as list subtitles.

| Row | List subtitle | Info bubble message |
|-----|---------------|---------------------|
| Left-swipe add | **none** | `cap19SettingsLeftSwipeAddSubtitle` |
| Left-swipe tip | **none** | `cap19SettingsLeftSwipeGuideSubtitle` |
| Starting-over notice | **none** | `browseSettingsNewRoundToastInfo` (full) |
| Show bottom-left details | **none** | `browseDisplayMetaOverlaySubtitle` |
| Photos Access status | muted status line (not a bubble) | — |

### Hard rule — info `i` hugs the annotated text

**Do**

- Put the `i` in the **same text run** as the label it explains
  (`Text.rich` + `WidgetSpan` after the title `TextSpan`).
- Keep a single constant gap: `kSettingsTitleInfoGap` (**2**) =
  padding between the **last title glyph** and the `i` glyph.
- Size the `WidgetSpan` child to the **glyph** (`kSettingsInfoIconSize`);
  grow the tap target with `OverflowBox` → `kSettingsInfoHit` (**44**),
  same idea as Cap 24 timezone `i`.

**Don't**

- `Flexible` / `Expanded` around `Text(title)` with a **trailing** `Icon`
  sibling — `Text` expands to the max width, so `i` lands on the **far
  edge of the text column** (looks like a second vertical lane, or
  “stuck to the other side of the row”). This bug has recurred; treat
  it as a hard ban for Settings (and any future inline info `i`).
- Give each row a different title→`i` gap. One constant only.

**Same every row?** Yes — when implemented via `WidgetSpan` +
`kSettingsTitleInfoGap`, the glyph-to-glyph distance is identical
regardless of title length. (A trailing-`Flexible` layout is *not*
identical: short titles can look “close” while long titles shove `i`
to the column edge.)

**Bubble behaviour** (shared with Cap 24 via `anchored_info_bubble.dart`):

| Constant | Value |
|----------|------:|
| `kAnchoredInfoBubbleMaxWidth` | **300** |
| `kAnchoredInfoBubbleMaxHeight` | **280** |
| `kAnchoredInfoBubbleGap` | **6** |
| `kAnchoredInfoBubbleSurfaceAlpha` | **0.96** |

- Prefer above the anchor; flip below when above is too tight
  (`spaceAbove >= 96 || spaceAbove >= spaceBelow`).
- Opaque barrier dismiss; taps on the bubble body do not dismiss.
- `dismiss()` removes `OverlayEntry` only — never `Navigator.pop`.
- Callers pass Cap-specific `bubbleKey` / `barrierKey` when tests need
  stable finders (Cap 24 timezone keys unchanged).

---

## 4. Light / Dark verification

Settings pane uses ambient `Theme` (`ThemeMode.system`). The info bubble
defaults to `tokens.surface` @ **0.96** + chrome `onSurface` text.

Muted status (`onSurface` @ **0.55**) must be checked in **both** Light and
Dark for readable contrast on `background` — not assumed from tokens alone.

Cap 24 half-sheets wrap `waketokTheme(Brightness.dark)` — that path never
proved Light contrast for this bubble. Cap 31.1 **requires** owner eyeball
(or screenshots) in **both** system Light and Dark. If Light shadow /
contrast is weak, retune after evidence (D5) — do not invent a second
surface recipe up front.

---

## 5. Checklist when adding a Settings section

1. Use `SettingsSectionHeader` + `kSettingsSectionGap` / title→row gap.  
2. Prefer `SettingsToggleRow` for switch rows.  
3. Put explanatory copy in the info bubble; keep the list to title + `i`.  
4. Photos Access: label **and** status = row title style (see §1). Other
   live helpers (probes) may still use muted `settingsStatusBodyStyle`.  
5. Access copy only via `AppLocalizations` (ADR-012).  
6. Colors / type only via `WakeTokTokens` helpers (ADR-009); no accent on
   section labels.  
7. Re-check Light and Dark after visual changes.

---

## 6. Out of scope (do not expand here)

- Full EN / zh-Hans copy sweep  
- Privacy / storage / about screens  
- In-app Appearance toggle product  
- Competitor-codename scan (Cap 31.5)  
- Changing Cap 24 half-sheet forced-dark policy  
- Cards / divider lines for Settings grouping  
