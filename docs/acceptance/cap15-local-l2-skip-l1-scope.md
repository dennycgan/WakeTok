# Cap 15 — Local / L2-ready skip Layer 1 (scope pointer)

> **Superseded for design detail by**
> `cap15-15.10-local-l2-skip-l1-design.md`. Kept as a short index.
>
> **Problem (owner observation, Kafka 2026-08-22):** Local assets, or assets
> that already completed Layer 2 on a prior visit, still show **Layer 1 blur**
> (and for video, corner spinner) before sharp still or playback. Two
> directly-playable videos separated by an item that only has Layer 1 does
> **not** match the product target and blocks a clean 393 probe matrix.

## Goal / non-goals

| | |
|---|---|
| **Goal** | When an item is **local / L2-ready**, becoming current should show **sharp still or direct video playback** without an unnecessary Layer 1 blur dwell. Re-visiting an id that **already completed L2 in this Session** should not regress to blur-first. |
| **Non-goals** | Do not fix **400** (PhotoKit cannot deliver L1). Do not fix **393** (shared PV settle wrong A/V) — paused until after this. Do not fix **395** (restart-from-0 after slot taken). Do not add Layer 1 network. Do not change Q3=B / 1+1 pool for 393. |

## Distinction from other debts

| Debt | This item |
|------|-----------|
| **400** | No poster at all (black) | Has poster / had L2 — should **skip** blur path |
| **393** | Wrong previous A/V on shared surface at settle | **Pipeline** — still shows blur when L2 is already available |
| **394 still gapless** | Flash inside Fit on L1→L2 swap | Closed 15.5; this is **skip L1 when L2-ready**, not gapless decode |
| **ADR-025 default** | Three layers always L1→L2 | This item **narrows** when L1 is required vs optional |

## Current behaviour (code-backed summary)

- Become-current almost always runs **L1 preview → dwell → L2** unless ±1
  preheat left a poster and `_retryLayer2Only()` runs — UI still often blur +
  spinner while L2 re-fetches.
- **No Session-level** “id X L2 completed → skip L1 on return.”
- Page State outside ±1 is lost → cold L1 again.

## Open design decisions (owner board — not pre-decided)

1. **First visit, local-only:** Skip L1 when Host/Dart can know L2 is
   immediately available without network, or only skip on **revisit after L2
   success**?
2. **Still vs video:** Same rule, or video may keep poster-only path when
   faster than full still export?
3. **Memory scope:** ±1 page State only vs **Session id→L2-ready cache**
   (survives scroll-away >1)?
4. **Dwell (Cap 16.4 N=500 ms):** Bypass dwell when L2-ready / local?
5. **393 sequencing:** Re-open 393 explore only after consecutive
   **local→local video** handoff no longer inserts blur-only neighbours in
   the common case.

## Candidate directions (not chosen — explore in design review)

- **A — Revisit fast path:** If `_media.displayLayer == full` or video L2
  completed for same id in Session, become-current **skip** `loadFeedPageLayer1`
  and mount/play L2 directly (bypass dwell when local).
- **B — Session cache:** Composition-root map `localId → L2 artifact` (file
  path / player prepare token); invalidate on leave-cancel / generation /
  Cap 16 rules.
- **C — Host hint:** Thin signal “display asset locally available now” to
  Dart — observability only; does not overturn ADR-025 local-only L1 policy
  for true iCloud miss.

Trade-offs: memory vs correctness vs Cap 16 cancel semantics; must not
re-open Cap 16 storage leak.

## Success criteria (draft)

Kafka Profile, Full, Optimize Storage ON, Wi‑Fi:

1. **Local video, first visit (if in scope):** No blur dwell before play when
   file is on device — or owner documents why one-frame poster is still required.
2. **Revisit after L2 completed:** Same id returns **sharp / playing** without
   blur-first regression (within agreed memory scope).
3. **iCloud / 400 path unchanged:** Still black or L1-miss chrome where
   PhotoKit has no local derivative.
4. **393 probe matrix:** Owner can reproduce **local video → local video**
   without a blur-only item between — then 393 explore may resume.
5. **Cap 16 invariant:** Storage still explainable-as-watched; no new duplicate
   networked loads.

## Hang

Phase number **TBD** after design decisions 1–5. Not merged into 15.8 or 15.9
wording until scoped. **15.9** Cap close-out may proceed on 15.8 PASS while this
item is scheduled next.
