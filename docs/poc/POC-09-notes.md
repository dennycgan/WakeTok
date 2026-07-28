# POC-09 — Current Photos Representation Export Gate

Measurement and design notes. Append facts only; no rhetoric.

## Scope locks (owner Q1–Q7 = A, 2026-07-28)

| Lock | Choice | Meaning |
|------|--------|---------|
| **Q1** | A | Obtain via `requestAVAsset` + self-built `AVAssetExportSession` |
| **Q2** | A | `deliveryMode = .highQualityFormat` |
| **Q3** | A | Subtitles: preserved **or** cleanly absent PASS; garbled/partial FAIL |
| **Q4** | A | Slo-mo: export duration ≈ `PHAsset.duration` / Photos-displayed |
| **Q5** | A | Explicit fail: iCloud-only + `networkAccessAllowed=false` |
| **Q6** | A | Phases 9.1–9.7 as locked in STATE |
| **Q7** | A | Trim/slo-mo fixtures must already be **local** (no download dependency) |

Out of gate (owner): HDR color; rotation (system-handled).

Unedited happy path: smoke in **9.1**, not a separate phase.

### 9.2 acceptance threshold (notes only; not a CI hard-assert)

For Trim fixtures, “original obviously longer” means:

```
original.duration - current.duration > 2.0s
```

Record in manual notes; HUD may show advisory. Do **not** fail automated unit tests solely on this number.

## How to open the spike

```bash
flutter run --dart-define=POC09_SPIKE=true
```

Or: debug home → **POC-09** button (kDebugMode only).

## Fixture album (owner prepares)

Suggested album name: `WakeTok-POC09`

| ID | Content | Phase |
|----|---------|-------|
| F0 | Unedited short **local** video | 9.1 smoke |
| F1 | Photos-trimmed (know pre/post lengths) | 9.2 |
| F2 | Slow-motion (note if user set normal speed) | 9.3 |
| F3 | Video with default audio | 9.4 |
| F4 | Soft or burned-in captions (optional) | 9.5 |
| F5 | iCloud-only, not downloaded | 9.6 |

## Phase 9.1 checklist

- [x] Paths: `lib/spikes/poc_09/`, `ios/Runner/Spikes/POC09/`,
      `pigeon/spikes/poc_09/`, `docs/poc/POC-09-notes.md`
- [x] `version=.current`, `deliveryMode=.highQualityFormat`
- [x] Dual probe `.current` vs `.original` durations
- [x] Export current representation to temp file; report export duration
- [x] Dart HUD + duration helper unit tests
- [x] `flutter analyze` + `flutter test` + simulator iOS build
- [x] Manual: Auth → list → pick F0 → Probe+Export (unedited smoke)

### Manual (9.1)

| ID | Steps | Pass |
|----|-------|------|
| H1 | Open POC-09 → Authorize Photos | Status authorized/limited |
| H2 | List local videos; select one (F0) | Asset id + PH duration shown |
| H3 | Probe+Export (`networkAccessAllowed` as needed for local) | current/original/export durations; path or clear error |
| H4 | Unedited smoke: export plays / duration ≈ PHAsset.duration | No crash; sensible numbers |

Manual 9.1: **PASS** — owner 2026-07-28.
Screenshot: `auth=limited`; `ph=cur=orig=exp=37.48s`; `audio=1`;
`origLonger(>2s)=false`; export path set.

## Build / measure log

- 9.1: **PASS** — analyze/test/simulator OK; device H1–H4 (unedited smoke)
