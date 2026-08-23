# Cap 15.11 — Shared PV transition guard (393 settle + peek)

> **Status: CLOSED (2026-08-23).** Device PASS Kafka + i17 —
> `cap15-15.11-notes.md`. Debt **393** closed in STATE. Work `c8a59b3` /
> ADR-032. Cap 15 continues → **15.12** (local first-visit skip L1,
> design pending) → **15.9** close-out.
>
> **Problem (Cap 15 intent):** doom-scroll base UX — eliminate visible **shared
> Platform View residue** during video handoff. Kafka 15.10 confirmed one
> ADR-006 pool family, **two phases:**
>
> | Phase | Symptom | Mechanism hint |
> |-------|---------|----------------|
> | **Peek** | Entering half shows blur poster → **black gap** (no content) | Neighbor page has **poster only** (no UiKitView until `isCurrent`); poster/Image stack can drop a frame |
> | **Settle** | ~0.5 s **previous** picture + sound at same progress → snap to B | Single `PlaybackSurfaceView` still bound to **A's player** until attach completes; audio leaks before pixels switch |
>
> **Same family** as STATE debt 393, Cap 7.7 observe-only, 13.6b ghost-frame
> notes. **One fix track**, not parallel debts.
>
> Locked owner direction (unchanged): Dart poster **cover + mute** first;
> **Host attach-ack** for trustworthy unwrap; overturn ADR-031 Q3=B / 1+1 pool
> only if this track fails (**owner re-board**).

---

## Goal / non-goals

| | |
|---|---|
| **Goal** | Video→video handoff (local playable pair primary): **peek window** no visible black gap on entering page; **settle window** no previous picture and **no previous audio**; after unwrap **B** plays correctly. |
| **Non-goals** | Do not change Q3=B / 1+1 pool / single Platform View architecture in v1. Do not fix **400** (no poster — cover N/A). Do not fix **395** playhead. Do not use `onSurfaceReady` / `notifyDisplaySurfaceReady` as unwrap trust points. |

---

## Feasibility (locked — do not re-debate)

| Layer | Verdict |
|-------|---------|
| **Dart opaque cover** | **Required.** Poster (Layer 1 JPEG) stacked **above** any future UiKitView on the **entering** page. Must mount **before** peek visibility, not only at `isCurrent`. |
| **Mute** | **Required.** Mask without mute fails acceptance (15.8 / 15.10: audio leak ~0.5 s). Mute the **active** `AVPlayer` on the shared surface for the whole guard window. |
| **Unwrap trust** | **`onSurfaceReady` / `notifyDisplaySurfaceReady` insufficient** (surface mounted ≠ pixels/audio for new id). **v1 ships Host attach-ack** at `surfaceView.attach(player:)` for the **current plan id**. |
| **Knife 3 (readyToPlay / first frame)** | **Deferred** to 15.11b only if Kafka still fails after attach-ack. |

---

## Architecture — feed-scoped `PvTransitionGuard`

New coordinator (Riverpod, `lib/app/browse/` or `lib/features/main_browse/` —
follow ADR-010: feature holds logic, Host via repository):

```
VerticalMediaFeed (scroll listener)
  → PvTransitionGuardNotifier.arm / disarm
  → PlaybackRepository.setTransitionAudioSuppressed(true|false)
  → each MediaFeedPage reads guard.isCovering(assetId)
```

### Guard states

| State | Meaning |
|-------|---------|
| `idle` | No cover, audio unsuppressed |
| `armed` | Scroll detected video handoff toward `targetAssetId`; mute ON; target page mounts cover |
| `awaitingAck` | Target became `isCurrent`; waiting Host attach-ack for `targetAssetId` |
| (returns to `idle`) | Ack received, or cancel/timeout/disarm |

Generation: bind to `_activation.currentDisplayGate.generation` + `feedIndex` so stale acks never unwrap.

---

## Mount / unmount timing (peek + settle — explicit)

### When to **arm** (mount cover + mute ON)

All must hold:

1. **Scroll signal:** `PageController.page` offset moved **> ε** (ε = 0.02 page) from settled index — i.e. user is actively dragging, **before** `onPageChanged` fires.
2. **Leaving item A:** index `feedIndex` is **video** with Layer 1 **poster** (`media.display != null`) and playback has reached **surface-ready** (or L2 in-flight on a revisiting token — still a video handoff).
3. **Entering item B:** the index being scrolled toward (`feedIndex ± 1`) is a **video-capable** page with Layer 1 poster (same 400 N/A rule).

**Actions on arm (same frame):**

- `PlaybackRepository.setTransitionAudioSuppressed(true)` → Host sets `activePlayer.isMuted = true` **without** changing persisted user mute preference (`muted` flag); warming player muted too.
- Guard records `targetAssetId`, `targetFeedIndex`, `displayGeneration`.
- **Entering page B** (currently `isPreheatNeighbor` or about to be): mount **`_PvTransitionCover`** — full-screen **opaque** `Image.file` of B's poster at Stack **top** (above poster slot + above UiKitView when it later mounts). Independent of 15.7 leave-side poster retention.

**Why not wait for `isCurrent`:** Kafka 15.10 proved black gap and wrong content appear **while B is still neighbor-only** (UiKitView not mounted on B). Cover must be up during **peek overlap**.

### When to **keep** cover

- From arm through attach-ack (or failure timeout).
- When B flips `isCurrent` and UiKitView mounts: cover **stays** (masks shared PV residue during attach).

### When to **disarm** (remove cover + restore audio)

**Primary trust point — Host attach-ack:**

- New `PlaybackFlutterApi.onPlaybackSurfaceAttached(PlaybackSurfaceAttachedDto)` fired on main queue **immediately after** `surfaceView.attach(player:)` when:
  - `player != nil`
  - attached player's asset id == `currentAssetIdentifier`
  - site: `adoptPreparedPlayer` (post-load attach) **and** `adoptActivePlayerOntoSurface` (re-adopt path)

Dart unwrap only when:

```text
ack.assetIdentifier == guard.targetAssetId
&& ack.feedIndex == guard.targetFeedIndex
&& guard.displayGeneration == current display generation
```

Then: remove cover, `setTransitionAudioSuppressed(false)` → Host `applyMuteToPlayers()` (respect user mute), call existing `play()` / `_syncPlaybackActive()` for B.

**Forbidden unwrap triggers:** `onSurfaceReady`, `finishLoad` return, fixed delay alone, generation bump alone.

**Failure / cancel paths (must not permanent mute or stuck cover):**

| Event | Action |
|-------|--------|
| User scrolls back to A (page offset returns near integer on A) | Disarm without ack; unmute |
| Leave-current / cancel prepare on target | Disarm |
| **Timeout** 2000 ms after `isCurrent` without ack | Disarm + unmute + log (degraded — may flash; hard fail if repeatable) |
| Load failure on B | Disarm; normal failure UI |

---

## Host changes (v1 — attach-ack)

| File | Change |
|------|--------|
| `pigeon/waketok_platform_apis.dart` | Add `PlaybackSurfaceAttachedDto { assetIdentifier, feedIndex, clearEpoch }`. Add `PlaybackFlutterApi.onPlaybackSurfaceAttached`. Add `PlaybackApi.setTransitionAudioSuppressed(bool)` — temporary mute for guard; does not persist `muted`. |
| `ios/Runner/Platform/PlaybackApiHost.swift` | Implement suppress API. After each qualifying `attach(player:)`, invoke Flutter ack with current ids + `clearEpoch`. |
| `lib/platform/playback_gateway.dart` | Wire ack stream + suppress API. |
| `lib/domain/playback/playback_repository.dart` | Interface methods. |

**No pool / Q3 changes in 15.11a.**

---

## Dart UI changes

| File | Change |
|------|--------|
| `vertical_media_feed.dart` | Scroll listener on existing `NotificationListener` → arm guard using fractional `page`. Pass `transitionCoverActive` into `MediaFeedPage`. |
| `vertical_media_feed.dart` (`MediaFeedPage`) | When `guard.isCovering(assetId)`, insert `_PvTransitionCover` above `_mediaStack` children. Cover uses same poster path as Layer 1 (not a second network fetch). |
| New `pv_transition_guard.dart` | Notifier + provider (Session-scoped or feed-scoped; clear on Browse leave). |

**15.7 invariant preserved:** leave-side poster on A unchanged; cover is **entering-side only**.

---

## Test plan

### Automated

| ID | Test |
|----|------|
| W-15.11a | Scroll offset arms guard → cover widget key on target page while `isPreheatNeighbor` |
| W-15.11b | Arm → `setTransitionAudioSuppressed(true)`; ack → false + cover removed |
| W-15.11c | Stale ack (wrong id / generation) does not unwrap |
| W-15.11d | Timeout / scroll-back disarm → unmute even without ack |
| Arch | No new `lib/features` → platform/generated imports |

### Device (Kafka Profile — primary matrix)

**Setup:** Full, Wi‑Fi, Optimize ON, Videos, **local→local** consecutive pair (same as 15.10 repro).

| # | Criterion | Pass |
|---|-----------|------|
| 1 | **Peek:** entering half shows poster/cover — **no black gap** | Visual |
| 2 | **Settle:** **no** previous video picture visible | Visual |
| 3 | **Settle:** **no** previous audio audible (0 leak default) | **A/V joint** — owner ear + eye |
| 4 | After unwrap: B plays from start; not stuck on poster | Visual |
| 5 | No permanent mute after 10 handoffs | Functional |
| 6 | 15.7 peek poster on leave **no regression** | Spot check |

**Fail gate for 15.11a:** any of 1–3 fails stably on local→local pair.

**15.11b (only if needed):** add `AVPlayerItem.status == .readyToPlay` or first-frame observer to ack payload.

---

## Phase / STATE (on owner **go** — not in work commit)

Insert into Phase Roadmap **before** 15.9:

```text
- [ ] 15.11 Shared PV transition guard (393 + peek black) — cover +
      transition mute + Host attach-ack. Design: this file. Does not
      close Cap 15. Target: Kafka local→local peek+settle PASS.
- [ ] 15.9 Cap close-out — **after 15.11**
```

YOU ARE HERE stays **Cap 15** → 15.11.

Known debt **393** row: close only when device matrix 1–3 PASS; do not close on widget tests alone.

---

## Rejected for v1

| Alt | Why |
|-----|-----|
| Mask only at `isCurrent` | Fails peek black (15.10 device) |
| Dart-only fixed delay unwrap | Does not prove content switch; fails audio leak |
| New Capability / Cap split | Owner: Cap 15 owns doom-scroll UX through this fix |
| Immediate Q3=B / dual player | Owner re-board only after 15.11a fails |

---

## Owner sign-off

- [ ] Accept peek+settle single guard track
- [ ] Accept Pigeon attach-ack + transition suppress in 15.11a
- [ ] Accept device pass bar (table above)

After checked: **OK start coding** for 15.11 work commit.
