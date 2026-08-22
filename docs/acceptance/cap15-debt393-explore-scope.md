# Cap 15 — Debt 393 explore scope (mask + mute ± attach-ack)

> Design-only. **No code in this note.** Independent of Cap **15.8**
> acceptance scope. Hang position (phase number) is **TBD** after this
> explore converges — do **not** pre-bind to 15.8.
>
> **Status (2026-08-22): PAUSED.** Owner approved **local/L2-ready skip Layer 1**
> first (`cap15-local-l2-skip-l1-scope.md`). Resume 393 explore after that
> item converges or owner explicitly re-orders.
>
> Locked owner direction (2026-08-22): explore Dart poster mask + mute +
> optional Host attach-ack first; overturn ADR-031 **Q3=B** / change the
> ADR-006 1+1 pool only as last resort after explore proves insufficient
> (**owner re-board required**). Pure Dart mask alone is expected to be
> insufficient; converging to “need attach-ack” is **successful explore
> convergence**, not overturning Q3=B.

## Goal / non-goals

| | |
|---|---|
| **Goal** | Suppress the settle window where the shared Platform View still shows/plays the **previous** item (**picture + sound**, same progress) before the new id. |
| **Non-goals** | Do not change Q3=B / 1+1 pool / Platform View architecture. Do not fix debt **400**. Do not promise a **15.8** delivery. Do not reinterpret `onSurfaceReady` / `notifyDisplaySurfaceReady` as “content switched.” Do not fix Instant replay / session playhead (395). |

## Why existing signals are not enough

- `finishLoad` can return to Dart **before** async `DispatchQueue.main.async { attach(B) }` runs — Dart “load done” ≠ surface shows B.
- `onSurfaceReady` / `notifyDisplaySurfaceReady` mean Platform View mounted / adopt requested — **not** pixels+audio for the new id.

## Visual mask (enter / settle — not 15.7 leave)

| | |
|---|---|
| **Mount** | Page becomes `isCurrent`, kind is **video** with an existing Layer 1 poster, and UiKitView is about to / has mounted. Mask = that page’s poster **above** the shared UiKitView. |
| **vs 15.7** | 15.7 keeps poster on the **leaving** page. This explore covers the **entering** page to hide shared-surface residue of A. Same medium (poster), different timing and purpose. |
| **Unmount** | Only at a **trust point** (below). **Forbidden:** unmount solely on `onSurfaceReady`, Dart `finishLoad` return, or generation bump. |
| **No poster** | **N/A** this explore (debt **400** / black path). |

## Mute

| | |
|---|---|
| **Start** | Same window as mask: mute (or `volume=0`) the **AVPlayer currently attached to the shared surface** (must bind the correct player). |
| **End** | Same trust point as mask unmount → unmute. |
| **Failure / timeout** | Must unmute + drop mask (or explicit degraded UI). **Permanent mute is a hard fail** of the explore. |

Mask and mute share one trust point so “picture unmasked but still muted” (or the reverse) cannot diverge.

## Trust-point candidates (ordered for explore)

1. **Dart-only conservative hold (knife 1)** — short fixed hold after settle (or next-frame schedule) then unmask+unmute. Purpose: **measure how long the bad window is**. **Not** formal proof that content switched.
2. **Optional Host attach-ack (knife 2 — separate board to add)** — semantic: surface has **attached** player for `id=B` (generation-matched). **Not** “first frame painted.” Candidate Host sites (list only):
   - Warming path: after `attach(B)` inside the main-async block that today runs **after** `finishLoad` returns
   - Become-current / `adoptPreparedPlayer` attach completion
   - Stronger / costlier (only if attach-ack still insufficient): `AVPlayerItem.status == .readyToPlay` or layer first-frame observation
3. Dart unwraps only when `ack.localId == currentId` and generation matches.

## Explore success (default bar)

Kafka (or floor device), **video→video**, both sides **local / already playable** (393 easiest):

1. Peek: next poster correct (15.7 must not regress).
2. Settle: **no** visible A picture; **no audible A audio** (default **0 audible leak**; relax only if measured impossible).
3. After unwrap: B plays correctly; no long stuck-poster; failure path never leaves permanent mute.
4. Q3=B / 1+1 pool unchanged.

iCloud-slow next: longer mask OK if finite; record separately from **400**.

## Explore insufficient → may propose pool / Q3=B reopen

Any one (still requires **owner re-board**; no auto-upgrade):

- No reliable ack (or ack itself races / wrong id); cannot define “user already sees/hears B.”
- Mute window so long / failure-prone that UX is worse than a brief wrong A/V flash.
- After mask+mute±ack, Kafka still stably reproduces wrong A/V, **or** new severe regressions (wrong B, hard stuck, permanent mute).

## Hang

Decide phase number only after design converges (enough / need ack / need pool). **Not** pre-bound to 15.8.
