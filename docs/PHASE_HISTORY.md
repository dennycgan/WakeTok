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

Work commit sha: 68a56a3
Docs commit sha: 4a6a9fe

## POC-04: Flutter Media Feed Architecture Gate — completed 2026-07-28

- [x] 2.1 Create isolated spike scaffold (lib/spikes/poc_04/, ios/Runner/Spikes/POC04/,
      pigeon/spikes/poc_04/, docs/poc/POC-04-notes.md; debug-only entry)
      — work: `8bf2c92`
- [x] 2.2 Spike Pigeon + Photos authorization + list device-local PHAssets
      — work: `70032ee`
- [x] 2.3 Minimal mixed vertical feed (Fit; image temp file; AVPlayer PV; pool 1+1)
      — work: `c432bb0`
- [x] 2.4 ≥100 mixed transitions; pool+tmp bounded (Probe 30/100); iPhone 13 Pro + 17
      — work: `1a648a6`
- [x] 2.5 Profile measure on iPhone 13 Pro: first-frame PASS (p90=93 ms);
      hitch gate adjusted to **< 25 ms/s + no Severe Hang** (ADR-001);
      hand PV 13–19 everyday feel; Hitch Probe HN≈38 upper bound; Texture escape failed
      — work/measure notes: `10bd0c1`, `e5c4117`
- [x] 2.6 iCloud-only + Network Link Conditioner — **skipped**; deferred to
      Production Main Browse Screen / feed
      — work: (none)
- [x] 2.7 Record Conditional Pass in DECISIONS.md (ADR-001 Accepted)
      — docs: `2e249e0` (content), `573614b` (Accepted + anchor);
        on `main` cherry-picks: `3ff7f58`, `9ea6424`

Docs close-out (STATE + PHASE_HISTORY): `33267c1`

## POC-03: Lock-screen continuous playback gate — completed 2026-07-28

- [x] 3.1 Create spike harness in lib/spikes/poc_03/ +
      ios/Runner/Spikes/POC03/; minimal AVQueuePlayer + AVAudioSession(.playback)
      setup; playback must not depend on Flutter Widget being alive
      — work: `77d7af8`
- [x] 3.2 Verify clip-to-clip auto-advance on lock screen:
      pre-queue next AVPlayerItem; confirm audio gap is imperceptible
      or acceptable between segments
      — work: `d736dcc`
- [x] 3.3 Verify audio interruption and recovery
      (phone call, Siri, other audio apps; session re-activates on return)
      — work: `4747fe1`
- [x] 3.4 Verify Control Center metadata (Now Playing info + transport controls)
      and AirPods play/pause/next
      — work: `9b26233`
- [x] 3.5 Verify process termination stops playback;
      next foreground launch can attempt SessionCheckpoint recovery
      — work: `9eeb912`
- [x] 3.6 Record go / no-go in DECISIONS.md
      (ADR-002 Conditional Pass Accepted; anchor `9eeb912`)
      — docs: `797e4b8`

Notes: `docs/poc/POC-03-notes.md`. Known debt → Production Background Audio
(WeChat/VoIP lock-home resume; iCloud interrupt; post-POC-09 physical-clip
queue verify).

## POC-09: Current Photos Representation Export Gate — completed 2026-07-29

- [x] 9.1 Spike harness + dual current/original probe + temp export;
      unedited smoke OK
      — work: `c98a073`
- [x] 9.2 Trim: export ≈ current; original longer; no silent original fallback
      — work: `e8e900b`
- [x] 9.3 Slow-motion HFR: export duration matches Photos-displayed / PHAsset
      — work: `ab86a2b`
- [x] 9.4 Default audio: track present + Play-export listen
      — work: `9794449`
- [x] 9.5 Subtitle scope: burned-in only; soft tracks out of scope (ADR-003)
      — docs (this close-out); no probe implementation
- [x] 9.6 Explicit failure: iCloud-only + network off → `inCloudUnavailable`
      (incl. 3164); controlGate ON; N1 local+OFF
      — work: `fcf7561`
- [x] 9.7 Record Pass (GO) in DECISIONS.md (ADR-004 Accepted; anchor `fcf7561`;
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
      (work: a1725c9; base app_zh.arb matches zh_Hans「本地化正常」
      for Flutter gen_l10n fallback only)
      — work: `a1725c9`
- [x] 4.2 Define shared Result<T, AppError> and AppError enum 1:1 with
      kickoff Data Contract codes plus unknown; Result combinator tests;
      native error mapping spec (R1–R6); ADR-008 Dart half
      — work: `9a405df`
- [x] 4.3 Production Pigeon baseline: PhotoLibraryApi + PlaybackApi
      (empty stubs); ErrorCode 1:1 AppError + mapping + exhaustive tests;
      PlaybackApi encodes ADR-006 ownership / plan / surface / restore
      vocabulary; ClipExportApi deferred; ADR-008 wire re-anchor
      — work: `8fed245`
- [x] 4.4 Wire l10n into MaterialApp with localeListResolutionCallback:
      first preferred locale only; languageCode zh → zh-Hans (incl.
      zh-Hant); otherwise English (ADR-U §10); manual preference deferred
      to Settings; device smoke en / zh-Hans / zh-Hant→简中 PASS
      — work: `2712d50`

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
      — work `2e95eca`
- [x] 5.2 Photos authorization domain + gateway: PhotoLibraryApi auth +
      presentLimitedLibraryPicker; Dart PhotosAccess + repository +
      gateway; Riverpod (ADR-010); Info.plist Usage PLACEHOLDER +
      PHPhotoLibraryPreventAutomaticLimitedAccessAlert = YES
      — work `5ad1357`
- [x] 5.3 Permission UI flows (en / zh-Hans, tokens only): Request /
      Blocked / Limited banner; Library Totals Shell landing
      — work `8ef8566`
- [x] 5.4 Library access + iCloud asset state model: libraryTotals +
      fetchLibraryPage; domain catalog + availability; shared
      PHFetchOptions (ADR-011); shell real counts
      — work `690aa0d` (availability KVC fix `7d8f022`)
- [x] 5.5 Real-device acceptance on iPhone 13 Pro: M1–M8 PASS (permission
      flows; totals exact match vs Photos Media Types; Light/Dark;
      en + zh-Hans); notes `docs/acceptance/cap5-5.5-notes.md`
      — acceptance fix `8d8c873` (limited-picker dismiss + resume refresh)

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
      — work `1a4e131`
- [x] 6.2 Pigeon regen + Swift host: expand kind/DTO/availability enum;
      implement `listAssetSources` (three built-ins, sync counts) and
      `resolveSource` (full id list, off-main enumeration, main-thread
      BinaryMessenger reply; shared PHFetchResult helpers matching
      `libraryTotals`); no device-local filter; host pair validation on
      the three legal (kind, id) pairs. Accept ~40k id bridge cost.
      — work `6e3714d`
- [x] 6.3 Dart domain + gateway + Riverpod (ADR-009/010): minimal
      built-in AssetSource types + repository under `lib/domain/source/`
      (separate from `domain/library`); composition-root wiring;
      features do not construct gateways. Architecture + localization
      guards green.
      — work `80d4806`
- [x] 6.4 Debug/smoke UI (extend library_smoke): switch All/Photos/Videos;
      resolved count vs `libraryTotals`; All-only date-quantile + id
      alignment tooling; built-in labels via ARB only (wire `displayName`
      not l10n); explicit negative path — pair mismatch →
      `assetUnavailable`. No product top-bar.
      — work `cbdc317`
- [x] 6.5 Real-device acceptance (iPhone 13 Pro + owner ~40k library):
      counts exact; full library incl. iCloud-only; All date-distribution
      sampling (N=3; epoch exclude; span = maxYear−minYear); ≥1
      `iCloudNotDownloaded`; M9 Limited subset list/resolve; notes under
      `docs/acceptance/cap6-6.5-notes.md`. Cap 6 capability close-out
      (STATE + PHASE_HISTORY; ADR-013 already Accepted at 6.2 docs).
      — acceptance on `6091b5d` (feature work through `cbdc317`)

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
      ADR-014: Accepted at Cap 7.2 work `5ef2e8a` (see DECISIONS).
      — docs `fb4bc9f`

- [x] 7.2 Theme tokens for feed chrome: typography scale tokens (ADR-009
      Known debt); feed scrim / on-media contrast tokens as needed; still
      `accentProvisional` (freeze in 7.8 only).
      — work `5ef2e8a`

- [x] 7.3 Playback + image pipeline (ADR-006): production foreground
      PlaybackApi path — PV attach/detach, bounded 1+1; image display
      request path; no Background Audio / Now Playing product scope.
      — work `29fcf2d`

- [x] 7.4 Main Browse chrome shell: top All/Photos/Videos + Pools disabled
      (ARB Coming soon on-cell; no tap SnackBar); bottom NavigationBar
      (Browse active; Clips/Auto/Settings stub; explicit indicatorColor
      token); Main Browse = default post-auth landing; library_smoke
      debug-only via Settings; Limited banner kept.
      — work `d54d9be`

- [x] 7.5 Vertical Media Feed: PageView (or equivalent) over ephemeral
      queue; Manual swipe; wire resolve(All|Photos|Videos); pool/preheat
      bounds (ADR-P.5 spirit); architecture + localization guards green.
      — work `fb82bf6`

- [x] 7.6 Source switch behavior: changing top tab rebuilds ephemeral
      queue from Cap 6 resolve and starts at queue head; no Pool model;
      no Session Continuity product rules; session-scoped successful
      resolve cache per built-in (ADR-014 Decision 5; process lifetime;
      failures uncached; “session” ≠ Consumption Session).
      — work `79f8c12`

- [x] 7.7 Real-device feed acceptance (iPhone 13 Pro, **Profile**): scroll
      real library; hitch < 25 ms/s AND no Severe Hang per 7.1 hard gate;
      notes under `docs/acceptance/`. Campaign recorded **FAIL** then
      **INVALIDATED as Profile gate** (errata: actual install was **Release**
      via `build`+`install --release`; tables retained as Release forensic
      only — `cap7-7.7-notes.md`). Hard bar unchanged. Fail path was
      suspended pending 7.7a (later **not** taken — 7.7a PASS).
      — docs `b45a318` + errata `2481d49`

- [x] 7.7a Profile hard-gate retest: Videos×3 + All×3, **same V-hard** rules,
      **Profile only** (`flutter build ios --profile` +
      `flutter install --profile`). Doomscroll intensity credibility **yes**.
      **PASS** 2026-08-06 (Videos ≈0.29/0.89/0.98; All ≈2.7/8.2/1.9 ms/s;
      zero Severe Hang). Notes `cap7-7.7a-profile-retest-notes.md`.
      — docs `eed9d22`

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
      — work `0e3eec2`

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
      ADR-015 wide draft approved in chat (Accepted at 8.2 work `a721bdc`)
- [x] 8.2 Immersive Browse chrome: forced-dark for Browse/Clips/Auto
      destinations; shared bottom bar always dark (even on Settings);
      Settings *pane* follows Appearance. Initial work `a721bdc`
      (ADR-015). Revision `5fb93de` (ADR-016): transparent top + compact
      custom bar. Fix `60f3283` (ADR-017): bar always dark on Settings.
      Pays forced-dark + opaque-top Known debts.
- [x] 8.3 Presentation Metadata: Pigeon + gateway + domain; current-page
      only; two HostApi calls (`requestPresentationMetadata` then
      `requestPresentationFileSize`) for progressive fields
      (`creationDateMs?`, required `mediaKind` on success,
      `fileSizeBytes?`, `fileSizeSemantics?`); host Tier 3/4
      implemented. Work `c0c04e1`. Feature-layer FeedMediaRequestGate
      staleness discard + Overlay consumer landed in 8.5 (`4f4c825`).
- [x] 8.4 POC-10: device-confirm safe Tier 3/4 paths already in `c0c04e1`;
      M1–M6 PASS; M7 N/A (no RAW+JPEG in owner library); Browse hitch
      qualitative OK. Notes: docs/acceptance/cap8-8.4-poc10-notes.md
      (2026-08-09; M2/M3 follow-ups + ADR-018). Temporary debug probe
      discarded (never on `main`). No host fix at 8.4 close-out.
- [x] 8.5 Media Info Overlay UI: fixed-height rows 1–3; row 4 hidden when
      `locationLabel` empty (no geocode); progressive paint; ARB; Live
      label + still size (ADR-018 Tier 4); dual-gate sync via
      `FeedActivationCoordinator`; session Overlay cache + background
      refresh. Work `4f4c825`; docs ADR-018 `2bdd207`; session-cache
      regression `W-O-cache` with this close-out.
- [x] 8.6 Loading / Empty product polish: shared `_BrowseStatusPanel`;
      resolve vs per-page Keys; per-page loading spinner-only (D1);
      W-L1–W-L6 (Overlay independence on per-page iCloud/failed). Work
      `dbc0cfd`. No Waiting for Media / Source Availability surfaces;
      no new ADR.
- [x] 8.7 Location deferral close-out: W-Loc1 (whitespace trim) + W-Loc2
      (feed Row2 exact + Row3 size fixture land; no Row4). Work `95f2037`.
      No geocode; Known debt unchanged; no formal device notes; no new ADR.
- [x] 8.8 Real-device acceptance: H1/S1–S4/C1/S3-format PASS; A1 leave-video
      audio leak fixed (`df83633`) + device retest PASS; W-O-prog. Notes:
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
      — docs `b4c1061` (roadmap) / work `94358be`
- [x] 9.2 Native host: PHLivePhoto request + PHLivePhotoView factory;
      `clearPlaybackPool` + clear-in-flight guards; cancel/failure;
      Pigeon LivePhotoApi + clearPlaybackPool channels (D1=A);
      D3 gesture recognizer disabled; ADR-019 appended
      — work `94358be` (ADR anchor `98fe191`)
- [x] 9.3 Pigeon + gateway + domain (current-page only); composition root
      (channels already in 9.2; Dart LivePhotoRepository + LivePhotoGateway
      + clearPlaybackPool on PlaybackRepository; no Feed wiring)
      — work `afd3181`
- [x] 9.4 Feed integration: Live current → await clear → play-once →
      Q7 still; leave/re-enter; Overlay/badge coexistence; F4
      feed-scoped `LiveHostOpSerial` + activation generation; host
      cancel/stop main-sync; no motion spinner (intentional interim —
      Q4=A spinner in 9.5, not Known debt)
      — work `c86dd6e`
- [x] 9.5 iCloud / failure: static-first + spinner-only; static fallback;
      no auto-skip (not Waiting for Media product surface); badge-adjacent
      preparing spinner; all `_livePreparing` writes via `gatedFlagUpdate`
      (L-S6 defensive seam `debugSetLivePreparing`)
      — work `042c59d`
- [x] 9.6 Mute preference binding (default unmuted) + Playback Style
      matrix (POC-08 #4 / #7); re-apply shared mute after video pool
      rebuild (ADR-019 Consequences reminder); `sharedMuteProvider`;
      Live `setMute`+`startPlayback` in one `LiveHostOpSerial` op;
      video `setMute` before `play`; library_smoke debug toggle;
      Style observation template for 9.7
      — work `8c0f4ca`
- [x] 9.7 Device POC-08 acceptance (iPhone 13 floor + 17 compat; Profile;
      local + iCloud + weak net; Q7 switch feel; item #5: note observed
      iCloud download state changes during motion prepare; items 1–8
      gate); notes under docs/acceptance/; POC Result/Decision →
      ADR-019 close
      — notes `docs/acceptance/cap9-9.7-poc08-notes.md`; mute host
      persist mid-gate `4aa93b0`; Style matrix filled; 17 P5–P7 N/A
      — docs `970c110`
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
      — docs `519564b`
- [x] 10.2 Domain kinds + SourceReference: album/smartAlbum;
      built-in pairs kept; exhaustiveness arms; mapper untouched
      — work `8c99d46`; ADR-020 Accepted docs `c0b0d47`
- [x] 10.3 SourcePoolDefinition + PersistencePolicy + ADR-P
      (30 validate / 10 constant); Q1–Q3=A
      — work `6aa35dc`; docs `21a5407`
- [x] 10.4 ItemOrderingPolicy.forKind (creationDateDescending /
      unspecified); ORD unit tests + architecture green
      — work `954d7e0`; docs `f7a36de`
- [x] 10.5 Cap close-out: STATE Cap `[x]` + YOU ARE HERE +
      PHASE_HISTORY; Phase Roadmap → Live Resolution placeholder
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-020 (Accepted, anchor `8c99d46`).
Known debt: no Cap 10 table-row adds or clears. Prior debts unchanged
(Location, playhead, file-size disclaimer, Release hang, UX-1/UX-2,
Portfolio scan, etc.).
