# WakeTok — Engineering State

> Current engineering state. Read this FIRST before starting work in a new chat.
> Maintenance: facts only, no history. Update = rewrite the relevant line.
> NEVER append paragraphs here.
> Conflict priority:
> - Architecture and product rules:
>   owner decision > DECISIONS.md > STATE.md > local kickoff > code
> - Current implementation state: code/git > STATE.md
> - Code that conflicts with an accepted ADR is a defect, not a decision override.
> History / rationale -> DECISIONS.md. Completed capability phase snapshots -> docs/PHASE_HISTORY.md.
> Private product spec -> docs/WakeTok(App)_project_kickoff.md (local only, gitignored, READ-ONLY for AI tools).

## Project facts
- Product: WakeTok — local-first personal media Rediscovery Player (iOS; Flutter UI + Swift native media layer)
- Flutter project name: `waketok`; device display name: WakeTok
- Bundle ID: `com.dennycgan.waketok`
  - Explicit App ID registration in Certificates, Identifiers & Profiles: owner-only
  - App Store Connect app-record: created — App name `WakeTok` reserved
    (primary language English (UK)); further ASC configuration remains owner-only
  - See `release-handoff.mdc`
- iOS deployment target: iOS 18.0 (see ADR-007; ADR-005 superseded)
- Test devices: iPhone 13 (performance floor), iPhone 17 (current-device compat)
- No backend, no custom auth, no remote database, no developer-owned media server (kickoff Tech Stack)
- Repository visibility: Private (see Known debt for public eligibility + pre-flight scan)
- Repository history: rewritten **2026-09-04** to purge `docs/GLOSSARY.en-zh.md`
  from all git history (privacy). Commit SHAs before that rewrite are obsolete;
  docs anchors were batch-remapped via filter-repo commit-map. Local offline
  backup of pre-purge history: `WakeTok-pre-purge-backup-20260904.git` (owner
  machine only; not in this repo). Re-verify Host pinch hit-test notes after
  Flutter SDK upgrades (Scrollable `DragScrollActivity.shouldIgnorePointer`).
  Same fragility family first observable symptom: debt **458**.
- Browse brief action feedback: use Cap 19 `showCap19BrowseToast` (top
  overlay under source chrome). Do **not** use Material bottom `SnackBar`
  for success/error toasts (Cap 19.5b owner §7 item 7; welded convention).
  Machine-guarded: `test/architecture/dependency_test.dart` fails on
  `SnackBar(` / `.showSnackBar(` under `lib/features/**` and `lib/app/**`
  (ADR-009 Enforcement — not owner-only post-capability audit).
  Toast top inset uses `MediaQueryData.fromView(View.of(context)).viewPadding`
  (not `MediaQuery.padding` / inherited `viewPadding`) so callers under
  top-chrome `SafeArea` — which zeroes both inherited paddings — match
  feed/left-swipe Y.
  Centered `AlertDialog` (naming / capacity / Info / delete) is orthogonal.

## Capability Roadmap (project-level; top-to-bottom = execution order; YOU ARE HERE)
- [x] Project Bootstrap (flutter create scaffold, pigeon/ placeholder, docs skeleton, root commit)
- [x] POC-04: Flutter Media Feed Architecture Gate (must pass before production domain/data/feature implementation)
- [x] POC-03: Lock-screen continuous playback gate (must pass before production domain/data/feature implementation)
- [x] POC-09: Current Photos Representation Export Gate
      (must pass before production physical-clip implementation)
- [x] App Foundation
      (gen_l10n + ARB localisation infrastructure, shared error/result
      contracts, production Pigeon contract baseline)
- [x] iOS Photos permission, Library access, iCloud asset state handling
      (phase 5.1 establishes theme token baseline; token-only styling
      from this capability onward — ADR-009)
- [x] All / Photos / Videos built-in source resolution
      (production resolution must enumerate the FULL library including
      iCloud-only assets; device-local filtering is spike-only; acceptance
      includes date-distribution sampling on owner's real 40k library)
- [x] Main Browse Screen and vertical Media Feed
      (ADR-014; Cap 7.7a Profile V-hard PASS; accent/brandGold freeze
      `009f804`; Release hang Known debt separate)
- [x] Media Info Overlay, loading states, empty states,
      POC-10 file-size semantics,
      optional best-effort Location Label (not release-blocking)
      (ADR-015…018; 8.8 notes; Location Known debt remains;
      cross-source playhead Accepted ADR-023 / Cap 13.5)
- [x] Live Photo rendering and static fallback (POC-08)
      (ADR-019; POC-08 PASS Cap 9.7; mute persist `474fb6a`;
      debt **436** open; debt **437** closed 14.6b `77afb23`;
      notes `cap9-9.7-poc08-notes.md`)
- [x] Asset Source and Source Pool Definition
      domain models
      (ADR-020; kinds `00b52ad`; SPD `894aef8`; ordering `4fa2104`)
- [x] Live Resolution, Asset Source Availability,
      Identity Coalescing, and Resolved Pool Snapshot
      (ADR-021; list `5179ac1`; album resolve `d1d01f0`;
      Snapshot `fd22ece`; smoke `d76dbe3`; notes 11.2/11.3/11.6)
- [x] Session Queue, Default Session Profile,
      and stable Item Ordering Semantics
      (ADR-022; CFG `87d7dce`; derive `c516c19`;
      Queue `0f622a5`; guard `1b4b8d9`; accept `894c74c`)
- [x] Endless Shuffle, Queue Stability, and Session Continuity
      (Cap 13 / ADR-023 Accepted `1d15caf`; ADR-024 `1a4f316`;
      13.6 closed under ADR-030 §5 everyday availability, owner
      2026-08-19 — not an Instruments numeric Pass; FAIL tables
      frozen)
- [x] Current-item iCloud media fetch, visual
      preheating, and loading states
      (Cap 14 / ADR-025 Accepted, work `a980506`; **first** 13.6
      foundation paid — iCloud copy-panel unreadability)
- [x] Feed swipe Layer 1→2 handoff polish and
      duplicate current-item Layer 2 request
      (Cap 15 / ADR-031…033; work through `5667a09`;
      debt **393** closed; notes `docs/acceptance/cap15-*.md`)
- [x] Cancel and dwell current-item Layer 2 fetch
      (Cap 16 / ADR-029 Accepted, work `255656d`; notes
      `docs/acceptance/cap16-16.5-notes.md`; **second** 13.6
      foundation paid on the product path; 13.6 closed under
      ADR-030 everyday availability, not an Instruments Pass)
- [x] Main Browse Layer 1→2 chrome and iCloud
      availability hardening (Cap 17 / ADR-034…039;
      `docs/acceptance/cap17-17.*.md`; PHASE_HISTORY)
- [x] Main Browse playback controls and gesture arbitration (Cap 18 /
      ADR-040; `docs/acceptance/cap18-18.*.md`; PHASE_HISTORY)
- [x] Add to Album / Cap 19 entry chrome (Cap 19 /
      ADR-041…042; `docs/acceptance/cap19-*.md`; PHASE_HISTORY)
- [x] Display magnification (pinch to zoom, lightweight) (Cap 20 /
      ADR-043; L2 still persistent + Reset; L1 + video L2 transient;
      D5=4×; `docs/acceptance/cap20-*.md`; PHASE_HISTORY)
- [x] Build a Pool, Ephemeral Pool, and Source ordering (Cap 21 /
      ADR-044…045; `docs/acceptance/cap21-*.md`; PHASE_HISTORY)
- [x] Saved Pool persistence, reopen, management, and capacity limits
      (Cap 22 / ADR-046…048; `docs/acceptance/cap22-*.md`;
      PHASE_HISTORY)
- [x] Current-asset still-in-library gate for mutation chrome
      (Cap 23 / ADR-049 Accepted; `docs/acceptance/cap23-*.md`;
      PHASE_HISTORY; debt **456b** Closed at 23.4)
- [x] Soft-delete current asset to Photos Recently Deleted
      (Cap 24 / ADR-050 Accepted; App soft-delete only; kick Session
      Queue on success; fail-closed on Host failure; narrow-supersede
      kickoff Do Not Build #4 delete bans + P1–P5; after still-in-library
      gate; PHASE_HISTORY)
- [x] Share current asset from Action Column
      (Cap 25 / ADR-051 Accepted; Q1=B …=0 Share=1 Album=2;
      Cap 23 gate; system share sheet; D14 enable + D15
      saveToCameraRoll exclude; PHASE_HISTORY)
> **MVP v1 submission track** — minimal closed loop for first App Review.
> Positioning: "Wake what you saved — A local-first vertical feed for
> rediscovering your own photo and video library." + album random-browse /
> light organize. Clip Export / Clip-dedicated Auto-play = v2 track below.

- [ ] Live Photo long-press replay + "…" half-sheet size field
      and Add-to-Album second entry
      (+ Overlay row-3 Animated still label / ADR-053)
      (supersedes ADR-040 D17 no-long-press limb; D17's explicit
      replay control was Decision-17'd but never actually shipped —
      no existing UI to remove; long-press replaces it as the sole
      replay affordance; narrowly reopens ADR-050 "Second
      Add-to-Album…deferred" for the entry-button half only —
      location stays deferred; second entry = close "…" sheet then
      present existing Cap 19 Album half-sheet, no new transition UI;
      size field reuses existing requestPresentationFileSize Pigeon
      path; Animated = presentation-only `isAnimated`, Cap 26.3
      before size 26.4) <-- YOU ARE HERE
- [ ] Auto bottom-nav slot redefinition — pull-up order-control sheet
      (Layer 1 only: newest / oldest / random switch, immediate
      requeue, default stays random; Auto is no longer a standalone
      bottom-nav destination — narrowly amend ADR-027 leave-Browse
      trigger: session end only on leave to remaining destinations
      (Settings / Clips if kept), not on opening the in-Browse sheet;
      resolve Clips stub visibility for Review; Layer 2/3 — autoplay
      on/off + autoplay-internal ordering — stay in "Auto-play Presets
      and Mode Eligibility Rule" below, paired with Clips v2)
- [ ] Debt 421 — Limited Access manage entry restored
      (presentLimitedLibraryPicker + Open Settings entry point;
      extracted from "Settings and localisation completion" below;
      pre-work: audit MainBrowseShellPage overlay stack alongside the
      new Auto sheet entry to avoid repeating the original notch /
      SafeArea layering bug that caused this debt)
- [ ] First-launch vertical-swipe guidance
      (minimal TikTok-style up/down hint; must not time-overlap with
      existing Cap 19.7 left-swipe guide — flexible scheduling, may
      slot alongside any of the three Caps above)
- [ ] MVP v1 pre-submission hardening
      (privacy policy final copy — after the three functional Caps
      above land; permission string finalize; portrait-only already
      locked — ADR-028 + Info.plist + SystemChrome +
      test/architecture/presentation_defaults_test.dart — no product
      work, verify only; small-screen device pass; App Store
      description / screenshots / keywords; empty-state Action Column
      dim widget-test coverage — near-zero cost, attach to whichever
      Cap above is convenient)
- [ ] TestFlight internal testing and release-candidate validation
      (MVP v1 track; owner executes distribution; Cursor prepares
      build and metadata)
- [ ] App Store metadata, screenshots, privacy disclosures,
      submission, and release verification
      (MVP v1 track first Review; owner executes submission; Cursor
      prepares assets only)

> **Post–v1 / Clips v2 track** — not in first Review scope. Distinct
> TestFlight / App Store Caps below are a second release event (Clip /
> background privacy disclosures etc.), not a merge of the v1 track.

- [ ] Auto-play Presets and Mode Eligibility Rule
      (Layer 2/3 only: autoplay on/off + autoplay-internal ordering
      e.g. single-asset replay; bottom-nav Auto destination nature is
      already decided in "Auto bottom-nav slot redefinition" above —
      this Cap owns eligibility rules and Layer 2/3 settings only;
      paired with Clips v2)
- [ ] Auto-play One-item Lookahead Fetch, Waiting for Media, and
      iCloud Fallback
      (renamed so "iCloud Fallback" is Auto-play / ADR-O, not Cap 14)
- [ ] Background Audio, lock-screen playback, system media controls
- [ ] SessionCheckpoint and Session Recovery
      (Queue, current Media Item, playback position,
      Waiting for Media, and process-termination contract)
- [ ] Physical Clip Export Core
      (fixed 120-second segments, POC-06 and POC-07,
      persistent Export Job / Segment state machine,
      cancellation and recoverable partial success;
      includes ClipExportApi Pigeon contract design,
      deferred from App Foundation)
- [ ] Photos import, backing Album, Clip Descriptor,
      and Generated Clip Source
- [ ] Clip export progress/result UI,
      failed-segment retry, cancellation, and resume UX
- [ ] Mute, Fit / Fill / 9:16 Crop, 2x gesture
      (Share already shipped Cap 25; tap-to-pause/resume Cap 18; MVP 2x
      = left or right edge hold temporary 2x, release → 1x; no
      slide-down lock; Cap 18 froze edge-hold slots only)
- [ ] Settings and localisation completion
      (remaining English / zh-Hans copy sweep; privacy / storage /
      about screens; Light/Dark layout verification; Limited Access
      manage entry already completed in the Debt 421 Cap above)
- [ ] Final real-device performance, memory,
      accessibility, privacy, and error-state hardening
      (full-product / post-Clips pass; distinct from MVP v1 hardening)
- [ ] TestFlight internal testing and release-candidate validation
      (post–v1 / Clips track; owner executes distribution; Cursor
      prepares build and metadata)
- [ ] App Store metadata, screenshots, privacy disclosures,
      submission, and release verification
      (post–v1 full-product Review — Clip / background privacy
      disclosures etc.; owner executes submission; Cursor prepares
      assets only)

> Each line is a capability, not a sub-step. Completed capabilities stay one line
> (phase snapshots -> docs/PHASE_HISTORY.md). Only the ACTIVE capability is
> expanded in the Phase Roadmap below.
> PoC placement:
> - POC-01 is closed as Failed and is not scheduled again.
> - POC-02 (Query Source) and POC-05 (CarPlay) are deferred outside MVP.
> - POC-04, POC-03, and POC-09 are closed project gates (see DECISIONS).
> - App Foundation is closed (see PHASE_HISTORY).
> - POC-06, POC-07, POC-08, and POC-10 run inside the capability
>   that consumes their result.
> Top-to-bottom = current execution order. Reorder if priorities change; never leave it unordered.

## Phase Roadmap (active capability only)
Active capability: Live Photo long-press replay + "…" half-sheet size
field and Add-to-Album second entry
Contract: owner-locked Cap kickoff (2026-09-15) — ADR-052 **Proposed**
in `docs/DECISIONS.md`; Overlay Animated — ADR-053 **Accepted**
(`fc0bfcc`; 26.3 done; "…" size is 26.4). Supersedes ADR-040 D17
no-long-press limb; narrow-reopens ADR-050 "…" Add-to-Album entry-button
half only (location / debt **401** stay Out); ADR-019 D8 directed
exception = App long-press; manual long-press **bypasses** Cap 25
Live-ended watchdog session skip set
(`browseLiveMotionWatchdogSkipIdsProvider`).
Owner Q1–Q9 locked (hold **400 ms** / haptic B / static-only A / mag A
/ sheet A / size A+omit-overridden-to-em-dash / row-order A / 405 Out A
/ single ADR A).
Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline

- [x] 26.1 Contract freeze
      (ADR-052 Proposed appended; debt **439** Picks it up → Cap 26;
      no `lib/` in this phase)
- [x] 26.2 Live long-press → play-only / silent re-request replay
      (work `cab0747`; Path R+S; silent in-flight lock; lifecycle Path S
      cancel; skip bypass; D11; debt **470** Accepted (phase) magnified
      ignore; i17 Profile smoke PASS)
- [x] 26.3 Overlay row-3 Animated still label
      (work `fc0bfcc`; ADR-053 Accepted; `isAnimated` via
      `playbackStyle == .imageAnimated`; no badge; Kafka + i17 Profile
      smoke PASS)
- [x] 26.4 "…" half-sheet size row
      (work `c1a0d13`; `presentationSizeCacheProvider` shared with
      Overlay; title always; never omit; resolved ∧ nil → "—"; L2-ready
      refresh; layout notes §12 + §12.6 Location home locked; Kafka +
      i17 Profile smoke PASS)
- [x] 26.4a Meta Overlay: keep chrome across still L1→L2 cover path
      upgrade
      (work `aee8ba5`; `_trackStillCoverPath` keep-ready; layout notes
      §13; debt **472** Closed — video Out structurally, not side-fix;
      Kafka + i17 Profile PASS)
- [x] 26.5 "…" Add-to-Album second entry
      (work `7001e6e`; muted Add above Delete; Cap 23 → pop → Cap 19;
      mutual latch; layout notes §12; W-26.5-1…7; Kafka + i17 Profile
      smoke PASS)
- [ ] 26.4b Misc polish (media / "…" chrome layout)
      (owner layout UI tweaks; keep
      `docs/reference/media-chrome-layout-notes.md` in sync) <-- YOU ARE HERE
- [ ] 26.6 Device acceptance (Kafka + i17) + Cap close
      (debt **439** Closed; ADR-052 Accepted + anchors; PHASE_HISTORY;
      two-commit discipline)

## Now working on (describe ONLY the in-progress item)
- Goal (one line): Cap 26.4b — Misc polish (chrome layout)
- Sub-steps done: 26.1–26.5; ADR-053 Accepted (`fc0bfcc`); 26.5 work
      `7001e6e` + Kafka / i17 Profile PASS; ADR-052 still Proposed
- Next step: owner layout UI adjustments + layout notes updates
- Related decisions: ADR-053 Accepted; ADR-052 Proposed (D1–D11;
      D7/D8 / D9); layout notes §12 / §12.6 / §13; ADR-015 / 018 /
      043 D12 / 050 continue; debt **439** → Cap 26; **401** Location
      content Out; **405** Out; **470** Accepted (phase); **469**
      Accepted (permanent); **472** Closed by Cap 26.4a

## Contract pointers (don't memorize, go read the source)
- Domain terms (bilingual, **local only / gitignored**):
  docs/GLOSSARY.en-zh.md — not published; Cap-frozen terms also in
  DECISIONS.md (e.g. ADR-043 Display Magnification)
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/waketok_platform_apis.dart → lib/platform/generated/, ios/Runner/Platform/ (spike under pigeon/spikes/ reference only)
- l10n: lib/l10n/ (ARB + AppLocalizations; locale_resolution.dart; untranslated_messages.json)
- **zh Pool product copy:** Cap 7 / Cap 21 chrome+Build zh ARB strings
  use the Cap 7 pool product-copy convention (`mainBrowsePoolsTab`,
  `mainBrowseCreatePool`, Temp chip, Saved placeholders). Kickoff /
  GLOSSARY concept term and English **Pool** are concept / EN-ARB /
  identifier vocabulary only — do not put EN “Pool” or the kickoff
  concept term into `app_zh_Hans.arb` product strings (Cap 22 Saved
  copy too). Debug `library_smoke` probe strings may still say Pool.
  (Do not paste locale glyphs into STATE — cite ARB keys.)
- **Ephemeral / Saved pool `feedSourceKind`:** any
  `BrowseOriginEphemeralPool` or `BrowseOriginSavedPool` maps to
  `AssetSourceKind.entireLibrary` (`BrowseChromeState.feedSourceKind`;
  ephemeral work `74c84e1`; Saved `saved:$poolId` feed id in `4db65ec`).
  Feed Layer 2 / Live / video fallback only know built-in
  kinds; passing `album` / `smartAlbum` hard-fails every item (L1 still
  OK). Not a product fork — restores the mixed-content probe contract.
  U-21.4-11 locks ephemeral. No separate ADR (ADR-044 already Accepted).
- **Limited / empty Build catalog:** Cap 21.4b catalog lists **user
  albums** (My Albums) + **curated system albums** (whitelist ∩
  non-empty). Limited (or any grant with zero listable user albums and
  zero visible system albums) shows the empty catalog copy — Start stays
  disabled. Cap 21.5 (`80128a3`): Create is **disabled** under Limited
  with `mainBrowseCreatePoolRequiresFullAccess` caption. Cap 21.5 ZH Full
  Access root wording follows Cap 5.3 `limitedAccessBannerMessage` (not
  Cap 19.5b). Cap 19.5b `cap19PanelAddToAlbumLimitedMessage` still uses a
  different Full Access phrasing — known drift, not fixed in the Cap 21.5
  copy-align follow-up (leave for a later localisation sweep). Expected:
  Build-a-Pool is effectively unusable until Full Access + listable
  sources; browsing All / Photos / Videos remains via top Built-in tabs.
  Built-ins stay omitted from the Build list (Accepted deviation vs
  ADR-044 §11). Boundary table:
  `docs/reference/cap21-smart-album-boundary.md`.
- **`assetSourcesProvider` list lag (Cap 21.5 / Cap 22):**
  Album-catalog data updates only when the FutureProvider is actively
  (re)read after invalidate — it does **not** auto-observe Photos library
  mutations. Cap 21.5 invalidates on Build open. Cap 22 Saved list /
  Info / chip peek also invalidate on open (ADR-046 D8) — debt **455**
  **Closed by Cap 22**. Session/Queue lag remains ADR-027 / ADR-023 D7
  (orthogonal).
- **Cap 21.4b smart-album boundary (live maintenance):** dead whitelist /
  exclude table + live emptiness / brute-enum rules —
  `docs/reference/cap21-smart-album-boundary.md`. New iOS subtypes do
  **not** auto-join; owner edits the table + ARB deliberately. Work
  `67cb08b`.
- PhotoKit multi-surface identity mismatches (Live/Animated;
  `mediaSubtypes` vs `playbackStyle` vs smart-album membership) +
  other implicit Host index:
  `docs/reference/ios-photokit-implicit-behavior-notes.md`
  (debt **471**; ADR-052 D11; ADR-053)
- Localization guard: ADR-012 + test/architecture/localization_test.dart
- Theme: lib/core/theme/ (WakeTokTokens ThemeExtension + waketokTheme; ADR-009)
- Authorization: lib/domain/authorization/, lib/platform/photo_library_gateway.dart, lib/features/authorization/ (ADR-010)
- Library catalog: lib/domain/library/, PhotoLibraryApi.libraryTotals / fetchLibraryPage (ADR-011); debug totals shell: lib/features/library_smoke/
- Main Browse shell: lib/features/main_browse/ (Cap 7.4–7.6 feed;
  Cap 8.2 immersive content + always-dark bottom bar `9c05462` / ADR-017;
  transparent top + compact bar `3c7aa1d` / ADR-016);
  Cap 14.4c IndexedStack always wrapped in immersive Theme (`9eecc7e`)
  so Settings cannot dispose VerticalMediaFeed;
  Cap 13.4 Shuffle Session wiring: `lib/app/browse/browse_session_providers.dart`
  (`aa03be8` / ADR-023);
  media-area chrome layout (Reset / LIVE / actions / MVP 3-row meta):
  `media_chrome_layout.dart` + work `81904e1`; notes
  `docs/reference/media-chrome-layout-notes.md` (not Cap 20–only; not ADR-043)
- Built-in sources: lib/domain/source/, PhotoLibraryApi.listAssetSources / resolveSource (ADR-013); providers: lib/features/library_smoke/asset_source_providers.dart
- Cap 11.2 list albums: Host `listAssetSources` Full = built-ins +
  albumRegular + smart (Hidden/RD excluded); Limited = built-ins only;
  domain `AssetSource.displayName` + nullable `estimatedCount`;
  gateway maps album/smartAlbum (`other` still throws); work `5179ac1`;
  notes `docs/acceptance/cap11-11.2-notes.md`
- Cap 11.3 resolve albums: Host `resolveSource` album/smartAlbum
  (creationDateDescending, image|video); Limited → unauthorized;
  missing collection → albumUnavailable; empty list = Empty;
  `ItemOrderingPolicy.forKind` aligned; debug probe cache `d1d01f0`;
  notes `docs/acceptance/cap11-11.3-notes.md`
- Cap 11.4 resolvePool: `lib/domain/source/resolve_pool.dart`,
  `resolved_pool_snapshot.dart`, `source_resolve_attempt.dart`,
  `source_resolve_status.dart`; sequential first-appearance coalesce;
  work `fd22ece`
- Cap 11.5 composition: `source_resolve_attempt_mapping.dart` +
  library_smoke Photos+All `resolvePool` probe; Main Browse unchanged;
  architecture guard `main_browse` ↛ `resolve_pool.dart`; work `d76dbe3`
- Cap 11.6 device coalesce: Photos+All `C=A`, All `contrib=V`; Kafka
  Full/Limited + iPhone 17 Full PASS; notes
  `docs/acceptance/cap11-11.6-notes.md`
- Source Pool Definition (Cap 10 / ADR-020):
  `lib/domain/source/source_pool_definition.dart`,
  `persistence_policy.dart`, `pool_capacity.dart`,
  `item_ordering_policy.dart`; `SourceReference` + `AssetSourceKind`
  (album/smartAlbum); work kinds `00b52ad` / SPD `894aef8` / ordering `4fa2104`
- Playback / display: lib/domain/playback/, lib/platform/playback_gateway.dart;
  PhotoLibraryApi.requestPreview (Cap 14.2 `a980506` / ADR-025 Layer 1,
  local-only still + video poster, cancellable);
  PhotoLibraryApi.requestDisplayAsset / requestPlayableVideo (Cap 14.3
  `92c3a60` / ADR-025 Layer 2 current item: network allowed + cancel;
  never `iCloudDownloadRequired`; ADR-006 Status narrow supersede);
  Feed three-layer UI (Cap 14.4 `9bfc4c7`): Layer 1 preview then
  current-item Layer 2; Layer 3 spinner Semantics; Retry overlay
  when a still remains; `mainBrowseFeedICloudOnly` retired;
  Feed ±1 neighbour `requestPreview` / `releasePreview` two-phase
  window (Cap 14.5 `e278f65`);
  Item-load chrome bottom-right (Cap 14.6b `77afb23`: LIVE badge +
  Layer 2 / Live-prepare spinner; Cap 15.3 `962b6d1`: Layer 1-miss
  `_loading` uses the same `_FeedCornerChrome`; library resolve
  loading stays centered; Cap 15.4 `d532064`: join in-flight Layer 1
  on neighbour→current promote — L1 `_localGate`, L2
  `currentDisplayGate`);
  Cap 16 leave-cancel `cancelInFlightPrepare` (`255656d` / ADR-029)
  + one networked `load` (`22ece57`) + Dart dwell **300 ms**
  (Cap 17.5 `15edc91` / ADR-035; was 500 ms `26294f5`); notes
  `docs/acceptance/cap16-16.5-notes.md` +
  `docs/acceptance/cap17-17.5-notes.md`;
  PlaybackRepository.clearPlaybackPool (Cap 9.3 `72a3a04` / ADR-019);
  debug probe: lib/features/library_smoke/playback_pipeline_probe.dart
- Live Photo motion: ios/Runner/Platform/LivePhotoApiHost.swift
  (viewType `waketok/live_photo_surface`); Pigeon LivePhotoApi /
  LivePhotoFlutterApi (Cap 9.2); Dart domain
  `lib/domain/live_photo/` + `LivePhotoGateway` +
  `livePhotoRepositoryProvider` (Cap 9.3 `72a3a04`); Feed play-once +
  `LiveHostOpSerial` (Cap 9.4 `db7a3e4`); preparing spinner +
  `gatedFlagUpdate` (Cap 9.5 `6f386c2`); 14.6b `77afb23` moves badge
  + preparing spinner to bottom-right (debt **437** closed);
  `sharedMuteProvider` + mute
  re-apply (Cap 9.6 `8fcd875`); video host mute persist (Cap 9.7
  `474fb6a` / ADR-019)
- Presentation Metadata: lib/domain/presentation/,
  PhotoLibraryApi.requestPresentationMetadata /
  requestPresentationFileSize (Cap 8.3 `79dc3bc` / ADR-015; Live still
  size ADR-018); Overlay + dual-gate + session cache: Cap 8.5 `f33c99e`
  (`lib/features/main_browse/media_info_overlay.dart`,
  `feed_activation_coordinator.dart`); provider:
  lib/features/library_smoke/presentation_providers.dart
- Errors / Result: lib/core/errors/, lib/core/result/ (ADR-008); ErrorCode mapping in lib/platform/error_code_mapping.dart
- Architecture boundaries: ADR-009 + ADR-010 + ADR-012 + test/architecture/ guard tests
- Cap 12 Session Configuration: `lib/domain/session/` —
  OrderPolicy / AdvanceMode / RepeatPolicy + SessionConfiguration
  (`87d7dce`); DefaultSessionProfile + classify/derive (`c516c19`,
  DPR-1…7; Cap 12 always generalMixed); SessionQueue +
  buildSessionQueue Sequential (`0f622a5`); Cap 13.2 Shuffle
  (`1d15caf`, SHUF-1…7; Cap 12 UnsupportedError removed);
  architecture guard main_browse ↛ build_session_queue (`1b4b8d9`)
- Cap 12.1 contract: ADR-022 Accepted (D1–D6=A) — Sequential Session
  Queue + Default Profile domain; derive ≠ apply was Cap 12; Cap 13.4
  (`aa03be8`) applied Mixed → Shuffle on Main Browse (ADR-023 /
  ADR-014 Decisions 2–3 superseded); segmentIndex = Generated Clip
  resolve-time (D5); OrderPolicy includes shuffle (Cap 13.2
  implements construction); D9 seam: `main_browse` still ↛
  `build_session_queue` / `resolve_pool` (wiring in `lib/app/browse/`)
- Cap 12.6 acceptance: unit-only (no device PoC); full `flutter test`
  PASS (+247) at HEAD `3ff004c`; no `docs/acceptance/cap12-12.6-notes.md`
- Cap 13.1 contract: ADR-023 Accepted (D1–D9=A, anchor `1d15caf`) —
  Endless Shuffle + Queue Stability + in-session Continuity; Main
  Browse Mixed → Shuffle product apply landed 13.4 (`aa03be8`); slim
  ConsumptionSession; Manual Shuffle = full Snapshot; playhead debt
  reclassified Accepted Cap 13.5 (not bug-fix; row kept); tab = new Session;
  13.6 closed under ADR-030 §5 (everyday availability, 2026-08-19),
  not Instruments V-hard
- Cap 13.2 Endless Shuffle: `buildSessionQueue` Fisher–Yates +
  injectable Random + `previousRoundLastId` first≠last retries;
  work `1d15caf`
- Cap 13.3 Continuity: `lib/domain/session/consumption_session.dart`
  — slim in-memory session; `startConsumptionSession` /
  `applySessionConfiguration` (Order rebuild + asset-id remap;
  Advance/Repeat config-only); no Checkpoint / browse history;
  work `7fa4aa4`
- Cap 13.8 Browse empty / failure feed:
  `lib/app/browse/browse_session_providers.dart` (`_snapshotFor` caches
  only when there is no hard failure **and** the coalesced list is
  non-empty; Cap 14.6 `d32a309` keeps resolve-loading on successful
  empty and re-resolves 3 extra times at 500/1000/2000 ms;
  `b9c2d68` skips resume auth invalidate while `requestAccess` is in
  flight and `restartSession` after Limited/full grant) +
  `lib/features/main_browse/vertical_media_feed.dart`
  (empty ids with `unauthorized` / `unavailable` status →
  resolve-failed panel + Retry, not empty copy); work `1a4f316` /
  ADR-024; 14.6 Kafka Profile PASS
- ADR-001 … ADR-031: docs/DECISIONS.md (ADR-031 Cap 15 Layer 1→2
  handoff polish — **Accepted**, anchor `962b6d1`; ADR-030 retires Instruments
  numeric hitch/hang gates — **Accepted**, anchor `162ed8e`; ADR-029
  Cap 16 cancel and dwell current-item Layer 2 — **Accepted**,
  anchor `255656d`; Decision 2 production dwell N numeric value
  superseded by ADR-035 (`15edc91`, 2026-08-26); ADR-028
  default Fit +
  portrait-only — **Accepted**, anchor `d70fddf`; ADR-027 Cap 14.4e leave Browse
  ends Consumption Session — **Accepted**, anchor `5658cf2`; ADR-026
  Cap 14.4d foreground video item-loop + return-to-ended replay —
  Accepted, anchor `24dbb88`; ADR-025 Cap 14 current-item iCloud fetch
  — Accepted, anchor `a980506`; ADR-024 Cap 13.8 Browse Snapshot cache
  — Accepted, anchor `1a4f316`; ADR-023 Cap 13 Endless Shuffle —
  Accepted, anchor `1d15caf`; ADR-022 Cap 12 Session Queue Accepted,
  anchor `87d7dce`; ADR-021 Cap 11 Live Resolution Accepted, anchor
  `5179ac1`; ADR-020 Cap 10 models Accepted)
- ADR-034: Cap 17 wait chrome / debt **400** / iCloud observability —
  **Accepted** (2026-08-25), anchor `65ea272` (Cap 17.3 work);
  Cap 17.4 presentation work `c3aa2dc` (Decision 3); debt **400**
  remains on the table as accepted residual (permanent) — Picks it up
  → Unassigned (ADR-034)
- ADR-035: Cap 17.5 production Layer-2 dwell N = 300 ms —
  **Accepted** (2026-08-26), anchor `15edc91`; supersedes ADR-029
  Decision 2 numeric N only
- ADR-036: Cap 17.5b Retry visibility + corner Layer-2 reassure —
  **Accepted** (2026-08-26), anchor `527baeb`
- ADR-037: Live L2→motion prepare chrome continuity (F1 handoff latch) —
  **Accepted** (2026-08-26), anchor `a42abcd`; narrow exception to
  ADR-034 Decision 2 F1
- ADR-038: Cap 17.7 Overlay capture-time honest presentation (~ exact +
  coarse relative bands) — **Accepted** (2026-08-27), anchor `d9db8c7`
- ADR-039: Cap 17.9 wait copy cleanup (delete center Layer2Waiting;
      source-switch L1 label delay) — **Accepted** (2026-08-27), anchor
      `f1ffadf`
- ADR-040: Cap 18 Main Browse gesture arbitration and dual-signal
      Manual playback control — **Accepted** (2026-08-28), anchor
      `0df9ceb` (Cap 18.4 work; 18.3 `84ef30c`)
- ADR-046: Cap 22 Saved Pool persistence — **Accepted** (2026-09-08),
      anchor `d62e962` (Cap 22.2 work); D3/D5/(D7 clear-park clause)
      narrowly superseded by ADR-047
- ADR-047: Cap 22 Build Save & browse + entry-point recipe shells —
      **Accepted** (2026-09-09), anchor `0b68e01` (Cap 22.4
      supplemental; first chrome `0ca1198`)
- ADR-048: Browse Snapshot cache — invalidate on successful in-app
      album membership writes — **Accepted** (2026-09-10), anchor
      `fbf2e82`
- ADR-049: Cap 23 current-asset still-in-library mutation gate —
      **Accepted** (2026-09-10), anchors `32a3617` (23.3) + `4004ad1`
      (23.2) + `893c8fb` (23.4 Case B harden); Proposed `25689b0`
- ADR-050: Cap 24 soft-delete current asset to Photos Recently Deleted —
      **Accepted** (2026-09-10), anchor `32d4bd1` (24.2 Host write;
      related Cap 24 work in PHASE_HISTORY)
- ADR-051: Cap 25 Share current asset from Action Column —
      **Accepted** (2026-09-12), anchor `99c2e73` (25.2 Host present;
      related Cap 25 work in PHASE_HISTORY)
- ADR-052: Cap 26 Live long-press replay + "…" size + Add-to-Album
      second entry — **Proposed** (2026-09-15); D11 effect
      non-discrimination; 26.2 work `cab0747` (Path R+S); Accepted
      + full anchors at Cap 26 close (26.6)
- ADR-053: Overlay row-3 Animated still label — **Accepted**
      (2026-09-15); work `fc0bfcc`; `isAnimated` via
      `playbackStyle == .imageAnimated`; Cap 26.3 closed before "…"
      size (26.4)
- Cap 25.2 presentShareSheet: Pigeon `PhotoLibraryApi.presentShareSheet`;
      domain `AssetShareRepository` + `PhotoLibraryGateway` +
      `assetShareRepositoryProvider`; Host in `PhotoLibraryService`
      (work `99c2e73`; Live-as-still + non-degraded still present =
      ADR-051 D12/D13); gateway tests
      `test/platform/cap25_2_share_gateway_test.dart`
- Cap 25.3 Share chrome: `cap25_share_entry_icon.dart` +
      `cap25_share_toast.dart`; `mainBrowseSharePresentInFlightProvider`;
      ARB `cap25ShareFailed` / `cap25ShareEntryIconSemantics`
      (work `c3b5a58`); widget tests
      `test/features/main_browse/cap25_3_share_entry_test.dart`
- Cap 24 soft-delete locked copy candidates (pre-ARB; EN + zh-Hans):
      `docs/reference/cap24-soft-delete-copy-candidates.md`
- Cap 24.5 device acceptance notes (Kafka + i17 matrix **PASS**):
      `docs/acceptance/cap24-24.5-notes.md`
      (ADR-050 D4 (a)(b) force-quit → real PhotoKit resolve;
      same-process tab switch must not be the sole gate; SYS =
      system PhotoKit consent only)
- Cap 23.4 device acceptance notes:
      `docs/acceptance/cap23-23.4-notes.md` (Kafka + i17 PASS; **456b**
      Closed)
- Cap 22 Saved Pool persistence: `lib/domain/source/saved_pool_repository.dart`
      + Drift `lib/data/local/` (work `d62e962`); Save UX 22.3
      (`4db65ec`); 22.4 chrome + ADR-047 polish (`0ca1198`, `0b68e01`);
      22.5 Misc polish (`7350f67`, `fd662c1`) + ADR-048 (`fbf2e82`);
      22.6 device acceptance notes
      `docs/acceptance/cap22-22.6-notes.md`
- Acceptance notes (Cap 5.5): docs/acceptance/cap5-5.5-notes.md
- Acceptance notes (Cap 6.5): docs/acceptance/cap6-6.5-notes.md
- Acceptance notes (Cap 11.2 list / Limited omit):
  docs/acceptance/cap11-11.2-notes.md
- Acceptance notes (Cap 11.3 album resolve / Limited unauthorized):
  docs/acceptance/cap11-11.3-notes.md
- Acceptance notes (Cap 11.6 Photos+All coalesce / 13+17):
  docs/acceptance/cap11-11.6-notes.md
- Acceptance notes (Cap 7.7 Release forensic + Errata):
  docs/acceptance/cap7-7.7-notes.md
- Acceptance notes (Cap 7.7a Profile retest):
  docs/acceptance/cap7-7.7a-profile-retest-notes.md
- ADR-001 re-eval outline (7.7a PASS; remaining hang-triggered
  SwiftUI fail path withdrawn by ADR-030):
  docs/acceptance/cap7-7.7-adr001-reevaluation-outline.md
- Acceptance notes (Cap 7.7b, N/A):
  docs/acceptance/cap7-7.7b-hang-diagnosis-notes.md
- Acceptance notes (Cap 8.4 POC-10 device confirm):
  docs/acceptance/cap8-8.4-poc10-notes.md
- Acceptance notes (Cap 8.8 Overlay / size / hitch / A1 audio):
  docs/acceptance/cap8-8.8-notes.md
- Cap 9.6 Playback Style observation matrix (filled in 9.7):
  docs/acceptance/cap9-9.6-playback-style-matrix.md
- Acceptance notes (Cap 9.7 POC-08 device):
  docs/acceptance/cap9-9.7-poc08-notes.md
- Acceptance notes (Cap 13.6 Profile V-hard FAIL — do not rewrite the
  FAIL tables): docs/acceptance/cap13-13.6-notes.md
- Acceptance notes (Cap 13.6b hang campaign stopped as inexecutable;
  Limited All empty draft 3 + resolution; 2026-08-18 disk-confounder
  append — do not rewrite A–D tables):
  docs/acceptance/cap13-13.6b-hang-diagnosis-notes.md
- Acceptance notes (Cap 13.6 Profile retest after Cap 14 — FAIL;
  All independent of disk-full; second foundation defect):
  docs/acceptance/cap13-13.6-retest-notes.md
- Acceptance notes (Cap 16.5 storage + hitch; Instruments numbers
  are not a 13.6 Pass — ADR-030):
  docs/acceptance/cap16-16.5-notes.md
- Acceptance notes (Cap 15.5 closed `2f24593`; Round 4 PASS;
  261/354 historical only; S2≈334 pre-existing iCloud overlap):
  docs/acceptance/cap15-15.5-notes.md
- Acceptance notes (Cap 15.6 closed `9eef9db`; Protocol B Full/Limited
  preview-tier model; debt **400** open):
  docs/acceptance/cap15-15.6-notes.md
- Acceptance notes (Cap 17.1 diagnosis closed; Tracks A/B/C; probes
  never committed):
  docs/acceptance/cap17-17.1-notes.md
- Acceptance notes (Cap 17.6 device + Live handoff residual):
  docs/acceptance/cap17-17.6-notes.md
- Acceptance notes (Cap 18.4 tap / affordance / lifecycle auto-resume):
  docs/acceptance/cap18-18.4-notes.md
- Acceptance notes (Cap 18.5 scrubber + preview bubble + release seek):
  docs/acceptance/cap18-18.5-notes.md
- Acceptance notes (Cap 18.6 device acceptance + residuals):
  docs/acceptance/cap18-18.6-notes.md
- Media chrome layout (Reset / LIVE / actions / MVP 3-row meta;
  shared browse chrome, not Cap 20–only; not ADR-043):
  docs/reference/media-chrome-layout-notes.md — work `81904e1`
- Cap 21.4b smart-album Build catalog boundary (live whitelist /
  exclude maintenance):
  docs/reference/cap21-smart-album-boundary.md — work `67cb08b`
- PhotoKit implicit multi-surface / Host notes (not ADR):
  docs/reference/ios-photokit-implicit-behavior-notes.md — debt **471**
- Acceptance notes (Cap 20.6 device acceptance — D5=4× / B.1 / Q2-A;
  debt **451** Closed / **452** Open):
  docs/acceptance/cap20-20.6-notes.md — work `bc15517`
- 13.6 measurement-gate re-evaluation protocol (campaign done;
  FAIL tables frozen; closer is ADR-030 §5):
  docs/acceptance/cap13-13.6-measurement-reeval-protocol.md
- Competitor products in committed docs: `Photo-App-A` / `Video-App-B`
  only; local map `docs/private/competitor-codenames.md` (gitignored)
- POC spike code & evidence: branch `spike/poc` — read-only archive;
  never merge; never delete
- (grows as code lands)

## Do NOT touch (unless explicitly opening a new phase)
- docs/WakeTok(App)_project_kickoff.md — owner's private spec, READ-ONLY for AI tools
- Main Browse shell IndexedStack Theme wrap — do not restore a
  destination-conditional Theme around the stack (disposes
  VerticalMediaFeed / PageController; 14.4c `9eecc7e`)
- (grows as fragile areas appear)

## Known debt / intentionally deferred
| ID | Status | Capability | Logged | Item | Reason | Picks it up | Related ADR |
|---|---|---|---|---|---|---|---|
| 397 | Open | Main Browse Screen |  | Release build Severe Hang / hitch on production feed (Kafka) | Accidental Release campaign V-hard FAIL (`cap7-7.7-notes.md`); **7.7a Profile PASS**. Evidence strength: **All** surface clean **3/3 FAIL (Release) → 3/3 PASS (Profile)** is a strong signal the mode divergence is real (not a one-off flip); **Videos** was already 2/3 PASS on Release (intermittent), so weaker as a divergence signal. Track for shipping; do not deep-dive cause here | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-001 / ADR-014 |
| 401 | Open | Media Info Overlay |  | Location Label (reverse geocode) not implemented | Owner Cap 8 Q1=B: Overlay row 4 hidden when empty this Cap (kickoff ADR-X best-effort deferral; no geocode). Current-Item-only geocode hard rule unchanged when a later Cap picks this up | Later Cap (or reopen when Owner schedules) | kickoff ADR-X |
| 404 | Accepted (permanent) | Media Info Overlay |  | Same-asset playhead shared across built-in sources (All ↔ Videos) — **Accepted behaviour** | First observed Cap 8.8 (`cap8-8.8-notes.md`): `PlaybackApiHost` keys the app-scoped player by `assetIdentifier` (ADR-006), so the same Photos id under All vs Videos reuses position / ended-on-last-frame. **Accepted (ADR-023 D6 / Cap 13.5)** — intentional Host keying, **not** a bug fix and **not** cross-tab Continuity (D8: tab = new Session; feed index still resets). No `PlaybackApiHost` change. **Row kept** (not deleted like resolved bugs) as a permanent record of accepted behaviour to prevent re-litigation when the shared playhead is noticed again. | Unassigned | ADR-006 / ADR-014 / ADR-023; `docs/acceptance/cap8-8.8-notes.md` |
| 405 | Open | Media Info Overlay |  | File-size disclaimer copy (kickoff ADR-W §5) unset | Size is logical resource bytes — not device disk / iCloud quota / optimized-local / immediate free-on-delete. iCloud-only blank size **before** local data exists is ADR-015/018 (never download solely for size; Photos Info is not a public-SDK ground truth). Same-page refresh after Layer 2 landed `43c984a`. Not an eng Decision gap; needs user-visible copy landing | Settings and localisation completion (or Cap 8.5/8.6 if a short on-media note is added) | kickoff ADR-W |
| 406 | Monitoring | Main Browse Screen |  | First cold start: All current item fails until Retry because the Cellular Data system prompt appears after Layer 2 has already been issued | China-SKU app-level first-network prompt (mainland China App Store vs NZ: Photo-App-A same split). Dart `HttpClient` pre-feed probe does **not** trigger it. Lifecycle auto-retry landed `8a827e4`. Kafka first-launch retest still pending. | Owner device confirm (Kafka first-launch retest) | ADR-025 |
| 407 | Open | Main Browse Screen |  | Optional native `URLSession` (CFNetwork) pre-feed to show the Cellular Data prompt on the loading screen instead of after first Layer 2 fail | Dart sockets do not trip the China-SKU prompt. Not required for everyday feed swipe once B auto-retries (`8a827e4`). Photo-App-A on China SKU still shows the prompt in the feed. | Later Cap / optional | ADR-025 |
| 408 | Closed | Main Browse Screen |  | **Leave-current did not stop PhotoKit iCloud video materialization; Browse continuously fills device storage; cannot reclaim from the system Photos library** | User-visible, independent of hitch. Optimize iPhone Storage **on** still loses: download rate beats system reclaim. 2026-08-18 replication: Videos V1 ~75 s, wait only first+last iCloud videos to play, flick the rest on cover → disk **200.2 → 207.38 GB (~+7 GB)**. Two watched videos ≠ +7 GB. WakeTok JPEG temps are bounded; growth is Photos library cache. **16.2** leave-cancel (`255656d`); **16.3** one networked `load` (`22ece57`; `requestPlayableVideo` is duration-only); **16.4** dwell 500 ms (`26294f5`). **16.5** (`docs/acceptance/cap16-16.5-notes.md`): no-Instruments Videos **+0.18 GB** / All **+0.02 GB** PASS vs that leak. Instruments GB is **System Data / purgeable**, not Settings Photos (idle attach ~+1.8 GB System Data; Photos 10.17→10.16 across reboot). Do **not** rewrite the 13.6 +7.18 GB as 100% Instruments (product cancel was also missing then). A late `cancel` after leave may still let A briefly enter prepare (not proven zero disk). App has **no public API** to delete Photos-library downloads (kickoff forbids an app-owned persistent media cache). Reclaim = iOS idle / reboot. **Second 13.6 gate-foundation defect** (Cap 14 was the first) — **product leak path paid by Cap 16**; 13.6 closed under ADR-030 §5 (everyday availability), not another 25 ms/s retest. | Closed by Cap 16 (ADR-029); 13.6 closed ADR-030 | ADR-025 D4 / ADR-029 / ADR-006 |
| 409 | Closed | Main Browse Screen |  | Tab leave does not cancel `PlaybackApiHost.prepareActive` iCloud video download | **Closed by 16.2** (`255656d`): `cancelInFlightPrepare` on leave current / dispose / leave Browse, including same-id. Dwell landed in 16.4 (`26294f5`). 16.5 measured no-Instruments storage PASS; remaining Instruments GB is System Data (notes), not missing leave-cancel. | Closed by Cap 16.2 (ADR-029) | ADR-025 D4 / ADR-029 / ADR-006 |
| 410 | Accepted (permanent) | Main Browse Screen |  | Profile/Debug may prompt Local Network (“Looking for devices on the local network”) before Photos | Flutter observatory / mDNS, not product PhotoKit. Release expected not to show it. | Unassigned | — |
| 411 | Open | POC-03 |  | WeChat/VoIP interrupt: no auto-resume on lock screen or iOS home without opening app | Q1=B: 3.3 PASS when shouldResume + poll/foreground resumes; suspended lock/home path deferred | Production Background Audio | ADR-002 |
| 412 | Open | POC-03 |  | Real physical-clip integration after POC-09 (≥3 exported clips locked queue) | Bundle WAV proved service shape only; confirm Photos-backed segments, order, Now Playing, no Dart per transition | Production Background Audio (prerequisite: Generated Clip Source available after Physical Clip Export Core + Photos import) | ADR-002 |
| 413 | Open | POC-03 |  | iCloud Asset download interrupt during background audio | P2=A: out of POC-03 scope | Production Background Audio | ADR-002 |
| 414 | Open | POC-09 |  | Slow-motion frame-rate / audio-pitch beyond duration gate | 9.3 passed duration only | Physical Clip Export Core | ADR-004 |
| 415 | Open | POC-09 |  | Multi-audio-track selection UX | 9.4 default track only | POC-07 | ADR-004 |
| 416 | Open | App Foundation |  | iOS 18 simulator smoke (no 18.x runtime installed) | Floor is 18.0 (ADR-007); day-to-day verify on 26.x only | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-007 |
| 417 | Open | App Foundation |  | Localization Inventory auto-generation/report tooling (kickoff ADR-U §7–8 summary artifact) | Hardcoded-copy scan + ARB key parity closed by ADR-012; Inventory report generator still deferred. **Also (logged Cap 21.5 follow-up):** `app_zh_Hans.arb` debug / probe strings under `source*` / `playbackProbe*` / `cap19*Probe*` still carry Latin product/API tokens (Photos, Videos, Pool, Limited, unauthorized, estimatedCount, PHAsset, bootstrap, L-BOOT, …). Visible only under `kDebugMode` / library_smoke — not Release product risk; systematic ZH cleanup deferred to Settings and localisation completion (same Inventory lane). Cap 21.5 follow-up only aligned `playbackProbeLoadImage` / `playbackProbeLoadVideo` with `libraryRowPhotos` / `libraryRowVideos` wording. | Settings and localisation completion | — (kickoff ADR-U) / ADR-012 |
| 418 | Open | App Foundation |  | App icon asset set | Owner parallel track; required before first TestFlight build upload | TestFlight internal testing | — |
| 419 | Open | Portfolio |  | Repository visibility: Private → Public (eligibility: first demoable vertical slice — Main Browse feed scrolls real Photos library content on device) | Cap 7 closed — eligibility met. Before Private→Public, owner must complete the pre-public privacy/sensitive-history scan checklist (local release-handoff); Cursor reminds only and must not run the scan. | Owner pre-public scan (any time after Cap 7) | — |
| 420 | Open | iOS Photos permission |  | NSPhotoLibraryUsageDescription is PLACEHOLDER copy | Final permission wording is owner-only (release-handoff) | TestFlight internal testing | — |
| 421 | Open | iOS Photos permission |  | Limited Access product chrome unmounted from Main Browse (`01a7611`) | Banner sat above IndexedStack (all four tabs) and the shell Column had no SafeArea (notch clipped it). **Removed the product mount, not the feature.** Final form TBD at Settings: persistent in-Settings entry + whether to remind on each launch. Until then, **Release/Profile users have no in-app button or entry** to present the Limited picker (`presentLimitedLibraryPicker`) or Open Settings after a Limited grant — changing access is only via iOS Settings, unrelated to WakeTok UI. Kickoff ADR-K §3 (explicit prompt + system path to Full) is unmet in this window; no compensatory prompt. Future designs must not block or interfere with system gestures (app switcher / Home). Debug `library_smoke` may still show the widget (`kDebugMode` only). | Settings and localisation completion | kickoff ADR-K |
| 422 | Open | iOS Photos permission |  | List-time availability via undocumented PHAssetResource KVC `locallyAvailable` | No public isLocallyAvailable on PHAsset/PHAssetResource in the iOS SDK. Host uses KVC in `mapAvailability`. **Cap 15.12 / 15.15 (ADR-033):** become-current may call `getAssetAvailabilities` (on-demand; resolve returns empty availabilities). Same KVC helper for probed ids only. **Further expansion** of KVC beyond this gate still needs explicit owner re-board. | Future Cap if expanding | ADR-033 |
| 423 | Open | Cap 6 / library_smoke |  | Library Totals Shell error row uses raw exception string (`'${asyncTotals.error}'`), not ARB | Predates ADR-012 smoke hardening; Cap 6.4 left untouched on purpose | Settings and localisation completion | ADR-012 |
| 424 | Open | Main Browse Screen |  | No architecture scan for hardcoded `TextStyle(` in `lib/features/**` (typography tokens exist; `Color(0x` still scanned) | Cap 7.2 locked type roles without a TextStyle literal guard; easy to bypass tokens while 7.4–7.7 chrome lands | Settings and localisation completion | ADR-009 / ADR-014 |
| 393 | Closed | Main Browse Screen |  | Video page swipe may flash the previous video — **with audio** (severity residual) | **Closed by 15.11** (`9d546f2` / ADR-032): `PvTransitionGuard` (entering-side cover + transition mute); unwrap on Host **`onPlaybackSurfaceReadyForDisplay`** (`AVPlayerLayer.isReadyForDisplay`), **not** attach-ack (attach observed `layerReady=false` in diagnosis — evidence in `cap15-15.11-notes.md`, not git). 15.11b: poster-hold + settle-on-target (cover release ≠ audio release) + stale feed-index re-arm fix. Kafka + i17 Profile PASS — `cap15-15.11-notes.md`. Peek black gap + settle wrong A/V both closed under debt **393**. ADR-006 1+1 pool unchanged. | Closed by Cap 15.11 | ADR-006 / ADR-032 / ADR-031 |
| 425 | Closed | Main Browse Screen |  | Local / L2-ready items still blur-first on revisit (Session) | **Closed by 15.10** (`62a5a2b`): Session L2-ready token skips Layer 1 on revisit; still sharp / video poster-until-play. Kafka PASS (`cap15-15.10-notes.md`). **v1 revisit only** — no list-time KVC on become-current (STATE `locallyAvailable` row unchanged). | Closed by Cap 15.10 | ADR-025 |
| 426 | Closed | Main Browse Screen |  | Session L2-ready revisit: residual corner spinner flash (&lt;T) after Host temp eviction | **Closed by Cap 17.3** (`65ea272` / ADR-034): path-class wait chrome (a4 T=150 ms) + promoted G (still a2 &lt;T) / B (a4 miss bypass) / F1(+D) (Live prepare &lt;T). Closes the **&lt;T residual corner flash** only — that flash is not remaining unfinished Cap 17.3 work. **≥T still/a4 chrome** is the intentional empty-window guard (see open row below). Device skew (Kafka clearer / i17 faint) unchanged. | Closed by Cap 17.3 | ADR-025 / ADR-029 / ADR-034; Cap 15.10/15.13; Cap 16 temps |
| 427 | Accepted (phase) | Main Browse Screen |  | Session L2-ready revisit: ≥T wait chrome / zero-spinner product choice (Host temp vs disk-resident L2-ready covers) | **MVP-acceptable product choice (not Cap 17 unfinished work).** After Cap 17.3, ≥T still/a4 wait chrome can still appear when Host temp eviction drops a cover (empty-window guard under ADR-034). Root tension remains Cap 16 tight temps vs disk-resident L2-ready covers. Solution paths (raise Preview/Display temp budgets; keep cover outside Host temp) are **unevaluated and unscheduled**; whether to optimize is a later product judgment. Closing the &lt;T flash row in Cap 17.3 does **not** decide this product limb closed or permanently declined. **Suspected mechanism cross-ref (not confirmed):** debt **441** (Session video revisit landing one-frame black) may share a4 / Host-temp cover-eviction infrastructure; **441** is a distinct symptom (≈1 frame at settle handoff, not ≥T wait-chrome policy). Continue observation on both rows. | Unassigned | ADR-025 / ADR-029 / ADR-034; Cap 16 temps; debt **441** |
| 428 | Open | Main Browse Screen |  | Cap 17.5 F1 — reduce wasted Layer-2 prepare (beyond Cap 16 leave-cancel / dwell) | Cap 17.5 scoped F1 as optional if tee showed illegal / wasted prepares. 17.1 Track B + Cap 17.5 Kafka dwell=300 dual-column session show cancels are overwhelmingly Cap 16–legitimate leave-cancel, not a bug class. F1 code may be **zero**; do not invent a phase to force a diff. Same recording pattern as the ≥T / temp-budget Unassigned row. | Unassigned | ADR-029 / ADR-034 / ADR-035; `cap17-17.5-notes.md` |
| 394 | Closed | Main Browse Screen |  | Local Layer 2 completing during a swipe exposes a Layer 1→2 handoff gap (stills and video); consecutive iCloud items stay on Layer 1 and do not flash | Trigger: on-device Layer 2 returns inside the scroll animation; iCloud Layer 2 is slow so the page keeps the preheated Layer 1. **Stills:** **Closed by 15.5** (`2f24593`) for local still→still gapless. **Video peek-black (leave-side poster loss):** **Closed by 15.7** (`bb3d5e2`) when L1 poster exists. **Revisit blur-first when L2-ready:** **Closed by 15.10** (`62a5a2b`). **Entering-peek black gap + settle wrong A/V (debt 393):** **Closed by 15.11** (`9d546f2` / ADR-032). Debt **400** unchanged. | Closed by Cap 15.11 (debt 393 limb) | ADR-006 / ADR-025 / ADR-032 |
| 395 | Closed | Main Browse Screen |  | Navigation return to a video is not yet uniformly restart-from-0 | **Closed by Cap 18.7 — intentional product design (ADR-040).** Cap 18.3 work `84ef30c`: `PlaybackCoordinator` + Host seek-zero-before-play on every trusted new navigation activation (no pause / playing branch). Pooled-player fast A→B→A path device-verified **395-P** / **395-PP** on Kafka + i17 Green (`cap18-18.6-notes.md`; docs `688ec43`). Unit: U-18.3-P1 Host policy. Foreground resume / surface reattach are not navigation activations (ADR-026 D3 mid-play preserve unchanged). | Closed by Cap 18.7 | ADR-006 / ADR-026 / ADR-040 |
| 396 | Closed | Main Browse Screen |  | Becoming current can bump display generation twice (`_activateCurrentItem` in the feed-index listen + `_beginCurrentItemActivation` in build), so Layer 2 may fire twice | **Closed by 15.4** (`d532064` / ADR-031 D8): join in-flight Layer 1 on neighbour→current promote; no second `requestPreview` on the same id (`preview_supersede`). Kafka M1+2: zero supersede on five miss `page_changed`; one `layer2_load_start` each. W-15.4 widget tests. | Closed by Cap 15.4 (ADR-031) | ADR-025 / ADR-010 / ADR-031 |
| 429 | Closed | Main Browse Screen |  | Browse→Settings→Browse while a video is playing flashes one poster frame | **Dissolved by 14.4e** (`5658cf2`): leave Browse ends the Session and returns at queue head, so the 14.4c keep-alive mid-queue resume path is gone. Remaining wait chrome after leave is the Layer 1 cold-start row below, not this poster flash. | Closed by Cap 14.4e (ADR-027) | ADR-006 / ADR-025 / ADR-027 |
| 398 | Closed | Main Browse Screen |  | Leave Browse (Settings/Clips/Auto) then return: queue-head page may show black + gold spinner with no Layer 1 still/poster | **Closed by 15.3** (`962b6d1` / ADR-031 Q2): same `_loading` miss chrome as debt **399**, now `_FeedCornerChrome` not centered. Black wait until Layer 1 still exists (ADR-025); 14.4e remount at index 0 can still land on a miss head (Shuffle). Kafka 2026-08-20 device: miss = corner spinner; library loading still centered. | Closed by Cap 15.3 (ADR-031) | ADR-025 / ADR-027 / ADR-031 |
| 399 | Closed | Main Browse Screen |  | Layer 1 miss (`_loading`) still uses a **centered** brand-gold spinner (`mainBrowseFeedPageLoading`); 14.6b only moved Layer 2 / Live-prepare chrome to bottom-right when a still/poster already exists | **Closed by 15.3** (`962b6d1` / ADR-031 Q2): miss page is `feedBackground` + `_FeedCornerChrome`; no delay-before-show; new ARB `mainBrowseFeedLayer1Loading`. Library resolve `mainBrowseFeedLoading` stays centered. Kafka device PASS. Debt **436** not in this close. | Closed by Cap 15.3 (ADR-031) | ADR-025 / ADR-019 / ADR-031 |
| 430 | Closed | Main Browse Screen |  | **Center Layer2Waiting (`mainBrowseFeedLayer2Waiting` / “Loading…”) necessity unclear — separate from Layer1Loading and corner reassure** | **Closed by 17.9** (`f1ffadf` / ADR-039): owner option **A** — deleted runtime center copy and ARB key; coverless L2 keeps corner spinner + `mainBrowseFeedLayer3Loading` semantics; corner reassure policy unchanged (`shouldShowLayer2CornerReassure`; `W-17.5b-covered` / coverless ≥3s tests updated). Fixed coverless re-enter `_loading` before L2 in-flight arm (hold/startLoad race). Guard option B (L1-miss→L2 center copy) **not** wired. | Closed by Cap 17.9 (ADR-039) | ADR-034 / ADR-036 |
| 431 | Closed | Main Browse Screen |  | All / Photos / Videos quick tab switch flashes one frame center Layer1Loading (`mainBrowseFeedLayer1Loading`) | **Closed by 17.9** (`f1ffadf` / ADR-039): source-switch-only 150 ms delay hides **visible** center copy on first current page after tab change; corner spinner + VoiceOver `mainBrowseFeedLayer1Loading` semantics stay immediate. Vertical swipe / cold start unchanged. Kafka Profile owner acceptance PASS (4-step). | Closed by Cap 17.9 (ADR-039) | ADR-039 |
| 432 | Open | Main Browse Screen |  | All / Photos / Videos quick tab switch may flash one frame feed-shell `mainBrowseFeedLoading` | **Optional polish (retained).** Tab change starts a new Consumption Session (`browseSessionProvider` reload); cached snapshots typically ≤1–2 frames of shell loading. Semantically distinct from page Layer1 copy (17.9 closed rows above). Owner rejected blank-hold polish (empty feed color reads as bug/stutter). Alternatives (`skipLoadingOnReload`, cache-hit synchronous session swap, delayed whole-screen library chrome) unevaluated. | Unassigned | ADR-023 D8 / ADR-039 |
| 400 | Accepted (permanent) | Main Browse Screen |  | iCloud / optimized-storage **video**: no Layer 1 poster — full-page black + spinner until Layer 2 plays; ±1 peek often stays black | **15.6 partial (`9eef9db`):** Host box **512×512** (was 1080). Raises **Limited** local-hit odds when a derivative near the box exists (Session B: 13×512-edge ok). **Does not** explain Full never-black: Protocol B same 16 ids under Full → 16/16 ok all **~120**, 0 miss — **inferred** Full opportunistic fallback to a fixed small thumb tier; Limited searches by `targetSize` without that fallback (`cap15-15.6-notes.md`). Limited residual miss (3/16 in B) can still lack any deliverable local image under Limited while Full has ~120 — PhotoKit authorization behavior under ADR-025 local-only; Host cannot invent pixels. Unvalidated trial: `deliveryMode = .fastFormat`. Product miss UI = separate discussion. Original Limited 6-video set (2026-08-18) still applies as early evidence. **Cap 17.4 (`c3aa2dc`):** coverless wait **visibility** improved (centered copy + corner spinner); **residual black accepted** (ADR-034 Decision 3). **Cap 17.8 close-out:** row remains on the table as accepted residual (permanent) — Host cannot invent pixels; no further fix or upgrade scheduled; not Cap 17 unfinished work. | Unassigned | ADR-025 / ADR-006 / ADR-031 / ADR-034 |
| 433 | Closed | Media Info Overlay |  | Capture time shown in Overlay (exact datetime + relative “X years Y months ago”) does not match iOS Photos for the same asset | **Closed by Cap 17.7** (`d9db8c7` / ADR-038): product goal changed from minute-level Photos wall-clock match to **honest approximate** presentation — row 2 `~ Y-M-D` and row 1 coarse short bands from `creationDate` local calendar only; ±1 calendar day vs Photos at import/timezone edges **accepted** (not a bug to chase in Overlay). Rows share honesty stance but are **not** guaranteed numerically consistent with each other or with Photos for cross-check. Minute-level Host/EXIF attempt reverted (`2c0a090`); archive `docs/private/cap17-7-minute-wall-clock-archive/`. Device smoke PASS iPhone13pro Kafka. Cap 19 long-press info may revisit with disclaimer. | Closed by Cap 17.7 | ADR-038; Cap 8 Overlay / ADR-014 family |
| 434 | Closed | Main Browse Screen |  | Lock then unlock on Manual Browse while a video is current: same index/frame, paused, no tap-to-play — swipe is the only escape | ADR-006 Cap 7.3: background detach + pause; foreground re-adopts the layer. **Closed by Cap 18.4** (`0df9ceb` / ADR-040 Decision 4 supplement + Decision 12): lifecycle leave is mechanical pause only (preserves intent); foreground resume auto-plays when intent preserved (respect mute). User tap-pause before interrupt stays paused with center affordance + tap resume. Supersedes the Cap 18.1 draft that required foreground stay paused until tap. No lock-aware special-case code. | Closed by Cap 18.4 (ADR-040) | ADR-006 / ADR-040 |
| 403a | Open | Main Browse Screen |  | Asset-source iCloud load feels much slower than Photo-App-A / iOS Photos | **Suspect clues (verify later — not closed root causes; not Cap 15.11 scope).** Owner subjective + Cap 15.11 **session** log on Kafka (`/tmp/waketok_1511b_stale_idx.log`, 2026-08-23): many items stayed blurry / non-playing while Photo-App-A in the same window eventually loaded; log skew `load-finished err=ok` ≈168 vs `operationCancelled` ≈417, **0** `iCloudDownloadFailed`. Suspect aggressive leave/remount/supersede cancel + single-flight prepare vs competitor / Photos keep-or-parallel download — **deep-dive WakeTok iCloud network + cancel policy** when scheduled; no attribution without further evidence. Debt **428** for wasted prepare is **Unassigned** (separate Known debt row; evidence leans legitimate leave-cancel). | Unassigned | ADR-025 / ADR-029 / ADR-034 / ADR-035 / ADR-036 |
| 403b-progress | Accepted (phase) | Main Browse Screen |  | Long iCloud Layer 2 has no progress/stall productization | Item-level `_FeedCornerChrome` spinner gives **no progress signal** during long iCloud Layer 2 (throughput, bytes, ETA). Cap **17.5b** delivered corner reassure + Retry definition (work `527baeb`); progress/stall productization was a direction only and is **not** planned for MVP. 17.5b Retry/reassure limb closed. | Unassigned | ADR-025 / ADR-029 / ADR-034 / ADR-035 / ADR-036 |
| 403b-wallclock | Accepted (phase) | Main Browse Screen |  | No blind wall-clock stall→fail timeout | Blind wall-clock timeout intentionally not adopted. Evaluated and rejected as a specific scheme; a smarter stall policy may be reconsidered later. | Unassigned | ADR-025 / ADR-029 / ADR-034 / ADR-035 / ADR-036 |
| 435 | Accepted (permanent) | Main Browse Screen |  | Layer 2 fail reason mapping collapses PhotoKit detail to three user-facing buckets (`network` / `download` / `generic`) | Cap 17.5b review confirmed: user-facing granularity **intentionally** stays at three categories (no action-path benefit from finer copy). Pre-fix Host path read `PHImageCancelledKey` + transferBegan only and **discarded** `PHImageErrorKey` / `PHImageResultIsInCloudKey` without logging. **Supplemented during 17.5b:** Host `logLayer2PhotoKitFail` in `PlaybackApiHost` (video `requestAVAsset`) and `PhotoLibraryService.handleDisplayResult` (display L2) prints cancelled / transferBegan / inCloud / phError / mapped Pigeon code to Console (Profile+Debug). Dart `feedFailureReasonFromPlatformCode` only ever sees the already-collapsed wire code. No further Cap assigned. | Unassigned | ADR-025 / ADR-036; `cap17-17.5b-notes.md` |
| 436 | Open | Live Photo (Cap 9.7) |  | Offline/weak-net iCloud Live: preparing spinner may be zero-duration (fail too fast) | POC-08 #5/#6 PASS with static fallback; owner wants later brief visible spin-then-fail so users see “needs network” (not progress-copy / Waiting for Media) | Live chrome / iCloud feedback polish | ADR-019; historical acceptance label: UX-1 |
| 437 | Closed | Live Photo (Cap 9.7) |  | LIVE badge + preparing spinner top-left overlaps status-bar time | **Closed by 14.6b** (`77afb23`). Badge + item Layer 2 / Live-prepare spinner share `_FeedCornerChrome` at bottom-right; Overlay `trailingInset` 123. Library resolve loading stays centered. Q7 play-once hide/show unchanged. Kafka Profile PASS. Debt **436** untouched. | Closed by 14.6b | ADR-019; historical acceptance label: UX-2 |
| 438 | Closed | Cap 13 (13.8) |  | **First launch right after granting Limited access shows an empty All tab and does not self-heal** | **Closed by 14.6** (`d32a309` + `b9c2d68`). Bounded re-resolve on successful empty remains; Kafka showed the empty All was started by resume `currentStatus()=.limited` **before** `requestAuthorization` completed. Skip that invalidate while `requestAccess` is in flight, then `restartSession` when the grant completes. Kafka Profile: loading then selected media, not empty copy. ADR-024 empty-not-cached remains as tab-switch backup. | Closed by 14.6 (ADR-025 D8 + grant-complete restart) | ADR-025 / ADR-024 / ADR-014 / ADR-021 |
| 439 | Open | Live Photo | Cap 18.1 | Live explicit replay control | Owning Cap was unassigned; ADR-019 Decision 8 narrow supplement pending that Cap. Persistent anchor for ADR-040 Decision 17 and Phase 18.1 `owning Cap TBD`. Cap 26 / ADR-052 Proposed supersedes D17 no-long-press with App long-press as sole replay affordance (explicit button never shipped). Do not delete until Cap 26 lands implementation and closes this row. | Cap 26 (ADR-052) | ADR-019 / ADR-040 / ADR-052 |
| 440 | Closed | Main Browse Screen | Cap 18.3 | Seven existing spinner / preparing-chrome widget tests are red on `main` | Verified against clean baseline `9e4a04e` before Cap 18.3: W-16.4e, W-L2, L-S6, W-14.6b-L1/L4, W-15.3, and W-14.4 all fail identically before and after the 18.3 worktree changes. Failures concern missing Layer3 / Live-preparing chrome within test timing windows, except W-15.3's LIVE-badge strut height (`16.0`, expected `>16.0`). They are not Cap 18.3 playback-intent regressions. W-16.4e probe (still a2 + L1 + dwell; real arm+dwell, not debugForce; elapsed synced to FakeAsync): asserts spinner at t≈0, which conflicts with ADR-034 G (suppress &lt;150 ms); at t≥150 ms spinner paints — product chrome healthy. That assert's timepoint is obsolete post-17.3 (stale assertion, not product regression). Does not re-prove the other six reds in this row. Widget tests reconciled to ADR-034 G/F1 clock semantics (elapsed sync + F1 timer pump); W-16.4e asserts ≥T dwell chrome; strut-height assertions removed post–Cap 17.5b layout. Seven tests green on `main` as of work commit `6682582`. | Closed before Cap 18.6 (test/chrome reconciliation) | ADR-032 / ADR-034 / ADR-039 |
| 441 | Monitoring | Main Browse Screen | Cap 18.4 | Session **video** revisit: landing settle may show one-frame full black between blur Layer 1 poster and Layer 2 play | **Known phenomenon family** — same lineage as `cap15-15.10-notes.md` §D (peek blur poster → transition empty window → L2 play). Cap 18.4 device (Kafka Profile, Optimize ON): iCloud video first-visit L2 complete → Session revisit; peek blur L1 OK; **landing settle occasional one-frame full black** then L2 plays directly. Not debt **400** (blur poster present). **15.11** closed local→local matrix only — this trigger outside that matrix. **Suspected mechanism cross-ref (not confirmed):** debt **427** Host-temp cover eviction on a4 video L2-ready revisit may worsen landing flash; **441** can also reproduce as a one-frame settle handoff without ≥T empty window or corner spinner. **Continue observation** — no Cap scheduled. | Unassigned | ADR-006 / ADR-025 / ADR-032 / ADR-034; `cap15-15.10-notes.md` §D; debt **427** |
| 442 | Accepted (phase) | Main Browse Screen | Cap 18.5 | Cap 18.5 scrub preview bubble may show async JPEG placeholder gaps (fast-drag strip, first-scrub cold start, in-flight bucket transition) | AVAssetImageGenerator + Host single-flight coalesce + 1.0s preview bucket + ADR-040 Decision 13 §2.1 borrow (max one bucket step, 350 ms wall-clock) do **not** guarantee a continuous real-frame strip at competitor parity. **Three distinct triggers, same architecture:** (1) **fast horizontal drag** — borrow cannot cover every bucket crossing; (2) **first scrub engagement** — no prior successful JPEG to borrow, bubble waits on first Host decode; (3) **mid-drag in-flight / bucket switch** — `#000000` placeholder (or bounded borrow) until async JPEG arrives; **trigger (3) is not fast-drag-specific** — every bucket switch clears the current frame and waits on async Host return; at normal scrub speed that window is often below perception (BENCH typical **14–150 ms**) but is not guaranteed to stay sub-threshold (BENCH max **388 ms** on sparse-GOP zero-tolerance decode). **Accepted for Cap 18.5 ship** (`b2ceabd` eliminated sparse-GOP drift-reject **permanent** black on hold; placeholder-then-JPEG remains by design per supplement item 8). Cap 18.6 soak: owner-acceptable, not Photos parity. Further optional tuning: scrub-touch prefetch, `maximumSize`; widening borrow is **not** a candidate (violates §2.1). | Unassigned | ADR-040 Decision 13; `docs/acceptance/cap18-18.5-notes.md`; `docs/acceptance/cap18-18.6-notes.md` |
| 443 | Accepted (phase) | Main Browse Screen | Cap 18.5 | Cap 18.5 progress scrub is **whole-second** granular (not iPhone Photos / slow-mo 0.01s edit resolution) | **Intentional Cap 18.5 scope.** Linear band maps to ratio; label + release seek use `round(ratio × duration)` to the nearest second. Sub-second scrub requires quantizer, Host seek tolerance/timeouts, and preview bucket changes — documented upgrade path in acceptance notes. Not a defect vs Photos frame-accurate trimming. | Unassigned | ADR-040; `docs/acceptance/cap18-18.5-notes.md` |
| 444 | Closed | Main Browse Screen | Cap 18.6 | External Photos delete while Consumption Session still lists the asset: misleading Layer 2 fail copy; Retry ineffective | **Verified (owner device, Kafka Profile `1ed7f0b`):** delete a still in iOS Photos without quitting WakeTok → first return to the same feed item still shows the image; swipe away and back → Layer 2 fail with `Could not load. Allow wireless data, then retry.` + Retry; Overlay metadata rows still visible — **not** a connectivity defect. **Verified (code):** missing `PHAsset` → Host `assetUnavailable`; Dart maps `assetUnavailable` → `FeedFailureReason.network` → that wireless-data string (debt **435** three-bucket collapse); no production `PHPhotoLibraryChangeObserver` / session queue invalidation on external library mutation. **Inferred (architecture — not log-verified this session):** first revisit may use cached L2 (`DisplayTempFileStore` / in-page display state); second remount likely hits fresh `requestDisplayAsset` on a deleted id. **Not Cap 18.6 scope.** **Closed by Cap 21.6** (`a448989`): feed-only remap to `FeedFailureReason.assetUnavailable` + `mainBrowseFeedUnavailable`; hide Retry; hide Overlay while loading/unavailable; dim Cap 19 entry when unavailable. Residuals **456** / **457**. | Closed by Cap 21.6 (`a448989`) | ADR-044 D3; ADR-022 / ADR-025; debt **435** |
| 445 | Accepted (permanent) | Add to Album / Cap 19 | Cap 19-19.2a | WakeTok User Album uniqueness must use KV + `localIdentifier`, not title string — duplicate same-title albums possible | **Device confirmed (19.2a Kafka Debug, `cap19-19.2a-notes.md`):** iOS Photos allows multiple User Albums named `"WakeTok"`; each Limited create-only bootstrap (or KV clear + recreate) adds another album. Limited path forbids list find (ADR-021). **D1 bootstrap must treat persisted `albumIdentifier` as canonical identity** — not display-name dedup. KV loss under Limited may create a second album even when one already exists in Photos. Accepted cost of no-list-find rule; not a 19.2a blocker. | Cap 19.3 (D1 bootstrap) / D3 follow-up | ADR-021 / ADR-K; `docs/acceptance/cap19-19.2a-notes.md` |
| 446 | Accepted (phase) | Add to Album / Cap 19 | Cap 19-19.5b | Panel add-to-album is single-select only — one album per sheet open; sheet dismisses on success | MVP scope: append the same asset to multiple albums requires reopening the panel each time. A fuller product may add multi-album multi-select + confirm (sheet stays open). PhotoKit has no single public “add to N albums” call — domain primitive `AlbumMutationRepository.addAssetToAlbum` is correctly one asset+album pair; upgrade is UI orchestration (N sequential calls) or optional Host batch in one `performChanges`. Distinct from Cap 19.7 **duplicate-append** row (re-append to the **same** album). | Unassigned | ADR-040 |
| 447 | Accepted (phase) | Add to Album / Cap 19 | Cap 19.8 | Cap 19 actions half-sheet: (1) enter has no visible bottom-up slide; (2) occasional tap→open hitch — after tapping the bottom-trailing icon, the UI sometimes does not react immediately (brief blank / light stutter) before the sheet appears | **Profile-confirmed (Kafka, Cap 19.8).** **Root cause (both limbs):** on tap the main isolate must cold-build the full half-sheet (Favorites + album picker + frost) while the playing feed still contends for frame budget; when that first paint overruns the ~250ms wall-clock enter, the slide is skipped (exit still animates — warm tree); when the thread is only intermittently busy, the same cost shows as post-tap hitch then pop-in. Empty fixed shell slides (isolates content cost). Two mounting strategies tried (defer-one-frame; defer-to-completed) both rejected — neither achieves single-phase visible slide. Profile full-content with `BackdropFilter` removed still flashed (Experiment 1 / Profile full control) — first-paint content cost alone can skip enter, so deferring only frost while keeping Favorites/album sync is unlikely to restore the slide. **Not exhaustively ruled out:** reducing the loading-skeleton build cost of Favorites/Album rows themselves (near-zero-cost static placeholders before real `ConsumerWidget` loading), and/or Host pre-warm (may only marginally cut hitch frequency). Future revisit should try those before assuming architecture-level rework. Reverted defer/frost staging; keep stock sheet. Distinct from ADR-042 (current-asset actionable gating). | Unassigned | ADR-040; Cap 19.8 Profile A/B |
| 448 | Accepted (phase) | Add to Album / Cap 19 | Cap 19.8 | System interactive-pop / back-gesture vs Cap 19 full-width left-swipe (D2=B) | **P-19.6-POP note at Cap 19 close-out.** D2=B does **not** claim interactive-pop is solved (ADR-041 / Cap 19 §5). 19.8 owner acceptance did not treat this as a Cap 19 blocker; residual conflict risk remains if iOS edge-back competes with left-swipe near the screen edge. Not a product-visible Cap 19 regression — accepted residual until a later gesture Cap revisits. | Unassigned | ADR-040 Decision 2; ADR-041; Cap 19.6 notes |
| 449 | Open | App Foundation | Cap 20.5 | No machine CI that runs `flutter test` on push (agent-only architecture / scoped Cap gates) | Cap 20.4 L1 unify broke Cap 15.5 `W-15.5a` Image State identity; agent Cap20 tasks ran architecture + Cap20 files only — no GitHub Actions / other CI forces full suite. Rule docs alone re-create the same miss class. Need a real push CI job (at least full `flutter test` or continuity + architecture). | Later (tooling) | — |
| 450 | Closed | Main Browse Screen / Cap 20 | Cap 20.5 | Still photo L1↔L2 doom-scroll black flash (peek / promote) after Cap 20.4 L1 unify | **Closed by post-20.5 work `3d29823`:** single `MagnificationHostModeBinder` on still cover (no Transient/Still type fork); `W-15.5a` enter + leave continuity in `still_image_element_continuity_test.dart`; Kafka/i17 local-asset doom-scroll PASS. Video shrink (mechanism C) and release scale spike (mechanism A) fixed separately in `282009e` — see `docs/acceptance/cap20-post-20.5-blackflash-shrink-notes.md`. | Closed by post-20.5 (`3d29823`) | ADR-043 Decision 14; Cap 15.5 |
| 451 | Closed | Main Browse Screen | Cap 20 | `W-14.6c` still `Image.file` uses `BoxFit.fill` but test expected `BoxFit.contain` | **Closed by Cap 20.6** (`bc15517`): assert rewritten for Cap 20 letterbox shell — `StillFittedMagnificationShell` sizes a contain-formula box from positive pixel dims; `Image` uses `BoxFit.fill` **only inside that box** (not viewport stretch). Architecture `presentation_defaults_test` still documents ctor default `BoxFit.contain` for fallbacks. Degenerate / missing pixel dims → viewport-sized fill stretch is debt **452** (Open). | Closed by Cap 20.6 (`bc15517`) | ADR-028; Cap 14.6c; Cap 20 letterbox |
| 452 | Open | Main Browse Screen | Cap 20.6 | Missing or ≤0 `pixelWidth`/`pixelHeight` on display still → letterbox shell falls back to viewport size → `BoxFit.fill` stretches | Production Host normally writes PHAsset / decoded dims. Dart fields stay nullable (Pigeon optional). Shell treats null OR ≤0 as fitted=viewport — then fill WOULD stretch. PHAsset can report 0 / wrong dims (iCloud / incomplete metadata). Healthy-path guard is `W-14.6c` (`bc15517`); this Open row tracks the degenerate-dims residual. | Unassigned | ADR-028; Cap 20 letterbox; `cap20-20.6-notes.md` |
| 453 | Closed | Live Photo (Cap 9) | Cap 20.6 | App leave / lock mid Live motion left a mid-frame PV; pinch dead | **Lifecycle gap itself is Cap 9 legacy** (no AppLifecycle → Live unload from Cap 9 landing). **Became user-visible only after Cap 20.5** wired `_liveMotionMounted` to `MagnificationHostMode.none` (stuck mid-motion frame + pinch failure = same root cause, two faces). Pinch recovery **depends on** Live unload — not a separate debt. **Not an ADR-043 product decision** (lifecycle fix under Cap 9 / ADR-019 shape; Host-mode gate only made the gap visible). Discovered during Cap 20.6 soak; does **not** block 20.6 close-out. **Closed by** `7f43863` (2026-09-05): leave `inactive`/`paused`/`hidden` + resume heal → same unload as `playbackEnded`, then best-effort `stopPlayback`; unload claims dirty before Host stop (stacked leave idempotent). i17 Profile PASS: static cover + pinch. | Closed by Cap 20.6 soak (`7f43863`) | ADR-019 |
| 454 | Closed | Main Browse Screen | Cap 21.2 | `W-14.6b-L4` / `W-15.3` corner-chrome bottom inset assert expects ~12; product bottom is ~7.2 since media chrome layout | **Discovered during Cap 21.2; not introduced by 21.2.** Stash of all Cap 21.2 Origin/ChromeState work still failed identically on clean HEAD. Root cause: `81904e1` (2026-09-05) changed `_FeedCornerChrome` bottom from fixed inset 12 to `mainBrowseLiveStatusBottomInset` (≈7.2, aligned with Overlay; see `media-chrome-layout-notes.md`); widget asserts still used `closeTo(12, 1)` on `feed.bottom - chrome.bottom` (trailing inset 12 remained correct). Distinct from closed debt **440** (timing/strut reds, fixed `6682582`). **Closed by test-only fix:** `W-14.6b-L4` / `W-15.3` now assert trailing via `kMediaChromeTrailingInset` and bottom via `mainBrowseLiveStatusBottomInset(tokens)` — aligns asserts with the product value already shipped in `81904e1`; **no `lib/` product change**. Full `flutter test` green. | Closed by debt-454 test align | —; `81904e1`; `docs/reference/media-chrome-layout-notes.md` |
| 455 | Closed | Saved Pool persistence | Cap 21.5 | Cap 22 Saved composition/detail must plan `assetSourcesProvider` refresh; list does not auto-detect deleted albums | **Closed by Cap 22:** Saved list / Info / chip peek invalidate `assetSourcesProvider` on open (ADR-046 D8 / 22.4 `0ca1198`); Cap 22.6 matrix **P-22.6-F** owner PASS on Kafka + i17 (real Photos album-removed honesty; notes `cap22-22.6-notes.md`). Session/Queue lag remains ADR-027 / ADR-023 D7 — orthogonal. | Closed by Cap 22 (22.4 refresh + 22.6 F) | ADR-044 / ADR-045 / ADR-046 D8; Contract pointers list-lag note |
| 456a | Open | Main Browse Screen / Cap 19 | Cap 21.6 | L2-ready still path skips PHAsset liveness (ex-456 Part A) | **Split from bare 456 at Cap 23.1.** Session still L2-ready + on-disk temp → `FeedPageMedia.still(cover)` without `requestDisplayAsset`; external delete can keep showing the JPEG until temp eviction / origin change — Cap 21.6 feed copy never fires until Host is hit. Out of ADR-044 D3. Future: Host existence check / tighter L2-ready. Not Cap 23 (still-in-library mutation gate). | later Host / L2-ready tighten | ADR-044 D3; Cap 15.10; ADR-033 |
| 456b | Closed | Main Browse Screen / Cap 19 | Cap 21.6 | Panel / mutation still-in-library gate (ex-456 Part B) | **Split from bare 456 at Cap 23.1.** Prefer proactive “asset still in Photos” checks **before** Favorites / Cap 19.5 Add-to-Album / left-swipe / future Share. Distinct from Cap 19.8 `mainBrowseCurrentAssetActionableProvider`; **AND** — do not merge axes. Predicate: `AssetAvailability != unavailable` (iCloudNotDownloaded remains still-in-library). Cap 21.6 Overlay hide + Cap 19 entry dim reuse feed `assetUnavailable` as interim — not this probe. Cap 23 / ADR-049 implements the gate. Half-sheet Delete / delete-original → debt **464**, not this row. **Closed by Cap 23.4** device matrix PASS (Kafka + i17 P-23-A…G); work `893c8fb`; notes `cap23-23.4-notes.md`. ADR-049 Accepted at Cap 23.5. | Closed by Cap 23.4 | ADR-049; ADR-042; ADR-033; ADR-044 D3; Cap 19.5 / 19.8 |
| 457 | Open | Main Browse Screen | Cap 21.6 | Host `layer2Failure` collapses missing-PHAsset and pre-transfer L2 failure into the same `assetUnavailable` wire code | Cap 21.6 remaps that code to `FeedFailureReason.assetUnavailable` + hides manual Retry (ADR-044 D3 feed-display only). Pre-transfer / China-SKU wireless users therefore lose wireless-specific copy and the Retry button, but retain: (1) debt **406** lifecycle auto-retry on resume (`_retryFailedLayer2AfterResume` ignores reason); (2) swipe to another feed item and back — leave clears fail chrome, activation bumps display generation, `_startLoad` re-requests L2 because fail never minted an L2-ready token. Splitting the Host bucket needs a new Pigeon/Host capability outside D3. Mid-transfer fail remains `iCloudDownloadFailed` (download copy + Retry). | Later Host / Pigeon capability | ADR-044 D3; debt **406** / **435**; Cap 21.6 |
| 458 | Monitoring | Main Browse Screen / Cap 20 | Cap 22.4 | Vertical feed lost page-snap (continuous slow drag; adjacent peeks L1→L2); kill-app recovers, leave-Browse does not — seen after Live (22.4) and once on **video** (Cap 25) | **Hit 1 — Cap 22.4 i17 Profile soak (`0ca1198`).** Offline Live play-once: pinch/other gestures had **no** magnification visual (Live Host `mode == none` as designed), then vertical paging became continuous strip drag (neighbor pages half-visible; peeks still advanced L1→L2) instead of snap page-change. **Not Cap 22.4 Saved chrome.** Leave Browse / return did **not** heal (IndexedStack keep-alive retains `PageController` / `ScrollPosition`); force-quit did. **Hit 2 — Cap 25 Decision 14 Profile on Kafka (iPhone 13 Pro), owner report.** Same page-snap loss once on a **video** while an iCloud-not-downloaded item was still L2-not-ready (Share correctly dimmed); owner was repeatedly tapping the dim Share hit target to confirm no response — not a normal Share path. Share dismiss was likely swipe-down (not 100% certain). Exact timing vs dim→bright edge unclear. Same fragility **family** as Project facts Host pinch / `DragScrollActivity.shouldIgnorePointer` (Platform View + outer pinch Listener + PageView). Do **not** change PageView physics without a reliable repro. **Relation to Bug#1** (video share sheet outside-tap / intermittent pause-toggle) **unconfirmed** — continue Monitoring; pause dedicated 458 chase until Bug#1 is diagnosed. | Continue **Monitoring**; opportunistic note if seen again. Primary: next Flutter SDK upgrade pinch/scroll re-verify. Do **not** put on Cap 25 must-pass close list. Cap discussion only if a clean repro appears independent of Bug#1 / dim-Share poke. | ADR-043 / ADR-040 / ADR-019; Project facts pinch/`DragScrollActivity` note; Cap 25 D14 device; Bug#1 |
| 459 | Closed | Main Browse Screen | Cap 22.5 | Endless round remount H0: when H1 Layer-1 seed misses, &lt;150 ms may show silent `feedBackground` (no gold spinner) before L1/L2 | **Closed:** Cap 22.5b real-bridge / soft-commit / H1–H0 remount path **reverted** to scheme A (static placeholder). Mechanism no longer exists. | Closed by Cap 22.5 scheme A revert | Cap 22.5; `cap22-22.5-endless-round-bridge-notes.md` |
| 460 | Closed | Main Browse Screen | Cap 22.5b | Soft-commit **landing==0** → post-frame+50ms epoch remount may chop a fling started inside that 50 ms window | **Closed:** soft-commit / deferred epoch remount **removed** with bridge revert (scheme A). | Closed by Cap 22.5 scheme A revert | Cap 22.5b; `cap22-22.5-endless-round-bridge-notes.md` |
| 461 | Closed | Main Browse Screen | Cap 22.5b | Fling past prepared[0] **and** prepared[1] can still hit a later last-page wall | **Closed:** prepared bridge pages **removed** with bridge revert (scheme A). | Closed by Cap 22.5 scheme A revert | Cap 22.5b; `cap22-22.5-endless-round-bridge-notes.md` |
| 462 | Closed | Main Browse Screen / Cap 19 | Cap 22.5b | Round-bridge remount disposed Cap19 left-swipe Listener while pointer still tracked → Unhandled `ref` after unmount | **Closed in Cap 22.5b follow-up:** remount clears `cap19LeftSwipeDragProvider`; gesture `mounted` guards on all `ref` / animation paths; `W-22.5b` remount with unfinished left-swipe pointer. Pattern retained on scheme A `advanceToNextRound` remount. | Closed by Cap 22.5b (pointer harden); retained on scheme A | Cap 22.5; ADR-041; `cap22-22.5-endless-round-bridge-notes.md` |
| 463 | Accepted (permanent) | Main Browse Screen | Cap 22.5 | Cross-round zero-hitch doom-scroll is impossible under finite-round table + boundary data-source swap | **Architectural floor (same Status class as debt 445).** Device soak under soft-commit bridge showed data-source identity swap overlapping in-flight `DragScrollActivity` / Ballistic on the common fast-scroll path — a discrete swap cannot be guaranteed never to collide with continuous scroll. Cap 22.5 ships scheme A (static placeholder + ScrollEnd → `advanceToNextRound` remount + jump) and **accepts** a hard cut. **Only path to a true zero floor:** scheme D (monotonic infinite index space + domain virtual mapping + product decision on cross-round back-scroll) — **independent Cap**, not misc polish. **Final product framing:** the residual pause is no longer an unpredictable defect surface — it now presents to the user as a legible, self-explanatory round boundary (placeholder page, then a brief deliberate pause before the next round starts), not as a stall or bug. This resolves the earlier concern that the pause read as broken/unexplained. It does **not** resolve, and was never intended to resolve, the original product ask for true endless zero-hitch doom-scroll continuity across round boundaries — that remains exclusively scheme D's territory. What changed across Cap 22.5's iteration was not the technical floor (still architectural, still non-zero), but the framing of the residual pause from "unexplained hitch" to "an accepted, consistent, user-legible boundary marker." Full retrospective + scheme D seed: `cap22-22.5-endless-round-bridge-notes.md` (see **Scheme D — future Cap seed**). | Scheme D only (future Cap; not scheduled) | Cap 22.5; `cap22-22.5-endless-round-bridge-notes.md` |
| 464 | Closed | Photo Library / Cap 24 | Cap 22 ADR-048 | Soft-delete current asset to system Recently Deleted (App soft-delete intent) | **Closed by Cap 24 / ADR-050.** Original row parked informal “delete from Photos” intent against kickoff bans. Cap 24 shipped soft-delete-to-system-Recently-Deleted only (`PHAssetChangeRequest.deleteAssets` → RD; Session Queue kick; never Empty RD). That soft-delete limb is done. **Permanent Empty Recently Deleted / purge originals** never entered Cap 24 — see debt **469**. Historical intent-park wording and ADR-048 invalidation cues remain useful background; do not reopen **464** for Empty/purge. | Closed by Cap 24 | ADR-050; ADR-048; ADR-049; debt **469**; kickoff (narrow supersede for soft-delete only) |
| 465 | Closed | Main Browse Screen | Cap 24.2 | Widget tests W-16.4d / W-16.4e: after Fake `deviceLocalForIds`, `displayCalls` is `['a1','a1']` where tests expect a single `requestDisplayAsset` | **Closed as (a) at Cap 24.5.5 (test-assert only; no product change).** After Cap 23 Fake `deviceLocalForIds`, W-16.4d saw `displayCalls == ['a1','a1']` before Retry. Read-only path: single `_startLoad` → `_startLoadFromDeviceLocalFirstVisit` → L2 `requestDisplayAsset` #1 → permanent `iCloudDownloadFailed` → Cap 15.12 false-positive fallback `_runFullLayer1BecomeCurrentPath` → `requestDisplayAsset` #2 (sequential; not become-current double-fire / missing single-flight). Same contract already locked by **W-15.12d** (expects length==2) / **W-15.12i**. Assert rewrite: acknowledge two pre-Retry displays; then assert Retry adds exactly one more call on a single `pump` (bypassDwell). W-16.4e kept out of the 465 narrative (separate All-tab deviceLocal skip-L1 / cover harness). Not a product bug; no new debt opened. | Closed by Cap 24.5.5 | ADR-034 D5; Cap 15 deviceLocal path; Cap 16.4; Cap 23.4 |
| 466 | Closed | Main Browse Screen | Cap 24.2 | Widget tests W-L6 / W-O-* / W-Loc2 / S-1 / S-3 / S-5 (and kin): `mediaInfoOverlay` or size copy `Found 0` while fail/Retry chrome may already be correct | **Closed by Cap 24.5.5 (test-infra only).** Root cause: Cap 21 `_suppressStillCoverChrome` hides Overlay until still/poster decode-ready; harness `/tmp/fake_*.jpg` never cleared the gate. Fix: shared `still_cover_test_helpers.dart` (fixture PNG seed + `pumpUntilStillCoverReady`, preferring existing `debugForceStillCoverDecodeBroken(false)` under FakeAsync). Product suppress logic unchanged. Restored W-O / W-L2 / W-L6 / W-Loc2 / S-1 / S-3 / S-5 (and kin). | Closed by Cap 24.5.5 | Cap 21 Overlay/cover discipline; Cap 8 Overlay |
| 467 | Closed | Main Browse Screen | Cap 24.2 | Widget tests Cap 17.3 (W-17.3a/l) / Cap 17.6 (W-17.6-*) / Live L-S* preparing: `mainBrowseFeedLayer3Spinner` or `mainBrowseFeedLivePreparing_*` `Found 0` | **Closed by Cap 24.5.5 (test-infra only).** Root causes: (1) `debugForceLayer2WaitChrome` without `mediaKind: still` never forced cover-ready (Approach A: pass `FeedPageMediaKind.still` in W-17.3a/l); (2) Live/video wait-chrome kin hit same suppress / All-tab `deviceLocal` skip-L1 so hung L2 never painted cover — harness used `iCloudNotDownloaded` + shared cover helper + F1 `pumpPastLivePreparingSuppress` where needed. Did **not** broaden debugForce API semantics or change `_suppressStillCoverChrome`. Restored Cap 17.3/17.6 / L-S* / W-14.6b / W-14.4 video wait-chrome reds. | Closed by Cap 24.5.5 | ADR-034; Cap 17.3/17.6; Cap 14.6b Live chrome |
| 468 | Monitoring | Main Browse Screen / Cap 24 | Cap 24.4b | Occasional first-page Layer 1 stall (never promotes to L2); heal by swipe away + revisit | **Seen twice on Kafka Profile (device-local stills, not iCloud):** (1) Cap 24.4b after Endless start-over (`0ccc8fa`); (2) Cap 24.4c after Pool/Origin leave-return (`0b6c7c6`). **Not** attributed to `sessionWorkingAssetIds` or `processSoftDeletedAssetIds` (those only shape Session id lists). **Photos side-channel (suspected co-factor, not proven):** owner also deleted/restored assets in system Photos while WakeTok stayed alive. Code: no `PHPhotoLibraryChangeObserver` (ADR-044 D3) — external delete/restore does **not** mutate Session Queue, Snapshot cache, or `processSoftDeletedAssetIds` (App soft-delete only). Leave→Photos→resume only auto-retries **already-failed** L2 (`_retryFailedLayer2AfterResume`); in-flight / never-started L2 is not restarted. Plausible race with lifecycle + next Host display request after PhotoKit mutation; causal link still unclear. **On recurrence record:** (1) iCloud vs device-local; (2) App soft-delete and/or Photos delete+restore in same process without force-quit; (3) start-over vs Pool leave-return; (4) leave-current + return / swipe+revisit self-heals. | Unassigned (observe) | ADR-025 / Cap 15–17 L2; Cap 22.5; ADR-044 D3; debt **444** / **456a** |
| 469 | Accepted (permanent) | Photo Library / Kickoff scope | Cap 24.6 | Permanent Empty Recently Deleted / purge originals from Photos (not soft-delete-to-RD) | **Never in product scope.** Split from debt **464** at Cap 24 Accept (ADR-050 D1 / D11). Cap 24 closed soft-delete-to-RD only; emptying Recently Deleted, permanent purge of originals, Hide, batch delete, and in-app trash UI remain forbidden. Kickoff “no delete/modify originals” permanent-purge reading stays binding. No Cap will schedule Empty RD / purge without a new ADR that overturns this row. | Never (no Cap) | ADR-050 D1/D11; debt **464**; kickoff |
| 470 | Accepted (phase) | Live Photo / Cap 26 | Cap 26.2 | Magnified Live long-press does not replay (user must Reset / return to fit first) | **Known MVP limitation — not a miss.** Cap 26.2 keeps ADR-052 D6/D10 magnified ignore and ADR-043 D1 Live rising-edge force-fit / no Flutter `Transform` on `PHLivePhotoView`. In-place magnified replay (Photos-like keep scale+pan) would require Host-side Live surface scale (same class as video L2 `setDisplayMagnification`); Flutter Platform View does not follow Flutter `Transform`, and `PHLivePhotoView` owns opaque playback/animation lifecycle so external bounds transforms are higher risk than the video L2 case already proven painful. Owner skipped MVP investment; no Cap scheduled to “fix” this. This row records the known consequence of those ADR decisions, not a newly found defect. | Unassigned (MVP accepted; no Cap scheduled) | ADR-043 D1; ADR-052 D6/D10 |
| 471 | Monitoring | Live Photo / Cap 21 source · Cap 9–26 browse | Cap 26.3 | System Album Live Photos (213) membership can diverge from WakeTok Live presentation (`.photoLive` / `mapMediaKind`) | **Observed (iPhone13pro Kafka, iOS 26.6 / 23G71; Host probe on `requestPresentationMetadata`):** two Photos Live-off assets remained browsable from a Live-oriented pool path but Browse showed no Live Overlay / LIVE badge and did not arm Live play — probe logged `mediaSubtypes` `0x200` with `photoLive=0` (`playbackStyle=1` observed only). A Live-on control in the same session logged `subtypes=0x208` (`photoLive=1`, `playbackStyle=3`). Not a WakeTok recognition bug: smart-album **213** membership and subtype-based Live identity are independent PhotoKit surfaces. **Symmetric risk (not observed on this probe):** if some iOS version / Live-off workflow keeps `.photoLive`, WakeTok would still show Live chrome and call `requestLivePhoto` while Photos presents a still — same class of accepted non-parity as ADR-052 Decision 11 ignoring `playbackStyle` for Live identity. Accumulation: `docs/reference/ios-photokit-implicit-behavior-notes.md` §2.3. | Unassigned (Monitoring; revisit if Pool UX or Photos-parity Live-off becomes a product goal) | ADR-052 D11; Cap 9 `mapMediaKind`; Cap 21 smart album 213; PhotoKit notes §2.3 |
| 472 | Closed | Main Browse Screen / Cap 26.4a | Cap 26.4a | Video L1 poster→L2 path change: whole Meta Overlay flash **unverified** → closed | **Closed by Cap 26.4a device smoke (Kafka + i17 Profile).** Owner saw no Meta 3-row flash on video while accepting still L1→L2 keep-ready. **Not a side-effect of 26.4a:** keep-ready explicitly requires `_media?.kind == FeedPageMediaKind.still` and excludes `kind == video`. **Structural reason video usually does not flash:** on video L2 success, `_trackStillCoverPath` is called with `(layer1?.display ?? _media?.display)?.localFilePath` — the **existing L1 poster**, not a new L2 full-still file. The “path changed → clear `_stillCoverReady` → `_suppressStillCoverChrome` tears down Overlay” branch is usually **not entered** because its path-change precondition does not hold for video; it is not that video somehow bypasses that branch after entering it. **Residual:** if video poster wiring later **does** swap to a different file between L1 and L2, the **same** clear-ready tear-down can return — 26.4a does **not** structurally make video safe (and keep-ready would still not apply while `kind == video`). Reopen only with a video-scoped change if flash is seen after such a poster-source change. | Closed by Cap 26.4a (Kafka + i17; structural note above) | Cap 26.4a; `vertical_media_feed.dart` `_trackStillCoverPath` + video `_applyLayer2Result` poster reuse; Cap 23.4 `_suppressStillCoverChrome`; Cap 15.5 gapless; layout notes §13 |

> Known debt ID **402 is permanently retired and must not be reused**:
> historical append-only notes used “UX-1 (402)” for debt **436**, while an
> earlier live Cap 18 draft reused 402 for debt **434**. Historical files stay
> unchanged; all new references use this table's canonical ID column.
>
> Bare Known debt ID **403** is retired as a single row (split into **403a** /
> **403b-progress** / **403b-wallclock**). Do not reuse bare 403. Logged stays
> empty on the split rows: first logged as 403 before Cap 18.
>
> Bare Known debt ID **456** is retired as a single row (split into **456a** /
> **456b** at Cap 23.1). Do not reuse bare 456. Logged on both split rows
> remains Cap 21.6 (original row). Historical notes may still say “456”;
> new references use **456a** / **456b**.
