# Cap 7 — Phase 7.7 Real-device feed acceptance notes

> Hard gate for production Main Browse vertical feed hitch / Severe Hang
> (STATE Phase 7.7 / ADR-014 Decision 7; pays ADR-001 Severe Hang debt).
> Owner acceptance on **iPhone 13 Pro** — result: **FAIL** (2026-08-06).

## Locked acceptance rules (2026-08-06 design)

| # | Choice |
|---|--------|
| Q1 | Residual video frame (flash of previous video): **observe only** in 7.7; rewrite existing Known debt `Picks it up` → Final real-device performance… hardening; **do not** fix in 7.7; **do not** accept as permanent product residue without later triage |
| Q2 | Instruments surfaces: **All** and **Videos** (both required) |
| Q3 | Per surface: **3** independent Runs; **every** Run must PASS the bar |
| Q4 | No iPhone 17 / Release secondary dataset |
| Q5 | On PASS with no product code: **single docs commit** (notes + STATE 7.7 `[x]` + residual debt row rewrite); Severe Hang Known debt row cleared only at **7.8** close-out. **On FAIL:** fill these notes + open ADR-001 re-evaluation (outline: `cap7-7.7-adr001-reevaluation-outline.md`); do **not** invent Conditional Pass; STATE/debt follow-up decided in that discussion |
| V-gate | **V-hard**: All and Videos use the **same** hard bar; either surface failing any Run → phase **FAIL** → ADR-001 SwiftUI / all-native re-evaluation discussion (no new Conditional Pass) |

**Hard bar (each Run):** Instruments Animation Hitches, **Profile**, mean hitch **&lt; 25 ms/s** **AND** **zero** Severe Hang in the evaluation window.

**Mean hitch formula (POC-04 / ADR-001):**  
`ms/s = Hitch Summary Duration (Total) ÷ recording window seconds`  
Do **not** use Avg Duration of individual hitches as the gate number.

**Orthogonal metrics (do not conflate):**

- **Hitch / Severe Hang** = timing (frame stalls). Gate PASS/FAIL.
- **Residual frame** = content (prior video’s last frame briefly visible while the next frame is on time). Q1=B — does **not** alone fail 7.7.
- If a Videos Run **fails** the hard bar, note whether the anomaly **roughly coincides** with a visible residual flash (see correlation column). That does not reclassify residual into Q1=A; it only preserves the forensic link.

**Confounding (mandatory honesty):** This gate’s Profile numbers are **not** a pure chrome delta vs ADR-001. At least two variables moved together: (1) full production chrome vs POC-04 bare spike feed; (2) device OS **iOS 26.6** vs ADR-001 baseline **iOS 26.5.2 (23F84)**. Do not attribute deltas to chrome alone.

**Scroll direction:** Kickoff / product Manual advance is **up and down**. Mid-run reverse scrolls are **in-scope** everyday interaction — not contamination. V3 and All×3 include reverse gestures; those Runs remain valid evidence.

**Out of scope for 7.7:** product code changes; Hitch Probe / `animateToPage` synthetic drive as gate; Release hitch mixed into the Profile bar; clearing ADR-001 Severe Hang Known debt row (→ 7.8 only if Cap 7 later PASSes that debt).

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro |
| Device name | Kafka (owner; same Cap 5.5 / 6.5 floor unit) |
| UDID | `00008110-001114420AEA801E` |
| **OS under test (this gate)** | **iOS 26.6** (build **23G71**) |
| **OS at ADR-001 / POC-04 baseline** | **iOS 26.5.2 (23F84)** — **different**; not the same environment |
| Note vs STATE project facts | STATE lists “iPhone 13 (performance floor)”; this gate uses **iPhone 13 Pro** — notes are authoritative |
| Build mode | **Profile** (`flutter run --profile`) — not Debug, not Release for the hard gate |
| Surface | Full production chrome: top All / Photos / Videos + disabled Pools + bottom bar |
| Git HEAD (tested) | `dd40f53` (Cap 7.6 docs on `main`; includes resolve cache `79f8c12`) |
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
| `flutter analyze` | Not re-run at Instruments session start (tree = `dd40f53`; Cap 7.6 suite was green at merge) |
| `flutter test` (incl. `test/architecture/`) | Same — not re-stamped at session start |

---

## Procedure (owner) — executed

1. Profile build on Kafka; Main Browse chrome confirmed.
2. Instruments Animation Hitches → Attach Runner; separate Recording per Run.
3. Videos ×3 then All ×3; on first hard-bar miss, campaign continued to full 6 Runs.
4. No Hitch Probe / no new product code for drive.
5. On FAIL: do not claim PASS; open ADR-001 re-evaluation outline (see Gate verdict).

---

## Instruments results

### Videos (V-hard; content type closest to ADR-001 PV hand / pure video)

| Run | Window (s) | Hitch count | Hitch Total | Mean hitch (ms/s) | Severe Hang? | Residual flash seen? | If hard-bar fail: flash coincides with anomaly? | Gesture notes | Result |
|-----|------------|-------------|-------------|-------------------|--------------|----------------------|-------------------------------------------------|---------------|--------|
| V1 | 36 | 5 | 66.67 ms | **≈1.85** | No | Yes (every video transition) | n/a (PASS) | Hand down (typical) | **PASS** |
| V2 | 37 | 2 | 16.67 ms | **≈0.45** | No | Yes (every video transition) | n/a (PASS) | Hand down (typical) | **PASS** |
| V3 | 39 | 5 | 58.34 ms | **≈1.50** | **Yes** | Yes (every video transition) | Owner: residual is **always** present on every transition; **no** necessary link to this hang | Mid-window **reverse up** back toward first video (everyday Manual) | **FAIL** |

Videos surface: **FAIL** (V3 Severe Hang; hitch alone on V3 would have passed &lt;25).

### All (V-hard; mixed stills + video — chrome + dilution context)

| Run | Window (s) | Hitch count | Hitch Total | Mean hitch (ms/s) | Severe Hang? | Gesture notes | Result |
|-----|------------|-------------|-------------|-------------------|--------------|---------------|--------|
| A1 | ≈74.7 | 69 | 2.99 s | **≈40.0** | **Yes** | Occasional mid-run reverse (up) | **FAIL** (hitch &gt;25 and Severe Hang) |
| A2 | ≈64.7 | 28 | 9.41 s | **≈145** | **Yes** | Occasional mid-run reverse (up); Max hitch ≈6.38 s | **FAIL** |
| A3 | ≈84 | 15 | 233.35 ms | **≈2.8** | **Yes** (long block ≈50–60 s region) | Occasional mid-run reverse (up) | **FAIL** (hitch would pass; Severe Hang fails) |

All surface: **FAIL** (3/3 hard-bar miss).

### Reference (not a pass/fail row)

| Reference | Value |
|-----------|--------|
| ADR-001 / POC-04 PV hand (iOS **26.5.2**) | ≈13.2 / 19.2 / 32.7 ms/s (Run3 FAIL + Severe Hang) — spike bare feed |
| This gate | Production chrome + iOS **26.6** — compare only with confounding stated above |
| POC-04 Hitch Probe HN (not used as 7.7 gate) | ≈38 ms/s + Severe Hang under `animateToPage` — upper bound only |

---

## Residual frame observation (Q1=B; not a hard gate alone)

| Field | Value |
|-------|--------|
| Repro (source / gesture) | Videos (and video pages in All): swipe to next **or** previous video |
| How often | **Always** — every video→video transition shows a brief flash of the previous playing frame |
| Severity (owner one-liner) | One-frame (or brief) residual; noticeable but owner judges **orthogonal** to Severe Hang |
| Overlap with hard-bar failures | No necessary coincidence; residual present on PASS Runs (V1/V2) as well as FAIL Runs |
| Known debt action | On Cap 7 close-out / FAIL follow-up docs: rewrite existing residual row `Picks it up` → Final real-device performance… hardening; Reason += “7.7 observe-only; see this notes file”. **Do not** clear as “accepted product residue” without triage. Not done in this FAIL fill alone unless owner’s FAIL docs commit includes it |

---

## Soft checks (not hitch numbers)

| ID | Scenario | Result | Notes |
|----|----------|--------|-------|
| S1 | Cold start → Main Browse chrome visible | PASS | Profile session |
| S2 | Tab switch All ↔ Photos ↔ Videos resets toward queue head | PASS | smoke; Cap 7.6 already验收 |
| S3 | Videos item plays on-screen | PASS | |
| S4 | Portfolio: feed screenshot-able on device | PASS | local only; eligibility evidence exists; **Public scan still owner-only** |

---

## Gate verdict

| Field | Value |
|-------|--------|
| Videos 3/3 | **FAIL** |
| All 3/3 | **FAIL** |
| **Phase 7.7** | **FAIL** |
| Fail path taken? | **Yes — ADR-001 SwiftUI / all-native re-evaluation discussion** (outline dated 2026-08-06) |
| Evidence completeness | **Yes** — Videos×3 + All×3 rows filled |

### Docs commit checklist (PASS only — N/A this campaign)

- [ ] ~~PASS path~~ — not applicable

### Docs / process on FAIL

- [x] This notes file filled (incl. OS under test vs ADR-001 baseline)
- [x] Discussion outline opened: `docs/acceptance/cap7-7.7-adr001-reevaluation-outline.md`
- [ ] Owner-directed STATE / Known debt updates after re-evaluation decisions (do **not** invent Conditional Pass; do **not** clear ADR-001 Severe Hang row as “paid”)

---

## Owner sign-off

| Field | Value |
|-------|--------|
| Owner | Denny C. Gan |
| Date | 2026-08-06 |
| Comment | V-hard FAIL on both surfaces. Bidirectional hand scroll in-scope. No Hitch Probe. Residual always-on, orthogonal to hang. Proceed to ADR-001 re-evaluation outline. |
