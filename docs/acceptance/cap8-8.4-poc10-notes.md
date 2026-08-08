# Cap 8 — Phase 8.4 POC-10 device confirm notes

> Device gate for Presentation Metadata file-size Tier 3/4 paths already
> implemented in Cap 8.3 work `c0c04e1` (STATE Phase 8.4 / ADR-015).
> Owner acceptance — **PASS** 2026-08-09 (with M7 **N/A**).

## Locked acceptance rules (8.4 design)

| # | Choice |
|---|--------|
| D1 | Temporary `library_smoke` presentation size probe (debug) for observation |
| D3 | Delete probe after gate (never landed on `main`; discarded after PASS) |
| D4 | PASS with no host fix → pure docs commit (notes + STATE); no new ADR |
| Matrix | M1–M4 mandatory; M6 edited; M7 RAW+JPEG (N/A if absent); #15 magnitude check non-blocking; #14 Browse hitch qualitative only |

**Not in scope:** Cap 7.7a hitch numbers; Overlay UI (8.5); Tier 1/`dataSize` spike; Tier 2 generated-clip size.

---

## Environment

- Device: owner iPhone (`00008110-001114420AEA801E`)
- Run mode: Flutter **debug** (Settings → Library smoke requires `kDebugMode`; `--profile` hides the entry)
- Photos access: Full
- Host under test: Cap 8.3 `c0c04e1` (`requestPresentationMetadata` /
  `requestPresentationFileSize`)
- Observation: temporary Presentation size probe (local uncommitted; removed
  after gate per D3=B)

---

## Matrix results

| # | Sample | Result | Notes |
|---|--------|--------|-------|
| M1 | Local still image | **PASS** | Example: `kind=image` `bytes=262925` `semantics=currentImageRepresentation`; Photos Info magnitude OK (non-blocking) |
| M2 | Local video | **PASS** | Owner confirmed (local download present for gate) |
| M3 | Live Photo | **PASS** | Dual nil size; `mediaKind=livePhoto` from basics call |
| M4 | iCloud-only video/image | **PASS** | Dual nil; no size-triggered download observed. Early Videos-source samples at `i=0` were iCloud-only (`bytes=nil`) as expected |
| M5 | Optional unavailable local data | — | Not required; skipped |
| M6 | Edited (Adjustment) image/video | **PASS** | Owner confirmed per ADR-W §3 (clear current-representation semantics or blank) |
| M7 | RAW + JPEG multi-resource | **N/A** | Owner library has no RAW+JPEG / ProRAW dual-original sample. **Not verified** that host returns dual nil for that class; ADR-W / ADR-015 multi-resource rule remains binding if such assets appear later |
| #15 | Photos Info magnitude (M1/M2) | **OK** | Non-blocking; order-of-magnitude check only |
| #14 | Browse qualitative hitch during metadata/size requests | **PASS** | Owner: no perceptible hitch |

---

## Verdict

**PASS** for Cap 8.4 device confirm of Tier 3/4 paths on available samples.
Residual: **M7 unverified** on this library (N/A). No host code change in this
close-out. Temporary probe discarded (never committed to `main`).

Next: Cap 8.5 Media Info Overlay UI + `FeedMediaRequestGate` staleness wiring.
