# Cap 7 — Phase 7.7a Profile hard-gate retest notes

> Binding **Profile** retest of Cap 7.7 hard bar after 7.7 campaign was
> **INVALIDATED** (Release build used by mistake — see `cap7-7.7-notes.md` Errata).
> Same V-hard rules as 7.7. Does **not** rewrite the Release forensic tables.
> Result: **TBD**.

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
| PASS path | Profile gate PASS → 7.7b–7.7d **N/A** (cancel/pause permanently unless new evidence); Release hang remains separate Known debt |

### Operational intensity (credibility — not a new numeric bar)

Prior **Release** campaign and early Profile diagnosis showed hangs under
**everyday / assertive** Manual scroll (including reverse, fast leave-page,
iCloud black pages kept scrolling) — not only gentle one-direction paging.

For 7.7a:

- Intentionally exercise **similar intensity** to those sessions (not a
  deliberately gentle “standardized” crawl).
- On **PASS**, fill the credibility field below: whether the campaign
  **attempted** to match previously hang-triggering patterns.
- This does **not** invent a third verdict. V-hard still decides PASS/FAIL
  from Instruments numbers. Partial surface FAIL (e.g. Videos PASS, All one
  miss) is simply **phase FAIL** under V-hard — no special branch.
- “Looked clean but may not have stressed the feed” must be called out in
  notes so a PASS is not later misread as under-tested.

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro (Kafka) |
| UDID | `00008110-001114420AEA801E` |
| OS under test | iOS 26.6 (23G71) |
| OS at ADR-001 baseline | iOS 26.5.2 (23F84) — different |
| Build mode | **Profile** (verify in Xcode/Flutter that install is Profile) |
| Git HEAD (tested) | _fill_ |
| Date (local) | _fill_ |
| Related invalidated campaign | `cap7-7.7-notes.md` (Release forensic) |
| Install commands used | _paste exact commands_ |

---

## Instruments results (Profile)

### Videos

| Run | Window (s) | Hitch count | Hitch Total | Mean hitch (ms/s) | Severe Hang? | Gesture / intensity notes | Result |
|-----|------------|-------------|-------------|-------------------|--------------|---------------------------|--------|
| V1 | | | | | | | |
| V2 | | | | | | | |
| V3 | | | | | | | |

Videos surface: **PASS / FAIL**

### All

| Run | Window (s) | Hitch count | Hitch Total | Mean hitch (ms/s) | Severe Hang? | Gesture / intensity notes | Result |
|-----|------------|-------------|-------------|-------------------|--------------|---------------------------|--------|
| A1 | | | | | | | |
| A2 | | | | | | | |
| A3 | | | | | | | |

All surface: **PASS / FAIL**

---

## Gate verdict

| Field | Value |
|-------|--------|
| Videos 3/3 | |
| All 3/3 | |
| **Phase 7.7a (Profile hard gate)** | **PASS / FAIL** |
| Intensity credibility (esp. if PASS) | Did this campaign attempt prior hang-trigger patterns (assertive scroll, reverse, fast leave, iCloud pages kept)? **yes / partial / no** — _one line_ |
| Next | If PASS → close 7.7b–d as N/A; keep Release hang Known debt; toward 7.8 (or Release triage). If FAIL → resume **7.7b** (keep existing Profile D-A-high attempts) |

---

## Owner sign-off

| Field | Value |
|-------|--------|
| Owner | |
| Date | |
| Comment | |
