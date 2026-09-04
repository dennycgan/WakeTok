# Cap 7 — Phase 7.7 Real-device feed acceptance notes

> Hard gate for production Main Browse vertical feed hitch / Severe Hang
> (STATE Phase 7.7 / ADR-014 Decision 7; pays ADR-001 Severe Hang debt).
> Owner acceptance on **iPhone 13 Pro** — result: **INVALIDATED as Profile hard
> gate** (errata 2026-08-06). Historical campaign label was **FAIL**; that
> **FAIL is not a valid ADR-014 Profile gate verdict** — see **Errata** below.
> Binding Profile retest = Cap **7.7a** (`cap7-7.7a-profile-retest-notes.md`).

## Errata (2026-08-06) — build mode violation

| Field | Value |
|-------|--------|
| What was recorded | Videos×3 + All×3 (tables below) |
| What notes claimed | **Profile** hard gate |
| What was actually installed | **`flutter build ios --release`** then **`flutter install --release -d 00008110-…`** |
| Rule violated | Procedure / ADR-014: **do not** use Release for the Profile hard gate |
| Why it happened | `flutter run --release` hangs on VM Service; owner used `build`+`install` to install, but kept the **`--release`** flag (habit from Cap 7.4/7.5). Profile does not need that workaround the same way (`flutter run --profile` works; preferred install path is still `build`+`install` **`--profile`**) |
| Effect on gate | **Profile hard-gate verdict INVALIDATED.** Tables kept as **Release forensic only** (real device evidence that Release can Severe Hang / hitch). Must **not** drive ADR-001 Fail path or Cap 7.7b as if Profile FAIL were proven |
| Correct install for Profile gates | `flutter build ios --profile` then `flutter install --profile -d 00008110-001114420AEA801E` |
| Next | Cap **7.7a** Profile retest (same V-hard rules). Cap **7.7b** paused until 7.7a |

**Do not delete the run tables.** They remain the Release campaign archive.

---

## Locked acceptance rules (2026-08-06 design)

| # | Choice |
|---|--------|
| Q1 | Residual video frame (flash of previous video): **observe only** in 7.7; rewrite existing Known debt `Picks it up` → Final real-device performance… hardening; **do not** fix in 7.7; **do not** accept as permanent product residue without later triage |
| Q2 | Instruments surfaces: **All** and **Videos** (both required) |
| Q3 | Per surface: **3** independent Runs; **every** Run must PASS the bar |
| Q4 | No iPhone 17 / Release secondary dataset **for the Profile hard gate** (Release forensic campaign below is accidental, not Q4 intent) |
| Q5 | Superseded by errata + 7.7a path — see STATE |
| V-gate | **V-hard**: All and Videos use the **same** hard bar |

**Hard bar (each Run):** Instruments Animation Hitches, **Profile**, mean hitch **&lt; 25 ms/s** **AND** **zero** Severe Hang in the evaluation window.

**Mean hitch formula (POC-04 / ADR-001):**  
`ms/s = Hitch Summary Duration (Total) ÷ recording window seconds`  
Do **not** use Avg Duration of individual hitches as the gate number.

**Orthogonal metrics (do not conflate):**

- **Hitch / Severe Hang** = timing (frame stalls). Gate PASS/FAIL.
- **Residual frame** = content (prior video’s last frame briefly visible while the next frame is on time). Q1=B — does **not** alone fail 7.7.
- If a Videos Run **fails** the hard bar, note whether the anomaly **roughly coincides** with a visible residual flash (see correlation column). That does not reclassify residual into Q1=A; it only preserves the forensic link.

**Confounding (mandatory honesty):** Even a **valid** Profile gate is **not** a pure chrome delta vs ADR-001 (chrome + iOS 26.6 vs 26.5.2). This file’s tables add a **third** confound: **Release vs Profile**.

**Scroll direction:** Kickoff / product Manual advance is **up and down**. Mid-run reverse scrolls are **in-scope**.

**Out of scope for 7.7 (original):** product code changes; Hitch Probe as gate; using Release **as** the Profile bar (violated — see Errata).

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro |
| Device name | Kafka (owner; same Cap 5.5 / 6.5 floor unit) |
| UDID | `00008110-001114420AEA801E` |
| **OS under test (this campaign)** | **iOS 26.6** (build **23G71**) |
| **OS at ADR-001 / POC-04 baseline** | **iOS 26.5.2 (23F84)** — **different** |
| Note vs STATE project facts | STATE lists “iPhone 13 (performance floor)”; this gate uses **iPhone 13 Pro** — notes are authoritative |
| **Build mode (actual)** | **Release** — see Errata (**not** Profile) |
| Build mode (claimed at fill time — wrong) | Profile |
| Surface | Full production chrome: top All / Photos / Videos + disabled Pools + bottom bar |
| Git HEAD (tested) | `42f46e8` (Cap 7.6 docs on `main`; includes resolve cache `14f28d7`) |
| Date (local) | 2026-08-06 |
| Approx. time since iOS 26.6 upgrade completed | Overnight upgrade prior to gate day; exact hours not recorded |
| Background activity note | Unknown / not specially verified quiet before campaign |
| Instruments | Animation Hitches (Responsiveness); attach **Runner** |
| Scroll style | Hand vertical flings, everyday force; **bidirectional allowed**; iCloud-only / black waiting pages **kept scrolling** (not skipped) |
| Access | Full Access |
| Run order | Videos V1→V3, then All A1→A3 |

### Pre-gate (automated)

| Check | Result |
|-------|--------|
| `flutter analyze` | Not re-run at Instruments session start (tree = `42f46e8`; Cap 7.6 suite was green at merge) |
| `flutter test` (incl. `test/architecture/`) | Same — not re-stamped at session start |

---

## Procedure (owner) — as executed (Release)

1. Installed via **`flutter build ios --release`** + **`flutter install --release`** (errata).
2. Instruments Animation Hitches → Attach Runner; separate Recording per Run.
3. Videos ×3 then All ×3; campaign continued to full 6 Runs after first hard-bar miss.
4. No Hitch Probe / no new product code for drive.
5. Campaign was recorded as FAIL and Fail path opened — **later invalidated** as Profile gate (Errata); Fail path **suspended** pending **7.7a**.

### Correct Profile install (for 7.7a and later Profile work)

**Preferred:**

```bash
flutter build ios --profile
flutter install --profile -d 00008110-001114420AEA801E
```

**Alternate:** `flutter run --profile -d 00008110-001114420AEA801E`  
(Do **not** use `--release` for Profile hard gates.)

---

## Instruments results — **Release forensic only** (not Profile hard gate)

### Videos (V-hard tables; Release build)

| Run | Window (s) | Hitch count | Hitch Total | Mean hitch (ms/s) | Severe Hang? | Residual flash seen? | If hard-bar fail: flash coincides with anomaly? | Gesture notes | Result |
|-----|------------|-------------|-------------|-------------------|--------------|----------------------|-------------------------------------------------|---------------|--------|
| V1 | 36 | 5 | 66.67 ms | **≈1.85** | No | Yes (every video transition) | n/a (PASS) | Hand down (typical) | **PASS** |
| V2 | 37 | 2 | 16.67 ms | **≈0.45** | No | Yes (every video transition) | n/a (PASS) | Hand down (typical) | **PASS** |
| V3 | 39 | 5 | 58.34 ms | **≈1.50** | **Yes** | Yes (every video transition) | Owner: residual is **always** present on every transition; **no** necessary link to this hang | Mid-window **reverse up** back toward first video (everyday Manual) | **FAIL** |

Videos surface (Release forensic): **FAIL** (V3 Severe Hang).

### All (Release forensic)

| Run | Window (s) | Hitch count | Hitch Total | Mean hitch (ms/s) | Severe Hang? | Gesture notes | Result |
|-----|------------|-------------|-------------|-------------------|--------------|---------------|--------|
| A1 | ≈74.7 | 69 | 2.99 s | **≈40.0** | **Yes** | Occasional mid-run reverse (up) | **FAIL** (hitch &gt;25 and Severe Hang) |
| A2 | ≈64.7 | 28 | 9.41 s | **≈145** | **Yes** | Occasional mid-run reverse (up); Max hitch ≈6.38 s | **FAIL** |
| A3 | ≈84 | 15 | 233.35 ms | **≈2.8** | **Yes** (long block ≈50–60 s region) | Occasional mid-run reverse (up) | **FAIL** (hitch would pass; Severe Hang fails) |

All surface (Release forensic): **FAIL** (3/3 hard-bar miss on Release).

### Reference (not a pass/fail row)

| Reference | Value |
|-----------|--------|
| ADR-001 / POC-04 PV hand (iOS **26.5.2**, Profile) | ≈13.2 / 19.2 / 32.7 ms/s (Run3 FAIL + Severe Hang) — spike bare feed |
| This file’s tables | Production chrome + iOS **26.6** + **Release** — not Profile gate |
| POC-04 Hitch Probe HN (not used as 7.7 gate) | ≈38 ms/s + Severe Hang under `animateToPage` — upper bound only |

---

## Residual frame observation (Q1=B; not a hard gate alone)

| Field | Value |
|-------|--------|
| Repro (source / gesture) | Videos (and video pages in All): swipe to next **or** previous video |
| How often | **Always** — every video→video transition shows a brief flash of the previous playing frame |
| Severity (owner one-liner) | One-frame (or brief) residual; noticeable but owner judges **orthogonal** to Severe Hang |
| Overlap with hard-bar failures | No necessary coincidence; residual present on PASS Runs (V1/V2) as well as FAIL Runs |
| Known debt action | Rewritten to Final real-device hardening (see STATE); orthogonal to hang |

---

## Soft checks (not hitch numbers)

| ID | Scenario | Result | Notes |
|----|----------|--------|-------|
| S1 | Cold start → Main Browse chrome visible | PASS | On **Release** install (errata) |
| S2 | Tab switch All ↔ Photos ↔ Videos resets toward queue head | PASS | smoke; Cap 7.6 already验收 |
| S3 | Videos item plays on-screen | PASS | |
| S4 | Portfolio: feed screenshot-able on device | PASS | local only; eligibility evidence exists; **Public scan still owner-only** |

---

## Gate verdict

| Field | Value |
|-------|--------|
| Videos 3/3 (Release forensic) | **FAIL** |
| All 3/3 (Release forensic) | **FAIL** |
| Historical phase label | **FAIL** (2026-08-06 fill) |
| **Profile hard-gate status** | **INVALIDATED** — see Errata; pending Cap **7.7a** |
| Fail path (ADR-001) | **Not taken** — Cap **7.7a** Profile PASS (`cap7-7.7a-profile-retest-notes.md`); was suspended after Errata |
| Evidence completeness | **Yes** — six Release Runs retained |

### Docs / process after errata

- [x] Errata recorded; tables retained as Release forensic
- [x] Cap **7.7a** Profile retest notes opened
- [x] Cap **7.7b** paused; Fail path suspended pending 7.7a
- [x] Known debt: Release hang row + Severe Hang retarget to 7.7a…

---

## Owner sign-off

| Field | Value |
|-------|--------|
| Owner | Denny C. Gan |
| Date | 2026-08-06 (campaign); errata 2026-08-06 |
| Comment | Original fill: V-hard FAIL both surfaces on device. Errata: build was **Release**, not Profile — Profile gate invalidated; proceed 7.7a. Residual always-on, orthogonal to hang. |
