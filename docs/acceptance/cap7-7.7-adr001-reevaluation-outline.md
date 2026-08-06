# Cap 7.7 → ADR-001 re-evaluation discussion outline

> Evidence: `docs/acceptance/cap7-7.7-notes.md` (Release forensic + **Errata**),
> `docs/acceptance/cap7-7.7a-profile-retest-notes.md` (binding Profile gate).  
> **Status (2026-08-06 errata):** Cap 7.7 Profile hard-gate verdict
> **INVALIDATED** (campaign used **Release**). ADR-001 Fail path
> **suspended** until Cap **7.7a** Profile retest.  
> Architecture fork (**D1**) remains **deferred**. Not a Conditional Pass.

## Why this discussion exists

ADR-001 / ADR-014 require a **Profile** hard gate on production chrome. Cap 7.7
ran Instruments and recorded V-hard FAIL, then discovered the install was
**Release** — so that FAIL **cannot** open SwiftUI re-evaluation as a Profile
gate result.

Release tables are **kept** (forensic + Known debt). Binding next step = **7.7a**.

---

## Current path (locked after errata)

| Phase | Role |
|-------|------|
| **7.7** | Release forensic campaign + Errata — Profile gate **INVALIDATED** |
| **7.7a** | **Active** — Profile Videos×3 + All×3, same V-hard; intensity credibility |
| **7.7b** | Paused until 7.7a **FAIL**; early Profile D-A-high retained |
| **7.7c / 7.7d** | Only if 7.7a FAIL then diagnosis/fix path runs |
| **ADR-015** | Only after 7.7d if that path runs |
| **7.8** | After 7.7a settles (PASS → toward close-out; FAIL → after 7.7d/ADR-015) |
| **Release hang debt** | Separate Known debt (shipping path) — even if 7.7a PASSes |

**7.7a exits**

| 7.7a | Next |
|------|------|
| **PASS** (6/6) + intensity note filled | 7.7b–d **N/A**; Fail path **not** taken; keep Release hang debt; toward 7.8 |
| **FAIL** (any Run) | Resume **7.7b**; Fail path active again under **valid Profile** FAIL |

Partial surface miss = **FAIL** (V-hard). No third verdict for “maybe under-tested”;
if numbers PASS, record whether hang-trigger intensity was attempted.

---

## Facts on the table

| Fact | Detail |
|------|--------|
| Device | iPhone 13 Pro Kafka; **iOS 26.6 (23G71)** |
| ADR-001 baseline OS | **iOS 26.5.2 (23F84)** |
| 7.7 actual build | **Release** (`build`+`install --release`) — errata |
| 7.7 Release forensic | Videos V3 hang; All A1–A3 hang / high hitch — tables retained |
| Profile hard gate | **Pending 7.7a** |
| Early 7.7b | Two Profile D-A-high — hang not reproduced; paused |

**Confounding:** chrome + OS vs ADR-001; plus **Release vs Profile** for 7.7 tables.

---

## Decision questions

### D1 — Architecture — **DEFERRED** (until valid Profile FAIL + normally 7.7d)

Parked options A/B/C unchanged. Do **not** choose from Release-only FAIL.

### D2 — Roadmap — **LOCKED (errata)**

7.7 invalidated; **7.7a** active; 7.7b paused; 7.8 blocked on 7.7a settlement.

### D3 — Known debt

- Severe Hang (ADR-001): Picks it up → **7.7a → (if FAIL) 7.7b→c→d**
- **Release hang** (new): shipping-path forensic → Final real-device hardening
- Residual frame: Final real-device hardening (unchanged)

### D4 — Portfolio

Unchanged caution: surface exists ≠ quality green light.

### D5 — Measurement

- Profile gates: `build`+`install --profile` (preferred) or `run --profile`
- No Hitch Probe by default
- No `--release` for Profile hard gates

---

## Agenda (now)

1. Confirm Errata + INVALIDATED Profile verdict (2 min).
2. Run **7.7a** Profile V-hard (owner) — intensity credibility field.
3. Branch on 7.7a PASS vs FAIL (table above).
4. Only on FAIL: resume 7.7b stacks → 7.7c → 7.7d → ADR-015 → D1 if needed.

---

## Non-goals

- Treating Release FAIL as Profile gate FAIL
- Deleting Release forensic tables
- Lowering the hard bar
- Drafting ADR-015 before a closed Profile evidence chain
- Quietly dropping Release hang because it is “out of ADR gate scope”

---

## Owner lock

| ID | Choice | Date |
|----|--------|------|
| Errata | 7.7 Profile gate INVALIDATED; Release forensic retained | 2026-08-06 |
| Path | 7.7a first; 7.7b paused; Fail path suspended | 2026-08-06 |
| Q1–Q3 (errata design) | A / A / A + intensity credibility on 7.7a | 2026-08-06 |
| D1 | Deferred | 2026-08-06 |
