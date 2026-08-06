# Cap 7.7 FAIL → ADR-001 re-evaluation discussion outline

> Triggered by Cap **7.7 FAIL** (2026-08-06).  
> Evidence: `docs/acceptance/cap7-7.7-notes.md`.  
> **Status (2026-08-06):** Architecture fork (**D1**) is **deferred**.  
> Active path = **diagnosis first** (Cap **7.7b** → **7.7c** → **7.7d**), then
> close the re-evaluation in **ADR-015** only after 7.7d retest evidence exists.  
> Not a coding task in 7.7b (default). Not a new Conditional Pass.

## Why this discussion exists

ADR-001 (POC-04) **Conditional Pass** kept Flutter UI + Swift Platform View, with
**Severe Hang** as Known debt that **must** be triaged in **production feed**.
ADR-014 Decision 7 made Cap 7.7 the hard gate: production chrome, Profile,
mean hitch &lt; 25 ms/s **and** zero Severe Hang. Fail path = this re-evaluation —
**not** another Conditional Pass / Known debt that rewrites ADR-001.

Cap 7.7 attempted that triage on the production Main Browse feed and **failed**
the hard bar on **both** Videos and All (V-hard). That FAIL is **archived** and
must not be rewritten.

---

## Current path (locked 2026-08-06) — diagnosis before D1

| Phase | Role |
|-------|------|
| **7.7** | Hard-gate measurement — **FAIL** (done; notes frozen) |
| **7.7b** | Time Profiler / System Trace — attribute main-thread block |
| **7.7c** | Fix concrete root cause(s) from 7.7b |
| **7.7d** | Re-run Videos×3 + All×3 under **same** V-hard rules |
| **ADR-015** | Written re-evaluation conclusion — **only after 7.7d** |
| **7.8** | Accent + Cap 7 close-out — after ADR-015 path settled |

**Hypothesis (to test, not to presume):** A3 ≈2.8 ms/s with Severe Hang and
large All hitch variance suggest intermittent **media-load / main-thread block**,
not a uniformly slow render pipeline. **D-idle** (no scroll) is the key control.
If stacks land on Flutter raster / PV composition, **SwiftUI remains fully open**.

**Do not:** lower the hard bar now; invent Conditional Pass; draft ADR-015
before 7.7d; treat “future Android” as a reason to skip diagnosis.

---

## Facts on the table (do not re-litigate measurement method here)

| Fact | Detail |
|------|--------|
| Device | iPhone 13 Pro Kafka; **iOS 26.6 (23G71)** |
| ADR-001 baseline OS | **iOS 26.5.2 (23F84)** — **different** |
| Build | Profile; full production chrome |
| HEAD (7.7 campaign) | `dd40f53` (notes commit `b45a318`) |
| Videos | V1≈1.85 PASS, V2≈0.45 PASS, **V3≈1.50 + Severe Hang FAIL** |
| All | **A1≈40 FAIL**, **A2≈145 FAIL**, **A3≈2.8 + Severe Hang FAIL** |
| Phase 7.7 | **FAIL** (archived) |
| Gestures | Hand only; **up and down** in-scope |
| Auto Hitch Probe | **Not used** |
| Residual frame | Always on video→video; orthogonal to hang (Q1=B) |

**Confounding (mandatory):** chrome **and** OS upgrade moved together vs POC-04.

---

## What ADR-001 already rejected / allowed

Already rejected at POC-04 time (do not silently revive without new ADR):

- Hard-fail on hitch &lt; 5 alone → leave Flutter
- Default Texture path (measured worse)
- **Immediate** full SwiftUI rewrite **at Conditional Pass time** (deferred until
  production feed cannot clear Severe Hang)

Explicitly allowed:

- Production feed cannot clear Severe Hang after an explicit attempt →
  **SwiftUI / all-native re-evaluation discussion**

“Re-evaluation” may conclude **keep Flutter+PV and fix a concrete bug**, **or**
move to SwiftUI — **only after diagnosis + (if fixing) retest**. Premature
“keep Flutter” or “rewrite SwiftUI” both skip the required work.

---

## Decision questions

### D1 — Architecture direction — **DEFERRED**

Do **not** choose A/B/C until **7.7b** (and normally **7.7d**) evidence exists.

Previous options (parked, still valid later):

- **A.** Time-boxed SwiftUI / all-native feed spike
- **B.** Stay Flutter + PV; bounded hang triage (now expressed as 7.7b–7.7d)
- **C.** Hybrid native feed host behind Flutter chrome — new ADR

**Interim:** proceed **B-shaped work** (diagnose + fix + same-bar retest) without
locking “architecture forever keep Flutter.”

### D2 — Cap 7 Phase Roadmap — **LOCKED**

- 7.7 marked **FAIL** archived; **7.7b / 7.7c / 7.7d** expanded; **7.8 blocked**
  until 7.7d + ADR-015 path settled. (STATE updated with 7.7b kickoff docs.)

### D3 — Known debt

- Severe Hang: **not** resolved; Picks it up → **7.7b → 7.7c → 7.7d** (STATE).
- Residual frame: rewritten to Final real-device hardening (observe-only in 7.7).

### D4 — Portfolio / Private→Public

Unchanged: surface exists ≠ demoable quality green light after 7.7 FAIL.

### D5 — Further measurement

- No Hitch Probe inside 7.7 / 7.7b by default.
- Probes only if 7.7b stacks unreadable (owner-approved, separate ask).

---

## Agenda (updated)

1. Confirm 7.7 FAIL archived; hard bar unchanged (2 min).
2. Run / review **7.7b** sessions (D-A-high, D-A-low, D-V-hang, **D-idle**) (owner).
3. Fill `cap7-7.7b-hang-diagnosis-notes.md` — stacks + classification (owner + agent).
4. Only then scope **7.7c** fix from notes.
5. **7.7d** retest → then draft **ADR-015** → resume **D1** if still needed → **7.8**.

---

## Non-goals

- Rewriting Cap 7.7 FAIL or the hard bar after seeing numbers
- Declaring residual frame “fine forever” without triage
- Mixing Release hitch into the Profile gate
- Starting SwiftUI **or** declaring “keep Flutter forever” **before** 7.7b stacks
- Drafting ADR-015 before 7.7d

---

## Owner lock

| ID | Choice | Date |
|----|--------|------|
| Path | Diagnosis first (7.7b→c→d); D1 deferred; ADR-015 after 7.7d | 2026-08-06 |
| D1 | **Deferred** | 2026-08-06 |
| D2 | 7.7 FAIL archived + 7.7b/c/d expanded; 7.8 blocked | 2026-08-06 |
| D3 | Severe Hang → 7.7b…; residual → Final hardening | 2026-08-06 |
| D4 | (unchanged recommendation) | |
| D5 | No default probes / Hitch Probe | 2026-08-06 |
| Q1–Q5 (7.7b design) | A / B / A / A / A | 2026-08-06 |
