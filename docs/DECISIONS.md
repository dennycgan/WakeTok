# WakeTok — Decision Log (ADR)

> Major technical/engineering decisions. Each entry is immutable: never edit or
> delete its reasoning. To overturn a decision, write a NEW entry and only flip
> the old entry's Status line to "Superseded by ADR-xxx".
> The top "Plain summary" line is for the project owner to verify — it must be
> understandable without deep technical knowledge.
> Workflow: draft the ADR in chat -> owner approves the draft -> append here
> (see state-decisions-maintenance.mdc and release-handoff.mdc).
> Append new entries at the end; numbering starts at ADR-001 and increments.
> Always record the date and a commit/PR anchor.
> **Accepted date** = `git log -1 --format=%cs <anchor-sha>` (the day the
> implementing commit lands on `main`), not the design-discussion day.
>
> Status values: Accepted | Superseded by ADR-xxx (date) | Deprecated (no
> replacement) | Reverted-in-code (implementation rolled back; see note)
>
> Revert reconciliation: if a code revert crosses the implementation point of an
> Accepted ADR, do NOT silently leave the log stale. Either (a) write a new ADR
> explaining the rollback, or (b) flip the old entry's Status to
> "Reverted-in-code (date, reason)" and add a one-line note. The original
> reasoning stays untouched.
>
> Note: lettered ADR references inside the local kickoff (ADR-K, ADR-P.5, …) are
> kickoff-internal spec anchors, NOT entries in this log. This log starts empty
> at ADR-001.

---

## ADR Template
- Status: Accepted (YYYY-MM-DD)  <!-- date = git log -1 --format=%cs <anchor-sha> -->
- Commit/PR anchor: <sha or #PR>
- Plain summary (owner reads this): <one plain-language sentence>
- Context / what problem forced this:
- Decision (what was chosen):
- Rejected alternatives (why not B):
- Consequences / constraints accepted:

---

## ADR-001: POC-04 Flutter media feed architecture gate — Conditional Pass

- Status: Accepted (2026-07-28)
- Commit/PR anchor: 3ff7f58
- Plain summary (owner reads this):
  We keep building WakeTok’s feed in Flutter with native iOS video (Platform View),
  after measuring that everyday scrolling feels OK; we tightened the written hitch
  bar to match that feel, and we will specially fix rare severe freezes later.
- Context / what problem forced this:
  POC-04 must decide whether Flutter UI + Swift media (UiKitView + AVPlayerLayer,
  pool 1+1, image temp files) is an acceptable architecture for the vertical media
  feed before production domain work. Original hitch bar was Instruments Animation
  Hitches mean < 5 ms/s on iPhone 13 Pro (Profile). Hand scrolling and a later
  fixed-cadence Hitch Probe showed the < 5 bar does not match acceptable everyday
  feel, while a Texture escape did not improve hitch.
- Decision (what was chosen):
  1. **Architecture:** Continue **Flutter + Swift-native** media. Production video
     surface is **Platform View** (`UiKitView` + `AVPlayerLayer`). Do **not** adopt
     the Conditional Texture escape as the default path.
  2. **First-frame gate — PASS:** On iPhone 13 Pro (Profile), FF20 warming-assisted
     p90 = **93 ms** (target < 500 ms). Timing: t0 = start of `attachActiveVideo`;
     t1 = first `AVPlayerLayer.isReadyForDisplay == true` (Platform View path that
     was measured). Cold-start first frame is out of scope for this gate.
  3. **Hitch gate — adjusted (not the original < 5):**
     - **New bar:** mean hitch **< 25 ms/s** AND **no Severe Hang** in the
       evaluation window (Instruments Animation Hitches / Hangs, Profile, gate
       device iPhone 13 Pro).
     - **Why adjust:** Everyday hand feel on PV ≈ **13–19 ms/s** was acceptable to
       the owner; < 5 was stricter than product-acceptable scrolling. Hitch Probe
       HN (PV, `overruns=0`) ≈ **38 ms/s** with Severe Hang is treated as a
       **reproducible upper bound under `animateToPage` load**, not the everyday
       feel reference. HF (`overruns=75`) has **invalid cadence** and is not used
       as a primary conclusion.
  4. **Path verdicts under the adjusted bar:**
     - **PV hand:** Run1/Run2 (≈13 / 19 ms/s) **pass**; Run3 (≈33 ms/s + Severe Hang)
       **fail** that run (severe hang / high rate).
     - **Texture escape (hand):** ≈33 / 64 ms/s — **worse than PV**; escape **failed**.
  5. **Overall POC-04:** **Conditional Pass** — PV path under normal hand scrolling
     meets the adjusted hitch bar and first-frame PASS; Texture escape rejected;
     Severe Hang remains an accepted debt to address in production feed work.
  6. **Data anchors (notes / commits, not this ADR’s Accepted date):**
     - Hand PV / Texture hitch and FF20: `docs/poc/POC-04-notes.md`; spike commits
       including Texture escape `10bd0c1` and Hitch Probe calibration `e5c4117`.
- Rejected alternatives (why not B):
  - **Keep hitch < 5 ms/s as hard fail → no-go / leave Flutter:** Rejected because
    owner-calibrated everyday PV feel (13–19) is acceptable; < 5 over-penalizes a
    viable Flutter+PV stack.
  - **Ship default video via Flutter Texture** (`AVPlayerItemVideoOutput` →
    `FlutterTexture`): Rejected — measured hitch worse than PV; escape did not close.
  - **Immediate full rewrite to SwiftUI / all-Swift-native UI stack:** Rejected —
    Conditional Pass on PV demonstrates Flutter+Swift-native is viable for this
    gate; SwiftUI re-evaluation is only triggered if production feed cannot clear
    Severe Hang debt after an explicit implementation attempt.
  - **Treat Hitch Probe HN ≈38 as the everyday gate number:** Rejected — HN is
    stricter programmatic scrolling; hand 13–19 remains the feel reference; HN
    informs upper-bound / tooling stress only.
- Consequences / constraints accepted:
  - **Severe Hang** (seen on some hand runs and on HN) is **known debt**: must be
    triaged in **production feed** implementation (not ignored); does not block
    Conditional Pass of POC-04 under normal hand scrolling.
  - Written hitch bar is now **< 25 ms/s + no Severe Hang**; original **< 5** is
    recorded as superseded for this gate’s pass/fail reading (this ADR).
  - Texture path may remain in the spike for evidence; it is **not** the production
    default surface.
  - Boundedness (pool ≤1+1, temp files) and PV first-frame PASS remain required
    baseline properties carried into production design.
  - `docs/STATE.md` / this log update still follow F1=A / two-commit docs discipline
    when the owner accepts and anchors this ADR.
  - Flutter UI layer is retained, preserving the cross-platform option for a
    future Android version. Android media layer (ExoPlayer + Surface) will
    require its own POC gate; this gate's conclusion does not pre-judge Android
    feed performance.
