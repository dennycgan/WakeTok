# WakeTok — Decision Log (ADR)

> Major technical/engineering decisions. Each entry is immutable: never edit or
> delete its reasoning. To overturn a decision, write a NEW entry and only flip
> the old entry's Status line to "Superseded by ADR-xxx".
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

- Status: Accepted (2026-07-28)
- Commit/PR anchor: 3ff7f58
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
       including Texture escape `10bd0c1` and Hitch Probe calibration `e5c4117`.
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
- Commit/PR anchor: 9eeb912
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
     - Work commits on `spike/poc` include `77d7af8` … `9eeb912` (anchor).
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
- Commit/PR anchor: fcf7561
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
  - Anchor note (O3=S1): Accepted against POC-09 work `fcf7561` (same close-out
    packaging as ADR-004); §9.5 body lives in notes in this docs commit.

---

## ADR-004: POC-09 Current Photos Representation Export Gate — Pass

- Status: Accepted (2026-07-29)
- Commit/PR anchor: fcf7561
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
       (unedited smoke). Work: `c98a073`.
     - **9.2** Trim: export ≈ current; original obviously longer (>2s notes
       threshold); no silent original fallback — PASS. Work: `e8e900b`.
     - **9.3** HFR/slo-mo: export duration matches Photos-displayed /
       PHAsset duration (Q4=A) — PASS. Work: `ab86a2b`.
     - **9.4** Default audio: track present + Play-export listen — PASS.
       Work: `9794449`.
     - **9.5** Soft subtitle tracks out of scope; burned-in incidental —
       PASS (docs / ADR-003). No track-probe implementation.
     - **9.6** Explicit failure: iCloud-only + networkAccessAllowed=false
       → `inCloudUnavailable` (incl. PHPhotosError 3164 mapping), no export
       path; same asset with network on → controlGate PASS; N1 local+OFF
       must not false-positive — PASS. Work: `fcf7561`.
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
- Commit/PR anchor: 0738c88
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
  superseded by ADR-025 (2026-08-15; Cap 14.3 work `ce8807f`) for
  **current-item Layer 2 only**. Still binding: Layer 1 preview, ±1
  preheat, POC-10 / Overlay file-size fetches, Live motion, and any
  other path not named in ADR-025 D7; PlaybackApi ownership, detachable
  surface, 1+1 pool, and the rest of this ADR remain binding
- Commit/PR anchor: a0b99d2
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
  - **Cap 7.3 fill-in (work `29fcf2d`, 2026-08-04):** production image path
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
  - **Cap 7.5 restore wiring (work `fb82bf6`, 2026-08-06):** restore contract
    is wired — `PlaybackGateway.onPlaybackRestoreRequired` → domain
    `PlaybackRepository.restoreRequests` → `main_browse` listens and syncs
    feed index / `PageController` (empty queue ignored; index clamped).

---

## ADR-007: iOS Deployment Target = iOS 18.0

- Status: Accepted (2026-07-30)
- Commit/PR anchor: c2f5924
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
- Commit/PR anchor: 9a405df (Dart half: AppError, Result, mapping spec);
  8fed245 (wire half: Pigeon ErrorCode + ErrorCode→AppError mapping)
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
- Commit/PR anchor: 95f11f6
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
  - **Cap 7.8 accent freeze (work `0e3eec2`, 2026-08-06):**
    Renamed `accentProvisional` → `accent`. Frozen hex: Light `#FC2555`,
    Dark `#FF6B8A`. New token `brandGold` `#E0C590` (Light == Dark).
    Loading `CircularProgressIndicator` uses `brandGold`; CTA / selected
    chrome / `ColorScheme.primary` use `accent`. `onPrimary` remains
    Material `fromSeed` (not pinned). ADR-014 Decision 8 cross-references
    this note only and does not duplicate hex.

---

## ADR-010: Riverpod as production state management

- Status: Accepted (2026-08-01)
- Commit/PR anchor: 5ad1357
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
- Commit/PR anchor: 690aa0d
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
    tracked as STATE known debt; fix `7d8f022`. Prefer a public API if
    Apple ships one.
  - Opaque page cursors are index-based; library mutations mid-pagination
    can stale a cursor (acceptable for Cap 5.4 debug catalog).

---

## ADR-012: Localization guard lock (ADR-U enforcement)

- Status: Accepted (2026-08-01)
- Commit/PR anchor: 64456b4
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
- Commit/PR anchor: 6e3714d
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
  - Cap 6.2 work commit (`6e3714d`) owns the Pigeon regen and Swift host
    implementation; this ADR’s Accepted date is that commit’s author date.
  - Domain gateway / smoke UI / ~40k device acceptance remain 6.3–6.5.
  - ~40k full-list resolve cost is accepted until a future ADR says
    otherwise.
  - Kickoff Item Ordering Open Question is closed for Entire Library +
    Media Type only.

---

## ADR-014: Cap 7 slim Main Browse feed model (Sequential + Manual)

- Status: Accepted (2026-08-03); Decisions 2–3 (Sequential product
  default / deferred Shuffle for Browse Mixed) are superseded by
  ADR-023 (2026-08-13; Cap 13.4 work `10a5735`) — Main Browse Mixed
  tabs use Shuffle + Manual + Repeat All via derive + Session Queue;
  Decision 4 outcome (tab switch → feed index 0) remains binding, with
  rationale re-grounded by ADR-023 D8 (tab = new Consumption Session)
  rather than “no Session Queue model yet”; the **Decision 5 caching
  clause only** — “session-scoped cache per source (at most one real
  `resolveSource` per All / Photos / Videos per session, reuse on
  revisit)”, as detailed in the Cap 7.6 Consequences bullet — is
  narrowly superseded by ADR-024 (2026-08-15; Cap 13.8 work
  `1f8a240`): a **successful but empty** resolve is no longer cached,
  so an empty source may issue more than one `resolveSource` per
  session; the rest of Decision 5 remains binding (independent Host
  predicates per built-in, no Dart derivation of Photos / Videos from
  All’s id list, `ResolvedSourceDto` carries ids only), and so does
  the Cap 7.6 rule that failures are never stored; Decisions 1, 6–7
  and the Cap 7 Profile V-hard / Release hang split remain binding
- Commit/PR anchor: 5ef2e8a
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
  - This ADR’s Accepted anchor (`5ef2e8a`) marks the **start** of Cap 7
    implementation (Decision 8 typography / scrim tokens only).
    Decisions 1–2 / 4–7 land progressively across 7.3–7.7 — see
    PHASE_HISTORY for the full per-phase trail.
  - **Cap 7.6 session-scoped resolve cache (work `79f8c12`, 2026-08-06):**
    Decision 5 detail — successful `resolve` results for All / Photos /
    Videos are kept in-memory for the `ProviderContainer` / process
    lifetime and reused on tab revisit; failures are never stored. This
    “session” is **not** the kickoff Consumption Session (no Session
    Continuity / Session Queue product rules). Tab switch still presents
    that source’s cached (or freshly resolved) id list and resets to
    queue head (Decision 4).
  - **Cap 7.8 accent freeze:** frozen accent / `brandGold` values are
    recorded in ADR-009 Consequences (work `0e3eec2`); this ADR does not
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
- Commit/PR anchor: a721bdc
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
     Implementation (work `a721bdc`): Theme+Builder so Scaffold.backgroundColor
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
    above (`a721bdc`, phase 8.2). Decisions 1–6 land progressively across
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
- Commit/PR anchor: 5fb93de
- Plain summary (owner reads this):
  Browse top tabs no longer sit on a grey translucent band — labels float on
  the media with a light text shadow. The bottom bar stays opaque dark but uses
  a compact custom icon+label row (48 logical pixels) so Material 3 NavigationBar
  SafeArea no longer inflates the grey block; height feels closer to
  Douyin/TikTok’s compact bar while keeping destination labels.
- Context / what problem forced this:
  Cap 8.2 work `a721bdc` (ADR-015 Decision 7) paid the “opaque top bar eating
  media” debt with a Stack overlay and `mediaScrim` fill. Owner real-device
  comparison against Douyin/TikTok showed the scrim still reads as a grey color
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
    fails Douyin-style floating labels).
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
    requires labels; accept remaining thickness vs Douyin).
  - Hard-code shadow / height `Color(0x…)` or `48` inside `lib/features/**` —
    rejected (ADR-009 token discipline; architecture `Color(0x` guard; tests
    must share the same token values).
- Consequences / constraints accepted:
  - ADR-015 Status records the Decision 7 translucent/scrim clause supersession;
    forced-dark text in Decision 7 stays historically accurate and binding.
  - `mediaScrim` token remains available for other on-media chrome (e.g. future
    Overlay); it is no longer used as the top source switcher background.
  - Accepted anchor is Cap 8.2 revision work `5fb93de` (2026-08-08).
  - Cap 8 continues at phase 8.3 (Presentation Metadata); this revision does not
    open 8.3 scope.

---

## ADR-017: Main Browse bottom bar always dark (Settings pane still follows Appearance)

- Status: Accepted (2026-08-08)
- Commit/PR anchor: 60f3283
- Plain summary (owner reads this):
  The Main Browse bottom bar stays dark even when Settings is open under a Light
  system Appearance, so all four destination icons stay visible. Only the
  Settings content area follows Light/Dark Appearance.
- Context / what problem forced this:
  ADR-015 Decision 7 said Settings follows Appearance, including the shared
  bottom bar while Settings is selected. After Cap 8.2 revision (`5fb93de`),
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
  - Accepted anchor is fix work `60f3283` (2026-08-08).

---

## ADR-018: Live Photo file size — still-only Tier 4 (supersedes ADR-015 Live dual-nil)

- Status: Accepted (2026-08-10)
- Commit/PR anchor: 4f4c825
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
  - Overlay device acceptance (with work `4f4c825`): Live/video Overlay sizes
    match iOS Photos Info and Mac Finder when using decimal SI display
    formatting — do not use third-party gallery UIs as size ground truth.
  - ADR-015 Status line records this narrow Decision 5 supersession.
  - Accepted date/anchor = implementing work `4f4c825` (2026-08-10).

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
  on `pendingPlay` / new AVPlayer — work `4aa93b0` (extends Cap 9.6 Dart
  re-apply; Dart-only was insufficient). New Known debt UX-1 (visible
  spin-then-fail on offline iCloud prepare) and UX-2 (badge+spinner →
  bottom-right). No Q7 jump debt. Status remains **Accepted**; POC-08 closed
  PASS.

---

## ADR-020: Cap 10 Asset Source + Source Pool Definition domain models

- Status: Accepted (2026-08-11)
- Commit/PR anchor: 8c99d46
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
  - Accepted date/anchor = first Cap 10.2 work `8c99d46` (2026-08-11),
    per F1=A (not Cap 10 close-out; not inside the work commit).

---

## ADR-021: Cap 11 Live Resolution, Availability, Identity Coalescing, Snapshot

- Status: Accepted (2026-08-11)
- Commit/PR anchor: `95779ef` (Cap 11.2 work — first Cap 11 implementing
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
     `2cf26a6` updates `ItemOrderingPolicy.forKind` so album/smartAlbum
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
      Cap 11.2 work sha `95779ef` as anchor (F1=A / E2; not inside the
      work commit). Accepted date from
      `git log -1 --format=%cs 95779ef` → 2026-08-11.
- Rejected alternatives (why not B):
  - Album ordering via Photos collection order / ascending — not chosen
    for Cap 11; Cap 11 reuses the already-verified creationDateDescending
    Host path (ADR-013) rather than opening a new collection-order PoC.
  - List albums only in Cap 14 — rejected; Cap 11 title requires live
    album resolution and Availability.
  - List albums under Limited as `unauthorized` rows — rejected; ADR-K
    "不列出或解析" means omit from list.
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
  - Cap 11.2 landed list + mapper (`95779ef`); Cap 11.3 landed
    album/smartAlbum resolve (`2cf26a6`); Cap 11.4 landed sequential
    `resolvePool` + coalesced Snapshot (`44b783e`); Cap 11.5 landed
    composition / smoke-debug (`8e37b64`); Cap 11.6 device coalesce
    PASS (`cap11-11.6-notes.md`). Cap 11 Capability Roadmap closed in
    the 11.7 docs commit (PHASE_HISTORY snapshot).
  - Accepted date/anchor = Cap 11.2 work `95779ef` (2026-08-11), per F1=A
    (unchanged; 11.3–11.7 are later implementing / acceptance / close-out
    commits, not a new ADR).

---

## ADR-022: Cap 12 Session Queue + Default Profile + Sequential Item Ordering lock

- Status: Accepted (2026-08-12)
- Commit/PR anchor: f53d455
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
  - Accepted date/anchor = first Cap 12.2 work `f53d455` (2026-08-12),
    per F1=A (not Cap 12 close-out; not inside the work commit).

---

## ADR-023: Cap 13 Endless Shuffle + Queue Stability + in-session Continuity lock

- Status: Accepted (2026-08-13)
- Commit/PR anchor: f0187b4
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
     round’s last id (kickoff / Glossary: 应尽量避免 — mechanism
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
    mechanism (“应尽量避免”), not prose alone.
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
    were rewritten as SHUF-1…7 in Cap 13.2 work `f0187b4`.
  - Architecture suite must stay green; guard tests update with D9 seam
    in 13.4.
  - 13.6 Profile V-hard is **must-pass** to close Cap 13 when D1=A;
    hitch regression blocks close-out.
  - Release hang Known debt stays on Final performance Cap.
  - No Cap 13 Known debt **adds**; playhead row is **reclassified** in
    13.5 (not deleted without replacement wording).
  - Accepted date/anchor = Cap 13.2 work `f0187b4` (2026-08-13), per
    docs workflow (not Cap 13.1 docs and not Cap close-out).

---

## ADR-024: Cap 13.8 Browse Snapshot cache — never cache an empty resolve; a mapped failure is not “empty”

- Status: Accepted (2026-08-15)
- Commit/PR anchor: 1f8a240
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
  (b) Cap 13.4 (`10a5735`) routes per-source failures through ADR-021
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
  - Accepted date/anchor = Cap 13.8 work `1f8a240` (2026-08-15) —
    13.8b and 13.8c shipped in that single work commit; this docs
    commit is separate per two-commit discipline.

---

## ADR-025: Cap 14 current-item iCloud fetch, visual preheating, and loading states

- Status: Accepted (2026-08-15)
- Commit/PR anchor: 393ebc9
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
  ADR-006’s Cap 7.3 fill-in (`29fcf2d`) sets
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

- Status: Accepted (2026-08-16)
  <!-- Accepted date from `git log -1 --format=%cs 8189543` → 2026-08-16 -->
- Commit/PR anchor: 8189543
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
  - Cap 14.4d work commit `8189543`; device Kafka: in-item loop,
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
  <!-- Accepted date from `git log -1 --format=%cs fe660dd` → 2026-08-17 -->
- Commit/PR anchor: fe660dd
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
  <!-- Accepted date from `git log -1 --format=%cs 24debf4` → 2026-08-18 -->
- Commit/PR anchor: 24debf4
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

- Status: Proposed
- Commit/PR anchor: (none until the first implementing work commit)
- Plain summary (owner reads this):
  Stopping on a photo or video should not start an iCloud download
  until you have stayed there briefly. Leaving the item (including
  opening Settings) must stop that download. WakeTok still cannot
  delete files iOS already put in the Photos library; it can only
  download less and cancel sooner. The hitch pass bar does not change.
- Context / what problem forced this:
  Cap 13.6 Profile retest after Cap 14
  (`docs/acceptance/cap13-13.6-retest-notes.md`, HEAD `8505379`) is
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
