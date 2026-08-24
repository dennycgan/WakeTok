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

## Live Resolution, Asset Source Availability,
Identity Coalescing, and Resolved Pool Snapshot
— completed 2026-08-12

- [x] 11.1 Contract freeze: owner Cap 11 review (D1–D6); ADR-021 Proposed
      (Limited list omits Album/Smart; sequential multi-source resolve;
      Album ordering = creationDateDescending); Out-of-scope locked
      — docs `2490c1d`
- [x] 11.2 Host list: User Album + Smart Album + Availability;
      open domain↔wire album/smartAlbum mapping; Limited: albums absent
      from list (ADR-K); `other` still throws
      — work `95779ef`; device notes `cap11-11.2-notes.md`;
        ADR-021 Accepted docs `e4133cb`
- [x] 11.3 Host resolve: album/smartAlbum with creationDateDescending;
      Availability on resolve; Limited resolve → unauthorized
      — work `2cf26a6`; device notes `cap11-11.3-notes.md`;
        docs `0f30ba2`
- [x] 11.4 Domain: ResolvedPoolSnapshot + Identity Coalescing
      (first appearance) + sequential resolvePool(SPD); partial-source
      failure non-blocking (Glossary §16)
      — work `44b783e`; unit tests SNAP-1…12; docs `7240d7d`
- [x] 11.5 Composition / smoke-debug wiring (Main Browse unchanged, D4=A);
      architecture green
      — work `8e37b64`; Photos+All smoke probe; main_browse ↛
        `resolve_pool.dart`; docs `36b868f`
- [x] 11.6 Acceptance: unit tests + device multi-source coalesce
      (iPhone 13 floor + 17)
      — work `8e37b64`; HEAD `36b868f`; notes `cap11-11.6-notes.md`;
        docs `ec3ce21`
- [x] 11.7 Cap close-out: STATE Cap `[x]` + YOU ARE HERE +
      PHASE_HISTORY; Phase Roadmap → Session Queue placeholder
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-021 (Accepted, anchor `95779ef`).
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
      — docs `7f84599`
- [x] 12.2 Domain: OrderPolicy / AdvanceMode / RepeatPolicy +
      SessionConfiguration
      — work `f53d455`; ADR-022 Accepted docs `55d4586`
- [x] 12.3 Default Session Profile derivation
      (current pools always General/Mixed; Pure Clip reserved)
      — work `ba81abc`; docs `a081856`
- [x] 12.4 Sequential Session Queue builder + ADR-M Sequential
      contract unit tests; shuffle branch documented refuse;
      acceptance: Mixed `deriveDefaultSessionProfile` output fed
      directly into `buildSessionQueue` must hit the documented
      refusal path (not covered by testing the two functions alone)
      — work `77571a9`; docs `d51c7d8`
- [x] 12.5 Composition / smoke-debug only (Main Browse unchanged,
      D1=A); architecture guard main_browse ↛ build_session_queue;
      architecture green
      — work `a14d748` (guard only; no smoke); docs `6127b44`
- [x] 12.6 Acceptance: unit tests (no device PoC; D1=A);
      docs-only; verified at HEAD `6127b44`; full `flutter test`
      PASS (+247); session CFG/DPR/SQ + architecture green;
      ADR-022 D1–D6 contract checklist PASS; no
      `docs/acceptance/cap12-12.6-notes.md` (unit-only — acceptance
      notes files are for device/manual evidence, not pure unit gates);
      Known debt unchanged
      — docs `2e167bf`
- [x] 12.7 Cap close-out: STATE Cap `[x]` + YOU ARE HERE +
      PHASE_HISTORY; Phase Roadmap → Endless Shuffle placeholder
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-022 (Accepted, anchor `f53d455`).
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
      + cancel (work `393ebc9`)
- [x] 14.3 Host Layer 2: current-item `requestDisplayAsset` /
      `requestPlayableVideo` may use network + cancel
      (work `ce8807f`; ADR-006 Status narrow supersede this docs
      commit)
- [x] 14.4 Feed three-layer UI + ARB; retire
      `mainBrowseFeedICloudOnly` (work `9cf22a5`)
- [x] 14.4b First-launch cellular retry + failure-reason copy
      (work `eddb7c3`); Overlay file-size refresh after Layer 2
      (work `900581e`; Kafka same-page size PASS)
- [x] 14.4c Browse↔Settings keep-alive: unconditional IndexedStack
      Theme wrap (work `6178f9e`; Kafka non-head still+video
      Settings round-trip PASS); resume activation latch;
      off-current `_startLoad` identity lock + neutral placeholder
- [x] 14.4d Video item loop + replay on return-to-ended
      (work `8189543` / ADR-026; Kafka: in-item loop, return-to-ended
      replay, mid-play seek preserve, dead-file preview reload,
      Live play-once; ADR-006 D4 background plan-end still no loop)
- [x] 14.4e Leave Browse resets queue (work `fe660dd` / ADR-027;
      Kafka: Settings/Clips leave → new Shuffle + index 0;
      AppLifecycle does not reset; APP-8/8b/8c)
- [x] 14.5 ±1 local-only visual preheat + cancel on leaving the window
      (work `fa09b00`; Kafka: neighbour Layer 1 more often present;
      video neighbour poster / no audio; two-step skip does not
      cap-3-evict the current preview)
- [x] 14.6 Limited first-launch All: keep resolve-loading on successful
      empty + bounded re-resolve (3 extra attempts, 500/1000/2000 ms)
      (work `37821ec` + `7329081`; Kafka Profile: grant Limited → All
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
      concurrency / dedupe). Not Cap 15. Work `16ed6e3`; Kafka
      Profile PASS
- [x] 14.6c Default Fit (contain / resizeAspect / scaleAspectFit)
      + portrait-only (`Info.plist` + `SystemChrome`). Not the
      Fit/Fill/Crop rail. Work `24debf4` / ADR-028; Kafka Profile
      PASS
- [x] 14.7 Cap 14 close-out docs: Cap 14 `[x]`; return YOU ARE HERE
      to Cap 13; 13.6 unblocked as executable at the unchanged
      V-hard bar; Instruments not run in 14.7
      (ADR-025 Accepted is the docs commit after 14.2, not 14.7)
      — docs (this commit)

Limited Access product chrome unmount (work `eb4473f`, docs
`816816b`) landed after 14.6b and is **not** a numbered Cap 14
phase. See Known debt: iOS Photos permission / Limited Access
product chrome unmounted from Main Browse.

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-025 (Accepted, anchor `393ebc9`); ADR-006 Status
narrow supersede (anchor `ce8807f`); ADR-026 (Accepted, anchor
`8189543`); ADR-027 (Accepted, anchor `fe660dd`); ADR-028
(Accepted, anchor `24debf4`).
Known debt: Limited Access product chrome unmounted (`eb4473f`);
iCloud video no Layer 1 poster (MVP-acceptable); Cap 15 Layer 1→2
handoff + duplicate Layer 2 rows unchanged. Do not rewrite 13.6
FAIL tables. Prior debts unchanged (Release hang, Location,
file-size disclaimer, UX-1, Portfolio scan, etc.).

## Cancel and dwell current-item Layer 2 fetch
— completed 2026-08-19

- [x] 16.1 Contract freeze: ADR-029 Proposed (no Accepted date, no
      fake anchor); Capability Roadmap insert; Parked Cap 13; Known
      debt Picks it up → Cap 16
      — docs: `4e5d57b`
- [x] 16.2 Host `cancelInFlightPrepare` + Dart leave/dispose/leave
      Browse (#1+#4); `flutter test` including `test/architecture/`
      — work: `d273358`; docs (ADR-029 Accepted): `2bafa1e`
- [x] 16.3 Plan ≠ download: `setPlaybackPlan` must not `prepareActive`;
      `load` completes on success/fail/cancel; feed drops
      `requestPlayableVideo` download; that API is duration-only
      (#2). Re-align `_layer2InFlight` with the new `load` completion
      — work: `df021b8`; docs: `6d56444`
- [x] 16.4 Dart dwell N=500 ms (initial; still + video Layer 2);
      Retry / resume-failed bypass; neighbour promote and Endless
      first item do not; keep `_layer2InFlight` true during dwell
      — work: `6ca736f`; docs (ADR-025 D2 timing note): `1bfbf53`
- [x] 16.5 Device: storage replication + All/Videos hitch notes
      (bar unchanged; Endless round PASS; N=500 dwell-feel
      unverified). Cap 16 `[x]` does **not** require 13.6 PASS
      — docs: `8312c5d`; notes `docs/acceptance/cap16-16.5-notes.md`
- [x] 16.6 Cap close-out: YOU ARE HERE returns to Cap 13; 13.6
      still FAIL until retest (now executable). ADR-029 Accepted
      (16.2 docs, anchor `d273358`); ADR-025 D2 timing note landed
      with 16.4
      — docs (this commit)

WT16 throwaway probe logs were never committed; removed from the
working tree at close-out.

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-029 (Accepted, anchor `d273358`).
Known debt: product storage leak path paid; 13.6 hitch still FAIL
(`c43bed7`); Layer 1 miss centered spinner → Cap 15; do not rewrite
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
      — docs `879681b`
- [x] 13.2 Domain: Endless Shuffle in `buildSessionQueue`
      (Fisher–Yates + round reshuffle + first≠last best-effort;
      injectable Random; Cap 12 UnsupportedError removed)
      — work `f0187b4`; docs (ADR-023 Accepted): `577864e`
- [x] 13.3 Domain: Queue Stability + in-session Continuity
      (rebuild mapping; slim ConsumptionSession; no
      SessionCheckpoint persistence)
      — work `78f6d9d`; docs `c67be56`
- [x] 13.4 Product apply: Main Browse Mixed → derive + Shuffle
      Queue; supersede ADR-014 Sequential product default via
      ADR-023; composition / guard update (D9=A)
      — work `10a5735`; docs `d1f2884`
- [x] 13.5 Playhead debt reclassification (D6=A): Known debt row
      reworded Accepted behaviour — not a bug fix (D8=A: tab =
      new Session; cross-tab Continuity not in Cap 13); no
      PlaybackApiHost code change
      — docs `3b476af`
- [x] 13.6 Acceptance — closed under **ADR-030 §5** (everyday
      availability, owner 2026-08-19); **not** an Instruments
      numeric Pass. FAIL tables stay frozen
      (`docs/acceptance/cap13-13.6-notes.md`,
      `docs/acceptance/cap13-13.6-retest-notes.md`); they do
      **not** represent the current bar.
      Timeline while the old V-hard gate was still the closer:
      FAIL `1842c39` → 13.6b hang campaign stopped as
      inexecutable `c97d350` → Profile retest FAIL `c43bed7` →
      close `740bd99` (anchor fill `9845493`).
- [x] 13.8 Browse empty / failure feed + claim Endless gesture
      (opened after 13.6 blocked; does **not** close or relax
      13.6). Listed here in the order it ran, not renumbered
      ahead of 13.6.
      - [x] 13.8a claim the Endless last-page gesture already on
            `main` — work `e8564ce`
      - [x] 13.8b mapped `unauthorized` / `unavailable` with empty
            coalesced ids now shows the resolve-failed panel +
            Retry instead of empty copy (**13.4 regression**) —
            work `1f8a240`
      - [x] 13.8c never cache an empty coalesced Snapshot
            (**Cap 13 scope expansion** — fixes pre-13.4 ADR-014
            D5 behaviour; not part of the 13.4 regression) —
            work `1f8a240`
      - [x] 13.8d Acceptance: APP-6/APP-7 + W-F4b/W-S1b and full
            `flutter test` green; device Kafka Profile Limited
            first-launch All → Photos/Videos → All has content
            **without force-quit** = PASS; `unauthorized` path
            unit-only by owner decision; no Instruments in 13.8
      - [x] 13.8e docs: ADR-024 + ADR-014 D5 cache-clause narrow
            supersede; 13.6 blocked reason; Known debt row for
            Limited first-launch All
            — docs `7edc99c`
- [x] 13.7 Cap close-out: STATE Cap `[x]` + PHASE_HISTORY;
      Phase Roadmap → Cap 15 placeholder (owner-approved phases
      later). Cap 14 and Cap 16 already `[x]`. Do not start Cap
      15 code. Layer 1 miss / black cover / swipe flash stay
      Known debt → Cap 15.
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY): (this commit)

Related ADR: ADR-023 (Accepted, anchor `f0187b4`); ADR-024
(Accepted, anchor `1f8a240`); ADR-030 (Accepted, anchor
`740bd99`).
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
      (`300d47b`). Kafka 2026-08-20 Debug. M3 A1 (stills + videos);
      M2 ≠ 1 so 15.4 is a real fix; Q2 no delay-before-show
- [x] 15.2 Contract freeze — ADR-031 **Proposed** (`300d47b`; no
      Accepted date, no fake anchor). Diagnosis-before-contract
      recorded. Q1=A1 512×512; Q2=A no delay-before-show; Q3=A;
      Q5=B; 393 related-not-equivalent; 15.4 real fix; M1/M2 Debug
      limit; M3 order protocol not executed (index odd/even only).
      Peak-memory baseline is a **hard gate before 15.5**, not
      optional. Three-axis Cap 16 invariant (ADR-030 language).
      Non-goal: Limited banner remount
- [x] 15.3 Layer 1-miss chrome unified to `_FeedCornerChrome`
      (debt 399+398); **no** delay-before-show. Work `4767ec4`;
      ADR-031 Accepted in this docs commit (anchor `4767ec4`).
      UX-1 (402) incidental; owner judges at 15.8. Kafka device
      chrome PASS (miss corner; library loading still centered)
- [x] 15.4 Single current-item activation (debt 396) — **real
      fix** (M2 `preview_supersede` ≠ 1), not verify-only. Work
      `ce18a33`; join in-flight L1 on neighbour→current promote.
      Kafka 2026-08-20 Debug WT15 (uncommitted): M1+2 five
      `page_changed`, zero `preview_supersede`; M1 one
      `layer2_load_start` per become-current
- [x] 15.5 Still Layer 1→2 gapless handoff (debt 394 stills).
      Work `6c7d3de` (gapless `32928a8`/`8cedea4` + sized decode
      `ResizeImagePolicy.fit`). Kafka Round 4 **PASS**: Fit flash
      none; aspect vs iOS Photos spot-check OK; no jetsam /
      force-quit / sustained climb. Memory not Round-3-systemic; do
      **not** bite ≈261. S2≈334 = pre-existing slow iCloud + gapless
      + preheat overlap (not a sized-decode regression) —
      `cap15-15.5-notes.md`. Keep 14.4d latch. Debt 394 **video**
      remains 15.7.
- [x] 15.6 Layer 1 local-hit A1: Host `previewTargetSize` **512×512**
      (debt 400; ADR-031 Q1=A1). Work `52e775c`. Kafka Protocol B
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
      Platform View contract. Work `b21b9fc` (2026-08-22). Keep
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
      `locallyAvailable` KVC). Work `750ddd6`. Kafka 2026-08-22
      Profile PASS — `cap15-15.10-notes.md`. Cap 16 M7 PASS
      qualitative-only (no numeric re-record). ADR-025 narrow supersede
      (this docs commit). 393/400 still open. 393 explore **paused**
      (scope gap: peek phase — see notes §G).
- [x] 15.11 Shared PV transition guard (393 peek + settle) +
      handoff deadlocks — cover + transition mute; Host
      **ready-for-display** trust (ADR-032; attach-ack retained but not
      unwrap); 15.11b poster-hold / settle-on-target (cover vs audio
      split) / stale feed-index re-arm / `_layer2InFlight` generation
      clear. Design: `cap15-debt393-explore-scope.md`. Work `c8a59b3`.
      Kafka + i17 Profile PASS — `cap15-15.11-notes.md`. Debt **393
      closed**. Debt **400** still open. iCloud load UX clue → Known
      debt (separate).
- [x] 15.12 Local first-visit skip L1 (deviceLocal) — work
      `a5cf507` (2026-08-24). Become-current skip Layer 1 when
      `AssetAvailability.deviceLocal`. Widget W-15.12*. Kafka
      large-library later stalled on resolve-time full availability
      scan (「正在加载图库…」) — **fixed by 15.15**, not rolled back
      here. i17 small/mostly-local hid the stall.
- [x] 15.13 Stale preview heal — work `4ceea4e` (2026-08-24).
      Session `lookupIfCoverOnDisk` evicts token when cover file
      gone. Widget coverage; device verified in the 15.12–15.14c
      Kafka/i17 chain (no separate notes file).
- [x] 15.14 Peek cover reuse on deviceLocal become-current —
      work `e866ed8` (2026-08-24). Skip second `requestPreview` when
      peek file still on disk (W-15.14a). Device: same chain.
- [x] 15.14b Arm poster-hold at L2 apply when `canReuseCover` —
      work `15a5bce` (2026-08-24). W-15.14b. Kafka still showed
      intermittent revisit peek black-flash when peek file already
      evicted (`canReuseCover=false`) — covered by 15.14c.
- [x] 15.15 resolveSource empty availabilities + on-demand
      `getAssetAvailabilities` — work `8b5802d` (2026-08-24);
      ADR-033. Kafka Profile 2026-08-24: 「正在加载图库…」reasonable
      duration **PASS**.
- [x] 15.14c DEVICE_LOCAL L2 apply always arms poster-hold —
      work `3fe9dd9` (2026-08-24). W-15.14c (dead peek file).
      Kafka + i17 Profile 2026-08-24: video revisit peek black-flash
      **not re-observed (PASS)**. Still revisit ~0.5s corner spinner
      on Kafka = Known debt (Host temp vs L2-ready), not this phase.
- [x] 15.9 Cap close-out: Cap 15 `[x]`; YOU ARE HERE → Cap 17
      placeholder; PHASE_HISTORY this snapshot; ADR-033; Known debt
      (L2-ready vs Host temps; KVC row; debt **400** Picks it up
      still open at close-out)
      — docs (this commit)

Docs close-out (STATE + PHASE_HISTORY + ADR-033): (this commit)

Related ADR: ADR-031 (Accepted, `4767ec4`); ADR-032 (`c8a59b3`);
ADR-033 (`8b5802d`).
Known debt at close: **400 still open** (Limited / local-only video
no Layer 1 poster — Host cannot invent pixels). 393 closed (15.11).
Session L2-ready vs display ≤1+1 / preview cap-3 temps (still
revisit spinner) recorded as a new row. iCloud load-speed / wait-UX
row unchanged. Do not treat 400 as closed because 393 or the spinner
debt were addressed.
