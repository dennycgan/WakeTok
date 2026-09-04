# Cap 7 — Phase 7.7a Profile hard-gate retest notes

> Binding **Profile** retest of Cap 7.7 hard bar after 7.7 campaign was
> **INVALIDATED** (Release build used by mistake — see `cap7-7.7-notes.md` Errata).
> Same V-hard rules as 7.7. Does **not** rewrite the Release forensic tables.
> Result: **PASS** (2026-08-06).

## Locked rules

| Item | Value |
|------|--------|
| Hard bar | mean hitch **&lt; 25 ms/s** AND **zero** Severe Hang per Run |
| Surfaces | **Videos** ×3 and **All** ×3 (**V-hard**: any Run fail → surface FAIL → phase FAIL) |
| Build | **Profile only** |
| Preferred install | `flutter build ios --profile` then `flutter install --profile -d 00008110-001114420AEA801E` |
| Alternate | `flutter run --profile -d 00008110-001114420AEA801E` |
| Forbidden | `--release` for this gate |
| Hitch formula | `Total hitch duration ÷ window seconds` |
| Continue on first miss | Yes — finish all 6 Runs for evidence |
| Fail path | Only if **this** Profile campaign FAILs → resume 7.7b / ADR-001 path |
| PASS path | Profile gate PASS → 7.7b–7.7d **N/A**; Release hang remains separate Known debt |

### Operational intensity (credibility — not a new numeric bar)

Prior **Release** campaign and early Profile diagnosis showed hangs under
**everyday / assertive** Manual scroll (including reverse, fast leave-page,
iCloud black pages kept scrolling) — not only gentle one-direction paging.

For 7.7a: intentionally exercise **similar intensity** (doomscroll / frame-out
then fling / mid-run reverse). On PASS, record credibility below.

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro (Kafka) |
| UDID | `00008110-001114420AEA801E` |
| OS under test | iOS 26.6 (23G71) |
| OS at ADR-001 baseline | iOS 26.5.2 (23F84) — different |
| Build mode | **Profile** |
| Git HEAD (tested) | `104d59d` (errata / 7.7a notes template on tree) |
| Date (local) | 2026-08-06 |
| Related invalidated campaign | `cap7-7.7-notes.md` (Release forensic) |
| Install commands used | `flutter build ios --profile` then `flutter install --profile -d 00008110-001114420AEA801E` |

---

## Instruments results (Profile)

### Videos

| Run | Window (s) | Hitch count | Hitch Total | Mean hitch (ms/s) | Severe Hang? | Gesture / intensity notes | Result |
|-----|------------|-------------|-------------|-------------------|--------------|---------------------------|--------|
| V1 | ≈86.9 | 3 | 25.00 ms | **≈0.29** | No | Doomscroll; frame-out then fling; mid-run reverse | **PASS** |
| V2 | ≈75.1 | 5 | 66.67 ms | **≈0.89** | No | Same intensity | **PASS** |
| V3 | ≈67.9 | 5 | 66.67 ms | **≈0.98** | No | Same intensity | **PASS** |

Videos surface: **PASS**

### All

| Run | Window (s) | Hitch count | Hitch Total | Mean hitch (ms/s) | Severe Hang? | Gesture / intensity notes | Result |
|-----|------------|-------------|-------------|-------------------|--------------|---------------------------|--------|
| A1 | ≈79 | 23 | 216.68 ms | **≈2.7** | No | Same intensity; iCloud-only pages kept scrolling | **PASS** |
| A2 | ≈70 | 55 | 575.04 ms | **≈8.2** | No | Same intensity | **PASS** |
| A3 | ≈94 | 21 | 183.35 ms | **≈1.9** | No | Same intensity | **PASS** |

All surface: **PASS**

---

## Gate verdict

| Field | Value |
|-------|--------|
| Videos 3/3 | **PASS** |
| All 3/3 | **PASS** |
| **Phase 7.7a (Profile hard gate)** | **PASS** |
| Intensity credibility (esp. if PASS) | **yes** — assertive doomscroll, reverse, fast leave; iCloud black pages not skipped |
| Next | **7.7b–7.7d N/A**; ADR-001 Fail path **not** taken; Release hang Known debt **remains**; proceed toward **Cap 7.8** |

---

## Owner sign-off

| Field | Value |
|-------|--------|
| Owner | Denny C. Gan |
| Date | 2026-08-06 |
| Comment | Profile V-hard 6/6 PASS under doomscroll intensity. Release forensic FAIL retained separately. |
