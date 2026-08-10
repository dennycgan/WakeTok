# Cap 9.6 — Playback Style observation matrix (POC-08 #7)

> **Not a product Style picker.** ADR-019 §10: system `PHLivePhotoView`
> default play-once (`.full`); variants are probed for POC-08, not edited
> (Do Not Build #19). Fill this table during **Cap 9.7** device acceptance.
>
> Cap 9.6 code keeps `startPlayback(with: .full)` only.

## Environment (fill in 9.7)

- Devices: iPhone 13 (floor) / iPhone 17 (compat)
- Run mode: Profile (preferred) / Debug
- Host: Cap 9.6 work sha `________`
- Mute: shared preference (library_smoke debug switch); default unmuted

## Matrix

| # | Asset type | Action | Expected | Result (9.7) | Notes |
|---|------------|--------|----------|--------------|-------|
| S1 | Ordinary Live Photo | Enter current → play-once | Full motion once → key still; audio follows mute | | |
| S2 | Loop edit (Photos) | Same | App still **once** (no Photos-style loop) | | |
| S3 | Bounce edit | Same | Completes once → key still | | |
| S4 | Long Exposure | Same | Plays or static fallback; no crash / no auto-skip | | |
| S5 | Other edited Live | Same | Motions or 9.5 static fallback; badge remains | | |

## Mute cross-check (POC-08 #4; brief)

| # | Steps | Expected | Result |
|---|-------|----------|--------|
| M1 | Default unmuted + Live play | Motion has audio | |
| M2 | library_smoke Mute on → return to Live / re-enter | Motion silent | |
| M3 | Mute on → Live → video | Video silent after clear/play | |

## Out of scope here

- Right-rail Mute / Share / Fit·Fill·Crop
- Persisted mute across process death
- Pigeon Playback Style selection API
