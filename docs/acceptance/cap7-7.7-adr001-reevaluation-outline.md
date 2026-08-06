# Cap 7.7 FAIL → ADR-001 re-evaluation discussion outline

> Triggered by Cap **7.7 FAIL** (2026-08-06).  
> Evidence: `docs/acceptance/cap7-7.7-notes.md`.  
> This is a **decision discussion**, not a coding task and not a new Conditional Pass.

## Why this discussion exists

ADR-001 (POC-04) **Conditional Pass** kept Flutter UI + Swift Platform View, with
**Severe Hang** as Known debt that **must** be triaged in **production feed**.
ADR-014 Decision 7 made Cap 7.7 the hard gate: production chrome, Profile,
mean hitch &lt; 25 ms/s **and** zero Severe Hang. Fail path = this re-evaluation —
**not** another Conditional Pass / Known debt that rewrites ADR-001.

Cap 7.7 attempted that triage on the production Main Browse feed and **failed**
the hard bar on **both** Videos and All (V-hard).

---

## Facts on the table (do not re-litigate measurement method here)

| Fact | Detail |
|------|--------|
| Device | iPhone 13 Pro Kafka; **iOS 26.6 (23G71)** |
| ADR-001 baseline OS | **iOS 26.5.2 (23F84)** — **different** |
| Build | Profile; full production chrome |
| HEAD | `dd40f53` |
| Videos | V1≈1.85 PASS, V2≈0.45 PASS, **V3≈1.50 + Severe Hang FAIL** |
| All | **A1≈40 FAIL**, **A2≈145 FAIL**, **A3≈2.8 + Severe Hang FAIL** |
| Phase | **7.7 FAIL** |
| Gestures | Hand only; **up and down** in-scope; V3 mid-run reverse; All×3 occasional reverse — **valid** |
| iCloud-only / black pages | Kept scrolling (not skipped) |
| Auto Hitch Probe | **Not used** (7.7 out of scope) |
| Residual frame | Always on video→video; owner: orthogonal to hang; Q1=B observe-only |

**Confounding (mandatory):** chrome **and** OS upgrade moved together vs POC-04.
Do not say “chrome alone caused X” without separating variables (often impossible
now that the device is on 26.6).

**Systemic vs one-off:** Six hand Runs; **four** hard-bar FAILs with Severe Hang
(V3, A1, A2, A3). V1/V2 show hitch can be very low **without** hang. Pattern
supports **intermittent but real** Severe Hang under everyday Manual scroll —
not a single polluted sample.

---

## What ADR-001 already rejected / allowed

Already rejected at POC-04 time (do not silently revive without new ADR):

- Hard-fail on hitch &lt; 5 alone → leave Flutter
- Default Texture path (measured worse)
- **Immediate** full SwiftUI rewrite **at Conditional Pass time** (deferred until
  production feed cannot clear Severe Hang)

Explicitly allowed trigger **now**:

- Production feed **cannot** clear Severe Hang after an explicit implementation
  attempt → **SwiftUI / all-native UI stack re-evaluation**

Cap 7.3–7.6 shipped production feed + chrome + resolve cache. Cap 7.7 is that
attempt’s measurement gate. It did not clear the debt.

---

## Decision questions for the owner (pick explicitly)

### D1 — Architecture direction

- **A.** Open a **time-boxed spike** to re-evaluate **SwiftUI / all-native** feed
  UI (keep Swift playback substrate where possible); Cap 7 remaining phases
  (7.8 accent / close-out) **paused or reshaped** until spike verdict.
- **B.** Stay on **Flutter + PV**; authorize a **bounded** production Severe Hang
  triage phase (new STATE capability or Cap 7 amendment) with explicit exit
  criteria — **without** calling 7.7 PASS / without Conditional Pass language.
- **C.** Hybrid: keep Flutter for chrome/settings; **native-only** vertical feed
  host (UIKit/SwiftUI Page/Scroll) behind a thin Flutter shell — requires new ADR.

### D2 — Status of Cap 7 Phase Roadmap

- **A.** Mark 7.7 **FAIL** in STATE; freeze 7.8 until D1 lands.
- **B.** Keep 7.7 open as `[~]` FAIL-evidence complete; block 7.8; same freeze.
- **C.** Other (owner write-in).

### D3 — Known debt rows (docs only after D1)

- Severe Hang (ADR-001 / Production Main Browse): **must not** be marked resolved.
  Update Reason / Picks it up to match D1 (e.g. “7.7 FAIL; see notes + this outline”).
- Residual frame: still rewrite `Picks it up` → Final real-device hardening
  (orthogonal; Q1=B) when next docs commit touches debt — independent of D1.

### D4 — Portfolio / Private→Public

- Eligibility (“screenshot-able feed”) is **met in soft sense** (S4), but
  **performance hard gate failed**. Public flip remains owner-only + privacy scan;
  recommend **not** treating 7.7 FAIL as portfolio green light for “demoable
  quality,” only for “surface exists.”

### D5 — Further measurement (only if D1 needs it)

- Do **not** add Hitch Probe inside “finish 7.7.”
- If the **re-evaluation spike** needs reproducible load, authorize probe **inside
  that spike’s scope** (separate ADR / STATE line), not retroactively as 7.7.

---

## Suggested discussion agenda (30–45 min)

1. Read Gate verdict + Videos/All tables in `cap7-7.7-notes.md` (5 min).
2. Agree confounding statement (chrome + iOS 26.6) (5 min).
3. Decide **D1** (architecture) — primary (15 min).
4. Decide **D2** (STATE roadmap freeze) (5 min).
5. Queue docs: notes already filled; STATE + debt updates after D1/D2 (5 min).
6. Explicitly reject: new Conditional Pass; “PASS if we ignore reverse scroll”;
   “PASS because V1/V2 hitch was low.”

---

## Non-goals for this discussion

- Rewriting Cap 7.7 hard bar after seeing FAIL numbers
- Declaring residual frame “fine forever” without triage
- Mixing Release hitch into the Profile gate
- Starting SwiftUI code **before** D1 is locked

---

## Owner lock (fill in meeting)

| ID | Choice | Date |
|----|--------|------|
| D1 | | |
| D2 | | |
| D3 | | |
| D4 | | |
| D5 | | |
| Notes | | |
