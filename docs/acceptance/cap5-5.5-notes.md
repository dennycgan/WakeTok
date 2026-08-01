# Cap 5 — Phase 5.5 Real-device acceptance notes

> Device gate for iOS Photos permission / library catalog (STATE Phase 5.5).
> Owner acceptance on **iPhone 13 Pro** — **PASS** 2026-08-01.

## Locked acceptance rules (2026-08-01 design)

| # | Choice |
|---|--------|
| 1 | Totals: **exact match** (All / Photos / Videos) — no ±tolerance |
| 2 | Photos read method: **Albums → Media Types** (照片 + 视频); All = sum |
| 3 | Notes path: this file |
| 4 | No product code in 5.5 unless a defect fix is required |

**M5 inclusion semantics (both apply):**

- STATE Phase 5.5: default `PHFetchOptions` — excludes Hidden and Recently Deleted
- ADR-011 Decision §3: same default PhotoKit semantics via shared
  `makeLibraryFetchOptions`

**Photos app procedure for M5:** Photos → 相簿 → 媒体类型 → record 照片 and
视频 counts; All = 照片 + 视频. Do not use 精选/回忆; do not include 已隐藏 /
最近删除.

### M5c — what “Hidden / Recently Deleted” means (spot-check)

Default PhotoKit fetch (**and** Photos → 媒体类型) **do not count** items that
live only in **已隐藏** or **最近删除**. Those albums can still contain photos;
they are simply **outside** the Media Types totals.

Exact M5 match while Hidden/Recently Deleted are non-empty ⇒ **M5c PASS**.

### M7 / M8 — system language + device restart

Changing **iPhone 语言** forces a **device restart**, which **kills every
app**. Cold start after reboot must follow system language → PASS.

### M2 note — iOS may SIGKILL on Photos privacy change

Changing Photos access in Settings often **SIGKILL**s the app (`flutter run`
shows `Target 0: (Runner) stopped`). Cold start with Full Access → Shell is
PASS. Do not FAIL solely because the debug session died.

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro |
| Device name | Kafka |
| iOS version | (owner device; not recorded) |
| Git HEAD (tested) | `05c6218` + fix `8d8c873` (picker dismiss / resume refresh) |
| Date (local) | 2026-08-01 |

### Pre-gate (automated)

| Check | Result |
|-------|--------|
| `flutter analyze` | PASS |
| `flutter test` | PASS (65) |

---

## Manual results (M1–M8)

| ID | Scenario | Result | Notes |
|----|----------|--------|-------|
| M1 | First ask → Shell | **PASS** | |
| M2 | Deny → Open Settings → restore → Shell | **PASS** | SIGKILL on Settings leave; cold start → Shell OK |
| M3 | Limited Banner + Manage; totals refresh | **PASS** | |
| M4 | Full Access; no Limited Banner | **PASS** | |
| M5 | Totals exact match vs Photos Media Types | **PASS** | exact match (owner) |
| M5c | Hidden / Recently Deleted not inflating WT | **PASS** | albums non-empty; WT still = Media Types |
| M6 | Light / Dark render | **PASS** | |
| M7 | English UI strings | **PASS** | cold start after language change |
| M8 | zh-Hans UI strings | **PASS** | cold start after language change |

### M5 count table (Full Access)

| Source | All | Photos | Videos |
|--------|-----|--------|--------|
| WakeTok Library Shell | (exact match) | (exact match) | (exact match) |
| Photos → 媒体类型 | (same) | (same) | (same) |

Exact match? **YES** (owner confirmed; numeric values not transcribed)

---

## Overall

- **Phase 5.5:** **PASS**
- **Capability 5 ready to close:** **YES**
- Owner sign-off: Denny — 2026-08-01

---

## Defects found (if any)

| # | Symptom | Suspected area | Fix |
|---|---------|----------------|-----|
| 1 | M3 totals stale after Manage selection | picker completed at present-time; no totals invalidate | `8d8c873` |
| 2 | M2 debugger stop when leaving for Settings | iOS SIGKILL on privacy change | accepted OS behavior; documented above |
