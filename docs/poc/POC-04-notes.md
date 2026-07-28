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

Pigeon: library + media bridge share one schema file (avoids duplicate Swift `PigeonError`):

```bash
dart run pigeon --input pigeon/spikes/poc_04/poc_04_photo_library.dart
```

## Devices

| Role | Device | iOS | Notes |
|------|--------|-----|-------|
| Gate (required) | iPhone 13 | | hitch + first-frame source of truth |
| Smoke | iPhone 17 | | compat only |

## Build / measure log

(fill in phase 2.4–2.6)

- Build mode:
- Duration:
- Item count:
- Tool:
- Hitch (ms/s):
- Local-video first-frame p90 (ms):
- Active player / memory notes:
- Conditional escapes used (if any):

## Decision draft (phase 2.7)

- Result: pass / conditional-go / no-go
- ADR draft: (chat → owner approve → DECISIONS.md)
