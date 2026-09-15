# PhotoKit implicit behavior notes (engineering accumulation)

This file is **not an ADR**. It does not record product decisions.
It accumulates PhotoKit / Photos.framework behaviors that are easy to
misread: multiple independent signals that often agree but are **not
guaranteed to stay in sync**, plus other undocumented or weakly
documented Host facts WakeTok has already tripped on.

**STATE.md** may point here; do not paste long matrices into STATE.

When iOS ships a major Photos / PhotoKit change, re-check entries that
matter to the active Cap before assuming last year’s probe still holds.
When a new mismatch is confirmed, **append a row here** (with device +
OS + evidence class) instead of rediscovering from zero.

---

## 1. Three classification surfaces (Live / Animated family)

WakeTok (and Photos UI) can answer “is this Live?” / “is this Animated?”
using at least three **independent** PhotoKit surfaces. They are
maintained separately and can update on different timelines.

| # | Surface | Shape | Rough role |
|---|---------|--------|------------|
| A | `PHAsset.mediaSubtypes` | `OptionSet` (bits may combine) | “Origin” / structural flags (e.g. `.photoLive`). Often tied to how the asset was captured or still classified at the subtype layer. |
| B | `PHAsset.playbackStyle` | Single enum value | **Presentation preference** for how to play/show the asset. Can change when the user edits effects in Photos (Loop / Bounce / Long Exposure / turn Live off, etc.). |
| C | Smart-album membership | `PHAssetCollection` (e.g. subtype **213** Live Photos, **214** Animated) | Separate catalog / index. May lag A/B, or use rules that are not identical to A or B. |

**Working rule for new features:** assume A/B/C can diverge. Pick the
surface that matches the product question, verify on device, and do not
treat “any one signal ≈ the others.”

WakeTok product choices that *select* a surface live in ADRs (e.g.
ADR-052 Decision 11). This file only records the **mismatch phenomena**
and evidence class.

---

## 2. Confirmed mismatch entries

Evidence classes (do not collapse these):

- **Device probe** — Host logged public API fields on a named device/OS.
- **Design + SDK** — Locked in an ADR from SDK headers / owner product
  path; **not** re-measured as rawValues in the Cap 26.3 Live-off probe
  session unless noted.

### 2.1 Loop / Bounce Live vs `playbackStyle` (identity gate)

- **Phenomenon:** A Live Photo whose Photos effect is Loop or Bounce
  typically still has `mediaSubtypes` containing `.photoLive`, while
  `playbackStyle` typically becomes `.videoLooping` (confirmed via SDK
  headers; not re-probed as a rawValue in this session). Subtype bits
  for Loop/Bounce themselves are **not** exposed on
  `PHAssetMediaSubtype`.
- **Surfaces:** A (`.photoLive`) vs B (`playbackStyle`).
- **Evidence class:** **Design + SDK** (ADR-052 Decision 11). Not
  re-probed as `subtypes` / `playbackStyle` rawValues in the Cap 26.3
  Live-off Console session.
- **Product stance (see ADR, do not re-decide here):** Cap 9 / Cap 26
  Live identity and long-press eligibility use **A only**
  (`.photoLive` → `mapMediaKind` → `livePhoto`). They **deliberately
  ignore B** for that gate. Mismatch is the *phenomenon*; Decision 11
  is the *choice of surface*.
- **Cross-ref:** ADR-052 Decision 11; Cap 9 `mapMediaKind` /
  `LivePhotoApiHost` `.photoLive` guard.

### 2.2 Smart album Animated (214) vs `.imageAnimated`

- **Phenomenon:** Membership in System Album **Animated**
  (`smartAlbumAnimated` / **214**) can include Loop/Bounce Live Photos.
  Those assets remain Live for WakeTok Browse when A has `.photoLive`;
  their `playbackStyle` is typically **not** `.imageAnimated`.
- **Surfaces:** C (214 membership) vs B (`.imageAnimated`) vs A
  (`.photoLive` for Live chrome).
- **Evidence class:** **Design + SDK / owner Build-a-Pool path**
  (ADR-053). Not measured via album-membership Host probe in the
  Cap 26.3 Live-off Console session.
- **Product stance (see ADR):** Overlay Animated label uses
  `mapMediaKind == image` **and** `playbackStyle == .imageAnimated`
  only — **never** 214 membership (avoids false Animated on Live).
- **Cross-ref:** ADR-053 Decisions 2–3; Cap 21 smart album **214**.

### 2.3 Smart album Live Photos (213) vs Live turned off

- **Phenomenon:** An asset the user turned **Live off** in Photos can
  still appear in System Album **Live Photos** (**213**) and thus in a
  Live-oriented Build-a-Pool source, while WakeTok Browse shows **no**
  Live Overlay / LIVE badge and does not arm Live play / Cap 26
  long-press — because Host `mapMediaKind` did not classify
  `livePhoto` (`mediaSubtypes` lacked `.photoLive`).
- **Surfaces:** C (213 membership) vs A (`.photoLive`).
- **Evidence class:** **Device probe** — iPhone13pro Kafka,
  iOS **26.6 (23G71)**, temporary Host log on
  `requestPresentationMetadata` (Cap 26.3 session):

  | Role | `localIdentifier` (prefix) | `mediaSubtypes.rawValue` | `photoLive` | `playbackStyle.rawValue` (observe only) |
  |------|----------------------------|---------------------------|-------------|----------------------------------------|
  | Live off #1 | `C1492781-3A89-4DA1-81C0-47333C0FD0D4` | `0x200` | 0 | 1 |
  | Live off #2 | `90FF78D0-3B15-401E-A27E-2BAEA18CB4A0` | `0x200` | 0 | 1 |
  | Live on (control) | `26B110E2-069E-4C3B-AE48-2696AC3B779B` | `0x208` | 1 | 3 |

  Reading: `.photoLive` is `0x8`; off rows lack that bit; on control
  `0x208 == 0x200 | 0x8`. `playbackStyle` logged for observation only —
  not used for Live identity (ADR-052 D11).
- **Symmetric risk (not observed on this probe):** If some iOS version
  / Live-off workflow **keeps** `.photoLive`, WakeTok would still show
  Live chrome and call `requestLivePhoto` while Photos presents a
  still — same *class* of non-parity as ignoring `playbackStyle` for
  identity (ADR-052 D11).
- **Cross-ref:** Known debt **471** (Monitoring); Cap 21 smart album
  **213**; Cap 9 / Cap 26 `mapMediaKind`.

---

## 3. Other PhotoKit implicit behaviors (index only)

Pointers only — details stay in ADRs / STATE debt. Revisit on major iOS
Photos changes if the linked Cap is active.

| Topic | Why “implicit” | See |
|-------|----------------|-----|
| `PHAssetResource` KVC `locallyAvailable` | No public Swift property; list-time local vs iCloud | ADR-011 family; related Known debt |
| Undocumented smart-album subtype raw values (e.g. Recently Deleted `1000000201`) | Not all catalog IDs are public enum cases | `docs/reference/cap21-smart-album-boundary.md`; Cap 11 / 21 |
| Limited library settle race | Authorization UI can return before PhotoKit library is populated | Cap authorization / resolve ADRs |
| `PHImageManager` opportunistic double callback / cancel | Multiple resultHandler invocations; cancel best-effort | Browse load / iCloud path ADRs |
| `PHLivePhotoView` / UiKitView vs Flutter `Transform` | Platform View may not follow Flutter magnification transforms | Known debt **470**; ADR-043 |

---

## 4. Maintenance

1. Before trusting an entry after a major iOS upgrade, re-probe or
   explicitly mark “unchecked on iOS X.Y.”
2. New mismatches: append under §2 (classification) or §3 (index), with
   **evidence class**, device/OS when probed, and ADR/debt links.
3. Do not move product decisions into this file — flip or add ADRs;
   keep this as the phenomenon / evidence log.
