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
