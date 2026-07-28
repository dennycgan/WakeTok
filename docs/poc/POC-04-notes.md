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

Profile (phase 2.5 gate build):

```bash
flutter run --profile --dart-define=POC04_SPIKE=true -d <device>
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

Known issue (fixed): Probe 100 first run FAIL with `poolMax=1+1 tmpMax=58` —
duplicate `onPageChanged` orphaned native temp files. Fix: probe owns paging;
controller serializes+epoch; host replaces temp per assetId.

### Automation (local)

- [x] `flutter analyze` + `flutter test` (incl. probe evaluator unit tests)
- [x] `flutter build ios --simulator --debug --no-codesign`

### Manual

- [x] D1–D3, D5 on iPhone 17 smoke and iPhone 13 Pro gate
- [ ] D4 Xcode Memory (optional; not recorded)

Owner 验收 (smoke): 2026-07-28 — Denny’s i17 Green; iOS 26.2 (23C55); iPhone 17; 256 GB.
Probe 100: `PASS poolMax=1+1 tmpMax=2 tmpFirst10=2 tmpLast10=2 (n=100)`.

Owner 验收 (gate device): 2026-07-28 — iPhone13pro Kafka; iOS 26.5.2 (23F84); Model iPhone 13 Pro; 256 GB.
Probe 100: `PASS poolMax=1+1 tmpMax=2 tmpFirst10=2 tmpLast10=2 (n=100)`.

### Devices

| Role | Device | iOS | Notes |
|------|--------|-----|-------|
| Gate | iPhone 13 Pro (Kafka) | 26.5.2 | 2.4 Probe 100 PASS; 2.5 hitch/first-frame source of truth |
| Smoke | iPhone 17 (Green) | 26.2 | 2.4 Probe 100 PASS; 2.5 compat smoke only |

## Phase 2.5 checklist

Locks: H1=C (hitch mean primary, p90 optional); H2=A Profile; H3=B N=20;
H4=A timeouts count in distribution; H5=C hand-scroll record + FF20 probe.

### Metric definitions (for 2.7 ADR)

- **Hitch:** Instruments Animation Hitches hitch time rate (ms/s) while scrolling
  mixed feed ≥30s or ≥50 page changes. Gate on **interval mean &lt; 5 ms/s**;
  record p90 if available. Flutter DevTools frames are auxiliary only (Platform View).
- **First-frame delay:** t0 = `attachActiveVideo` begin; t1 depends on surface:
  - Platform View: first `AVPlayerLayer.isReadyForDisplay == true`
  - Texture: first successful pixel via `FlutterTexture` / display-link frame
  p90 over N=20 local-video settles; target **&lt; 500 ms**. Timeout 3000 ms still
  **counts** (H4=A).
- **Important:** 首帧延迟 = 有 warming 加速后的感知延迟，非冷启动延迟.
  (First-frame latency is warming-assisted perceived delay, not cold-start delay.)

### 2.5 Profile results (iPhone 13 Pro Kafka, Platform View E1=A)

- Hitch Run1 ≈13.2 ms/s (541.71 ms / 41.0 s) — FAIL vs &lt;5
- Hitch Run2 ≈19.2 ms/s (475.04 ms / 24.7 s) — FAIL
- Hitch Run3 ≈32.7 ms/s (1.42 s / 43.5 s) + Severe Hang — FAIL
- FF20 PASS: `ff n=20 p50=76ms p90=93ms` (warming-assisted)

### Conditional escape: Texture (T1=B T2=A T3=A T4=A T5=A)

Locks / contract (implemented):
- Default surface: **Texture** (AppBar **→PV** / **→Tex** to A/B).
- Warming does **not** register a texture.
- `attachActiveVideo` returns textureId only after `FlutterTextureRegistry.register`.
- Dart shows black placeholder until id ≥ 0, then `Texture(textureId)`.
- Hitch pass still required mean &lt; 5 ms/s (T4=A). FF20 re-run planned (T5=A).

### 2.5 Profile results (iPhone 13 Pro Kafka, Texture)

- Hitch Run4 ≈33.3 ms/s (1.30 s / 39.0 s); count=68; avg=19.06 ms; **Max=233.35 ms** — FAIL
- Hitch Run5 ≈64.3 ms/s (2.38 s / 37.0 s); count=92; avg=25.82 ms; **Max=425.03 ms** + **Hangs** — FAIL
- Owner feel: worse than PV; occasional stuck page switch (matches Max hitch / Hangs).
- Texture FF20: **not run** (hitch already FAIL; T5 moot for escape close).

### Conditional escape verdict

- **Not closed.** Texture does **not** improve hitch vs PV; observed rates are **worse**.
- Likely cost: per-frame **CPU pixel copy** (`AVPlayerItemVideoOutput` → `CVPixelBuffer`)
  + Flutter engine texture upload (`textureFrameAvailable` / `copyPixelBuffer`), vs
  `AVPlayerLayer` compositing in the Platform View path.
- Both pre-authorized escapes (PV and Texture) fail the &lt;5 ms/s hitch gate.

### Automation (local)

- [x] `flutter analyze` + `flutter test` (incl. after Texture)
- [x] `flutter build ios --simulator --debug --no-codesign` (after Texture)

### Manual on iPhone 13 Pro (Profile)

- [x] P0–P3 Platform View baseline (hitch FAIL / FF PASS)
- [x] Texture hitch ≥30s (Run4/Run5) → mean **not** &lt; 5 ms/s — FAIL
- [ ] Texture FF20 (skipped; hitch FAIL closes escape)
- [ ] P5 iPhone 17 smoke (optional; skipped)

AppBar: **→PV/→Tex** · **P30** · **P100** · **FF20**

## Build / measure log

- Build mode: Profile (`flutter run --profile --dart-define=POC04_SPIKE=true`)
- Device: iPhone 13 Pro Kafka; iOS 26.5.2 (23F84)
- Tool: Instruments Animation Hitches (Responsiveness; Deferred; Attach Runner)
- Hitch mean (ms/s):
  - PV: ≈13.2 / 19.2 / 32.7 — FAIL
  - Texture: ≈33.3 / 64.3 — FAIL (worse)
- Hitch Max (Texture): 233 ms (Run4), 425 ms (Run5)
- Local-video first-frame p90 (ms): PV FF20 p90=93 (PASS); Texture FF20 not run
- Active player / memory notes: 2.4 poolMax 1+1; tmp stable at 2 (17 + 13 Pro)
- Conditional escapes used: Texture (T1–T5) — **did not close** hitch gate
- Phase 2.4 Probe 100 (iPhone 17): `PASS poolMax=1+1 tmpMax=2 tmpFirst10=2 tmpLast10=2 (n=100)`
- Phase 2.4 Probe 100 (iPhone 13 Pro): `PASS poolMax=1+1 tmpMax=2 tmpFirst10=2 tmpLast10=2 (n=100)`
- Phase 2.4 Xcode Memory note: not recorded
- Phase 2.5 overall hitch: **Fail** (both surfaces)

Pigeon: library + media bridge share one schema file (avoids duplicate Swift `PigeonError`):

```bash
dart run pigeon --input pigeon/spikes/poc_04/poc_04_photo_library.dart
```

## Decision draft (phase 2.7)

- **POC-04 overall: Fail** (hitch gate; both PV and Texture).
- Boundedness / FF20 (PV) were positive but do **not** override hitch Fail.
- Per Fail path: evaluate **SwiftUI / Swift-native** architecture alternatives
  (ADR draft in chat → owner approve → then `docs/DECISIONS.md`; not written yet).
- `docs/STATE.md` / DECISIONS stay out of work commits until owner gates (F1=A).
