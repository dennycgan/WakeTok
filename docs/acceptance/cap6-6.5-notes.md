# Cap 6 — Phase 6.5 Real-device acceptance notes

> Device gate for All / Photos / Videos built-in source resolution
> (STATE Phase 6.5 / ADR-013). Owner acceptance on **iPhone 13 Pro** —
> **PASS** 2026-08-02.

## Locked acceptance rules (2026-08-02 design)

| # | Choice |
|---|--------|
| Q1 | Year-span **N = 3** |
| Q2 | Epoch / dirty dates: exclude UTC `1970-01-01` and year **&lt; 1990** |
| Q3 | Automated pre-gate only (`flutter analyze` + `flutter test`); no new code |
| Q4 | After close-out, Phase Roadmap = Main Browse TBD placeholder |
| Q5 | Pure docs one commit (notes + STATE + PHASE_HISTORY) when no product fix |
| M9 | **Mandatory** Limited subset list/resolve (not Known debt) |

**R3 year-span (All-only quantiles):**

1. `resolve(All)` → `ids`; `ids.length == libraryTotals.all`
2. `q ∈ {0, ⌊0.25(n−1)⌋, ⌊0.50(n−1)⌋, ⌊0.75(n−1)⌋, n−1}`
3. Each point: `fetchLibraryPage(cursor:'$q', pageSize:1)`;
   `assetIdentifier == ids[q]` (`align=OK`)
4. Exclude dirty dates (Q2). If fewer than **2** credible dated points remain →
   **do not** judge N; notes **N/A** + remaining count and reason.
5. Otherwise span = **`maxYear − minYear`** (same definition as smoke UI
   parenthetical, e.g. `1970–2026 (56)` ⇒ `2026−1970`). Require span ≥ N.

> **Owner footnote (credibility of epoch exclusion):** The library contains
> photos/videos imported from other devices into iCloud that display as
> **1970-01-01** in Photos / PhotoKit while the owner recalls the true capture
> time as approximately **2016**. Epoch exclusion is therefore grounded in
> confirmed import dirty metadata, not speculation.

**Photos totals procedure (M2):** Photos → 相簿 → 媒体类型 → 照片 + 视频;
All = sum. Same Cap 5.5 / ADR-011 inclusion (Hidden / Recently Deleted out).

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro |
| Device name | (owner device; same Cap 5.5 floor unit) |
| Note vs STATE project facts | STATE lists “iPhone 13 (performance floor)”; this gate used **iPhone 13 Pro** — notes are authoritative for the run |
| Git HEAD (tested) | `c47f77d` (includes 6.4 work `6be43d4`) |
| Date (local) | 2026-08-02 |
| N (year-span) | 3 |
| Span formula | `maxYear − minYear` |

### Pre-gate (automated)

| Check | Result |
|-------|--------|
| `flutter analyze` | PASS |
| `flutter test` | PASS (85) |

---

## Manual results (M1–M9)

| ID | Scenario | Result | Notes |
|----|----------|--------|-------|
| M1 | Cold start → Library Shell | **PASS** | Full Access for M1–M8 |
| M2 | Totals exact vs Photos Media Types | **PASS** | See count table |
| M3 | list estimatedCount vs totals (All/Photos/Videos) | **PASS** | e.g. Videos estimatedCount 2055 |
| M4 | Resolve All/Photos/Videos; match vs totals OK | **PASS** | Owner confirmed lengths match totals |
| M5 | All quantile indices + align=OK | **PASS** | See quantile table |
| M6 | Credible year-span ≥ N | **PASS** | Credible span **8** ≥ 3; see R3 calc |
| M7 | ≥1 `iCloudNotDownloaded` | **PASS** | 4 of 5 quantile rows |
| M8 | Probe illegal pair → ARB copy | **PASS** | Exercised with All/Photos/Videos selected; same ARB each time |
| M9 | Limited subset list/resolve | **PASS** | See Limited table |

M10 (zh-Hans) not required for this close-out.

### M2 / M4 count table (Full Access)

| Source | All | Photos | Videos |
|--------|-----|--------|--------|
| WakeTok Library Shell (totals) | 42410 | 40355 | 2055 |
| Photos → 媒体类型 | 42410 | 40355 | 2055 |
| Resolve length (match OK) | 42410 | 40355 | 2055 |

Exact match? **YES**. Sanity: `40355 + 2055 = 42410`.

### M5 quantile table (Full Access, n = 42410, last = 42409)

Expected indices: `0, 10602, 21204, 31806, 42409`
(`⌊0.25×42409⌋=10602`, `⌊0.50×42409⌋=21204`, `⌊0.75×42409⌋=31806`).

| q | assetIdentifier | creationDate (UTC) | align | avail |
|---|-----------------|--------------------|-------|-------|
| 0 | `9B745F9A-E0E2-4AFA-9688-5AA73EB7E235/L0/001` | `2026-08-02T11:05:59.000Z` | OK | deviceLocal |
| 10602 | `BFAF2107-658E-4E98-9E69-33AA01A68600/L0/001` | `2024-01-22T01:39:21.003Z` | OK | iCloudNotDownloaded |
| 21204 | `312BB707-0468-4FC2-97EA-6285D4F59E6F/L0/001` | `2021-12-24T13:58:49.463Z` | OK | iCloudNotDownloaded |
| 31806 | `2EEF2E20-B857-497D-B7D4-F1AB09D202E4/L0/001` | `2018-12-24T12:04:34.423Z` | OK | iCloudNotDownloaded |
| 42409 | `90C3F6F5-88CE-48FF-89FD-44B6D534D926/L0/001` | `1970-01-01T00:00:00.000Z` | OK | iCloudNotDownloaded |

Smoke UI raw year span (all non-null dates, **before** R3 exclusion):
`1970–2026 (56)` = `2026 − 1970`.

**Index vs count:** `q=42409` is the last **0-based index** (`n−1`), not the
count `42410`. Not a mismatch.

### M6 / R3 year-span calculation

| Step | Value |
|------|-------|
| Dirty / excluded | **only** `q=42409` (`1970-01-01T00:00:00.000Z`) — oldest index under creationDate descending; expected for epoch metadata |
| Credible points | **4** (years 2026, 2024, 2021, 2018) |
| Credible count ≥ 2? | **YES** (no N/A fallback) |
| Credible minYear | **2018** (q=31806) |
| Credible maxYear | **2026** (q=0) |
| Credible span (`max−min`) | **8** |
| N | **3** |
| `8 ≥ 3`? | **YES → PASS** |

### M7 iCloud evidence

Quantile `avail=iCloudNotDownloaded` at q=10602, 21204, 31806, 42409
(**4 ≥ 1**).

### M8 negative pair

UI string (ARB `sourcePairMismatchError`):
`Expected error: source reference unavailable.`
Confirmed with segmented selection on All, Photos, and Videos (probe itself
uses fixed illegal pair `entireLibrary` + `photos`).

### M9 Limited subset

| Field | Value |
|-------|--------|
| Access | Limited (banner visible) |
| Owner selection size | 35 |
| Shell totals | All **35** / Photos **18** / Videos **17** (`18+17=35`) |
| All list | `estimatedCount: 35` |
| All resolve | `resolved length: 35`; `match vs totals: OK` |
| vs Full | 35 ≪ 42410 |
| Unauthorized? | **No** — built-ins remained listable/resolvable |

---

## Overall

- **Phase 6.5:** **PASS**
- **Capability 6 ready to close:** **YES**
- Owner sign-off: Denny — 2026-08-02

---

## Defects found (if any)

| # | Symptom | Suspected area | Fix |
|---|---------|----------------|-----|
| — | None blocking 6.5 | — | — |
