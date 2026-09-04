# POC-03 — Lock-screen continuous playback gate

Measurement and design notes. Append facts only; no rhetoric.

## Scope locks (owner P1–P6)

| Lock | Choice | Meaning |
|------|--------|---------|
| **P1** | A | Spike media = **bundle** short WAV fixtures (`clip_a/b/c.wav`) |
| **P2** | A | kickoff「iCloud Asset 下载中断」**out of POC-03**; debt → Production Background Audio |
| **P3** | B | Gap: lock-screen **subjective** + optional foreground probe **p90 &lt; 150 ms** (3.2+) |
| **P4** | A | Interrupt `shouldResume` → auto `play()` (3.3+) |
| **P5** | A | Cold start offers **Restore?**; **no auto-play** until user confirms (3.5+) |
| **P6** | A | `UIBackgroundModes` → `audio` in Info.plist (3.1) |

P7 (merge main docs into spike/poc): done before 3.1 coding.

## How to open the spike

```bash
flutter run --dart-define=POC03_SPIKE=true
```

Or: debug home → **POC-03** button (kDebugMode only).

## Phase 3.1 checklist

- [x] Spike paths: `lib/spikes/poc_03/`, `ios/Runner/Spikes/POC03/`,
      `pigeon/spikes/poc_03/`, `docs/poc/POC-03-notes.md`
- [x] `AVQueuePlayer` + `AVAudioSession(.playback)` on App-scoped host
- [x] Playback continues after Flutter route pop (not tied to Widget lifecycle)
      (dispose does not call stop; owner verifies M2 on device)
- [x] Bundle fixtures loaded by native `configureBundleQueue`
- [x] `UIBackgroundModes` includes `audio`
- [x] `flutter analyze` + `flutter test` + simulator iOS build

### Manual (3.1)

| ID | Steps | Pass |
|----|-------|------|
| M1 | Open POC-03 → Configure → Play | Audible tone |
| M2 | Pop spike page (or leave route); audio continues | Widget-independent |
| M3 | Pause / Play / Stop from spike UI (re-enter if needed) | Controls work |

Manual M1–M3: **PASS** — owner device 验收 2026-07-28
(Configure/Play audible; pop route audio continues; Pause/Play/Stop OK).

## Phase 3.2 checklist

Locks: P3=B (lock-screen subjective + foreground gap p90 &lt; 150 ms).

- [x] Keep ≥1 pre-queued `AVPlayerItem` ahead (circular bundle clips)
- [x] Record gap ms: item did-play-to-end → next `currentItem`
- [x] Dart HUD: `formatGapSummary` + Clear gaps
- [x] `flutter analyze` + `flutter test` + simulator build
- [x] Manual lock-screen ≥5 advances (subjective gap OK)
- [x] Foreground probe: n≥5 and p90 &lt; 150 ms (optional sentry; unlock after lock run)

### Manual (3.2)

| ID | Steps | Pass |
|----|-------|------|
| L1 | Configure → Play → **lock** phone | Audio continues |
| L2 | Listen ≥5 automatic clip advances | Auto-advance works |
| L3 | Subjective gap between clips | Imperceptible or acceptable |
| G1 | Unlock; gap HUD n≥5, p90&lt;150 (if samples collected) | Foreground sentry |

Manual 3.2: **PASS** — owner 2026-07-28 after lock→unlock.
Screen: `gap n=24 p50=4ms p90=4ms (PASS p90<150; foreground probe)`;
`playing=true` still; advances ≫5. Owner confirms L1–L3 OK.

## Phase 3.3 checklist

Locks: P4=A (`shouldResume` → auto `play()`). Owner gate **Q1=B** (2026-07-28):
PASS when interrupt ends and playback auto-resumes without tapping Play
(process awake via poll and/or returning to app). Lock-screen / iOS-home
resume **without** opening WakeTok is **Known debt** → Production Background Audio.

- [x] Observe `AVAudioSession.interruptionNotification`
- [x] On began: pause; remember wasPlaying
- [x] On ended + shouldResume + wasPlaying: reactivate session + play
      (background-task poll ~25s + foreground fallback)
- [x] HUD: `int=` flag/count + last summary line
- [x] `flutter analyze` + `flutter test` + simulator build
- [x] Manual interrupt + auto-resume (Q1=B)

### Manual (3.3)

| ID | Steps | Pass (Q1=B) |
|----|-------|-------------|
| I1 | Play → interrupt (call / Siri / other audio / WeChat) | Audio stops; HUD began |
| I2 | End interrupt | Auto play without tapping Play (poll and/or open app OK) |
| I3 | HUD | `ended shouldResume=true → auto play (…)` |
| — | Lock/home resume without opening app | **Not required** (debt) |

Manual 3.3: **PASS (Q1=B)** — owner 2026-07-28.
Other scenarios OK; WeChat video while locked: no lock/home resume;
open app → `auto play (poll 24)`; continues from pause point.

## Phase 3.4 checklist

- [x] `MPNowPlayingInfoCenter` title/artist/elapsed/duration/rate
- [x] `MPRemoteCommandCenter`: play / pause / toggle / next / previous
- [x] Next = `advanceToNextItem` + prequeue; previous = seek current to 0
- [x] HUD: `remote=` last command
- [x] `flutter analyze` + `flutter test` + simulator build
- [x] Manual: Control Center + AirPods

### Manual (3.4)

| ID | Steps | Pass |
|----|-------|------|
| N1 | Play → lock / Control Center | Title = clip id; artist WakeTok POC-03 |
| N2 | Pause / Play from CC or AirPods | Transport works; HUD `remote=` |
| N3 | Next from CC or AirPods | Advances clip; audio continues |

Manual 3.4: **PASS** — owner 2026-07-28.
Screenshot: `playing=true · #1/3 · clip_b · …` + `remote=next`; gap n=18 still PASS.
N1/N2 owner-confirmed (CC metadata + pause/play); N3 evidenced by HUD `remote=next` on clip_b.

## Phase 3.5 checklist

Locks: P5=A (cold start offers Restore?; no auto-play until confirm).

- [x] Persist SessionCheckpoint (clipId / positionMs / index / wasPlaying) to UserDefaults
- [x] Flush on play/pause/item/rate + willResignActive; clear on Stop / Dismiss
- [x] `getPendingCheckpoint` only when engine not configured (post-kill cold)
- [x] Spike Restore? dialog; Restore seeks + play; Dismiss clears
- [x] Dart helpers + unit tests (`poc_03_checkpoint.dart`)
- [x] `flutter analyze` + `flutter test` + simulator build
- [x] Manual: kill → silent; cold Restore? (K1–K3)

### Manual (3.5)

| ID | Steps | Pass |
|----|-------|------|
| K1 | Play → force-quit app | Audio stops (no zombie playback) |
| K2 | Relaunch → open POC-03 | Restore? dialog; **no** auto-play |
| K3 | Restore / Dismiss | Restore resumes near ckpt; Dismiss stays silent |

Manual 3.5: **PASS** — owner 2026-07-28 (K1–K3).
Force-quit silent; cold relaunch Restore? without auto-play; Restore/Dismiss OK.

## Phase 3.6 checklist

- [x] Draft ADR-002 Conditional Pass in chat; owner approved (1A/2A/3 + edits)
- [x] Append ADR-002 to `docs/DECISIONS.md` (anchor `9568f7b`, Accepted 2026-07-28)
- [x] Close-out STATE + PHASE_HISTORY; YOU ARE HERE → POC-09

## Acceptance map

| Phase | Auto | Manual gate |
|-------|------|-------------|
| 3.2 | gap probe unit + HUD | L1–L3 (+ G1 sentry) |
| 3.3 | interruption + bg poll | I1–I3 (Q1=B); lock/home debt |
| 3.4 | Now Playing + remote cmds | N1–N3 |
| 3.5 | checkpoint helper tests | K1–K3 (P5=A) |
| 3.6 | — | ADR-002 Conditional Pass |

## Build / measure log

- 3.1: M1–M3 PASS (2026-07-28)
- 3.2: **PASS** — lock→unlock; gap n=24 p50=4ms p90=4ms; L1–L3 owner OK
- 3.3: **PASS (Q1=B)** — auto resume via poll/foreground; WeChat lock/home = debt
- 3.4: **PASS** — owner 2026-07-28; HUD `remote=next` + clip_b; N1/N2 owner OK
- 3.5: **PASS** — owner 2026-07-28; K1–K3 (P5=A Restore?)
- 3.6: **PASS** — ADR-002 Conditional Pass Accepted (anchor `9568f7b`)
