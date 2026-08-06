# Cap 7 — Phase 7.7b Severe Hang diagnosis notes

> Attribute Cap 7.7 Severe Hang main-thread blocks (ADR-001 re-evaluation,
> diagnosis-first). Does **not** rewrite 7.7 **FAIL** or the hard bar.  
> Result: **TBD** (fill after Instruments sessions).

## Locked rules (2026-08-06)

| # | Choice |
|---|--------|
| Q1 | STATE Phase Roadmap: 7.7 FAIL archived + 7.7b/c/d expanded |
| Q2 | Sessions: **D-A-high**, **D-A-low**, **D-V-hang**, **D-idle** |
| Q3 | No temporary probes by default; ask owner if stacks unreadable |
| Q4 | ADR-015 only after **7.7d** retest — do **not** draft here |
| Q5 | Outline updated: D1 deferred → diagnosis path |

**Tools:** Instruments **Time Profiler** + **System Trace** (and/or Hangs aligned
to wall clock). Build: **Profile**. Device: Kafka. Surface: full production chrome.

**Hard bar (unchanged; not re-judged in 7.7b):** mean hitch &lt; 25 ms/s AND zero
Severe Hang — see `cap7-7.7-notes.md`.

**Hypothesis under test (not presumed true):** hang often on **media load /
main-thread block**, including possibly **while not scrolling** (A3-like:
low hitch + Severe Hang). If stacks are Flutter raster / PV composition,
SwiftUI remains an open re-evaluation outcome.

**Priority when reading stacks:** (1) PhotoKit / `locallyAvailable` / request
paths (2) JPEG / `Image` decode (3) network / long sync I/O (4) PV attach /
1+1 pool (5) Flutter framework / raster.

**Out of scope:** product fixes (→ 7.7c); hard-bar retune; Hitch Probe;
ADR-015 Accepted; rewriting 7.7 FAIL.

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro (Kafka) |
| UDID | `00008110-001114420AEA801E` |
| OS under test | iOS 26.6 (23G71) |
| OS at ADR-001 baseline | iOS 26.5.2 (23F84) — different |
| Build mode | Profile |
| Git HEAD (diagnosed) | _fill_ |
| Date (local) | _fill_ |
| Related 7.7 FAIL notes | `cap7-7.7-notes.md` (`b45a318`) |

---

## Sessions

### D-A-high — All, high hitch + hang (A2-like)

| Field | Value |
|-------|--------|
| Window / wall clock of hang | |
| Scrolling at hang? | |
| iCloud / black page visible? | |
| System Trace notes | |
| Time Profiler heaviest main stack (top frames) | |
| Classification | PhotoKit / decode / I/O / PV / Flutter / other / unclear |
| Result | _captured / missed hang_ |

### D-A-low — All, low hitch + hang (A3-like)

| Field | Value |
|-------|--------|
| Window / wall clock of hang | |
| Scrolling at hang? | |
| Hitch context (if also recorded) | |
| Time Profiler heaviest main stack (top frames) | |
| Same family as D-A-high? | yes / no / unclear |
| Classification | |
| Result | |

### D-V-hang — Videos, with Severe Hang (V3-like)

| Field | Value |
|-------|--------|
| Window / wall clock of hang | |
| Scrolling / reverse? | |
| Time Profiler heaviest main stack (top frames) | |
| Same family as All hangs? | yes / no / unclear |
| Classification | |
| Result | |

### D-idle — no scroll 20–40 s (control)

| Field | Value |
|-------|--------|
| Surface | All / Videos |
| Duration still (s) | |
| Severe Hang while idle? | yes / no |
| If yes: stack summary | |
| Implication | If hang while idle → weakens “render pipeline can’t keep up”; strengthens load/timer/path-on-current-item. If no hang idle → focus on become-current / load window. |
| Result | |

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

_One short paragraph: what blocked the main thread; what is **not** supported._

### Inputs to Cap 7.7c (suggested fix targets)

| # | Target | Rationale from stacks | Owner approve before code? |
|---|--------|----------------------|----------------------------|
| 1 | | | yes |
| 2 | | | |

---

## Explicit non-claims

- [ ] Does **not** change 7.7 FAIL verdict
- [ ] Does **not** change hard bar
- [ ] Does **not** draft ADR-015
- [ ] Does **not** lock “keep Flutter” or “SwiftUI rewrite”

---

## Owner sign-off

| Field | Value |
|-------|--------|
| Owner | |
| Date | |
| Comment | |
