# Cap 9.6 — Playback Style observation matrix (POC-08 #7)

> **Not a product Style picker.** ADR-019 §10: system `PHLivePhotoView`
> default play-once (`.full`); variants are probed for POC-08, not edited
> (Do Not Build #19). Filled during **Cap 9.7** device acceptance.
>
> Cap 9.6 code keeps `startPlayback(with: .full)` only.
> Full POC gate notes: `docs/acceptance/cap9-9.7-poc08-notes.md`.

## Environment (9.7)

- Devices: **iPhone 13 Pro** (floor) — Style S1–S5 + Q7 done; **iPhone 17**
  (compat) — P1–P4 + stress only; Style P5–P7 **N/A** (no iCloud library /
  insufficient Live edit materials)
- Run mode: **Profile** (Style / Q7); **Debug** (Mute M1–M3 via library_smoke)
- Host: Cap 9.6 work `8fcd875` / docs `f7935b9`; mute persist **`474fb6a`**
- Mute: shared preference (library_smoke debug switch); default unmuted
- Q7 (play-once → unload PV → key still): **功能 PASS，jump OK** — returns to
  opening still; feels natural vs iOS Photos

## Matrix

| # | Asset type | Action | Expected | Result (9.7) | Notes |
|---|------------|--------|----------|--------------|-------|
| S1 | Ordinary Live Photo | Enter current → play-once | Full motion once → key still; audio follows mute | **PASS** (iPhone 13 Pro); **N/A** (17) | 13: play-once → key still; Q7 OK. 17: Style matrix not run (insufficient Live materials) |
| S2 | Loop edit (Photos) | Same | App still **once** (no Photos-style loop) | **PASS** (iPhone 13 Pro); **N/A** (17) | Once only (not Photos loop). **Audio:** Photos Loop current representation is silent; WakeTok matches — not a mute defect |
| S3 | Bounce edit | Same | Completes once → key still | **PASS** (iPhone 13 Pro); **N/A** (17) | Once → key still. **Audio:** Photos Bounce current representation is silent; WakeTok matches — not a mute defect |
| S4 | Long Exposure | Same | Plays or static fallback; no crash / no auto-skip | **PASS** (iPhone 13 Pro); **N/A** (17) | Met expectation on 13 |
| S5 | Other edited Live | Same | Motions or 9.5 static fallback; badge remains | **PASS** (iPhone 13 Pro); **N/A** (17) | Met expectation on 13 |

## Mute cross-check (POC-08 #4; brief)

| # | Steps | Expected | Result |
|---|-------|----------|--------|
| M1 | Default unmuted + Live play | Motion has audio | **PASS** | Ordinary Live has audio when unmuted |
| M2 | library_smoke Mute on → return to Live / re-enter | Motion silent | **PASS** | Debug shared-mute switch |
| M3 | Mute on → Live → video | Video silent after clear/play | **PASS** (after `474fb6a`) | Initially FAIL on Videos (host `setMute` lost on pendingPlay / new AVPlayer). Fixed by host-persisted `muted` + re-apply; owner retest **PASS**. Loop/Bounce silent assets are unrelated (see S2/S3) |

## Out of scope here

- Right-rail Mute / Share / Fit·Fill·Crop
- Persisted mute across process death
- Pigeon Playback Style selection API
