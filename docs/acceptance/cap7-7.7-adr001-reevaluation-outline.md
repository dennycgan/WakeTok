# Cap 7.7 → ADR-001 re-evaluation discussion outline

> Evidence: `cap7-7.7-notes.md` (Release forensic + Errata),
> `cap7-7.7a-profile-retest-notes.md` (**Profile PASS**).  
> **Status (2026-08-06):** Cap **7.7a Profile V-hard PASS**. ADR-001 Fail path
> (**SwiftUI / all-native re-evaluation**) **not taken**. Cap **7.7b–7.7d N/A**.
> ADR-015 **not** required on this path. Proceed toward Cap **7.8**.
> Release hang remains a **separate** Known debt (shipping path).

## Why this file still exists

Records the errata + retest path so history is honest: a Release mis-build
looked like Profile FAIL, then a correct Profile campaign **PASSed**.

---

## Closed path

| Phase | Outcome |
|-------|---------|
| **7.7** | INVALIDATED as Profile gate (Release forensic retained) |
| **7.7a** | **PASS** — Videos+All ×3, doomscroll intensity yes |
| **7.7b–d** | **N/A** |
| **Fail path / D1** | **Not taken** |
| **ADR-015** | **Not drafted** (PASS path) |
| **7.8** | Next (accent + close-out; clear Profile Severe Hang debt row) |
| **Release hang debt** | Still open → Final real-device hardening |

---

## Profile 7.7a summary (binding)

| Surface | ms/s | Hang | Result |
|---------|------|------|--------|
| Videos | ≈0.29 / 0.89 / 0.98 | none | PASS |
| All | ≈2.7 / 8.2 / 1.9 | none | PASS |

Vs Release forensic (non-binding): Videos V3 + All A1–A3 had Severe Hang —
see `cap7-7.7-notes.md`.

---

## Owner lock

| ID | Choice | Date |
|----|--------|------|
| 7.7a | **PASS** | 2026-08-06 |
| Fail path | Not taken | 2026-08-06 |
| 7.7b–d | N/A | 2026-08-06 |
| Next | Cap 7.8 | 2026-08-06 |
