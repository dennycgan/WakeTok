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

Work commit sha: e41440e
Docs commit sha: f2c005e

## POC-04: Flutter Media Feed Architecture Gate — completed 2026-07-28

- [x] 2.1 Create isolated spike scaffold (lib/spikes/poc_04/, ios/Runner/Spikes/POC04/,
      pigeon/spikes/poc_04/, docs/poc/POC-04-notes.md; debug-only entry)
      — work: `ddbbf70`
- [x] 2.2 Spike Pigeon + Photos authorization + list device-local PHAssets
      — work: `ed6a7d1`
- [x] 2.3 Minimal mixed vertical feed (Fit; image temp file; AVPlayer PV; pool 1+1)
      — work: `b1b8fda`
- [x] 2.4 ≥100 mixed transitions; pool+tmp bounded (Probe 30/100); iPhone 13 Pro + 17
      — work: `2eb95f8`
- [x] 2.5 Profile measure on iPhone 13 Pro: first-frame PASS (p90=93 ms);
      hitch gate adjusted to **< 25 ms/s + no Severe Hang** (ADR-001);
      hand PV 13–19 everyday feel; Hitch Probe HN≈38 upper bound; Texture escape failed
      — work/measure notes: `5cc0b9d`, `2c9fb59`
- [x] 2.6 iCloud-only + Network Link Conditioner — **skipped**; deferred to
      Production Main Browse Screen / feed
      — work: (none)
- [x] 2.7 Record Conditional Pass in DECISIONS.md (ADR-001 Accepted)
      — docs: `f1ca720` (content), `6157b22` (Accepted + anchor);
        on `main` cherry-picks: `577b586`, `21abaf0`

Docs close-out (STATE + PHASE_HISTORY): `1d24c57`

## POC-03: Lock-screen continuous playback gate — completed 2026-07-28

- [x] 3.1 Create spike harness in lib/spikes/poc_03/ +
      ios/Runner/Spikes/POC03/; minimal AVQueuePlayer + AVAudioSession(.playback)
      setup; playback must not depend on Flutter Widget being alive
      — work: `8ec6c47`
- [x] 3.2 Verify clip-to-clip auto-advance on lock screen:
      pre-queue next AVPlayerItem; confirm audio gap is imperceptible
      or acceptable between segments
      — work: `e152181`
- [x] 3.3 Verify audio interruption and recovery
      (phone call, Siri, other audio apps; session re-activates on return)
      — work: `8b5ce36`
- [x] 3.4 Verify Control Center metadata (Now Playing info + transport controls)
      and AirPods play/pause/next
      — work: `d71723a`
- [x] 3.5 Verify process termination stops playback;
      next foreground launch can attempt SessionCheckpoint recovery
      — work: `9568f7b`
- [x] 3.6 Record go / no-go in DECISIONS.md
      (ADR-002 Conditional Pass Accepted; anchor `9568f7b`)
      — docs: `8ba76aa`

Notes: `docs/poc/POC-03-notes.md`. Known debt → Production Background Audio
(WeChat/VoIP lock-home resume; iCloud interrupt; post-POC-09 physical-clip
queue verify).

## POC-09: Current Photos Representation Export Gate — completed 2026-07-29

- [x] 9.1 Spike harness + dual current/original probe + temp export;
      unedited smoke OK
      — work: `8fcac6c`
- [x] 9.2 Trim: export ≈ current; original longer; no silent original fallback
      — work: `ba72532`
- [x] 9.3 Slow-motion HFR: export duration matches Photos-displayed / PHAsset
      — work: `96e4a23`
- [x] 9.4 Default audio: track present + Play-export listen
      — work: `a4f2130`
- [x] 9.5 Subtitle scope: burned-in only; soft tracks out of scope (ADR-003)
      — docs (this close-out); no probe implementation
- [x] 9.6 Explicit failure: iCloud-only + network off → `inCloudUnavailable`
      (incl. 3164); controlGate ON; N1 local+OFF
      — work: `3883b8f`
- [x] 9.7 Record Pass (GO) in DECISIONS.md (ADR-004 Accepted; anchor `3883b8f`;
      ADR-003 Accepted same packaging)
      — docs: (this close-out commit)

Notes: `docs/poc/POC-09-notes.md`. Deferred (do not overturn Pass): slo-mo
pitch/frame-rate → Physical Clip Export Core; multi-audio UX → POC-07;
soft-sub → ADR-003 out of scope.
