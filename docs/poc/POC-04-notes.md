# POC-04 — Flutter Media Feed Architecture Gate

Measurement and decision notes. Append facts only; no rhetoric.

## Scope locks (owner D1–D10)

- Live Photo Platform View: deferred (not in POC-04)
- Fit / Fill / 9:16: Fit only
- Background audio independent of Flutter widget: deferred to POC-03
- Pigeon: `pigeon/spikes/poc_04/` only
- Image bridge: temp file → Flutter `Image`
- Player pool: 1 active + 1 warming
- iCloud-only samples: owner confirms after phase 2.5

## How to open the spike (Phase 2.1+)

```bash
flutter run --dart-define=POC04_SPIKE=true
```

Or: debug session → default home → **POC-04** button (kDebugMode only).

## Phase 2.2 checklist

- [x] System Photos dialog appears on **Request Photos access** (first time)
- [x] Auth status shows `authorized` or `limited` after allow
- [x] **List local assets** returns only device-local image/video rows (count > 0 if library has local media)
- [x] Denied/restricted → list shows `unauthorized` error
- [x] Placeholder usage string visible in Settings (owner will replace before release)

Owner 验收: 2026-07-28 (device; Listed 100 after full access).

Local filter (host): `isNetworkAccessAllowed = false` + `PHImageResultIsInCloudKey` (image sync / video semaphore). Avoids `PHAssetResource.isLocallyAvailable` (SDK/OS gated). Prefer a real device with local media; simulator library may be empty.

## Phase 2.3 checklist

Locks: E1=A UiKitView+AVPlayerLayer; E2=A Open feed; E3=A maxLongEdge 1080; E4=A muted; E5=C HUD+mock tests+device leak probe.

**Gate order (required):** A1–A4 automation must all be green **before** any device M1–M8. Do not reverse.

Automation:
- [x] A1 `flutter analyze` + `flutter test` (incl. widget smoke)
- [x] A2 feed controller mock: mixed transitions respect pool 1+1 intents
- [x] A3 image temp release when leaving keep window
- [x] A4 `flutter build ios --simulator --debug --no-codesign`

Manual (only after A1–A4 green):
- [x] M1–M8 per design (feed Fit, video play/stop, pool HUD, leak probe, etc.)

Owner 验收: 2026-07-28 (device; muted video OK).

## Phase 2.4 checklist

Locks: G1=A (pool+tmp probe + Xcode Memory visual); G2=B (Probe 30 + Probe 100).
Gate device: **iPhone 13** (other devices smoke only).

### Boundedness semantics (for 2.7 ADR)

Under **E1=A** (UiKitView + AVPlayerLayer):

- There is **no** Flutter `TextureRegistry` texture id in this spike.
- “Textures bounded” for POC-04 **means**: Platform Views do not accumulate
  unboundedly across sustained scrolling **and** the AVPlayer pool stays ≤1 active
  + ≤1 warming.
- Automated probe asserts **pool ≤1+1** and **temp-file count bounded** only.
  It does **not** count live `UiKitView` instances (PageView.builder may keep a
  small neighbor cache). Non-accumulation of Platform Views is evidenced by
  builder dispose behavior plus **Xcode Memory** not climbing monotonically
  after Probe 100 (owner visual check).

Known issue (fixed in working tree): Probe 100 first run FAIL with
`poolMax=1+1 tmpMax=58` — duplicate `onPageChanged` (PageView + probe) orphaned
native temp files. Fix: probe owns paging; controller serializes+epoch; host
replaces temp per assetId.

### Automation (local)

- [x] `flutter analyze` + `flutter test` (incl. probe evaluator unit tests)
- [x] `flutter build ios --simulator --debug --no-codesign`

### Manual (after automation green)

Roadmap gate device remains **iPhone 13**; owner accepted 2.4 on **iPhone 17 smoke** (below). Re-run Probe 100 on iPhone 13 before treating 2.4 numbers as the go/no-go floor if 2.5 hitch/first-frame require it.

- [x] D1 Local mixed library; List → Open feed
- [x] D2 **Probe 100** → on-screen `PASS … (n=100)`
- [x] D3 Note `poolMax` / `tmpFirst10` / `tmpLast10` from summary (no monotonic tmp climb)
- [ ] D4 Xcode Memory (Debug): before vs after Probe 100 — no sustained staircase growth
- [x] D5 Manual scroll ~20 more — no crash, no dual audio (owner 验收)

Owner 验收: 2026-07-28 — Denny’s i17 Green; iOS 26.2 (23C55); Model iPhone 17; 256 GB.
Probe 100: `PASS poolMax=1+1 tmpMax=2 tmpFirst10=2 tmpLast10=2 (n=100)`.
Prior FAIL `tmpMax=58` attributed to duplicate onPageChanged; fixed before PASS.

### Devices

| Role | Device | iOS | Notes |
|------|--------|-----|-------|
| Gate (required) | iPhone 13 | | hitch + first-frame source of truth; **2.4 Probe 100 not yet re-run here** |
| Smoke | iPhone 17 | 26.2 | 2.4 Probe 100 PASS (owner 验收) |

## Build / measure log

(fill in phase 2.4–2.6)

- Build mode: Debug (`flutter run`)
- Duration: (Probe 100 ~1–2 min)
- Item count: listed ≤100 mixed local assets
- Tool: in-app Probe 100 + pool/tmp diagnostics
- Hitch (ms/s): (phase 2.5)
- Local-video first-frame p90 (ms): (phase 2.5)
- Active player / memory notes: poolMax 1+1; tmp stable at 2; D4 Xcode Memory not recorded
- Conditional escapes used (if any): none
- Phase 2.4 Probe 100 summary: `PASS poolMax=1+1 tmpMax=2 tmpFirst10=2 tmpLast10=2 (n=100)` on iPhone 17
- Phase 2.4 Xcode Memory note: not recorded

Pigeon: library + media bridge share one schema file (avoids duplicate Swift `PigeonError`):

```bash
dart run pigeon --input pigeon/spikes/poc_04/poc_04_photo_library.dart
```

## Decision draft (phase 2.7)

- Result: pass / conditional-go / no-go
- ADR draft: (chat → owner approve → DECISIONS.md)
