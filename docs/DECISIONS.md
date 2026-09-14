# WakeTok — Decision Log (ADR)

> Major technical/engineering decisions. Each entry is immutable: never edit or
> delete its reasoning. To overturn a decision, write a NEW entry and only flip
> the old entry's Status line to "Superseded by ADR-xxx".
> Historical entries may have specific third-party product names replaced with
> anonymized codenames per privacy policy (see
> `docs/private/competitor-codenames.md`, gitignored). This is a textual
> substitution only and does not alter any decision's reasoning, evidence, or
> Status. All other content remains immutable per the rule above.
> The top "Plain summary" line is for the project owner to verify — it must be
> understandable without deep technical knowledge.
> Workflow: draft the ADR in chat -> owner approves the draft -> append here
> (see state-decisions-maintenance.mdc and release-handoff.mdc).
> Append new entries at the end; numbering starts at ADR-001 and increments.
> Always record the date and a commit/PR anchor.
> **Accepted date** = `git log -1 --format=%cs <anchor-sha>` (the day the
> implementing commit lands on `main`), not the design-discussion day.
>
> Status values: Proposed | Accepted | Superseded by ADR-xxx (date) |
> Deprecated (no replacement) | Reverted-in-code (implementation rolled back;
> see note). Proposed = design locked in docs before the implementing work
> commit; flip to Accepted with real anchor after that work lands (no fake
> anchors while Proposed).
>
> Revert reconciliation: if a code revert crosses the implementation point of an
> Accepted ADR, do NOT silently leave the log stale. Either (a) write a new ADR
> explaining the rollback, or (b) flip the old entry's Status to
> "Reverted-in-code (date, reason)" and add a one-line note. The original
> reasoning stays untouched.
>
> Note: lettered ADR references inside the local kickoff (ADR-K, ADR-P.5, …) are
> kickoff-internal spec anchors, NOT entries in this log. This log starts empty
> at ADR-001.

---

## ADR Template
- Status: Accepted (YYYY-MM-DD)  <!-- date = git log -1 --format=%cs <anchor-sha> -->
- Commit/PR anchor: <sha or #PR>
- Plain summary (owner reads this): <one plain-language sentence>
- Context / what problem forced this:
- Decision (what was chosen):
- Rejected alternatives (why not B):
- Consequences / constraints accepted:

---

## ADR-001: POC-04 Flutter media feed architecture gate — Conditional Pass

- Status: Accepted (2026-07-28); hitch **hard-gate reading** (mean
  hitch < 25 ms/s AND no Severe Hang) and the hang-triggered SwiftUI /
  all-native re-eval fail path are superseded by ADR-030 (2026-08-19)
- Commit/PR anchor: 577b586
- Plain summary (owner reads this):
  We keep building WakeTok’s feed in Flutter with native iOS video (Platform View),
  after measuring that everyday scrolling feels OK; we tightened the written hitch
  bar to match that feel, and we will specially fix rare severe freezes later.
- Context / what problem forced this:
  POC-04 must decide whether Flutter UI + Swift media (UiKitView + AVPlayerLayer,
  pool 1+1, image temp files) is an acceptable architecture for the vertical media
  feed before production domain work. Original hitch bar was Instruments Animation
  Hitches mean < 5 ms/s on iPhone 13 Pro (Profile). Hand scrolling and a later
  fixed-cadence Hitch Probe showed the < 5 bar does not match acceptable everyday
  feel, while a Texture escape did not improve hitch.
- Decision (what was chosen):
  1. **Architecture:** Continue **Flutter + Swift-native** media. Production video
     surface is **Platform View** (`UiKitView` + `AVPlayerLayer`). Do **not** adopt
     the Conditional Texture escape as the default path.
  2. **First-frame gate — PASS:** On iPhone 13 Pro (Profile), FF20 warming-assisted
     p90 = **93 ms** (target < 500 ms). Timing: t0 = start of `attachActiveVideo`;
     t1 = first `AVPlayerLayer.isReadyForDisplay == true` (Platform View path that
     was measured). Cold-start first frame is out of scope for this gate.
  3. **Hitch gate — adjusted (not the original < 5):**
     - **New bar:** mean hitch **< 25 ms/s** AND **no Severe Hang** in the
       evaluation window (Instruments Animation Hitches / Hangs, Profile, gate
       device iPhone 13 Pro).
     - **Why adjust:** Everyday hand feel on PV ≈ **13–19 ms/s** was acceptable to
       the owner; < 5 was stricter than product-acceptable scrolling. Hitch Probe
       HN (PV, `overruns=0`) ≈ **38 ms/s** with Severe Hang is treated as a
       **reproducible upper bound under `animateToPage` load**, not the everyday
       feel reference. HF (`overruns=75`) has **invalid cadence** and is not used
       as a primary conclusion.
  4. **Path verdicts under the adjusted bar:**
     - **PV hand:** Run1/Run2 (≈13 / 19 ms/s) **pass**; Run3 (≈33 ms/s + Severe Hang)
       **fail** that run (severe hang / high rate).
     - **Texture escape (hand):** ≈33 / 64 ms/s — **worse than PV**; escape **failed**.
  5. **Overall POC-04:** **Conditional Pass** — PV path under normal hand scrolling
     meets the adjusted hitch bar and first-frame PASS; Texture escape rejected;
     Severe Hang remains an accepted debt to address in production feed work.
  6. **Data anchors (notes / commits, not this ADR’s Accepted date):**
     - Hand PV / Texture hitch and FF20: `docs/poc/POC-04-notes.md`; spike commits
       including Texture escape `5cc0b9d` and Hitch Probe calibration `2c9fb59`.
- Rejected alternatives (why not B):
  - **Keep hitch < 5 ms/s as hard fail → no-go / leave Flutter:** Rejected because
    owner-calibrated everyday PV feel (13–19) is acceptable; < 5 over-penalizes a
    viable Flutter+PV stack.
  - **Ship default video via Flutter Texture** (`AVPlayerItemVideoOutput` →
    `FlutterTexture`): Rejected — measured hitch worse than PV; escape did not close.
  - **Immediate full rewrite to SwiftUI / all-Swift-native UI stack:** Rejected —
    Conditional Pass on PV demonstrates Flutter+Swift-native is viable for this
    gate; SwiftUI re-evaluation is only triggered if production feed cannot clear
    Severe Hang debt after an explicit implementation attempt.
  - **Treat Hitch Probe HN ≈38 as the everyday gate number:** Rejected — HN is
    stricter programmatic scrolling; hand 13–19 remains the feel reference; HN
    informs upper-bound / tooling stress only.
- Consequences / constraints accepted:
  - **Severe Hang** (seen on some hand runs and on HN) is **known debt**: must be
    triaged in **production feed** implementation (not ignored); does not block
    Conditional Pass of POC-04 under normal hand scrolling.
  - Written hitch bar is now **< 25 ms/s + no Severe Hang**; original **< 5** is
    recorded as superseded for this gate’s pass/fail reading (this ADR).
  - Texture path may remain in the spike for evidence; it is **not** the production
    default surface.
  - Boundedness (pool ≤1+1, temp files) and PV first-frame PASS remain required
    baseline properties carried into production design.
  - `docs/STATE.md` / this log update still follow F1=A / two-commit docs discipline
    when the owner accepts and anchors this ADR.
  - Flutter UI layer is retained, preserving the cross-platform option for a
    future Android version. Android media layer (ExoPlayer + Surface) will
    require its own POC gate; this gate's conclusion does not pre-judge Android
    feed performance.

---

## ADR-002: POC-03 lock-screen continuous playback gate — Conditional Pass

- Status: Accepted (2026-07-28)
- Commit/PR anchor: 9568f7b
- Plain summary (owner reads this):
  WakeTok can retain a Swift-owned AVQueuePlayer beyond the lifetime of a
  Flutter route, continue queue playback while locked, and support Now Playing
  and system remote commands. This conditionally validates the native background
  playback substrate. The complete product flow using WakeTok-generated physical
  clips read back from Photos remains to be confirmed after POC-09.
- Context / what problem forced this:
  POC-03 must decide, before production domain/data/feature work, whether an
  app-scoped native playback service (AVQueuePlayer + AVAudioSession(.playback)
  + UIBackgroundModes audio) can keep a continuous queue alive across lock
  screen, system interruption, Control Center / headphone remotes, and process
  kill — without tying playback lifetime to a Flutter Widget.
- Decision (what was chosen):
  1. **Conditional Pass (GO with debt):** Retain the spike’s native background
     playback substrate as the shape reference for Production Background Audio
     and SessionCheckpoint: app-scoped player, session category `.playback`,
     pre-queued advance, Now Playing + remote commands, and cold-start
     Restore? (P5=A, no auto-play until confirm).
  2. **Phase evidence (3.1–3.5), see `docs/poc/POC-03-notes.md`:**
     - 3.1 Widget-independent playback (M1–M3 PASS).
     - 3.2 Lock-screen auto-advance was manually verified. Foreground gap probe
       measured n=24, p50≈4ms, p90≈4ms (3.2 gate session). A later session also
       showed n=18, p50≈2ms, p90≈4ms. Both apply to bundled WAV fixtures and are
       not treated as the final gap result for WakeTok-exported physical clips.
       (P3=B; L1–L3 PASS.)
     - 3.3 Interruption recovery under owner gate Q1=B (I1–I3 PASS): auto-resume
       via poll and/or returning to the app; lock/home resume without opening
       WakeTok not required for this gate.
     - 3.4 Control Center / AirPods play-pause-next (N1–N3 PASS).
     - 3.5 Force-quit stops audio; cold start offers Restore? without auto-play
       (K1–K3 PASS; P5=A).
     - Work commits on `spike/poc` include `8ec6c47` … `9568f7b` (anchor).
  3. **Known debt (does not overturn Conditional Pass):**
     - WeChat/VoIP: no auto-resume on lock screen or iOS home without opening
       the app → Production Background Audio (Q1=B).
     - kickoff "iCloud Asset download interruption" out of POC-03 (P2=A) →
       Production Background Audio.
     - **Real physical-clip integration:** After POC-09, play at least three
       consecutive WakeTok-exported clips from Photos through the native queue
       while locked. Confirm acceptable transitions, correct segment order,
       Now Playing updates, and no Dart dependency per transition
       → Production Background Audio.
  4. **Spike fixtures:** Bundle WAV (`clip_a/b/c`) are sufficient to prove the
     service shape for this gate.
  5. **Scope boundary:** The spike used bundled WAV assets. It proves the native
     playback service shape, but not the complete production path through
     physical video export, Photos import, PHAsset resolution, and generated
     segment ordering.
- Rejected alternatives (why not B):
  - **No-go / abandon Flutter+native split for a pure-SwiftUI audio shell now:**
    Rejected — gate evidence supports Conditional Pass on the native substrate.
  - **Hard-fail unless VoIP interrupt resumes on lock/home without opening the
    app:** Rejected — owner locked Q1=B for 3.3.
  - **Cold-start auto-play from SessionCheckpoint:** Rejected — P5=A requires
    explicit Restore?.
  - **Treat bundled-WAV gap probe as the final production gap bar for exported
    physical clips:** Rejected — fixtures ≠ Photos-backed generated segments;
    final gap confirmation is deferred (see Known debt / after POC-09).
- Consequences / constraints accepted:
  - Production Background Audio / SessionCheckpoint should reuse this spike’s
    ownership and control surface as the implementation reference.
  - Gate retrospectively assessed as lower-risk than anticipated given iOS
    background audio maturity; spike results serve as implementation reference
    for Production Background Audio capability.
  - Listed debts must be scheduled; they are not “already solved.”
  - Completing the product path (export → Photos → native queue while locked)
    remains a post-POC-09 confirmation, not a claim of this ADR.
  - Next capability after this gate close-out: **POC-09** (phases owner-approved
    separately).

---

## ADR-003: WakeTok subtitle scope — burned-in only; soft tracks out of scope

- Status: Accepted (2026-07-29)
- Commit/PR anchor: 3883b8f
- Plain summary (owner reads this):
  WakeTok only cares about burned-in subtitles (text that is already pixels in
  the video picture). Soft subtitle / caption tracks are out of product scope —
  WakeTok does not process them and does not promise to keep them.
- Context / what problem forced this:
  During POC-09 we had to decide how far subtitle handling goes for export /
  physical clips. On iOS Photos, user video captions are overwhelmingly
  burned-in. Camera-app recordings typically do not create soft subtitle
  tracks; Photos edits often drop soft tracks; soft-sub material that arrives
  via external import is rare, and whether those tracks survive
  `AVAssetExportSession` is unreliable. An earlier POC-09 Q3 lock allowed
  “preserved or cleanly absent”; this ADR narrows product scope so WakeTok
  does not commit to soft-track behavior at all.
- Decision (what was chosen):
  1. WakeTok subtitle scope = **burned-in** captions only (part of the video
     image). They are preserved naturally whenever the current representation
     exports successfully.
  2. **Soft subtitle / closed-caption tracks** (e.g. tx3g, WebVTT,
     CEA-608-style CC tracks) are **out of scope**.
  3. WakeTok does **not** read, process, preserve, or commit to any export
     behavior for those soft tracks.
  4. If `AVAssetExportSession` happens to keep a soft track, that is a
     **system side effect**, not a WakeTok feature.
  5. This boundary applies to **MVP and all later versions** until a **new ADR**
     overturns it.
- Rejected alternatives (why not B):
  - **Build soft-track probe + preserve logic:** Rejected — soft tracks are
    rare in the Photos library WakeTok targets; cost exceeds covered scenarios.
  - **Assert “100% of user content is burned-in”:** Rejected — that is an
    empirical claim about user libraries, not always true. The precise product
    statement is “WakeTok does not handle soft subtitle tracks.”
- Consequences / constraints accepted:
  - POC-09 phase **9.5** needs **no** subtitle-track probe implementation
    (recorded in `docs/poc/POC-09-notes.md` §9.5).
  - For the rare asset that has soft tracks, whether captions appear after
    clip export depends on system export behavior — **not** a WakeTok
    responsibility.
  - Spike diagnostics may still surface incidental `textTrackCount` values;
    production must **not** treat soft-track preservation as a product feature.
  - Future soft-sub retention requests require a **new ADR**.
  - Anchor note (O3=S1): Accepted against POC-09 work `3883b8f` (same close-out
    packaging as ADR-004); §9.5 body lives in notes in this docs commit.

---

## ADR-004: POC-09 Current Photos Representation Export Gate — Pass

- Status: Accepted (2026-07-29)
- Commit/PR anchor: 3883b8f
- Plain summary (owner reads this):
  WakeTok may build production physical-clip export on Photos’ *current*
  representation: request AVAsset with version=.current and
  deliveryMode=.highQualityFormat, then export. Trim, slow-mo duration,
  default audio, and explicit iCloud failure behaved as required. Soft
  subtitle tracks stay out of product scope (ADR-003). The full 120s clip
  state machine is not part of this gate.
- Context / what problem forced this:
  Production Physical Clip Export must not silently use the unedited
  original when the user trimmed or otherwise edited in Photos. POC-09
  was the gate that current-representation obtain + temp export is the
  correct input path before that capability is built.
- Decision (what was chosen):
  1. **Pass (GO):** Adopt `PHVideoRequestOptionsVersion.current` +
     `deliveryMode = .highQualityFormat` + self-built `AVAssetExportSession`
     (Q1=A, Q2=A) as the production obtain/export *input path* for clips.
  2. **Phase evidence** (`docs/poc/POC-09-notes.md`; work on `spike/poc`):
     - **9.1** Harness + dual current/original probe + temp export — PASS
       (unedited smoke). Work: `8fcac6c`.
     - **9.2** Trim: export ≈ current; original obviously longer (>2s notes
       threshold); no silent original fallback — PASS. Work: `ba72532`.
     - **9.3** HFR/slo-mo: export duration matches Photos-displayed /
       PHAsset duration (Q4=A) — PASS. Work: `96e4a23`.
     - **9.4** Default audio: track present + Play-export listen — PASS.
       Work: `a4f2130`.
     - **9.5** Soft subtitle tracks out of scope; burned-in incidental —
       PASS (docs / ADR-003). No track-probe implementation.
     - **9.6** Explicit failure: iCloud-only + networkAccessAllowed=false
       → `inCloudUnavailable` (incl. PHPhotosError 3164 mapping), no export
       path; same asset with network on → controlGate PASS; N1 local+OFF
       must not false-positive — PASS. Work: `3883b8f`.
  3. **Scope boundary:** This spike proved obtain + *temp* export metrics
     and failure shape. The formal **120s** segment state machine, job
     persistence, cancellation, and Photos re-import live in **Physical
     Clip Export Core** (and follow-on capabilities)—not in POC-09.
  4. **Deferred (do not overturn Pass):**
     - Slow-motion **frame-rate / audio-pitch** playback behavior beyond
       duration gate → Physical Clip Export Core (and/or product QA there).
     - Multi-audio-track **selection UX** → POC-07.
     - Soft subtitle / CC track round-trip → **out of scope** per **ADR-003**
       (not a scheduled debt to “fix later” without a new ADR).
- Rejected alternatives (why not B):
  - **No-go / require original-only or always-download path:** Rejected —
    Trim/slo-mo evidence needs `.current`; explicit fail covers undownloaded
    cloud assets.
  - **Treat soft-sub preservation as in-gate must-pass:** Rejected — ADR-003.
  - **Ship 120s state machine inside POC-09:** Rejected — gate is obtain-path
    compatibility only.
- Consequences / constraints accepted:
  - Physical Clip Export Core may proceed on the locked obtain path.
  - ADR-002’s post-POC-09 debt (play ≥3 WakeTok-exported clips locked) remains
    scheduled under Production Background Audio after real clips exist.
  - Spike code under `lib/spikes/poc_09/` / `ios/Runner/Spikes/POC09/` is
    evidence, not the production job engine.
  - Capability Roadmap: POC-09 → [x]; YOU ARE HERE → App Foundation
    (phases 4.1–4.4 owner-approved; revisable before coding).

---

## ADR-005: iOS Deployment Target = iOS 16.0

- Status: Superseded by ADR-007 (2026-07-30)
- Commit/PR anchor: 0be5397
- Plain summary (owner reads this):
  WakeTok’s minimum supported iOS version is 16.0.
- Context / what problem forced this:
  Bootstrap left the iOS deployment target at the Flutter default as a
  placeholder (kickoff Open Question: platform target TBD). All three
  project gates (POC-04, POC-03, POC-09) were verified on real devices
  running iOS 26.x. Production Pigeon contracts, Photos permission APIs,
  and native error mapping must lock a minimum before App Foundation
  coding starts.
- Decision (what was chosen):
  1. Minimum iOS deployment target = **iOS 16.0**.
  2. `ios/Podfile` and the Xcode project deployment settings must be
     updated to match. That configuration change is the **implementation
     part** of this decision and lands in a subsequent **work** commit —
     not in this docs commit.
- Rejected alternatives (why not B):
  - **Keep Flutter’s iOS 13-era default:** Rejected — little coverage
    benefit for WakeTok’s audience; constrains modern PHPicker / Limited
    Access and related Photos APIs.
  - **Raise to iOS 17+:** Rejected — excludes still-used older devices
    without a clear product gain for MVP.
- Consequences / constraints accepted:
  - All production code may assume iOS 16+ APIs are available.
  - Devices below iOS 16 are out of support scope.
  - STATE Project facts records iOS 16.0; Bootstrap “Flutter default”
    deployment-target debt is closed by this ADR.

---

## ADR-006: App-scoped PlaybackApi ownership (Platform View is detachable surface)

- Status: Accepted (2026-07-30); the Cap 7.3 fill-in clause that
  current-item `requestDisplayAsset` / `requestPlayableVideo` (and
  foreground player prepare) must use `isNetworkAccessAllowed = false`
  and fail immediately with `iCloudDownloadRequired` is narrowly
  superseded by ADR-025 (2026-08-15; Cap 14.3 work `92c3a60`) for
  **current-item Layer 2 only**. Still binding: Layer 1 preview, ±1
  preheat, POC-10 / Overlay file-size fetches, Live motion, and any
  other path not named in ADR-025 D7; PlaybackApi ownership, detachable
  surface, 1+1 pool, and the rest of this ADR remain binding
- Commit/PR anchor: bb5371a
- Plain summary (owner reads this):
  WakeTok’s player lives in a Swift app-scoped service, not inside a Flutter
  widget. The feed’s Platform View only attaches/detaches the picture; lock-screen
  audio and advancing to the next video keep working when the UI is gone.
- Context / what problem forced this:
  ADR-001 keeps Flutter UI + native video (PV). ADR-002 proves native
  background audio / Now Playing with a queue. App Foundation 4.3 needs a
  production PlaybackApi shape: who owns the player across lock, page changes,
  and unlock restore — without tying lifetime to a Flutter route. A POC-04
  lock-screen feed probe (spike/poc) validated detach + background advance +
  foreground adopt on real Photos video (P1–P3 PASS).
- Decision (what was chosen):
  1. **Ownership:** Production **PlaybackApi** is implemented by an **app-scoped
     Swift playback service** (player pool / queue). Flutter drives intent
     (plan, page sync, play/pause); it does **not** own `AVPlayer` lifetime.
  2. **Surface:** Platform View + `AVPlayerLayer` is a **detachable display
     surface**. On `didEnterBackground`, detach layer; keep audio. On
     `willEnterForeground`, Dart `jumpToPage` → PV ready → **adopt existing
     player** (no stop/recreate; restore guard).
  3. **Background advance:** Dart supplies a **video-only playback plan**
     `{assetId, feedIndex}`. Native advances while locked; **images are not
     in the plan**. Prefer **AVQueuePlayer lookahead** (insert next before
     end). Do **not** rely on background `replaceCurrentItem` + `play()` —
     that path can report playing while silent. This refines ADR-001's pool
     semantics for the background path: the foreground 1+1 display-pool
     contract is unchanged; while the lock probe / background mode is active,
     lookahead is queue-based and warming promotion is disabled (promotion
     would replace AVQueuePlayer and clear lookahead).
  4. **Plan end:** Stop at last item; keep position; **no loop** (product may
     revisit under Session Continuity later).
  5. **Scope of this ADR:** Ownership + restore + background advance contract
     for PlaybackApi. Now Playing / remote commands remain as in **ADR-002**
     (not re-proven by this feed probe).
- Rejected alternatives (why not B):
  - **Flutter/`video_player`-owned lifetime:** Rejected — lock/widget teardown
    breaks continuous audio (ADR-002 boundary).
  - **Unlock stop + recreate player:** Rejected — probe requires adopt-in-place
    for A/V sync and to avoid SIGABRT from item stealing.
  - **Warming-player promotion while lock probe / background queue active:**
    Rejected — replaces AVQueuePlayer and clears lookahead (`queueItems→0`).
  - **Background `replaceCurrentItem`/`play()` as primary advance:** Rejected —
    silent “fake play” on device.
- Consequences / constraints accepted:
  - App Foundation **4.3 PlaybackApi** must encode this ownership model
    (empty impl OK; contract matches).
  - Production Background Audio capability implements Now Playing / remotes
    on top of this service (ADR-002 debts unchanged).
  - Spike code under POC-04 remains evidence, not the production service class
    names.
  - Image-at-lock and Control Center black-screen edge cases stay product /
    later phase concerns; probe used `didEnterBackground` (not
    `willResignActive`) for detach.
  - Foreground page-driven attach/release and native background queue advance
    are mutually exclusive *control modes* for the same player: while locked /
    detached, the service advances via AVQueuePlayer lookahead; Dart must not
    treat unlock restore as a normal page apply that tears down the queue.
  - The unlock restore window uses a restore guard (and `_probeOwnsPaging`) so
    `jumpToPage` + adopt cannot race a second `attach`/`release` path — that
    race SIGABRT'd the probe. Separately, probe mode disables warming promotion
    so a display-pool promote cannot replace AVQueuePlayer and clear lookahead.
  - **Cap 7.3 fill-in (work `07d10d6`, 2026-08-04):** production image path
    extends `DisplayAssetDto` with `localFilePath` (host JPEG temp → Flutter
    `Image.file`). Display temps share the display-pool **≤1+1** eviction
    discipline (POC-04 `tmpMax=2`): a new temp must clean up an unused prior
    file — no unbounded accumulation. Host `requestDisplayAsset` /
    `requestPlayableVideo` (and foreground player prepare) are **local-only**
    (`isNetworkAccessAllowed = false`); iCloud-only assets return
    `ErrorCode.iCloudDownloadRequired` immediately with **no** host-initiated
    network download — waiting/retry UI is the next capability. Cap 7.3
    foreground lifecycle: detach layer + **pause** on background; re-adopt
    existing player on foreground / play (no recreate). Keep-audio + queue
    advance + Now Playing remain Production Background Audio (ADR-002).
  - **Cap 7.5 restore wiring (work `a4388ad`, 2026-08-06):** restore contract
    is wired — `PlaybackGateway.onPlaybackRestoreRequired` → domain
    `PlaybackRepository.restoreRequests` → `main_browse` listens and syncs
    feed index / `PageController` (empty queue ignored; index clamped).

---

## ADR-007: iOS Deployment Target = iOS 18.0

- Status: Accepted (2026-07-30)
- Commit/PR anchor: 67c9884
- Plain summary (owner reads this):
  WakeTok’s minimum supported iOS version is 18.0. This replaces the earlier
  iOS 16.0 floor (ADR-005).
- Context / what problem forced this:
  ADR-005 locked iOS 16.0 before App Foundation coding, but underweighted
  device reality: the owner’s gate devices (iPhone 13 Pro, iPhone 17) both
  run iOS 26.x, and there is no device available that can run iOS 16 or 17.
  The frozen iPhone 7 (iOS 14.4) is below every candidate minimum and is a
  Photos-library content donor only, not a test target. Claiming support for
  iOS 16 therefore commits WakeTok to untestable QA debt across two major
  OS releases. ADR-005’s docs-only Accept also never landed the matching
  Xcode/Podfile bump (tree still showed Flutter-default 13.0), so this ADR
  both supersedes the floor and is the first implementation of a real
  deployment target. Separately, ADR-005 rejected “raise to iOS 17+” under a
  broader-coverage assumption; that assumption no longer holds.
- Decision (what was chosen):
  1. Minimum iOS deployment target = **iOS 18.0**.
  2. Engineering floor is enforced only by `IPHONEOS_DEPLOYMENT_TARGET = 18.0`
     in Xcode project build settings (all configurations; RunnerTests inherit).
     Do **not** add `MinimumOSVersion` to `ios/Flutter/AppFrameworkInfo.plist`
     — the current Flutter template omits that key, and hand-added keys the
     toolchain does not own are silently dropped on template regeneration.
     Do **not** implement ADR-005’s deferred 16.0 bump as an intermediate step.
  3. Flip ADR-005 Status only to **Superseded by ADR-007 (date)**; do not
     edit ADR-005’s original reasoning.
  4. Rationale for **18** (not 17): raise the floor to the highest major
     still broadly aligned with last-supported OS for XS/XR-class hardware,
     while refusing an iOS 26 minimum that would drop that generation without
     a clear MVP gain. (Owner may tighten this bullet if a specific 18+ API
     dependency is named later.)
- Rejected alternatives (why not B):
  - **Keep iOS 16.0 (ADR-005):** Rejected — two major versions of untestable
    QA debt; coverage benefit is speculative given owner hardware.
  - **Jump minimum to iOS 26:** Rejected — drops still-used XS/XR-generation
    devices that can run current non-26 majors; benefit for MVP is unclear.
  - **Rewrite ADR-005 in place:** Rejected — decision log is append-only;
    supersession requires a new ADR.
- Consequences / constraints accepted:
  - Production code may assume **iOS 18+** APIs. APIs newer than the minimum
    (including current 26-only APIs) still need compile-time availability
    guards where used.
  - No iOS 18 physical device or simulator runtime is available in the
    current toolchain set: an **iOS 18 simulator smoke** is deferred to the
    Final real-device performance / hardening capability and recorded as a
    Known debt row in `docs/STATE.md`. Day-to-day verify on existing **26.x**
    simulators / devices.
  - Devices below iOS 18 are out of support scope.
  - `docs/STATE.md` Project facts deployment target becomes iOS 18.0
    (ADR-007); Related decisions reference ADR-007 (ADR-005 superseded).
  - If/when `ios/Podfile` is first introduced (first dependency that needs
    native CocoaPods), that same commit **must** set
    `platform :ios, '18.0'`.

---

## ADR-008: Production error contract (AppError + Result + native mapping spec)

- Status: Accepted (2026-07-30)
- Commit/PR anchor: 6c1eed3 (Dart half: AppError, Result, mapping spec);
  e23a94b (wire half: Pigeon ErrorCode + ErrorCode→AppError mapping)
- Plain summary (owner reads this):
  WakeTok uses one shared list of error names in Dart (plus “unknown”),
  a small Ok/Err Result type, and a written native mapping table. Spike
  names like inCloudUnavailable stay out of production. The Pigeon wire
  enum and mapping code come in the next foundation step.
- Context / what problem forced this:
  App Foundation must lock stable cross-layer error codes before Photos,
  playback, and export gateways ship. POC-09 used spike-era
  `inCloudUnavailable` for PHPhotosError 3164; kickoff Data Contract
  instead lists `iCloudDownloadRequired` and `iCloudDownloadFailed`.
  Without a production contract, Pigeon and Swift implementations would
  diverge or re-leak spike names.
- Decision (what was chosen):
  1. **AppError** enum = kickoff Data Contract codes 1:1 plus
     **unknown** (`lib/core/errors/app_error.dart`). No optional
     message on the enum; gateways may wrap later.
  2. **`Result<T, E>`** sealed Ok/Err with map / mapError / flatMap /
     fold / getOrElse (`lib/core/result/result.dart`).
  3. **Native mapping spec** (contract table, not Swift execution yet)
     in `lib/core/errors/native_error_mapping_spec.dart`:
     - R1: PHPhotosError 3164 / network required with
       networkAccessAllowed=false → iCloudDownloadRequired
     - R2: network allowed + download **entered transfer phase** +
       non-3164 failure → iCloudDownloadFailed (mere allow/request
       without transfer does not map to Failed)
     - R3: user cancel → operationCancelled (never Failed)
     - R4: wire ErrorCode.unknown (4.3) → AppError.unknown
     - R5: channel-layer anomalies → AppError.unknown
     - R6: spike `inCloudUnavailable` forbidden in production contracts
  4. **Wire half deferred to 4.3:** Pigeon ErrorCode 1:1 with AppError
     (including unknown) + ErrorCode→AppError mapping + exhaustive
     switch tests. After 4.3 work lands, append that sha to this ADR’s
     Commit/PR anchor line (do not rewrite Decision/Rejected text).
  5. Swift-side mapping execution remains in later capabilities’ first
     real native implementations.
- Rejected alternatives (why not B):
  - **Keep spike `inCloudUnavailable` in production:** Rejected —
    collapses Required vs Failed; conflicts with kickoff codes.
  - **AppFailure(code, message?) as Result error type in 4.2:**
    Rejected — STATE locks `Result<T, AppError>`; message wrapping
    can layer later without changing the code enum.
  - **String wire codes only:** Rejected — owner locked Pigeon enum
    for compile-time alignment with AppError.
  - **Wait to Accept until 4.3:** Rejected — Dart half is already
    implemented; dual-anchor records the split without inventing a
    second ADR for the same contract.
- Consequences / constraints accepted:
  - Production Dart must not introduce spike error member names.
  - 4.3 must deliver ErrorCode + mapping + exhaustive tests and
    re-anchor this ADR’s wire half.
  - R2 “transfer phase” is stricter than a bare “download attempted”
    reading; STATE 4.2 wording matches the spec.
  - Spec table is auditable contract; it does not yet run on device.

Note (ADR-009): mapping file relocated from lib/core/errors/ to
lib/platform/ to satisfy the generated-import boundary; mapping
semantics (1:1, exhaustive, unknown fallback) unchanged.

---

## ADR-009: Production layered architecture lock

- Status: Accepted (2026-07-31)
- Commit/PR anchor: 79459e0
- Plain summary (owner reads this):
  Kickoff’s layered architecture is now a repo constraint. The App Foundation
  tree is the canonical layout. Dart import boundaries are enforced by
  `test/architecture/` guard tests (zero allowlist for generated imports).
- Context / what problem forced this:
  The kickoff architecture section lived only in a gitignored private spec, so
  the repo could not see or enforce it. App Foundation landed `core` + platform
  contracts with three benign path choices (`lib/l10n/`,
  `lib/platform/generated/`, no `bootstrap`/`router` yet). Before `features/`
  appears, boundary rules must be visible in-repo and machine-checked.
  ErrorCode→AppError mapping is a protocol adapter (input type is generated);
  it was moved from `lib/core/errors/` to `lib/platform/` so the generated-import
  rule needs no allowlist (see ADR-008 note).
- Decision (what was chosen):
  1. **Dependency direction** (runtime / design) is binding downward only:
     Widget/Screen → Controller/ViewModel → UseCase → Repository interface →
     (DB repository | Pigeon platform gateway). Compile-time imports follow
     Decision 2; the composition root (`lib/main.dart` / future `lib/app/`)
     wires implementations.
  2. **Import bans (zero allowlist for generated):**
     - `lib/features/**` must not import DB packages (`sqflite`, `drift`,
       `sqlite3`, `floor`, `isar`), `lib/platform/**` (including generated),
       or `lib/data/**`.
     - Only `lib/platform/**` (excluding generated sources) may import
       `lib/platform/generated/**`.
     - `lib/platform/` is the sole Pigeon gateway home; `lib/data/` is
       persistence only and must not import generated.
     - `lib/domain/**` must not import `features` / `data` / `platform`.
     - `lib/core/**` must not import `features`.
     - Dart business code must not depend on Swift types; Swift must not
       decide product rules (Pool / Ordering / Repeat / Eligibility) —
       playback ownership remains ADR-006.
     - Scan exemptions (not import allowlists): `lib/l10n/**`,
       `lib/platform/generated/**`, `lib/main.dart`, `lib/app/**`.
  3. Cross-platform I/O uses approved Pigeon Data Contracts only; any new
     cross-layer dependency requires a new owner-approved ADR.
  4. **Canonical paths** = App Foundation’s actual tree (`lib/l10n/` for
     gen_l10n; `lib/platform/generated/` named to discourage hand-edits).
     Kickoff directory diagrams stay advisory. No behavior-free “align the
     tree” refactors. New folders appear when a capability needs them.
  5. **Theme discipline** (binding starts when Capability **5.1** lands):
     colors and type sizes come from `lib/core/theme` semantic tokens
     (Light/Dark); feature code must not hard-code Color/TextStyle values;
     numeric token values live only in code. Until 5.1, only forward-armed
     guards apply; composition-root seed theme is not a defect.
  6. **Enforcement:** `test/architecture/` must stay green and is part of
     each Coding Task’s test step (`00-workflow-gates.mdc`). Machine Slice-1
     bans `Color(0x` / `Color(0X` in `lib/features/**`; fuller theme scanning
     may tighten later without renumbering this ADR unless Decision 5 is
     overturned.
- Rejected alternatives (why not B):
  - **Paste the full kickoff architecture into rules:** Rejected — too long,
    fights the advisory directory diagram, invites cosmetic refactors.
  - **Owner-only post-capability audits as the sole defense:** Rejected —
    new chats miss the check; not a durable gate.
  - **Cosmetic moves to match the kickoff directory diagram:** Rejected —
    churn without behavior.
  - **Allowlist `lib/core/errors/**` for generated imports:** Rejected —
    would bake a permanent exception; mapping relocated to `lib/platform/`
    instead (E2).
- Consequences / constraints accepted:
  - Architecture is repo-visible; conflict priority
    (owner > DECISIONS > STATE > kickoff) closes for layering.
  - Local Cursor rules cite ADR-009 / ADR-006 and the ban list; they do not
    duplicate kickoff prose (`.cursor/` is gitignored).
  - The three App Foundation path choices are canonical, not debt.
  - Dart boundaries = guard tests; Swift product-rule discipline = review +
    ADR-006 (not claimed by Dart scanners).
  - Guard tests are a release gate for tasks that touch `lib/`.
  - **Cap 7.8 accent freeze (work `009f804`, 2026-08-06):**
    Renamed `accentProvisional` → `accent`. Frozen hex: Light `#FC2555`,
    Dark `#FF6B8A`. New token `brandGold` `#E0C590` (Light == Dark).
    Loading `CircularProgressIndicator` uses `brandGold`; CTA / selected
    chrome / `ColorScheme.primary` use `accent`. `onPrimary` remains
    Material `fromSeed` (not pinned). ADR-014 Decision 8 cross-references
    this note only and does not duplicate hex.

---

## ADR-010: Riverpod as production state management

- Status: Accepted (2026-08-01)
- Commit/PR anchor: a9443ae
- Plain summary (owner reads this):
  WakeTok uses Riverpod for UI/feature state. Domain code stays free of
  Riverpod types so business rules are not tied to one UI framework.
- Context / what problem forced this:
  Capability 5.2 is the first production feature layer that needs shared
  authorization state across screens. Kickoff Tech Stack names Riverpod;
  without an Accepted ADR, composition-root wiring and domain purity would
  rely on chat memory only. ADR-009 already bans features from importing
  platform gateways, so state adapters must sit above domain interfaces.
- Decision (what was chosen):
  1. Adopt **`flutter_riverpod`** (no codegen / `riverpod_annotation` in 5.2).
  2. Mount **`ProviderScope`** at the composition root (`lib/main.dart` /
     future `lib/app/**`).
  3. **`lib/domain/**` is Riverpod-free:** no `package:riverpod`,
     `package:flutter_riverpod`, or `package:riverpod_*` imports; repository
     / use-case signatures use only `Future` / `Stream` (no `AsyncValue`).
  4. Gateway construction and domain-interface binding happen only at the
     composition root. `lib/features/**` must not construct platform
     gateways or hold Pigeon / gateway concrete types. Tests may
     `ProviderScope(overrides: …)`.
  5. Feature notifiers (`AsyncNotifier` / `Notifier`) wrap domain
     repositories; `go_router` remains deferred.
  6. **Enforcement:** `test/architecture/` bans Riverpod package imports
     under `lib/domain/**` (substring / package-name match).
- Rejected alternatives (why not B):
  - **Bloc / Cubit as default:** Rejected — conflicts with kickoff stack and
    splits the first feature onto a second state library.
  - **Service Locator / get_it for repositories:** Rejected — harder to
    override in widget tests; fights Riverpod’s override model.
  - **Riverpod types in domain:** Rejected — couples domain to UI framework;
    blocks plain unit tests of ports.
  - **Codegen-first (`riverpod_annotation`):** Rejected for 5.2 — extra
    build_runner surface before the first notifier shape stabilizes.
- Consequences / constraints accepted:
  - ADR-010 applies from Cap 5.2 onward for new feature state.
  - Temporary DEBUG auth harness in `lib/main.dart` is not product UI and
    must not become the 5.3 permission-screen foundation.
  - Local Cursor rules should cite ADR-010 alongside ADR-009 for domain /
    composition-root constraints.
---

## ADR-011: Library catalog API vs source resolution; shared fetch options; nullable createdAt

- Status: Accepted (2026-08-01)
- Commit/PR anchor: a7cb28a
- Plain summary (owner reads this):
  The app reads the Photos library as a flat list of assets with shared
  counting rules, and keeps creation dates honest when PhotoKit leaves them
  empty — album/source browsing stays a later feature.
- Context / what problem forced this:
  Cap 5.4 needs PHAsset-level paging, per-type totals for the debug shell,
  and an availability vocabulary without implementing product All/Photos/
  Videos source resolution. Existing Pigeon `listAssetSources` /
  `resolveSource` look like album APIs; reusing them for full-library
  enumeration would conflict with STATE (“no PHAssetCollection/Album
  enumeration”) and confuse the next capability. Totals for a ~40k library
  must not require shipping every asset over Pigeon. PhotoKit
  `creationDate` may be nil; inventing an epoch would corrupt sort and UX.
- Decision (what was chosen):
  1. **Catalog HostApi (separate from source resolution):** add
     `libraryTotals()` and `fetchLibraryPage(cursor, pageSize)` on
     `PhotoLibraryApi`. Leave `listAssetSources` / `resolveSource` as
     stubs for the next capability.
  2. **Totals vs paging:** `libraryTotals` uses PhotoKit typed fetch
     counts (photos = images including Live Photos; videos separate;
     all = photos + videos). `fetchLibraryPage` pages metadata only
     (id / media kind / creationDate / availability). Do not derive
     shell totals by scanning every page in Dart.
  3. **Shared `PHFetchOptions` construction:** one Swift helper
     (`makeLibraryFetchOptions`) owns inclusion/sort defaults for both
     totals and paging so the two paths cannot drift. Default PhotoKit
     semantics (Hidden / Recently Deleted excluded). Sort:
     `creationDate` descending; nil dates at end (no epoch fallback).
     No device-local-only filter.
  4. **Nullable createdAt:** domain `DateTime?` / wire `creationDateMs?`
     mirror PhotoKit nil; never substitute epoch.
  5. **Availability at list time:** domain keeps four values
     (`deviceLocal` / `iCloudNotDownloaded` / `downloading` /
     `unavailable`); catalog listing must not fabricate `downloading`.
     Wire enum is `AssetAvailabilityDto` to avoid clashing with domain
     `AssetAvailability`.
- Rejected alternatives (why not B):
  - **Implement catalog via `resolveSource` / album enumeration:**
    Rejected — contradicts Cap 5.4 “PHAsset only, no album enumeration”
    and steals the next capability’s API shape.
  - **Totals by paging the entire library in Dart:** Rejected —
    unacceptable cost/memory for ~40k assets; fragile vs Photos counts.
  - **Independent `PHFetchOptions` in totals vs page:** Rejected —
    silent count/page mismatch under 5.5 acceptance.
  - **`createdAt` non-null with epoch (or similar) fallback:** Rejected —
    lies about PhotoKit and breaks “nil sorts last”.
  - **Fabricate `downloading` during enumeration:** Rejected — not
    observable without an in-flight resource request.
- Consequences / constraints accepted:
  - Next All/Photos/Videos **source** work must not repurpose catalog
    page APIs as album browsers without a new ADR.
  - Shell totals and page universe must keep sharing the same options
    helper; changing inclusion/sort requires updating that one site.
  - List-time local-vs-iCloud uses undocumented KVC
    `PHAssetResource.locallyAvailable` (no public Swift property);
    tracked as STATE known debt; fix `ff2d610`. Prefer a public API if
    Apple ships one.
  - Opaque page cursors are index-based; library mutations mid-pagination
    can stale a cursor (acceptable for Cap 5.4 debug catalog).

---

## ADR-012: Localization guard lock (ADR-U enforcement)

- Status: Accepted (2026-08-01)
- Commit/PR anchor: b718e36
- Plain summary (owner reads this):
  Product UI copy must go through ARB/AppLocalizations. A machine test
  blocks hardcoded user-facing strings and missing zh-Hans keys, so Cap 6
  cannot quietly ship English-only or hardcoded copy.
- Context / what problem forced this:
  Cap 5 shipped the first product permission UI strings. The only automated
  check today is an empty Untranslated Messages Report, which catches missing
  translations for existing keys but not hardcoded widget copy. Cap 6 will
  add much more UI. ADR-009 showed that kickoff rules plus
  `test/architecture/` guards work; apply the same pattern to the
  machine-checkable core of kickoff ADR-U (§2, key parity, placeholder
  `description`).
- Decision (what was chosen):
  1. In `lib/features/**` and `lib/app/**`, user-visible copy must come from
     `AppLocalizations` / gen_l10n (kickoff ADR-U §2). Hardcoded user-facing
     string literals in common text widgets are forbidden (scanner subset
     defined in the guard test).
  2. **Tightens ADR-U §5:** `app_en.arb` and `app_zh_Hans.arb` **message key
     sets must be identical** on every guard run. Missing zh-Hans keys fail
     the test (no silent lag). (`app_zh.arb` Flutter fallback is out of
     scope for this parity check.)
  3. Messages whose value contains a `{placeholder}` must have a matching
     `@key` object with a non-empty `description` (machine-checkable subset
     of ADR-U §4). Other §4 description cases remain review.
  4. Guard tests stay green and are part of Coding Tasks that touch `lib/`
     (same workflow as ADR-009 / `00-workflow-gates` + local rules).
  5. ADR-U §7–8 Localization Inventory **auto-generation / report tooling**
     is **out of scope**; remains Known debt until Settings and localisation
     completion.
- Rejected alternatives (why not B):
  - **Fold into Cap 6 phase 1:** Rejected — mixes product acceptance with
    infra gating.
  - **Wait for Settings capability:** Rejected — Cap 6 would multiply
    violations; cheaper to lock now.
  - **Automate all of ADR-U in one ADR:** Rejected — Inventory (§7–8) is a
    report pipeline, not the same as an intercept gate.
- Consequences / constraints accepted:
  - Cap 6+ UI work has ARB/key-parity enforcement from the first commit;
    phase text need not restate “use ARB.”
  - This ADR does **not** machine-check Chinese quality, terminology, or
    duplicate meanings (review + future Inventory).
  - Dynamic non-copy displays (e.g. raw exception text / pure numeric
    interpolations) are outside the hardcoded-letter scan by design.
  - **Untranslated Messages Report** is narrowed to tracking keys that
    **already exist** but whose zh-Hans copy may still need polish. It no
    longer owns “does this key exist?” — that duty belongs to
    `localization_test.dart` key-parity (Decision 2).
  - Local Cursor rules cite ADR-012; published truth is DECISIONS + tests.

---

## ADR-013: Built-in All / Photos / Videos source resolution

- Status: Accepted (2026-08-02)
- Commit/PR anchor: ce7b850
- Plain summary (owner reads this):
  WakeTok resolves the three built-in library sources (All, Photos, Videos)
  as real Asset Sources over `listAssetSources` / `resolveSource`. Resolve
  returns the full ordered id list in one call, including iCloud-only
  assets. Sort is creation-date newest-first, same as the Cap 5 catalog.
  Debug/smoke UI only — product All/Photos/Videos tabs stay with Main Browse.
- Context / what problem forced this:
  Cap 5 delivered a catalog API (`libraryTotals` / `fetchLibraryPage`) and
  left `listAssetSources` / `resolveSource` as stubs (ADR-011). Cap 6 must
  implement product built-in source resolution without album enumeration,
  Main Browse chrome, or device-local-only filtering. `ResolvedSourceDto`
  already carries a full `List<String> assetIdentifiers` (no cursor) — Cap 6
  fills that shape rather than adding a paging HostApi. Wire gaps vs kickoff
  `AssetSourceDTO`: `AssetSourceKind` lacked Entire Library / Media Type
  cases; `AssetSourceDto` lacked `estimatedCount` / `availability` /
  `canAddContent`. Kickoff Item Ordering for these source kinds was still
  an Open Question; Cap 5.4 already proved `creationDate` descending via
  shared `makeLibraryFetchOptions`.
- Decision (what was chosen):
  1. **Keep `resolveSource` DTO shape (D1=A).** One call returns the full
     `assetIdentifiers` list. Cap 6 accepts holding ~40k ids on the Dart
     heap as an explicit cost. If a real device later proves this
     unacceptable → new ADR + new HostApi, not a silent Cap 6 semantic
     change. Allowed host internals: off-main-thread enumeration and
     shared fetch helpers — not “lazy indexing” that pretends the full
     list never crossed the bridge. After background enumeration,
     **BinaryMessenger reply must hop to the main/platform thread**
     (`DispatchQueue.main.async`); pair-mismatch / auth failures that
     never leave the calling thread complete in place.
  2. **Ordering = Creation Date Descending (D2=A)** for Entire Library and
     Media Type Sources. Reuses ADR-011’s verified `makeLibraryFetchOptions`
     sort. Closes kickoff ADR-M §5 for these two kinds without a new PoC.
     Album / Smart Album ordering remains deferred. No device-local filter.
  3. **`listAssetSources` returns only the three built-ins (D4=A).** Album /
     Smart Album stay unlisted. Sync HostApi (not `@async`); counts use
     `PHFetchResult.count` only.
  4. **Cap 6 UI = debug/smoke only (D3=A).** Product top-bar stays with
     Main Browse.
  5. **Wire + domain (D6=A) with frozen pairs (Option A):**
     - `AssetSourceKind`: rename `userLibrary` → `entireLibrary`; add
       `mediaTypePhotos`, `mediaTypeVideos`; keep `album` / `smartAlbum` /
       `other` for later.
     - Legal pairs (`sourceType` == kind name; same short id on list and
       resolve):

       | Product | kind / sourceType   | sourceIdentifier |
       |---------|---------------------|------------------|
       | All     | entireLibrary       | all              |
       | Photos  | mediaTypePhotos     | photos           |
       | Videos  | mediaTypeVideos     | videos           |

     - `AssetSourceDto.sourceIdentifier` from `listAssetSources` and
       `SourceReferenceDto.sourceIdentifier` into `resolveSource` are the
       **same string** for a given built-in — the three frozen short ids
       are the only legal round-trip values; host pair validation accepts
       exactly these **three legal (kind, id) pairs**.
     - Pair mismatch → existing `ErrorCode.assetUnavailable`; no new
       ErrorCode.
     - `AssetSourceDto` fields: `estimatedCount` (built-ins: always present
       and **exact** vs matching `libraryTotals` component; approximate
       semantics reserved for future albums), `AssetSourceAvailabilityDto`
       (`available` / `empty` / `unavailable` / `unauthorized`),
       `canAddContent` always `false` for built-ins. Wire `displayName`
       is `""` for built-ins — not an l10n source (ARB in smoke UI).
  6. **Shared `PHFetchResult` helpers** (`photosFetchResult` /
     `videosFetchResult` / `allFetchResult`) must be the single
     construction path for `libraryTotals`, `listAssetSources`, and
     `resolveSource` (same discipline as ADR-011’s single
     `makeLibraryFetchOptions`).
  7. **Limited Access (kickoff ADR-K §2):** Limited still resolves All /
     Photos / Videos as the currently accessible subset. Cap 6 does not
     list Album; Limited-mode Album `unauthorized` is forward-looking.
  8. **Acceptance sampling (D5):** resolved counts == `libraryTotals`;
     date-distribution quantiles **All-only** via
     `fetchLibraryPage(cursor:q, pageSize:1)` + id alignment; year-span N
     owner-supplied before 6.5 (placeholder N=3); iCloud sample reuses
     ADR-011 KVC `locallyAvailable` only. Cap 6.4 smoke must also exercise
     a **negative** mismatched-pair → `assetUnavailable` path.
- Rejected alternatives (why not B):
  - Source-scoped paging HostApi (`resolveSourcePage`) in Cap 6 —
    rejected (would be a new contract, not a stub fill-in).
  - Repository “lazy indexing” without reopening Pigeon — rejected
    (contradicts D1=A once the full list has crossed the bridge).
  - `sourceType: "builtin"` + short ids — rejected (cannot be 1:1 with
    three kinds; conflicts with `sourceType: 'album'` precedent).
  - Compound ids `builtin:all|…` — rejected (duplicates namespace already
    provided by `sourceType` + `sourceIdentifier`).
  - New ErrorCode for pair mismatch — rejected; use `assetUnavailable`.
  - Creation Date Ascending / Photos Collection Order PoC for built-ins —
    rejected; Descending already proven in Cap 5.4.
  - Product All/Photos/Videos chrome in Cap 6 — rejected (STATE orders
    Main Browse next).
  - Listing Albums in Cap 6 `listAssetSources` — rejected (later
    capability; ADR-011 stub intent).
  - Device-local-only production resolve — rejected (STATE / spike-only).
  - Alternate iCloud list-time detection in Cap 6 — rejected (reuse
    ADR-011 KVC debt as-is).
- Consequences / constraints accepted:
  - Cap 6.2 work commit (`ce7b850`) owns the Pigeon regen and Swift host
    implementation; this ADR’s Accepted date is that commit’s author date.
  - Domain gateway / smoke UI / ~40k device acceptance remain 6.3–6.5.
  - ~40k full-list resolve cost is accepted until a future ADR says
    otherwise.
  - Kickoff Item Ordering Open Question is closed for Entire Library +
    Media Type only.

**Cap 19.2 narrow supplement (2026-09-01; work `81e4b93`):**
`listAssetSources` user albums wire `AssetSourceDto.canAddContent` from
`PHAssetCollection.canPerform(.addContent)`; smart albums and built-ins
remain `false`. Kickoff Data Contract field no longer placeholder-only.

---

## ADR-014: Cap 7 slim Main Browse feed model (Sequential + Manual)

- Status: Accepted (2026-08-03); Decisions 2–3 (Sequential product
  default / deferred Shuffle for Browse Mixed) are superseded by
  ADR-023 (2026-08-13; Cap 13.4 work `aa03be8`) — Main Browse Mixed
  tabs use Shuffle + Manual + Repeat All via derive + Session Queue;
  Decision 4 outcome (tab switch → feed index 0) remains binding, with
  rationale re-grounded by ADR-023 D8 (tab = new Consumption Session)
  rather than “no Session Queue model yet”; the **Decision 5 caching
  clause only** — “session-scoped cache per source (at most one real
  `resolveSource` per All / Photos / Videos per session, reuse on
  revisit)”, as detailed in the Cap 7.6 Consequences bullet — is
  narrowly superseded by ADR-024 (2026-08-15; Cap 13.8 work
  `1a4f316`): a **successful but empty** resolve is no longer cached,
  so an empty source may issue more than one `resolveSource` per
  session; the rest of Decision 5 remains binding (independent Host
  predicates per built-in, no Dart derivation of Photos / Videos from
  All’s id list, `ResolvedSourceDto` carries ids only), and so does
  the Cap 7.6 rule that failures are never stored; Decisions 1 and 6
  remain binding; Decision 7’s Cap 7.7 **fail path** (SwiftUI /
  all-native re-eval) and the Instruments numeric pair as a
  **shipping gate for later Caps** are superseded by ADR-030
  (2026-08-19); Cap 7.7a Profile PASS and the Release hang Known debt
  remain binding
- Commit/PR anchor: 66d8c96
- Plain summary (owner reads this):
  Cap 7 Main Browse drives a vertical feed from Cap 6 built-in
  `resolveSource` id lists only. Order is Sequential (creation-date
  descending as returned by resolve); advance is Manual swipe. Kickoff’s
  General/Mixed default Shuffle is deferred until the Endless Shuffle
  capability. Severe Hang must be cleared on **full production chrome**
  under Instruments **Profile** with a hard gate — not Conditional Pass.
- Context / what problem forced this:
  Cap 6 (ADR-013) delivered All / Photos / Videos resolution and left
  product chrome to Main Browse. Kickoff §7 / ADR-N defaults General /
  Mixed pools to Shuffle + Manual + Repeat All, but STATE schedules
  Endless Shuffle / Queue Stability / Session Continuity **after** Cap 7.
  Cap 6 built-ins are Entire Library / Media Type sources (not Pure
  Generated Clip Pools) — they fall under that General/Mixed default.
  STATE Phase Roadmap text is replaced when the next capability opens, so
  a multi-capability deferral of Shuffle cannot live only in STATE.
  Separately, ADR-001 left Severe Hang as Known debt that **must** be
  triaged in production feed; its rejected alternative already points to
  SwiftUI / all-native re-evaluation if production feed cannot clear the
  debt — not another Conditional Pass. Cap 7 therefore needs an
  append-only ADR that freezes: slim queue shape, Sequential+Manual,
  chrome/Severe Hang gate, and explicit Out-of-scope vs later capabilities.
- Decision (what was chosen):
  1. **Slim feed input = Cap 6 resolve only.** The Cap 7 ephemeral queue is
     the ordered `assetIdentifiers` from `AssetSourceRepository.resolve`
     for one built-in `SourceReference` (`all` / `photos` / `videos`).
     No Source Pool Definition, Identity Coalescing product layer, Saved
     Pool, or Album listing in Cap 7.
  2. **Order Policy = Sequential; Advance = Manual.** Queue order is the
     resolve list order (ADR-013 creationDate descending). User advances
     by vertical swipe. No Endless Shuffle, no Auto-play, no Repeat
     product controls in Cap 7. Videos may play while on-screen; end-of-
     item does **not** auto-advance (Manual).
  3. **Kickoff Shuffle default deferred (structural).** Kickoff General /
     Mixed default Shuffle remains the long-term product default but is
     **not** implemented in Cap 7. It is scheduled for the STATE
     capability “Endless Shuffle, Queue Stability, and Session
     Continuity” (and related Session Queue work). This ADR records that
     deliberate multi-capability deferral.
  4. **Tab switch resets to queue head.** Changing All / Photos / Videos
     rebuilds the ephemeral queue from that source’s resolve result and
     starts at index 0. No Session Continuity “keep current asset”
     semantics (no Session Queue model yet).
  5. **Resolve binding — no client-side subset derivation.** Photos /
     Videos queues must **not** be derived by filtering/reordering All’s
     id list on Dart. `ResolvedSourceDto` carries ids only (no
     `mediaKind`). Host uses independent predicates per built-in. Cap 7
     implementation (phases 7.5–7.6) must call `resolve` per selected
     built-in; **session-scoped cache per source** (at most one real
     `resolveSource` per All / Photos / Videos per session, reuse on
     revisit) is the intended performance strategy — detail in 7.5/7.6
     design, constraint frozen here.
  6. **Chrome In / Out for Cap 7.**
     - **In:** Top All / Photos / Videos; **Pools** tab visible but
       disabled (ARB); bottom bar shell (Browse active; Clips / Auto /
       Settings stub); Limited banner; Main Browse = default post-auth
       landing; `library_smoke` demoted to debug-only.
     - **Out:** Media Info Overlay / Location / file-size (next
       capability); Live Photo motion (static + optional LIVE badge
       only; full treatment later + POC-08); Pool / Auto-play /
       Lookahead / Background Audio / Share / Mute / Fit·Fill·Crop /
       2× / Add to Album / clip flows.
  7. **Severe Hang / hitch hard gate (pays ADR-001 debt).** Cap 7.7
     acceptance on **iPhone 13 Pro**, Instruments **Profile** only (same
     mode as ADR-001 baselines; Release must not be mixed into the gate
     number — optional Release notes only as a **separate** secondary
     dataset if owner later asks). Bar: mean hitch **< 25 ms/s** AND
     **zero** Severe Hang. **Retest surface = full production chrome**
     (top tabs including disabled Pools + bottom bar) — **not** a bare
     PageView (POC-04 spike lacked chrome). Fail path = ADR-001’s
     already-written SwiftUI / all-native re-evaluation discussion —
     **not** a new Conditional Pass or new Known debt that rewrites
     ADR-001.
  8. **Accent / typography close-out (ADR-009 debts).** Cap 7.8 freezes
     accent (current `accentProvisional` may become formal accent, or
     owner-supplied hex). Typography tokens land in Cap 7.2. Cap 7
     close-out docs commit must clear/mark resolved the Known debt rows
     that named Main Browse / Production Main Browse as picker-up:
     Severe Hang (ADR-001), typography tokens (ADR-009), final accent
     (ADR-009). Portfolio Private→Public scan remains owner-only.
- Rejected alternatives (why not B):
  - Implement kickoff Shuffle in Cap 7 — rejected (STATE schedules
    Shuffle later; would pull Session Queue / Continuity early).
  - Keep current asset across tab switches — rejected (no Session Queue
    / Continuity model yet; Q3=A).
  - Derive Photos/Videos by filtering All’s resolve list — rejected
    (no `mediaKind` on wire; host predicates are independent).
  - Severe Hang Conditional Pass / new Known debt if 7.7 fails —
    rejected (conflicts with ADR-001 “must triage in production feed”
    and the written SwiftUI re-evaluation fail path).
  - Measure hitch on bare PageView without chrome — rejected (production
    surface includes chrome; spike was not representative).
  - Mix Release hitch numbers into the Profile gate — rejected
    (incomparable to ADR-001 Profile baselines).
  - Block Cap 7 close on final app-icon pixels before accent freeze —
    rejected (Known debt separates accent freeze at Main Browse close
    from icon assets before TestFlight).
  - Full `PHLivePhotoView` in Cap 7 — rejected (STATE lists Live Photo
    capability after Main Browse).
  - Ship Pools / bottom destinations as real features in Cap 7 —
    rejected (later capabilities).
- Consequences / constraints accepted:
  - ADR-013 remains the resolve/ordering contract for built-ins; Cap 7
    **consumes** it and does not reopen Pigeon for feed paging.
  - ADR-006 foreground PlaybackApi production path is Cap 7.3 work;
    Background Audio / Now Playing stay later.
  - ADR-009/010/012 continue to bind layering, Riverpod, ARB, tokens.
  - Until Endless Shuffle capability lands, product default for
    All/Photos/Videos browse is **Sequential + Manual** under this ADR,
    despite kickoff Shuffle wording.
  - 7.1 is design-freeze only (STATE / chat contract). This ADR is
    appended and marked Accepted only after the first Cap 7 work commit
    that implements part of this contract exists; Accepted date =
    that commit’s author date (`git log -1 --format=%cs <sha>`). Do not
    anchor on a docs-only 7.1 `[x]` commit.
  - This ADR’s Accepted anchor (`66d8c96`) marks the **start** of Cap 7
    implementation (Decision 8 typography / scrim tokens only).
    Decisions 1–2 / 4–7 land progressively across 7.3–7.7 — see
    PHASE_HISTORY for the full per-phase trail.
  - **Cap 7.6 session-scoped resolve cache (work `14f28d7`, 2026-08-06):**
    Decision 5 detail — successful `resolve` results for All / Photos /
    Videos are kept in-memory for the `ProviderContainer` / process
    lifetime and reused on tab revisit; failures are never stored. This
    “session” is **not** the kickoff Consumption Session (no Session
    Continuity / Session Queue product rules). Tab switch still presents
    that source’s cached (or freshly resolved) id list and resets to
    queue head (Decision 4).
  - **Cap 7.8 accent freeze:** frozen accent / `brandGold` values are
    recorded in ADR-009 Consequences (work `009f804`); this ADR does not
    duplicate hex.

---

## ADR-015: Cap 8 Media Info Overlay contract + POC-10 file-size semantics

- Status: Accepted (2026-08-08); the Decision 7 clause that top source chrome
  uses translucent/scrim (mediaScrim) is superseded by ADR-016 (2026-08-08);
  the Decision 7 clause that Settings Appearance includes the shared bottom
  bar is superseded by ADR-017 (2026-08-08) — Browse/Clips/Auto content
  forced-dark and Settings *pane* Appearance remain binding; the Decision 5
  clause that Live Photo file size is dual-nil / undetermined is superseded by
  ADR-018 (2026-08-10; still-only Tier 4 / `currentImageRepresentation`) —
  other Decision 5 multi-resource rules (edited / RAW+JPEG / no misleading
  sum) remain binding
- Commit/PR anchor: e058e32
- Plain summary (owner reads this):
  Browse (and the Clips/Auto stubs) stay forced-dark in the immersive shell;
  the bottom bar stays dark even on Settings. The Settings pane still follows
  Appearance. The media-info overlay ships three rows first (dates plus Live
  label / file size); Location is out for this Cap. File size uses public local
  fallbacks only — if we cannot get a value, that row stays blank.
- Context / what problem forced this:
  Cap 7 (ADR-014) shipped the vertical feed but left Media Info Overlay,
  loading/empty polish, POC-10 file-size semantics, and two Known debts
  (forced-dark immersive chrome; opaque top bar). Kickoff MVP Scope §3 /
  ADR-W / POC-10 / ADR-X / ADR-T define the product rules. Cap 8 must freeze
  an implementable contract without pulling Waiting for Media, Source
  Availability, Live motion (POC-08), or Location reverse-geocode into this
  capability. Formal Xcode 26.3 Photos headers have no PHAssetResource.dataSize,
  so Tier 1 cannot be assumed.
- Decision (what was chosen):
  1. **Overlay rows:** Fixed-height Presentation Metadata overlay, bottom-leading
     above the bottom bar. Cap 8 renders rows 1–3 only (Relative Date, Exact
     Date and Time, Media Characteristics). Row 4 (Location) is omitted
     (owner Q1=B; kickoff ADR-X best-effort deferral). Empty fields keep
     reserved row height for rows that are shown so layout does not jump
     while scrolling.
  2. **Progressive field updates:** Host/domain expose per-field nullable
     metadata (`creationDateMs`, `mediaKind`, `fileSizeBytes`,
     `fileSizeSemantics`). UI paints each field when it arrives; file size
     may update row 3 in place. Do not block paint on a fully populated DTO.
  3. **Request discipline:** Metadata fetch is **current feed page only**
     (owner Q5=A). Cancel on page leave; session-scoped memory cache; do not
     scan the resolved id list. **Location “current Item only”** remains a
     kickoff hard rule for any future Location Cap and is **not** relaxed if
     metadata ±1 prefetch is ever added later.
  4. **Live Photo label vs motion:** Row 3 may show Live Photo copy when
     `mediaKind == livePhoto` (owner Q4=A). PHLivePhoto / motion playback
     stays the Live Photo capability + POC-08.
  5. **POC-10 tiers for Cap 8:**
     - Tier 1 (`PHAssetResource.dataSize`): **Unavailable** on the formal
       SDK used for MVP (verified: Xcode 26.3 / iPhoneOS SDK
       `PHAssetResource.h` has no `dataSize`). No KVC / private API; no
       runtime `respondsToSelector` spike.
     - Tier 2 (generated-clip known output size): **slot only** until Physical
       Clip Export exists.
     - Tier 3 (local video URL via `requestAVAsset`, network access disallowed)
       and Tier 4 (local image representation byte count via
       `requestImageDataAndOrientation`, network disallowed): **enabled** for
       Cap 8 when semantics are reliable.
     - Multi-resource / ambiguous assets: return nil rather than a misleading
       sum (kickoff ADR-W).
     - Nil means blank row content, not zero bytes; never download solely for
       size; never block playback for size.
  6. **`fileSizeSemantics` enum (Cap 8 new contract — not kickoff/GLOSSARY
     terms):** Wire/domain may carry
     `primaryResource` | `localVideoUrl` | `currentImageRepresentation` |
     `unknownUnavailable` (names frozen at implementation). Documents and ADR
     must label this enum as Cap-8-introduced, not a kickoff glossary term.
  7. **Immersive chrome (owner Q2=B):** When bottom destination is Browse,
     Clips, or Auto, force dark immersive tokens for that content **and** the
     shared bottom bar (destination-conditional Theme override; bar is a
     sibling of IndexedStack). Settings follows Appearance, including the bar
     while Settings is selected. Top source chrome becomes translucent/scrim
     so media shows through (pays Cap 7 Known debts in phase 8.2).
     Implementation (work `e058e32`): Theme+Builder so Scaffold.backgroundColor
     resolves after the dark override; Browse pane is a Stack with full-bleed
     feed and Positioned top chrome using `mediaScrim` + on-media label tokens.
  8. **Out of Cap 8:** Location reverse-geocode UI; Waiting for Media product
     surface; Source Availability multi-source errors; Endless Shuffle /
     Session Queue; Right Action Rail / Share / Mute / Fit·Fill·Crop / 2×;
     Add to Album.
- Rejected alternatives (why not B):
  - Implement Location in Cap 8 — rejected (scope/risk; kickoff ADR-X allows
    hide row 4; Known debt recorded).
  - Forced-dark on feed+top only (bar follows Appearance) — rejected (hard
    Light/Dark seam under immersive feed; owner Q2=B).
  - Runtime probe for `dataSize` despite missing formal header — rejected
    (does not change Cap 8 path; owner Q3=A).
  - Defer Live Photo row-3 copy until Live Photo Cap — rejected (mediaKind
    already required for size tiering; owner Q4=A).
  - Prefetch metadata for ±1 neighbors in Cap 8 — rejected (hitch risk;
    owner Q5=A).
  - Extend `resolveSource` with full-library presentation metadata — rejected
    (payload/perf; use current-page requests).
  - KVC / private file-size APIs to raise coverage — rejected (POC-10 /
    kickoff ban).
- Consequences / constraints accepted:
  - ADR-009 / ADR-010 / ADR-012 continue to bind tokens, composition root, ARB.
  - ADR-014 feed model unchanged; Cap 8 adds chrome + overlay on top.
  - Tier 2 wiring waits for Generated Clip / export capabilities.
  - Location Known debt remains until Owner schedules a later Cap; current-Item
    geocode discipline stays binding then.
  - Accepted date/anchor = first Cap 8 work commit that implements any Decision
    above (`e058e32`, phase 8.2). Decisions 1–6 land progressively across
    8.3–8.6; phase 8.4 confirms Tier 3/4 on device and must not invent a
    second ADR for the same freeze.
  - Clips/Auto share the immersive dark shell while stubs; a future Cap may
    overturn with a new ADR if product context diverges.
  - Kickoff ADR-W §5 disclaimer (size ≠ device disk / iCloud quota /
    optimized-local / immediate free-on-delete) remains a copy landing
    Known debt — not duplicated as eng Decisions here.

---

## ADR-016: Cap 8.2 revision — transparent top chrome + compact bottom bar

- Status: Accepted (2026-08-08)
- Commit/PR anchor: 3c7aa1d
- Plain summary (owner reads this):
  Browse top tabs no longer sit on a grey translucent band — labels float on
  the media with a light text shadow. The bottom bar stays opaque dark but uses
  a compact custom icon+label row (48 logical pixels) so Material 3 NavigationBar
  SafeArea no longer inflates the grey block; height feels closer to
  Video-App-B’s compact bar while keeping destination labels.
- Context / what problem forced this:
  Cap 8.2 work `e058e32` (ADR-015 Decision 7) paid the “opaque top bar eating
  media” debt with a Stack overlay and `mediaScrim` fill. Owner real-device
  comparison against Video-App-B showed the scrim still reads as a grey color
  band over media; the reference UI floats tab labels with no background block,
  relying on text shadow for contrast on bright frames. Separately, Material 3
  `NavigationBar` paints SafeArea *inside* its Material, so setting `height`
  still yields a tall grey block (row + Home Indicator). ADR-015 never froze a
  bottom-bar height. Forced-dark destination rules from ADR-015 Decision 7 remain
  correct and are not reopened.
- Decision (what was chosen):
  1. **Supersede scope (narrow):** Only the ADR-015 Decision 7 clause that the
     top source chrome uses a **translucent/scrim** (`mediaScrim`) fill so media
     shows through is superseded. The **forced-dark** portion of ADR-015
     Decision 7 (Browse/Clips/Auto + shared bottom bar forced dark via
     destination-conditional Theme; Settings follows Appearance;
     Theme+Builder so Scaffold resolves tokens after override) is **unaffected**
     and remains binding.
  2. **Top source chrome treatment (final):** `_TopSourceChrome` `Material.color`
     is `Colors.transparent` (Material retained for InkWell). Selected /
     unselected colors remain `accent` / `onMedia`·`onMediaMuted`. Readability
     on arbitrary media comes from **on-media text shadows**, not a scrim band.
     Shadow parameters live on `WakeTokTokens.onMediaLabelShadows` (same in
     Light/Dark): single layer `Color(0x8A000000)`, `blurRadius: 6`,
     `offset: Offset(0, 1)`. Dual-shadow remains an optional post-device follow-up,
     not part of this Decision. `_PoolsCell` uses the same shadows.
  3. **Bottom bar (new; not a supersede):** Do **not** use Material 3
     `NavigationBar` for Main Browse. Use a custom compact destination row with
     content height **`48`** logical pixels (`WakeTokTokens.immersiveBottomBarHeight`,
     L/D same), keeping destination labels. Paint the same opaque `surface` under
     the Home Indicator as a separate inset below the row so SafeArea does not
     inflate the icon+label strip. Background remains opaque under the existing
     forced-dark rules. Widget tests guard content height and transparent top
     Material (W-9 / W-11).
- Rejected alternatives (why not B):
  - Keep / only lower `mediaScrim` alpha — rejected (still a visible color band;
    fails Video-App-B-style floating labels).
  - Edit ADR-015 Decision 7 in place to replace scrim wording — rejected
    (Accepted entries are immutable; supersede via new ADR).
  - Broad “supersedes ADR-015 Decision 7” without clause scope — rejected
    (would falsely imply forced-dark is overturned).
  - Treat height 48 / custom bar as superseding ADR-015 — rejected (ADR-015 never
    specified height or NavigationBar; this is additive).
  - Keep M3 `NavigationBar` and only set `height` / `MediaQuery.removePadding` —
    rejected (inner SafeArea still paints a tall grey block on device; owner
    acceptance failed until the custom row landed).
  - Hide destination labels (`alwaysHide`) for a thinner bar — rejected (owner
    requires labels; accept remaining thickness vs Video-App-B).
  - Hard-code shadow / height `Color(0x…)` or `48` inside `lib/features/**` —
    rejected (ADR-009 token discipline; architecture `Color(0x` guard; tests
    must share the same token values).
- Consequences / constraints accepted:
  - ADR-015 Status records the Decision 7 translucent/scrim clause supersession;
    forced-dark text in Decision 7 stays historically accurate and binding.
  - `mediaScrim` token remains available for other on-media chrome (e.g. future
    Overlay); it is no longer used as the top source switcher background.
  - Accepted anchor is Cap 8.2 revision work `3c7aa1d` (2026-08-08).
  - Cap 8 continues at phase 8.3 (Presentation Metadata); this revision does not
    open 8.3 scope.

---

## ADR-017: Main Browse bottom bar always dark (Settings pane still follows Appearance)

- Status: Accepted (2026-08-08)
- Commit/PR anchor: 9c05462
- Plain summary (owner reads this):
  The Main Browse bottom bar stays dark even when Settings is open under a Light
  system Appearance, so all four destination icons stay visible. Only the
  Settings content area follows Light/Dark Appearance.
- Context / what problem forced this:
  ADR-015 Decision 7 said Settings follows Appearance, including the shared
  bottom bar while Settings is selected. After Cap 8.2 revision (`3c7aa1d`),
  unselected destinations use on-media muted foreground colors intended for a
  dark bar. Under Light Appearance those labels/icons painted nearly invisible
  on a light bar (Browse/Clips/Auto appeared missing; only the selected Settings
  accent remained). Owner acceptance required the bar to stay black always.
- Decision (what was chosen):
  1. **Supersede scope (narrow):** Only the ADR-015 Decision 7 clause that
     **Settings Appearance includes the shared bottom bar** is superseded. Browse /
     Clips / Auto **content** forced-dark, and Settings **pane** following
     Appearance, remain binding. ADR-016 top-chrome treatment is unaffected.
  2. **Bottom bar theme:** Always apply `waketokTheme(Brightness.dark)` to the
     Main Browse bottom bar (independent of destination and ambient ThemeMode).
     Settings / stub panes continue to use ambient tokens when Settings is
     selected; Browse/Clips/Auto content stay forced-dark.
- Rejected alternatives (why not B):
  - Keep bar on ambient Light when Settings is selected — rejected (on-media
    muted icons vanish; owner bug report).
  - Force the entire Main Browse shell (including Settings pane) dark always —
    rejected (Settings content should still follow Appearance).
  - Edit ADR-015 Decision 7 in place — rejected (Accepted entries are immutable;
    supersede via new ADR).
- Consequences / constraints accepted:
  - ADR-015 Status records this bar-clause supersession alongside the ADR-016
    top-chrome supersession; Decision 7 body text is historical.
  - Widget tests W-8 / T4 assert: bar surface stays dark on Settings under Light
    ambient; Settings pane tokens stay light; all four destination labels remain
    findable.
  - Accepted anchor is fix work `9c05462` (2026-08-08).

---

## ADR-018: Live Photo file size — still-only Tier 4 (supersedes ADR-015 Live dual-nil)

- Status: Accepted (2026-08-10)
- Commit/PR anchor: f33c99e
- Plain summary (owner reads this):
  Live Photos show file size for the still image only (same Tier 4 path and
  `currentImageRepresentation` semantics as ordinary stills). WakeTok does not
  add the paired motion video bytes. Other multi-resource cases (edited
  ambiguity, RAW+JPEG, misleading sums) stay blank per ADR-015.
- Context / what problem forced this:
  Cap 8 / ADR-015 treated Live Photo as an undetermined multi-resource case and
  returned dual nil for file size, while Overlay row 3 still showed the Live
  Photo label. Device probes later showed:
  - `.photo` resource / Tier 4 still bytes align with iOS Photos Info for the
    still (example: ~2.89 MB vs Photos Info 2.9 MB on a local Live sample).
  - Summing `.photo` + `.pairedVideo` (~4.97 MB) was briefly considered
    (Option B) because it appeared to match a third-party gallery’s Live
    package display (~5.1 MB).
  - That third-party reference was then shown unreliable in an independent
    case: an AirDrop’d mp4 whose Mac Finder and iOS Photos Info both reported
    ~306.6 MB while the third-party UI showed ~10.87 GB (~35×). Size validation
    therefore dropped third-party gallery numbers and kept iOS Photos Info
    (and Finder / filesystem) as ground truth.
  - With Option B’s external-match rationale gone, product chose Option A:
    match Photos Info’s still size, lowest explanation cost for users who
    cross-check in Photos.
  - Separate M2 follow-up: Tier 3 for local video `IMG_0165` matched Photos
    Info 11.3 MB (11,260,685 bytes) — Tier 3 itself was not the defect behind
    earlier third-party mismatches.
- Decision (what was chosen):
  1. **Narrow supersede of ADR-015 Decision 5:** Only the concrete outcome
     “Live Photo → dual nil file size because inherent dual resources are
     undetermined” is superseded. The rest of Decision 5 remains binding
     (Tier 1 unavailable; Tier 2 slot; Tier 3/4 enabled; edited / RAW+JPEG /
     other ambiguous multi-resource → nil rather than a misleading sum; nil ≠
     zero; never download solely for size).
  2. **Live Photo size path:** Use the **same Tier 4 host path as ordinary
     images** (`requestImageDataAndOrientation` with network access
     disallowed). Return `fileSizeBytes` when local data is available and set
     `fileSizeSemantics` to existing **`currentImageRepresentation`**. Do
     **not** introduce a Live-specific semantics enum value.
  3. **No paired-video sum:** Do not read or add `.pairedVideo` (or other
     motion) resource bytes for Overlay file size.
  4. **Carve-out vs other multi-resource rules:** Live Photo’s inherent
     `{.photo, .pairedVideo}` pair is **not** treated as “undetermined → nil”
     solely because two resources exist. Showing still-only Tier 4 is an
     intentional, documented exception. Edited Live Photos still use Tier 4
     (current representation), consistent with edited stills. RAW+JPEG and
     other non-Live ambiguous combinations remain nil when semantics are not
     clear (unchanged).
  5. **iCloud / unavailable still:** If Tier 4 cannot obtain local image data
     (including iCloud-only Live), return dual nil for size — same failure
     mode as ordinary images. This is not the old “Live always nil” policy.
- Rejected alternatives (why not B):
  - Option B (sum `.photo` + `.pairedVideo` via `requestData`) — rejected after
    the third-party gallery reference used to justify package-total matching
    was disqualified; Photos Info remains the user-facing cross-check and
    reports the still.
  - Keep ADR-015 Live dual-nil forever — rejected (Overlay example and product
    want a size when the still is locally measurable; Tier 4 semantics are
    clear).
  - New `fileSizeSemantics` for Live package total — rejected with Option B.
  - Undocumented KVC `fileSize` / private resource URLs for production size —
    rejected (kickoff / POC-10 public-API discipline).
- Consequences / constraints accepted:
  - Host maps `MediaKind.livePhoto` into `resolveLocalImageFileSize` alongside
    `.image`.
  - Overlay row 3 may show `Live Photo · {formatted size}` when both label and
    size are present (existing join copy).
  - Cap 8.4 notes M3 records the original dual-nil PASS and points here; M2
    records the Tier 3 numeric Photos Info cross-check.
  - Overlay device acceptance (with work `f33c99e`): Live/video Overlay sizes
    match iOS Photos Info and Mac Finder when using decimal SI display
    formatting — do not use third-party gallery UIs as size ground truth.
  - ADR-015 Status line records this narrow Decision 5 supersession.
  - Accepted date/anchor = implementing work `f33c99e` (2026-08-10).

---

## ADR-019: Cap 9 Live Photo motion surface + PlaybackApi.clearPlaybackPool

- Status: Accepted (2026-08-10)
- Commit/PR anchor: 98fe191
- Plain summary (owner reads this):
  Live Photos in Manual browse play motion once through a dedicated native
  surface, then return to the still image (unload in a later Cap 9 phase).
  Entering a Live item releases the video player pool first (awaited), so Live
  decode does not stack on a paused video player. Mute stays a shared
  preference (default unmuted). Pigeon channels for LivePhotoApi and
  clearPlaybackPool land in Cap 9.2; Dart domain/gateway wiring is Cap 9.3.
  This Cap does not clear any Known debt table rows.
- Context / what problem forced this:
  Cap 7 (ADR-014) shipped Live as static still + LIVE badge only. Cap 8
  (ADR-015) added Overlay Live copy and still-only size (ADR-018) but left
  PHLivePhoto motion to this capability + POC-08. Kickoff ADR-S / MVP Scope
  require play-once, end on key still, iCloud static-first + failure fallback,
  and mute respect — without Auto-play, Background Audio, Lookahead, 2×, or
  clip export for Live. ADR-006’s video 1+1 pool and single playback surface
  must not be overloaded to own Live. Production feed uses single-item video
  plans today (adjacent-page warming is effectively idle); the real contention
  is a paused leftover AVPlayer after video→Live. ADR-006 already needed
  restore-guard discipline against attach/release races (SIGABRT risk).
  STATE Phase Roadmap lists “9.2 Native / 9.3 Pigeon”; Cap 9.2 lands the
  minimal Pigeon channels with the native hosts so HostApi methods exist —
  9.3 remains domain/gateway/composition-root wiring only (not a scope
  overrun).
- Decision (what was chosen):
  1. **LivePhotoApi + independent Platform View** (`waketok/live_photo_surface`;
     not AVPlayer / not video PlaybackPlan). Swift owns PHLivePhoto request,
     PHLivePhotoView, end/fail, mute apply, cancel. Dart owns current-page
     orchestration and UI (from Cap 9.3/9.4).
  2. **Visible surface exclusivity:** at most one visible PV — video
     `playback_surface` or Live viewType — for the current Browse page.
  3. **PlaybackApi.clearPlaybackPool():** new ADR-006 extension. Clears plan /
     active+warming AVPlayers, detaches video surface, clears pool-local
     pending/preparing state; does **not** reset mute preference. Idempotent.
     Empty `setPlaybackPlan` is **not** the release contract. Host uses a
     `clearEpoch` so in-flight prepare/warm callbacks no-op after clear; Dart
     **awaits** clear before LivePhotoApi.requestLivePhoto (no parallel).
  4. **Who calls clear:** Dart Feed orchestration via PlaybackRepository —
     LivePhotoApi must not call PlaybackApi.
  5. **When to clear:** when a **Live** item becomes current (covers
     video→Live and video→still→Live with a leftover pool). **video→ordinary
     still** stays pause-only (no clear). Rationale: free decode headroom for
     PHLivePhoto only.
  6. **Failure split (for 9.3 gateway):** Sync-detectable failures (missing
     asset, not `.photoLive`, …) → throw `PlatformException` with
     `ErrorCode` member name. Async `PHLivePhoto` request failures (incl.
     iCloud after network allowed) → `LivePhotoFlutterApi.onLivePhotoFailed`
     only. Same request must not both throw and emit failed.
  7. **Reuse ErrorCode.iCloudDownloadFailed** (not a new enum member): aligns
     with ADR-008 R2 (network allowed / transfer attempted, non-cancel
     failure). Distinct from `iCloudDownloadRequired` (local-only / no
     host-initiated download). Exhaustive ErrorCode switches unchanged in
     count.
  8. **Play-once lifecycle (ADR-S):** ready → Dart calls startPlayback once →
     later phases unload Live PV → still Image.file (Q7=A). Leave stops;
     re-enter may auto-play once; **no** gesture/tap replay. **Hard gate:**
     disable `PHLivePhotoView.playbackGestureRecognizer` (D3 / Q6=A).
  9. **Mute interim:** shared preference default **unmuted**; apply to video
     setMute path and Live surface; Mute UI Cap later.
  10. **Playback Style:** system PHLivePhotoView default once; variants probed
      in POC-08; no editing UX (Do Not Build #19).
  11. **Out of Cap 9 / Known debt:** no clearing of any STATE Known debt
      table row. Q7 switch jump, if unacceptable on device, may add a **new**
      debt row — must not merge into “Video page swipe flash”. No Mute/Share/
      Fit·Fill·Crop/2× rail; no Auto/Background/Lookahead; no Waiting for
      Media product surface; no multi-item video plan / adjacent warming work.
  12. **POC-08** runs inside this Cap; item #5 records observed iCloud
      download state changes in 9.7 notes (spinner-only UI, Q4=A); item #8
      records plugin vs native rationale (no first-party PHLivePhotoView
      plugin; photo_manager-class DIY VideoPlayer ≠ Photos-parity lifecycle).
- Rejected alternatives (why not B):
  - Extend PlaybackApi / AVPlayer to play Live — rejected (Live ≠ Video; ADR-S).
  - Empty setPlaybackPlan as release — rejected (host early-return today; muddy).
  - clear on all video→non-video — rejected (Cap scope; still decode cheap).
  - Keep Live PV mounted after end (Q7=B) — rejected for later phases
    (simpler surface model; accept 9.7 jump gate).
  - Parallel clear + Live request — rejected (defeats “free resources” window).
  - Default muted / force-silent Live — rejected (Q1=A; ADR-S mute follow).
  - Flutter plugin as default Live path — rejected; self-built Pigeon + PV
    (POC-08 #8).
  - Cap 9 pays Release hang / video flash Known debt — rejected (picker-up
    unchanged).
  - New ErrorCode for Live iCloud failure — rejected; reuse
    `iCloudDownloadFailed` (ADR-008 R2).
- Consequences / constraints accepted:
  - ADR-006 remains video ownership truth; this ADR narrow-extends pool release
    + allows a second viewType for Live only.
  - ADR-014/015 Live-motion deferral is paid across Cap 9 phases; ADR-018 size
    semantics unchanged.
  - ADR-009/010/012 continue to bind layers, composition root, ARB/tokens.
  - Cap 9.2 delivers native hosts + Pigeon channels; Cap 9.3 wires Dart
    domain/gateway/composition root; Feed play-once orchestration is Cap 9.4.
  - **Mute after clear (Cap 9.6 reminder, not a Cap 9.2 defect):** Video host
    `setMute` only sets `activePlayer?.isMuted` — there is no host-persisted mute
    flag. `clearPlaybackPool` correctly does not invent one. After clear (or any
    new AVPlayer), the new player starts at AVFoundation default until Dart
    calls `setMute` again. That re-apply window is pre-existing for every pool
    rebuild, not introduced by Cap 9; Cap 9.6 (mute preference binding) must
    document/ensure Dart re-applies the shared preference after video reactivation.
  - Accepted date/anchor = implementing work `98fe191` (2026-08-10).
- POC-08 Result (Cap 9.7, 2026-08-11):
  **PASS** on available samples (notes
  `docs/acceptance/cap9-9.7-poc08-notes.md`; Style matrix
  `docs/acceptance/cap9-9.6-playback-style-matrix.md`). iPhone 13 Pro: items
  1–8 exercised (S1–S5 PASS; Q7 jump OK; offline iCloud static fallback PASS;
  rapid leave/return stress PASS). iPhone 17: P1–P4 + stress PASS; P5–P7 /
  Style **N/A** (no iCloud library photos / insufficient Live edit materials).
  Mid-gate: Mute ON → Videos lost mute until host-persisted `muted` + re-apply
  on `pendingPlay` / new AVPlayer — work `474fb6a` (extends Cap 9.6 Dart
  re-apply; Dart-only was insufficient). New Known debt UX-1 (visible
  spin-then-fail on offline iCloud prepare) and UX-2 (badge+spinner →
  bottom-right). No Q7 jump debt. Status remains **Accepted**; POC-08 closed
  PASS.

---

## ADR-020: Cap 10 Asset Source + Source Pool Definition domain models

- Status: Accepted (2026-08-11)
- Commit/PR anchor: 00b52ad
- Plain summary (owner reads this):
  Cap 10 adds Dart-only domain types for Source Pool recipes (ordered Asset
  Source references, ephemeral/saved persistence policy, capacity constants)
  and expands domain source kinds to include Album / Smart Album references.
  It does not list or resolve albums, build Pool UI, save presets to disk,
  or model Generated Clip specialization — those stay later capabilities.
- Context / what problem forced this:
  Cap 6 / ADR-013 delivered three built-in sources only; Cap 7 / ADR-014
  drives Main Browse from a single `SourceReference.resolve` with no
  SourcePoolDefinition. Kickoff Glossary and ADR-E/G/H/L/P require Pool
  Definitions composed solely of Asset Source references (Live Binding
  recipes, not Media Item snapshots), with MVP kinds including Album and
  Smart Album. STATE schedules Cap 10 as domain models only, then Cap 11
  Live Resolution / Availability / Identity Coalescing / Resolved Pool
  Snapshot, later Build-a-Pool UI and Saved Pool persistence. Without a
  Cap-scoped contract, Cap 10 risks: opening Pigeon/Host album list early;
  inventing Generated Clip binding fields before the Physical Clip /
  backing Album capability; wiring Main Browse to SPD before Snapshot
  exists; or silently changing Cap 6 gateway mapping.
- Decision (what was chosen):
  1. **Scope = Dart domain + unit tests only (D1=A / D7=A).** No Pigeon
     schema change, no Host change, no
     `lib/platform/photo_library_gateway.dart` mapper change. Mapper
     continues to `throw` for wire `album` / `smartAlbum` / `other`.
  2. **No Generated Clip specialization types in Cap 10 (D2 cut).** Pool
     may later hold backing-album identity only via ordinary `album`
     `SourceReference`. Field shapes for Generated Clip Source wait for
     the dedicated Photos import / Clip Descriptor / Generated Clip
     Source capability. ADR Out of scope only — no Dart types that tests
     could freeze.
  3. **Generalize existing `SourceReference` (D3=A).** Do not invent a
     parallel `AssetSourceReference` type. Cap 6 built-in three legal
     pairs and `isLegalBuiltInPair` remain.
  4. **Domain `AssetSourceKind` adds `album` and `smartAlbum` (D8=A).**
     Wire `other` stays out of domain; mapper still throws on `other`.
  5. **Main Browse / Cap 7 feed: zero wiring (D4=A).** No ephemeral
     single-source SPD factory consumption; no change to
     `resolve(SourceReference)` call path for All / Photos / Videos.
  6. **Exhaustiveness-only call-site updates allowed.** Expanding
     `AssetSourceKind` may require reject/unreachable switch arms and
     updates to `asset_source_contract_test.dart` value-count assertions,
     `fake_asset_source_repository`, and smoke UI switches. **Forbidden:**
     changing All / Photos / Videos behavior; touching gateway mapper
     logic.
  7. **`SourcePoolDefinition` + `PersistencePolicy` (D6=A).** Shape:
     `id`, optional `displayName`, `persistencePolicy` (`ephemeral` |
     `saved`), `orderedSourceReferences[]`. `saved` is constructible at
     the type level; Cap 10 ships no repository / persistence consumer
     (Saved Pool CRUD = later Cap).
  8. **Capacity (kickoff ADR-P):** validate max **30** Asset Source
     references per Definition now; expose max **10** Saved Pool Presets
     as a named constant only (enforcement / count logic = Saved Pool Cap).
  9. **`ItemOrderingPolicy` slot (D5=A / D9=A):** standalone enum +
     `forKind(AssetSourceKind)` helper — built-ins map to creation-date
     descending (ADR-013); `album` / `smartAlbum` map to `unspecified`
     (ADR-M Album ordering Open Question remains open). Not stored on
     Definition or Reference fields.
  10. **Acceptance:** unit tests + docs/ADR only; no device PoC.
  11. **Docs workflow (E2 / F1=A / F2=A):** Cap 10.1 docs commit appends
      this entry as **Proposed** (no Accepted date, no fake anchor) and
      adds the GLOSSARY Generated Clip Cap 10 cross-ref. After the first
      Cap **10.2** work commit exists, a later docs commit flips Status to
      Accepted with that work sha as anchor (not inside the work commit;
      not deferred to Cap 10 close-out).
- Rejected alternatives (why not B):
  - Cap 10 opens album list/resolve Host or gateway mapper (D7=B) —
    rejected; no observable Host album payloads yet; Cap 11 owns live
    mapping.
  - Model `GeneratedClipSourceBinding` / `generatedClip` kind now —
    rejected; specialization lands with Photos import / Clip Descriptor
    Cap; early field freeze risks rewrite.
  - Parallel `AssetSourceReference` type — rejected; generalize
    `SourceReference`.
  - Wire Main Browse through SPD in Cap 10 — rejected; Snapshot layer
    not present; ADR-014 path stays until a later Cap migrates.
  - Close ADR-M Album ordering in Cap 10 — rejected; needs verified
    collection order PoC / later Ordering Cap.
  - Domain includes wire `other` — rejected (D8=A); reserved until a
    product meaning exists.
  - Forbid constructing `persistencePolicy: saved` until Saved Cap —
    rejected; type allows `saved`, persistence consumer deferred.
  - Put ADR Accepted inside the 10.2 work commit — rejected; two-commit
    discipline (F1=A).
- Consequences / constraints accepted:
  - Cap 10 does **not** pay any Known debt table row.
  - Identity Coalescing, Resolved Pool Snapshot, Asset Source
    Availability runtime, Session Queue / Default Profile, Build-a-Pool
    UI, Saved Pool persistence remain later STATE capabilities.
  - POC-02 Query Source stays out of MVP; Date Range / Query kinds are
    not instantiated.
  - Kickoff ADR-J Generated Clip = Album specialization remains product
    truth; Cap 10 only refuses to freeze implementation fields early.
  - Architecture guards must stay green on any `lib/` touch
    (ADR-009/010/012).
  - Accepted date/anchor = first Cap 10.2 work `00b52ad` (2026-08-11),
    per F1=A (not Cap 10 close-out; not inside the work commit).

---

## ADR-021: Cap 11 Live Resolution, Availability, Identity Coalescing, Snapshot

- Status: Accepted (2026-08-11)
- Commit/PR anchor: `5179ac1` (Cap 11.2 work — first Cap 11 implementing
  commit; list albums + open album/smartAlbum gateway mapping)
- Plain summary (owner reads this):
  Cap 11 resolves a Source Pool Definition into a runtime Resolved Pool
  Snapshot: list/resolve User and Smart Albums, report per-source
  Availability, coalesce duplicate PHAssets by first appearance, and keep
  Main Browse on its Cap 7 single-source path. Limited Access never lists
  albums; multi-source resolve runs sequentially in Dart.
- Context / what problem forced this:
  Cap 10 (ADR-020) delivered SourcePoolDefinition and album/smartAlbum
  domain kinds but left gateway mapping throwing and Host list/resolve
  built-in-only (ADR-013). Kickoff ADR-E/H/K/M and Glossary §7–8/§16
  require Live Binding resolution, Identity Coalescing, and Availability
  before Session Queue work. Album Item Ordering was still `unspecified`
  (ADR-020 / ADR-M). Cap 11 must lock list/resolve behavior, coalescing,
  and orchestration without Build-a-Pool UI or Main Browse migration.
- Decision (what was chosen):
  1. **Album / Smart Album ordering = creationDateDescending (D1=A).**
     **Reason:** reuse the Cap 6 / ADR-013 built-in path already verified
     on the owner's ~40k library (creation-date descending Host sort) —
     not a shortcut that skips album-order validation. Photos *collection*
     order remains an open product question (ADR-M); Cap 11 deliberately
     does not open a separate collection-order PoC because the chosen
     mechanism is the same already-proven pipeline, applied to album /
     smartAlbum fetches. **Implementation status:** Cap 11.3 work
     `d1d01f0` updates `ItemOrderingPolicy.forKind` so album/smartAlbum
     map to `creationDateDescending` (Host fetch uses the same sort).
  2. **`listAssetSources` includes User Albums + Smart Albums + the three
     built-ins (D2=A).** Utilities UI sections are not sources. Approximate
     `estimatedCount` allowed for albums (ADR-013 reserved semantics).
     Cap 11.2 implements listing; album/smartAlbum resolve remains 11.3.
  3. **Limited Access list behavior (ADR-K aligned):** Under Limited,
     `listAssetSources` returns **only** the three built-ins (accessible
     subset). User Album and Smart Album entries are **omitted entirely**
     — they do **not** appear with `availability: unauthorized`. Resolve of
     an album/smartAlbum reference under Limited (e.g. stale Full-Access
     Saved ref) returns **unauthorized** and does not enumerate members
     (ADR-K: do not list or resolve Album/Smart Album).
  4. **Pool orchestration in Dart (D3=A), sequential only.**
     `resolvePool(SourcePoolDefinition)` calls existing `resolveSource`
     **one source at a time** in Definition order. Identity Coalescing
     runs **incrementally** after each source: merge that source's ids
     into a growing accumulator + seen-id set, then **discard** that
     source's full `assetIdentifiers` list before the next
     `resolveSource`. **No concurrent** multi-source resolve in Cap 11.
     Peak memory: at most **one** in-flight full id list + the growing
     coalesced accumulator + seen-id set — not N full lists held
     simultaneously. Accepts repeated bridge cost vs ADR-013
     single-source cost multiplied by source count. A native
     `resolvePool` HostApi is out of Cap 11 scope.
  5. **Identity Coalescing = first appearance (kickoff ADR-M §6).** Same
     `PHAsset.localIdentifier` kept at the earliest Source Reference
     position; later duplicates dropped. No visual-similarity dedupe.
  6. **ResolvedPoolSnapshot** holds the **coalesced** ordered asset ids
     + per-source Availability (and related light metadata as needed —
     e.g. counts / status, not raw per-source id arrays). **Must not**
     retain fields such as `perSourceRawIds` / per-source full identifier
     lists after coalesce (peak-memory and contract: Snapshot is the
     coalesced view). No Media Item count hard cap (ADR-P). Not
     user-saveable (ADR-H).
  7. **Partial source failure — confirmation of Glossary §16 (D5), not a
     new Cap 11 product fork:** Glossary §16 already states that as long
     as the Resolved Pool Snapshot has ≥1 Media Item, browsing may start;
     when some Sources are Empty / Unavailable / Unauthorized, the App
     shows source-level **non-blocking** hints and does **not** invalidate
     the whole pool for one failed Source. Cap 11 **confirms** that text
     for Live Resolution / Snapshot construction. Option B ("fail the
     entire pool if any source is Empty/Unavailable/Unauthorized") was
     never a viable Glossary reading — §16 excludes it — so D5 is
     confirmation, not a fresh A/B choice. All-empty / all-failed still
     yields a structured empty / availability outcome for UI (product
     copy may land later).
  8. **Main Browse unchanged (D4=A).** Cap 7 single-source resolve path
     stays. Cap 11 exposes resolvePool + list albums via domain /
     smoke-debug only.
  9. **Gateway mapper:** Map pigeon `album` / `smartAlbum` into domain;
     wire `other` still throws. Opens ADR-020 D7 Cap-11 handoff.
  10. **Out of scope:** Session Queue / Default Profile / Eligibility /
      Shuffle; Build-a-Pool UI; Saved Pool CRUD; Generated Clip
      specialization; Query Source; concurrent resolve; Photos
      collection-order PoC.
  11. **Docs workflow:** Cap 11.1 docs commit appended this entry as
      **Proposed**. This docs commit flips Status to **Accepted** with
      Cap 11.2 work sha `5179ac1` as anchor (F1=A / E2; not inside the
      work commit). Accepted date from
      `git log -1 --format=%cs 5179ac1` → 2026-08-11.
- Rejected alternatives (why not B):
  - Album ordering via Photos collection order / ascending — not chosen
    for Cap 11; Cap 11 reuses the already-verified creationDateDescending
    Host path (ADR-013) rather than opening a new collection-order PoC.
  - List albums only in Cap 14 — rejected; Cap 11 title requires live
    album resolution and Availability.
  - List albums under Limited as `unauthorized` rows — rejected; ADR-K
    "do not list or resolve" means omit from list.
  - Concurrent Dart `resolveSource` fan-out — rejected; peak memory
    would be ~N full id lists; sequential bounds peak to one list +
    coalesced accumulator + seen-id set.
  - Snapshot keeps per-source full id lists after coalesce — rejected;
    Snapshot is coalesced ids + Availability only.
  - New Pigeon `resolvePool` in Cap 11 — rejected; reuse resolveSource.
  - Wire Main Browse through SPD/Snapshot now — rejected (D4=A).
  - Fail entire pool if any source Empty/Unavailable/Unauthorized —
    not a Glossary §16 option (D5 confirmation; B excluded a priori).
  - Amend ADR-020 in place — rejected; append ADR-021.
- Consequences / constraints accepted:
  - Cap 11 does **not** pay any Known debt table row.
  - Multi-source resolve wall-clock ≈ sum of per-source resolve times.
  - ~40k id lists remain an accepted cost per source (ADR-013); Snapshot
    may approach union size after coalescing.
  - Cap 12+ consumes Snapshot; Cap 14 builds Pool UI on listAssetSources.
  - Cap 11.2 landed list + mapper (`5179ac1`); Cap 11.3 landed
    album/smartAlbum resolve (`d1d01f0`); Cap 11.4 landed sequential
    `resolvePool` + coalesced Snapshot (`fd22ece`); Cap 11.5 landed
    composition / smoke-debug (`d76dbe3`); Cap 11.6 device coalesce
    PASS (`cap11-11.6-notes.md`). Cap 11 Capability Roadmap closed in
    the 11.7 docs commit (PHASE_HISTORY snapshot).
  - Accepted date/anchor = Cap 11.2 work `5179ac1` (2026-08-11), per F1=A
    (unchanged; 11.3–11.7 are later implementing / acceptance / close-out
    commits, not a new ADR).

---

## ADR-022: Cap 12 Session Queue + Default Profile + Sequential Item Ordering lock

- Status: Accepted (2026-08-12)
- Commit/PR anchor: 87d7dce
- Plain summary (owner reads this):
  Cap 12 adds Dart-only Session Configuration and a Sequential Session
  Queue builder on top of Cap 11's Snapshot. Default Profile derivation
  returns kickoff values (Mixed → Shuffle) but is not wired to Main
  Browse — ADR-014 Sequential remains the effective product default
  until Cap 13. Item ordering for current source kinds is locked to
  creation-date descending. Shuffle queue construction and Session
  Continuity stay later capabilities.
- Context / what problem forced this:
  Cap 11 (ADR-021) delivers a coalesced Resolved Pool Snapshot and
  leaves Session Queue / Default Profile / Eligibility / Shuffle out of
  scope. Kickoff ADR-M/N and Glossary §9/§11 require: a finite Session
  Queue derived from Snapshot + Session Configuration; Default Profile
  (Pure Clip vs General/Mixed); Sequential concat by Source Reference
  order plus within-clip `segmentIndex` order. STATE splits this from
  Endless Shuffle / Queue Stability / Session Continuity (Cap 13) and
  from Auto-play Eligibility (later). ADR-014 still binds Main Browse to
  Sequential + Manual and deferred kickoff Shuffle. Without a Cap-scoped
  contract, Cap 12 risks: wiring Shuffle into the production feed;
  implementing Queue-layer `segmentIndex` sort that ADR-021's flat
  Snapshot cannot support; omitting `OrderPolicy.shuffle` while the
  derivation function must return Shuffle; or inventing Consumption
  Session / Clip Descriptor types early.
- Decision (what was chosen):
  1. **Scope = Dart domain + unit tests; Main Browse zero wiring
     (D1=A).** No Pigeon / Host change. No Main Browse migration onto
     SPD / Snapshot / Session Queue. Optional `library_smoke` probe
     only. Architecture guard (lands with the builder file):
     `main_browse` ↛ `build_session_queue` — same shape as ADR-021's
     `main_browse` ↛ `resolve_pool` test.
  2. **Default Profile derivation ≠ product default (D2=A).**
     `deriveDefaultSessionProfile` returns kickoff ADR-N values:
     General/Mixed → Shuffle + Manual + Repeat All; Pure Generated
     Clip → Sequential + Manual + Repeat All. **This cap introduces a
     derivation function whose output is not wired to any product
     surface; ADR-014 remains the effective default until Cap 13
     supersedes it.** Without Clip Descriptor / `generatedClip` kind,
     every constructible pool classifies as General/Mixed; Pure is
     reserved / unreachable (same discipline as ADR-020: no Generated
     Clip specialization types).
  3. **No `ConsumptionSession` type (D3=A).** Cap 12 ships
     `SessionConfiguration` + `SessionQueue` only. Continuity,
     Checkpoint, Runtime Presentation State, and current-item mapping
     stay Cap 13 / later.
  4. **ADR-M §5 closed for instantiated kinds (D4=A).** Sequential
     Item Ordering for Entire Library, Media Type, Album, and Smart
     Album remains `creationDateDescending` (ADR-013 / ADR-021). Photos
     Collection Order is not adopted. No new ordering PoC. Sequential
     Session Queue for these kinds = `snapshot.coalescedAssetIds`
     (Source Reference concat already done at resolvePool).
  5. **`segmentIndex` step executes at Generated Clip resolve-time,
     not as a Queue-layer sort (D5).** Sequential ordering's
     `segmentIndex` step is deferred to the Generated Clip source's
     resolve-time policy, not implemented as a Queue-layer sort —
     this reinterprets where Glossary §11's two-step algorithm
     executes. Product-visible order is unchanged (Source Reference
     concat, then `segmentIndex` ascending within each Generated Clip
     Source). **Why the execution site must move:** ADR-021 Snapshot
     is a flat coalesced id list with no per-source raw ids; Queue
     cannot regroup-and-sort by `segmentIndex` without reopening that
     contract or taking Clip Descriptor + source membership as Queue
     inputs (out of Cap 12). Cap 12 Sequential builder does not read
     Clip Descriptors. Generated Clip Cap owns the resolve-time
     policy, including how non-descriptor members of a backing album
     are ordered relative to clips (ADR-J §5). Do not add
     `segmentIndexAscending` to `ItemOrderingPolicy` until that kind
     exists.
  6. **`OrderPolicy` is a two-value enum including `shuffle`;
     `buildSessionQueue` refuses shuffle (D6=A / option a).**
     `OrderPolicy` = `{ sequential, shuffle }` so
     `deriveDefaultSessionProfile` can return a type-correct Mixed
     default. Cap 12 `buildSessionQueue` implements Sequential only
     (finite list; Repeat Policy is not expanded). Passing
     `OrderPolicy.shuffle` is a **documented domain refusal** (not
     `UnimplementedError`, which reads as unfinished work). Exact
     error type is a 12.4 implementation detail (`UnsupportedError` /
     `ArgumentError` acceptable) with a message that cites Cap 13 /
     this ADR. Cap 13 implements shuffle construction.
  7. **Manual Queue = full Snapshot (no Eligibility type).** Mode
     Eligibility stays the later Auto-play Cap. Cap 12 does not
     introduce eligibility enums or filter interfaces.
  8. **Out of scope:** Endless Shuffle algorithm / round-boundary
     rules (ADR-M §7–8); Queue Stability / Continuity (ADR-I);
     Auto-play Presets and lock-screen / Background Audio (ADR-N
     §6–8, ADR-O); SessionCheckpoint; Build-a-Pool UI; Saved Pool
     CRUD; Generated Clip types / `segmentIndex` implementation;
     Main Browse wiring; Pigeon; Known debt rows (playhead remains
     Cap 13).
  9. **Docs workflow:** This Cap 12.1 docs commit appends this entry
     as **Proposed** (no Accepted date, no fake anchor). After the
     first Cap **12.2** work commit exists, a later docs commit flips
     Status to Accepted with that work sha as anchor (not inside the
     work commit; not deferred to Cap 12 close-out).
- Rejected alternatives (why not B):
  - Wire Main Browse through Sequential Session Queue in Cap 12
    (D1=B) — rejected; production feed / hitch surface; ADR-014 path
    stays until a later Cap migrates.
  - Apply kickoff Shuffle as the product default now (D2=B) —
    rejected; would supersede ADR-014 D2/D3 and pull Cap 13 early.
  - Built-in tabs permanently Sequential; Shuffle only for user-built
    Pools (D2=C) — rejected; product fork not requested; kickoff
    Mixed default remains the long-term rule for Cap 13.
  - Slim `ConsumptionSession` in Cap 12 (D3=B) — rejected; Continuity
    is Cap 13; extra type freezes a session shape early.
  - Leave ADR-M §5 open until Generated Clip (D4=B) — rejected; all
    instantiated kinds already have verified
    `creationDateDescending`; capability title requires the lock.
  - Open a Photos Collection Order PoC (D4=C) — rejected; Cap 11
    already declined that path.
  - Keep Glossary §11's two-step as a Queue-layer sort (D5 inverse)
    — rejected; impossible against ADR-021 Snapshot without
    reopening per-source id lists.
  - `OrderPolicy` is Sequential-only until Cap 13 (D6 option b) —
    rejected; contradicts D2=A: derivation must return Shuffle and
    the type must be able to hold it.
  - `buildSessionQueue` throws `UnimplementedError` on shuffle —
    rejected as the named contract; that type means "author forgot";
    refusal must read as "not this Cap".
  - Implement shuffle construction in Cap 12 but leave it unwired —
    rejected; STATE schedules Endless Shuffle as Cap 13.
  - Eligibility filter interface now, identity/all-pass default —
    rejected; avoid freezing Cap 16 shapes (ADR-020 D2 discipline).
  - Amend ADR-014 or ADR-021 in place — rejected; append ADR-022.
- Consequences / constraints accepted:
  - **Derive ≠ apply (product):** This cap introduces a derivation
    function whose output is not wired to any product surface;
    ADR-014 remains the effective default until Cap 13 supersedes it.
    Readers must not treat Mixed→Shuffle in the derivation function
    as "Shuffle shipped".
  - **Derive ≠ apply (domain):** Even a direct call
    `buildSessionQueue(snapshot, deriveDefaultSessionProfile(...))`
    refuses today, because Mixed derivation yields shuffle. Sequential
    tests pass an explicit Sequential configuration. This is the
    domain seam for Cap 13, not a broken pipeline.
  - Glossary §11 product text (two-step Sequential algorithm) is
    **not rewritten**; only the engineering execution site of step 2
    is recorded here and in a GLOSSARY Cap 12 note. Observable order
    for a future Pure / multi-clip Sequential queue remains Source
    order then `segmentIndex` within each clip source.
  - Cap 12 does **not** pay any Known debt table row. Same-asset
    playhead across All↔Videos stays Session Continuity (Cap 13).
  - Architecture guards must stay green on any `lib/` touch
    (ADR-009/010/012). The `main_browse` ↛ `build_session_queue`
    guard lands when that file exists (12.4/12.5).
  - Accepted date/anchor = first Cap 12.2 work `87d7dce` (2026-08-12),
    per F1=A (not Cap 12 close-out; not inside the work commit).

---

## ADR-023: Cap 13 Endless Shuffle + Queue Stability + in-session Continuity lock

- Status: Accepted (2026-08-13); D10’s 13.6 must-pass Instruments
  V-hard (mean hitch < 25 ms/s AND zero Severe Hang) is superseded
  for close-out by ADR-030 (2026-08-19)
- Commit/PR anchor: 1d15caf
- Plain summary (owner reads this):
  Cap 13 makes kickoff General/Mixed default Shuffle the real Main Browse
  experience (Endless Shuffle rounds), adds in-session Queue Stability /
  Continuity for Order/Repeat changes on the same Snapshot, and accepts
  same-asset playhead sharing across All↔Videos as intentional Host
  behaviour — not a bug fix. Auto-play Eligibility, Background Audio,
  and SessionCheckpoint stay later capabilities.
- Context / what problem forced this:
  Cap 12 (ADR-022) shipped Session Configuration + Sequential
  `buildSessionQueue` and a Mixed→Shuffle derivation that is not wired
  to Browse; shuffle construction throws a documented `UnsupportedError`.
  ADR-014 still binds Main Browse to Sequential + Manual and structurally
  deferred kickoff Shuffle to this capability. Kickoff MVP Scope §7 and
  ADR-N require General/Mixed → Shuffle + Manual + Repeat All with Endless
  Shuffle round semantics (ADR-M §7–8). Without a Cap-scoped lock, Cap 13
  risks: delivering domain-only shuffle without product apply (re-deferring
  ADR-014); pulling Auto-play Eligibility / Checkpoint SQLite / Background
  Audio early; treating All↔Videos shared playhead as a Host bug fix when
  Continuity is defined on one Snapshot; or dropping the Cap 7.7a Profile
  hitch hard gate when Shuffle reopens the production feed surface.
- Decision (what was chosen):
  1. **Main Browse product apply — Mixed → Shuffle (D1=A).** Cap 13
     wires Main Browse built-in tabs (All / Photos / Videos as
     General/Mixed pools per ADR-014 / ADR-N) so
     `deriveDefaultSessionProfile` + Endless Shuffle `buildSessionQueue`
     become the **effective** product default. This **supersedes
     ADR-014 Decisions 2–3** (Sequential product default / deferred
     Shuffle) for that surface when Cap 13 wiring lands. Kickoff MVP
     Scope §7: General/Mixed default is Shuffle, Manual, Repeat All —
     not an optional mode. Cap 13 title delivers the Shuffle
     **experience**, not only domain scaffolding. Cap 12 ADR-022
     shuffle refusal is removed when 13.2 lands.
  2. **Slim in-memory `ConsumptionSession` (D2=A).** Cap 13 introduces
     a slim session type holding at least: Resolved Pool Snapshot,
     Session Queue, Session Configuration, current item / queue index,
     and optional playback-position reference as needed for Continuity
     mapping. **Excluded:** `runtimePresentationState`, `playbackState`,
     `audioRoute` (kickoff ties these to foreground/lock-screen —
     Background Audio Cap). Cap 13 Continuity **subset** = Order /
     Repeat changes on the **same** Snapshot (kickoff Continuity
     bullets for Manual↔Auto and lock/unlock stay later Caps).
     Browse-history field: include only if 13.3 mapping needs it;
     otherwise defer without inventing Runtime Presentation fields.
  3. **Zero SessionCheckpoint / SQLite (D3=A).** No
     `saveSessionCheckpoint`, no new persistence tables. Kickoff Rule H
     *allows* caching Snapshot for recovery; it does not require Cap 13
     to persist across process death. Rule I / Continuity examples are
     in-session. SessionCheckpoint remains its own Capability Roadmap
     row.
  4. **Manual Shuffle = full Snapshot; no Eligibility (D4=A).** Shuffle
     permutes all coalesced Snapshot ids. Mode Eligibility stays the
     Auto-play Cap (kickoff N §6+; Shuffle Queue examples mix photos and
     clips with no audio-track filter). Aligns Cap 12 ADR-022 “Manual
     Queue = full Snapshot”.
  5. **Injectable `Random` + finite first≠last retry (D5=A).**
     Fisher–Yates with injectable `Random` (tests may pass a seeded
     instance; production uses a non-deterministic source). When
     `n > 1`, finite retries so the new round’s first id ≠ previous
     round’s last id (kickoff / Glossary: should try to avoid — mechanism
     required, not docs-only). Round is stable mid-play; reshuffle only
     at round boundary under Repeat All.
  6. **Playhead Known debt = reclassification Accepted, not a bug fix
     (D6=A).** `PlaybackApiHost` continues to key the app-scoped player
     by `assetIdentifier` (ADR-006). Same Photos id under All vs Videos
     may share playhead / ended-on-last-frame. **Handling = reword the
     Known debt row from “pending fix at Session Continuity” to
     “Accepted behaviour”.** Explicit: this is **not** a behaviour
     fix and **not** cross-tab Continuity. Constrained by D8=A
     (tab switch = new Session). Continues owner Cap 8.8 preliminary
     view (`cap8-8.8-notes.md`). **No `PlaybackApiHost` code change in
     Cap 13 for this debt.**
  7. **Queue Stability = domain contract + unit tests (D7=A).** ADR-I
     §§1–3 are passive outcomes (Snapshot/Queue do not auto-mutate on
     library change; unchanged config ⇒ stable queue). Cap 11/12
     already produce a one-shot Snapshot and derive Queue from it —
     Cap 13 does **not** install a Photos observer solely to no-op.
     Rebuild + Continuity mapping when Order/Repeat change (ADR-I §4
     without Eligibility variants).
  8. **Tab switch = new Session (D8=A).** Changing All / Photos /
     Videos starts a new Consumption Session (feed index 0). Continuity
     applies only within the same tab / same Snapshot Session (e.g.
     Order/Repeat rebuild). Kickoff Continuity is anchored on one
     Resolved Pool Snapshot; built-in tabs are distinct Asset Sources
     (ADR-013) with distinct resolve results. Aligns ADR-014 Decision 4
     (tab reset to queue head). No cross-tab Continuity in Cap 13.
  9. **Architecture guards — composition seam (D9=A, depends on D1=A).**
     Cap 13 replaces the Cap 12 `main_browse` ↛ `build_session_queue`
     (and, if needed for the chosen wiring path, `main_browse` ↛
     `resolve_pool`) ban with an ADR-010 composition-root seam:
     features must not construct gateways or hold platform concrete
     types; wiring happens at `lib/main.dart` / `lib/app/**` (or an
     owner-approved provider seam). D9 is an explicit owner decision —
     not implied solely by D1.
  10. **Acceptance hard gate when Browse is wired (13.6).** Instruments
      **Profile** Hang retest on **iPhone 13 Pro (Kafka)**, UDID
      `00008110-001114420AEA801E`, same V-hard rules as ADR-014 Cap
      **7.7a**: mean hitch **< 25 ms/s** AND **zero** Severe Hang on
      production chrome with Shuffle-driven feed; **not** Conditional
      Pass. Does **not** clear the Release hang Known debt row (same
      split as 7.7a). No new PoC gate; no Checkpoint recovery test.
  11. **Out of scope:** Auto-play Presets / Mode Eligibility (N §6+);
      ADR-O iCloud Fallback; Background Audio / lock-screen / Now
      Playing; SessionCheckpoint persistence; Build-a-Pool / Saved Pool
      CRUD; Generated Clip / Pure Sequential product path; Eligibility
      filter types; Photos library observer for Stability; cross-tab
      Continuity; releasing Cap 7 Release hang debt.
  12. **Docs workflow:** Cap 13.1 appends this entry as **Proposed**.
      After the first Cap **13.2** work commit, a later docs commit
      flips Status to Accepted with that work sha as anchor. When
      Accepted, ADR-014 Decisions 2–3 are recorded superseded for
      Browse Mixed default (ADR-014 Status line: flip only if owner
      chooses full-entry supersession; otherwise Consequences here
      remain the authoritative partial supersession). Playhead Known
      debt row rewrite lands in phase **13.5** docs (not 13.1).
- Rejected alternatives (why not B):
  - Domain-only Shuffle without Browse apply (D1=B) — rejected;
    re-defers ADR-014’s structural deferral; contradicts MVP Scope §7
    and this capability’s title.
  - Sequential SessionQueue wire first, Shuffle later in Cap (D1=C) —
    rejected; unnecessary second product flip inside one Cap.
  - Full Glossary ConsumptionSession including Runtime Presentation
    (D2=C) — rejected; pulls Background Audio fields early.
  - Providers/helpers only, no session type (D2=B) — rejected; Continuity
    mapping needs an explicit in-memory session seam for Cap 13.
  - Minimal SessionCheckpoint in Cap 13 (D3=B) — rejected; conflicts
    with STATE’s separate Checkpoint Cap and kickoff in-session Continuity
    examples.
  - Eligibility enums with Manual all-pass (D4=B) — rejected; freezes
    Auto-play Cap shapes early (Cap 12 D7 discipline).
  - Docs-only first≠last (D5=B) — rejected; Glossary requires a
    mechanism (“should try to avoid”), not prose alone.
  - Deterministic production seed (D5=C) — rejected; undermines
    user-perceived randomness of Shuffle.
  - Split Host key `(sourceId, assetId)` (D6=B) — rejected; high Host
    risk, low product gain given Cap 8.8 preliminary accept and D8=A.
  - Leave playhead debt open (D6=C) — rejected; ADR-022 already pointed
    Cap 13 as the revisit.
  - Cross-tab Continuity (D6=D / D8=B) — rejected; kickoff Continuity is
    same-Snapshot; tabs are different sources.
  - Photos observer no-op for Stability (D7=B) — rejected; over-engineering
    vs ADR-I passive wording.
  - Keep both architecture bans while wiring Browse (D9=B) — rejected;
    incompatible with D1=A without an approved composition seam.
- Consequences / constraints accepted:
  - **Product default flips:** After 13.4 wiring + ADR Accepted, Main
    Browse Mixed pools use Shuffle + Manual + Repeat All. ADR-014
    Decisions 2–3 no longer describe the effective Browse default.
    ADR-014 Decision 4 (tab → index 0) remains and aligns with D8=A.
  - **Playhead debt handling = reclassification, not fix:** ADR-023 /
    Cap 13.5 rewrite the Known debt row to Accepted behaviour under
    D8=A; readers must not treat Cap 13 as having “fixed” All↔Videos
    playhead sharing.
  - Cap 12 SQ-4 / SQ-7 tests that expected shuffle `UnsupportedError`
    were rewritten as SHUF-1…7 in Cap 13.2 work `1d15caf`.
  - Architecture suite must stay green; guard tests update with D9 seam
    in 13.4.
  - 13.6 Profile V-hard is **must-pass** to close Cap 13 when D1=A;
    hitch regression blocks close-out.
  - Release hang Known debt stays on Final performance Cap.
  - No Cap 13 Known debt **adds**; playhead row is **reclassified** in
    13.5 (not deleted without replacement wording).
  - Accepted date/anchor = Cap 13.2 work `1d15caf` (2026-08-13), per
    docs workflow (not Cap 13.1 docs and not Cap close-out).

---

## ADR-024: Cap 13.8 Browse Snapshot cache — never cache an empty resolve; a mapped failure is not “empty”

- Status: Accepted (2026-08-15)
- Commit/PR anchor: 1a4f316
- Plain summary (owner reads this):
  When a Browse tab resolves to zero items, WakeTok no longer remembers
  that emptiness for the rest of the process. A user who grants Limited
  access and lands on an empty All tab can switch to Photos or Videos
  and back, and All then shows content — no force-quit. Separately, a
  source that failed because of permissions now shows a failure message
  with a Retry button instead of the “no content in this source” copy,
  which had no Retry at all.
- Context / what problem forced this:
  Cap 13.6b device work (`docs/acceptance/cap13-13.6b-hang-diagnosis-notes.md`,
  draft 3) found that on a first-launch **Limited** library the default
  All tab showed empty copy while Photos / Videos had items, switching
  back to All stayed empty in the same process, and only force-quit +
  reopen made All populate. Two independent defects sit behind that:
  (a) `browseSnapshotCacheProvider` stored any non-hard-failure
  Snapshot, including one whose coalesced id list is length 0 — a
  **pre-13.4** behaviour inherited from ADR-014 Decision 5 / the Cap 7.6
  cache bullet, so one unlucky first resolve poisoned the whole process;
  (b) Cap 13.4 (`aa03be8`) routes per-source failures through ADR-021
  `resolvePool`, which records `unauthorized` / `albumUnavailable` in
  `sourceStatuses` instead of throwing, so the feed saw “resolved,
  zero ids” and rendered the empty-state copy with no Retry — a 13.4
  regression against the ADR-015 / ADR-021 empty-vs-failed split. Both
  had to be settled before Cap 13 could be described honestly, and (a)
  is an explicit, owner-approved **scope expansion** of Cap 13.
- Decision (what was chosen):
  1. **Never cache a successful but empty Snapshot.**
     `BrowseSessionNotifier._snapshotFor` calls `cache.put` only when
     there is no hard failure **and** `coalescedAssetIds` is non-empty.
     This narrowly supersedes the ADR-014 Decision 5 caching clause: the
     “at most one real `resolveSource` per built-in per session”
     guarantee no longer holds for an empty result. Everything else in
     Decision 5 (independent Host predicates, no Dart derivation of
     Photos / Videos from All, ids-only DTO) is untouched.
  2. **Mapped Failed renders the failure panel, not the empty panel.**
     When the ordered id list is empty and any `SourceResolveStatus`
     has availability `unauthorized` or `unavailable`, the feed shows
     the same `mainBrowseFeedResolveFailed` panel + Retry as a thrown
     resolve error; Retry is `ref.invalidate(browseSessionProvider)`.
     A genuinely empty source (no failed status) keeps the
     `mainBrowseFeedEmpty` copy with no Retry.
  3. **Failures are still never cached — continuity, not a new
     exception.** The `hasHardFailure` guard landed with Cap 13.4 and
     preserves the ADR-014 Cap 7.6 rule (“failures are never stored”)
     under `resolvePool` semantics, where failures no longer throw.
     Readers must not treat 13.8 as having changed failure caching.
  4. **Cap 13 scope expansion, recorded explicitly.** Decision 1 fixes
     behaviour that predates 13.4 and is therefore **not** part of the
     13.4 regression; only Decision 2 is. This ADR exists so the two
     are not later collapsed into “Cap 13 broke and fixed its own
     cache”.
  5. **Acceptance shape (13.8d).** Unit / widget: APP-6, APP-7,
     W-F4b, W-S1b (+4; suite 267) with the full `flutter test` and
     architecture suite green. Device: Kafka iPhone 13 Pro Profile,
     first-launch Limited — All → Photos/Videos → All has content with
     no force-quit. The `unauthorized` path is **unit-only** by owner
     decision (creating that state on device is not worth the
     permission thrash). No Instruments in 13.8.
  6. **Out of scope.** Resolving only after authorization / Limited
     selection has settled, any Photos library observer, and the
     remaining first-frame empty flash (Known debt, picked up by the
     iCloud media-loading capability). Cap 13.6’s Profile V-hard gate
     (ADR-023 D10) is untouched and Cap 13 stays blocked there.
- Rejected alternatives (why not B):
  - Keep the empty-cache behaviour as Known debt with no code —
    rejected; the sticky half required a force-quit to escape, which no
    user will discover, and the fix is a one-line predicate.
  - Resolve only after PhotoKit reports the Limited selection settled —
    rejected **for 13.8**; correct direction but permission/timing
    scope, far larger than this phase, and it would have pulled Cap 13
    into a second open front while 13.6 is blocked.
  - Invalidate the cache after the system Limited picker dismisses —
    rejected; patches one entry path only, leaves the empty-cache
    defect on every other path, and does not remove the first-frame
    race.
  - Render mapped Failed with the empty copy (status quo after 13.4) —
    rejected; drops Retry and contradicts ADR-021’s status semantics,
    where Failed and Empty are different outcomes.
  - Clear the whole Snapshot cache on every tab switch — rejected;
    would discard ADR-014 Decision 5’s performance intent for the
    normal non-empty case.
- Consequences / constraints accepted:
  - A genuinely empty source re-resolves on every tab revisit
    (bounded: one host call per revisit). Accepted as the price of not
    caching empty.
  - On first-launch Limited the **first** All frame may still flash
    empty, with no Retry, until the user switches tabs. Recorded as
    Known debt with the switch-away-and-back workaround and pointed at
    the iCloud media-loading capability; explicitly **not** fixed here.
  - ADR-014 Status records the Decision 5 caching-clause supersession;
    ADR-014’s reasoning is untouched.
  - No Host / Swift change, no Pigeon change, no theme or ARB key
    change (13.8b reuses the existing `mainBrowseFeedResolveFailed` /
    `mainBrowseFeedRetry` copy).
  - Cap 13.6 remains FAIL / blocked on gate-foundation grounds; 13.8
    neither lowers nor splits that bar, and 13.7 close-out stays
    unavailable.
  - Accepted date/anchor = Cap 13.8 work `1a4f316` (2026-08-15) —
    13.8b and 13.8c shipped in that single work commit; this docs
    commit is separate per two-commit discipline.

---

## ADR-025: Cap 14 current-item iCloud fetch, visual preheating, and loading states

- Status: Accepted (2026-08-15); the Decision 2 clause that
  current-item Layer 2 starts with **no dwell** is narrowly
  superseded by ADR-029 (2026-08-19; Cap 16.4 work `26294f5`) for
  **timing only**; the Decision 2 clause that the current item
  **shows Layer 1 when available** before Layer 2 is narrowly
  superseded by Cap **15.10** (2026-08-22; work `62a5a2b`) when
  **Session L2-ready** proof exists — **revisit only** (skip L1
  preview + dwell; video keeps poster until surface ready). First
  visit, iCloud miss, and no-proof paths unchanged. Still binding:
  `isNetworkAccessAllowed = true` including cellular (D1=A); Layer 1
  local-only policy, ±1 preheat, Overlay file-size, Live motion stay
  local-only; three-layer model and D2=B ±1 preheat unchanged
- Commit/PR anchor: a980506
- Plain summary (owner reads this):
  When you stop on a photo or video that lives in iCloud, WakeTok should
  still show a recognisable preview immediately in most cases, then load
  the real file (including on cellular) with a spinner on top, and let
  you swipe away to cancel. The first screen after granting Limited
  access must not claim the library is empty while PhotoKit is still
  catching up. This is not Auto-play lookahead or “waiting for the next
  video in a queue”.
- Context / what problem forced this:
  Cap 13.6 Profile V-hard is **blocked on a gate-foundation defect**,
  not because a hang was skipped or unfound
  (`docs/acceptance/cap13-13.6-notes.md`,
  `docs/acceptance/cap13-13.6b-hang-diagnosis-notes.md`): iCloud-only
  pages render as copy whose Retry is a no-op, and Shuffle scatters
  those pages, so Instruments is unreadable. That copy exists because
  ADR-006’s Cap 7.3 fill-in (`07d10d6`) sets
  `isNetworkAccessAllowed = false` on `requestDisplayAsset` /
  `requestPlayableVideo` and treats `PHImageResultIsInCloudKey` as a
  hard `iCloudDownloadRequired` — without falling back to the
  **local thumbnail / poster that PhotoKit usually already has**.
  Kickoff MVP Scope §1–2 (and the Glossary clause titled
  “Manual Doom Scroll” — cited, not adopted as WakeTok working
  vocabulary) already require: stay on the current item; show a media
  **loading** state; do not skip; show fetch / wait / fail / retry for
  iCloud-only resources. Cap 8 shipped a panel + Retry, but Retry
  cannot succeed under local-only Host policy.
  Separately, Limited first-launch All can resolve successful-empty
  before PhotoKit has written the Limited selection into
  `allFetchResult`. ADR-024 stopped **caching** that emptiness; the
  first frame can still show empty copy. Waiting for the Limited
  picker to dismiss is **not** a fix — that dismiss has already
  happened when the empty All resolve runs.
  Pulling the Capability Roadmap row “One-item Lookahead Fetch,
  Waiting for Media, iCloud Fallback” would import Auto-play
  Eligibility, Pending Eligibility, and ADR-O foreground/background /
  process-termination semantics. Kickoff ADR-O §1 / §3 and Glossary
  “Auto-play Fetch Rule” bind lookahead to Auto-play only. Kickoff
  ADR-P.5 allows bounded **local** visual preheating on Manual
  browse; it forbids downloading full originals merely to preheat.
- Decision (what was chosen):
  1. **Capability identity.** Title:
     **Current-item iCloud media fetch, visual preheating, and
     loading states** (Cap 14). Do **not** use “Doom Scroll” in the
     capability name, this ADR’s title, code identifiers, ARB keys, or
     test names. When citing kickoff, quote the Glossary heading
     “Manual Doom Scroll” or MVP Scope §1–2 as a spec reference only.
  2. **Three display layers.**
     - **Layer 1 — degraded preview (usually local, immediate):**
       show any image PhotoKit can return without network: thumbnail,
       degraded still, or **video poster**. Video preview **must not**
       use `requestDisplayAsset` (Host already returns
       `unsupportedMedia` for videos). Black / failure chrome is
       forbidden while Layer 1 succeeded.
     - **Layer 2 — full resource (current item only):** full still
       or playable video. `isNetworkAccessAllowed = true`, including
       cellular (D1=A). No App-level cellular toggle in this Cap
       (evaluate at Settings).
     - **Layer 3 — loading indicator:** spinner over Layer 1 while
       Layer 2 is in flight. User may swipe away at any time.
     **Failure / blank chrome is allowed only when Layer 1 is
     unavailable and Layer 2 has failed or there is no network.**
     Two copy paths: (a) Layer 2 still in flight — waiting, spinner,
     no Retry; (b) Layer 2 failed or cancelled — reason + **effective**
     Retry (a new network-allowed request). “Keep trying” means the
     current Layer 2 request is in flight — **not** an unbounded retry
     loop and **not** a Reachability observer.
  3. **Pigeon shape (D7=A).** Keep one-shot `Result` completions.
     Add `requestPreview` (local-only, stills **and** video poster,
     cancellable). Change existing `requestDisplayAsset` /
     `requestPlayableVideo` so the **current-item Layer 2** path may
     set `isNetworkAccessAllowed = true` and is cancellable. Do **not**
     introduce a FlutterApi event stream for opportunistic
     double-callbacks in this Cap. PhotoKit `.opportunistic` two-callback
     delivery does not fit one Pigeon `Result`; two requests, two
     completions.
  4. **Cancellation (in-scope, not an optimisation).** Leaving the
     current item cancels its in-flight Layer 2 request. Leaving the
     ±1 window cancels that neighbour’s preview. Host must retain
     request ids (`cancelImageRequest` / stop caching as applicable).
     Un-cancelled full fetches would waste cellular, pile work onto
     the hitch surface, and complete onto the wrong page.
  5. **±1 visual preheating (D2=B).** Preheat at most one item
     before and after the current item using **already-local**
     thumbnail/poster only (`networkAccessAllowed = false`). Do not
     start a Layer 2 download for neighbours. Aligns with kickoff
     ADR-P.5 (bounded visual preheat; no full original merely to
     preheat).
  6. **Live Photo (D3=A).** Still / key photo uses Layers 1–2.
     Motion stays local-only (ADR-019 UX-1 remains). Matches kickoff
     ADR-S: if motion is still in iCloud, show the still + loading;
     on motion failure, remain on the still — do not skip.
  7. **Narrow supersede of ADR-006 — Layer 2 current item only.**
     When this ADR is **Accepted**, ADR-006 Status will record that
     **only** the Cap 7.3 fill-in rule that **current-item full still
     / playable video** must use `isNetworkAccessAllowed = false` and
     must fail immediately with `iCloudDownloadRequired` is
     superseded. **Still binding:** Layer 1 preview, ±1 preheat, POC-10
     / Overlay file-size fetches, Live motion, and any other path not
     named here stay local-only. Do **not** treat “Cap 7.3 local-only”
     as a blanket lift. **Do not flip ADR-006 Status in the Proposed
     docs commit.**
  8. **Limited first-launch empty All (D4, restated).** Product: the
     first screen after granting Limited must not show empty copy
     while PhotoKit may still be populating `allFetchResult`.
     Mechanism: **not** “wait for the picker / auth callback” (that
     callback has already run). On a **successful empty** Snapshot
     (no hard failure): keep **resolve-loading** (not empty copy) and
     re-resolve **up to 3 additional times** with delays **500 ms,
     1000 ms, 2000 ms** after each empty result (four attempts
     including the first; ~3.5 s after the first empty). Then show
     empty copy if still empty (true empty library). Hard failures
     stay on the 13.8b failed panel; no automatic retry. No
     `PHPhotoLibraryChangeObserver` in this Cap (ADR-023 D7 / kickoff
     ADR-I: do not rebuild a non-empty Session because the library
     changed). Tab-switch re-resolve of empty (ADR-024) remains as
     backup.
  9. **Copy.** Retire or rewrite `mainBrowseFeedICloudOnly` (and debug
     `playbackProbeICloudOnly`): “iCloud-only on this device” is false
     once Layer 1 is the normal iCloud-only first paint. New waiting /
     failed strings via ARB + ADR-012.
  10. **Roadmap reorder.** Insert Cap 14 immediately after Cap 13 in
      execution order. **Skip (defer, do not delete)** Build-a-Pool,
      Saved Pool, and Auto-play Presets — they do not restore 13.6’s
      gate foundation. Rename the later row to **Auto-play One-item
      Lookahead Fetch, Waiting for Media, and iCloud Fallback** so
      “iCloud Fallback” is not ambiguous with Cap 14. Out of Cap 14:
      lookahead; Auto-play Waiting for Media / Pending Eligibility;
      ADR-O foreground vs background vs process termination; Mode
      Eligibility / Presets; file-size-triggered download.
  11. **Two open capabilities — intentional STATE deviation (D5).**
      `state-decisions-maintenance` allows only one ACTIVE capability
      in the Phase Roadmap. Cap 13 is not complete, so it cannot move
      to PHASE_HISTORY. STATE will: mark Cap 13 `[~]` on the
      Capability Roadmap; put YOU ARE HERE on Cap 14; replace the
      Phase Roadmap with 14.1–14.7; add a **Parked capability: Cap 13**
      section holding 13.6 (blocked, bar unchanged) and 13.7. This is
      an explicit deviation, not an accident.
  12. **Close-out binds 13.6 but does not run it (D6).** Cap 14 must
      not be marked `[x]` until STATE records that 13.6’s
      gate-foundation defect is **cleared as a blocker** (Layer 1+2+3
      on production chrome) and **YOU ARE HERE returns to Cap 13**
      with Phase Roadmap 13.6 + 13.7. The hitch retest itself remains
      **Cap 13.6** at the **unchanged** ADR-014 / ADR-023 D10 V-hard
      bar (not lowered, not Conditional Pass, not split). Cap 14’s
      last phase is docs / unpark — **not** Instruments. 13.6 notes
      for the re-run must record network conditions and roughly how
      much of the library was already local, so a “quiet” trace is not
      mistaken for a free pass. This Cap restores **executability** of
      13.6; it does not claim 13.6 PASS.
  13. **Docs workflow.** Cap 14.1 appends this entry as **Proposed**
      (this commit): no Accepted date, no fake anchor. After the first
      **14.2** work commit, a later docs commit flips Status to
      Accepted with that work sha (`git log -1 --format=%cs`) — same
      pattern as ADR-022 / ADR-023. The **ADR-006 Status** narrow
      supersede is **not** part of that 14.2 docs commit; it lands in
      the docs commit after **14.3** work (the sha that actually
      allows network on current-item Layer 2). Cap 14.7 close-out is
      separate: Cap `[x]`, return YOU ARE HERE to Cap 13.
- Rejected alternatives (why not B):
  - Advance the Auto-play Lookahead / Waiting for Media / iCloud
    Fallback capability instead — rejected; ADR-O is Auto-play-only
    and would pull Eligibility / Presets.
  - Keep iCloud-only as a copy panel until a later performance Cap —
    rejected; contradicts kickoff MVP Scope §1–2 and leaves 13.6
    inexecutable.
  - One opportunistic Pigeon call with two completions / FlutterApi
    stream (D7=B) — rejected; freezes an unverified event channel;
    video still cannot use `requestDisplayAsset`.
  - ±1 network Display-sized preheat (D2=C) — rejected; two extra
    downloads per swipe; muddies 13.6.
  - Live motion download in this Cap (D3=B) — rejected; separate Host
    path + UX-1.
  - Wait for Limited picker completion before first All resolve —
    rejected; that is the current timing of the bug.
  - `PHPhotoLibraryChangeObserver` (even empty-only) in this Cap —
    rejected; too easy to violate ADR-023 D7; empty-only invalidate
    may be a later ADR.
  - App-level Wi-Fi-only (D1=B) or “follow system Photos cellular”
    (D1=C) — rejected; Settings is not built; C is an unverified
    PhotoKit assumption. Cancellation bounds cellular cost.
  - Run the 13.6 Instruments matrix as Cap 14’s last phase —
    rejected; phase ownership would mix two capabilities.
  - Flip ADR-006 Status in the Proposed commit — rejected; no
    implementing sha yet.
- Consequences / constraints accepted:
  - ADR-014 Decision 5 remainder, ADR-024 empty-cache rule, and
    ADR-023 D7 / D10 remain binding.
  - Architecture guards (ADR-009/010/012) stay green on every `lib/`
    touch; new user-visible copy goes through ARB.
  - Genuinely empty libraries wait ~3.5 s on loading before empty
    copy — accepted cost of not lying on Limited first launch.
  - 13.6 hitch numbers after Cap 14 will include decode of Layer 1,
    swap to Layer 2, and overlay spinner — that is the real product
    surface, not a reason to lower the bar.
  - Vocabulary: keep “Doom Scroll” inside kickoff / GLOSSARY citations
    only.

---

## ADR-026: Cap 14.4d foreground video item-loop + return-to-ended replay

- Status: Accepted (2026-08-16); Decision 3’s mid-play re-enter
  `playOnly` branch is narrowly superseded by ADR-040 Decision 9
  (2026-08-27; Cap 18.3 work `84ef30c`) when
  `trustedStartsNewNavigationActivation == true` → always
  `seekZeroAndPlay`; non-navigation technical re-entry retains
  Decision 3 (mid-play `playOnly`; at-end still seek 0). Decision 1’s
  foreground item-end loop is narrowly supplemented by ADR-040
  Decision 10 (same date/anchor): loop only when
  `trustedUserIntentWantsPlay == true`. ADR-006 D4 and non-navigation
  mid-play playhead preserve remain binding.
  <!-- Accepted date from `git log -1 --format=%cs 24dbb88` → 2026-08-16;
       narrow-supersede date from `git log -1 --format=%cs 84ef30c` →
       2026-08-27 -->
- Commit/PR anchor: 24dbb88
- Plain summary (owner reads this):
  On Manual Browse, an ordinary video on the current page loops from the
  start when it finishes. If you swipe away and come back, it restarts
  only when it had already reached the end; a mid-play return keeps the
  playhead. Under lock-screen / background plan-advance, finishing the
  plan still stops and keeps position — no plan loop. Live Photos still
  play once.
- Context / what problem forced this:
  Cap 7 / ADR-014 Decision 2 freezes Manual advance (end-of-item does
  **not** auto-advance to the next feed item) and no Repeat product
  controls in Cap 7. ADR-006 D4 freezes **background plan-advance** at
  plan end: stop, keep position, **no loop**. Cap 14.4d needs in-item
  loop for the foreground current video and replay when returning to an
  ended item, without violating D4, without using `currentTime` /
  `duration` float equality that would break ADR-023 D6 playhead
  sharing, and without turning Live (ADR-019) into a loop.
- Decision (what was chosen):
  1. **Foreground page-driven current video: in-item loop.**
     When `AVPlayerItem` ends and the item is still the foreground
     current item → seek 0 + play. This loops **within the same feed
     item**; it is **not** auto-advance to the next item and **not**
     ADR-014 Repeat product controls. ADR-014 D2 (“end-of-item does
     not auto-advance”) remains binding.
  2. **ADR-006 D4 unchanged.**
     When `isBackgroundPlanAdvance == true`, item-end →
     `stopKeepPosition` — **no** loop (including a one-item
     Browse-shaped plan). Policy evaluates **D4 before** the
     foreground loop branch.
  3. **Re-enter / become-current: seek 0 only when at-end.**
     Use the Host discrete `activeItemDidPlayToEnd` (or equivalent end
     flag). **Do not** use `currentTime` / `duration` float checks.
     Mid-play re-enter only `play()`, preserving ADR-023 D6 All↔Videos
     playhead sharing.
  4. **Live does not loop.**
     This ADR constrains the `PlaybackApi` ordinary-video path only;
     Live play-once (ADR-019) must not regress.
  5. **Policy table is a Host-testable pure unit.**
     `VideoPlaybackPolicy.actionOnItemEnd` /
     `actionOnBecomeCurrent` stay separate from Host glue; automation
     covers the decision table, not on-device AVPlayer end feel.
- Rejected alternatives (why not B):
  - Unconditional loop on every item-end (including background plan) —
    violates ADR-006 D4.
  - Seek 0 on every re-enter regardless of position — breaks ADR-023
    D6 playhead sharing.
  - Treat `currentTime` ≈ `duration` as “at end” — float-unreliable and
    duplicates the discrete end event.
  - Same loop policy for Live and ordinary video — violates ADR-019.
  - Auto-advance to the next feed item at item end — violates Manual /
    ADR-014 D2.
- Consequences / constraints accepted:
  - Cap 14.4d work commit `24dbb88`; device Kafka: in-item loop,
    return-to-ended replay, mid-play seek preserve, Live plays once.
  - `backgroundPlanAdvanceActive` defaults to false until a background
    Cap wires the real flag; that Cap **must** feed the true value or
    D4 is a no-op.
  - Dead-file `requestPreview` reload in the same work commit is an
    adjacent bugfix, **not** a product decision frozen by this ADR.
  - Does **not** supersede ADR-006 D4, ADR-014 D2 (auto-advance),
    ADR-019, or ADR-023 D6.

---

## ADR-027: Cap 14.4e leave Browse ends Consumption Session

- Status: Accepted (2026-08-17)
  <!-- Accepted date from `git log -1 --format=%cs 5658cf2` → 2026-08-17 -->
- Commit/PR anchor: 5658cf2
- Plain summary (owner reads this):
  Leaving the Browse tab for Settings, Clips, or Auto ends the current
  browse queue and starts a fresh shuffled session at the first item.
  Locking the phone or sending the app to the background does not do
  that. Switching All / Photos / Videos still starts a new session the
  same way as before.
- Context / what problem forced this:
  Cap 14.4c kept VerticalMediaFeed alive across Settings (IndexedStack
  Theme wrap) so non-head pages would not black-screen. That also kept
  the Consumption Session and feed index, so Browse→Settings→Browse
  resumed mid-queue. ADR-023 D8 only covers built-in tab switches, not
  bottom-nav leave. Cap 14.4e needs an explicit leave-Browse boundary
  without stretching D8 or treating AppLifecycle as leave.
- Decision (what was chosen):
  1. **New ADR (not a D8 reinterpretation).** Leave-Browse is parallel
     to ADR-023 D8; D8 / ADR-014 Decision 4 tab behaviour unchanged.
  2. **Strength C.** On leave: new Consumption Session + re-Shuffle +
     feed index 0; do **not** clear the process Snapshot cache.
  3. **Trigger = bottom-nav leave only.**
     `MainBrowseDestinationNotifier.select`: when
     `browse → !browse` (Settings / Clips / Auto). Order: set
     `state = next` first, then `restartSession()`, then `setIndex(0)`.
  4. **Background / lock do not reset** — they never call `select()`.
  5. **Keep 14.4c keep-alive.** IndexedStack + Theme wrap stay;
     keep-alive ≠ keep-session. Resume latch activates the new head.
  6. **`restartSession` not `invalidate`.** Invalidating
     `browseSessionProvider` would dispose the notifier and reset the
     in-notifier `roundEpoch`, so the PageView key might not remount.
     Unexpected throws after `AsyncLoading` become `AsyncError` (not a
     stuck spinner); `ref.mounted` guards both success and error writes.
- Rejected alternatives (why not B):
  - Stretch ADR-023 D8 to mean any leave — rejected; D8 text is tab-only.
  - Reset only on `browseResumed` / in `VerticalMediaFeed.build` —
    rejected; mutating session providers during build is unsafe.
  - Index-only reset or `advanceToNextRound` only — rejected; not a
    full new Session.
  - Clear Snapshot cache on leave — rejected; forces re-resolve.
  - Treat AppLifecycle pause as leave — rejected; conflicts with
    playback ownership / future Background Audio continuity.
- Consequences / constraints accepted:
  - W-14.4c “preserve non-zero index” product expectation is flipped;
    State identity keep-alive assertions remain.
  - Settings resume poster-flash Known debt dissolves (no mid-queue
    resume path). Queue-head Layer 1 spinner-only wait may be more
    visible; recorded as Known debt, not a 14.4e defect.
  - ADR-023 D6 same-asset Host playhead sharing unchanged.
  - Does **not** supersede ADR-023 D8 or ADR-014 Decision 4.

---

## ADR-028: Default Fit presentation + portrait-only

- Status: Accepted (2026-08-18)
  <!-- Accepted date from `git log -1 --format=%cs d70fddf` → 2026-08-18 -->
- Commit/PR anchor: d70fddf
- Plain summary (owner reads this):
  Browse always shows the whole picture (Fit), like opening an item in
  iOS Photos — not a cropped fill. The app stays portrait even if the
  phone’s orientation lock is off. If a later version adds Fill or
  9:16 Crop, those are extras; Fit stays the default.
- Context / what problem forced this:
  Production Browse shipped Fill (`BoxFit.cover` /
  `resizeAspectFill` / `scaleAspectFill`) with no ADR. Kickoff lists
  Fit / Fill / 9:16 Crop as a later rail. Fill hides edges; that is
  not acceptable for MVP. Measuring 13.6 on Fill then switching to Fit
  would force a second hitch campaign. Flutter’s template also allowed
  iPhone landscape; that is not a doom-scroll product.
- Decision (what was chosen):
  1. **Fit is the permanent default**, whether or not the
     “Share, Mute, Fit / Fill / 9:16 Crop…” capability ever ships.
     Default means: still `BoxFit.contain`, video
     `AVLayerVideoGravity.resizeAspect`, Live
     `UIView.ContentMode.scaleAspectFit`. Fill and 9:16 Crop, if added
     later, are **optional modes**, not co-equal defaults. Last-used
     Fill/Crop must **not** become the cold-start default unless a
     **new** ADR overturns this.
  2. **Portrait-only for MVP.** `Info.plist` (iPhone and iPad) allows
     only `UIInterfaceOrientationPortrait`. Dart also calls
     `SystemChrome.setPreferredOrientations([portraitUp])`. The system
     Portrait Orientation Lock does not change this: the app does not
     follow landscape.
  3. **Not the three-mode rail.** Overlay / LIVE / spinner stay
     viewport-positioned. No `DisplayModePreference` in 14.6c.
- Rejected alternatives (why not B):
  - Leave Fill until the three-mode Cap — rejected; 13.6 would
    measure chrome we will not ship.
  - Equal three-way default / last-selected as default — rejected;
    Fit is the product default.
  - Plist-only or Dart-only orientation — rejected; UIKit launch vs
    Flutter runtime both need the mask.
  - Copy iOS Photos rotation (landscape when lock is off) —
    rejected; WakeTok stays portrait.
- Consequences / constraints accepted:
  - Letterboxing on non-matching aspect; chrome may sit on black
    bars (accepted).
  - When the Capability Roadmap item **Share, Mute, Fit / Fill /
    9:16 Crop, 2x gesture, tap-to-pause/resume** lands, add UI for
    Fill / 9:16 Crop as optionals; **do not** change the Fit default
    without a new ADR.
  - Landscape / CarPlay would need a new ADR; not implied by this
    one.
  - Architecture tests lock the three constants and plist.

---

## ADR-029: Cap 16 cancel and dwell current-item Layer 2 fetch

- Status: Accepted (2026-08-19); Decision 7’s unchanged Instruments
  numeric hitch/hang shipping gate (and “does not mark 13.6 `[x]`”)
  is superseded for 13.6 close-out by ADR-030 (2026-08-19); Cap 16
  product cancel / dwell / single-fetch remains binding; **Decision 2
  production dwell N numeric value (initial 500 ms) is superseded by
  ADR-035 (2026-08-26)** — leave-cancel / single-prepare mechanism
  unchanged
  <!-- Accepted date from `git log -1 --format=%cs 255656d` → 2026-08-19 -->
- Commit/PR anchor: 255656d
- Plain summary (owner reads this):
  Stopping on a photo or video should not start an iCloud download
  until you have stayed there briefly. Leaving the item (including
  opening Settings) must stop that download. WakeTok still cannot
  delete files iOS already put in the Photos library; it can only
  download less and cancel sooner. The hitch pass bar does not change.
- Context / what problem forced this:
  Cap 13.6 Profile retest after Cap 14
  (`docs/acceptance/cap13-13.6-retest-notes.md`, HEAD `80ed0b9`) is
  **FAIL** at the unchanged V-hard bar. All 3/3 failed by mean hitch
  (~68.9 / 64.4 / 65.1 ms/s) **with disk headroom**. Videos filled
  the device. Replication: ~75 s Videos V1, wait only first+last
  iCloud videos to play, flick the rest on cover → **200.2 → 207.38 GB
  (~+7 GB)**. Two watched videos ≠ +7 GB. Optimize iPhone Storage was
  on; reboot reclaims; download rate beats reclaim while Browse runs.
  This is 13.6’s **second** gate-foundation defect (Cap 14 paid
  copy-panel unreadability). The six-Run matrix cannot be repeated on
  a 256 GB phone; a full device makes any App’s hitch numbers
  meaningless.
  ADR-025 Decision 4 already requires: leaving the current item
  cancels in-flight Layer 2. Implementation cancels
  `requestPlayableVideo` / `requestDisplayAsset` but **not**
  `PlaybackApiHost.prepareActive` until the **next** `load()` /
  `replaceCurrentItem` (and only when the id changes). Leave Browse
  (ADR-027) sets `isCurrent` false with **no** following `load()`, so
  prepare keeps running.
  Becoming current video starts **two** networked
  `.highQualityFormat` `requestAVAsset` calls: `requestPlayableVideo`
  (feed awaits it, discards `durationSeconds`; this is also the only
  Dart-visible iCloud-video failure path) and `prepareActive` (via
  `setPlaybackPlan` **and** `load`; the second is de-duped).
  ADR-025 Decision 2 says current-item Layer 2 uses
  `isNetworkAccessAllowed = true` with **no dwell**. PhotoKit
  `cancelImageRequest` is best-effort once a transfer has begun, so
  cancel-on-leave alone will not stop skip-downloads.
- Decision (what was chosen):
  1. **Capability identity.** Title: **Cancel and dwell current-item
     Layer 2 fetch** (Cap 16). Not Cap 15 (swipe Layer 1→2 handoff).
     Do not use “Doom Scroll” in the capability name, this ADR’s
     title, code identifiers, ARB keys, or test names.
  2. **Narrow supersede of ADR-025 Decision 2 — timing only.**
     Current-item Layer 2 still uses `isNetworkAccessAllowed = true`,
     including cellular (ADR-025 D1=A unchanged). It must **not**
     start until the item has been current for **N milliseconds**.
     **N = 500 ms is an initial value to be adjusted after on-device
     acceptance, not a derived constant.** Applies to **still and
     video** current-item Layer 2 (`requestDisplayAsset` and
     `prepareActive` / `load`). Layer 1, ±1 preheat, Overlay file-size,
     and Live **motion** stay local-only. Retry bypasses the dwell.
     Endless new-round first item uses the **same** dwell (not a
     bypass); 16.5 records whether last-item overscroll feels slow.
  3. **Leave-cancel completes ADR-025 Decision 4 (no new ADR for
     this bullet).** Leaving current (swipe, leave Browse / Settings /
     Clips / Auto, dispose) must immediately: cancel the dwell timer;
     cancel PhotoLibrary Layer 2; **and** cancel in-flight
     `prepareActive` **without comparing the next id**. Host gains
     `cancelInFlightPrepare`. Background / lock remain ADR-006
     detach+pause (out of scope).
  4. **One networked video fetch; `load` reports completion.**
     Feed must not `await requestPlayableVideo` as a download.
     `requestPlayableVideo` remains for debug probe: Host returns
     `PHAsset.duration` / type checks and must **not**
     `requestAVAsset`. **`setPlaybackPlan` records the plan only —
     it must not call `prepareActive`.** `load` is the single
     networked prepare and completes on success, mapped failure
     (same codes as today’s playable path), or cancel. Swallowing
     a nil `AVAsset` in the PhotoKit callback without completing
     `load` is forbidden (that would drop Retry).
  5. **16.3 pre-check (callers of `PlaybackApi.load`).** Production
     `lib/`: only `_loadVideo` in `feed_page_media.dart`. Debug:
     `playback_pipeline_probe.dart` (also awaits `load`; a later
     completion is **more** correct). Live Photo uses
     `clearPlaybackPool` + `requestLivePhoto`, **not** `load`.
     Tests/fakes/gateway/generated/Host are wrappers. Probe and
     fakes must follow the new completion contract.
  6. **16.3 `_layer2InFlight` (UI vs data).** Today: true before
     `loadFeedPageLayer2`; stills clear it when Layer 2 returns;
     **video keeps it true until Platform View `onSurfaceReady`**.
     Extending `load` until playable keeps the spinner up for the
     real download (today the long wait was the extra
     `requestPlayableVideo`). `onSurfaceReady` remains the attach
     clear — do not assume try/catch preserves spinner. Cancel must
     complete `load` or the spinner sticks. 16.4 must keep
     `_layer2InFlight` true during the dwell, not only during Host
     I/O.
  7. **Storage / hitch close-out.** This Cap `[x]` when cancel +
     single fetch + dwell land and device notes record: skip-heavy
     Videos growth is explainable as watched items (not a hard GB
     bar); N=500 keep/adjust; All×3 and Videos×3 hitch **measured**.
     **Does not** mark 13.6 `[x]`. Hitch bar unchanged (ADR-023 D10 /
     ADR-014): mean < 25 ms/s AND zero Severe Hang; not Conditional
     Pass; not split; not discussed in this Cap.
  8. **Roadmap.** Insert Cap 16 after Cap 14. Park Cap 13 (13.6
     blocked, 13.7 last). Cap 15 starts only after 13.7. Two open
     capabilities = same STATE deviation as ADR-025 D11.
  9. **Docs workflow.** 16.1 appends this entry as **Proposed**.
     After **16.2** work, a docs commit flips this ADR to Accepted
     (anchor = 16.2 sha; `git log -1 --format=%cs`). ADR-025
     Decision 2 Status note (timing narrow-supersede) waits for
     **16.4** dwell to land — not the 16.2 docs commit. Cap 16
     close-out returns YOU ARE HERE to Cap 13; does not run
     Instruments as this Cap’s last phase (13.6 owns the retest).
- Rejected alternatives (why not B):
  - Guess-patch hitch inside Cap 13 / start Cap 15 between 14.7 and
    13.6 — rejected; wrong class of work.
  - Cancel-only, no dwell — rejected; PhotoKit cancel is best-effort.
  - Dwell video only — rejected; All stills also start networked
    `requestDisplayAsset`; still leave-cancel is already correct.
  - Delete Photos-library cache at session end — rejected; no public
    API; kickoff forbids an app-owned persistent media cache.
  - Lower or Conditional-Pass the 13.6 bar in this Cap — rejected;
    current “feels OK” is storage-contaminated; ADR-001-class bar
    changes need a separate campaign.
  - Hard MB/GB storage gate — rejected; two fully watched 4K items
    can be multi-GB legally.
  - New FlutterApi display stream for prepare failure — rejected;
    `load` completion is enough; does not reopen ADR-025 D7.
  - Bypass dwell on Endless new-round first item — not chosen up
    front; default is the same 500 ms; observe in 16.5.
- Consequences / constraints accepted:
  - PhotoKit may still finish a transfer that had already begun.
  - Watched originals stay in the Photos library until iOS reclaims.
  - Background / lock may still download.
  - iCloud video with no Layer 1 poster: black + spinner also covers
    the 500 ms dwell (existing Known debt).
  - Cap 7.7a ~5–7 ms/s was local-only; this Cap does not promise that
    number, only that leaked concurrent downloads stop.
  - Architecture guards (ADR-009/010/012) stay green on every `lib/`
    touch. Dwell N lives in Dart, not Swift. Features do not import
    `lib/platform` or `lib/data`.
  - 13.6 hitch after this Cap includes dwell + one Layer 2 fetch;
    that is the product surface, not a reason to lower the bar.

---

## ADR-030: Retire Instruments numeric hitch/hang gates; close SwiftUI fail path

- Status: Accepted (2026-08-19)
  <!-- Accepted date from `git log -1 --format=%cs 162ed8e` → 2026-08-19 -->
- Commit/PR anchor: 162ed8e
- Plain summary (owner reads this):
  WakeTok no longer uses any Instruments hitch or hang **number** as a
  Pass/Fail shipping gate. Mean hitch and Severe Hang from Animation
  Hitches are diagnostic only. Cap 13.6 closes on everyday
  uninstrumented use: no hard freeze, no app-not-responding, no
  force-quit, no crash — not on beating 25 ms/s. A SwiftUI rewrite is
  out of the feasible set because a later Android client is still
  planned, not because any hitch number passed.
- Context / what problem forced this:
  ADR-001 set mean hitch **< 25 ms/s** AND **no Severe Hang**. ADR-014
  Decision 7 and ADR-023 D10 reused that pair as a must-pass Profile
  V-hard gate (Cap 7.7 / Cap 13.6). Frozen FAIL tables stay
  (`docs/acceptance/cap13-13.6-notes.md`,
  `docs/acceptance/cap13-13.6-retest-notes.md`).
  Cap 16 paid the product storage leak; 16.5 showed Animation Hitches
  sessions correlating with GB-class **System Data** growth and Photos
  flat. The same template on Kafka failed Photo-App-A and Video-App-B
  on the old bar. Owner daily **uninstrumented** Video-App-B on this
  iPhone 13 Pro is smooth.
  **Mean hitch is not a clean leftover metric.** Video-App-B, For You,
  ~77 s assertive scroll, Hangs threshold >500 ms, no reboot between
  Runs (Run 2 continued in the same Instruments session):

  | Run | Mean hitch | Labelled Severe Hang | Session |
  |-----|------------|----------------------|---------|
  | 1 | ≈28.2 ms/s | 2.64 s | after reboot |
  | 2 | ≈40.5 ms/s | 4.33 s | still attached; System Data already +~10 GB from Run 1 |

  Same protocol and similar duration; For You items are not
  bit-identical. Mean hitch and Hang both worsened as attach time and
  System Data grew. That is the same **session-duration** pattern as
  storage, not proof of one Instruments file format, and not a reason
  to keep mean hitch as Pass/Fail after dropping Hang.
  A one-shot uninstrumented smoothness bake-off vs Photo-App-A is
  **not** the closer: the peer app is a finished product; WakeTok is
  mid-roadmap; the snapshot would expire on the next feature; and with
  Instruments numbers retired there is no numeric backstop.
  Separately, ADR-001 left a SwiftUI re-eval trigger if production
  feed cannot clear Severe Hang; ADR-014 Decision 7 pointed Cap 7.7
  fail at that discussion. Close that trigger on planning grounds.
- Decision (what was chosen):
  1. **No Instruments numeric Pass/Fail for feed close-out.** Retire
     **both** mean hitch < 25 ms/s **and** zero Severe Hang as shipping
     gates (Cap 13.6 and any later Cap that inherited that pair). Do
     not replace them with another Instruments number (including a
     raised ms/s bar). Historical FAIL tables are not rewritten and are
     not “the product is still unfixed on that bar.”
  2. **Instruments stays a diagnostic.** Animation Hitches, Hangs, Time
     Profiler, and other templates may still be used to inspect a
     trace. No reading from those traces is a Pass/Fail closer. This
     ADR does not claim traces are fabricated or that Instruments is
     useless.
  3. **Storage clause (correlation, not file-format proof).** Attached
     Animation Hitches sessions on WakeTok, Photo-App-A, and
     Video-App-B showed GB-class **System Data** growth with Photos flat.
     Not Photos-library download by the app under test. Not unique
     proof of an Instruments file format.
  4. **Comparator roles (protocol evidence only).** Photo-App-A and
     Video-App-B show the old bar has no discriminating power under
     this protocol. They are **not** a 13.6 smoothness bake-off.
     Video-App-B labelled Hang diagnoses the **attach protocol**;
     owner everyday uninstrumented Video-App-B is smooth.
  5. **13.6 closer = everyday availability (no competitor pair).**
     Close Cap 13.6 when the owner confirms that **normal daily Manual
     Browse on Kafka, without Instruments, and without an assertive
     lab stress-scroll**, does not show: hard freeze (app ignores
     input), app-not-responding, required force-quit, or crash. Jank
     that is not those events does not fail this closer. Layer 1 miss
     / black cover is **out** (Known debt / Cap 15). No Photo-App-A vs
     WakeTok uninstrumented pair; that step is **cancelled**, not
     deferred.
     **Owner confirmation (2026-08-19):** As of today, everyday
     uninstrumented WakeTok use on Kafka has not shown hard freeze,
     app-not-responding, force-quit, or crash.
  6. **SwiftUI fail path closed (independent of §1–5).** ADR-001’s
     hang-triggered SwiftUI / all-native re-eval is **withdrawn**.
     ADR-014 Decision 7’s fail path pointing at that discussion is
     **withdrawn**. Feasible UI stack remains Flutter + Swift-native
     media. SwiftUI / all-native iOS rewrite is **out of WakeTok’s
     feasible set** because the owner still plans a later Android
     client (ADR-001 already kept Flutter for that). Android is not a
     Capability Roadmap line. Future poor traces **do not** reopen
     SwiftUI. Not because calibration “passed” the old bar (it did not).
- Rejected alternatives (why not B):
  - Keep mean hitch as a numeric gate after dropping only Severe Hang
    — rejected; Video-App-B Run 1→2 shows mean hitch moving with
    attach duration / System Data, not as an independent clean score.
  - Keep ADR-023 D10 Instruments V-hard as 13.6 must-pass — rejected;
    Photo-App-A and Video-App-B fail it; Video-App-B is smooth off-tool.
  - Lower the ms/s number and keep a hard Instruments gate — rejected;
    same protocol still grows System Data and can induce Hang.
  - Ban all Instruments use — rejected; diagnosis remains allowed.
  - Close 13.6 on an uninstrumented Photo-App-A vs WakeTok score —
    rejected; unfair (finished peer vs mid-roadmap), not durable
    (expires on the next feature), and has no numeric backstop once
    Instruments numbers are retired.
  - Use Video-App-B everyday smoothness as WakeTok’s product bar —
    rejected; different content and network; 13.6 asks only whether
    WakeTok is usable day-to-day.
  - Leave ADR-001 SwiftUI fail path armed until hang debt is “cleared”
    — rejected; out of the feasible set for Android planning.
  - Rewrite frozen 13.6 FAIL tables — rejected; evidence stays.
- Consequences / constraints accepted:
  - **ADR-001** hitch hard-gate reading and hang-triggered SwiftUI
    re-eval are superseded (Status line). First-frame PASS, Platform
    View default, Texture rejection, Flutter-for-Android option remain.
  - **ADR-014** Decision 7 fail path and later-Cap Instruments numeric
    shipping gate are superseded (Status line). Cap 7.7a Profile PASS
    and Release hang Known debt stay untouched.
  - **ADR-023** D10 13.6 must-pass Instruments V-hard is superseded for
    close-out (Status line). Do not read old FAIL as Conditional Pass
    of the old bar.
  - Cap 13.6 `[x]` uses §5 owner confirmation (2026-08-19), not an
    Instruments numeric Pass. Cap 13 `[x]` still waits for 13.7.
  - Layer 1 black cover / missing poster stays Known debt → Cap 15.
  - Competitor codes only in committed docs; local map gitignored.
  - Accepted date / anchor = the docs commit that appends this entry
    (no product-code work commit).

---

## ADR-031: Cap 15 feed Layer 1→2 handoff polish

- Status: Accepted (2026-08-20)
  <!-- Accepted date from `git log -1 --format=%cs 962b6d1` → 2026-08-20 -->
- Commit/PR anchor: 962b6d1
- Plain summary (owner reads this):
  Swiping the feed should keep a recognisable still or video cover, put
  the wait spinner with the other item chrome (bottom-right), and not
  download extra copies of the same photo. Shrinking the local preview
  size should make iCloud-optimised items show a cover more often.
  Leaving a video should not go to a black page when a cover already
  exists. This does not change the one player / one Platform View
  contract, does not let Layer 1 use the network, and does not put the
  Limited banner back on Main Browse.
- Context / what problem forced this:
  Cap 15 is the active capability after Cap 13/14/16 close. Known debt:
  still/video swipe-in flash (394); listen+build double generation
  (396); Layer 1 miss centered spinner (399) plus leave-Browse return
  (398); iCloud video no Layer 1 poster (400). 13.6 close does not mark
  these solved. Design input is not a re-run of the Instruments six-Run
  matrix (ADR-030). Evidence: docs/acceptance/cap15-15.1-notes.md
  (2026-08-20, Kafka, Debug WT15 throwaway — never committed).
- Process deviation (must be explicit):
  Cap 15 uses **diagnosis before contract freeze** (15.1 then 15.2).
  This is a deliberate deviation from 14.1/16.1. Reason: Q1 and Q3
  needed device evidence (same class of failure as 14.4c IndexedStack
  dispose, 14.6 Host typed-fetch, 13.6 Instruments pollution).
- Decision (what was chosen):
  1. **Capability identity.** Title: Feed swipe Layer 1→2 handoff
     polish and duplicate current-item Layer 2 request (Cap 15). Do
     not use “Doom Scroll” in the capability name, this ADR, code
     identifiers, ARB keys, or test names.
  2. **Q1 = A1 (from 15.1 M3).** Shrink Host `previewTargetSize`.
     Layer 1 stays `networkAccessAllowed = false` (ADR-025 D2).
     **Q1=B (Layer 1 network) is rejected** — would reopen Cap 16’s
     download path. **A2 (two-tier small-then-large on the production
     preview table) is a non-goal** — Host `previewRequests` is
     same-assetId supersede; A2 needs a contract ADR. 15.1 clean
     samples (videos n=4, stills n=3, split tables): 1080 miss /
     512 and 256 hit; not mixed → not default C. Contaminated
     `4/L0/001` (Layer 2 before M3) excluded from A1 evidence.
     **Initial production box = 512×512** (not 256): same miss-fix,
     better Fit quality; no search for a 512–1080 threshold. 15.6
     device visual QA on Fit (14.6c) is required, not miss-rate
     alone. Host change follows 14.2: unit-test pure logic; PhotoKit
     path declared un-exercised in the work commit message. Extra
     local `requestPreview` calls are **not** under ADR-029 §4
     (that rule is networked Layer 2). A1 is one local request at
     the new size, not two.
  3. **M3 order-contamination (honest limit).** The locked 15.1
     protocol (same asset both orders, or process restart between
     tiers) **was not executed**. The throwaway driver only
     alternated tier order by queue index (even: 1080→256→512;
     odd: 512→1080→256). That is **not** the locked protocol.
     A1 is adopted because every clean sample showed the same
     direction under both those index orders; cache-pollution
     artefacts usually look mixed. Residual risk: PhotoKit cache
     from an earlier tier on the same process. Do not write 15.1
     as if counterbalancing was completed.
  4. **Q2 = A.** Item-level Layer 1-miss chrome unifies to
     `_FeedCornerChrome` (debts 399+398). Library resolve loading
     stays centered. **Delay-before-show is not added:** Full M5-A
     had almost no `_loading`; Limited miss windows were seconds,
     not <50 ms flashes. UX-1 (402) is a 15.8 incidental check,
     not a Cap 15 goal.
  5. **Q3 = A.** On leave-current, keep poster / last still in the
     **leaving page’s Dart widget state**. Do **not** change the
     ADR-006 1+1 player + single Platform View contract (Background
     Audio / lock screen still pending). Debt 393 (swipe-away residue
     on the shared surface) is **related but not equivalent** —
     masking by Layer 1 blur + dwell is not closure. 15.8 observes;
     close 393 only if confirmed gone. Do not invent a Layer 1
     network path to unmask 393.
  6. **Q4.** Pull 398 (same `_loading` as 399). Do not pull 395
     (restart-from-0 after the slot is taken — already accepted
     MVP). 402 not in scope; 15.8 incidental only.
  7. **Q5 = B.** Per-debt observable before/after (15.1 notes vs
     15.8) **and** ADR-030 §5 owner daily-use. App logs / owner
     observation, not Instruments numeric gates. ADR-030 retired
     hitch/hang **hard bars**, not all measurement.
  8. **15.4 (396) is a real fix.** Verify-only required M1=1 **and**
     M2=1. 15.1: one networked `layer2_load_start` per
     become-current (M1); **`preview_supersede` on every Videos
     page_changed in m1m2 (M2 ≠ 1).** Dual `requestPreview` is
     also structural (current + ±1 preheat, same-id Host table),
     not only a race.
  9. **M1/M2 Debug methodology limit.** Counts were collected on
     **Debug**, not Profile. 16.5 locked Profile for timed runs;
     Debug JIT/asserts are not timing-grade. Direction (real fix)
     is adopted by **risk asymmetry**: slower Debug is more likely
     to widen than hide the race; a slightly eager 15.4 is safer
     than a false verify-only. If Profile device behaviour after
     15.4 **materially** contradicts this (e.g. M2 already 1 on
     Profile with no supersede), that is a **new finding**, not a
     silent rewrite of 15.1. Do not treat Debug M1/M2 as equal to
     Profile timing evidence.
  10. **Three-axis no-Cap-16-regression invariant** (same gate
      language as ADR-030: observable failure + qualitative
      judgement; no isolated numeric hard bars):
      (1) **Networked Layer 2** — must not add fetches that cannot
      be explained by items that became current and completed
      dwell; duplicate in-flight downloads fail.
      (2) **Device storage** — 16.5 Videos +0.18 GB / All +0.02 GB
      are comparison baselines, not caps. Growth must stay
      explainable as watched items (16.5 protocol, no Instruments).
      15.1 Full Videos M7: Photos 10.18→10.18 GB; total −0.92 GB
      in System Data — Photos-flat, not a leak.
      (3) **Peak memory** — no unbounded or material peak growth
      beyond measurement noise; jetsam / force-quit / sustained
      climb fail. If gapless causes a discernible rise, 15.5 must
      offset (e.g. viewport-sized decode) or that implementation
      does not pass.
  11. **Peak-memory baseline is a hard gate before 15.5 starts,
      not an optional 15.1 leftover.** 15.2 may freeze without
      it. **No 15.5 work commit** until Kafka (or the floor
      device) records a before peak (Xcode Memory gauge,
      indicative) on the **current** still L1→L2 path (`Image.file`
      + path `ValueKey`, no gapless yet), plus Layer 2 file bytes
      and decode pixel size for the same waited-L2 stills. That
      session’s notes are the 15.8 memory “before” column. Missing
      this baseline makes the memory invariant untestable.
  12. **15.5 approach.** Waited Full stills: Fit-interior flash
      3/3. Enable gapless by removing the path `ValueKey` that
      currently destroys `_ImageState`; keep 14.4d `_postedBroken`
      across **asset** change. Sized decode if the pre-15.5
      memory/decode numbers warrant it.
  13. **Acceptance (15.8).** Owner daily-use (ADR-030 §5) +
      per-debt before/after table (incl. 393 and UX-1 verdicts) +
      storage on 16.5 protocol (explainable-as-watched) + peak
      memory vs the **pre-15.5** baseline. All-tab M7 and Limited
      Endless first-item `_loading` may be filled at 15.8; they
      do not block 15.2.
  14. **Docs timing.** 15.2 appends this entry as **Proposed**.
      After **15.3** work, a docs commit flips Accepted (anchor =
      15.3 sha; `git log -1 --format=%cs`). 15.9 close-out does
      **not** flip Accepted.
  15. **Non-goals.** Remount Limited Access product chrome on
      Main Browse (`01a7611` / `a2b54f9`). Layer 1 network.
      Two-tier preview Host contract (A2). Session playhead /
      mid-play resume across 1+1 slot occupancy (395). Changing
      dwell N. Instruments hitch/hang numeric Pass.
- Rejected alternatives (why not B):
  - Freeze ADR before 15.1 — rejected; Q1/Q3 need device data.
  - Q1=B Layer 1 network — rejected; reopens Cap 16.
  - Q1=C keep 1080 — rejected; 15.1 clean samples show usable
    local hits at 512/256.
  - A2 two-tier production previews — rejected; same-id supersede.
  - Q3=B change 1+1 / Platform View — rejected; Background Audio
    contract not yet specified.
  - 15.4 verify-only — rejected; M2 ≠ 1.
  - Delay-before-show spinner — rejected by M5 distribution.
  - Treat Debug M1/M2 as Profile-grade without a caveat —
    rejected; must disclose.
  - Treat “393 not visible” as closed — rejected; masked.
- Consequences:
  15.3 is the first Cap 15 work commit. 15.6 Host 512 box + Fit
  visual QA. 15.5 blocked on memory before-measure. Probe source
  stays out of git; 15.1 notes land in the 15.2 docs commit.

---

## ADR-032: Cap 15.11 shared Platform View handoff — ready-for-display trust (not attach-ack)

- Status: Accepted (2026-08-23); architecture-guard clarification
  (2026-08-27): ADR-032's entering-side `_PvTransitionCover` is the
  sole `BoxFit.cover` exception to ADR-028's default-Fit scan. It renders
  an opaque transition mask, not presented feed media, and must fill the
  viewport without letterbox gaps. Feed still/video/Live defaults remain
  Fit; no product display-mode decision changed.
  <!-- Accepted date from `git log -1 --format=%cs 9d546f2` → 2026-08-23 -->
- Commit/PR anchor: 9d546f2
- Plain summary (owner reads this):
  When you swipe between two local videos, WakeTok now keeps a poster cover
  and mutes sound until the **new** video’s picture is actually ready to
  show — not merely when the player is wired to the screen. That stops the
  old video’s picture and sound from leaking during the handoff.
- Context / what problem forced this:
  Cap 15 debt **393** (shared 1+1 AVPlayer + single Platform View — ADR-006):
  local→local video handoff showed two distinct failure modes on device
  (Kafka 2026-08-22 after 15.10; design `cap15-debt393-explore-scope.md`):
  1. **Peek:** entering half-screen went blur poster → **black gap** (no
     content) while the neighbour page had poster only (no UiKitView until
     `isCurrent`).
  2. **Settle:** after full settle, **previous** item’s picture **and sound**
     continued at the same progress for ~0.5 s, then snapped to the target.
  Cap 15.7 closed leave-side poster loss; Cap 15.10 closed revisit blur-first.
  393 required a **handoff guard**, not more Layer 1 blur or dwell masking
  (ADR-031 Q3 related-not-equivalent).
  **15.11a** shipped `PvTransitionGuard`: entering-side opaque poster cover +
  `setTransitionAudioSuppressed` + Host `onPlaybackSurfaceAttached`
  (attach-ack). Device still failed: unwrap on attach-ack removed cover
  **before** pixels switched; audio could unmute while the layer still showed
  the previous item.
  **Device evidence (Kafka Profile, Cap 15.11 diagnosis — TEMP logs removed
  before work commit `9d546f2`):**
  - On every qualifying attach, Host logged `ready-display-edge` with
    **`layerReady=false`** at attach time (`reason=attach-sample`;
    `to=false`). KVO later raised `layerReady=true` (`reason=kvo`;
    `to=true`) tens–hundreds of ms later.
  - Therefore **`onPlaybackSurfaceAttached` correlates with
    `playerLayer.player` binding, not with a displayable frame** for the new
    id. Unwrapping guard or poster-hold on attach alone reproduces 393
    settle wrong-A/V or peek black.
  - **`notifyDisplaySurfaceReady` / Dart `onSurfaceReady`** were already
    ruled insufficient in explore scope (surface mounted ≠ pixels/audio for
    new id; Cap 15.10 / explore doc §Feasibility).
  **15.11b follow-ons** (same work commit, not a separate capability phase)
  were required before acceptance:
  - **Settle-on-target split:** visual cover may end on true feed-index
    commit; transition mute must **not** end until first-frame ready —
    otherwise unmute + shared surface still shows A.
  - **Poster-hold:** video UiKitView deferred while guard covering or
    `_layer2InFlight`; Opacity hides surface until ready-for-display on the
    **current** page (parallel to guard cover on the entering page).
  - **Stale feed-index re-arm:** scroll listener must read **live**
    `mainBrowseFeedIndexProvider`, not build-captured index; after settle,
    stale `ScrollUpdate` re-armed guard toward the settled page →
    `guard-disarm reason=timeout` (~2 s) even when L2 finished in ~70 ms.
  - **`_layer2InFlight` generation ownership:** Tab / leave paths must
    clear inFlight without sticking blur + corner spinner.
  Kafka + i17 Profile PASS (`cap15-15.11-notes.md`); debt 393 closed.
- Decision (what was chosen):
  1. **Product trust point = Host first displayable frame, not attach.**
     Add `PlaybackFlutterApi.onPlaybackSurfaceReadyForDisplay` with the same
     identity triple as attach-ack: `(assetIdentifier, feedIndex,
     clearEpoch)` where `clearEpoch` is Host pool invalidation generation
     (`getPlaybackPoolEpoch` / ADR-006 `clearEpoch`). Emit when
     `AVPlayerLayer.isReadyForDisplay` becomes true for the bound player
     on the shared Platform View (`PlaybackSurfaceView` KVO). **Keep**
     `onPlaybackSurfaceAttached` on the Pigeon surface for diagnostics /
     future callers; **do not** use attach-ack as guard unwrap or
     poster-hold clear.
  2. **Guard unwrap + audio release** listen only to
     `surfaceReadyForDisplayEvents`. Match triple against arm snapshot
     (`targetAssetId`, `targetFeedIndex`, `armPoolEpoch`). On match:
     - If cover still armed → full `disarm(resumePlay: true)`.
     - If cover already released by settle-on-target →
       `releaseTransitionAudio(resumePlay: true)` only.
     Do **not** re-check Dart `FeedMediaRequestGate.displayGeneration` on
     ready-for-display (settle can bump generation while pool epoch still
     valid — same race class that made attach-ack unwrap untrustworthy).
  3. **Settle-on-target (guard deadlock / linger fix).** On true
     `mainBrowseFeedIndexProvider` commit to `targetFeedIndex`:
     `releaseCovering` only — clears `_PvTransitionCover` and
     `canMountVideo` defer; **preserves** `_transitionAudioHeld` and
     audio-match triple for the ready-for-display listener. Forbidden:
     ending transition mute on settle; using scroll epsilon alone to drop
     cover when index equals target (mid-peek false settle).
  4. **Poster-hold uses the same ready-for-display stream** on the
     **current** page: `_holdPosterUntilFirstFrame` cleared on matching
     triple (`reason=ready-for-display`); `releaseTransitionAudio` for
     poster-hold path uses the same event. Video slot: `canMountVideo =
     isCurrent && !guard.isCovering && !_layer2InFlight`. Opacity 0 until
     hold clears — avoids mounting empty UiKitView during peek black.
  5. **Transition mute is Host-scoped and non-persistent.**
     `PlaybackApi.setTransitionAudioSuppressed(true)` mutes active+warming
     players without changing user mute preference; cleared only by Dart
     after ready-for-display (or timeout / disarm failure paths). Timeout
     remains 2 s (degraded unwrap; device matrix required 0 timeout on
     acceptance build).
  6. **Scope / non-goals.** ADR-006 1+1 pool + single Platform View
     unchanged (no Q3=B). Debt **400** (no Layer 1 poster) unchanged.
     Cap **15.12** (local first-visit skip L1) is out of scope. TEMP
     `[WT15.11]` device logs were **not** shipped in `9d546f2`.
- Rejected alternatives (why not B):
  - **Unwrap on attach-ack only (15.11a first ship)** — rejected by
    device evidence: attach always observed `layerReady=false`; unwrap
    early exposes previous A/V on shared surface.
  - **Unwrap on `notifyDisplaySurfaceReady` / Dart surface-ready alone**
    — rejected (explore + 15.10): does not prove layer pixels for new id.
  - **Fixed delay unwrap** — rejected: cannot prove content switch; fails
    audio-leak acceptance; varies by local vs iCloud.
  - **End mute on settle-on-target** — rejected: reproduces 393 settle
    audio leak when layer still shows A.
  - **Dual player / Q3=B** — not chosen; owner re-board only if this track
    failed (explore doc §Rejected).
  - **Re-check displayGeneration on ready-for-display** — rejected:
    settle-on-target intentionally bumps gate before first frame; caused
    stuck cover + timeout in diagnosis.
- Consequences / constraints accepted:
  - Future handoff features must treat **`onPlaybackSurfaceReadyForDisplay`
    as the visibility contract** for unmasking user-visible video pixels on
    the shared Platform View. Attach-ack is wiring notification only.
  - First-frame latency includes PhotoKit prepare + layer KVO; cover + mute
    may persist until `isReadyForDisplay` (acceptable for 393 closure).
  - Guard arm must use **live feed index** after async epoch read; widget
    tests must keep `debugDispatchPvScrollArm` / `Settled` hooks (formal
    test surface, not TEMP diag).
  - ADR-031 Q3 (leave-side poster retention) preserved; entering-side
    cover is additive.
  - Widget tests W-15.11a–j + platform surface tests are the regression
    harness; device matrix in `cap15-15.11-notes.md` is acceptance gate.

---

## ADR-033: Cap 15.15 — resolveSource omits availabilities; on-demand probe

- Status: Accepted (2026-08-24)
  <!-- git log -1 --format=%cs b8071a1 → 2026-08-24 -->
- Commit/PR anchor: b8071a1
- Plain summary (owner reads this):
  Listing a large Photos library no longer asks “is every item on this
  phone?” up front. WakeTok only asks that for the item you are looking
  at when it needs the answer — so All/Photos/Videos opens promptly on
  big libraries.
- Context / what problem forced this:
  Cap 15.12 used list-time `AssetAvailability` so device-local items
  could skip Layer 1 on first visit. The first Host path filled
  `ResolvedSourceDto.assetAvailabilities` for every id during
  `resolveSource` (per-id `PHAssetResource` + KVC `locallyAvailable`).
  On Kafka’s large library that made "Loading library…" hang before the
  feed appeared. Smaller / mostly-local libraries hid the bug.
- Decision (what was chosen):
  1. **`resolveSource` returns `assetAvailabilities: []` always**
     (field kept for wire compatibility; not parallel to ids).
  2. **New `getAssetAvailabilities(ids)`** — on-demand probe; unknown
     → unavailable. Domain port + gateway; Host off main thread.
  3. **Feed become-current:** after Session L2-ready miss, if snapshot
     has no availability, probe **current id only** → 15.12 path or
     FULL_L1.
  4. **Probe failure / leave → conservative FULL_L1** (not deviceLocal).
  5. **Tests** may inject at resolve via fake; production Host omits.
- Rejected alternatives (why not B):
  - **Full-library availability at resolve** — rejected: Kafka stall.
  - **Roll back 15.12 skip-L1** — rejected: stall was the scan.
  - **Batch-fill whole library after first frame** — rejected: same cost.
  - **Session-level availability cache** — deferred, non-blocking.
- Consequences / constraints accepted:
  - Callers must **not** assume resolve fills availabilities.
  - deviceLocal fast path depends on become-current probe (or test inject).
  - KVC remains undocumented; must not silently expand (STATE Known debt).
  - 15.14c / L2-ready temp eviction Known debt are separate.


## ADR-034: Cap 17 Layer 1→2 wait chrome, debt 400 presentation, and iCloud observability contract

- Status: Accepted (2026-08-25); Decision 2 **F1 (+D)** Live-prepare
  suppress-below-T has a **narrow handoff continuity exception** in
  **ADR-037** (Accepted 2026-08-26, anchor `a42abcd`) — when Layer-2
  wait chrome already painted this inFlight, motion prepare skips F1
  &lt;T; short / unlatched F1 evidence and intent are unchanged.
  **17.4 center coverless `Layer2Waiting` copy** superseded by **ADR-039**
  (Accepted 2026-08-27, anchor `f1ffadf`); debt 400 residual black and
  corner chrome contract here remain binding.
- Commit/PR anchor: `65ea272` (Cap 17.3 work; first Cap 17 implementing commit)
- Plain summary (owner reads this):
  Waiting in Main Browse should match how long the wait usually is: a quick
  local revisit should not flash a spinner for nothing, but a long iCloud
  load should still show clear feedback (and progress when Host already
  reports it). Items that never get a local Layer 1 cover may stay black;
  Cap 17 improves how that wait looks, and does not switch Layer 1 to a
  mode that helps a few misses by making every cover worse. Speeding up
  iCloud must stay explainable and measurable, must not claim to match
  Photo-App-A, and must not weaken Cap 16 cancel / dwell / single-download
  rules.
  Cap 17.3 locks a4 suppress-below-T at T=150 ms and promotes three
  paint-layer rules that the path-class helper alone does not cover:
  still a2 suppress-below-T (G), a4 loading miss-chrome bypass (B), and
  Live-prepare suppress-below-T on all path-classes (F1, with D folded).
  An optional off-current paint hard-gate (E) remains in code without
  empirical proof that off-current chrome paint occurs. Live inFlight
  band-follow (C/F2) remains in code as wiring consistency, not as a
  Decision 2 promotion. An a4 minimum spinner visibility hold (min-show)
  was designed then removed after device evidence showed it never entered
  after-band on the sessions that mattered and did not address the flash
  users actually saw.
- Context / what problem forced this:
  Cap 17 follows Cap 15/16 with known Main Browse debt: Host-temp vs
  L2-ready revisit chrome; debt **400** (iCloud / optimized-storage video
  without Layer 1 poster); debt **403**-class iCloud load feel + dead-end
  wait UX. Process matches Cap 15: **diagnosis before contract** (17.1 then
  17.2). Evidence: `docs/acceptance/cap17-17.1-notes.md` (2026-08-25,
  Kafka, Profile WT17 throwaway — **never committed**). Track A path-class
  durations; Track B Full+Limited Host load finish / leave-cancel / progress;
  Track C Full/Limited × opportunistic / `.fastFormat` @512 sync probe.
  Owner decisions for this freeze: **D1–D5 = A**, with a4 band-threshold
  wording, i17 spot-check, and a1 regression-lock test as below.
  Cap **17.3** device contrast (Kafka / i17; A-only vs B–G ON Profile tees,
  never committed) locked the paint-layer extensions below.
- Process note:
  17.2 appended this entry as **Proposed**. Cap **17.3** work commit
  `65ea272` is the Accepted anchor (Accepted date from
  `git log -1 --format=%cs 65ea272`). Cap close-out does **not** re-flip
  Accepted.
- Decision (what was chosen):
  1. **Capability identity.** Title: Main Browse Layer 1→2 chrome and
     iCloud availability hardening (Cap 17). Do not use “Doom Scroll” in
     the capability name, this ADR, code identifiers, ARB keys, or test
     names. Cap **18** / debt **402** out of scope.
  2. **D1 = A — Wait chrome by path-class / duration band (not a single
     in-flight bool).** Production must not treat `_layer2InFlight` alone
     as “always show corner chrome.” Chrome kind is selected from a
     path-class × expected-duration policy (exact type names are an
     implementation detail of 17.3):
     - **a1** (Layer 1 miss): keep immediate corner chrome; **no**
       delay-before-show on this path (ADR-031 Q2 preserved).
     - **a2** (wait-to-playable, long tail): corner chrome; **may** show
       Host progress when progress samples exist (Track B: progress was
       observed). No per-item ETA promise.
     - **a3** (L2-ready hit): no wait chrome.
     - **a4** (`l2ready_evict` / Host-temp revisit): **not** a homogeneous
       “always short / always suppress” class. 17.1 Full a4 n=186 bucket
       counts were **65 / 108 / 13 / 0 / 0 / 0** for
       [&lt;50, 50–200, 200–500, 0.5–2s, 2–10s, &gt;10s] ms — about **7%**
       sit in **200–500 ms**. **17.3 locks band threshold T = 150 ms**
       from that distribution and device notes (`kDefaultA4SuppressBelow`).
       Policy: while on the a4 path and still in flight, **suppress**
       chrome for elapsed &lt; T; if still in flight after T, show normal
       corner chrome. Do **not** read this ADR as “all a4 are &lt;200 ms”
       or “suppress every a4 for the whole request.” A single fixed
       suppress-all-a4 rule is rejected because it recreates the
       empty-window failure mode ADR-031 Q2 warned about (wait with
       neither content nor chrome), now inside the a4 tail.
     - **a5**: rare / unobserved under Kafka Host-temp pressure (17.1);
       do not design product defaults around ideal a5; if observed, fold
       into the revisit / a4-style band policy.
     - **a6**: short-path band treatment consistent with the same policy
       helper (no separate product story).
     - **17.3 promoted paint-layer rules (Decision 2 extension).** These
       are product rules for Cap 17.3, enforced in Main Browse presentation
       (not a second competing path-class enum):
       - **G — still a2 suppress-below-T:** For `FeedPageMediaKind.still`
         on path a2, do not paint Layer-2 wait corner chrome while
         `elapsedInFlight < T`. After T, paint normally. **Video a2 stays
         immediate** (iCloud / long-wait feedback). G suppresses only the
         brief band; **≥T still a2 chrome remains by design** and must not
         be described as “G eliminates all revisit spinners.”
       - **B — a4 loading miss bypass:** While path is a4 and the page is
         in the ADR-031-style `_loading` miss chrome branch, do **not**
         paint immediate miss gold (a4 eviction remount is not a true
         first-visit L1 miss). Session L2-ready token may tag a4 early so
         this gate applies before cover-on-disk lookup completes.
       - **F1 (+D) — Live prepare suppress-below-T (all path-classes):**
         While `_livePreparing`, suppress Live corner gold until prepare
         wall time ≥ T; short prepares never paint. D (a3/a4-only prepare
         suppress) is **folded into F1** — one rule, all paths.
     - **17.3 retained, not Decision-2-promoted:**
       - **E — off-current hard gate:** If `!isCurrent`, do not paint item /
         Layer-2 / Live / loading wait corner chrome. **Evidence status:**
         A-only contrast (including a rapid multi-page protocol aimed at
         off-current paint) observed **zero** `cur=false` spinner paints on
         Kafka and i17. E is retained as a **conservative product defense**,
         **not** as a data-driven finding that it blocks a demonstrated
         off-current chrome paint. Do not cite E as “validated effective.”
         Distinct from Decision 2’s existing a4 policy clause
         (`!isCurrent` → none on **a4 only** via `resolveWaitChrome`).
       - **C / F2 — Live inFlight follows wait band (not promoted):**
         Live inFlight must not OR-bypass the wait-chrome policy (C on a4;
         F2 extends band-follow for Live inFlight more broadly). Kept for
         **wiring consistency** with path-class chrome (otherwise a4/F1
         policy is bypassed while Layer-2 is in flight). **Not** listed
         among the promoted G/B/F1 rules; weaker direct causal evidence
         than F1 prepare suppress. Do not roll back C/F2 solely to shrink
         code — rollback would re-open Live inFlight bypass against F1.
     - **17.3 removed — a4 min-show (B1):** Do **not** keep spinner
       visible after Layer-2 inFlight clears for a minimum wall time.
       Content may mount as soon as L2 succeeds; leave-current already
       cancelled any hold. **Timeline (decision trace, required):**
       Min-show was designed to improve a4 **after-band visibility** (hold
       chrome ~1s without delaying L2 content). Device diagnosis later
       showed the flash users actually noticed was **short current-page
       a2 settle / Live prepare** (G / F1), not a4 after-band. Independent
       sessions under the Cap 17.3 probe:
       - **Kafka** (same device as 17.1 Full a4 n=186): P2+P4 combined
         a4 `complete` **n=66**, after-band (`elapsed ≥ T`) **0%**,
         min-show `holdMs>0` **0%**. Sample size ≈ **one-third** of 17.1
         Full; supports removal but is **not** an equal-n reproduction
         of the 17.1 ~7% (13/186) 200–500 ms tail.
       - **i17** (device-skewed quieter library): B–G ON session a4
         `complete` **n≈183**, after-band **0%**, `holdMs>0` **0%**.
         Per Known debt, low a4 tail on i17 is **expected**; this row is
         **not** an independent falsification of Kafka’s 17.1 tail and
         must not be merged with Kafka into a vague “two large devices
         both proved zero.”
       Verdict: min-show did not address the symptomatic flash path and
       did not trigger in these sessions → **remove as unused /
       mis-aimed design**, with this paragraph retained as the audit
       trail.
  3. **D2 = A — Debt 400 presentation scheme.** Cap 17 **accepts residual
     black** when no local Layer 1 derivative exists (Limited + local-only
     Layer 1 cannot invent pixels). **17.4** improves wait **visibility**
     (corner chrome / shared progress channel when networked Layer 2 is
     already in flight / optional short copy via l10n — exact UI in 17.4).
     **Do not** ship production Layer 1 `deliveryMode = .fastFormat` in
     Cap 17: Track C Limited `.fastFormat` was **26/26 miss** (regression);
     Full `.fastFormat` cleared miss ids **and** globally downgraded
     already-good ~512 hits to ~40–120. Not a miss-only free lunch; not a
     Limited rescue. **Do not** enable Layer 1 network. Miss-3 is
     heterogeneous (2× never-hit + 1× post-L2-play reclaim **candidate,
     not proven**); UI must not assume one black-screen cause. Closing the
     Known-debt **400** row is **not** required for 17.2/17.4 pass.
  4. **D3 = A — iCloud optimization acceptance (17.5).** Bar =
     **explainable wait + observable improvement**; **no** promise to match
     Photo-App-A / iOS Photos. **Primary before/after columns:** load
     finished **ok**, **deduped cancel** (same id + leave window; leave may
     emit a second late cancel finish — 17.1 Full raw 91 ≈ 74 leave + 17
     orphan), **fail = 0**, **progress present**. Full auth is the
     15.11-homologous primary column; Limited may supplement. **Latency
     proxy:** Track A **a2** wait-to-playable distribution (Full evidence:
     p50 360 ms / p90 3796 ms / max 18598 ms) — mixes local/iCloud and
     still/video; **not** an iCloud-only distribution; still the only
     latency evidence from 17.1. **Forbidden KPIs:** undeduped raw
     `load-finished cancel` totals; `cancel stillCurrent=true` as a
     supersede score (≡ leave Host snapshot; withdrawn in 17.1). Optional
     later: dedicated Host iCloud-only timing — not required to freeze
     17.2. Method language matches ADR-030: observable failure +
     qualitative judgement; no Instruments hitch/hang numeric shipping
     gate. Throwaway probes **never committed**.
  5. **D4 = A — Cap 16 storage / fetch invariants (hard, restated).**
     Cap 17 implementations (especially 17.5) **must not** weaken:
     (1) current-item networked Layer 2 starts only after dwell N
     (ADR-029; N adjustable only with explicit acceptance, not silently
     for speed); (2) leave-current cancels dwell, PhotoLibrary Layer 2,
     and in-flight `prepareActive` without requiring a next-id compare;
     (3) one networked video prepare path via `load` completion;
     (4) storage growth remains explainable as watched items (16.5
     protocol language; no hard GB bar). Adding concurrent networked
     Layer 2 fetches that cannot be explained by become-current + dwell
     **fails** this Cap. “Faster iCloud” is not grounds to drop
     leave-cancel.
  6. **D5 = A — Track C sync vs async follow-up.** 17.1 Track C used
     `isSynchronous = true` (≠ production async `requestPreview` / Cap 15.6
     first-paint morphology). An optional `isSynchronous = false` re-probe
     does **not** block 17.2; run only if 17.4/17.6 disputes first-paint
     morphology. Not a standing Cap 17 gate.
  7. **Phase mapping.**
     - **17.3:** path-class chrome unification with a4 T=150 ms; promoted
       G / B / F1(+D); retain E (disclaimer) and C/F2 (non-promoted
       wiring); remove a4 min-show per Decision 2 timeline; tear Cap 17.3
       diagnostic chrome tee before work commit. Local peek residue in
       STATE/ADR phase language is satisfied by G (+ a4 band), not by
       claiming E was empirically required. **Landed** `65ea272`.
     - **17.4:** debt 400 wait presentation per Decision 3.
     - **17.5:** iCloud fetch-path work under Decisions 4–5.
     - **17.6:** device acceptance + residual triage (Main Browse
       foundation only).
     - **17.7:** Cap close-out.
  8. **Automated tests (contract for `lib/` work commits).** Every Cap 17
     Coding Task that touches `lib/` keeps `test/architecture/` green
     (ADR-009 / ADR-012). Cap 17.3 landed (names flexible; see
     `cap17_3_wait_chrome_*_test.dart`):
     - Pure Dart unit: path-class × duration-band → chrome kind, including
       a4 suppress-below-T / show-after-T with injectable T.
       **No** a4 min-show hold helpers (removed).
     - Pure Dart unit: cancel **id+window dedupe** helper used for 17.5
       metrics (leave → double finish).
     - Thin widget tests: a4 short band suppresses spinner; past T shows
       chrome while still in flight; still a2 (G) suppresses below T;
       **video a2 remains immediate regardless of elapsed time — G
       suppression is still-only, not a general a2 rule (regression
       lock)**; a4 `_loading` does not show miss gold (B); L2-ready hit
       has no wait chrome; a1 miss chrome remains immediate (ADR-031 Q2
       regression lock); L2 success clears inFlight without min-show hold.
     - Host/PhotoKit paths: pure-logic unit tests where extracted; declare
       un-exercised PhotoKit in the work-commit message when applicable
       (same discipline as Cap 14/15 Host changes).
     - **Non-tests:** committed WT17 sources; Instruments numeric
       assertions; spinner goldens; CI that requires reproducing lasting
       debt-400 black.
  9. **Manual / device notes (minimum, not a Cap 15.8 matrix at 17.2).**
     - **17.2:** contract review only; no device script.
     - **17.3 / 17.4:** light device notes on **Kafka** (short revisit
       flash; no-L1 wait readability) **and a quick i17 pass** confirming
       that a Kafka-chosen a4 **T** does not introduce new flash on an
       i17-scale, mostly-local library (Host-temp debt is device-skewed:
       clear on Kafka, faint/acceptable on i17 — STATE Known debt). Not a
       full formal protocol. Cap 17.3 contrast sessions (A-only / B–G ON)
       informed Decision 2 extensions; probes never committed.
     - **17.5:** before/after table per Decision 4; reuse 17.1 Host tee
       discipline (`print`+`NSLog` if needed); probes never committed.
     - **17.6:** ADR-030 §5 owner daily-use + residual triage.
  10. **Non-goals.** Layer 1 network; Full vs Limited **production**
      auth fork; treating Debug/Profile probe chrome as Release copy;
      closing Known-debt **400** or **403** from diagnosis/contract alone;
      Cap 18 gestures; matching Photo-App-A load speed; Instruments
      hitch/hang Pass bars; silent dwell-N or leave-cancel weakening.
- Rejected alternatives (why not B):
  - D1=B universal delay-before-show (including a1) — rejected; reopens
    ADR-031 Q2 failure mode on L1 miss.
  - D1=C defer all duration bands — rejected; 17.1 shows a4 vs a2 need
    distinct policy now.
  - Homogeneous “suppress all a4” without T / without show-after-T —
    rejected; ignores Full a4 **13/186** in 200–500 ms and empty-window
    risk.
  - a4 min-show (B1) as the Cap 17.3 fix for settle / revisit corner
    flash — rejected after Kafka/i17 probe sessions: after-band hold did
    not fire on the measured completes, and the visible flash mapped to
    short still a2 / Live prepare (G / F1), not a4 after-band.
  - Promoting E to a Decision-2 “validated” rule from B–G ON-only
    sessions — rejected; A-only + rapid multi-page protocol still saw
    zero off-current spinner paints. Retention is conservative only.
  - Rolling back C/F2 while keeping F1 — rejected; re-opens Live
    inFlight OR-bypass of wait policy on a4 / Live paths.
  - Treating i17 large-n zero after-band as equal-weight disproof of
    17.1 Kafka a4 tail — rejected; debt is device-skewed; same-device
    Kafka n=66 is the comparable (smaller-n) column.
  - D2=B miss-only second preview request / D2=C production `.fastFormat`
    — rejected for Cap 17; Track C + Host same-id supersede cost; Limited
    regression; Full global quality downgrade.
  - D3=C qualitative-only with no before/after table — rejected; 17.5
    needs observable columns; 17.1 already defined them.
  - D3 using raw cancel or `stillCurrent=true` as KPI — rejected; 17.1
    withdrew / corrected.
  - D3 using a2 p90 as a hard pass/fail threshold for 17.5 — rejected;
    a2 mixes local/iCloud and still/video, producing false PASS (fast
    local sessions hide slow iCloud) or false FAIL (one heavy iCloud
    session skews the whole distribution).
  - D4=B cite ADR-029 only — rejected; 17.5 readers need the hard edges
    inlined.
  - D5=B mandatory async Track C before 17.4 — rejected; non-blocking
    follow-up per 17.1.
- Consequences:
  Cap 17.3 work commit `65ea272` implements Decision 2 extensions
  (G/B/F1), keeps E and C/F2 with the disclaimers above, removes
  min-show and Cap 17.3 throwaway chrome tee / contrast dart-define
  scaffolding, and lands unit/widget tests accordingly. Docs commit
  after owner acceptance flips this ADR to Accepted (this entry).
  STATE Known debt Host-temp revisit chrome is closed for the &lt;T flash
  path; ≥T wait chrome remains by design. Debt **400** / **403** stay
  open for 17.4 / 17.5.

---

## ADR-035: Cap 17.5 production Layer-2 dwell N = 300 ms

- Status: Accepted (2026-08-26)
  <!-- Accepted date from `git log -1 --format=%cs 15edc91` → 2026-08-26 -->
- Commit/PR anchor: 15edc91
- Plain summary (owner reads this):
  Production current-item Layer 2 dwell is **300 ms** (was the Cap 16
  initial 500 ms). Leave-cancel and the single networked prepare path
  are unchanged. The change only moves when that path may start.
- Context / what problem forced this:
  ADR-029 Decision 2 set **N = 500 ms as an initial value to be
  adjusted after on-device acceptance**, not a derived constant. Cap
  17.5 on-device work (Kafka Profile; notes
  `docs/acceptance/cap17-17.5-notes.md`) chose a more aggressive N for
  earlier content availability when the owner intends to watch, while
  keeping a guard rail (200 ms rejected from hand-speed S1: ~95% would
  cross dwell). Cancel cleanliness was checked with a dual-column
  leave_after_prepare frame (finishOk / silentDeliver); system-level
  cost (battery / thermal / throttling) was **not** measured.
- Decision (what was chosen):
  1. **Production N = 300 ms** for `browseLayer2DwellProvider` (still
     and video current-item Layer 2). Retry continues to bypass dwell
     (ADR-029 unchanged).
  2. **Supersede ADR-029 Decision 2 for the numeric N only.** Cap 16
     leave-cancel, one networked `load` prepare, and storage discipline
     remain binding (also restated in ADR-034 Decision 5). Do not edit
     ADR-029 Decision body text — Status on ADR-029 records this
     supersede (same pattern as ADR-023 vs ADR-014 product default).
  3. **Acceptance frame = qualitative “no hard-failure signal,” not a
     statistical failure-rate proof.** Sample size of leak windows does
     not establish a percentage; notes must not be read as a validated
     0% silent-deliver rate.
  4. **Out of this ADR:** F1 reduce-wasted-prepare (Known debt
     Unassigned); Retry user-visible definition review (Cap **17.5b**);
     long-wait reassuring copy / Retry reason UI (17.5b kickoff only).
- Alternatives considered:
  - Keep N=500 — rejected; owner intent biases earlier prepare when
    watching is likely; 500 felt slow on device.
  - N=200 — rejected; S1 hand-speed ~95% would cross dwell; guard rail
    would effectively disappear.
  - **Pass criterion = statistical significance / large-n proof of a
    failure rate (e.g. treat n=1 leak window as insufficient)** —
    rejected. Cancel leave-path is Cap 16–validated; lowering N only
    changes invocation frequency. Pass = **no observed hard-failure
    signal** (finishOk / silentDeliver in the observed leak window;
    frequency proxy + subjective smoothness + Photos storage as weak
    cost signals). Small leak-window n does **not** claim a validated
    0% rate — that is intentional, not an oversight.
  - Stack more Videos-only dual-column sessions to enlarge n before
    adopting 300 — rejected; unfalsifiable “need more n” loop; same
    ADR-030 discipline that refuses Instruments hitch/hang as a
    shipping gate by piling runs.
  - Scripted S3 “sudden stop” hand-speed mix as a required gate —
    rejected; artificial stop scenes do not represent real browse
    mood; network/device noise would dominate; more S3 time would not
    make the N decision more reliable.
  - Edit ADR-029 Decision 2 body in place — rejected; loses Accepted
    history of the initial 500 ms choice.
- Consequences:
  Work commit `15edc91` lands production 300 ms + W-16.4 / related test
  expectation sync + `cap17-17.5-notes.md`. Docs commit accepts this
  ADR and updates STATE Cap 17.5 / 17.5b / F1 Unassigned. Further
  fetch-path work, if ever scheduled, still uses ADR-034 Decision 4
  explainable + observable bar — Cap 17.5 phase title narrowing does
  not void that bar.

---

## ADR-036: Cap 17.5b Retry visibility + corner Layer-2 reassure

- Status: Accepted (2026-08-26); center coverless **`Layer2Waiting` dual
  copy** with corner reassure (Decision 3 coexistence limb) superseded
  by **ADR-039** (Accepted 2026-08-27, anchor `f1ffadf`). Corner
  reassure AND gates, G1, Retry, and LIVE layout remain binding.
- Commit/PR anchor: 527baeb
- Plain summary (owner reads this):
  Peek must not show a leftover full-page Fail+Retry after leave.
  On long Layer-2 waits (spinner visible), a short “Still loading” line
  may appear to the left of the bottom-right gold spinner after 3
  seconds — including when Layer 1 / poster is already on screen.
  Center “Loading…” stays coverless-only so it never covers the image.
  On Live rows the LIVE badge stacks **above** the gold spinner and is
  pinned to the screen trailing edge on its own Positioned so
  “Still loading” may coexist without bumping Overlay `trailingInset`.
  Fail Retry is a translucent on-media chip with theme accent label;
  fail reason copy stays on-media body.
- Context / what problem forced this:
  Cap 17 D7 asked for a user-visible Retry definition review. Code
  already had resolve / L2 fail Retry and cancel≠fail, but leave left
  `FeedPageMediaKind.failed` mounted so off-current peek could still
  show PageRetry — contradicting “cancel/leave must not show Retry.”
  Separately, long iCloud L2 waits (often **with** L1/poster + corner
  spinner only) felt dead-ended; owner wanted short corner reassure
  after a subjective 3s without covering Layer 1 and without replacing
  Cap 17.4 center coverless copy. An early draft gated reassure on
  coverless-only; device smoke showed that hid the common covered case,
  so the lock was corrected to drop the coverless requirement while
  keeping center chrome coverless-only. A later draft soft-degraded
  (hid) reassure when LIVE was visible; owner rejected the collision —
  LIVE moves above the spinner and pins to the trailing edge so both
  can show.
- Decision (what was chosen):
  1. **Page center chrome must not cover Layer 1 / poster.** Center
     wait/fail only when coverless. Feed-level library loading copy may
     stay centered (not page L2).
  2. **G1:** Fail PageRetry only when `isCurrent`; leave coerces
     `failed` → neutral pending placeholder.
  3. **Corner reassure (incremental):** after **3s** wall time while
     L2 wait spinner is visible, paint short copy left of the spinner
     (**coverless not required**). May coexist with center
     `Layer2Waiting` when coverless (not XOR). Mutex vs center
     `Layer1Loading` (L1-miss excludes reassure). With L1/poster,
     center wait stays off; corner alone. Excludes a4, L1-miss-only
     pages, fail, and off-current. **LIVE badge may coexist** — badge
     stacks above the spinner row and uses an **independent**
     `Positioned(right: inset)` trailing pin (do **not** bump Overlay
     `trailingInset`; do **not** soft-degrade-hide reassure).
  4. **¬a4 kept as path-class carve-out** (re-confirmed after dropping
     coverless): a4 is L2-ready eviction revisit, not first-wait dead
     air; 17.1 a4 max ≪ 3s; expand only with new ≥3s evidence.
  5. **Timer discipline:** leave/clear cancels the timer; ticks are
     generation-gated like a4 reveal. If unclean under fast scroll,
     remove reassure rather than ship jank.
  6. **Retry product:** fail-only Retry; cancel/leave/waiting no Retry;
     resume auto-retry only when already failed; Retry bypasses dwell;
     button has no reason subtitle; button is an explicit translucent
     `onMedia` chip (α≈0.28) with `WakeTokTokens.accent` label; fail
     reason stays `bodyOnMedia`. Fail Retry / resume-fail
     **await cancelInFlightPrepare then reload** (Dart-only; Cap16
     serial same-id path).
- Alternatives considered:
  - Center “second tier” upgrade of `Layer2Waiting` — rejected; owner
    required corner incremental placement and allowed dual copy when
    coverless.
  - Bump Overlay `trailingInset` to fit horizontal LIVE+reassure+spinner
    — rejected; shared constant would shift all Live Overlay layout.
  - Soft-degrade hide reassure when LIVE visible — **superseded**; owner
    required LIVE above spinner + independent trailing pin so reassure
    can coexist without a wider horizontal row.
  - Coverless-only corner reassure — **superseded during 17.5b device
    smoke**; common L1+spinner waits never showed copy. Replaced by
    Decision 3 (cover optional).
  - Also include a4 whenever spinner ≥3s — rejected (and re-confirmed
    after the coverless correction): separate path class + no ≥3s
    evidence; keep ¬a4 until new data.
  - Accept peek Fail+Retry as Known debt — rejected; violates leave
    cancel product narrative; cheap `isCurrent` gate.
- Consequences:
  Cap 17.5b work `527baeb` implements G1 + corner reassure + LIVE
  trailing layout + translucent accent Retry + l10n + cancel-before-
  retry + Host Layer2 fail Console probe + tests named in
  `docs/acceptance/cap17-17.5b-notes.md`. This docs commit accepts
  ADR-036 and marks 17.5b `[x]` in STATE (YOU ARE HERE remains Cap 17;
  next phase 17.6).

---

## ADR-037: Live L2→motion prepare chrome continuity (F1 handoff latch)

- Status: Accepted (2026-08-26)
- Commit/PR anchor: a42abcd
- Plain summary (owner reads this):
  On long iCloud Live waits, if the bottom-right gold spinner already
  showed during Layer-2 still download, it must not blink off and on
  again when Live motion prepare starts (that bounce also shoves the
  LIVE badge up and down). Short Live prepares that never showed an L2
  spinner still keep the Cap 17.3 “hide under 150 ms” rule. Playing an
  already-prepared Live must never turn the loading spinner on — that
  path is separate from prepare (future long-press replay uses play-only).
- Context / what problem forced this:
  Cap 17.6 Kafka soak on iCloud Live showed a two-phase corner chrome
  sequence: L2 wait spinner (+ optional Still loading) cleared, LIVE
  dropped, then motion prepare painted gold again and lifted LIVE.
  Cap 14.6b already same-frame-armed `_livePreparing` on L2 success to
  avoid a dip; Cap 17.3 F1(+D) then suppressed Live prepare gold for
  wall time &lt; T on **every** prepare arm, including after a long L2
  wait that had already shown spinner — recreating a visible gap.
  ADR-034 F1 evidence for short-prepare flash suppression remains
  valid; this is a newly observed handoff scene, not a rollback of F1.
- Decision (what was chosen):
  1. **Latch:** `_layer2WaitChromeLatched` becomes true when L2 wait
     corner spinner actually paints during this inFlight (not “elapsed
     ≥ T” alone). Cleared on new arm / leave / after handoff consume.
  2. **Handoff continuity (A):** on L2 success → Live prepare, if
     latched, skip F1 &lt;T suppress for that prepare arm so spinner
     stays up. If not latched, F1 unchanged.
  3. **Reassure (A1):** Package B Still loading stays tied to L2
     inFlight only — does **not** continue into motion prepare.
  4. **Prepare vs play-only:** `_prepareLiveMotion` is the only path
     that may set `_livePreparing` / loading chrome.
     `_playLiveMotionOnce` never arms preparing. Do **not** invent a
     Dart “already on disk” check without Host prepared-state; after
     Q7 unload Host often drops the LivePhoto — future replay needs
     keep-or-silent-re-request with chrome off, not a fake isPrepared.
  5. **ADR-034 F1:** Status notes this narrow exception; Decision 2 F1
     body is not rewritten.
- Alternatives considered:
  - Silent motion prepare whenever L1/cover exists (no second spinner)
    — rejected; weak-net motion wait would lose feedback.
  - Unify L2+motion into one wait clock — rejected for 17.6 residual
    scope.
  - Docs-only Known debt — rejected; clear foundation chrome defect
    with owner device repro.
  - Edit ADR-034 F1 Decision 2 body in place — rejected; same
    append-only pattern as ADR-035 / ADR-036.
- Consequences:
  Work `a42abcd` + tests `W-17.6-*` / updated `W-14.6b-L2`; notes
  `docs/acceptance/cap17-17.6-notes.md`. Kafka + i17 Profile PASS.
  Cap 17.6 docs mark phase `[x]`; next **17.7** Overlay capture-time.
  Long-press Live replay remains future work on the play-only path.

---

## ADR-038: Cap 17.7 Overlay capture-time honest presentation

- Status: Accepted (2026-08-27)
- Commit/PR anchor: d9db8c7
- Plain summary (owner reads this):
  Overlay capture time no longer tries to match iOS Photos to the minute.
  Row 2 shows an approximate calendar date (`~ Y-M-D`); row 1 uses coarse
  “within 3 days / within a week” bands for recent items so timezone edges
  do not fake precision. Both rows come from the same library date field;
  they are honest about uncertainty but are not guaranteed to match Photos
  or to cross-check each other like one formula.
- Context / what problem forced this:
  Cap 17.7 opened when Overlay showed whole-hour offsets vs Photos (e.g.
  `2019-11-09 05:00` vs `2019-11-08 19:00`). An implementing pass
  (`bf14f95`) pursued minute-level alignment via Host EXIF/TIFF and video
  creation strings; device evidence showed local-only limits, iCloud gaps,
  and import-timezone cases where `creationDate` reinterpreted in device
  local time still disagreed with Photos (e.g. cross-region saved video:
  correct day in Photos, wrong hour when forced through device TZ). Owner
  reverted that path (`2c0a090`) and **changed the product goal**:
  prefer fuzzy correctness over precise wrongness. Cap 19 may later show
  richer info on long-press with disclaimer; Overlay remains lightweight.
- Decision (what was chosen):
  1. **Single source:** `PHAsset.creationDate` only — Dart `toLocal()`
     calendar math. No Overlay EXIF/Host wall-clock API, no network read,
     no Photos-import private timezone fields.
  2. **Row 2 (exact label):** day precision only — l10n `~ {Y-M-D}`
     (EN and zh-Hans unified `~` prefix). Remove minute datetime key
     (`mediaInfoExactDateTime`). Not authoritative Photos wall clock.
  3. **Row 1 (relative):** keep D3=B — elapsed vs device `now` on the
     same `creationDate` instant; **do not** derive relative from row 2
     or EXIF Y-M-D. Coarse mapping on existing `diffDays`:
     - `0–2` → “Within the past 3 days” / `3天内`
     - `3–7` → “Within the past week” / `一周内`
     - `8–30` → `{N} days ago` / `{N} 天前`
     - `>30` → existing month/year strings (unchanged)
     Delete `mediaInfoRelativeToday` (merged into 0–2 band).
  4. **Relative R2 superseded:** the draft that kept “Today” and added
     `Around` / “昨天左右” on selected bands is **not** implemented;
     coarse short bands replace that approach (no `Around`/`约` on row 1).
  5. **Honesty boundary (rows 1 ↔ 2 ↔ Photos):**
     - Same **product stance**: avoid copy that ±1 calendar-day timezone
       error can obviously falsify.
     - **Not the same formula:** row 2 is absolute approximate date; row 1
       is elapsed buckets — do **not** expect users to reverse-engineer
       row 1 from row 2 or vice versa as a proof obligation.
     - **Within WakeTok:** both rows use the same `creationDate` → local
       calendar day; for `diffDays` 8–30, `{N} days ago` matches that
       date arithmetically; short bands intentionally hide `N`.
     - **vs Photos:** may differ by ±1 calendar day at import/timezone
       edges; accepted constraint, not Overlay bug chase in Cap 17.7.
  6. **Archive:** minute-level Host/EXIF implementation notes and Swift
     reference live in gitignored
     `docs/private/cap17-7-minute-wall-clock-archive/` (not product path).
- Rejected alternatives (why not B):
  - **Minute-level Photos match** (`bf14f95`) — reverted (`2c0a090`):
    precise wrong on import TZ / missing local bytes; local-only cannot
    match Photos private import timezone for all assets.
  - **Relative R2** (`Around 1 day ago` / “昨天左右”, Around on 8–30) —
    superseded; conflicts with coarse-band strategy; keeps false precision
    on “Today”.
  - **Anchor relative to EXIF/row-2 Y-M-D** — rejected; reopens D3 and
    couples rows against locked Instant-vs-now relative semantics.
  - **Row 2 bare `Y-M-D` without `~`** — rejected after review; reads as
    false authority next to Photos.
  - **Row 1 `Around` modifiers instead of coarse bands** — rejected;
    “Around Today” awkward; owner chose interval copy without extra hedge
    words on row 1.
- Consequences / constraints accepted:
  Work `d9db8c7` + tests `cap17_7_exact_date_approx_test.dart` (U1–U4,
  R-A…R-future). Device smoke PASS iPhone13pro Kafka. STATE marks 17.7
  `[x]`; Known debt Overlay capture-time row **Closed** with goal-change
  note. Cap 17 YOU ARE HERE → **17.8** close-out. Cap 19 may add
  creationDate + disclaimer on long-press; does not reopen Overlay minute
  alignment in Cap 17.7 scope.

---

## ADR-039: Cap 17.9 — delete center Layer2Waiting; source-switch Layer1 label delay

- Status: Accepted (2026-08-27)
- Commit/PR anchor: f1ffadf
- Plain summary (owner reads this):
  Remove the redundant center “Loading…” on coverless Layer-2 waits —
  corner spinner and “Still loading” reassure are enough. Fix a
  coverless video re-enter race so loading state is correct before
  Layer-2 arms. When switching All / Photos / Videos, hide the visible
  “Loading item” center text for 150 ms on the new tab’s first item;
  the corner spinner and screen-reader feedback stay immediate.
- Context / what problem forced this:
  Known debt questioned whether center `Layer2Waiting`
  (`mainBrowseFeedLayer2Waiting`) added value beyond center
  `Layer1Loading` and corner reassure (Cap 17.5b). Production paths
  rarely showed center “Loading…”; coverless L2 often duplicated copy
  with reassure after 3s (`W-17.5b-dual`). A coverless video
  leave→re-enter with an L2-ready token could arm in-flight before
  `_startLoad` finished, briefly exposing the wrong center wait state.
  Separately, quick All / Photos / Videos tab switches flashed one
  frame of center “Loading item” on the remounted current page even
  when Layer 1 completed within milliseconds.
- Decision (what was chosen):
  1. **Delete runtime center Layer2Waiting.** Remove
     `mainBrowseFeedLayer2Waiting` from ARB and all paint paths.
     Coverless L2 wait keeps bottom-right gold spinner; semantics use
     `mainBrowseFeedLayer3Loading`. Center fail slot unchanged.
  2. **Corner reassure unchanged.** `shouldShowLayer2CornerReassure`
     stays independent (cover not required; mutex vs L1-miss page
     only). Supersedes ADR-036 Decision 3 dual-copy coexistence when
     coverless; does **not** change Package B AND gates.
  3. **Coverless re-enter order fix.** In
     `_holdVideoSurfaceForL2ReloadIfNeeded`, when the page has no
     display/poster, set `_loading = true` **before**
     `_armLayer2InFlight` so the hold/startLoad async gap cannot form
     `!_loading` + coverless + inFlight.
  4. **Source-switch-only visible Layer1 center delay.** On the first
     current `MediaFeedPage` mounted after an All / Photos / Videos
     source change, delay **visible** center `mainBrowseFeedLayer1Loading`
     copy for **150 ms** (`kSourceSwitchLayer1CenterLabelDelay`).
     Corner spinner and VoiceOver semantics remain immediate. Cold
     start, vertical swipe to a new item, and in-place reload stay
     immediate center copy. Constant is **independent** from a4
     suppress `kDefaultA4SuppressBelow` (same initial value, separate
     product decision).
  5. **Feed-shell library loading retained.** One-frame
     `mainBrowseFeedLoading` (“Loading library…”) on tab switch may
     still appear while `browseSessionProvider` reloads; owner
     accepted as optional polish debt (blank-hold rejected as
     bug-like). Not in 17.9 scope.
- Rejected alternatives (why not B):
  - **Wire L1-miss→L2 guard (Known debt option B)** — rejected; owner
    chose delete center Layer2Waiting (option A).
  - **Collapse to one center wait string (option C)** — rejected with A.
  - **Reuse a4 T constant for source-switch delay** — rejected; tab
    switch polish and a4 wait distribution are separate decisions.
  - **Delay corner spinner / semantics on source switch** — rejected;
    accessibility and immediate motion feedback must stay.
  - **Suppress feed-shell library loading on tab switch** — deferred;
    owner retained one-frame shell flash over empty feed color.
- Consequences / constraints accepted:
  Work `f1ffadf` + tests (`main_browse_wait_copy_cleanup_widget_test.dart`,
  updated cap17_3/4/5b). Kafka Profile 4-step device验收 PASS.
  STATE marks 17.9 `[x]`; Known debt Layer2Waiting + source-switch
  Layer1 center flash **Closed**; feed-shell library tab-switch flash
  **Unassigned optional polish**. Docs commit accepts ADR-039;
  ADR-034 Status notes 17.4 center Layer2Waiting supersession;
  ADR-036 Status notes dual-copy supersession. `cap17-17.5b-notes.md`
  supersession note appended (historical dual-copy facts preserved).

---

## ADR-040: Cap 18 Main Browse gesture arbitration and dual-signal Manual playback control

- Status: Accepted (2026-08-28); Decision 13 is narrowly supplemented by
  Cap 18.5 (2026-08-29 — corrected from an earlier docs-commit-date
  attribution; work `3d115a4`, docs `04ef327`; 2026-08-31; work `b2ceabd`);
  Decision 13 Cap 19.2b scrub-drag keep-playing supplement (2026-09-01;
  work `96d5ead`); Decision 13 Cap 19.2c preview/seek quantizer align
  (2026-09-01; work `0ef9ef2`); Decision 13 Cap 19.2d seek-hold + live
  ghost (2026-09-01; work `7637812`); Decision 18 Limited deferral
  superseded by ADR-041 (2026-09-01); Decision 20 supplement added
  (2026-09-01; docs `372175c`)
- Commit/PR anchor: `0df9ceb` (Cap 18.4 work — tap, center affordance,
  lifecycle auto-resume pivot; follows Cap 18.3 dual-signal work
  `84ef30c`); Cap 18.5 supplement anchor `04ef327`; Cap 18.5 preview
  tolerance / drift-gate supplement anchor `b2ceabd`; Cap 19.2b Decision 13
  supplement anchor `96d5ead`; Cap 19.2c Decision 13 supplement anchor
  `0ef9ef2`; Cap 19.2d Decision 13 supplement anchor `7637812`; Cap 19
  Decision 20 supplement anchor `372175c`
- Plain summary (owner reads this):
  Cap 18 freezes Main Browse’s gesture-arbitration inventory once, then
  implements vertical swipe arbitration, video media-area tap
  pause/resume, and a video scrubber under a dual-signal Manual play
  model. Returning through a new navigation activation always restarts
  from zero and auto-plays. Foreground resume and surface reattachment
  do not restart. Later Caps own 2×, Cap 19 entry chrome, pinch,
  Live replay button, and left-swipe add-to-album — Cap 18 only locks
  their slots and conflict rules.
- Context / what problem forced this:
  Main Browse already supports vertical swipe and foreground video
  playback, but it has no user-facing pause/resume control or scrubber.
  Known debt **434** records a consequence: after Manual Browse leaves
  the foreground, native playback pauses and later reattaches the same
  frame, but the user cannot resume without swiping away. Known debt
  **395** records inconsistent navigation-return behaviour caused by
  the bounded 1+1 player pool: if the previous player has been evicted,
  A→B→A rebuilds A at zero; if A remains in the player pool, ADR-026
  Decision 3 uses `playOnly` and preserves its mid-play position.
  Cap 18 turns restart-from-zero on every new navigation activation into
  intentional product behaviour. This decision is based on debt **395**
  and the desired deterministic contract, not on a claimed competitor
  convention. Owner audit also expanded the gesture inventory beyond an
  earlier six-item sketch: entry chrome is no longer a long-press
  recognizer; 2× uses both edges; left-swipe add-to-album shares those
  edges; pinch-zoomed pan must override vertical swipe; Live needs an
  explicit replay button as a narrow ADR-019 exception. ADR-006 remains
  binding: Swift owns `AVPlayer`; Dart owns product intent and
  orchestration.
- Decision (what was chosen):
  1. **Gesture-arbitration inventory (define once).** Cap 18 freezes
     Main Browse’s known gesture-arbitration inventory in one place.
     Item count is **not** a hard promise — future Caps may add or
     remove entries; count itself is not a contractual constraint.
     Current known inventory:
     1. **Vertical swipe** — already shipped; not redesigned here.
     2. **Tap** — ordinary video only; Cap 18 delivers.
     3. **Progress-drag / scrubber** — ordinary video only; Cap 18
        delivers.
     4. **2×** — left **or** right edge hold, temporary rate, release
        → 1×, **no** slide-down lock; Share / Mute / Fit / 2× Cap
        delivers.
     5. **Cap 19 entry container** — fixed bottom-trailing icon that
        opens a half-sheet panel (replaces long-press-as-entry);
        Cap 19 delivers panel contents; Cap 18 freezes only the
        hit-test / arbitration slot.
     6. **Pinch** — still: persistent zoom + Reset; video: non-
        persistent (release → fit); Cap 20 delivers.
     7. **Live Photo replay control** — new explicit control before
        the existing LIVE badge; owning Cap TBD; requires ADR-019
        Decision 8 narrow supplement (Decision 17).
     8. **Left-swipe add to WakeTok album** — new horizontal gesture;
        Cap 19 delivers; Cap 18 freezes the slot and the edge-hold
        vs horizontal-drag arbitration with item 4 (Decision 18).
     Cap 18 freezes and **implements** only items 1–3 (swipe / tap /
     progress-drag). Existence, concrete form, and owning Cap for
     items 4–8 are stated per item above. This ADR does **not**
     pre-judge gestures not listed here. Cap 18 does **not** ship
     product UI or recognizers for items 4–8; it freezes reserved
     regions and conflict rules so later Caps can land without
     rewriting the Cap 18 arena.
  2. **Shipped Cap 18 regions, priority, and reserved exceptions.**
     Shipped active regions: (1) scrubber band above the bottom
     control bar, not overlapping Media Info Overlay (same Q4=B
     placement); (2) media-area tap outside the scrubber band,
     existing controls, Overlay, and reserved trailing chrome slots;
     (3) existing vertical `PageView` swipe. Baseline priority for
     shipped Cap 18 behaviour:
     `scrubber band > media-area tap > vertical PageView swipe`,
     implemented primarily through spatial separation and locked by
     gesture-arena tests. Any touch that begins inside the scrubber
     band belongs to the scrubber: a pure tap (no material movement)
     in that band is a **no-op** and must **not** fall through to
     media-area tap pause/resume. Tap pause/resume applies only to an
     L2-ready ordinary video. Tap on a still or Live Photo has no
     playback effect under this Cap’s shipped rules. Live continues
     ADR-019 play-once for accidental gesture/tap replay (see
     Decision 17 for the explicit-control exception).
     **Reserved arbitration exceptions** (contract now; implement in
     owning Caps):
     - **Edge hold (2×) vs left-swipe album** (items 4 and 8): both
       claim left/right edge strips. Distinguish with the same class
       of early-motion threshold already used to separate tap from
       vertical swipe — if significant horizontal translation appears
       within a short press window, treat as left-swipe album; if the
       finger stays put past the hold threshold, treat as 2× hold.
       Do not pretend the conflict is absent.
     - **Pinch-zoomed still pan** (item 6): while a still is in any
       non-fit magnified state, single-finger drag is pan-to-inspect
       and must **not** drive vertical `PageView` swipe; vertical
       swipe returns only after fit. This is an explicit exception to
       the baseline priority order above.
     - **Trailing chrome slots** (items 5 and 7): bottom-trailing
       iconography (Cap 19 entry icon; Live replay control before the
       LIVE badge; existing LIVE badge / corner wait chrome) share
       trailing real estate. Cap 18 freezes that these slots are
       outside scrubber / media-tap / vertical-swipe arenas. Concrete
       stacking / spacing among those trailing controls is owned by
       Cap 19 and the Live-replay owning Cap — not redesigned here.
  3. **Dual-signal playback model.**
     `effectiveShouldPlay = userIntentWantsPlay && systemPermissionAllowsPlay`.
     `userIntentWantsPlay` represents the current video activation’s
     requested play state. `systemPermissionAllowsPlay` includes at
     least: an allowed foreground lifecycle state; current-page
     ownership; playable video readiness; display-surface readiness;
     and no transition, failure or teardown gate that prohibits
     playback. A future Background Audio capability may expand the
     system-permission predicate. It must not bypass explicit user
     intent.
  4. **Navigation activation and intent lifecycle.** A single
     `startsNewNavigationActivation` result drives both resetting intent
     to true and restarting playback from zero. New navigation
     activations include: initial current-video activation; A→B; B→A;
     and source/session navigation that produces a newly current feed
     item. They do **not** include: foreground resume of the same
     current item; surface reattachment; same-item widget rebuild;
     transition-cover release; or tap resume. For every new video
     navigation activation: `userIntentWantsPlay = true`, seek to zero,
     and auto-play when system permission allows — regardless of whether
     the video was paused or playing when previously left.
     **Cap 18.4 narrow supplement (device M-434′):** lifecycle leave
     (`inactive`, `paused`, `hidden`, background) performs a **mechanical
     pause only** — it does **not** write `userIntentWantsPlay = false`.
     Leave sets `isForegroundLifecycle = false`, which denies
     `systemPermissionAllowsPlay` without mutating user intent.
     Foreground resume (`onForegroundResumeSync`) restores
     `isForegroundLifecycle = true` and re-applies the **preserved**
     intent — when `userIntentWantsPlay == true`, playback auto-resumes
     (respecting mute). User tap-pause before a system interrupt leaves
     intent false → remain paused on resume with center affordance
     (Decision 12). Foreground resume is never a navigation activation.
  5. **Dart activation generation source.** Cap 18 reuses the existing
     `FeedActivationCoordinator.currentDisplayGate`. No second
     playback-specific generation counter is introduced. Reasons:
     `FeedActivationCoordinator.beginCurrentItem()` synchronously bumps
     `currentDisplayGate`; Cap 15.4 tests already require one
     `beginCurrentItem()` per become-current activation;
     `_activateCurrentItem` avoids a duplicate begin for the same
     current asset and generation; A→B→A receives distinct generations
     even when the asset identifier returns to A; App lifecycle
     foreground resume does not call `beginCurrentItem()`; the gate
     already invalidates stale current-display work.
     `_layer2InFlightGeneration` is **not** used because it is
     page-local, nullable and scoped only to Layer 2 I/O. Before
     sending an effective `play()` or `pause()` after an asynchronous
     gap, the coordinator must verify
     `currentDisplayGate.isCurrent(capturedGeneration) &&
     activeAssetIdentifier == intent.assetIdentifier`. Failure means the
     operation is stale and no targetless playback command may be sent.
  6. **Explicit Pigeon intent and navigation-activation mirror.** Add
     Pigeon DTO `PlaybackIntentDto` with required fields
     `assetIdentifier`, `wantsPlay`, `startsNewNavigationActivation`,
     and `clearsPendingNavigationActivation`, plus HostApi
     `setPlaybackIntent(PlaybackIntentDto intent)`. A bare-bool method
     shape is not part of the contract. The Dart coordinator must:
     (1) capture the current asset identifier and `currentDisplayGate`
     generation; (2) compute the activation / pending-clear flags once
     for that update; (3) build one `PlaybackIntentDto`; (4) await
     `setPlaybackIntent(dto)`; (5) revalidate the captured generation
     and asset identifier; (6) only while still current, await `play()`
     or `pause()`. Lifecycle-driven leave-foreground updates
     (`inactive`, `paused`, `hidden`, or background) send the
     **preserved** `wantsPlay` value (not forced false),
     `startsNewNavigationActivation = false`, and
     `clearsPendingNavigationActivation = true`. Other updates default
     `clearsPendingNavigationActivation` to false unless a later ADR
     explicitly defines another cancellation case.
     `setPlaybackIntent` and the following playback command must not be
     issued concurrently. The Swift implementation must complete the
     mirror update before replying to Pigeon; it must not enqueue the
     mutation asynchronously and return first. `play()` and `pause()`
     retain their existing mechanical semantics and do not infer or
     mutate user intent.
  7. **Persistent intent mirror and one-shot activation are separate.**
     Host state separates persistent intent from one-shot activation.
     Conceptual state: `PlaybackIntentMirror { assetIdentifier,
     wantsPlay, clearEpochAtArm }`, `PendingActivation {
     assetIdentifier, clearEpochAtArm }`, optional
     `playbackIntentMirror` and optional `pendingNavigationActivation`.
     A nil `playbackIntentMirror` has default semantic
     `userIntentWantsPlay = true`. When `setPlaybackIntent` is received,
     Host synchronously records a mirror bound to
     `(intent.assetIdentifier, current clearEpoch)`. If
     `startsNewNavigationActivation` is true, Host arms a
     `PendingActivation` for that asset and epoch. By default, a
     non-navigation intent update does not erase a still-pending
     matching navigation activation before it can be applied. The
     explicit exception is a lifecycle-driven leave-foreground update:
     when `clearsPendingNavigationActivation` is true, Host must
     synchronously clear a pending activation **only** when it matches
     the same `(assetIdentifier, clearEpochAtArm)` validation used by
     Decision 8, before replying to Pigeon. It must reuse that shared
     identity/epoch matcher rather than implement a second validation
     path. A false clear flag preserves the matching pending activation,
     including when `wantsPlay = false`; implementations must not infer
     clearing from `wantsPlay` alone. A newer navigation activation
     replaces the previous pending activation.
  8. **Host identity and epoch validation.** Before using the intent
     mirror, Host validates
     `mirror.assetIdentifier == currentAssetIdentifier &&
     mirror.clearEpochAtArm == clearEpoch`. Before consuming a pending
     activation, Host validates the same identity/epoch pair on the
     pending value. Only validated values become `trustedWantsPlay` and
     `trustedStartsNewNavigationActivation`. An untrusted intent mirror
     must not affect the current item. An invalid pending activation is
     discarded and treated as
     `trustedStartsNewNavigationActivation = false`; that false value
     does **not** force `playOnly` — ADR-026’s existing `itemAtEnd`
     branch still applies. The pending activation is strictly one-shot:
     retain while the matching player is not ready; consume when the
     matching become-current policy is evaluated; clear immediately
     after evaluation; discard on asset/epoch mismatch; clear on cancel,
     supersede or pool clear where the corresponding activation is no
     longer valid.
  9. **ADR-026 Decision 3 narrow supplement.**
     `VideoPlaybackPolicy.actionOnBecomeCurrent` remains a pure,
     Host-testable function and receives only a validated boolean
     `trustedStartsNewNavigationActivation`. Policy: if player does not
     exist → `prepareNew`; else if trusted new navigation activation →
     `seekZeroAndPlay`; else if item at end → `seekZeroAndPlay`; else →
     `playOnly`. This narrowly supplements ADR-026 Decision 3: a new
     navigation activation always restarts from zero; a non-navigation
     technical re-entry preserves ADR-026 D3; foreground resume and
     surface reattachment use `playOnly` for a mid-play player; at-end
     technical re-entry still seeks zero and plays. The same trusted
     navigation result must drive intent reset and seek policy.
     Separate Dart and Host derivations are forbidden. After the
     implementing work commit exists, the following docs commit must
     append the narrow-supersede statement and real work SHA to
     ADR-026’s Status line.
  10. **ADR-026 item-end narrow supplement.**
      `VideoPlaybackPolicy.actionOnItemEnd` remains pure and adds
      `trustedUserIntentWantsPlay`. Foreground item loop returns
      `loopSeekZeroAndPlay` only when it is foreground page-driven, the
      observed item is the current player item, the active asset is
      current, and `trustedUserIntentWantsPlay == true`. When trusted
      intent is false, item-end must not restart playback. ADR-006
      background plan-end behaviour remains higher priority and
      continues to stop without looping.
  11. **Pool-clear semantics.** `clearPlaybackPool()` must clear
      `playbackIntentMirror` and `pendingNavigationActivation`, restoring
      default user intent to true. This intentionally differs from mute:
      mute is a cross-item user preference and survives pool clear;
      playback intent belongs to the current activation and resets;
      pending navigation activation must never cross a clear epoch.
  12. **Tap and center affordance.** For an L2-ready current video:
      media-area tap while playing sets intent false and pauses;
      media-area tap while paused sets intent true and plays when
      system permission allows. Center affordance appears only when
      `userIntentWantsPlay == false` on a foreground current L2-ready
      video (user tap-pause — not merely lifecycle mechanical pause
      while intent remains true). Debt **434** closes through: system
      interrupt auto-resumes when intent was preserved (Decision 4
      supplement); user tap-pause before interrupt stays paused with
      affordance + tap resume. No lock-aware special-case
      implementation is permitted.
  13. **Runtime observe and scrubber (item 3).** `PlaybackApiHost`
      periodically emits the existing `PlaybackRuntimeEventDto` with
      current asset identifier, feed index, playback position and
      playback state. For the current ordinary video page the scrubber
      band is **always visible** (not conditionally hidden). Until that
      video’s Layer 2 is ready, the scrubber is **frozen**: visible,
      non-interactive, no progress fill, no drag response. Unfreeze
      uses the existing L2-ready signal only — Cap 18 does **not** add
      a Host iCloud-transfer progress signal for the scrubber. While
      unfrozen and idle, the scrubber follows trusted runtime position.
      Interaction is **drag-only**: tapping a point on the bar to jump
      is **not** supported; a pure tap in the band is a no-op
      (Decision 2). During drag, update only a static timestamp label
      for the drag position — **no** frame-by-frame scrub preview in
      Cap 18. On finger release, call `seek(position)` **once**, then
      return runtime-event ownership to Host observations. Photos-style
      scrub preview (continuous seek / thumbnail strip) is an **optional
      later enhancement**, not a Cap 18 hard acceptance gate; technical
      feasibility under iCloud streaming `AVPlayer` may be evaluated
      during or after 18.5 scrubber work, and must not expand 18.4
      (tap / debt **434**) scope. Scrubber progress is playback
      progress, not debt **403** iCloud transfer progress. Still and
      Live pages do not show a scrubber.
  14. **2× future constraint (item 4).** Cap 18 does not implement 2×.
      Future MVP 2×: hold **left or right** edge for temporary 2×
      (both edges, for left- and right-handed use); release → 1×; **no**
      slide-down lock. Cap 18 freezes both edge strips as reserved hold
      regions in the arbitration map and records the edge-hold vs
      left-swipe conflict rule (Decision 2 / Decision 18). Cap 18 adds
      no 2× recognizer or rate-change product UI.
  15. **Cap 19 entry container (item 5; replaces long-press entry).**
      Product entry is a **fixed bottom-trailing icon**, always visible
      (not gated by Photos authorization state). Tap opens a half-sheet
      rising from the bottom. Cap 18 freezes only the icon’s hit-test /
      arbitration slot (outside scrubber, media-area tap, and vertical
      swipe). Cap 18 does **not** ship the icon widget, panel, or
      album-list UI. Cap 19 owns panel contents. The in-panel **Add to
      Album** row remains bound by kickoff **ADR-K**: under Full Access,
      show album list normally; under Limited, album enumerate/resolve
      is unavailable — Limited must either omit that row or show an
      explicit Full Access requirement, and must **not** open an empty
      or erroring album panel. That is precise ADR-K application, not a
      supersession. Other future panel rows are Cap 19’s concern.
  16. **Pinch reserved rules (item 6).** Cap 20 delivers pinch. Cap 18
      freezes: still persistent zoom + Reset; video non-persistent
      (release → fit). While a still is magnified (any non-fit state),
      the Reset control must remain welded into the visible safe area
      (not covered or dismissed by other chrome). Pinch-out / reverse
      pinch may return toward 1× as a second exit beside Reset; forcing
      below 1× clamps to fit — **no** smaller-than-fit shrink state.
      Magnified still single-finger drag = pan only (Decision 2
      exception); fit restores vertical swipe.
  17. **Live Photo replay control + ADR-019 Decision 8 narrow
      supplement (item 7).** Product adds an explicit replay control
      immediately before the existing bottom-trailing LIVE badge;
      activating it replays Live motion once. MVP does **not** add
      Photos-style long-press-to-replay; that gesture slot stays unused.
      This **narrowly supplements** ADR-019 Decision 8: the original
      “no gesture/tap replay” + disabled
      `PHLivePhotoView.playbackGestureRecognizer` hard gate remains for
      accidental recognizer-driven replay; an **independent, explicit
      control** (not a media-area tap / not a long-press recognizer) is
      an intentional directed exception because explicit control
      activation ≠ accidental gesture replay. All other ADR-019 clauses
      stay. Owning Cap for the control is TBD. Cap 18 does not ship the
      control. When that work commit exists, the following docs commit
      must append the narrow-supersede note and real SHA to ADR-019’s
      Status line (same pattern as ADR-026 in Decision 9) — **not** as
      part of Cap 18.3 / 18.4 docs acceptance.
  18. **Left-swipe add to WakeTok album (item 8).** Horizontal
      left-swipe appends the current asset into a fixed WakeTok album
      created automatically on first app launch (append-only; does not
      remove other album memberships). Default **on**; user may disable
      in Settings (Settings Cap owns the toggle UI; Cap 18 only records
      the preference intent). Cap 18 freezes the gesture slot and the
      edge-hold vs horizontal-drag arbitration with item 4 (Decision 2).
      Cap 18 does not ship the recognizer or album mutation.
      **Limited Access feasibility is unknown** and must be verified in
      Cap 19 — do **not** lock a Limited conclusion in this ADR. If Cap
      19 finds Limited cannot support the append, force the gesture off
      under Limited by reusing the same user-visible enable bit (no
      second switch); Full Access keeps the Settings preference.
      Horizontal-edge interaction with system back / interactive-pop
      remains a Cap 19 device-acceptance risk, not a Cap 18
      implementation item.
  19. **Persistence boundary.** Cap 18 introduces no database table or
      migration. Playback intent, pending activation, runtime position
      and scrub state are current-session runtime state.
      SessionCheckpoint persistence remains deferred. The left-swipe
      enable preference (Decision 18) is a Settings-owned preference
      when that Cap lands — not introduced by Cap 18 schema work.
- Rejected alternatives (why not B):
  - **Bare bool parameters for intent/activation** — rejected; intent
    and navigation activation require asset identity and future
    contract evolution; DTOs match existing Playback contract
    conventions.
  - **Separate `beginNavigationActivation()`** — rejected; two Pigeon
    calls introduce ordering dependency and a second state machine with
    possible orphaned activation state.
  - **Infer activation from `load()` or `syncPlanPosition()`** —
    rejected; those methods already own plan bookkeeping and
    preparation responsibilities; inference would create a second
    activation definition outside Dart coordinator control.
  - **Infer intent from `play()` / `pause()`** — rejected; technical
    playback operations do not represent user intent
    (`PvTransitionGuard` Dart resume; Swift background/clear direct
    pause paths).
  - **Ask Dart at native item-end** — rejected; introduces an
    asynchronous race into `AVPlayerItemDidPlayToEndTime` handling and
    conflicts with `endSeekInFlight`.
  - **New playback-only Dart generation counter** — rejected;
    `currentDisplayGate` already provides exactly-once become-current
    generation semantics and stale-operation validation.
  - **Keep “no physical placeholders / no reserved regions”** —
    rejected; owner audit requires Cap 18 to freeze slots and conflict
    rules for items 4–8 without shipping their product UI.
  - **Hide scrubber until L2 ready** — rejected; scrubber stays visible
    and freezes until L2 ready.
  - **Tap-to-seek on the progress bar / Cap 18 scrub preview** —
    rejected as Cap 18 hard scope; drag + single seek-on-release only;
    continuous preview is optional later work.
  - **Right-edge-only 2×** — rejected; both edges for handedness.
  - **Long-press-as-Cap-19-entry** — rejected; replaced by always-
    visible bottom-trailing icon + half-sheet (Decision 15).
  - **Photos-style Live long-press replay in MVP** — rejected; explicit
    control only (Decision 17).
  - **Pretend 2× edge hold and left-swipe do not conflict** —
    rejected; early-motion threshold rule is mandatory (Decision 2).
  - **Lock Limited behaviour for left-swipe in Cap 18** — rejected;
    Cap 19 must verify first (Decision 18).
- Consequences / constraints accepted:
  Cap 18 must preserve ADR-006 native player ownership; ADR-019 Live
  play-once and disabled `playbackGestureRecognizer` except for the
  recorded Decision 17 explicit-control narrow supplement; ADR-027
  Settings-leave session behaviour; ADR-026 technical re-entry
  behaviour outside the stated narrow supplements; Cap 15 transition
  cover and audio suppression; Cap 16 cancellation and dwell behaviour;
  kickoff ADR-K for Limited album enumerate/resolve on Cap 19 panel
  Add-to-Album.
  Layer responsibilities: domain playback intent/rules + repository
  interface; `lib/features/main_browse/` owns `PlaybackCoordinator`,
  reuse of `FeedActivationCoordinator.currentDisplayGate`, tap/scrubber
  UI and post-await generation/asset validation; `lib/app/browse/`
  wires providers only; Pigeon adds `PlaybackIntentDto` +
  `setPlaybackIntent`; gateway maps DTOs; Host owns intent mirror,
  `PendingActivation?`, asset/clearEpoch validation and runtime event
  emission; `VideoPlaybackPolicy` stays pure trusted-input policy only.
  Data Contract: `PlaybackGateway.setPlaybackIntent(intent)` is state
  sync, not a playback command; `play()`/`pause()` do not mutate intent;
  intent update must complete before the associated playback command;
  Dart must revalidate activation generation and asset after awaiting;
  Host trusts intent/activation only after assetId and clearEpoch
  validation; activation is one-shot while intent persists for the
  matching asset/epoch; pool clear resets intent to default true and
  removes pending activation.
  Debt **395** cannot close until this specific pre-existing failing
  branch passes: A plays to mid-position → swipe to B → return to A
  before A’s old player is evicted from the 1+1 pool → A seeks to zero
  → A auto-plays — tested with A previously playing and tap-paused.
  Testing only the already-evicted/rebuilt-player path is insufficient
  because that path already restarted at zero before Cap 18. After work
  and unit/device verification, debt **395** becomes
  **Closed by Cap 18 — intentional design**.
  Debt **434** acceptance (Cap 18.4 device M-434′): current video
  playing → inactive/background → return foreground on same item →
  **auto-resumes** when intent preserved (respect mute). User tap-pause
  before interrupt → stay paused on resume → center affordance → tap
  resumes. Supersedes the Cap 18.1 draft that required foreground stay
  paused until tap.
  **Accepted narrow intent race.** When
  `trustedStartsNewNavigationActivation == true` and the matching
  player still exists in the 1+1 pool, `actionOnBecomeCurrent` returns
  `seekZeroAndPlay` without consulting a later `wantsPlay = false`
  update for the same activation. Because a non-navigation intent
  update does not clear the pending navigation activation, a pause
  issued between navigation return and Host policy evaluation could
  theoretically be overwritten by that seek-and-play action. Under the
  current pooled-player path, this window is expected to complete
  within the same or an effectively adjacent rendering frame and is
  judged not human-triggerable; this is an implementation expectation,
  not a formal impossibility guarantee. Cap 18 adds no branch for it.
  If device acceptance or later production evidence makes the behaviour
  reproducible, add a new Known debt row rather than silently expanding
  Cap 18.

**Cap 18.5 Decision 13 narrow supplement (2026-08-29 — corrected from an
earlier docs-commit-date attribution; work `3d115a4`, docs `04ef327`; device
i17 Green + Kafka Profile PASS —
`docs/acceptance/cap18-18.5-notes.md`):**

1. **Scrub preview bubble shipped.** Cap 18.5 adds Host
   `requestScrubPreviewFrame` (AVAssetImageGenerator JPEG; must not seek
   active AVPlayer) and a drag-only preview bubble above the scrubber band.
   This narrowly supplements Decision 13’s Cap 18 “no frame-by-frame scrub
   preview” hard gate — preview is optional enhancement that **did** land in
   18.5, not a Cap 18 hard acceptance requirement.

2. **Preview pipeline contract.** 1.0s bucket quantize; Dart single-flight
   throttle; Host coalesce; §2.1 borrow allows at most one bucket-step lag
   (350 ms wall-clock) when scrub direction is monotonic. Placeholder gaps
   under fast drag are accepted (debt **442**).

3. **Scrub release seek path.** On finger release: mechanical pause during
   drag; then `seek(positionSeconds)` with async Pigeon completion (zero
   tolerance + 450 ms Host wall-clock timeout); clear stale
   `pendingNavigationActivation`; then `playFromCurrentPosition()` (not
   `play()` re-enter seek-zero). `playbackSeekEpoch` invalidates overlapping
   loop seek-zero completions.

4. **Second-granularity quantizer.** Linear ratio drag; label + release seek
   use `round(ratio × duration)` whole seconds (debt **443** — intentional;
   not Photos 0.01s). Thumb/fill follow continuous ratio while dragging.

5. **Resident chrome pairing.** Track + `MM:SS / MM:SS` timestamp paint
   together via `scrubberResidentChromeVisible` (L2-ready and duration known);
   peek-hide during mid-swipe via vertical-feed settle gate.

**Cap 18.5 Decision 13 narrow supplement — preview end-cap, drift gate, and
mid-path zero tolerance (2026-08-31; work `b2ceabd`; device i17 Green +
iPhone13pro Kafka Profile PASS — `docs/acceptance/cap18-18.5-notes.md`):**

1. **Mid-path preview bucket unchanged.** Scrub preview requests remain on the
   existing 1.0s bucket quantizer (`kScrubPreviewBucketStepSeconds`); label,
   release seek, and Host `requestScrubPreviewFrame(positionSeconds)` all stay
   on whole-second keys. This supplement does **not** expose sub-second preview
   buckets or change `scrubberSeekSeconds` / round-quantizer behaviour (debt
   **443** unchanged).

2. **End-cap zone definition.** End-cap applies when the preview request falls
   in the asset's last incomplete second, or when Dart issues the tail shot at
   `duration − ε` (`kScrubPreviewEndEpsilonSeconds = 0.05`). Requests **past**
   PhotoKit asset duration (`position > duration + slack`) are **not** end-cap:
   Host keeps keyframe snap there so Dart/Host duration skew cannot force exact
   seeks past EOS and starve the single-flight preview queue.

3. **Host zero tolerance on end-cap.** Inside the end-cap zone (and, after
   item 6, all in-range mid-path requests), `AVAssetImageGenerator` uses
   `requestedTimeToleranceBefore/After = .zero` so tail watermark frames are
   not replaced by earlier keyframe snap under infinite tolerance.

4. **End-cap and drift-reject failures forbid borrow.** When preview is in the
   end-cap zone, or when Dart rejects a returned frame under item 7 (Option B),
   `forbidBorrow` is true: §2.1 borrow must not fill the bubble with a prior
   bucket JPEG (prevents re-legalizing “frames before the Douyin tail” and
   displaying misaligned frames after drift reject). Ordinary Host **nil** on
   mid-path still allows bounded §2.1 borrow.

5. **Whole-second scrub seek unchanged.** Progress-drag release still uses
   `round(ratio × duration)` whole-second seek with zero-tolerance async Pigeon
   seek, 450 ms Host wall-clock timeout, and 900 ms Dart timeout
   (`docs/acceptance/cap18-18.5-notes.md` scrub-release section). End-cap /
   preview tolerance changes do not alter release seek quantizer or timeout
   policy.

6. **Mid-path preview tolerance: infinite → exact (zero).** For all preview
   requests in range (`position ≤ asset duration + slack`), Host now uses exact
   (zero) tolerance — not only end-cap. **Reason:** under infinite tolerance,
   sparse-GOP local videos snapped `actualSeconds` to distant I-frames; with
   Option B (item 7) this produced high-frequency `driftReject` and solid
   placeholder that never cleared while holding the same second. Device
   DiagnosticBenchmark (removed before `b2ceabd` commit) on five assets (22
   zero-tolerance probe shots): **0 failures**; `actual` aligned to requested
   second; Host isolated latency mostly 14–388 ms (see acceptance notes).
   Past-duration requests remain infinite (item 2).

7. **Option B retained (complementary, not replaced).** Host returns
   `ScrubPreviewFrameDto.actualSeconds`; Dart rejects when
   `|requested − actual| > 1.0s` (inclusive of exactly one bucket step),
   equivalent to Host nil (`forbidBorrow`, not written to `lastSuccessful`).
   Mid-path zero tolerance **reduces** drift-reject frequency because `actual`
   usually matches the request; Option B remains the safety net against rare
   misaligned frames. **Do not revert** to displaying infinite-tolerance
   misaligned JPEGs without drift gate — that was the original defect this
   pipeline fixes.

8. **Occasional >350 ms preview latency (accepted acceptance expectation).**
   Zero-tolerance decode can exceed the 350 ms §2.1 borrow wall-clock window
   on some assets/positions (Benchmark max **388 ms** on one probe). Product
   behaviour: brief solid placeholder (or bounded borrow when eligible), then
   the correct JPEG once Host completes — **not** permanent black while
   holding. Kafka Profile hold test (2026-08-31): zero-tolerance build,
   `driftReject = 0`; user confirmed real frame appears after brief wait.
   This is distinct from the pre-`b2ceabd` drift-reject stall class.

**Cap 19.2b Decision 13 narrow supplement — scrub drag keep-playing
(2026-09-01; work `96d5ead`; device i17 Green Profile PASS):**

1. **Drag-begin mechanical pause removed.** Cap 18.5 Decision 13 supplement
   item 3 required a mechanical pause for the duration of scrub drag. Cap
   19.2b deletes `PlaybackCoordinator.onUserScrubBegin` and the Main Browse
   feed wiring (scheme A; **no** no-op stub). While the finger is down on
   the scrubber, the main picture follows existing `userIntentWantsPlay` /
   `effectiveShouldPlay` — no Manual-intent mutation. Release path is
   unchanged: whole-second `seek`, clear stale `pendingNavigationActivation`,
   then `playFromCurrentPosition()` when effective.

2. **Product rationale.** Cap 18.5’s drag-freeze was a misread of
   Video-App-B–class keep-playing scrub UX. 19.2b corrects that product
   behaviour; it does **not** reopen Cap 18 PHASE_HISTORY.

3. **Out of scope for this supplement.** Scrub preview bubble, Host
   `requestScrubPreviewFrame`, and the Cap 18.5 dual quantizers (preview
   mid-path **floor** bucket vs label/release **round** seek) are unchanged
   here. Any later alignment of those quantizers is a separate phase — not a
   19.2b regression. (19.2b made the floor/round mismatch easier to see
   because the main picture keeps moving during drag; it did not introduce
   the mismatch.)

**Cap 19.2c Decision 13 narrow supplement — scrub preview/seek quantizer
align (2026-09-01; work `0ef9ef2`; device i17 Green Profile PASS):**

1. **Discovery path.** Cap 18.5 shipped mid-path preview request keys via
   floor buckets while label + release seek used `scrubberSeekSeconds`
   (round). Cap 19.2b keep-playing made that dual-quantizer seam easy to
   see during drag; **19.2b did not introduce the seam** — 19.2c closes it.

2. **Mid-path coupling invariant.** Non-end-cap `scrubPreviewRequestSeconds`
   must go through `scrubberSeekSeconds` (round). Do **not** reintroduce a
   parallel floor (or other) quantizer for mid-path preview keys. Changing
   label, release seek, or preview request quantization requires reviewing
   the other two in the **same** diff.

3. **Intentional exceptions.** End-cap and integer-duration EOS-safe paths
   still request `duration − ε` so Host is not asked for exact EOS. Those
   preview keys may differ from the release seek second by design.

4. **Direction detect.** Scrub borrow reverse detection follows whole-second
   **request keys** (same mid-path round path), not a separate floor bucket.
   Dead `scrubPreviewBucketSeconds` was removed.

**Cap 19.2d Decision 13 narrow supplement — seek-hold + live playhead ghost
(2026-09-01; work `7637812`; device i17 Green Profile PASS):**

1. **Optimistic landing + seek-hold.** On committed scrub release, Dart writes
   the seek second into `_positionSeconds` in the same `setState` that clears
   `_dragging`, then ignores Host observe ticks until they settle near the
   hold (or a ~1.2s hold window expires). Prevents the fill from flashing
   back to the pre-seek playhead while AVPlayer seek is still in flight.

2. **Live ghost while dragging.** Track stack is track →
   `scrubProgressLiveGhost` → primary played fill. Ghost follows live
   runtime playhead; primary follows the finger. Token
   `scrubProgressLiveGhost` started at ~30% white (`0x4DFFFFFF`); i17 Green
   Profile smoke confirmed the starting value (retune later only if product
   asks).

3. **Cancel path.** Uncommitted / cancel release does **not** write an
   optimistic seek second. With mid-drag runtime collection, cancel follows
   the latest live observe; residual catch-up of about one Host observe tick
   (~250ms) is **accepted** and is **not** a zero-jump guarantee.

4. **Dependency.** Ghost UX assumes Cap 19.2b keep-playing during drag; does
   not reopen Cap 18 PHASE_HISTORY.

**Cap 19 Decision 20 supplement — magnified still vs left-swipe
(2026-09-01; docs `372175c`; with ADR-041):**

1. **Gap closed.** ADR-040 Decision 2 / 16 freeze magnified-still
   single-finger drag as **pan only** (no vertical PageView). Decision 18
   freezes left-swipe add-to-album. Cap 18 never wrote the cross-rule
   between item 6 (pinch) and item 8 (left-swipe). Cap 19 supplies it.

2. **Rule.** While the **current still** is in a **non-fit magnified**
   state, the Cap 19 left-swipe recognizer **does not arm / does not
   fire**. Single-finger drag remains pan (Decision 2 / 16). Fit restore
   re-enables left-swipe arming per D2=B (ADR-041).

3. **Video.** Non-persistent video pinch (Decision 16) does **not** arm
   this guard (no lasting non-fit still state).

4. **Ownership.** Cap 19 ships the guard + a read-only magnification
   signal stub for tests. Cap 20 wires real pinch magnification state
   into that signal. No Cap 18 reopen.

5. **Out of scope.** Does not claim interactive-pop / system-back vs
   left-swipe is solved (device gate at 19.6 / 19.8).

---

## ADR-041: Cap 19 §5 product lock — left-swipe range (D2) and Limited policy (D3)

- Status: Accepted (2026-09-01)
- Commit/PR anchor: `372175c`
- Plain summary (owner reads this): Cap 19 locks full-width left-swipe to
  the fixed WakeTok album under both Full and Limited access; Limited
  panel Add-to-Album stays Full-Access-only. Does not claim system
  back-gesture conflict is fixed.
- Context / what problem forced this:
  Cap 19 §5 had D1 (WakeTok album bootstrap) and D4 (Limited half-sheet
  row) locked 2026-08-31. D2 (swipe hit region) and D3 (Limited
  left-swipe vs kickoff ADR-K) waited on the 19.2a PhotoKit spike. Spike
  SPIKE COMPLETE on Kafka (`3f7a8e4`,
  `docs/acceptance/cap19-19.2a-notes.md`): L-BOOT, L-APPEND, L-BOOT-KV,
  and optional Full D1 all PASS. Owner locked D2=B and D3=B on
  2026-09-01.
- Decision (what was chosen):
  1. **D2 = B — full media width.** Left-swipe recognizer arms across the
     media area (not a left-edge strip only). Arbitration with future 2×
     edge-hold reuses Cap 18 / ADR-040 Decision 2 early-motion threshold
     (early horizontal displacement → swipe; stationary hold →
     edge-hold). No new arbitration rule for D2.
  2. **D3 = B — supersede kickoff ADR-K for the left-swipe line only.**
     Under Limited, left-swipe append to the fixed WakeTok album is
     enabled the same as Full Access (KV-known or create-only album id;
     `addAssetToAlbum`). This does **not** authorize Limited
     `listAssetSources` find / User Album enumerate (ADR-021 / ADR-K
     list red line unchanged).
  3. **D4 unchanged.** Limited half-sheet Add-to-Album row remains a
     non-interactive Full Access requirement row — no picker, no album
     list. Left-swipe and panel row are independent entries; intentional
     asymmetry is accepted.
  4. **Supersedes ADR-040 Decision 18 Limited deferral only.** Decision
     18’s product slot (left-swipe → fixed WakeTok album; Settings
     preference; edge-hold arbitration) stands. The Cap 18 clause that
     forbade locking Limited behaviour is superseded by this ADR’s
     Decision item 2.
  5. **Interactive-pop / system back** remains an **unverified Cap 19
     device risk** for 19.6 / 19.8 acceptance — D2=B does **not**
     resolve it.
  6. **Debt 445** (duplicate same-title albums; KV + `localIdentifier`
     uniqueness) remains Accepted (permanent); more visible under
     Limited create-only bootstrap — accepted cost of D3=B, not a
     blocker.
- Rejected alternatives (why not B’s opposite):
  - **D2 = A (left-edge strip only):** smaller target; worse for
    left-handed use; still sits on the same edge as future 2× hold and
    system interactive-pop — does not remove those conflicts, only
    shrinks the useful swipe region.
  - **D3 = A (strict ADR-K force-off under Limited):** after 19.2a proved
    Limited create + append on a known WakeTok album id without list
    find, force-off would discard a working path that does not violate
    the enumerate/list-find red line. Panel (D4) already carries the
    Full Access upgrade cue for album *picking*.
- Consequences:
  - 19.6 may implement full-width left-swipe for Full and Limited per
    D3=B.
  - ADR-040 Decision 20 (magnified still vs left-swipe) ships in the
    same docs batch; Cap 20 still wires real pinch state.
  - Formal ADR-K “no Limited album features” reading is **narrowly**
    superseded for **left-swipe → fixed WakeTok album only**; panel
    enumerate path stays ADR-K / D4.

---

## ADR-042: Cap 19 current-asset actionable signal (Browse mutation entries)

- Status: Accepted (2026-09-04); Decision 8 narrow supplement Accepted
  (2026-09-04, work `17ec5a1`)
- Commit/PR anchor: `a13adfa` (Decisions 1–7); Decision 8 work `17ec5a1`
- Plain summary (owner reads this): Browse actions that need a real current
  photo/video (add to album, Favorites, left-swipe, and later share) all ask
  one shared “is the current item determined?” flag — they must not invent
  their own checks or reuse the scrubber’s “ready to play” freeze. Trailing
  mutation chrome also hides fully while the vertical feed is peeking or
  under PV transition cover (Decision 8).
- Context / what problem forced this:
  Cap 19.8 device diagnosis (Kafka Profile): the bottom-trailing Add-to-Album
  entry was mounted whenever Browse was selected, ignoring whether
  `browseSessionProvider` had a determinate current asset. Opening the panel
  or mutating while `mainBrowseCurrentAssetIdProvider` was null produced
  generic failure copy (“Couldn't add… Try again.”) that reads like network
  or permission failure. Left-swipe guide checked asset id for coach display,
  but arming did not share one actionability predicate with the entry icon —
  inconsistent gates. Future share chrome will need the same gate. This is a
  **data-availability / mutation-entry** concern, orthogonal to ADR-040
  gesture arbitration and entry *slot geometry*, and to scrubber L2-ready
  freeze (ADR-040 Decision 13).
- Decision (what was chosen):
  1. **Canonical signal:** `mainBrowseCurrentAssetActionableProvider` in
     `lib/features/main_browse/main_browse_providers.dart` — `true` iff
     `mainBrowseCurrentAssetIdProvider` is non-null and non-empty. This is
     the sole **actionability** signal for current-asset mutation entries.
  2. **Required consumers (gate / arm / enable):** Cap 19 entry icon (and
     future share control), left-swipe arming (`leftSwipeArmingAllowed` /
     `cap19LeftSwipeArmingProvider`). New current-asset mutation chrome must
     `watch`/`read` this provider — do **not** invent a parallel null check
     for “may the user engage this entry?”, and do **not** reuse
     `scrubberFrozen` or other playback-ready predicates.
  3. **Id for mutations:** Controllers that need the asset string still read
     `mainBrowseCurrentAssetIdProvider`. Null remains a defensive last line
     (extreme timing); it must not be the primary UI enable path.
  4. **Not-ready vs real failure copy:** When the defensive null path fires,
     surface `cap19CurrentMediaNotReady` (“Media isn't ready yet.” /
     「媒体尚未就绪。」) — not generic operation-failure toasts. No
     “Try again” for not-ready (retry is meaningless until an asset exists).
  5. **Favorites state machine:** `Cap19FavoritesPhase.mediaNotReady` is
     distinct from `loadError` (Host/status failure). Do not overload
     `loadError` with not-ready semantics.
  6. **Album list orthogonality:** `listAssetSources` / picker list load does
     **not** depend on current asset id and must not be forced through the
     actionable gate. Append-to-album row taps still use not-ready vs failed
     outcomes when id is missing.
  7. **Entry chrome when not actionable:** Keep the icon visible at the
     shell-fixed slot; disable with reduced opacity
     (`kCap19EntryIconDisabledOpacity`); do not hide (avoids flicker on brief
     session loading). Instant opacity switch — no AnimatedOpacity.
  8. **Trailing mutation chrome settle visibility (narrow supplement):**
     Trailing current-asset mutation chrome on Browse (Cap 19 entry icon;
     future share; **same slot family**) is interaction-ready only when all
     of: (1) `mainBrowseCurrentAssetActionableProvider` is true, (2) vertical
     feed is settled (`mainBrowseVerticalFeedSettledProvider`; same
     peek/settle epsilon discipline as Cap 18.5 scrubber), (3) current asset
     is not under PV transition cover
     (`!pvTransitionGuard.isCovering(currentId)`). Pure predicate:
     `mainBrowseTrailingMutationChromeVisible` in
     `main_browse_trailing_chrome_policy.dart` (not `scrubber_policy.dart`).
     While peeking or covering: **fully hidden** (not opacity-disabled).
     Decision 7 still owns only the not-actionable axis (slot visible +
     reduced opacity; do not hide). Do not gate this chrome on
     `scrubberFrozen` / L2-ready. Feed publishes settle via Riverpod; shell
     must not read `VerticalMediaFeedState` private fields. Covering is
     derived from existing `pvTransitionGuardProvider`, not a duplicate
     provider.
- Rejected alternatives (why not):
  - **Gate with `scrubberFrozen` / L2-ready:** Wrong product axis — still /
    Live / not-yet-ready video must still allow Favorites and add-to-album;
    “can play” ≠ “current asset identity is known.”
  - **Per-entry ad-hoc `assetId == null` for enablement:** Causes gate drift
    (observed: guide vs arm vs icon). Actionability belongs in one provider.
  - **Hide entry icon when not actionable:** Conflicts with Cap 19.4
    shell-fixed slot / no jump on short loading; prefer disabled opacity.
  - **Defer / two-phase half-sheet enter as the “fix” for related polish:**
    Separate Cap 19.8 debt **447** (enter animation); out of scope for this
    ADR. Actionable gating does not claim to solve enter hitch.
  - **Fold this into ADR-040:** ADR-040 owns gesture arbitration and frozen
    chrome slots; current-asset actionability is Browse data readiness for
    mutations — keep a separate ADR (same boundary discipline as ADR-041
    vs stuffing D1 into ADR-040).
  - **New ADR for peek/settle chrome visibility:** Rejected — same
    “when may trailing mutation chrome engage?” concern as Decisions 1–7;
    Decision 8 is a narrow supplement.
  - **Dim (Decision 7 opacity) while peeking or covering:** Rejected —
    wrong axis; peek/cover must fully hide (scrubber mid-swipe chrome
    precedent), not look like not-actionable.
  - **Omit `transitionCovering` from the settle gate:** Rejected — after
    page settle, PV cover can still show an unclean handoff; mutation chrome
    must wait for the same clean window as scrubber chrome.
  - **Put `mainBrowseTrailingMutationChromeVisible` in
    `scrubber_policy.dart`:** Rejected — trailing mutation slot family is
    not scrubber-specific; keep
    `main_browse_trailing_chrome_policy.dart` for discoverability.
- Consequences / constraints accepted:
  - Share and any later current-asset mutation entry must reuse
    `mainBrowseCurrentAssetActionableProvider` **and** Decision 8 settle /
    cover visibility (same slot family).
  - Generic failure ARB keys stay for true Host/PhotoKit failures only.
  - Vertical page changes do not null the id between valid indices; brief
    not-actionable windows are expected on session loading / empty / error
    (and rare clamp races), showing as disabled opacity — accepted.
  - Implementing Cap 19.8 work commit anchors Accepted (`a13adfa`,
    2026-09-04). Decision 8 work `17ec5a1` (2026-09-04); Kafka device PASS
    for peek hide / no early show under covering / restore when settled.

---

## ADR-043: Cap 20 Display Magnification (pinch) contract

- Status: Accepted (2026-09-04); Decision 11 “no new Pigeon / no Host zoom
  API” clause narrowly revised by Decision 13 (same date); Decision 13
  further narrowly supplemented by inner-content transform (`282009e`,
  2026-09-04); Decision 3 / D7 narrowly supplemented by double-tap-to-exit
  (`66fc463`, 2026-09-05); Decision 5 max-scale numeric lock **4×**
  (`bc15517`, 2026-09-05)
- Commit/PR anchor: `ae9cb7e` (Cap 20.2 first implementing work);
  Decision 13 work `ca3b4ed`; Decision 14 / Cap 20.4 product `32d149f`;
  Decision 13 inner-content supplement `282009e`; Decision 3 / D7 exit
  double-tap `66fc463`; Decision 5 **4×** lock `bc15517`
- Plain summary (owner reads this):
  Cap 20 ships lightweight pinch on Main Browse. **Layer-2** photo /
  animated image / Live **static** keep zoom until fit, with Reset while
  magnified; Cap 20.5b also exits that persistent still via double-tap
  (enter-by-double-tap stays Out). **All Layer-1** surfaces (photo
  preview, Live static preview, video poster) and **video Layer-2** use
  **transient** pinch (release→fit, no Reset). Session UI state only (no
  SQLite). Video L2 visual scale uses one narrow Host method
  `PlaybackApi.setDisplayMagnification` on the Platform View **inner
  magnification content** (outer embedding root stays identity —
  Decision 13 / `282009e`) only when native push is armed — not a general
  zoom API. Aligns with iOS Photos only for Cap 20’s implemented set;
  sole known delta is a fixed max scale.
- Context / what problem forced this:
  ADR-040 Decision 16 reserved pinch rules; Cap 19 Decision 20 shipped a
  read-only magnification stub and left-swipe arming guard. Cap 20 must
  freeze state machine, chrome layout, Live motion-window policy, and
  clear triggers before wiring product code. Live static rendering already
  uses `Image.file` after Q7 unload (`_liveMotionMounted == false`);
  `PHLivePhotoView` exists only during the short play-once window — so a
  broad PlatformView scale spike is unnecessary.
- Decision (what was chosen):
  1. **Photos alignment scope.** Within Cap 20’s implemented set — pinch
     zoom-in, magnified pan, clamp-to-fit floor (no smaller-than-fit),
     still persistent zoom, video release→fit — match Photos feel for
     still / animated image / Live static key frame. This is not a claim
     of full Photos viewer parity.
  2. **Known delta (in-scope behaviour, different rule than Photos).**
     **Only:** MVP max scale is a **fixed** multiplier. **Cap 20.6
     (work `bc15517`, 2026-09-05) locked the numeric value at 4×**
     (`kCap20MaxScale = 4.0`). Photos uses a resolution-based cap.
     Document as known delta — not “incomplete Photos alignment.”
  3. **Out of Cap 20 (never promised; not known deltas).** Double-tap
     **to enter** zoom; smaller-than-fit shrink state; Live native
     in-view zoom / Transform on `PHLivePhotoView`; Photos-style
     long-press Live replay (debt **439** / ADR-040 Decision 17 owning
     Cap TBD); debt **448** interactive-pop vs left-swipe.
     **Decision 3 / D7 narrow supplement (2026-09-05, work `66fc463`):**
     Cap 20.5b adds double-tap **to exit** persistent still /
     Live-static Layer-2 magnification only
     (`MagnificationHostMode.still` + magnified). Action is the same
     `forceFit()` path as Reset (no separate animation). Video /
     transient Host modes are untouched. Fit-state double-tap remains a
     no-op (does **not** enter magnification — D7 enter stays Out).
     Implementation is a hand-written pointer state machine on the
     existing `MagnificationPointerHost` `Listener` — **no**
     `GestureDetector.onDoubleTap` / `DoubleTapGestureRecognizer`
     (avoids ~300ms tap disambiguation delaying single-finger pan).
     Timing / geometry: first tap-up → second tap-down ≤350ms; two
     downs within ≤24px; max press ≤500ms; move beyond ~18px or ≥2
     fingers cancels the candidate. Pending first-tap candidate also
     clears on `browseMagnificationProvider` `hasActiveMagnification`
     falling edge (covers Reset / leave-current / Cap 19 panel /
     Live rising-edge forceFit — one clear point, not per-trigger
     forks). Reset vs Host double-tap relies on hit-test layering
     (Reset chrome above Host); Host does not re-filter Reset bounds.
     **Kickoff long-press album entry is not a live conflict:** MVP
     kickoff “long-press media (non-chrome) → album panel” was
     **replaced** by Cap 19 / ADR-040 Decision 15 (fixed bottom-trailing
     icon → half-sheet via `cap19_entry_icon` /
     `cap19_actions_half_sheet`). Verification for Cap 20.5b: `lib/`
     has **zero** `onLongPress` / `LongPressGestureRecognizer` usages;
     album entry does not share this Host pointer stream. ADR-040
     Decision 17 keeps Photos-style Live long-press replay Out (gesture
     slot unused). Therefore Cap 20.5b does **not** add a long-press
     exclusion branch in the double-tap state machine — do not re-derive
     “live long-press” from kickoff text alone.
  4. **D1 — Live Photo.** Static Live on **Layer-2** (`FeedDisplayLayer.full`,
     `!_liveMotionMounted`, `Image.file`, `PlaybackMediaKind.livePhoto`)
     uses the **persistent still** path + Reset. **Layer-1** Live preview
     is **transient** (Decision 14). While `_liveMotionMounted == true`:
     do **not** arm or accept new pinch; on rising edge of
     `_liveMotionMounted`, **force fit** if currently magnified. No
     `Transform` on `PHLivePhotoView`. No throwaway PV scale spike.
  5. **D2 — Reset chrome (A).** While still magnified, Reset is a small
     control welded bottom-left **above** `MediaInfoOverlay` (Overlay
     stays readable). Independent `Align` + dynamic `bottom` inset
     (option 1 — do not refactor Overlay into a shared Column). Geometry:
     `left: 16`; trailing inset `MediaInfoOverlay.trailingInset`;
     `bottom = mainBrowseMediaOverlayBottomInset(tokens) +
     overlayColumnHeight + 8` where
     `overlayColumnHeight = rowHeight × (baseRowCount + (location?1:0))`.
     Reset mounts only for persistent still magnification (not transient).
     Stack: place Reset as a late `_mediaStack` child (defensive last
     layer). Functionally, Cap 19 left-swipe already
     `SizedBox.shrink()`s when `!armed`, and arming is false while
     magnified once the real signal replaces the stub — z-order is
     hygiene against edge-frame races, not a hit-test hard requirement.
  6. **D3 — Transient mid-pinch.** While ≥2 fingers are down on a
     **transient** pinch (video L1/L2 or photo/Live L1), temporarily lock
     vertical `PageView`; unlock after release→fit (or when contact ends).
     Playback **continues** (no mechanical pause; do not mutate
     `userIntentWantsPlay`).
  7. **D4 — Clear magnification.** Force fit / discard transform when:
     (a) current item is no longer current; (b) leave Browse / Session
     ends; (c) Reset or reverse-pinch reaches fit; (d) Cap 19 actions
     half-sheet opens (`cap19ActionsPanelOpenProvider` → true). Do **not**
     bind clearing only to vertical settle on a neighbour page.
  8. **D5 — Max scale.** Fixed multiplier for MVP. **Cap 20.6 lock
     (work `bc15517`, Accepted date 2026-09-05 from
     `git log -1 --format=%cs bc15517`):** numeric value is **4×**
     (`kCap20MaxScale = 4.0`; regression `T-20.6-1`). Sole Photos known
     delta (Decision 2) — **4× remains the sole known delta vs iOS
     Photos** (fixed multiplier vs Photos’ resolution-based cap). The
     prior “3× vs 4× deferred to soak” clause is closed by this lock —
     do not re-open that binary pick without a new owner pass.
     **Future optimization (recorded, not scheduled):** Owner judges
     fixed 4× less “satisfying” than Photos’ resolution-floating upper
     bound, but **acceptable for Cap 20**. A one-time cross-check against
     **Photo-App-A** (peer product with a similar fixed ~4× ceiling)
     supported reasonableness only — **not** an ongoing competitor-parity
     commitment. If product later needs to raise the ceiling or switch to
     a resolution-related cap (closer to native Photos), that requires a
     **new owner pass** and is **out of Cap 20** — distinct from re-opening
     the closed 3×-vs-4× soak pick.
  9. **D6 — ADR shape.** New ADR-043; ADR-040 Decision 16 text unchanged;
     this ADR cites Decision 16 / Decision 20.
  10. **Cap 19 inheritance.** Replace
      `cap19StillMagnificationStubProvider` with a real
      `isCurrentStillMagnified` signal consumed by
      `leftSwipeArmingAllowed` / Decision 20. No Cap 18 reopen.
  11. **Persistence / Data Contract.** Session-scoped runtime UI state
      only. No SQLite table, no new Pigeon method, no Host zoom API.
      **Narrowly revised by Decision 13:** the “no new Pigeon / no Host
      zoom API” clause no longer forbids the single method named there.
      SQLite ban and “no general zoom API” remain. Do not read Decision 11
      as authorizing further Pigeon without a new owner-approved decision.
  12. **Animated images.** No separate feed kind; `FeedPageMediaKind.still`
      — same persistent still rules (Layer-2; see Decision 14 for L1).
  13. **`setDisplayMagnification` (Decision 11 narrow revise + Q3 revise).**
      Cap 20.4 Q3 originally locked MVP video pinch to Flutter `Transform`
      over UiKitView, with an escape hatch: if Kafka showed the native
      surface did not follow scale, **stop and re-discuss** (temporary
      degrade or a **narrow** Host API). On Kafka, UiKitView **did not**
      follow Flutter `Transform`. An interim **poster overlay** during
      pinch looked like “L2 became L1” and was rejected. A first native
      attempt mutated `AVPlayerLayer` anchorPoint / bounds /
      affineTransform each frame; that fought
      `PlaybackSurfaceContainer.layoutSubviews`
      (`playerLayer.frame = bounds`) → **no visible zoom + shell jitter**.
      Converged to: apply scale/translation only on the Platform View
      **container** `UIView.transform` (center anchor); identity restores
      fit. **Process note:** implementing this Host method before an
      explicit owner Decision-11 revise violated the Q3 “stop and
      re-discuss” gate; recorded so Cap escape hatches are not
      self-approved again.
      **Chosen:** Exactly one new Host method on existing `PlaybackApi`:
      `setDisplayMagnification(scale, translationX, translationY)`.
      Applies **only** to the bound video L2 Platform View **container**
      `UIView.transform`. Does **not** pause playback (D3). No-op with no
      surface. Identity ≈ `(1, 0, 0)`. **No** new `FlutterApi` callback.
      Native push is gated independently of
      `MagnificationHostMode.transient` (photo/Live L1 are also transient
      but must not drive the player). **Not a precedent** for adding
      further Pigeon/Host zoom APIs (Live 20.5, other gestures, or a
      general `setZoom`). Any future Host pinch API requires a **new**
      owner-approved decision after hitting a documented stop-and-re-discuss
      gate. Work `ca3b4ed`.
      **Decision 13 narrow supplement (2026-09-04, work `282009e`):**
      Same Host method / no new Pigeon. Transform must **not** apply to
      the Flutter embedding–owned **outer** `PlaybackSurfaceContainer`
      (`transform` stays identity). Scale/translation apply only to an
      **inner** `magnificationContent` UIView; outer `layoutSubviews`
      syncs that child via `bounds` + `center` (never assign `frame` to
      a non-identity child). Root cause: `FlutterPlatformViewsController
      compositeView` `setFrame` while outer transform ≠ identity folds
      scale into `bounds` → permanent shrink after identity restore.
      Read the original Chosen phrase “Platform View **container**
      `UIView.transform`” as the **inner magnification content view**
      under the Platform View root — **not** the embedding root outer.
  14. **Layer-1 unified transient / Layer-2 still persistent.** All
      Layer-1 surfaces (photo preview, Live static preview, video poster)
      use `MagnificationHostMode.transient`: release→fit, no Reset. L1 is
      degraded recall/preview, not detail inspection; persistent L1 zoom
      adds Reset/PageView-lock cost without product value. **Persistence +
      Reset** only for photo / Live-static **Layer-2**
      (`FeedDisplayLayer.full` still via `usesPersistentMagnification`).
      **Video Layer-2** remains transient (visual scale via Decision 13
      when native push armed). Policy is keyed by **display layer**, not
      media kind alone. Same-page L1→L2 promote (`transient`→`still`)
      forceFits to identity and **re-baselines** pinch from the current
      finger span **without** clearing the pointer map (T-20.4-12).
      Work `32d149f`.
- Rejected alternatives (why not):
  - **Broad Live `PHLivePhotoView` Transform spike before D1:** Rejected —
    static Live already shares the still `Image.file` path; PV is a ~1–2s
    motion window only.
  - **Keep magnified transform during `_liveMotionMounted` without new
    pinch:** Rejected — PV replaces the scaled still visually; keeping
    latent scale under an unscaled PV is inconsistent; force fit on
    rising edge.
  - **D2-B hide/dim Overlay while magnified:** Rejected for MVP — inspect
    mode should keep metadata readable (owner lock A).
  - **D2-C move Reset off bottom-left:** Rejected — product lock.
  - **ADR-040 Decision 16 narrow supplement only:** Rejected — state
    machine + chrome + Live gate + clears need a Cap-owned ADR (same
    pattern as ADR-041/042).
  - **Pause video for mid-pinch:** Rejected — inspect should not fight
    Cap 18 dual-signal intent.
  - **Clear zoom only on PageView settle to neighbour:** Rejected — too
    narrow vs leave current / leave Browse / sheet / Reset paths.
  - **Pure Flutter `Transform` on UiKitView for video L2:** Rejected —
    failed on Kafka (surface ignores Transform).
  - **Pinch-time poster overlay as L2 visual:** Rejected — looks like L1;
    hides live playback.
  - **Per-frame `AVPlayerLayer` anchor/bounds mutation:** Rejected —
    fights `layoutSubviews`; jitter / no zoom.
  - **Broad Host zoom API / new Pigeon interface:** Rejected — must stay
    one method, one surface (Decision 13).
  - **Persistent pinch on photo Layer-1:** Rejected — recall ≠ detail;
    fights L1 unify (Decision 14).
  - **Clearing pointer map on L1→L2 mode handoff:** Rejected — dead
    gesture until lift.
  - **Keying native mag push off `MagnificationHostMode.transient` alone:**
    Rejected — Decision 13 gate.
  - **Revisit (Transform / embedding):** If Flutter Platform View
    composition changes materially (e.g. post-Impeller embedding path),
    **re-verify** whether Flutter `Transform` can drive the video surface
    before adding any further Host API — do not treat the Transform /
    playerLayer Rejected block as permanently forbidding a Transform-only
    revisit.
- Consequences / constraints accepted:
  - Cap 20.2+ product code waits on this freeze; Accepted date from
    `git log -1 --format=%cs ae9cb7e` (2026-09-04).
  - ADR-028 Fit (presentation mode) remains the Browse default; Cap 20
    “fit” means magnification scale floor 1×, not Display Mode Fill/Crop.
  - ADR-040 Decision 16 / Decision 20 remain binding; this ADR implements
    them.
  - GLOSSARY adds Display Magnification / pinch / Reset; do not conflate
    with ADR-028 Fit.
  - Decision 13 is the **only** Cap 20 exception to Decision 11’s Pigeon
    ban; it is not a template for later Caps.
  - Escape-hatch “stop and re-discuss” = message owner and wait before
    code; **project-wide** collaboration rule (mirrored in
    `.cursor/rules/00-workflow-gates.mdc` Stop conditions).
  - **`setDisplayMagnification` has no throttle/debounce:** each armed
    matrix publish crosses the platform channel on pointer moves. Kafka
    Profile smoke (performance-floor device) showed no material hitch; if
    the device matrix grows or a regression appears, re-evaluate
    coalescing/throttling — treat current behavior as a verified choice,
    not an unexplained bug.
  - **Cap 20.5 (work `114f393`):** Live motion Host `mode == none` ignore
    + rising-edge forceFit via `hasActiveMagnification` are **coverage /
    Host harness**, not a new product gate (D1 path already 20.2–20.4).
    Feed mounts motion with `setMode(none)` then
    `onLiveMotionMountedChanged(true)` in one try block — **convention,
    not a generation-gated invariant**. Rising-edge notifier forceFit is
    the safety net if that order is later broken; T-20.5-4 guards it.
  - **L1/L2 still cover continuity (acceptance):** any Cap that changes
    Layer-1/Layer-2 handoff or still cover tree must device-verify on
    **local downloaded** assets so network latency cannot mask render
    flashes (Cap 20.4 Kafka iCloud blind spot). Automate with Image
    State identity tests (`W-15.5a` + leave demote).
  - **Still black-flash fix (work `3d29823`):** single
    `MagnificationHostModeBinder` on the still cover tree. Regression
    guards: `W-15.5a` (enter) + leave demote in
    `test/features/main_browse/still_image_element_continuity_test.dart`
    (and feed `W-15.5a`). Debt **450** Closed.
  - **Video shrink + release spike (work `282009e`):** Decision 13
    inner-content transform (mechanism C) + Dart
    `_silenceReleaseControllerToZero` (mechanism A). Device: Kafka C and
    A verified **separately**. Regression guard for A:
    **`T-20.A-1`** in `cap20_video_magnification_test.dart` — after the
    release peak, once a `setDisplayMagnification` scale is ≤1.02, no
    later call may exceed 1.02. Notes:
    `docs/acceptance/cap20-post-20.5-blackflash-shrink-notes.md`.
  - **Cap 20.5b (work `66fc463`):** Decision 3 / D7 narrow supplement —
    double-tap **exit** for persistent still only; enter stays Out.
    Device: Kafka Profile still double-tap exit + Reset + video
    unchanged PASS. Notes: `docs/acceptance/cap20-20.5b-notes.md`.
    Widget: `T-20.5b-1…8` in `cap20_still_magnification_test.dart`
    (incl. candidate clear on forceFit with fake clock still inside
    the 350ms window — `T-20.5b-8`).
  - **Cap 20.6 (work `bc15517` + soak docs):** Decision 5 numeric lock
    **4×**; Q2-A soak PASS (keep Q2-A, no Q2-B); Cap 17.6 **B.1**
    mixed-pool fast-swipe PASS (Kafka primary, i17 short retest);
    continuity gates treated green on current `main` without a ritual
    re-run. Notes: `docs/acceptance/cap20-20.6-notes.md`. Debt **451**
    Closed (letterbox-shell `W-14.6c` assert); debt **452** Open
    (missing/degenerate pixel dims → viewport-sized fill stretch).
    Live AppLifecycle unload (debt **453**) is Cap 9 / ADR-019 — not
    an ADR-043 decision; recorded in STATE only.

---

## ADR-044: Cap 21 Build a Pool — BrowseChromeState, ephemeral park, four-control chrome

- Status: Accepted (2026-09-05)
- Commit/PR anchor: a695d2f
- Plain summary (owner reads this):
  Cap 21 lets you build a temporary multi-source Pool and browse it from a
  four-control top bar: a “Temp Pool” chip when one is parked, built-in
  All/Photos/Videos, a Saved-pools control (empty shell this Cap), and
  Create. The app remembers at most one parked temp Pool so you can leave
  it for All and tap back. Saving named Pools to disk is the next
  capability. Deleted Photos items get honest load-fail copy, not a fake
  “allow wireless data” message.
- Context / what problem forced this:
  Cap 10–13 delivered Source Pool Definition, resolvePool, Identity
  Coalescing, Session Queue, and Endless Shuffle, but Main Browse still
  drives sessions from a single `SourceReference`
  (`mainBrowseSelectedSourceProvider`) and explicitly rejects Pools as a
  `SourceReference`. Kickoff’s product path uses a fourth “Pools” cell
  opening a Pool Picker Sheet; Cap 7–20 ship that cell as disabled Coming
  soon. Cap 21 must: (1) wire ephemeral multi-source Definitions into
  Browse without Saved SQLite (next Capability Roadmap row); (2) replace
  the Sheet-centric entry with a chrome that separates “parked temp
  composition” from “Saved preset library”; (3) preserve ADR-027 Leave
  Browse semantics (restart on current selection, not fall back to All);
  (4) pay debt **444** without violating ADR-023 D7 / kickoff ADR-I Queue
  Stability. A single `activeOrigin` value cannot express “browsing All
  while a temp Pool chip remains tappable,” so chrome state needs a
  parked Definition field.
- Decision (what was chosen):
  1. **D1 — Save UI boundary.** Cap 21 implements only kickoff “create
     pool” flow A’s **No** branch: select sources → reorder → **Start
     Browsing** as ephemeral. Naming + persist Saved Pool Preset is Cap
     22. Cap 21 may show **visible disabled gray rows** in the Saved
     dropdown (“Save current pool”, “Manage pools”, empty Saved) matching
     Cap 7 `_PoolsCell` / Coming soon language — no save dialog, no disk
     write. No Drift/SQLite/`LocalRepository.savePool` in this Cap.
  2. **D2 — Limited Access (confirm ADR-K / ADR-021 Decision 3).** Under
     Limited, `listAssetSources` returns only built-ins; Build a Pool may
     run with All/Photos/Videos only. Do not list Album/Smart rows as
     Unauthorized.
  3. **D3 — debt 444.** On the Main Browse feed Layer-2 failure path
     (`feedFailureReasonFromPlatformCode` and equivalent feed mapping):
     Host/Pigeon `assetUnavailable` must **not** map to wireless/network
     copy; introduce a distinct `FeedFailureReason` + ARB; disable or hide
     useless Retry for that reason. The Session Queue may still retain the
     id (no mid-session Snapshot/Queue rebuild). Soft-skip/tombstone of
     the current item (D3-B) is optional and does not violate ADR-I.
     Installing `PHPhotoLibraryChangeObserver` to mutate the Queue (D3-C)
     is forbidden. **Implementation bound:** remap only the feed display
     failure chain — do **not** globally reinterpret
     `ErrorCode.assetUnavailable` for favorite / add-to-album / empty-id
     guards that reuse the same wire code.
  4. **D4 — Origin identity vs built-in tabs.** A Session started via
     Build→Start is always `activeOrigin = ephemeralPool(...)`, even when
     the Definition holds a single built-in reference. Choosing
     All/Photos/Videos sets `activeOrigin = builtIn(...)` and starts a
     **new** Session (same class of boundary as ADR-023 D8).
  5. **D5 — Partial source failure (confirm ADR-021 Decision 7 /
     Glossary §16).** If the coalesced Snapshot has ≥1 Media Item,
     browsing may start; Empty/Unavailable/Unauthorized sources get
     non-blocking hints. Not a new Cap 21 product fork.
  6. **D6.1 — `BrowseChromeState` (two fields).**
     ```
     BrowseChromeState
     ├── activeOrigin:
     │     builtIn(SourceReference) | ephemeralPool(SourcePoolDefinition)
     │     // drives Consumption Session; changing activeOrigin ⇒ new Session
     └── parkedEphemeralPool: SourcePoolDefinition?
           // remembered temp pool for the left chip; independent of activeOrigin
     ```
     **Invariants:** at most one parked ephemeral; if `activeOrigin` is
     `ephemeralPool(D)` then `parkedEphemeralPool` is non-null and
     identity-equal to that same Definition; `parked` is cleared or
     replaced **only** on process death or successful **Start Browsing**
     of a new ephemeral (replace); switching `activeOrigin` to `builtIn`
     does **not** clear `parked`; opening Build and canceling **without
     Start** leaves `parked` and `activeOrigin` unchanged.
     **Wiring:** `browseSessionProvider` / `restartSession` / feed-index
     reset / L2-ready clear / magnification leave hooks key off
     **`activeOrigin` only**. Chip visibility keys off
     **`parkedEphemeralPool != null`**. `mainBrowseSelectedSourceProvider`
     becomes built-in memory/projection only. Cap 21 does not add
     `savedPool` to `activeOrigin` (Cap 22 may extend via new ADR text).
     **21.2 hard gate — migrate all consumers** (owner-verified complete
     set): (1) `browse_session_providers.dart` `build()` watch +
     `restartSession()` read; (2) `main_browse_providers.dart`
     `MainBrowseFeedIndex` listen; (3) `vertical_media_feed.dart` watch
     (Layer-1 label delay) + listen (magnification clear / leave current);
     (4) `browse_l2_ready_session.dart` listen clears L2-ready map.
  7. **D6.2 — Snapshot cache.** Ephemeral multi-source Snapshots enter
     `browseSnapshotCacheProvider`. Cache key = ordered `SourceReference`
     fingerprint (`kind`+`id` sequence; duplicate refs participate). Do
     **not** key by throwaway `SourcePoolDefinition.id`. Equivalent
     single-ref fingerprints may share entries with built-in tabs.
     Cache only successful non-empty results; empty/hard-fail uncached
     (ADR-024). Leave Browse does not clear the cache (ADR-027).
  8. **D6.3 — Leave Browse.** Preserve full `BrowseChromeState`
     (`activeOrigin` + `parkedEphemeralPool`). `restartSession` opens a
     new Session on the same `activeOrigin` Definition (reshuffle + index
     0). Do **not** fall back to All. Process death drops in-memory chrome
     state (Accepted boundary until SessionCheckpoint Cap).
  9. **D6.4 — Four-control top chrome (supersedes kickoff Sheet path).**
     Product path supersedes kickoff §1.2 / §3.1 “fourth Pools cell →
     Pool Picker Sheet as sole custom entry” (kickoff file remains
     read-only). Layout:
     ```
     [Temp Pool chip]   [Built-in ▾]   [Saved pools ▾]   [Create]
      (if parked≠null)   (screen-centered pair)            (always)
     ```
     - Temp Pool chip: dynamic; fixed short label; tap per Decision 10.
     - Built-in dropdown: All / Photos / Videos only.
     - Saved pools dropdown: Cap 21 empty shell + visible gray
       placeholder rows; Cap 22 wires real Saved data.
     - Create: always; opens Build a Pool Screen.
     **Rationale for four controls:** parked/current temporary
     composition and the Saved preset library are different product
     objects and must not share one control that is both status and
     library. (Rejected non-rationale: “prevent infinite temp tabs” —
     a single `parkedEphemeralPool` already bounds count.)
  10. **D7 — Temp chip, honesty, layout, composition peek.**
      **Chip copy:** fixed short label (e.g. “临时 Pool” / EN ARB in
      21.3). **No** source-name join on the chip. Join-as-default-name
      remains valid **only** for Cap 22 “Save current pool” full-width
      name suggestions (kickoff examples such as `E02 + E03`), not for
      this narrow chip. Multi-source join truncation for that Cap 22
      field may use “first N names + M more” (N chosen in that Cap).
      **Visibility (F1):** show chip iff `parkedEphemeralPool != null`;
      hide when null (no permanent gray empty chip). Runtime absence ≠
      Cap 7 Coming-soon unfinished-feature gray.
      **Tap behavior:**
      1. `parked != null` and `activeOrigin` is built-in → set
         `activeOrigin = ephemeralPool(parked)`, **new Session**.
      2. `parked != null` and `activeOrigin` is already that ephemeral →
         **do not** reshuffle; open a lightweight **read-only
         composition peek** listing display names for parked
         `SourceReference`s via live `listAssetSources()` (Snapshot /
         `SourceResolveStatus` has no `displayName`). Mark unavailable
         sources. Form factor is 21.3; **contract requires the peek**.
         Live list is read-only enumeration — not ADR-023 D7 Queue
         rebuild.
      3. Create → **Start Browsing** success → replace `parked` with the
         new Definition, set `activeOrigin = ephemeralPool(new)`.
      **Built-in collapsed honesty:** when `activeOrigin` is ephemeral,
      the built-in control must not present as the selected browsing
      source (no solid “All selected” lie). Remembering last built-in for
      menu highlight is OK; a11y must match `activeOrigin`.
      **Layout:** (1) Built-in + Saved dropdowns are screen-center
      anchored (notch/Dynamic Island geometric center) and must **not**
      translate when the temp chip appears/disappears — independent
      layers (e.g. `Stack`); chip and Create float separately.
      (2) Chip visibility tracks `parkedEphemeralPool != null`, including
      while `activeOrigin` is built-in.
      **Surfaces:** `WakeTokTokens` + immersive dark (ADR-016 direction);
      no default light `PopupMenu`. Frosted `BackdropFilter` is **not**
      an acceptance gate (debt **447**); prefer opaque/high-opacity
      scrim. Expanded menus absorb taps and block vertical feed drag
      (ADR-040).
  11. **Build a Pool Screen (Cap 21 scope).** Multi-select User Album /
      Smart Album / All / Photos / Videos (Limited: built-ins only). Do
      **not** list Generated Clip Source (types not landed). Reorder =
      Definition reference order (kickoff ADR-M §1). Within-source item
      ordering remains creationDateDescending (ADR-021/022); no new
      Ordering PoC. UI disables further adds at
      `PoolCapacity.maxSourcesPerPool` (30) before factory `ArgumentError`.
      Zero sources ⇒ cannot Start. Start → chrome updates per D6.1/D7 →
      `resolvePool` → existing Default Profile path (no Generated Clip ⇒
      all Mixed ⇒ Shuffle).
  12. **Out of scope.** Saved CRUD / SQLite / enforcing max 10 Saved
      presets; Generated Clip Source / Pure Sequential product path;
      SessionCheckpoint / process-death restore of ephemeral; Query
      Source (POC-02); real Manage / mid-browse Save flows; Photos
      collection-order PoC; Auto-play / Background Audio; observer-driven
      Queue rebuild; Cap 22 rules for `parked` when selecting a Saved
      preset.
  13. **Docs workflow.** This entry is appended **Proposed** (no Accepted
      date, no fake anchor). After the first Cap 21 implementing work
      commit exists, a later docs commit flips Status to Accepted with
      that work sha as anchor and Accepted date from
      `git log -1 --format=%cs <sha>` (two-commit discipline).
- Rejected alternatives (why not B):
  - Cap 21 ships Saved + SQLite (merge Cap 22) — rejected; next roadmap
    row owns persistence; no Drift baseline yet.
  - D3-C Photos observer mutates Queue mid-session — rejected; conflicts
    with ADR-023 D7 / kickoff ADR-I.
  - Three-control chrome with temp status inside the Saved dropdown
    (prior D7(c)) — rejected; conflates parked temp composition with
    Saved library.
  - Chip shows joined source titles — rejected; narrow chrome overflow;
    temp Pool is short-lived; composition peek covers recall.
  - Always-visible disabled temp slot (F2) — rejected; wrong absence
    metaphor; wastes space.
  - Leave Browse clears parked — rejected; breaks D6.3 / return-to-temp.
  - Non-tappable chip — rejected; forces re-Create to return.
  - Single `activeOrigin` without `parkedEphemeralPool` — rejected;
    cannot show chip while browsing All.
  - Tap always starts a new Session while already on that ephemeral —
    rejected; pointless reshuffle; conflicts with composition peek.
  - Cap 21 wires real Saved dropdown data — rejected; breaks D1.
  - Frosted glass as Cap 21.3 acceptance gate — rejected; debt **447**.
  - “Prevent infinite temp tabs” as rationale for four controls —
    rejected as invalid; single parked value already bounds count
    (discussion residue; not a decision basis).
  - Encode Pool as a fake `SourceReference` — rejected; existing code
    forbids it; multi-source Definitions need Origin/chrome state.
  - Cache key = `SourcePoolDefinition.id` — rejected; throwaway ids miss
    forever and grow the map unboundedly.
  - Leave Browse falls back to All — rejected; contradicts ADR-027
    restart-on-current-selection.
- Consequences / constraints accepted:
  - Main Browse session authority moves from `SourceReference`-only to
    **`BrowseChromeState`** (`activeOrigin` + `parkedEphemeralPool`).
  - Kickoff Pool Picker Sheet is superseded as the MVP **primary** custom
    entry path; Saved/Manage/Save-current land via the Saved control in
    Cap 22.
  - Cap 22 may use source-name join only as save-default suggestions in a
    full-width name field — not on the Cap 21 temp chip.
  - Debt **444** is paid on the feed failure-mapping limb in this Cap.
  - Narrow-width chip vs center-anchored dropdown overlap is a **21.3
    layout** risk, not an open Cap 21.1 product fork.
  - Architecture / localization guards remain mandatory on `lib/` work
    (ADR-009/010/012).

## ADR-045: Cap 21.5 pool-path honesty — D5 hint surfaces and partial Snapshot cache

- Status: Accepted (2026-09-07)
- Commit/PR anchor: 80128a3
- Plain summary (owner reads this):
  When some albums in a temp Pool fail but others still have photos,
  WakeTok still lets you browse. Cap 21.5 does **not** push a banner on
  Main Browse for those partial failures. Honesty lives in the temp-chip
  composition peek (and later Cap 22 Saved rows). Non-empty Snapshots may
  be cached even if a source hard-failed; truly empty results stay
  uncached and keep the existing empty auto-retry rules.
- Context / what problem forced this:
  ADR-044 Decision 5 requires non-blocking hints for Empty / Unavailable /
  Unauthorized sources when the coalesced Snapshot still has ≥1 item. An
  early Cap 21.5 attempt used a dismissible Main Browse push banner;
  device soak showed it as noise and competed with feed chrome. Peek
  already lists composition names (ADR-044 D6.4 / D7). Separately, cache
  policy for “partial hard-fail but non-empty coalesced list” needed an
  explicit lock so empty auto-retry (ADR-025 D8) is not confused with
  empty-never-cache (ADR-024).
- Decision (what was chosen):
  1. **D5 presentation surfaces.** Partial-source honesty is **pull-only**
     on Main Browse: composition peek on the parked temp chip (Cap 21),
     plus Cap 22 Saved composition / detail rows later. **Do not** push a
     Main Browse feed banner for partial sources.
  2. **Partial Snapshot cache.** If `coalescedAssetIds` is non-empty,
     the Snapshot **may** enter the browse session cache even when one or
     more sources hard-failed. `_hasHardFailure` (or equivalent) used for
     ADR-025 D8 empty auto-retry remains driven only by empty-result
     paths — do not flip it solely because a non-empty partial resolve
     had a hard-fail limb. Empty Snapshots remain never-cached (ADR-024).
  3. **Peek label honesty (implementation bound of D6.4 peek).** Start
     freezes display labels (`parkedCompositionLabels`). Missing list
     matches never show PhotoKit ids. Suffix vocabulary:
     Requires Full Access (Limited + missing, or unauthorized) vs
     Removed from Photos (Full Access + missing / unavailable); empty or
     available sources show the name only.
  4. **Build catalog freshness (21.5 soak, not a D5 rewrite).** Opening
     Create / Build invalidates `assetSourcesProvider` (and smart catalog
     as needed). Cover thumbnail requests time out to placeholder so a
     stalled cover cannot block the catalog.
  5. **Limited Create.** Under Limited Access, Create is disabled with
     Full Access caption copy (same vocabulary as Cap 19.5b). Extends the
     Cap 21.4b Limited / empty-Build Accepted deviation; does not rewrite
     ADR-044 Decision 2’s built-ins-only Build list rule.
  6. **List lag for Cap 22.** `assetSourcesProvider` does not auto-observe
     Photos library mutations; “album removed” peek honesty appears only
     after an intentional refresh. Cap 22 Saved UIs that reuse the list
     must plan invalidate timing (STATE debt **455**). Session / Queue
     lag remains ADR-027 / ADR-023 D7 — orthogonal.
- Alternatives considered and rejected:
  - Dismissible Main Browse push banner for partial sources — rejected;
    owner soak: chrome noise; D5 “non-blocking” ≠ push interrupt.
  - Treating any source hard-fail as empty-cache / empty-retry path —
    rejected; would discard browsable coalesced content and conflate
    ADR-024 / ADR-025 D8.
  - Showing PhotoKit ids when list match is missing — rejected; breaks
    peek honesty.
  - Claiming Limited + missing album as “deleted” — rejected; Host omits
    albums under Limited; Full Access vocabulary required.
- Consequences / constraints accepted:
  - ADR-044 Decision 5 **product** rule (browse when ≥1 item; non-blocking
    hints) stays; this ADR narrows **where** hints appear.
  - Do not edit ADR-044 Decision 5 body; this entry is the presentation /
    cache lock.
  - Debt **444** (honest feed `assetUnavailable` copy) remains Cap 21.6.
  - Architecture / localization guards remain mandatory on `lib/` work
    (ADR-009/010/012).

---

## ADR-046: Cap 22 Saved Pool persistence — Drift SQLite, save/start decoupling, Saved chrome

- Status: Accepted (2026-09-08); Decision 3 (Build Save/Start decoupling +
  `lastSavedFingerprint`) and Decision 5 (shared surfaces including one
  composition-peek family for temp + Saved Info) are **narrowly superseded
  by ADR-047** (Accepted 2026-09-09, anchor `0b68e01`). Decision 7’s
  “Start-after-matching-Save … clear `parkedEphemeralPool`” clause is
  superseded with Decision 3 under ADR-047 (Promote / Build Save & browse
  remain the clear-park writers). D1–D2, D4 ephemeral peek Save, D6
  menu/unique names, D7 chip occupancy (aside from that clear-park
  clause), D8–D9 remain binding.
- Commit/PR anchor: d62e962
- Plain summary (owner reads this):
  You can save a multi-source Pool recipe under a name, reopen it from
  Saved pools, rename or delete it, and browse it later. Recipes live in
  a local SQLite database (Drift). Names must be unique. Saving never
  starts browsing by itself; Start browsing is the only Build action that
  changes what you are watching.
- Context / what problem forced this:
  Cap 21 delivered ephemeral Build→Start, parked temp chip, composition
  peek, and a gray Saved shell (ADR-044 / ADR-045). Kickoff and GLOSSARY
  §15 require Saved Pool Presets: persist ordered Asset Source references
  + display name (not Snapshots or playheads), enforce max 10 Saved and
  max 30 sources per Definition, reopen/rename/delete, and live re-resolve
  on each new Session. Cap 22 must extend `activeOrigin` with `savedPool`,
  replace the Coming-soon Saved stubs, and close debt **455** (refresh
  `assetSourcesProvider` when opening Saved composition UI). Owner UX
  locks two Save entries (Build before Start; ephemeral peek), shared
  dialogs, chip reuse when Saved is active, no recipe edit in MVP, and
  unique names with validate-and-block (no auto-suffix).
- Decision (what was chosen):
  1. **D1 — Persist what.** Saved Preset = `SourcePoolDefinition` with
     `persistencePolicy: saved`: id, displayName, createdAt/updatedAt,
     ordered SourceReferences (kind + id + position). Do **not** persist
     Resolved Snapshot, Session Queue, or playback position
     (SessionCheckpoint = later Cap). Cap 22 ships pool + ordered-ref
     tables only; Clip / GeneratedClip / Export tables are **Out**.
     Persistence stack: **SQLite via Drift** — owner-approved engineering
     choice (kickoff requires local SQLite only; Drift is **not** a
     kickoff mandate). Domain repository interface; Drift implementation
     under `lib/data/`; features must not import Drift (ADR-009/010).
  2. **D2 — Capacity (kickoff ADR-P / ADR-020).** Max **10** Saved
     Presets (enforce on save). Max **30** sources per Definition
     (already Cap 21). At capacity, Save opens a **shared capacity
     dialog** (not the naming dialog); guide the user to Saved pools to
     delete; **no** auto-delete of the oldest. Ephemeral Start remains
     allowed. Temp Definitions do not count toward 10.
  3. **D3 — Save / Start decoupling (Build).** **Save** = persist only:
     shared naming dialog → DB write → stay on Build → light success
     feedback; **no** route pop; **no** chrome / Session change (extends
     ADR-044 D6.1 “Build cancel does not write chrome”). On successful
     Save, Build tracks `lastSavedFingerprint` (ordered SourceReference
     sequence) + `lastSavedPoolId`. **Start** is the sole Build action
     that writes chrome: if the current selection fingerprint equals
     `lastSavedFingerprint` → `activeOrigin = savedPool(lastSavedPoolId)`
     and **`parkedEphemeralPool = null`**; otherwise Cap 21 ephemeral
     Start (replace parked with the new ephemeral Definition). Save-only
     then leave Build without Start: chrome unchanged; the preset exists
     in DB and is opened only from Saved pools.
  4. **D4 — Second Save entry (composition peek).** Ephemeral peek (temp
     chip while `activeOrigin` is that ephemeral): footer **Save this
     pool** → shared naming dialog → on success: write DB,
     **`activeOrigin = savedPool(...)`**, **`parkedEphemeralPool = null`**
     (promote; do not keep a duplicate parked shadow). Saved Info peek:
     recipe only; **no** Save footer.
  5. **D5 — Shared dialogs / surfaces.** One naming dialog (Build Save,
     peek Save, and Rename). One capacity-full dialog (both Save
     entries). One composition peek card family (temp peek vs Saved Info;
     footers differ). Delete confirm = thin shared confirm dialog.
  6. **D6 — Saved pools menu + unique displayName.** Control label:
     **Saved pools** (EN); zh per Cap 7 pool product-copy convention.
     List presets; per-row **Info** (peek), **Rename**, **Delete** (+
     confirm). **Out:** edit recipe / reorder sources / replace
     unavailable sources (**Accepted deviation** vs kickoff Manage Pools
     “adjust order / replace failed sources”). Missing-source honesty:
     ADR-045 suffixes. **Unique names:** on confirm in the shared naming
     dialog, if the normalized name collides with another Saved preset →
     **block submit** and show an inline error; **no** auto-suffix / auto-
     rename. Normalize for compare: trim + case-insensitive (no locale-
     specific fold tables). Rename uses the same predicate and **excludes
     the current pool id** (same normalized name as self is allowed).
     Debt **455:** invalidate/refresh `assetSourcesProvider` when opening
     Saved list or Saved Info (and equivalent name-mapping UI).
  7. **D7 — Chrome / chip when `savedPool` active.** Extend
     `activeOrigin` with `savedPool(...)`. Chip rules: `builtIn` /
     `ephemeralPool` unchanged from Cap 21; when `activeOrigin` is
     `savedPool`, the chip shows the **current Saved** composition path;
     `parkedEphemeralPool` may remain in memory but does **not** own the
     chip. Switching Saved → built-in restores the parked-temp chip if
     park is non-null. Promote / Start-after-matching-Save paths that
     make the recipe “only saved” **clear `parkedEphemeralPool`**.
  8. **D8 — Debt 455.** Closing **455** (Saved composition UI refresh
     timing) is a Cap 22 acceptance criterion.
  9. **D9 — Out of Cap 22.** Recipe edit; SessionCheckpoint; Clip
     persistence; cross-device sync; debt **456** / **457**; still-in-
     library Cap; Share UI.
- Rejected alternatives (why not):
  - Save&Start merged, “also save” checkbox, or post-save “start now?”
    sheet — rejected; Save must not navigate or write chrome; Start is
    the sole Build chrome writer (single-control semantics since Cap
    21.3).
  - Allowing duplicate displayNames — rejected (owner revision); silent
    auto-suffix “(2)” — rejected (no unsolicited smart correction).
  - Claiming Drift is a kickoff requirement — rejected; kickoff specifies
    SQLite only; Drift is an owner-approved encapsulation choice.
  - Implementing kickoff Manage “reorder / replace failed sources” in
    Cap 22 — rejected; MVP Accepted deviation = no recipe edit.
- Consequences / constraints accepted:
  - Accepted date/anchor = Cap 22.2 work `d62e962` (2026-09-08), from
    `git log -1 --format=%cs d62e962` (not inside the work commit).
  - ADR-044 D6.1/D6.4/D7 remain binding; this ADR adds `savedPool` origin,
    Save entries, and Saved menu behavior.
  - Architecture / localization guards remain mandatory on `lib/` work
    (ADR-009/010/012).
  - Phase **22.5** misc polish is a placeholder; a mini scope freeze with
    the owner is required before any 22.5 code; 22.5 must not absorb
    debt **456** Part B, recipe edit, or SessionCheckpoint.

---

## ADR-047: Cap 22 Build Save & browse + entry-point recipe shells (supersedes ADR-046 D3 / D5)

- Status: Accepted (2026-09-09)
- Commit/PR anchor: 0b68e01
- Plain summary (owner reads this):
  On Build a Pool, **Save & browse** names the recipe, saves it, and
  immediately starts browsing that Saved pool. **Browse without saving**
  always starts a temporary pool. Recipe list **shell** is chosen by
  **tap entry point** (not temp vs saved): top-leading chip → composition
  peek; Saved-menu row **i** → centered AlertDialog. Re-tapping an
  already-active Saved row shows a Cap 19 browse toast (not a recipe
  shell). Saved recipe titles use `Sources in “{name}”` /
  「{name}」中的来源 on both shells; Temp peek keeps
  **Sources in this pool**.
- Context / what problem forced this:
  Cap 22.4 device soak showed ADR-046 Decision 3’s Save-only / fingerprint
  Start path mismatched product intent (assemble then watch; optional
  persist — not “save several presets without browsing”). Separately,
  ADR-046 D5’s single peek family and an early soak guess that “Saved =
  center / Temp = peek” both failed owner review: shell must follow
  **where** the user tapped. Owner locked Build CTA + entry-point shells
  into one ADR during the same soak; implementing code lands in the Cap
  22.4 supplemental work commit (not the first 22.4 chrome work
  `0ca1198`).
- Decision (what was chosen):
  1. **Supersede scope (narrow).** Supersedes **ADR-046 Decision 3** in
     full, **ADR-046 Decision 5**’s “one composition peek card family
     (temp peek vs Saved Info)” clause (and D6’s “per-row Info (peek)”
     wording as that Info surface), and **ADR-046 Decision 7**’s
     “Start-after-matching-Save … clear park” clause only. ADR-046 D1–D2,
     D4 ephemeral peek **Save this pool** promote, D6 menu/unique names
     (aside from Info surface), D7 chip occupancy rules, D8–D9 remain
     binding. Do **not** edit ADR-046 Decision bodies in place.
  2. **D3 — Save & browse / Browse without saving (Build).**
     - **Save & browse:** shared naming dialog → DB write →
       `activeOrigin = savedPool(...)` and **`parkedEphemeralPool =
       null`** → pop Build (same chrome-write family as D4 peek
       promote). Cancel or capacity-full: stay on Build; no chrome
       write. No success SnackBar required. Visual primary CTA =
       Filled accent (**Save & browse** above outlined **Browse without
       saving**).
     - **Browse without saving (Start):** always Cap 21 ephemeral Start
       (replace parked with the new ephemeral Definition) → pop Build.
       **Never** consult a prior Save fingerprint.
     - **Removed:** `lastSavedFingerprint` / `lastSavedPoolId` and any
       Start-after-matching-Save branch.
     - Copy (new ARB keys; not peek’s “Save this pool”): EN **Save &
       browse** / **Browse without saving**; zh **保存并浏览** /
       **不保存直接浏览**.
     - Overturns the ADR-046 Rejected alternative that forbade merging
       Save with Start navigation/chrome write — that reject assumed a
       false “save several without browsing” workflow.
  3. **D5 — Shared dialogs / surfaces (revised; entry-point shells).**
     Keep one naming dialog and one capacity-full dialog. **Recipe list
     shell = tap target, not pool attribute:**
     - **Top-leading chip** (Temp while parked-active, or Saved chip
       while `savedPool` active) → **composition peek**. Temp may show
       Save footer; Saved peek never shows Save footer.
     - **Saved-menu row Info (i)** → **centered AlertDialog** (immersive
       dark shell — same family as naming / capacity).
     - **Saved-menu row Open** when that preset is **already** active →
       Cap 19 `showCap19BrowseToast` (**You're already browsing
       “{name}”.** / **当前刷的就是这个片库。**); do **not** open peek
       or center Info.
     - **Titles:** Temp peek = **Sources in this pool**. Any Saved
       recipe surface (peek or center) =
       `mainBrowseSavedPoolSourcesTitle` — EN **Sources in “{name}”**,
       zh **「{name}」中的来源**. Body = live composition lines
       (ADR-045 honesty / debt **455** refresh). Delete confirm
       unchanged. Menu already dismisses before Info (row Icon `pop`).
  4. **Clear park.** Promote (ADR-046 D4) and Build Save & browse
     (this ADR D3) paths that make the recipe “only saved” **clear
     `parkedEphemeralPool`**. Ephemeral Start still replaces park with
     the new temp Definition (Cap 21).
  5. **Peek vs center dismiss.** Ephemeral composition peek must not
     remain under naming / capacity dialogs. Callers dismiss peek before
     those surfaces; naming / capacity entry also call
     `dismissCompositionPeekIfOpen()` as double-insurance for the Temp
     peek → Save path. Centered Saved Info is not a peek and does not
     rely on that insurance.
- Rejected alternatives (why not):
  - Keep D3 decoupled for potential future recipe-edit — rejected; D6
    already excludes recipe edit from MVP with nothing scheduled; if
    recipe editing is ever added in a later Cap, re-decoupling Save/Start
    needs its own owner decision at that time, not assumed from this
    supersede.
  - Reuse peek “Save this pool” copy for Build Save & browse — rejected;
    Build labels must state that browsing starts immediately.
  - Attribute-based shells (Saved always center / Temp always peek) —
    rejected; owner soak: shell follows **click position**, not
    temp/saved.
  - Already-active Saved row Open → center Info — rejected; toast only.
  - Edit ADR-046 Decision 3 / D5 bodies in place — rejected (append-only
    ADR discipline).
- Consequences / constraints accepted:
  - Accepted date and anchor come from Cap 22.4 supplemental work
    `0b68e01` (`git log -1 --format=%cs` → 2026-09-09), not `0ca1198`
    and not the design-discussion day.
  - ADR-046 Status records the narrow supersession; historical Rejected
    “Save&Start merged … rejected” text under ADR-046 stays as history.
  - Architecture / localization guards remain mandatory on `lib/` work
    (ADR-009/010/012).
  - SnackBar ban for Browse toasts is STATE + architecture guard
    (ADR-009 Enforcement); not a new ADR number.

## ADR-048: Browse Snapshot cache — invalidate on successful in-app album membership writes

- Status: Accepted (2026-09-10)
- Commit/PR anchor: fbf2e82
- Plain summary (owner reads this):
  After WakeTok successfully adds a photo or video to a user album
  (left-swipe or the add-to-album panel), it forgets only the Browse
  Snapshot cache entries that include that album. Switching to a Saved
  pool that uses that album then reloads fresh membership — no
  force-quit. Everyday switching among All and other Saved pools that
  do not use that album stays on the existing in-memory cache. Changes
  made outside WakeTok (system Photos, other apps, iCloud) still may
  need a force-quit until a later observer exists. If you stay on the
  same pool you are already browsing, the feed does not reshuffle just
  because you appended; leave and re-open (or switch origin) to see
  membership updates.
- Context / what problem forced this:
  In one process lifetime: browse All → left-swipe append into the
  WakeTok album → immediately open a Saved pool whose recipe includes
  that album → the new asset is missing until process death. Root cause:
  successful `addAssetToAlbum` did not invalidate
  `browseSnapshotCacheProvider`. Origin switch rebuilds a Session but
  `_snapshotFor` returns a process-lifetime hit keyed by ordered
  `SourceReference` fingerprint (ADR-014 Decision 5 / ADR-044 D6.2;
  empty-never-cache remains ADR-024; partial non-empty cache remains
  ADR-045). Cap 19.5 notes intentionally skipped automatic
  Snapshot/Session rebuild after album mutation; that omission is now
  product-visible for the All→Saved closed loop and must be corrected
  with an explicit invalidation rule — not a silent UI-local patch, and
  not by disabling process-lifetime caching on every Origin enter.
- Decision (what was chosen):
  1. **Trigger (narrow membership writes only).** Invalidate only after
     a **successful** Host call that **changes membership of an existing
     user album**, through the single `AlbumMutationRepository`
     (or equivalent sole write façade) surface. Today that is
     `addAssetToAlbum`. Future membership APIs (e.g.
     `removeAssetFromAlbum`) **must** use the same surface so the rule
     applies automatically (illustrative only — remove-from-album is
     **not** on the product roadmap). Do **not** trigger on: failed
     writes; read `albumContainsAsset`; `createAlbum` alone (catalog /
     identity — does not stale existing fingerprint coalesced ids;
     catalog freshness remains ADR-045 / debt **455**). Favorites or
     other non-album membership APIs are out of this ADR.
  2. **Shared invalidation hook.** Implement invalidation once at the
     composition-root repository wrapper / sole use-case (ADR-010).
     Feature callers (left-swipe append, panel add-to-album, future
     paths) must not each call `BrowseSnapshotCache` directly. Both
     known Cap 19 write paths go through the same hook.
  3. **Invalidation granularity — per album, not whole-cache clear.**
     On success for `albumIdentifier`, remove every
     `browseSnapshotCacheProvider` entry whose ordered-refs fingerprint
     **includes** `SourceReference(kind: album, id: albumIdentifier)`
     (single-album and multi-source keys; ADR-045 partial entries
     included). Leave entries that do not reference that album
     (e.g. All / Photos / Videos and unrelated Saved fingerprints)
     intact so unrelated Origin revisits keep process-lifetime hits.
  4. **Cache hit policy otherwise unchanged.** Successful non-empty
     Snapshots remain process-lifetime until invalidated as above;
     Leave Browse does not clear the cache (ADR-027); empty / hard-fail
     never cached (ADR-024); partial non-empty may still be cached
     (ADR-045) until a membership write removes the affected keys.
  5. **Active Session — no automatic restart (option B).** Membership
     write success **does not** call `restartSession()` and does not
     rebuild the in-memory Session for the current `activeOrigin`.
     Fresh membership appears on the **next** Session build that needs
     a Snapshot for an affected fingerprint (typical: switch Origin to
     a pool that includes the album → cache miss → resolve; may show
     “Loading library…” once for that Origin). This fully covers the
     reported All→append→open Saved pool loop.
  6. **Out of scope / Accepted boundaries.**
     - **External library changes** (system Photos app, other apps,
       iCloud sync) are **not** guaranteed visible in-process; no Photos
       library observer in this ADR. Same recording style as ADR-044
       D6.3 “Process death drops in-memory chrome state (Accepted
       boundary until SessionCheckpoint Cap)” — known cost, not denied.
     - **Same-Origin live refresh (option A rejected):** while the user
       remains on an `activeOrigin` whose recipe already includes the
       mutated album, the current feed is **not** restarted/reshuffled
       on append. Unexpected `restartSession` would reorder an in-flight
       browse after an action (append) that users do not mentally link
       to “rebuild this queue.” Leave/re-enter or switch Origin to see
       updates. Not solved here.
     - **Force re-resolve on every Origin enter** — rejected (below).
     - **Whole-cache `clear()`** — rejected (below).
     - **App-wide internal-action event bus / router** — rejected
       (below); membership writes have one consumer today (Snapshot
       cache); hook at the repository wrapper. Revisit only when a
       second, different in-app action→module notify case appears.
  7. **Cost statement.** Paying resolve / possible “Loading library…”
     is acceptable **only** for Origins whose fingerprints were
     invalidated by a **known in-app membership write**, and only on
     the next Session build that needs them. This is not “disable
     process-lifetime cache,” and must not be implemented as a broader
     invalidation than Decision 1–3.
- Rejected alternatives (why not):
  - Re-resolve / skip Snapshot cache on every Origin enter — rejected;
    destroys All ↔ Saved everyday fast switching for a low-frequency
    append→switch loop.
  - Whole-map `browseSnapshotCache.clear()` after membership write —
    rejected; forces unrelated Origins to reload; exceeds minimal
    correction boundary.
  - Patch only left-swipe (or only panel) at the call site — rejected;
    third membership path would reintroduce the hole; violates shared
    hook.
  - Auto `restartSession` when `activeOrigin` includes the album
    (option A) — rejected for this ADR; unexpected reshuffle of an
    in-progress feed (see Decision 6).
  - Photos change observer / syncing external edits — rejected; separate
    capability-sized scope.
  - Pretending external staleness does not exist — rejected; must remain
    an explicit Accepted boundary.
  - Generic in-app action event bus before a second consumer exists —
    rejected; YAGNI / premature abstraction.
- Consequences / constraints accepted:
  - Amends the **invalidation** contract of the Browse Snapshot
    process-lifetime cache (ADR-014 Decision 5 / ADR-044 D6.2). Does
    **not** overturn ADR-024 empty-never-cache, ADR-027 Leave Browse,
    or ADR-045 partial-cache rules except that affected keys are dropped
    on membership write.
  - Cap 19.5 “no automatic Snapshot/Session rebuild on album mutation”
    is superseded **for in-app membership writes via the shared hook**
    by this ADR; external mutation and same-Origin live restart remain
    as in Decision 6.
  - Implementation + tests: wrapper invalidates only matching keys;
    left-swipe and panel both exercise the hook; unrelated keys survive;
    no `restartSession` on success.
  - Accepted date/anchor = work `fbf2e82` (`git log -1 --format=%cs`
    → 2026-09-10); this docs commit is separate per two-commit
    discipline. Informal owner intent to someday delete original Photos
    assets (not remove-from-album) is parked as STATE debt **464** —
    not approved by this ADR and does not overturn kickoff scope.
- Relationship:
  Amends ADR-014 D5 / ADR-044 D6.2 (invalidation). Leaves ADR-024,
  ADR-027, ADR-045 binding as stated. Orthogonal to debt **455**
  (`assetSourcesProvider` catalog lag). Cross-ref debt **464**
  (delete-original intent park).

## ADR-049: Cap 23 current-asset still-in-library mutation gate

- Status: Accepted (2026-09-10)
- Commit/PR anchor: `32a3617` (Cap 23.3 shared dialog + mutation
  wiring); related `4004ad1` (23.2 provider/probe), `893c8fb` (23.4
  feed Case B harden + device notes)
- Plain summary (owner reads this):
  Before Favorites, Add to Album, or left-swipe-into-album runs, WakeTok
  checks once whether the current photo or video still exists in the
  Photos library. If it is gone, a shared centered dialog says so and
  the action does not run. This is separate from “is there a current
  item?” (Cap 19 actionable). iCloud items that are not downloaded yet
  still count as in the library.
- Context / what problem forced this:
  Debt **456** (Cap 21.6) Part B: users could engage Cap 19 mutation
  chrome while the Session still listed an asset that Photos had already
  deleted; failure arrived late (Host error / wrong copy). Cap 21.6
  closed debt **444** with feed-only `assetUnavailable` remap and dimmed
  the Cap 19 entry when feed fail chrome was already up — that is **not**
  a proactive Photos-existence probe. Cap 22 delivered Saved Pool; the
  Roadmap Cap “Current-asset still-in-library gate…” (Cap 23) now owns
  Part B. Part A (L2-ready still showing a deleted asset’s JPEG) remains
  **456a** and is out of this ADR.
- Decision (what was chosen):
  1. **Canonical existence signal.** One Browse provider (name locked in
     23.2) is the sole Photos-existence gate for current-asset mutation
     entries. New mutation chrome (including future Share) must use it —
     no per-entry parallel probes.
  2. **AND with actionable — do not merge.** Keep
     `mainBrowseCurrentAssetActionableProvider` (ADR-042; Cap 21.6 may
     still treat feed Host-unavailable as not-actionable). Still-in-
     library is a **second** axis. Do not fold existence into
     actionable.
  3. **Predicate.** Still-in-library iff
     `AssetAvailability != unavailable`. Thus `deviceLocal`,
     `iCloudNotDownloaded`, and `downloading` (if ever returned) all
     count as in-library. Existence ≠ device-local.
  4. **Probe API and timing.** On-demand
     `AssetSourceRepository.getAssetAvailabilities([currentId])`
     (ADR-033 / existing Pigeon). **No** continuous polling and **no**
     `PHPhotoLibraryChangeObserver` in this Cap (ADR-044 D3).
     - Cap 19 entry tap: probe before opening the half-sheet.
     - Favorites toggle / Add-to-Album append: probe before Host
       mutation.
     - Left-swipe: probe **once immediately before append**
       (`addAssetToAlbum` / WakeTok append path) — **not** on arm
       (arm may fire repeatedly in one gesture; membership cannot
       change in that millisecond window in a way that justifies
       re-probe).
  5. **Shared unavailable dialog.** One centered dialog for all Cap 23
     mutation gates. **Reuse** the Cap 22 Saved immersive-dark
     `AlertDialog` shell (`browseSavedPoolAlertDialog` /
     `saved_pool_dialogs.dart` family) — do not invent a second visual
     system. New ARB keys for copy (EN + zh-Hans); do not reuse
     wireless Layer-2 failure strings.
  6. **Entry re-entry — in-flight latch.** While a still-in-library
     probe is in flight, or while the unavailable dialog is visible,
     ignore further Cap 19 entry taps (and equivalent re-entry into the
     same gated action). **Not** a wall-clock debounce: fixed delays
     reopen the race when async work outlasts the timer (same class of
     defect as fixed-delay vs state-driven round handling). Latch clears
     when the probe finishes and any dialog is dismissed.
  7. **Debt split (STATE).** Bare Known debt **456** is retired at Cap
     23.1 (same pattern as bare **403** → **403a** / **403b-***).
     **456a** = L2-ready limb (Open; out of Cap 23). **456b** = this
     gate (Open until Cap 23 device PASS, then Closed).
  8. **Out of scope.** Debt **456a**; Share UI; delete-original (**464**);
     library change observer / Session Queue rebuild; merging existence
     into actionable; closing **457**.
- Rejected alternatives (why not):
  - Probe on every left-swipe arm update — rejected; conflicts with
    on-demand / anti-churn spirit; append-boundary probe is enough.
  - Wall-clock tap debounce — rejected; state-driven in-flight latch.
  - Merge existence into `mainBrowseCurrentAssetActionableProvider` —
    rejected; Roadmap / debt **456b** require AND, not merge.
  - Continuous poll or Photos library observer — rejected; Cap scope +
    ADR-044 D3.
  - New dialog visual language — rejected; reuse Cap 22 Saved shell.
  - Keep bare **456** until Cap close — rejected; unclear Open/Closed
    status during Cap 23 execution.
- Consequences / constraints accepted:
  - Accepted with implementing anchors above
    (`git log -1 --format=%cs 32a3617` → 2026-09-10).
  - Cap 21.6 feed Host-unavailable dimming stays as interim chrome for
    the already-failed feed path; Cap 23 covers proactive gates when
    feed may still show content (**456a** residual possible).
  - Architecture / localization guards remain mandatory on `lib/` work
    (ADR-009 / ADR-010 / ADR-012).
- Relationship:
  Extends ADR-042 (orthogonal existence axis). Uses ADR-033
  `getAssetAvailabilities`. Does not amend ADR-044 D3 feed-only remap.
  Closed STATE debt **456b** at Cap 23.4 (`0ba5f22` / work `893c8fb`);
  leaves **456a** Open.

## ADR-050: Cap 24 soft-delete current asset to Photos Recently Deleted

- Status: Accepted (2026-09-10); Decision 2 Action Column **index layout**
  (Album at index 1; Share placeholder at index 2) is **narrowly
  superseded by ADR-051** (Proposed at Cap 25.1; Accepted date/anchor
  when Cap 25 implementing work lands). Soft-delete entry, half-sheet,
  Session semantics, and all other ADR-050 decisions remain binding.
- Commit/PR anchor: 32d4bd1
- Plain summary (owner reads this):
  From Browse, the user can open a bottom "…" action, see a small
  half-sheet with a Photos-finder time landmark (EXIF when available,
  otherwise an approximate `~` time from the library date), tap Delete,
  and soft-delete the current photo or video into the system Recently
  Deleted album after the **system** PhotoKit consent UI (no separate
  App confirm AlertDialog — see Decision 3 revised). WakeTok immediately
  removes that item from the current Session Queue so it cannot be
  revisited in this session. Restoring it in Photos only brings it back
  on the next Pool enter (a new Session resolve). WakeTok never empties
  Recently Deleted.
- Context / what problem forced this:
  Doom-scroll organization without soft-delete feels incomplete. Cap 23
  already ships still-in-library mutation gates and Host Recently Deleted
  → unavailable mapping. Kickoff Do Not Build #4 still bans delete UI /
  Doom Scroll delete; debt **464** only parks informal intent and must
  not be read as approval. Owner directed Cap 24 after Cap 23 close;
  Auto-play / queue-order roadmap items may move later (owner plan;
  not decided in this ADR).
- Decision (what was chosen):
  1. **Soft-delete only.** Host uses `PHAssetChangeRequest.deleteAssets`
     (or equivalent). Assets go to system Recently Deleted. Permanent
     purge / Empty Recently Deleted is never in product scope.
  2. **Single entry.** Action Column lowest icon is "…" (index 0). Cap 19
     Add-to-Album entry moves to index 1 via
     `actionColumnBottomInsetForIndex`. Share placeholder, if documented,
     shifts to index 2. Horizontal `kMediaChromeOverlayTrailingInset`
     unchanged. Update
     `docs/reference/media-chrome-layout-notes.md` when Cap 24 ships.
  3. **Half-sheet + confirm.** "…" opens a half-sheet (reuse Cap 19
     visual constants: tint/blur tokens in `cap19_entry_layout.dart`).
     Tapping Delete shows a confirm dialog (Cap 22
     `browseSavedPoolAlertDialog` immersive dark shell) before any Host
     write. Copy class: iOS Photos soft-delete / Recently Deleted ~30
     days / iCloud Photos wording; use “this item” / media-neutral
     phrasing (same family as `stillInLibraryUnavailableDialog`), never
     photo-only. App confirm is mandatory. If PhotoKit / the system shows
     a second confirm after the App dialog, accept that stack — do not
     invent a third in-app confirm. Device acceptance notes the system
     layer if observed.

     **Decision 3 revised (2026-09-11; work `6c5f39a`):** Device evidence
     on Cap 24 Profile builds: PhotoKit
     presents the system delete-consent UI (“Allow WakeTok to delete…”,
     Recently Deleted ~30 days). Stacking a separate App AlertDialog on
     that system confirm is redundant. Peer **Photo-App-A** also routes
     overflow / half-sheet Delete straight into the system consent UI
     without a second in-app confirm. Therefore Decision 3’s
     App-confirm-mandatory limb is superseded for Cap 24 chrome as
     follows:

     - “…” still opens the half-sheet (unchanged visual contract).
     - Tapping Delete runs Cap 23 still-in-library, then Host
       `softDeleteAsset` immediately — **no** App AlertDialog.
     - The **only** user consent surface is the system PhotoKit UI.
     - While Host awaits, the half-sheet stays open with Delete-row busy
       (ex-Q6=A busy semantics move to the sheet Delete control);
       an in-flight latch also covers the Cap 23 gate window (no busy
       spinner there) and blocks barrier / system-back dismiss until the
       full Delete attempt finishes (success / cancel / fail / gate deny).
     - Cap 24.5 notes SYS / CANCEL describe the system UI only.
     - Decision 9 table glosses that say “half-sheet + confirm” now mean
       half-sheet Delete → system PhotoKit consent (not an App
       AlertDialog).

     **Assumption (explicit; P0 if broken):** This revision assumes
     `PHAssetChangeRequest.deleteAssets` presents a system-level user
     consent UI on every iOS version WakeTok supports. If that
     assumption is ever falsified on a supported device / OS / Screen
     Time / MDM configuration, treat as **P0** — do not demote to
     Monitoring debt.
  4. **Session semantics (success, failure, evidence).**
     - **Success:** on successful Host delete callback, remove that asset
       id from the in-memory Session Queue and advance to the next item.
       No in-session revisit. Restore in Photos does not re-inject into
       the current Session; reappearance requires a later Pool enter /
       new resolve.
     - **Failure:** on Host delete failure (permission change, PhotoKit
       error, `performChanges` `success=false`, or Pigeon failure): do
       **not** remove from Queue, do **not** advance; show an in-place
       non-blocking error toast in the **same feedback style** as Cap 19
       add-to-album failure (non-blocking; “didn’t succeed — try again”
       tone). Use a **new** ARB key (e.g. `cap24SoftDeleteFailed`) — do
       **not** reuse `cap19PanelAddToAlbumError` (that copy is
       album-add-specific). Fail-closed — no optimistic Session mutation.
     - **Evidence (not “Verified in WakeTok code”):**
       `makeLibraryFetchOptions()` only sets `creationDate`
       sortDescriptors; it does **not** set inclusion flags. Product
       relies on PhotoKit defaults for catalog / paging / resolve fetches
       (nearby comment claims Hidden + Recently Deleted excluded;
       `includeHiddenAssets` left at Apple default `false`). By-id fetch
       in `getAssetAvailabilities` (`options: nil`) still returns
       Recently Deleted assets and uses
       `isInRecentlyDeletedSmartAlbum` — a **different** path; Hidden is
       intentionally **not** excluded on that by-id path. Cap 24 does
       **not** invent a second Recently Deleted detector for Session
       surgery after a successful in-app delete (Queue removal is the
       Session source of truth for that id).        Cap 24 **device acceptance
       MUST confirm**: (a) after App soft-delete, while the asset remains
       in system Recently Deleted, a **new** Session resolve of the same
       Pool does not include that id; (b) after the user restores it in
       Photos, a **later** new Session resolve may include it again. If
       either fails on device, add an explicit filter (see Rejected
       alternatives escape). Hidden exclusion is **not** used as product
       justification for soft-delete Session semantics.

       **Decision 4 evidence (Cap 24.5):** Owner matrix on Kafka + i17
       **PASS** for (a) and (b) under the locked force-quit → real
       PhotoKit resolve protocol. Notes
       `docs/acceptance/cap24-24.5-notes.md`. SYS / CANCEL / SUCCESS
       also PASS; FAIL SKIP (harness). Escape hatch not taken. ADR-050
       remains Proposed until Cap 24 close.
  5. **Reuse Cap 23 Recently Deleted recognition; no library observer.**
     Cap 23.4 `isInRecentlyDeletedSmartAlbum` on
     `getAssetAvailabilities` / `requestDisplayAsset` /
     `requestPreview` remains the Host gate when an id is still probed
     (delete-before probe, races, external delete). No
     `PHPhotoLibraryChangeObserver` — App-owned success path via Host
     completion only (aligns ADR-044 D3).
  6. **"…" shares Cap 19 slot-family chrome.** Visibility and dimming
     follow ADR-042 Decision 7 (not-actionable dim) and Decision 8 (hide
     under peek / PV-covering), **and** Cap 23 still-in-library /
     feed-unavailable rules already applied to the Cap 19 entry — not
     probe-on-tap-only. Cap 23 still-in-library gate remains required
     before the Host delete write.
  7. **Exact-minute Photos-finder landmark in the half-sheet (complements
     Overlay Meta row 2 — does not copy it).** Overlay row 2 is
     **passive**, day-only, deliberately fuzzy (`~ Y-M-D` from
     `creationDate`→device local — ADR-038). The half-sheet row is
     **user-initiated**: give the most precise civil clock WakeTok can
     show as a landmark to find the same item in iOS Photos — “as precise
     as possible; wrong hour on cross-timezone edges is acceptable.” A
     sometimes-wrong minute landmark beats no landmark. Disclaimer + UI
     source marking (below) carry honesty — not blankness.

     **Source priority (MVP):**
     1. **EXIF/TIFF naked wall** (still/Live only) → display **without**
        `~` (true container civil clock).
     2. Else **`PHAsset.creationDate` → device local** (Instant fallback)
        → display **with** `~` prefix (same honesty mark as Overlay
        approximate row — Instant must not look identical to EXIF).
     3. Else no `creationDate` → **omit** the minute row.

     **Display shape (locked):** include **calendar date + time** (Photos
     find needs both; half-sheet may cover Overlay row 2). EXIF:
     `yyyy-MM-dd HH:mm[:ss]` bare. Instant fallback:
     `~ yyyy-MM-dd HH:mm` (minute precision; seconds optional only on
     EXIF when present). ARB: bare formatter vs approx formatter (e.g.
     `cap24SoftDeleteSheetExactMinute` / 
     `cap24SoftDeleteSheetExactMinuteApprox`) — not
     `mediaInfoExactDateApprox`.

     **vs Overlay row 2 — accepted mismatch:** A bare EXIF half-sheet
     date may differ from Overlay Meta row 2’s `~ y-m-d` for the same
     asset. EXIF is capture-local civil clock from the container; row 2
     is `creationDate` reinterpreted in the **device** time zone
     (ADR-038 honesty boundary: rows / Photos are not required to
     cross-check as one formula). That divergence is **expected and
     accepted** — not a Cap 24 acceptance FAIL and not a new bug to
     “fix” by forcing the two surfaces onto one source.

     **Disclaimer (locked copy; covers both sources):** ARB
     `cap24SoftDeleteSheetMinuteTimezoneNote` —
     EN: “For photos or videos saved across time zones, the hour shown
     may be wrong, and in rare cases the date may be off by up to a
     day.” zh-Hans: as locked in Cap 24 copy freeze (English gloss:
     cross-timezone photos/videos — hour may be wrong; in rare cases the
     date may differ by about a day).

     **"…" affordance vs minute row — decouple.** The "…" icon stays on
     Cap 19 slot-family rules (Decision 6 / ADR-042 D7–D8 + Cap 23
     still-in-library). **Do not** require Layer 2 ready to tap "…".
     Gating delete on L2 success would block soft-delete for assets that
     never mint L2-ready (e.g. STATE debt **400** iCloud/optimized-storage
     video: black + spinner, no L1 poster) — rejected product regression.

     **Half-sheet interaction + no Instant→EXIF flash:** shell + Delete
     (and confirm path) interactive immediately. The minute row must
     **not** paint Instant/`~` first and later jump to bare EXIF. Still/
     Live: await `lookupIfCoverOnDisk` (and local EXIF parse if any),
     **then** choose EXIF bare vs Instant `~` vs omit — **one** paint.
     Video: no EXIF attempt — paint Instant `~` when `creationDate`
     exists (no wait on L2). Minute row may stay empty briefly on stills
     until that resolve; must not block Delete.

     **Stale async result (Cap 23.2 class):** Cap 24 "…" reuses Cap 19
     `showModalBottomSheet` modality (barrier; underlying feed does not
     receive browse gestures while open — current asset cannot change via
     doom-scroll under the sheet). After any `await` on the minute path,
     paint only if the half-sheet widget is still **mounted** (sheet not
     dismissed / disposed). If a future Cap ever opens a non-modal "…"
     surface that can leave current while open, add capture-id-then-compare
     (same class as Cap 23.2 probe stale-guard) before paint — not required
     while modality matches Cap 19.

     **Still / Live data path:** After the sheet opens, await
     `browseL2ReadySessionProvider.lookupIfCoverOnDisk(currentId)` (a
     `Future` — not sync `lookup` alone). On `FeedL2ReadyKind.stillFull`
     with on-disk `cover.localFilePath`, parse naked wall **locally**
     from that Layer 2 display temp (ImageIO EXIF `DateTimeOriginal` /
     else TIFF `DateTime`; archive field rules; Host/gateway boundary —
     Pigeon shape deferred). Temps are raw
     `requestImageDataAndOrientation` bytes (not UIImage re-encode); EXIF
     **may** be absent. If EXIF/TIFF datetime present → bare value. If
     lookup miss / eviction / no datetime → Instant→local with `~` when
     `creationDate` is available (reuse existing presentation /
     Overlay metadata source — e.g. Cap 8.3
     `requestPresentationMetadata` / held snapshot — **no new network**).
     **No** half-sheet network escalate; Cap 17.7 archive “local fail →
     network retry” is **not** inherited.

     **Video (MVP):** Do **not** parse AVAsset creation-date strings and
     do **not** issue a new `requestAVAsset` from the half-sheet.
     `PlaybackApi.load` already downloads AVAsset for play but does not
     report wall-clock strings; L2-ready video cover is poster-only.
     MVP video minute row = Instant→local with `~` from existing
     `creationDate` (zero extra Host cost). Omit row only if
     `creationDate` is nil. Optional later (out of MVP): piggyback
     string parse at prepare success into Session cache for bare
     (non-`~`) video landmark.
  8. **MVP Out (slots only):** location row; second Add-to-Album entry
     inside the "…" sheet. No permanent Empty Recently Deleted UI. No
     swipe-to-delete. No top-right trash. No in-app Recently Deleted
     browser / batch delete. No Hide mapping. No library observer.
  9. **Kickoff Do Not Build #4 — narrow supersede (line-by-line).**
     This ADR does **not** vaguely “revise kickoff.” It narrowly
     supersedes only the Delete-related bans below for Cap 24
     soft-delete UX. Hide remains forbidden. **Historical fact:**
     Favorite was already product-shipped in Cap 19 without a
     line-by-line supersede of Do Not Build #4; this ADR records that
     gap and does **not** re-ban Favorite or backfill ADR-042.

     | Kickoff #4 ban (English gloss of local kickoff; still-forbidden list) | Cap 24 effect |
     |---|---|
     | No swipe-to-delete | Remains **in force** (no swipe-delete). |
     | Do not show a delete button | **Narrowly superseded:** Delete may appear **only** inside the "…" half-sheet (and its confirm). No always-on feed Delete button; no top-right trash control. |
     | Do not show a top-right trash control | Remains **in force**. |
     | Do not implement an in-app pending-deletion area or batch delete | Remains **in force** for in-app trash area / batch. Soft-delete into **system** Recently Deleted is allowed; WakeTok does not implement its own trash UI or batch delete. |
     | Do not run Favorite, Delete, or Hide directly in Doom Scroll | **Narrowly superseded for Delete only:** soft-delete may run from Doom Scroll via "…" → half-sheet → confirm → Host. Favorite remains as Cap 19 already ships. Hide remains forbidden. |

     Introducing the "…" half-sheet is the Do Not Build #4 re-freeze path
     for a Media Actions Sheet when a second organize action exists
     (kickoff §1.7 foreshadowed this). Cap 24’s sheet is that minimal
     sheet (Delete + reserved slots only).
  10. **Parallel kickoff “no delete / modify originals” wording —
      named coverage (local kickoff; not rewritten in-repo).**
      Same narrow reading as Decision 9: soft-delete-to-system-Recently-
      Deleted is allowed; permanent Empty Recently Deleted, Hide, batch,
      and content edit of originals are not. Add-to-Album remains
      append-only.

      | ID | Kickoff locus | Cap 24 effect |
      |---|---|---|
      | P1 | MVP Scope §14 Add to Album (~“append only; no move / copy / delete / modify of originals”) | §14 **Add-to-Album contract unchanged** (membership append only). Narrowly supersedes the implication that the App never soft-deletes originals — Cap 24 is a **separate** Native Action Mapping. |
      | P2 | Module / iOS App linkage → Add to Album (~same append-only sentence) | Same as P1. |
      | P3 | C: MVP organization-duty boundary (~append-only; Favorite/Delete/Hide/batch stay in Photos; further mapping needs #4 ADR) | Narrowly supersedes for Cap 24 soft-delete-to-RD from Doom Scroll; Hide / batch / permanent purge remain out. Favorite already Cap 19. |
      | P4 | §1.7 Long-press media area — extension list (Favorite / Hide / Delete; v1.0 UI must not appear) | Same treatment as Do Not Build #4 table (Decision 9): Delete only via "…" half-sheet + confirm; Hide stays banned; Favorite historical Cap 19 fact. |
      | P5 | §3.4 MVP-invisible extension components (Delete Button / Swipe to Delete / Trash Icon / Pending Deletion Area / Favorite / Hide / …) | Same UI bans as #4. Half-sheet Delete is **not** an always-visible rail Delete button or top-right trash icon. Swipe-delete, in-app pending-deletion area, and top-right trash remain banned. Favorite already Cap 19. |

  11. **Debt 464 on Accept (implementing work).** Do **not** write a
      blanket “464 Closed.” Split: soft-delete intent → **Closed by Cap
      24**; permanent Empty Recently Deleted / purge → remain
      **Accepted (permanent)** never. Until Accept, **464** stays Open
      as intent park.
- Rejected alternatives (why not):
  - Bolt soft-delete onto Cap 23.5 (docs-only close) — rejected; medium
    Cap.
  - Permanent purge / Empty Recently Deleted — rejected.
  - Swipe-delete or always-visible Delete / top-right trash — rejected
    (#4 remains for those).
  - Second Add-to-Album or location in MVP "…" sheet — deferred.
  - Library observer to sync deletes — rejected (ADR-044 D3).
  - Re-invent Recently Deleted detection after Cap 23.4 Host helper —
    rejected.
  - Treat `makeLibraryFetchOptions` comment as code-verified RD
    exclusion without device proof — rejected; Decision 4 evidence
    downgrade + device-acceptance gate.
  - New resolve filter “exclude RD” beyond PhotoKit defaults — rejected
    **unless** device acceptance proves default exclusion fails.
  - Reuse `cap19PanelAddToAlbumError` for delete failure — rejected;
    wrong literal meaning; new key, same toast style.
  - Optimistic Queue remove before Host success — rejected; fail-closed.
  - Gate "…" on Layer 2 ready — rejected; blocks soft-delete when L2
    never succeeds (debt **400** class).
  - Show Instant/`~` first then upgrade to bare EXIF — rejected; one
    paint after still EXIF attempt resolves.
  - Paint Instant fallback **without** `~` (looks like EXIF) — rejected;
    UI source mark required, not disclaimer-only.
  - Use Instant→local as the **primary** still landmark when EXIF is
    available — rejected; EXIF bare wins when present.
  - Omit still/video landmark whenever EXIF/AVAsset string is missing
    (no Instant fallback) — rejected; user-initiated half-sheet prefers
    Instant+`~` over blank when `creationDate` exists.
  - New half-sheet `requestAVAsset` / network escalate for video (or
    still) minute — rejected for MVP; video uses Instant+`~` only.
  - Inherit Cap 17.7 archive network escalate for still minute —
    rejected; still EXIF reads existing L2 display temp only.
  - Force half-sheet EXIF civil date to match Overlay row 2 `~ y-m-d`
    (or treat mismatch as FAIL) — rejected; ADR-038 multi-source
    honesty; accepted Cap 24 divergence.
  - Weak non-time placeholder copy when both EXIF and Instant are
    missing — rejected; omit the minute row.
- Consequences / constraints accepted:
  - Accepted with implementing anchor `32d4bd1`
    (`git log -1 --format=%cs 32d4bd1` → 2026-09-10). Related Cap 24
    work: `f4928b6` / `52b6c39` / `0ccc8fa` / `0b6c7c6` / `6c5f39a` /
    `ae8d8cd` / `d62ad70` (and polish commits cited in PHASE_HISTORY).
  - Cap 23 ADR-049 gates remain required before the Host delete write.
  - Architecture / localization guards remain mandatory on `lib/` work
    (ADR-009 / ADR-010 / ADR-012).
  - On Accept: debt **464** Closed (soft-delete intent); permanent Empty
    / purge → new debt **469** Accepted (permanent). Action Column
    indices were updated in Cap 24.3 layout notes (`f4928b6`); Cap 24
    close-out also fixed stale Zone-overview / §2 wording that still
    named Cap 19 as lowest.
- Relationship:
  Builds on ADR-049 / Cap 23.4 Recently Deleted mapping; ADR-042 D7/D8
  chrome; ADR-044 D3 (no observer); Cap 19 half-sheet tokens; Cap 22
  alert shell. Narrowly supersedes kickoff Do Not Build #4
  Delete-related lines and parallel loci P1–P5 as tabled. Does not
  authorize Hide, batch delete, or permanent purge.

## ADR-051: Cap 25 Share current asset from Action Column

- Status: Proposed; Decision 15 (exclude saveToCameraRoll only) Accepted (2026-09-14; work `39f04a4`)
- Commit/PR anchor: pending (flip to Accepted with implementing work sha
  at Cap 25 close; no fake anchor while Proposed)
- Plain summary (owner reads this):
  Browse Action Column gains a Share control between "…" and Add-to-Album.
  Tap runs the Cap 23 still-in-library gate, then Host presents the system
  share sheet for the current Photos asset. Cancel and successful share are
  silent; only Host present/prepare failure shows a Cap 19-style toast.
  Session Queue is unchanged. No local DB. Mute / Fit / 2× stay out of this Cap.

- Context / what problem forced this:
  MVP Scope §12 and kickoff Share flow require System Share Sheet from the
  Right Action Rail. Cap 19 / Cap 24 shipped album and "…" chrome; layout
  notes left Share as a placeholder at index 2 (ADR-050 Decision 2). Owner
  Cap 25 lock moves Share to the middle (index 1) and Album to index 2.
  Cap 23 / ADR-049 already require future Share to reuse the still-in-library
  gate; Cap 25 lands that chrome without Photos mutation or Queue surgery.

- Decision (what was chosen):

  1. **Action Column indices (Q1=B) — narrowly supersedes ADR-050 D2 index
     layout.** Bottom-up:
     - index 0 = Cap 24 "…" (unchanged)
     - index 1 = Share (this Cap)
     - index 2 = Cap 19 Add-to-Album (moves up from Cap 24’s index 1)
     Horizontal `kMediaChromeOverlayTrailingInset` unchanged.
     **Supersede scope:** ADR-050 Decision 2’s Action Column **index layout**
     clauses only (Album at 1 + Share placeholder at 2). Soft-delete entry,
     half-sheet, Session semantics, and other ADR-050 decisions remain
     binding. Same-turn docs must update
     `docs/reference/media-chrome-layout-notes.md` §7 (Share i=1, Album i=2;
     Zone overview / §2 wording if they still say Share-at-2).

  2. **Host presents system share sheet (Q2=A).** New Pigeon method on
     `PhotoLibraryApi` (name locked in 25.2, e.g. `presentShareSheet`):
     Host loads `PHAsset` by id, builds system `UIActivityViewController`
     activity items, and presents from the app’s UIViewController.
     **Not** an App-owned export-to-sandbox product pipeline (no Clip Export
     Job, no durable WakeTok media file as the share product).
     **Allowed:** ephemeral PhotoKit materialization solely to populate
     activity items (UIImage / AV URL / NSItemProvider / temporary URLs the
     system requires). Temps are share-scoped and cleaned after the system
     completion handler; do **not** park them in Preview/Display temp product
     pools as a share side effect.

  3. **iCloudNotDownloaded (Q3=A).** Cap 23 still-in-library remains the only
     pre-share existence gate (`AssetAvailability != unavailable`, including
     `iCloudNotDownloaded` — ADR-049 Decision 3). After the gate passes, Host
     still presents; system/PhotoKit may download or fail. No App wait layer
     / Layer-2 gate for Share.

  4. **Dismiss / cancel / complete UX (Q4=A) + completion contract.**
     - User cancels the share sheet (`completed == false`) or finishes a
       share target: **silent** — no success toast, no error toast.
     - Host failure before/at present (see Decision 5): Cap 19-style
       non-blocking toast; **new** ARB key (do not reuse album-add /
       soft-delete failure copy).
     - **Do not** map share-sheet cancel to `operationCancelled`. That code
       is Cap 24 soft-delete system-consent cancel semantics; copying it
       would falsely treat a normal dismiss as an operation error path.
     - Pigeon Future **succeeds when the system sheet has been presented**
       (or fails before present). Sheet dismiss does not fail the Future.
       Session Queue / Snapshot unchanged on all share outcomes.

  5. **Error codes — no new ErrorCode; reuse `assetUnavailable`.**
     Kickoff Data Contract has no Share-specific code. Cap 25 failure surface
     is narrow:
     - cannot resolve a presentable root `UIViewController`, or
     - cannot build activity items for the `PHAsset` (including missing asset
       after the Dart gate race).
     Both map to existing **`assetUnavailable`** as an **intentional
     wire-code overload** (same family as Cap 24 Host soft-delete mapping
     non-missing failures to that code for one toast path). Do **not** add a
     new Pigeon ErrorCode in Cap 25. Dart maps that failure to the Share
     fail toast only (not wireless Layer-2 copy).

  6. **Limited Access (Q5=A).** Show Share under Limited the same way Cap 24
     "…" remains visible for an accessible current asset. **Reason (must not
     be omitted):** ADR-K “no Limited album features” targets album
     **enumerate / list-find** (Album Picker / Limited create-only bootstrap
     constraints). Share does not list or look up albums; it only asks the
     system to share the **current** authorized-visible asset. That is
     outside the ADR-K album list-find red line. Full Access is not required
     for the Share entry.

  7. **Icon (Q6=A).** `CupertinoIcons.square_and_arrow_up`. Cap 24
     `ellipsis_circle` uses optical size **36** (not 32) with an in-code
     comment. Share may need a similar on-device weight pass in 25.3 — do
     **not** treat 32pt as locked without Profile eyeball.

  8. **Chrome / gates — named symbols + no Layer-2 ready requirement.**
     Share is the same trailing mutation slot family as Cap 19 / Cap 24 "…".
     Implementers must wire these **named** symbols — do **not** invent a
     parallel null-check or approximate gate:

     - **Actionability / enable axis:**
       `mainBrowseCurrentAssetActionableProvider` (ADR-042 Decisions 1–7;
       sole “is current item determined?” signal — do not gate Share enable
       on ad-hoc `mainBrowseCurrentAssetIdProvider == null` checks for UI
       enablement; id provider remains the string source for the Host call).
     - **Peek / PV-cover visibility (hide vs dim):**
       `mainBrowseTrailingMutationChromeVisible` in
       `main_browse_trailing_chrome_policy.dart` (ADR-042 Decision 8 —
       actionable ∧ vertical feed settled ∧ not PV-covering).
     - **Still-in-library before Host present:**
       `ensureCurrentAssetStillInLibraryForMutation` (ADR-049).

     **Layer 2 ready — explicitly not required.** Share chrome and tap
     enablement do **not** require Layer 2 ready / `scrubberFrozen` /
     playback-ready predicates. Same independence as Cap 24 "…" under
     ADR-050 Decision 7 (“…" affordance vs minute row — decouple”: do not
     require Layer 2 ready to tap "…"). Gating Share on L2 success would
     block share for assets that never mint L2-ready (e.g. STATE debt
     **400** coverless iCloud / optimized-storage video — Accepted
     (permanent)) — rejected. Availability for Share = actionable
     provider + Cap 23 probe pass on tap; decode/L2 state is orthogonal.

     Feed Host-unavailable dimming stays as Cap 21.6 interim where already
     applied; Cap 25 does not merge existence into actionable.

  9. **In-flight latch — Share-specific (not Cap 24 PopScope copy).**
     Cap 24 latch pairs with Flutter half-sheet + `PopScope(canPop: !latch)`
     to block barrier / system-back dismiss while Host delete runs. Share
     presents a **native** `UIActivityViewController`, not a Flutter route —
     there is **no** PopScope to arm.
     Latch covers only the async window:
     **tap → Cap 23 probe → Host invoke until present returns (success or
     fail).** Once the system sheet is up, it covers the icon and naturally
     prevents re-taps. Latch clears when that window ends (probe deny /
     dialog / Host Future settle). Do **not** hold a Flutter PopScope for
     the lifetime of the system sheet.

  10. **iPad popover anchor (Host note; out of MVP acceptance).**
      `UIActivityViewController` on iPad requires
      `popoverPresentationController` `sourceView` / bar-button anchor or it
      can crash. Cap 25 Host implements **iPhone-only** present (kickoff: iPad
      not an MVP acceptance target). 25.2 Host implementation notes must
      state explicitly: **iPhone-only; iPad needs a separate anchor** — so a
      future iPad Simulator run does not look like a mysterious share crash.

  11. **Out of scope.** Mute / Fit / Fill / 9:16 Crop / 2×; debt **456a** /
      **457**; Empty Recently Deleted (**469**); library change observer;
      Share analytics / custom share targets; any Drift / SQLite entity for
      Share; kickoff Do Not Build #4 re-freeze (Share is System Share Sheet,
      not a Native Action Mapping Photos organize write — #4 does not apply;
      no narrow supersede of #4 required for Cap 25).

  12. **Live Photo share materialization = still key frame only.** Share
      never calls `PHImageManager.requestLivePhoto` and never places a
      `PHLivePhoto` in `UIActivityViewController` activity items. Live
      assets use the **same** static `requestImage` path as ordinary stills
      (key photo). Recipients get a still, not Live motion — intentional.
      Narrowly supersedes Cap 25.2 owner Q-A=A1 (“prefer Live, still
      fallback”). Feed Live motion (`LivePhotoApi` / ADR-019) is unchanged.

  13. **Still (incl. Live-as-still) present only non-degraded UIImage.**
      Host ignores `PHImageResultIsDegradedKey == true` callbacks and
      presents only when a non-degraded `UIImage` is available. Scope is
      **still image materialization only** (Live shares this path via
      Decision 12). Does **not** change video `requestAVAsset`, cancel /
      pause / spinner / UIWindow presentation chrome.


  15. **System share sheet exclusions (narrow).**
      Before presenting `UIActivityViewController`, Host sets
      `excludedActivityTypes` to **exactly**:
      - `UIActivity.ActivityType.saveToCameraRoll`
      **Reason:** the shared asset is already in the user's iOS Photos
      library; the system "Save Image" / "Save Video" (same activity
      type) action is a redundant save-back-to-Camera-Roll and is
      product noise for WakeTok Browse Share.
      **Explicit non-exclusions (intentional keep):**
      - `UIActivity.ActivityType.assignToContact` — retained; may have
        valid uses; do not exclude by analogy with save-to-camera-roll
        unless a later owner decision revisits it.
      - All other built-in system activities (e.g. Print, Copy) —
        retained.
      - Third-party share extensions (WeChat, WhatsApp, etc.) — not
        controllable via this list; left to the system.
      **Out of scope:** share-sheet chrome width / half-expanded vs
      fully-expanded layout (system-owned; Cap 25 does not customize).
      **Accepted (2026-09-14).** Implementing work commit `39f04a4`.

- Rejected alternatives (why not):
  - Exclude assignToContact / Print together with saveToCameraRoll — rejected;
    owner keeps the native activity list except Camera-Roll save-back
    (Decision 15).
  - Share at index 2 above Album (ADR-050 placeholder) — rejected; owner Q1=B.
  - Export-to-temp then share URL as the product path — rejected; invents an
    App export pipeline inconsistent with Host-touches-PHAsset style
    (soft-delete / display request). Ephemeral PhotoKit item prep for the
    system sheet remains allowed under Decision 2.
  - Prefer `PHLivePhoto` activity item with still fallback (Cap 25.2 Q-A=A1)
    — superseded by Decision 12; always-still is simpler and one code path.
  - Block Share until `deviceLocal` / force Layer 2 first — rejected; conflicts
    with ADR-049 iCloudStillInLibrary, ADR-050 D7 "…" L2 independence, and
    thickens Cap 25.
  - Map share cancel → `operationCancelled` — rejected; wrong Cap 24 consent
    semantics; cancel must be silent success-path for Dart.
  - New ErrorCode for share present failure — rejected; reuse
    `assetUnavailable` overload (Decision 5).
  - Hide Share under Limited — rejected; not an album list-find feature.
  - Copy Cap 24 PopScope latch onto Share — rejected; wrong UI host (Decision 9).
  - Ad-hoc parallel actionable / existence checks instead of the named
    providers above — rejected; ADR-042 / ADR-049 drift class.

- Consequences / constraints accepted:
  - ADR-050 Decision 2 index layout narrowly superseded as of Cap 25.1
    Proposed; layout notes §7 updated in the same docs commit. Product
    chrome: Cap 25.3 placed Share at index 1 / Album at index 2 (`c3b5a58`).
  - Cap 25.2 Q-A=A1 Live-prefer path superseded by Decision 12 (always
    still key frame for Share).
  - Architecture / localization guards remain mandatory on `lib/` work.
  - Known debt close count for Cap 25 = **0**.
  - GLOSSARY: no new concept node (Share is chrome on Media Item).

  - Decision 15: Host excludes only `saveToCameraRoll` on Share present;
    assignToContact and other built-ins remain intentional keeps.
- Relationship:
  Narrowly supersedes ADR-050 Decision 2 **index layout** only.
  Extends ADR-042 / ADR-049 (Share is a required consumer of the named
  symbols in Decision 8).
  Inherits Cap 24 "…" Layer-2 independence from ADR-050 Decision 7
  affordance clause (Decision 8).
  Does not amend ADR-K album list-find rules; Decision 6 records why Share
  is outside that red line.
  Orthogonal to ADR-044 D3 (no library observer).
