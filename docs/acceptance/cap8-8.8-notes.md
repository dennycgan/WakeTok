# Cap 8 — Phase 8.8 Real-device acceptance notes

> Overlay UI path on device after Cap 8.5–8.7: height stability, file-size
> sample semantics (reuse 8.4 / ADR-018 known assets), coarse hitch feel,
> leave-video audio pause. **Not** a Cap 7.7a Instruments / &lt;25 ms/s re-gate.
>
> Owner acceptance — **PASS** 2026-08-10 (A1 retest after leave-current pause
> fix).

## Locked acceptance rules (8.8 design)

| # | Choice |
|---|--------|
| D1 | Add automated `W-O-prog` (progressive height); audio-leak fix in same phase |
| D2 | Entire gate on **Profile** build |
| D3 | S1–S3 required; S4 iCloud-only optional |
| D4 | Coarse hitch = subjective C1 only — no Instruments |
| Samples | Reuse 8.4 / ADR-018 known assets (do not pick fresh unknowns) |
| S3 extra | Row3 joined copy format (`Live Photo · {size}` / zh `实况照片 · {size}`) |
| Optional | zh-Hans Row1 relative-date clip glance — note only, non-gating |

**Not in scope:** Cap 7.7a V-hard; Release hang; M7 RAW+JPEG; Location; host Tier re-prove.

---

## Environment

| Field | Value |
|-------|--------|
| Device | iPhone 13 Pro (Kafka) |
| UDID | `00008110-001114420AEA801E` |
| Build mode | **Profile** |
| Git HEAD (first campaign) | `02d9789` (pre-fix Overlay / size / hitch matrix) |
| Git HEAD (A1 retest) | `9b0dc46` (`fix(app): pause playback when leaving video for non-video`) |
| Photos access | Full |
| Date (local) | 2026-08-10 |
| Install | `flutter build ios --profile` then `flutter install --profile -d 00008110-001114420AEA801E` |

---

## Matrix

| # | Check | PASS standard | Result | Notes |
|---|--------|---------------|--------|-------|
| H1 | Overlay height | Progressive fill; height stable; no Row4 | **PASS** | Owner: visual stable |
| S1 | Local still (8.4 M1 reuse) | Overlay size matches Photos Info | **PASS** | Identical to Photos「i」 |
| S2 | Local video **`IMG_0165`** | Overlay **11.3 MB** | **PASS** | Identical to Photos「i」 |
| S3 | Live Photo (ADR-018 sample) | (a) **2.9 MB** still-only; (b) one-line `Live Photo · 2.9 MB` | **PASS** | Joined Row3 confirmed; not two rows; not clipped |
| S4 | iCloud-only | Size blank; no size-triggered download | **PASS** | No size; no download |
| C1 | Coarse hitch | ~1 min doomscroll; no obvious stutter/freeze | **PASS** | Subjective; see Observe-only for non-gate artifacts |
| **A1** | Leave playing video → still / iCloud-only | Previous video **audio must stop** | **PASS** | Retest 2026-08-10 after fix; video→still and video→iCloud both stop audio |
| (opt) | zh-Hans Row1 | Glance relative date clip — non-gating | — | Not required this run |

---

## Observe-only (not 8.8 FAIL)

Recorded during C1 doomscroll; **out of Cap 8.8 gate**. Do not conflate with A1.

| Item | Classification | Notes |
|------|----------------|-------|
| Still↔still one black frame between pages | Observe-only (new note; not Cap 8 scope) | Owner: always between images |
| Video residual / previous-frame flash on swipe | **Existing Known debt** (Cap 7.7 notes: “Videos swipe… brief flash of the previous playing frame”, Always, orthogonal to Severe Hang; STATE ADR-006 row) | Not a new finding |
| Play once then freeze on last frame (no loop) | **Explicit Cap 7 non-goal** (ADR-014 Decision 2: Manual advance; no Repeat product controls in Cap 7) | Not a new defect |

---

## Cross-source playback progress (first observation — pending owner product call)

**Behavior:** Same video asset reached via **All** and via **Videos** shares playhead / ended-on-last-frame state (e.g. half-played in All → open in Videos continues mid-play; finished in All → Videos shows last frame without restarting).

**Mechanism (one sentence):** `PlaybackApiHost` keeps a single app-scoped AVPlayer keyed by **`assetIdentifier`** (reuse path when `activeAssetId` matches); it does **not** key state by “source tab + feed index”, so the same Photos id under All vs Videos hits the **same** player/position.

**Status:** **First observation this campaign** — not previously accepted or rejected in product docs. ADR-014 Decision 4 covers tab switch resetting **feed index** to queue head, **not** whether playhead should reset when the same asset appears under another source. ADR-006 explains the architecture; it does **not** alone mean the UX is accepted.

**Owner preliminary view (not a final decision):** Behavior looks acceptable for now and may even help a future Session Continuity capability; **revisit when Session Continuity is designed**. **No fix in Cap 8.8.**

**Cap 13.5 update:** **Accepted behaviour** per ADR-023 D6 (docs commit for Cap 13.5). Not a Host / `PlaybackApiHost` fix; not cross-tab Continuity (ADR-023 D8: tab = new Session). STATE Known debt row reworded and **kept** as a permanent accepted-behaviour record (not removed) to prevent re-litigation. Closed by Cap 13.5.

---

## Audio leak (A1) — fixed + retested PASS

**Repro (pre-fix):**

- **A (bug):** Playing video → swipe to still **or** iCloud-only (black) page → **prior video audio keeps playing**.
- **B (ok):** Playing video → swipe to another playable video → audio switches to the new video.

**Root cause:** On leave-current, parent clears `assignedDisplayGeneration` in the **same** `didUpdateWidget` as `isCurrent: false`. The old branch order treated generation change as `_startLoad()` and **skipped** the pause path. Next-page video “fixed” audio only by preparing a new player (coincidental), not by an explicit leave-page pause.

**Fix:** Always `pause()` when leaving current, before/independent of identity/generation reload. Tests: **W-F8b** (video→still), **W-F8c** (video→iCloud-only).

**Retest:** Profile install of fix; video→still and video→iCloud-only — **owner PASS** 2026-08-10.

---

## Verdict

| Field | Value |
|-------|--------|
| Overlay / size / hitch (H1, S1–S4, C1, S3 format) | **PASS** |
| Leave-video audio (A1) | **PASS** (retest) |
| **Phase 8.8 overall** | **PASS** |
| Residual | M7 N/A; Location Known debt; cross-source playhead pending Session Continuity review; Observe-only rows above |

Next: Cap 8.9 close-out (STATE Capability `[x]` + PHASE_HISTORY).
