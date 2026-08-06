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
> Status values: Accepted | Superseded by ADR-xxx (date) | Deprecated (no
> replacement) | Reverted-in-code (implementation rolled back; see note)
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
     - kickoff「iCloud Asset 下载中断」out of POC-03 (P2=A) → Production
       Background Audio.
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

- Status: Accepted (2026-07-30)
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

- Status: Accepted (2026-08-03)
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
