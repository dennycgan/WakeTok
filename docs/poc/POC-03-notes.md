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

## Acceptance map (later phases)

| Phase | Auto | Manual gate |
|-------|------|-------------|
| 3.2 | gap probe unit + HUD | L1–L3 (+ G1 sentry) |
| 3.3 | — | call/Siri/other app; auto-resume (P4) |
| 3.4 | — | Control Center + AirPods |
| 3.5 | checkpoint DTO tests | kill → silent; cold Restore? (P5) |
| 3.6 | — | ADR go/no-go |

## Build / measure log

- 3.1: M1–M3 PASS (2026-07-28)
- 3.2: **PASS** — lock→unlock; gap n=24 p50=4ms p90=4ms; L1–L3 owner OK
