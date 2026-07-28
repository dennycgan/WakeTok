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

## Phase 2.1 checklist

- [x] Isolated dirs: `lib/spikes/poc_04/`, `ios/Runner/Spikes/POC04/`, `pigeon/spikes/poc_04/`
- [x] Debug-only entry (dart-define and/or kDebugMode button); release home not permanently replaced
- [x] Placeholder screen compiles

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
