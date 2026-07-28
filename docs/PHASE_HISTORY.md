# WakeTok — Phase History

Append-only archive of completed capability phase snapshots.
Each entry is appended in the docs commit (Commit 2) of the
capability's final phase. Never edit past entries.

---

## Project Bootstrap — completed 2026-07-28
- [x] 1.1 Reset docs/STATE.md + docs/DECISIONS.md to WakeTok skeletons
- [x] 1.2 Environment check: flutter --version + flutter doctor
- [x] 1.3 Scaffold: flutter create, preserve .gitignore, add pigeon/.gitkeep
- [x] 1.4 Smoke check: flutter analyze + launch on iOS simulator
- [x] 1.5 Root commit + push

Work commit sha: 68a56a3
Docs commit sha: 4a6a9fe

## POC-04: Flutter Media Feed Architecture Gate — completed 2026-07-28

- [x] 2.1 Create isolated spike scaffold (lib/spikes/poc_04/, ios/Runner/Spikes/POC04/,
      pigeon/spikes/poc_04/, docs/poc/POC-04-notes.md; debug-only entry)
      — work: `8bf2c92`
- [x] 2.2 Spike Pigeon + Photos authorization + list device-local PHAssets
      — work: `70032ee`
- [x] 2.3 Minimal mixed vertical feed (Fit; image temp file; AVPlayer PV; pool 1+1)
      — work: `c432bb0`
- [x] 2.4 ≥100 mixed transitions; pool+tmp bounded (Probe 30/100); iPhone 13 Pro + 17
      — work: `1a648a6`
- [x] 2.5 Profile measure on iPhone 13 Pro: first-frame PASS (p90=93 ms);
      hitch gate adjusted to **< 25 ms/s + no Severe Hang** (ADR-001);
      hand PV 13–19 everyday feel; Hitch Probe HN≈38 upper bound; Texture escape failed
      — work/measure notes: `10bd0c1`, `e5c4117`
- [x] 2.6 iCloud-only + Network Link Conditioner — **skipped**; deferred to
      Production Main Browse Screen / feed
      — work: (none)
- [x] 2.7 Record Conditional Pass in DECISIONS.md (ADR-001 Accepted)
      — docs: `2e249e0` (content), `573614b` (Accepted + anchor);
        on `main` cherry-picks: `3ff7f58`, `9ea6424`

Docs close-out (STATE + PHASE_HISTORY): `33267c1`
