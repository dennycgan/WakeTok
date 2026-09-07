# WakeTok — Phase History

Append-only archive of completed capability phase snapshots.
Each entry is appended in the docs commit (Commit 2) of the
capability's final phase. Never edit past entries.

---

## Project Bootstrap — completed 2026-07-28
- [x] 1.1 Reset docs/STATE.md + docs/DECISIONS.md to WakeTok skeletons
- [x] 1.2 Environment check: flutter --version + flutter doctor
- [x] 1.3 Scaffold: flutter create, preserve .gitignore, add pigeon/.gitkeep
- [x] 1.4 Smoke check: flutter analyze + launch on iOS simulator
- [x] 1.5 Root commit + push

Work commit sha: e41440e
Docs commit sha: f2c005e

## POC-04: Flutter Media Feed Architecture Gate — completed 2026-07-28

- [x] 2.1 Create isolated spike scaffold (lib/spikes/poc_04/, ios/Runner/Spikes/POC04/,
      pigeon/spikes/poc_04/, docs/poc/POC-04-notes.md; debug-only entry)
      — work: `ddbbf70`
- [x] 2.2 Spike Pigeon + Photos authorization + list device-local PHAssets
      — work: `ed6a7d1`
- [x] 2.3 Minimal mixed vertical feed (Fit; image temp file; AVPlayer PV; pool 1+1)
      — work: `b1b8fda`
- [x] 2.4 ≥100 mixed transitions; pool+tmp bounded (Probe 30/100); iPhone 13 Pro + 17
      — work: `2eb95f8`
- [x] 2.5 Profile measure on iPhone 13 Pro: first-frame PASS (p90=93 ms);
      hitch gate adjusted to **< 25 ms/s + no Severe Hang** (ADR-001);
      hand PV 13–19 everyday feel; Hitch Probe HN≈38 upper bound; Texture escape failed
      — work/measure notes: `5cc0b9d`, `2c9fb59`
- [x] 2.6 iCloud-only + Network Link Conditioner — **skipped**; deferred to
      Production Main Browse Screen / feed
      — work: (none)
- [x] 2.7 Record Conditional Pass in DECISIONS.md (ADR-001 Accepted)
      — docs: `f1ca720` (content), `6157b22` (Accepted + anchor);
        on `main` cherry-picks: `577b586`, `21abaf0`

Docs close-out (STATE + PHASE_HISTORY): `1d24c57`

## POC-03: Lock-screen continuous playback gate — completed 2026-07-28

- [x] 3.1 Create spike harness in lib/spikes/poc_03/ +
      ios/Runner/Spikes/POC03/; minimal AVQueuePlayer + AVAudioSession(.playback)
      setup; playback must not depend on Flutter Widget being alive
      — work: `8ec6c47`
- [x] 3.2 Verify clip-to-clip auto-advance on lock screen:
      pre-queue next AVPlayerItem; confirm audio gap is imperceptible
      or acceptable between segments
      — work: `e152181`
- [x] 3.3 Verify audio interruption and recovery
      (phone call, Siri, other audio apps; session re-activates on return)
      — work: `8b5ce36`
- [x] 3.4 Verify Control Center metadata (Now Playing info + transport controls)
      and AirPods play/pause/next
      — work: `d71723a`
- [x] 3.5 Verify process termination stops playback;
      next foreground launch can attempt SessionCheckpoint recovery
      — work: `9568f7b`
- [x] 3.6 Record go / no-go in DECISIONS.md
      (ADR-002 Conditional Pass Accepted; anchor `9568f7b`)
      — docs: `2b0538f`

Notes: `docs/poc/POC-03-notes.md`. Known debt → Production Background Audio
(WeChat/VoIP lock-home resume; iCloud interrupt; post-POC-09 physical-clip
queue verify).

## POC-09: Current Photos Representation Export Gate — completed 2026-07-29

- [x] 9.1 Spike harness + dual current/original probe + temp export;
      unedited smoke OK
      — work: `8fcac6c`
- [x] 9.2 Trim: export ≈ current; original longer; no silent original fallback
      — work: `ba72532`
- [x] 9.3 Slow-motion HFR: export duration matches Photos-displayed / PHAsset
      — work: `96e4a23`
- [x] 9.4 Default audio: track present + Play-export listen
      — work: `a4f2130`
- [x] 9.5 Subtitle scope: burned-in only; soft tracks out of scope (ADR-003)
      — docs (this close-out); no probe implementation
- [x] 9.6 Explicit failure: iCloud-only + network off → `inCloudUnavailable`
      (incl. 3164); controlGate ON; N1 local+OFF
      — work: `3883b8f`
- [x] 9.7 Record Pass (GO) in DECISIONS.md (ADR-004 Accepted; anchor `3883b8f`;
      ADR-003 Accepted same packaging)
      — docs: (this close-out commit)

Notes: `docs/poc/POC-09-notes.md`. Deferred (do not overturn Pass): slo-mo
pitch/frame-rate → Physical Clip Export Core; multi-audio UX → POC-07;
soft-sub → ADR-003 out of scope.

## App Foundation — completed 2026-07-30

- [x] 4.1 Add flutter_localizations + intl; configure gen_l10n;
      create app_en.arb (template) and app_zh_Hans.arb with one smoke
      key each; l10n.yaml sets untranslated-messages-file as the zh
      translation backlog mechanism (kickoff ADR-U §5);
      verify generated l10n.dart compiles
      (work: a73a8a3; base app_zh.arb matches zh_Hans "Localization OK"
      for Flutter gen_l10n fallback only)
      — work: `a73a8a3`
- [x] 4.2 Define shared Result<T, AppError> and AppError enum 1:1 with
      kickoff Data Contract codes plus unknown; Result combinator tests;
      native error mapping spec (R1–R6); ADR-008 Dart half
      — work: `6c1eed3`
- [x] 4.3 Production Pigeon baseline: PhotoLibraryApi + PlaybackApi
      (empty stubs); ErrorCode 1:1 AppError + mapping + exhaustive tests;
      PlaybackApi encodes ADR-006 ownership / plan / surface / restore
      vocabulary; ClipExportApi deferred; ADR-008 wire re-anchor
      — work: `e23a94b`
- [x] 4.4 Wire l10n into MaterialApp with localeListResolutionCallback:
      first preferred locale only; languageCode zh → zh-Hans (incl.
      zh-Hant); otherwise English (ADR-U §10); manual preference deferred
      to Settings; device smoke en / zh-Hans / zh-Hant→zh-Hans PASS
      — work: `473b859`

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Known debt carried forward: iOS 18 simulator smoke → Final hardening
(ADR-007); Localization Inventory → Settings and localisation completion
(kickoff ADR-U).

## iOS Photos permission, Library access, iCloud asset state — completed 2026-08-01

- [x] 5.1 Theme token baseline: lib/core/theme semantic Light/Dark tokens
      (surface / background / onSurface / accent-provisional /
      feed-background minimal set), ThemeData wired in MaterialApp,
      provisional accent; existing screens render in both modes;
      token-only styling starts here (ADR-009)
      — work `502d03a`
- [x] 5.2 Photos authorization domain + gateway: PhotoLibraryApi auth +
      presentLimitedLibraryPicker; Dart PhotosAccess + repository +
      gateway; Riverpod (ADR-010); Info.plist Usage PLACEHOLDER +
      PHPhotoLibraryPreventAutomaticLimitedAccessAlert = YES
      — work `a9443ae`
- [x] 5.3 Permission UI flows (en / zh-Hans, tokens only): Request /
      Blocked / Limited banner; Library Totals Shell landing
      — work `4665705`
- [x] 5.4 Library access + iCloud asset state model: libraryTotals +
      fetchLibraryPage; domain catalog + availability; shared
      PHFetchOptions (ADR-011); shell real counts
      — work `a7cb28a` (availability KVC fix `ff2d610`)
- [x] 5.5 Real-device acceptance on iPhone 13 Pro: M1–M8 PASS (permission
      flows; totals exact match vs Photos Media Types; Light/Dark;
      en + zh-Hans); notes `docs/acceptance/cap5-5.5-notes.md`
      — acceptance fix `be74226` (limited-picker dismiss + resume refresh)

Docs close-out (STATE + PHASE_HISTORY + acceptance notes): (this commit)

Related ADRs: ADR-009, ADR-010, ADR-011. Known debt carried: typography
tokens → Main Browse; Usage Description PLACEHOLDER → TestFlight;
PHAssetResource KVC `locallyAvailable` → Final hardening.

## All / Photos / Videos built-in source resolution — completed 2026-08-02

- [x] 6.1 Contract lock (ADR-013): freeze built-in wire shape before Swift —
      `AssetSourceKind` rename/add (`userLibrary`→`entireLibrary`,
      `mediaTypePhotos`, `mediaTypeVideos`); `AssetSourceDto` fields
      (`estimatedCount` exact for built-ins, `AssetSourceAvailabilityDto`,
      `canAddContent=false`); `listAssetSources` stays synchronous;
      `resolveSource` keeps full-list DTO (D1=A); Ordering = creationDate
      descending via shared `makeLibraryFetchOptions` (D2=A, no new PoC);
      Option A reference pairs + round-trip
      (`AssetSourceDto.sourceIdentifier` from list ==
      `SourceReferenceDto.sourceIdentifier` into resolve; only
      `all`/`photos`/`videos`); pair mismatch → `assetUnavailable`;
      D5 All-only quantile sampling via `fetchLibraryPage(cursor:q,
      pageSize:1)` + id alignment; iCloud sample reuses ADR-011 KVC only;
      year-span N owner-supplied before 6.5 (placeholder N=3); debug/smoke
      UI only (D3); list returns only three built-ins (D4); minimal domain
      AssetSource built-in kinds (D6). Design-freeze only (no Pigeon/Swift
      in 6.1).
      — work `3941283`
- [x] 6.2 Pigeon regen + Swift host: expand kind/DTO/availability enum;
      implement `listAssetSources` (three built-ins, sync counts) and
      `resolveSource` (full id list, off-main enumeration, main-thread
      BinaryMessenger reply; shared PHFetchResult helpers matching
      `libraryTotals`); no device-local filter; host pair validation on
      the three legal (kind, id) pairs. Accept ~40k id bridge cost.
      — work `ce7b850`
- [x] 6.3 Dart domain + gateway + Riverpod (ADR-009/010): minimal
      built-in AssetSource types + repository under `lib/domain/source/`
      (separate from `domain/library`); composition-root wiring;
      features do not construct gateways. Architecture + localization
      guards green.
      — work `1d2eab4`
- [x] 6.4 Debug/smoke UI (extend library_smoke): switch All/Photos/Videos;
      resolved count vs `libraryTotals`; All-only date-quantile + id
      alignment tooling; built-in labels via ARB only (wire `displayName`
      not l10n); explicit negative path — pair mismatch →
      `assetUnavailable`. No product top-bar.
      — work `6be43d4`
- [x] 6.5 Real-device acceptance (iPhone 13 Pro + owner ~40k library):
      counts exact; full library incl. iCloud-only; All date-distribution
      sampling (N=3; epoch exclude; span = maxYear−minYear); ≥1
      `iCloudNotDownloaded`; M9 Limited subset list/resolve; notes under
      `docs/acceptance/cap6-6.5-notes.md`. Cap 6 capability close-out
      (STATE + PHASE_HISTORY; ADR-013 already Accepted at 6.2 docs).
      — acceptance on `c47f77d` (feature work through `6be43d4`)

Docs close-out (STATE + PHASE_HISTORY + acceptance notes): (this commit)

Related ADR: ADR-013. Known debt carried: Library Totals Shell raw
exception error row → Settings and localisation completion (ADR-012).

## Main Browse Screen and vertical Media Feed — completed 2026-08-06

- [x] 7.1 Contract freeze (ADR-014): Cap 7 slim feed model — ephemeral id
      queue from Cap 6 resolve only; Sequential + Manual (kickoff General/
      Mixed default Shuffle deferred until Endless Shuffle capability);
      chrome In/Out; Pools tab visible+disabled; tab switch resets to
      queue head; smoke demoted from default landing; Live Photo = static
      (+ optional LIVE badge). Freeze Severe Hang / hitch bar for 7.7:
      iPhone 13 Pro, **Instruments Profile** (same mode as ADR-001
      baselines; Release not mixed into the gate — optional Release notes
      only as a separate secondary dataset if owner later asks); mean hitch
      < 25 ms/s AND **zero** Severe Hang (hard gate; no Conditional Pass
      rewrite of ADR-001). **Retest surface must be full production chrome**
      (top All/Photos/Videos + disabled Pools tab + bottom bar shell) — not
      a bare PageView; POC-04 spike had no chrome, so hitch may regress once
      chrome is mounted. Design-freeze (no production feed code in 7.1).
      ADR-014: Accepted at Cap 7.2 work `66d8c96` (see DECISIONS).
      — docs `a6462ab`

- [x] 7.2 Theme tokens for feed chrome: typography scale tokens (ADR-009
      Known debt); feed scrim / on-media contrast tokens as needed; still
      `accentProvisional` (freeze in 7.8 only).
      — work `66d8c96`

- [x] 7.3 Playback + image pipeline (ADR-006): production foreground
      PlaybackApi path — PV attach/detach, bounded 1+1; image display
      request path; no Background Audio / Now Playing product scope.
      — work `07d10d6`

- [x] 7.4 Main Browse chrome shell: top All/Photos/Videos + Pools disabled
      (ARB Coming soon on-cell; no tap SnackBar); bottom NavigationBar
      (Browse active; Clips/Auto/Settings stub; explicit indicatorColor
      token); Main Browse = default post-auth landing; library_smoke
      debug-only via Settings; Limited banner kept.
      — work `4ee414c`

- [x] 7.5 Vertical Media Feed: PageView (or equivalent) over ephemeral
      queue; Manual swipe; wire resolve(All|Photos|Videos); pool/preheat
      bounds (ADR-P.5 spirit); architecture + localization guards green.
      — work `a4388ad`

- [x] 7.6 Source switch behavior: changing top tab rebuilds ephemeral
      queue from Cap 6 resolve and starts at queue head; no Pool model;
      no Session Continuity product rules; session-scoped successful
      resolve cache per built-in (ADR-014 Decision 5; process lifetime;
      failures uncached; “session” ≠ Consumption Session).
      — work `14f28d7`

- [x] 7.7 Real-device feed acceptance (iPhone 13 Pro, **Profile**): scroll
      real library; hitch < 25 ms/s AND no Severe Hang per 7.1 hard gate;
      notes under `docs/acceptance/`. Campaign recorded **FAIL** then
      **INVALIDATED as Profile gate** (errata: actual install was **Release**
      via `build`+`install --release`; tables retained as Release forensic
      only — `cap7-7.7-notes.md`). Hard bar unchanged. Fail path was
      suspended pending 7.7a (later **not** taken — 7.7a PASS).
      — docs `58b62d4` + errata `104d59d`

- [x] 7.7a Profile hard-gate retest: Videos×3 + All×3, **same V-hard** rules,
      **Profile only** (`flutter build ios --profile` +
      `flutter install --profile`). Doomscroll intensity credibility **yes**.
      **PASS** 2026-08-06 (Videos ≈0.29/0.89/0.98; All ≈2.7/8.2/1.9 ms/s;
      zero Severe Hang). Notes `cap7-7.7a-profile-retest-notes.md`.
      — docs `e4f662d`

- [x] 7.7b Severe Hang diagnosis — **N/A** (7.7a Profile PASS; diagnosis path
      not required). Notes left paused/cancelled:
      `cap7-7.7b-hang-diagnosis-notes.md`.

- [x] 7.7c Fix hang root cause — **N/A** (no 7.7b).

- [x] 7.7d Profile re-retest after fix — **N/A** (no 7.7c). ADR-015 **not**
      required on this PASS path.

- [x] 7.8 Accent freeze (last) + Cap 7 close-out: rename
      `accentProvisional` → `accent` (Light `#FC2555`, Dark `#FF6B8A`);
      add `brandGold` `#E0C590` (L==D); Loading spinners → `brandGold`;
      CTA / selected chrome → `accent`. Same docs commit: clear Profile
      Severe Hang / typography / final-accent Known debt rows; add Browse
      forced-dark + opaque top-bar debts (Media Info Overlay); ADR-009
      Consequences + ADR-014 cross-ref; STATE + PHASE_HISTORY. Portfolio
      Public scan remains owner-only. **Release hang** Known debt stays.
      — work `009f804`

Docs close-out (STATE + PHASE_HISTORY + ADR-009/014): (this commit)

Related ADRs: ADR-001, ADR-006, ADR-009, ADR-010, ADR-012, ADR-014.
Known debt carried: Release hang → Final hardening; Browse forced-dark +
opaque top bar → Media Info Overlay; Portfolio Private→Public scan
owner-only (eligibility met).

## Media Info Overlay, loading states, empty states,
POC-10 file-size semantics, optional best-effort Location Label
— completed 2026-08-10

- [x] 8.1 Contract freeze: Overlay four-row contract (row 4 omitted this
      Cap); POC-10 Tier policy (Tier 1 Unavailable; Tier 2 slot; enable
      3/4); immersive chrome scope Q2=B; progressive field updates;
      ADR-015 wide draft approved in chat (Accepted at 8.2 work `e058e32`)
- [x] 8.2 Immersive Browse chrome: forced-dark for Browse/Clips/Auto
      destinations; shared bottom bar always dark (even on Settings);
      Settings *pane* follows Appearance. Initial work `e058e32`
      (ADR-015). Revision `3c7aa1d` (ADR-016): transparent top + compact
      custom bar. Fix `9c05462` (ADR-017): bar always dark on Settings.
      Pays forced-dark + opaque-top Known debts.
- [x] 8.3 Presentation Metadata: Pigeon + gateway + domain; current-page
      only; two HostApi calls (`requestPresentationMetadata` then
      `requestPresentationFileSize`) for progressive fields
      (`creationDateMs?`, required `mediaKind` on success,
      `fileSizeBytes?`, `fileSizeSemantics?`); host Tier 3/4
      implemented. Work `79dc3bc`. Feature-layer FeedMediaRequestGate
      staleness discard + Overlay consumer landed in 8.5 (`f33c99e`).
- [x] 8.4 POC-10: device-confirm safe Tier 3/4 paths already in `79dc3bc`;
      M1–M6 PASS; M7 N/A (no RAW+JPEG in owner library); Browse hitch
      qualitative OK. Notes: docs/acceptance/cap8-8.4-poc10-notes.md
      (2026-08-09; M2/M3 follow-ups + ADR-018). Temporary debug probe
      discarded (never on `main`). No host fix at 8.4 close-out.
- [x] 8.5 Media Info Overlay UI: fixed-height rows 1–3; row 4 hidden when
      `locationLabel` empty (no geocode); progressive paint; ARB; Live
      label + still size (ADR-018 Tier 4); dual-gate sync via
      `FeedActivationCoordinator`; session Overlay cache + background
      refresh. Work `f33c99e`; docs ADR-018 `9b3fcb0`; session-cache
      regression `W-O-cache` with this close-out.
- [x] 8.6 Loading / Empty product polish: shared `_BrowseStatusPanel`;
      resolve vs per-page Keys; per-page loading spinner-only (D1);
      W-L1–W-L6 (Overlay independence on per-page iCloud/failed). Work
      `baccc62`. No Waiting for Media / Source Availability surfaces;
      no new ADR.
- [x] 8.7 Location deferral close-out: W-Loc1 (whitespace trim) + W-Loc2
      (feed Row2 exact + Row3 size fixture land; no Row4). Work `eb257c1`.
      No geocode; Known debt unchanged; no formal device notes; no new ADR.
- [x] 8.8 Real-device acceptance: H1/S1–S4/C1/S3-format PASS; A1 leave-video
      audio leak fixed (`9b0dc46`) + device retest PASS; W-O-prog. Notes:
      docs/acceptance/cap8-8.8-notes.md. Not a Cap 7.7a re-gate; no new ADR.
- [x] 8.9 Cap 8 close-out: STATE + PHASE_HISTORY; Location Known debt
      remains; forced-dark / opaque-top cleared at 8.2; cross-source
      playhead Known debt recorded (Session Continuity revisit).
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-015, ADR-016, ADR-017, ADR-018 (Live still size narrow-
supersedes ADR-015 Live dual-nil). Known debt carried: Location Label
(geocode deferred); same-asset cross-source playhead (Session Continuity);
file-size disclaimer copy. Forced-dark + opaque-top debts paid in 8.2.

## Live Photo rendering and static fallback (POC-08)
— completed 2026-08-11

- [x] 9.1 Contract freeze: Q1–Q7; LivePhotoApi + viewType; visible PV
      exclusivity; `PlaybackApi.clearPlaybackPool()` (Dart await before
      LivePhotoApi; host race guards; Live-activation-only clear — stills
      stay pause-only); Q7 unload PV→still; Known debt table rows not
      cleared; POC-08 Success Criteria locked (items 1–8; #5 observe
      iCloud download state changes in 9.7 notes without progress-copy
      UI; #8 plugin vs native — recorded rationale: no first-party
      PHLivePhotoView plugin; photo_manager-class packages expose
      still+paired video files for DIY VideoPlayer, not Photos-parity
      PHLivePhotoView lifecycle/mute/styles — self-built Pigeon+PV);
      ADR-019 drafted in chat; Accepted at Cap 9.2 work
      — docs `9a46306` (roadmap) / work `8920120`
- [x] 9.2 Native host: PHLivePhoto request + PHLivePhotoView factory;
      `clearPlaybackPool` + clear-in-flight guards; cancel/failure;
      Pigeon LivePhotoApi + clearPlaybackPool channels (D1=A);
      D3 gesture recognizer disabled; ADR-019 appended
      — work `8920120` (ADR anchor `98fe191`)
- [x] 9.3 Pigeon + gateway + domain (current-page only); composition root
      (channels already in 9.2; Dart LivePhotoRepository + LivePhotoGateway
      + clearPlaybackPool on PlaybackRepository; no Feed wiring)
      — work `72a3a04`
- [x] 9.4 Feed integration: Live current → await clear → play-once →
      Q7 still; leave/re-enter; Overlay/badge coexistence; F4
      feed-scoped `LiveHostOpSerial` + activation generation; host
      cancel/stop main-sync; no motion spinner (intentional interim —
      Q4=A spinner in 9.5, not Known debt)
      — work `db7a3e4`
- [x] 9.5 iCloud / failure: static-first + spinner-only; static fallback;
      no auto-skip (not Waiting for Media product surface); badge-adjacent
      preparing spinner; all `_livePreparing` writes via `gatedFlagUpdate`
      (L-S6 defensive seam `debugSetLivePreparing`)
      — work `6f386c2`
- [x] 9.6 Mute preference binding (default unmuted) + Playback Style
      matrix (POC-08 #4 / #7); re-apply shared mute after video pool
      rebuild (ADR-019 Consequences reminder); `sharedMuteProvider`;
      Live `setMute`+`startPlayback` in one `LiveHostOpSerial` op;
      video `setMute` before `play`; library_smoke debug toggle;
      Style observation template for 9.7
      — work `8fcd875`
- [x] 9.7 Device POC-08 acceptance (iPhone 13 floor + 17 compat; Profile;
      local + iCloud + weak net; Q7 switch feel; item #5: note observed
      iCloud download state changes during motion prepare; items 1–8
      gate); notes under docs/acceptance/; POC Result/Decision →
      ADR-019 close
      — notes `docs/acceptance/cap9-9.7-poc08-notes.md`; mute host
      persist mid-gate `474fb6a`; Style matrix filled; 17 P5–P7 N/A
      — docs `4ed013c`
- [x] 9.8 Cap 9 close-out: STATE Cap `[x]` + YOU ARE HERE + PHASE_HISTORY;
      Known debt: no table-row clears; UX-1/UX-2 from 9.7 retained
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-019 (Live Photo / clearPlaybackPool / POC-08 Result).
Known debt carried: UX-1 (brief visible spin-then-fail on offline/weak-net
iCloud Live prepare); UX-2 (LIVE badge + spinner → bottom-right). No Cap 9
table-row clears. Prior debts (Location, playhead, file-size disclaimer,
Release hang, Portfolio scan, etc.) unchanged.

## Asset Source and Source Pool Definition domain models
— completed 2026-08-11

- [x] 10.1 Contract freeze: D1–D9 / F1–F2; ADR-020 Proposed;
      GLOSSARY Cap 10 note; Out-of-scope locked
      — docs `c1692d8`
- [x] 10.2 Domain kinds + SourceReference: album/smartAlbum;
      built-in pairs kept; exhaustiveness arms; mapper untouched
      — work `00b52ad`; ADR-020 Accepted docs `73aa7b3`
- [x] 10.3 SourcePoolDefinition + PersistencePolicy + ADR-P
      (30 validate / 10 constant); Q1–Q3=A
      — work `894aef8`; docs `76add91`
- [x] 10.4 ItemOrderingPolicy.forKind (creationDateDescending /
      unspecified); ORD unit tests + architecture green
      — work `4fa2104`; docs `0e731c1`
- [x] 10.5 Cap close-out: STATE Cap `[x]` + YOU ARE HERE +
      PHASE_HISTORY; Phase Roadmap → Live Resolution placeholder
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-020 (Accepted, anchor `00b52ad`).
Known debt: no Cap 10 table-row adds or clears. Prior debts unchanged
(Location, playhead, file-size disclaimer, Release hang, UX-1/UX-2,
Portfolio scan, etc.).

## Live Resolution, Asset Source Availability,
Identity Coalescing, and Resolved Pool Snapshot
— completed 2026-08-12

- [x] 11.1 Contract freeze: owner Cap 11 review (D1–D6); ADR-021 Proposed
      (Limited list omits Album/Smart; sequential multi-source resolve;
      Album ordering = creationDateDescending); Out-of-scope locked
      — docs `8ebc1ec`
- [x] 11.2 Host list: User Album + Smart Album + Availability;
      open domain↔wire album/smartAlbum mapping; Limited: albums absent
      from list (ADR-K); `other` still throws
      — work `5179ac1`; device notes `cap11-11.2-notes.md`;
        ADR-021 Accepted docs `d4ed3ac`
- [x] 11.3 Host resolve: album/smartAlbum with creationDateDescending;
      Availability on resolve; Limited resolve → unauthorized
      — work `d1d01f0`; device notes `cap11-11.3-notes.md`;
        docs `5ff91ba`
- [x] 11.4 Domain: ResolvedPoolSnapshot + Identity Coalescing
      (first appearance) + sequential resolvePool(SPD); partial-source
      failure non-blocking (Glossary §16)
      — work `fd22ece`; unit tests SNAP-1…12; docs `7e5ba45`
- [x] 11.5 Composition / smoke-debug wiring (Main Browse unchanged, D4=A);
      architecture green
      — work `d76dbe3`; Photos+All smoke probe; main_browse ↛
        `resolve_pool.dart`; docs `e543424`
- [x] 11.6 Acceptance: unit tests + device multi-source coalesce
      (iPhone 13 floor + 17)
      — work `d76dbe3`; HEAD `e543424`; notes `cap11-11.6-notes.md`;
        docs `a294f82`
- [x] 11.7 Cap close-out: STATE Cap `[x]` + YOU ARE HERE +
      PHASE_HISTORY; Phase Roadmap → Session Queue placeholder
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-021 (Accepted, anchor `5179ac1`).
Known debt: no Cap 11 table-row adds or clears. Dual User Album overlap
deferred to Cap 14 (not a Known debt row). Prior debts unchanged
(Location, playhead, file-size disclaimer, Release hang, UX-1/UX-2,
Portfolio scan, etc.).

## Session Queue, Default Session Profile,
and stable Item Ordering Semantics
— completed 2026-08-12

- [x] 12.1 Contract freeze: owner review D1–D6=A; ADR-022 Proposed
      (derive ≠ apply; segmentIndex = resolve-time; OrderPolicy
      includes shuffle, builder refuses it); Out-of-scope locked
      — docs `a8aa831`
- [x] 12.2 Domain: OrderPolicy / AdvanceMode / RepeatPolicy +
      SessionConfiguration
      — work `87d7dce`; ADR-022 Accepted docs `5fdfede`
- [x] 12.3 Default Session Profile derivation
      (current pools always General/Mixed; Pure Clip reserved)
      — work `c516c19`; docs `6b5ecf2`
- [x] 12.4 Sequential Session Queue builder + ADR-M Sequential
      contract unit tests; shuffle branch documented refuse;
      acceptance: Mixed `deriveDefaultSessionProfile` output fed
      directly into `buildSessionQueue` must hit the documented
      refusal path (not covered by testing the two functions alone)
      — work `0f622a5`; docs `8eee755`
- [x] 12.5 Composition / smoke-debug only (Main Browse unchanged,
      D1=A); architecture guard main_browse ↛ build_session_queue;
      architecture green
      — work `1b4b8d9` (guard only; no smoke); docs `3ff004c`
- [x] 12.6 Acceptance: unit tests (no device PoC; D1=A);
      docs-only; verified at HEAD `3ff004c`; full `flutter test`
      PASS (+247); session CFG/DPR/SQ + architecture green;
      ADR-022 D1–D6 contract checklist PASS; no
      `docs/acceptance/cap12-12.6-notes.md` (unit-only — acceptance
      notes files are for device/manual evidence, not pure unit gates);
      Known debt unchanged
      — docs `894c74c`
- [x] 12.7 Cap close-out: STATE Cap `[x]` + YOU ARE HERE +
      PHASE_HISTORY; Phase Roadmap → Endless Shuffle placeholder
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-022 (Accepted, anchor `87d7dce`).
Known debt: no Cap 12 table-row adds or clears. Same-asset playhead
All↔Videos remains Cap 13 (not paid here). Prior debts unchanged
(Location, playhead, file-size disclaimer, Release hang, UX-1/UX-2,
Portfolio scan, etc.).

## Current-item iCloud media fetch, visual
preheating, and loading states
— completed 2026-08-18

- [x] 14.1 Contract freeze: ADR-025 Proposed (no Accepted date, no
      fake anchor); Capability Roadmap reorder; Parked Cap 13;
      Known debt Picks it up → Cap 14; Auto-play lookahead row renamed
- [x] 14.2 Host Layer 1: `requestPreview` (local still + video poster)
      + cancel (work `a980506`)
- [x] 14.3 Host Layer 2: current-item `requestDisplayAsset` /
      `requestPlayableVideo` may use network + cancel
      (work `92c3a60`; ADR-006 Status narrow supersede this docs
      commit)
- [x] 14.4 Feed three-layer UI + ARB; retire
      `mainBrowseFeedICloudOnly` (work `9bfc4c7`)
- [x] 14.4b First-launch cellular retry + failure-reason copy
      (work `8a827e4`); Overlay file-size refresh after Layer 2
      (work `43c984a`; Kafka same-page size PASS)
- [x] 14.4c Browse↔Settings keep-alive: unconditional IndexedStack
      Theme wrap (work `9eecc7e`; Kafka non-head still+video
      Settings round-trip PASS); resume activation latch;
      off-current `_startLoad` identity lock + neutral placeholder
- [x] 14.4d Video item loop + replay on return-to-ended
      (work `24dbb88` / ADR-026; Kafka: in-item loop, return-to-ended
      replay, mid-play seek preserve, dead-file preview reload,
      Live play-once; ADR-006 D4 background plan-end still no loop)
- [x] 14.4e Leave Browse resets queue (work `5658cf2` / ADR-027;
      Kafka: Settings/Clips leave → new Shuffle + index 0;
      AppLifecycle does not reset; APP-8/8b/8c)
- [x] 14.5 ±1 local-only visual preheat + cancel on leaving the window
      (work `e278f65`; Kafka: neighbour Layer 1 more often present;
      video neighbour poster / no audio; two-step skip does not
      cap-3-evict the current preview)
- [x] 14.6 Limited first-launch All: keep resolve-loading on successful
      empty + bounded re-resolve (3 extra attempts, 500/1000/2000 ms)
      (work `d32a309` + `b9c2d68`; Kafka Profile: grant Limited → All
      shows loading then content, not empty copy; resume during picker
      does not start All resolve; `requestAccess` complete restarts
      Browse)
- [x] 14.6b Item load chrome: LIVE badge + Layer 2 / Live-prepare
      spinner bottom-right (`_FeedCornerChrome`; display =
      `_layer2InFlight || _livePreparing` with same-setState handoff).
      Non-Live spinner uses a zero-width badge strut so vertical
      slot matches Live. Library resolve loading stays centered.
      Overlay `trailingInset` 123 (measured). Does not change 13.6
      risk (UI/presentation only; no Host request timing /
      concurrency / dedupe). Not Cap 15. Work `77afb23`; Kafka
      Profile PASS
- [x] 14.6c Default Fit (contain / resizeAspect / scaleAspectFit)
      + portrait-only (`Info.plist` + `SystemChrome`). Not the
      Fit/Fill/Crop rail. Work `d70fddf` / ADR-028; Kafka Profile
      PASS
- [x] 14.7 Cap 14 close-out docs: Cap 14 `[x]`; return YOU ARE HERE
      to Cap 13; 13.6 unblocked as executable at the unchanged
      V-hard bar; Instruments not run in 14.7
      (ADR-025 Accepted is the docs commit after 14.2, not 14.7)
      — docs (this commit)

Limited Access product chrome unmount (work `01a7611`, docs
`a2b54f9`) landed after 14.6b and is **not** a numbered Cap 14
phase. See Known debt: iOS Photos permission / Limited Access
product chrome unmounted from Main Browse.

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-025 (Accepted, anchor `a980506`); ADR-006 Status
narrow supersede (anchor `92c3a60`); ADR-026 (Accepted, anchor
`24dbb88`); ADR-027 (Accepted, anchor `5658cf2`); ADR-028
(Accepted, anchor `d70fddf`).
Known debt: Limited Access product chrome unmounted (`01a7611`);
iCloud video no Layer 1 poster (MVP-acceptable); Cap 15 Layer 1→2
handoff + duplicate Layer 2 rows unchanged. Do not rewrite 13.6
FAIL tables. Prior debts unchanged (Release hang, Location,
file-size disclaimer, UX-1, Portfolio scan, etc.).

## Cancel and dwell current-item Layer 2 fetch
— completed 2026-08-19

- [x] 16.1 Contract freeze: ADR-029 Proposed (no Accepted date, no
      fake anchor); Capability Roadmap insert; Parked Cap 13; Known
      debt Picks it up → Cap 16
      — docs: `07c63a3`
- [x] 16.2 Host `cancelInFlightPrepare` + Dart leave/dispose/leave
      Browse (#1+#4); `flutter test` including `test/architecture/`
      — work: `255656d`; docs (ADR-029 Accepted): `bcc6d3a`
- [x] 16.3 Plan ≠ download: `setPlaybackPlan` must not `prepareActive`;
      `load` completes on success/fail/cancel; feed drops
      `requestPlayableVideo` download; that API is duration-only
      (#2). Re-align `_layer2InFlight` with the new `load` completion
      — work: `22ece57`; docs: `3db80b1`
- [x] 16.4 Dart dwell N=500 ms (initial; still + video Layer 2);
      Retry / resume-failed bypass; neighbour promote and Endless
      first item do not; keep `_layer2InFlight` true during dwell
      — work: `26294f5`; docs (ADR-025 D2 timing note): `4845075`
- [x] 16.5 Device: storage replication + All/Videos hitch notes
      (bar unchanged; Endless round PASS; N=500 dwell-feel
      unverified). Cap 16 `[x]` does **not** require 13.6 PASS
      — docs: `68db7a5`; notes `docs/acceptance/cap16-16.5-notes.md`
- [x] 16.6 Cap close-out: YOU ARE HERE returns to Cap 13; 13.6
      still FAIL until retest (now executable). ADR-029 Accepted
      (16.2 docs, anchor `255656d`); ADR-025 D2 timing note landed
      with 16.4
      — docs (this commit)

WT16 throwaway probe logs were never committed; removed from the
working tree at close-out.

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-029 (Accepted, anchor `255656d`).
Known debt: product storage leak path paid; 13.6 hitch still FAIL
(`143f274`); Layer 1 miss centered spinner → Cap 15; do not rewrite
13.6 FAIL tables. Prior debts unchanged (Release hang, Location,
file-size disclaimer, UX-1, Portfolio scan, etc.).

## Endless Shuffle, Queue Stability, and Session Continuity
— completed 2026-08-19

- [x] 13.1 Contract freeze: owner review D1–D9=A; ADR-023 Proposed
      (Browse Shuffle product apply; slim ConsumptionSession;
      zero Checkpoint/SQLite; Manual Shuffle = full Snapshot;
      injectable Random + first≠last retry; playhead debt
      reclassified Accepted not bug-fix; tab = new Session;
      composition-seam guard update); Out-of-scope locked
      — docs `2fde80f`
- [x] 13.2 Domain: Endless Shuffle in `buildSessionQueue`
      (Fisher–Yates + round reshuffle + first≠last best-effort;
      injectable Random; Cap 12 UnsupportedError removed)
      — work `1d15caf`; docs (ADR-023 Accepted): `5733173`
- [x] 13.3 Domain: Queue Stability + in-session Continuity
      (rebuild mapping; slim ConsumptionSession; no
      SessionCheckpoint persistence)
      — work `7fa4aa4`; docs `bd1823d`
- [x] 13.4 Product apply: Main Browse Mixed → derive + Shuffle
      Queue; supersede ADR-014 Sequential product default via
      ADR-023; composition / guard update (D9=A)
      — work `aa03be8`; docs `dbd261e`
- [x] 13.5 Playhead debt reclassification (D6=A): Known debt row
      reworded Accepted behaviour — not a bug fix (D8=A: tab =
      new Session; cross-tab Continuity not in Cap 13); no
      PlaybackApiHost code change
      — docs `ccace05`
- [x] 13.6 Acceptance — closed under **ADR-030 §5** (everyday
      availability, owner 2026-08-19); **not** an Instruments
      numeric Pass. FAIL tables stay frozen
      (`docs/acceptance/cap13-13.6-notes.md`,
      `docs/acceptance/cap13-13.6-retest-notes.md`); they do
      **not** represent the current bar.
      Timeline while the old V-hard gate was still the closer:
      FAIL `96f081c` → 13.6b hang campaign stopped as
      inexecutable `5fcfdc8` → Profile retest FAIL `143f274` →
      close `162ed8e` (anchor fill `6a100c7`).
- [x] 13.8 Browse empty / failure feed + claim Endless gesture
      (opened after 13.6 blocked; does **not** close or relax
      13.6). Listed here in the order it ran, not renumbered
      ahead of 13.6.
      - [x] 13.8a claim the Endless last-page gesture already on
            `main` — work `afd2507`
      - [x] 13.8b mapped `unauthorized` / `unavailable` with empty
            coalesced ids now shows the resolve-failed panel +
            Retry instead of empty copy (**13.4 regression**) —
            work `1a4f316`
      - [x] 13.8c never cache an empty coalesced Snapshot
            (**Cap 13 scope expansion** — fixes pre-13.4 ADR-014
            D5 behaviour; not part of the 13.4 regression) —
            work `1a4f316`
      - [x] 13.8d Acceptance: APP-6/APP-7 + W-F4b/W-S1b and full
            `flutter test` green; device Kafka Profile Limited
            first-launch All → Photos/Videos → All has content
            **without force-quit** = PASS; `unauthorized` path
            unit-only by owner decision; no Instruments in 13.8
      - [x] 13.8e docs: ADR-024 + ADR-014 D5 cache-clause narrow
            supersede; 13.6 blocked reason; Known debt row for
            Limited first-launch All
            — docs `3c16c91`
- [x] 13.7 Cap close-out: STATE Cap `[x]` + PHASE_HISTORY;
      Phase Roadmap → Cap 15 placeholder (owner-approved phases
      later). Cap 14 and Cap 16 already `[x]`. Do not start Cap
      15 code. Layer 1 miss / black cover / swipe flash stay
      Known debt → Cap 15.
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-023 (Accepted, anchor `1d15caf`); ADR-024
(Accepted, anchor `1a4f316`); ADR-030 (Accepted, anchor
`162ed8e`).
Known debt: 13.6 closer is ADR-030 §5, not an Instruments Pass;
do not rewrite 13.6 FAIL tables. Layer 1 miss / iCloud no-poster /
swipe flash / duplicate Layer 2 → Cap 15. Prior debts unchanged
(Release hang, Location, file-size disclaimer, UX-1, Portfolio
scan, etc.).

## Feed swipe Layer 1→2 handoff polish and
duplicate current-item Layer 2 request
— completed 2026-08-24

- [x] 15.1 Device diagnosis probe — throwaway probe **never
      committed**; evidence `docs/acceptance/cap15-15.1-notes.md`
      (`c6a9ca3`). Kafka 2026-08-20 Debug. M3 A1 (stills + videos);
      M2 ≠ 1 so 15.4 is a real fix; Q2 no delay-before-show
- [x] 15.2 Contract freeze — ADR-031 **Proposed** (`c6a9ca3`; no
      Accepted date, no fake anchor). Diagnosis-before-contract
      recorded. Q1=A1 512×512; Q2=A no delay-before-show; Q3=A;
      Q5=B; 393 related-not-equivalent; 15.4 real fix; M1/M2 Debug
      limit; M3 order protocol not executed (index odd/even only).
      Peak-memory baseline is a **hard gate before 15.5**, not
      optional. Three-axis Cap 16 invariant (ADR-030 language).
      Non-goal: Limited banner remount
- [x] 15.3 Layer 1-miss chrome unified to `_FeedCornerChrome`
      (debt 399+398); **no** delay-before-show. Work `962b6d1`;
      ADR-031 Accepted in this docs commit (anchor `962b6d1`).
      UX-1 (402) incidental; owner judges at 15.8. Kafka device
      chrome PASS (miss corner; library loading still centered)
- [x] 15.4 Single current-item activation (debt 396) — **real
      fix** (M2 `preview_supersede` ≠ 1), not verify-only. Work
      `d532064`; join in-flight L1 on neighbour→current promote.
      Kafka 2026-08-20 Debug WT15 (uncommitted): M1+2 five
      `page_changed`, zero `preview_supersede`; M1 one
      `layer2_load_start` per become-current
- [x] 15.5 Still Layer 1→2 gapless handoff (debt 394 stills).
      Work `2f24593` (gapless `563f2d4`/`32d4d09` + sized decode
      `ResizeImagePolicy.fit`). Kafka Round 4 **PASS**: Fit flash
      none; aspect vs iOS Photos spot-check OK; no jetsam /
      force-quit / sustained climb. Memory not Round-3-systemic; do
      **not** bite ≈261. S2≈334 = pre-existing slow iCloud + gapless
      + preheat overlap (not a sized-decode regression) —
      `cap15-15.5-notes.md`. Keep 14.4d latch. Debt 394 **video**
      remains 15.7.
- [x] 15.6 Layer 1 local-hit A1: Host `previewTargetSize` **512×512**
      (debt 400; ADR-031 Q1=A1). Work `9eef9db`. Kafka Protocol B
      (Full vs Limited same 16 ids): Full 16/16 ok all ~120; Limited
      13×512-edge ok + 3 miss. **Inferred:** Full falls back to a
      fixed ~120 thumb tier; Limited searches by `targetSize` (no
      same fallback). 512 helps **Limited** hit-rate; Full never-black
      is largely independent of 512/1080. Debt 400 **open** (Limited
      residual miss = PhotoKit Limited + local-only; Host cannot
      invent pixels). Notes `cap15-15.6-notes.md`. Optional later:
      trial `deliveryMode = .fastFormat` (unvalidated).
- [x] 15.7 Video leave-current frame retention (debt 394 video
      peek-black); does not change the ADR-006 1+1 player /
      Platform View contract. Work `bb3d5e2` (2026-08-22). Keep
      `video`+poster kind on leave; poster stable Stack index 0;
      UiKitView only while current. Kafka Full/Limited: posted
      video peek shows Layer 1 (PASS). Limited video L1-miss N/A
      this session (does not close 400). Settle flash of previous
      video **with audio** = debt **393** (not 15.7).
- [x] 15.8 Device acceptance — ADR-030 §5 owner daily-use
      confirmation + per-debt before/after table (incl. 393 and
      UX-1 verdicts) + storage on the 16.5 protocol
      (explainable-as-watched) + peak-memory narrative per
      `cap15-15.5-notes.md` (qualitative; no MB hard bar). Kafka
      2026-08-22 Profile PASS — `cap15-15.8-notes.md`. Storage M7
      **qualitative only** (no numeric before/after this session —
      weaker than 16.5/15.1 protocol; see notes). 393/400 still
      open. 393 explore **paused** for 15.10.
- [x] 15.10 Session L2-ready skip Layer 1 on revisit — local /
      already-L2-completed items must not blur-first on second+
      become-current in the same Browse Session. **v1: revisit only**
      (no public PhotoKit pre-check — STATE Known debt
      `locallyAvailable` KVC). Work `62a5a2b`. Kafka 2026-08-22
      Profile PASS — `cap15-15.10-notes.md`. Cap 16 M7 PASS
      qualitative-only (no numeric re-record). ADR-025 narrow supersede
      (this docs commit). 393/400 still open. 393 explore **paused**
      (scope gap: peek phase — see notes §G).
- [x] 15.11 Shared PV transition guard (393 peek + settle) +
      handoff deadlocks — cover + transition mute; Host
      **ready-for-display** trust (ADR-032; attach-ack retained but not
      unwrap); 15.11b poster-hold / settle-on-target (cover vs audio
      split) / stale feed-index re-arm / `_layer2InFlight` generation
      clear. Design: `cap15-debt393-explore-scope.md`. Work `9d546f2`.
      Kafka + i17 Profile PASS — `cap15-15.11-notes.md`. Debt **393
      closed**. Debt **400** still open. iCloud load UX clue → Known
      debt (separate).
- [x] 15.12 Local first-visit skip L1 (deviceLocal) — work
      `cefa448` (2026-08-24). Become-current skip Layer 1 when
      `AssetAvailability.deviceLocal`. Widget W-15.12*. Kafka
      large-library later stalled on resolve-time full availability
      scan ("Loading library…") — **fixed by 15.15**, not rolled back
      here. i17 small/mostly-local hid the stall.
- [x] 15.13 Stale preview heal — work `a3d0375` (2026-08-24).
      Session `lookupIfCoverOnDisk` evicts token when cover file
      gone. Widget coverage; device verified in the 15.12–15.14c
      Kafka/i17 chain (no separate notes file).
- [x] 15.14 Peek cover reuse on deviceLocal become-current —
      work `d948f2e` (2026-08-24). Skip second `requestPreview` when
      peek file still on disk (W-15.14a). Device: same chain.
- [x] 15.14b Arm poster-hold at L2 apply when `canReuseCover` —
      work `18a2af8` (2026-08-24). W-15.14b. Kafka still showed
      intermittent revisit peek black-flash when peek file already
      evicted (`canReuseCover=false`) — covered by 15.14c.
- [x] 15.15 resolveSource empty availabilities + on-demand
      `getAssetAvailabilities` — work `b8071a1` (2026-08-24);
      ADR-033. Kafka Profile 2026-08-24: "Loading library…" reasonable
      duration **PASS**.
- [x] 15.14c DEVICE_LOCAL L2 apply always arms poster-hold —
      work `5667a09` (2026-08-24). W-15.14c (dead peek file).
      Kafka + i17 Profile 2026-08-24: video revisit peek black-flash
      **not re-observed (PASS)**. Still revisit ~0.5s corner spinner
      on Kafka = Known debt (Host temp vs L2-ready), not this phase.
- [x] 15.9 Cap close-out: Cap 15 `[x]`; YOU ARE HERE → Cap 17
      placeholder; PHASE_HISTORY this snapshot; ADR-033; Known debt
      (L2-ready vs Host temps; KVC row; debt **400** Picks it up
      still open at close-out)
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY + ADR-033): (this commit)

Related ADR: ADR-031 (Accepted, `962b6d1`); ADR-032 (`9d546f2`);
ADR-033 (`b8071a1`).
Known debt at close: **400 still open** (Limited / local-only video
no Layer 1 poster — Host cannot invent pixels). 393 closed (15.11).
Session L2-ready vs display ≤1+1 / preview cap-3 temps (still
revisit spinner) recorded as a new row. iCloud load-speed / wait-UX
row unchanged. Do not treat 400 as closed because 393 or the spinner
debt were addressed.

## Main Browse Layer 1→2 chrome and iCloud availability hardening
— completed 2026-08-27

- [x] 17.1 Diagnosis (Tracks A/B/C) — notes
      `docs/acceptance/cap17-17.1-notes.md`; WT17 probes **never
      committed**
      — docs: `7a7c2f5`
- [x] 17.2 Contract freeze — ADR-034 Proposed
      — docs: `d65de06`
- [x] 17.3 Layer 1→2 handoff chrome unification (path-class wait
      chrome; a4 T=150 ms; promoted G/B/F1(+D))
      — work: `65ea272`; docs (ADR-034 Accepted): `03ca133`
- [x] 17.4 debt 400 wait-state presentation (coverless visibility;
      residual black accepted)
      — work: `c3aa2dc`; docs: `3ed9431`
- [x] 17.5 Layer-2 dwell N 500→300 ms
      — work: `15edc91`; docs (ADR-035 Accepted): `e56fa2a`; notes
      `docs/acceptance/cap17-17.5-notes.md`
- [x] 17.5b Retry visibility + corner L2 reassure
      — work: `527baeb`; docs (ADR-036 Accepted): `542ef1f`; notes
      `docs/acceptance/cap17-17.5b-notes.md`
- [x] 17.6 Device acceptance + Live L2→motion handoff latch
      — work: `a42abcd`; test: `4692ece`; docs (ADR-037 Accepted):
      `fb6af28`; notes `docs/acceptance/cap17-17.6-notes.md`
- [x] 17.7 Overlay capture-time honest presentation (~ exact +
      coarse relative bands; minute-level path reverted `2c0a090`)
      — work: `d9db8c7`; docs (ADR-038 Accepted): `16653be`
- [x] 17.9 Wait copy cleanup (delete center Layer2Waiting;
      source-switch L1 label delay; coverless re-enter `_loading` fix)
      — work: `f1ffadf`; docs (ADR-039 Accepted): `1aa3c66`
- [x] 17.8 Cap close-out: Cap 17 `[x]`; YOU ARE HERE → Cap 18
      placeholder; PHASE_HISTORY this snapshot; Known debt **400**
      Picks it up → Unassigned (accepted residual; no further fix
      scheduled); debt **403**-class stall/progress Unassigned;
      Layer2Waiting / tab Layer1 flash rows closed in **17.9**
      — docs (this commit)

WT17 throwaway probe logs were never committed.

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-034 (`65ea272`); ADR-035 (`15edc91`); ADR-036
(`527baeb`); ADR-037 (`a42abcd`); ADR-038 (`d9db8c7`); ADR-039
(`f1ffadf`).
Known debt at close: **400 still open** — Picks it up **Unassigned**
(accepted residual black per ADR-034; not Cap 17 unfinished work).
**403**-class iCloud load feel / stall·progress **Unassigned**
(17.5b Retry/reassure limb closed). Overlay capture-time closed
(17.7 / ADR-038). ≥T wait chrome / F1 wasted prepare / feed-shell
tab-switch polish Unassigned. Do not close 400 because 17.4
improved coverless visibility or 17.9 closed wait-copy rows.

## Main Browse playback controls and gesture arbitration (Cap 18) — 2026-08-31

- [x] 18.1 Contract freeze — ADR-040 Accepted
      — docs `9e4a04e` (Proposed) / `c745f4c` (Accepted); anchor `0df9ceb`
- [x] 18.2 Host runtime observe — work `7f74826`; docs `9a0b53a`;
      250 ms periodic + immediate emit; no dedupe; Mapper + Host XCTest +
      Dart platform (scrubber consumer → 18.5)
- [x] 18.3 Dual-signal + coordinator — work `84ef30c`; docs `f8988b9` /
      `9d1dea4` (ADR-026 narrow supplement); debt **395** implementation
- [x] 18.4 Tap + center affordance + lifecycle auto-resume — work
      `0df9ceb`; docs `c745f4c`; Kafka Profile PASS —
      `cap18-18.4-notes.md`; debt **434** closed; debt **441** opened
- [x] 18.5 Scrubber + progress-drag + preview bubble — work `3d115a4` +
      `04ef327` + `b2ceabd`; docs `7b9f43c` / `1ed7f0b`; device i17 Green +
      Kafka Profile PASS — `cap18-18.5-notes.md`; debts **442** / **443**
      Accepted (phase)
- [x] 18.6 Device acceptance — Kafka Profile + i17 Green PASS;
      deliberate **395-P** / **395-PP** + end-cap scrub; debt **442** Item
      clarified; debt **444** opened — `cap18-18.6-notes.md`; docs `688ec43`
- [x] 18.7 Cap close-out: Cap 18 `[x]`; YOU ARE HERE → Cap 19 placeholder;
      PHASE_HISTORY this snapshot; debt **395** Closed (intentional design)
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-040 (`0df9ceb`; 18.5 supplements `b2ceabd` / `1ed7f0b`);
ADR-026 (narrow supplement `f8988b9`).
Known debt at close: **395 closed** (intentional design); **434 closed**;
**440 closed**; **442** / **443** Accepted (phase); **441** Monitoring;
**444** Open → **Build a Pool, Ephemeral Pool, and Source ordering**;
**439** Open Unassigned (Live explicit replay). Do not close **442**, **443**,
**441**, or **444** in this close-out.

## Add to Album / Cap 19 entry chrome (Cap 19) — 2026-09-04

- [x] 19.1 Contract freeze — §5 complete (D1–D4); ADR-041 + Decision 20
      docs batch
- [x] 19.2a Limited album spike — work `3f7a8e4`; notes
      `docs/acceptance/cap19-19.2a-notes.md`
- [x] 19.2b Scrub drag playback fix — work `96d5ead`; ADR-040 Decision 13
      narrow supplement; device PASS i17 Green Profile
- [x] 19.2c Scrub preview/seek quantizer align — work `0ef9ef2`; ADR-040
      Decision 13 narrow supplement; device PASS i17 Green Profile
- [x] 19.2d Scrub seek-hold + live playhead ghost — work `7637812`;
      ADR-040 Decision 13 narrow supplement; device PASS i17 Green Profile
- [x] 19.2 Native album write path hardening — work `81e4b93`; ADR-013
      narrow supplement; notes `docs/acceptance/cap19-19.2-notes.md`
- [x] 19.3 WakeTok album bootstrap — work `1341e20`; notes
      `docs/acceptance/cap19-19.3-notes.md`
- [x] 19.4 Entry chrome + half-sheet — work `958178d`; notes
      `docs/acceptance/cap19-19.4-notes.md`
- [x] 19.5 Panel Add-to-Album picker — work `36c22ef`; notes
      `docs/acceptance/cap19-19.5-notes.md`
- [x] 19.5b Panel Add-to-Favorites — work `0fa4580`; notes
      `docs/acceptance/cap19-19.5b-notes.md`
- [x] 19.6 Left-swipe append — work `ce815f7`; notes
      `docs/acceptance/cap19-19.6-notes.md`; P-19.6-POP → 19.8
- [x] 19.7 Preference + polish — work `b73e4d0`; notes
      `docs/acceptance/cap19-19.7-notes.md`
- [x] 19.8 Device acceptance + close-out — work `a13adfa` (ADR-042
      Decisions 1–7 actionable + scrub gold ghost) + `17ec5a1` (Decision 8
      trailing chrome peek/cover hide) + `da34f93` (left-swipe drag copy /
      icons); docs ADR `0eaa4be` / `4a406a1`; owner Kafka + dual-entry /
      Limited matrix PASS; Cap 19 `[x]`; YOU ARE HERE → Cap 20 placeholder;
      PHASE_HISTORY this snapshot; debt **447** unchanged Accepted (phase);
      debt **448** opened (interactive-pop residual, P-19.6-POP note)
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-041 (`372175c`); ADR-042 (`a13adfa` / Decision 8
`17ec5a1`); ADR-040 D13 / D15 / D18 / Decision 20 supplements; ADR-013
narrow (`81e4b93`).
Known debt at close: **445** Accepted (permanent); **446** / **447** /
**448** Accepted (phase); **421** Open (Settings Limited — out of Cap 19);
**444** Open → Build a Pool Cap. Do not close **447** or **448** in this
close-out.

## Display magnification (pinch to zoom, lightweight) (Cap 20) — 2026-09-05

### Landmark constraints (long-lived Cap 20 boundaries)

1. **Decision 13 / no-precedent Host API.** Cap 20 shipped with **zero
   SQLite** and **no new general Pigeon / Host zoom surface**. The **only**
   Cap 20 exception to Decision 11’s “no new Pigeon / no Host zoom API”
   rule is Decision 13: one narrow method
   `PlaybackApi.setDisplayMagnification(scale, translationX, translationY)`
   that drives the Platform View **inner** magnification content while the
   Flutter embedding–owned **outer** root stays identity (Decision 13
   supplement `282009e` / `ca3b4ed`). This revise is **not a precedent**
   for later Caps to add Host zoom APIs without a fresh owner pass and
   ADR (stop-and-re-discuss gate stands).

2. **D5 max scale = 4× — empirical lock, not a derived optimum.** Cap 20.6
   locked `kCap20MaxScale = 4.0` after Kafka + i17 soak PASS, with a
   one-time reasonableness check against **Photo-App-A** (peer ~fixed 4×
   ceiling) — **not** an ongoing competitor-parity promise, and **not** a
   math optimum from pixel density or a measured performance cliff.
   4× remains the sole Photos known delta (fixed multiplier vs Photos’
   resolution-based cap). Raising the ceiling later is **out of Cap 20**
   and needs a **new owner pass**, including re-validation of scopes
   **this 4× lock did not cover**:
   (a) **Low-resolution still clarity** under a higher fixed multiplier —
       WakeTok does not float the cap by resolution the way Photos does;
       soft/pixelated stills may look obviously soft well before a new
       numeric ceiling;
   (b) **Kafka (performance-floor) hand-feel / hitch** at the new ceiling —
       4× PASS does not imply higher multipliers’ render/sample cost;
   (c) **Video L2 Decision 13 native path stability** at higher scale —
       armed `setDisplayMagnification` on **inner** magnification content
       (outer identity); watch for Platform View composition / frame-set
       edge cases of the class that previously surfaced as the “shrink /
       outer-transform” failure mode (`282009e`);
   (d) **Reset / pan feel** — larger max scale amplifies on-screen
       displacement for the same finger travel; chrome and clamp feel may
       need retuning.

### Phase snapshot

- [x] 20.1 Contract freeze
      — D1–D6 locked (D7/D8 Out / no-touch); Live PV scale spike
        **cancelled**; ADR-043 Accepted; GLOSSARY §18 adds Display
        Magnification / pinch / Reset (Fit vs fit disambiguation)
- [x] 20.2 Magnification signal + arbitration wiring
      — work `ae9cb7e`; stub → `browseStillMagnifiedProvider`;
        PageView lock + left-swipe guard; T-20.2-12a/12b
- [x] 20.3 Still path (persistent pinch + pan + clamp-to-fit + Reset;
      Live static / animated as still)
      — work `e6515ea`; PageView-outer host; Plan A; T-20.3-1…11
- [x] 20.4 Video path (transient; release → fit; D3) + L1 unify
      — work `ca3b4ed` (Decision 13) + `32d149f` (L1 unify / native push
        gate / T-20.4-12); Kafka Profile L2 smoke PASS
- [x] 20.5 Live motion-window gate
      — work `114f393`; Host mode-none + rising-edge coverage;
        i17 Live smoke PASS
- [x] 20.5b Double-tap to exit persistent magnification
      — work `66fc463`; still / Live-static L2 only; enter stays Out;
        notes `cap20-20.5b-notes.md`
- [x] 20.6 Device acceptance
      — work `bc15517` (D5=4× / letterbox `W-14.6c` / Q2 lock); docs
        `e49377d`; notes `cap20-20.6-notes.md`; Kafka primary + i17
        short retest; Q2-A keep; B.1 PASS; debts **451** Closed /
        **452** Open; **453** Closed earlier (not ADR-043)
- [x] 20.7 Cap close-out: Cap 20 `[x]`; YOU ARE HERE → Build a Pool…;
      PHASE_HISTORY this snapshot
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-043 (`ae9cb7e`; Decision 13 `ca3b4ed` / inner
`282009e`; Decision 14 `32d149f`; D7 exit `66fc463`; D5=4× `bc15517` /
docs `e49377d`); ADR-040 Decision 16 / Decision 20.

Known debt at close (unchanged Status in 20.7): **449** Open (no push
CI); **452** Open (degenerate pixel dims); **448** Accepted (phase) Out
of Cap 20; **450** / **451** / **453** Closed. Do not flip these in
this close-out.

### Related work during Cap 20 (footer — not phases)

- **GLOSSARY history purge (privacy; Cap 20.2 window, 2026-09-04) —
  not a 20.1 deliverable.** Distinct from the 20.1 §18 term add.
  Trigger: remove personal / privacy-sensitive content that had lived
  in published `docs/GLOSSARY.en-zh.md`. Method: `git filter-repo`
  rewrite of **`main` and `spike/poc`**. Impact: nearly all historical
  commit SHAs changed; docs anchors batch-remapped (`93e34eb` on main,
  `292511c` on poc notes); pre-purge SHAs obsolete. Offline backup
  (owner machine only): `WakeTok-pre-purge-backup-20260904.git`. After
  purge the file stays **local-only / gitignored** (not published).
  Heaviest repo operation in Cap 20 — do not collapse into the 20.1
  phase line.
- `3d29823` — still L1↔L2 black-flash / debt **450** Closed
- `282009e` — video shrink C + release spike A (Decision 13 inner)
- `81904e1` — media chrome layout (shared browse; **not** ADR-043)
- `7f43863` — Live AppLifecycle unload / debt **453** Closed (Cap 9 /
  ADR-019; Cap 20.5 Host gate made gap visible)

---

## Path correction — media-chrome-layout-notes (2026-09-07)

Forward-pointer only. Does **not** edit the Cap 20 entry above.

- **Path correction (Cap 21.4b docs; work `67cb08b`):**
  `docs/acceptance/media-chrome-layout-notes.md`, referenced in the
  Cap 20 entry above, has moved to
  `docs/reference/media-chrome-layout-notes.md`. Original Cap 20 entry
  text is unchanged. Live Contract pointers: `docs/STATE.md`.
