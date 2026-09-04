# Cap 9.7 — POC-08 device acceptance notes

> Device gate for Live Photo rendering / static fallback (POC-08 items 1–8)
> after Cap 9.1–9.6 implementation. Locked design: G1=A G2=A G3=A G4=A G5=A
> (+ #5 N/A if no iCloud-only Live; rapid leave/return stress blocks on
> mechanism failure).
>
> Owner acceptance — **PASS** 2026-08-11 (iPhone 17: P5–P7 / Style **N/A**).

## Locked acceptance rules (9.7 design)

| # | Choice |
|---|--------|
| G1 | iPhone 13 floor + iPhone 17 compat (full where samples exist) |
| G2 | Profile primary; Debug short session for Mute M2/M3 |
| G3 | Missing Style / edit samples → row **N/A**, not blocking |
| #5 | No iCloud-only Live sample → **N/A** (symmetric with G3) |
| G4 | Q7 jump: OK → PASS; no new Q7 debt this gate |
| G5 | ADR-019 append POC-08 Result; Status stays Accepted |
| Stress | Same Live rapid leave/return 3–5× — mechanism failure blocks verdict |

**Not in scope:** Right-rail Mute; Style product picker; Waiting for Media UI;
clearing pre-existing Known debt table rows.

---

## Environment

- Devices: **iPhone 13 Pro** (floor); **iPhone 17** (compat)
- Run mode: Flutter **Profile** (lifecycle / Q7 / Style / stress / iCloud);
  **Debug** (library_smoke Shared mute — `kDebugMode` only)
- Photos access: Full
- Host under test: Cap 9.6 `8fcd875` / docs `f7935b9`; mute host persist
  **`474fb6a`** (2026-08-11) during 9.7 after M3 FAIL on Videos
- Style matrix: `docs/acceptance/cap9-9.6-playback-style-matrix.md`

---

## POC-08 items 1–8

| # | Gate | Result | Notes |
|---|------|--------|-------|
| 1 | photoLive identity (badge / Overlay) | **PASS** | 13 Pro + 17 (P1–P4) |
| 2 | PHLivePhoto + full auto play-once | **PASS** | Both devices |
| 3 | Enter / leave / re-enter lifecycle | **PASS** | Both; stress 3–5× rapid leave/return **PASS** (no hang/crash/wrong audio/stuck PV) |
| 4 | Live audio ↔ global Mute | **PASS** | M1–M3 after `474fb6a`; see Style matrix Mute table |
| 5 | iCloud static-first + download/prepare observe | **PASS** (13 Pro) / **N/A** (17) | 13: offline uncached Live → still + badge, no skip/crash; spinner often invisible (fail too fast) — **UX-1** debt. 17: no iCloud storage / no iCloud library photos |
| 6 | Offline / fail → static fallback, no skip | **PASS** (13 Pro) / **N/A** (17) | Same offline session as #5 on 13 |
| 7 | Loop / Bounce / Long Exposure / edited Live | **PASS** (13 Pro S1–S5) / **N/A** (17) | 17 lacks Live edit samples for P5–P7. Loop/Bounce silent in Photos current representation — WakeTok matches (not mute bug) |
| 8 | Plugin vs native rationale | **PASS** (docs) | Self-built Pigeon + `waketok/live_photo_surface`; recorded in Cap 9.1 / ADR-019 — no new plugin spike |

### Q7

- Unload PV → key still: **功能 PASS**
- Subjective jump: **OK** (natural vs iOS Photos; **no** new Known debt row)

---

## Device split

| Check | iPhone 13 Pro | iPhone 17 |
|-------|---------------|-----------|
| P1–P4 lifecycle / Q7 / Overlay | PASS | PASS |
| Rapid leave/return stress | PASS | PASS |
| P5–P6 iCloud / offline | PASS (observe) | **N/A** (no iCloud photos) |
| P7 Style matrix | S1–S5 PASS | **N/A** (insufficient Live materials) |
| Mute M1–M3 | PASS (post-`474fb6a`) | Covered via shared host; 17 focused P1–P4 |

---

## Follow-ups → Known debt (this docs commit)

| ID | Item | Picks it up |
|----|------|-------------|
| **UX-1** | Offline/weak-net iCloud Live: preparing spinner may be zero-duration; later ensure brief visible spin-then-fail so users see “needs network” | Live chrome / iCloud feedback polish (not Waiting for Media product surface) |
| **UX-2** | LIVE badge + preparing spinner top-left overlaps status-bar time → move to **bottom-right** | Main Browse / Live chrome polish |

---

## Verdict

**PASS** for Cap 9.7 / POC-08 on available samples.

- iPhone 17 P5–P7 / Style **N/A** by sample absence (G3 / #5), not deferred work.
- Mid-gate fix: video mute host persist `474fb6a` (M3).
- Q7 jump OK — no new debt.
- ADR-019: POC-08 Result appended (Status remains Accepted).

Next: Cap **9.8** Cap 9 close-out (STATE Cap `[x]` + PHASE_HISTORY).
