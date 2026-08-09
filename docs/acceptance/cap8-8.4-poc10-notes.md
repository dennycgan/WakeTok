# Cap 8 — Phase 8.4 POC-10 device confirm notes

> Device gate for Presentation Metadata file-size Tier 3/4 paths already
> implemented in Cap 8.3 work `c0c04e1` (STATE Phase 8.4 / ADR-015).
> Owner acceptance — **PASS** 2026-08-09 (with M7 **N/A**).
>
> **Follow-up (2026-08-09 investigation; ADR-018 Accepted 2026-08-10 on
> work `4f4c825`):** numeric Tier 3 cross-check for M2, and M3 Live Photo
> size policy superseded by **ADR-018** (still-only Tier 4). See matrix
> notes below.

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
| M2 | Local video | **PASS** | Owner confirmed (local download present for gate). **Numeric follow-up (2026-08-09):** `IMG_0165.MOV` — Tier 3 `requestAVAsset` local URL file size **11,260,685** bytes (≈11.26 MB decimal); sole `PHAssetResource` type `.video` `requestData` matched the same byte count; iOS Photos Info showed **11.3 MB**. Confirms Tier 3 for this sample. An earlier magnitude mismatch against a third-party gallery display was attributed to that app’s incorrect size UI (separate AirDrop/mp4 case showed ~35× inflation vs Finder + Photos Info) — not a WakeTok Tier 3 defect. |
| M3 | Live Photo | **PASS** (8.4) / **superseded** | **8.4 gate:** dual nil size; `mediaKind=livePhoto` from basics call — PASS under then-binding ADR-015. **ADR-018 (Accepted 2026-08-10, work `4f4c825`):** Live Photo size is no longer dual nil; host uses Tier 4 still path (`requestImageDataAndOrientation` / `currentImageRepresentation`), same as ordinary images — does not sum `.pairedVideo`. Owner Overlay re-check: WakeTok displayed size matches iOS Photos Info and Mac Finder (decimal SI formatting). |
| M4 | iCloud-only video/image | **PASS** | Dual nil; no size-triggered download observed. Early Videos-source samples at `i=0` were iCloud-only (`bytes=nil`) as expected |
| M5 | Optional unavailable local data | — | Not required; skipped |
| M6 | Edited (Adjustment) image/video | **PASS** | Owner confirmed per ADR-W §3 (clear current-representation semantics or blank) |
| M7 | RAW + JPEG multi-resource | **N/A** | Owner library has no RAW+JPEG / ProRAW dual-original sample. **Not verified** that host returns dual nil for that class; ADR-W / ADR-015 multi-resource rule remains binding if such assets appear later |
| #15 | Photos Info magnitude (M1/M2) | **OK** | Non-blocking; order-of-magnitude check only. M2 later tightened with exact byte cross-check (see M2 note). |
| #14 | Browse qualitative hitch during metadata/size requests | **PASS** | Owner: no perceptible hitch |

---

## Verdict

**PASS** for Cap 8.4 device confirm of Tier 3/4 paths on available samples.
Residual: **M7 unverified** on this library (N/A). No host code change in the
original 8.4 close-out. Temporary probe discarded (never committed to `main`).

**Post-8.4:** M2 numeric Photos Info alignment recorded above; M3 Live size
policy updated by ADR-018 (still-only Tier 4; Accepted on work `4f4c825`).

Next at time of original 8.4 close-out was Cap 8.5 Overlay UI. Overlay + Live
still size shipped in work `4f4c825` (ADR-018).
