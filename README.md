# WakeTok

**A local-first vertical feed for rediscovering your own photo and video library.**

WakeTok is a local-first media Rediscovery Player, currently shipping for iOS.
The system Photos app is an archive and editor; it is not built for endless,
session-oriented rediscovery. WakeTok keeps media on-device (on iOS: PhotoKit /
iCloud as the system provides it), with Flutter for UI and Swift owning
playback and library I/O across a typed Pigeon boundary.

---

## Tech Stack

The stack is conventional Flutter-on-iOS. The interesting choices are at the
Flutter/Swift boundary: typed Pigeon Host/Flutter contracts, an exhaustive
wire `ErrorCode` ↔ Dart `AppError` map, and an app-scoped native player whose
lifetime is not tied to a Flutter route. Flutter was retained after POC-04 in
part to preserve a cross-platform UI option for a future Android version
(ADR-001); the Android media layer would need its own gate.

| Layer | Choice | Why |
|-------|--------|-----|
| UI | **Flutter / Dart** | Cross-platform UI option later; POC-04 Conditional Pass kept Flutter for the feed shell after measuring everyday scroll feel on device. |
| Native media (iOS) | **Swift + PhotoKit + AVFoundation** | Library access, authorization, and `AVPlayer` lifetime cannot live inside Flutter widgets if lock-screen audio and background advance must continue. |
| Bridge | **Pigeon (`PhotoLibraryApi` / `PlaybackApi`)** | Generated, typed Host/Flutter contracts; wire `ErrorCode` stays 1:1 with Dart `AppError` (ADR-008). |
| Video surface (iOS) | **UiKitView + `AVPlayerLayer` (Platform View)** | Production default after POC-04; Flutter Texture escape measured worse hitch and was rejected (ADR-001). |
| UI state | **Riverpod** | Composition-root `ProviderScope`; domain stays Riverpod-free (ADR-010). |
| Backend | **None** | No developer media server, custom auth, or remote DB; Photos / iCloud remain system-owned. |

---

## Core engineering challenge: Flutter feed performance on a real device

The product needs a TikTok-like vertical feed over the user’s own library.
The hard question was whether **Flutter UI + native iOS video** could meet a
measurable hitch budget on **iPhone 13 Pro** before any production domain layer.

**POC-04 (architecture gate).** The spike used Platform View (`UiKitView` +
`AVPlayerLayer`), a bounded 1+1 player pool, and image temp files. Instruments
Animation Hitches originally targeted **< 5 ms/s**. Everyday hand scrolling on
PV landed around **13–19 ms/s** and felt acceptable; the written bar was
**recalibrated to < 25 ms/s with no Severe Hang** so the gate matched
product-acceptable feel rather than an over-strict lab number (ADR-001).
First-frame (warming-assisted) **p90 ≈ 93 ms** passed a < 500 ms bar.

**Texture escape — rejected.** A Conditional path pushed frames through
`AVPlayerItemVideoOutput` → Flutter Texture. Hand hitch was **worse** than PV
(~33 / 64 ms/s). Texture was kept only as spike evidence, not the production
default.

**Conditional Pass + debt.** Normal hand scrolling on PV cleared the adjusted
bar; some runs and a programmatic Hitch Probe still showed **Severe Hang**.
That hang is accepted **known debt** for the production Main Browse / feed
capability — it did not overturn keeping Flutter + PV.

**ADR-006 — Platform View is a detachable surface.** Building on POC-04/POC-03
evidence, production **PlaybackApi** is an **app-scoped Swift** service:
Flutter sends plan/sync intent; it does not own `AVPlayer` lifetime. On
background, the layer **detaches** while audio continues; native
**AVQueuePlayer lookahead** advances the video-only plan. On foreground,
Dart `jumpToPage` then **adopts the existing player in place** (no
stop/recreate), under a **restore guard** so adopt cannot race a second
attach/release (that race SIGABRT’d the lock-screen feed probe).

---

## Implementation status

| Status | Capability |
|--------|------------|
| ✅ | **Project Bootstrap** — Flutter iOS scaffold, docs skeleton, `pigeon/` placeholder |
| ✅ | **POC-04** — Feed architecture gate; hitch bar recalibrated; Texture escape rejected (ADR-001) |
| ✅ | **POC-03** — Lock-screen continuous playback gate; native queue / Now Playing substrate (ADR-002) |
| ✅ | **POC-09** — Current Photos representation export gate (ADR-003 / ADR-004) |
| ✅ | **App Foundation** — gen_l10n, `Result`/`AppError`, production Pigeon baseline (ADR-006–008) |
| ✅ | **iOS Photos permission & library catalog** — auth UI, totals shell, `libraryTotals` / `fetchLibraryPage` (ADR-009–012) |
| 🔧 | **All / Photos / Videos source resolution** — next capability (phases TBD) |
| ⏳ | **Later roadmap** — Main Browse / feed, session domain, clip export, settings, hardening, release — see `docs/STATE.md` |

---

## Engineering process

I ship in phases with manual gates (`docs/STATE.md`); project rules in
`.cursor/rules/` keep AI-assisted sessions inside phase scope.

---

## Further reading

- **`docs/STATE.md`** — Current engineering snapshot, capability roadmap, and active phase pointer.
- **`docs/DECISIONS.md`** — Append-only ADR log (architecture gates, playback ownership, boundaries, localisation guards).

Private portfolio project — contact me for access or demo.

---

## License

No open-source license has been granted at this stage.
This repository is currently private; when made public, source will be
visible for portfolio and technical review purposes only.
