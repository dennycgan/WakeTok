# Cap 7 — Phase 7.7b Severe Hang diagnosis notes

> Attribute Severe Hang main-thread blocks (ADR-001 re-evaluation,
> diagnosis-first) **if** Cap **7.7a** Profile hard gate **FAIL**s.  
> **Status: PAUSED** pending Cap **7.7a** (`cap7-7.7a-profile-retest-notes.md`).  
> Cap **7.7** Profile gate was **INVALIDATED** (Release used — see
> `cap7-7.7-notes.md` Errata). Do **not** treat Release FAIL as Profile FAIL.

## Campaign status

| Field | Value |
|-------|--------|
| Status | **Paused** (2026-08-06) |
| Resume when | Cap **7.7a** Profile hard gate **FAIL** |
| Cancel / N/A when | Cap **7.7a** Profile hard gate **PASS** |
| Early Profile attempts | Two **D-A-high** sessions (correct Profile build) — hang **not** reproduced; **retain** as spare if 7.7a FAILs — do **not** discard |
| Do not run now | D-A-low / D-V-hang / D-idle (off-campaign until resume) |

## Locked rules (when resumed)

| # | Choice |
|---|--------|
| Q1 | STATE: 7.7 invalidated + 7.7a + 7.7b/c/d |
| Q2 | Sessions: **D-A-high**, **D-A-low**, **D-V-hang**, **D-idle** |
| Q3 | No temporary probes by default; ask owner if stacks unreadable |
| Q4 | ADR-015 only after **7.7d** — do **not** draft here |
| Q5 | Outline: D1 deferred; Fail path only after valid Profile FAIL |

**Tools:** Instruments **Time Profiler** + **System Trace**. Build: **Profile**
(`build`+`install --profile` preferred).

**Hard bar (unchanged; judged in 7.7a, not here):** mean hitch &lt; 25 ms/s AND zero
Severe Hang.

**Hypothesis under test (not presumed true):** hang often on **media load /
main-thread block**, including possibly **while not scrolling** (A3-like on
Release forensic). If stacks are Flutter raster / PV composition, SwiftUI
remains an open re-evaluation outcome.

**Priority when reading stacks:** (1) PhotoKit / `locallyAvailable` / request
paths (2) JPEG / `Image` decode (3) network / long sync I/O (4) PV attach /
1+1 pool (5) Flutter framework / raster.

**Out of scope while paused / in 7.7b:** product fixes (→ 7.7c); hard-bar retune;
Hitch Probe; ADR-015 Accepted; rewriting 7.7 Release tables.

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro (Kafka) |
| UDID | `00008110-001114420AEA801E` |
| OS under test | iOS 26.6 (23G71) |
| OS at ADR-001 baseline | iOS 26.5.2 (23F84) — different |
| Build mode | Profile |
| Git HEAD (diagnosed) | _fill when resumed_ |
| Date (local) | _fill_ |
| Related notes | `cap7-7.7-notes.md` (Release forensic + Errata); `cap7-7.7a-profile-retest-notes.md` |

---

## Sessions

### D-A-high — All, high hitch + hang (A2-like)

| Field | Value |
|-------|--------|
| Attempt 1 (pre-pause) | Profile; hang **not** captured — retain |
| Attempt 2 (pre-pause) | Profile; hang **not** captured — retain |
| Window / wall clock of hang | |
| Scrolling at hang? | |
| iCloud / black page visible? | |
| System Trace notes | |
| Time Profiler heaviest main stack (top frames) | |
| Classification | PhotoKit / decode / I/O / PV / Flutter / other / unclear |
| Result | _paused / captured / missed hang_ |

### D-A-low — All, low hitch + hang (A3-like)

| Field | Value |
|-------|--------|
| Window / wall clock of hang | |
| Scrolling at hang? | |
| Hitch context (if also recorded) | |
| Time Profiler heaviest main stack (top frames) | |
| Same family as D-A-high? | yes / no / unclear |
| Classification | |
| Result | _not started — paused_ |

### D-V-hang — Videos, with Severe Hang (V3-like)

| Field | Value |
|-------|--------|
| Window / wall clock of hang | |
| Scrolling / reverse? | |
| Time Profiler heaviest main stack (top frames) | |
| Same family as All hangs? | yes / no / unclear |
| Classification | |
| Result | _not started — paused_ |

### D-idle — no scroll 20–40 s (control)

| Field | Value |
|-------|--------|
| Surface | All / Videos |
| Duration still (s) | |
| Severe Hang while idle? | yes / no |
| If yes: stack summary | |
| Implication | If hang while idle → weakens “render pipeline can’t keep up”; strengthens load/timer/path-on-current-item. If no hang idle → focus on become-current / load window. |
| Result | _not started — paused_ |

---

## Cross-session synthesis

| Question | Answer |
|----------|--------|
| Dominant classification | |
| Idle hang supports load-path hypothesis? | |
| High vs low hitch hangs same stack family? | |
| Videos vs All same stack family? | |
| Evidence for / against Flutter raster as root? | |
| Evidence for / against PhotoKit sync on hot path? | |

### Diagnosis conclusion (attribution only — not a fix plan freeze)

_One short paragraph after resume + captures._

### Inputs to Cap 7.7c (suggested fix targets)

| # | Target | Rationale from stacks | Owner approve before code? |
|---|--------|----------------------|----------------------------|
| 1 | | | yes |
| 2 | | | |

---

## Explicit non-claims

- [x] Does **not** treat invalidated 7.7 Release FAIL as Profile gate FAIL
- [ ] Does **not** change hard bar
- [ ] Does **not** draft ADR-015
- [ ] Does **not** lock “keep Flutter” or “SwiftUI rewrite”

---

## Owner sign-off

| Field | Value |
|-------|--------|
| Owner | |
| Date | |
| Comment | Paused pending 7.7a. |
