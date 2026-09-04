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
- [ ] <-- YOU ARE HERE: Display magnification (pinch to zoom, lightweight)
      (Cap 20). L2 still: persistent zoom + Reset; all L1 + video L2:
      transient release→fit (ADR-043 Decision 13/14). Magnified still pan
      overrides vertical PageView until fit — Cap 18 freezes that
      arbitration exception; Cap 20 implements.
- [ ] Build a Pool, Ephemeral Pool, and Source ordering
      (**deferred past Cap 14**)
- [ ] Saved Pool persistence, reopen, management, and capacity limits
      (**deferred past Cap 14**)
- [ ] Auto-play Presets and Mode Eligibility Rule
      (**deferred past Cap 14**)
- [ ] Auto-play One-item Lookahead Fetch, Waiting for Media, and
      iCloud Fallback
      (renamed so “iCloud Fallback” is Auto-play / ADR-O, not Cap 14)
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
- [ ] Share, Mute, Fit / Fill / 9:16 Crop, 2x gesture
      (tap-to-pause/resume moved to Cap 18; MVP 2x = left **or**
      right edge hold for temporary 2x, release → 1x; no
      slide-down lock; Cap 18 freezes both-edge hold slots and
      edge-hold vs left-swipe album arbitration only — no 2x
      product UI in Cap 18)
- [ ] Settings and localisation completion
      (English/zh-Hans copy, privacy/storage/about screens,
      Light/Dark layout verification; Limited Access manage
      entry — `presentLimitedLibraryPicker` + Open Settings —
      belongs on the Settings page when this capability lands)
- [ ] Final real-device performance, memory,
      accessibility, privacy, and error-state hardening
- [ ] TestFlight internal testing and release-candidate validation
      (owner executes distribution; Cursor prepares build and metadata)
- [ ] App Store metadata, screenshots, privacy disclosures,
      submission, and release verification
      (owner executes submission; Cursor prepares assets only)

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
Active capability: Display magnification (pinch to zoom, lightweight) (Cap 20)

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> Principle: within Cap 20’s implemented behaviours (pinch in, magnified
> pan, clamp-to-fit floor), **Layer-2** still (photo / animated / Live
> static) is persistent + Reset; **all Layer-1** and **video L2** are
> transient release→fit. Match iOS Photos feel for still / animated /
> Live static L2. ADR-043: **Known delta** = fixed max scale only; other
> Photos-only behaviours stay **Out of Cap 20**. Decision 13 =
> `setDisplayMagnification` (narrow Host API); Decision 14 = L1 unify.
> Inherits Cap 19 Decision 20 left-swipe magnification guard
> (`browseStillMagnifiedProvider` replaces Cap 19 stub as of 20.2).
> Live motion PV window (`_liveMotionMounted`): no new pinch; force fit
> on rising edge — **no** PHLivePhotoView Transform spike (cancelled).

- [x] 20.1 Contract freeze
      — D1–D6 locked (D7/D8 Out / no-touch); Live PV scale spike
        **cancelled** (static Live = still path; motion window gated);
      — ADR-043 Accepted; GLOSSARY §18 Display Magnification / pinch /
        Reset (Fit vs fit disambiguation; file now **local-only /
        gitignored**)
- [x] 20.2 Magnification signal + arbitration wiring
      — work `ae9cb7e`; stub → `browseStillMagnifiedProvider`;
        PageView lock + left-swipe guard; arena unit tests
        (T-20.2-12a/12b Live rising-edge auto + remount/replay)
- [x] 20.3 Still path (persistent pinch + pan + clamp-to-fit + Reset;
      includes Live static key frame / animated image as still)
      — work `e6515ea`; PageView-outer host; Plan A (no single-finger
        candidate lock); T-20.3-1…11
- [x] 20.4 Video path (non-persistent; release → fit; mid-pinch D3;
      playback continues) + L1 unify transient
      — work `ca3b4ed` (Decision 13 `setDisplayMagnification`) +
        `32d149f` (transient rename, L1 unify, native push gate,
        L1→L2 handoff T-20.4-12); Kafka Profile L2 smoke PASS
- [x] 20.5 Live motion-window gate
      — work `114f393`; main D1 path already in 20.2–20.4; this phase
        nails Host mode-none ignore + T-20.5-* and rising-edge
        `hasActiveMagnification` coverage (not a new motion gate).
        i17 Live static→motion→static smoke PASS (local Live assets)
- [ ] 20.6 Device acceptance (Kafka + iPhone 17; max-scale pick 3×/4×;
      retest Cap 17.6 **B.1** fast-swipe <300ms / no flyby thrash —
      still pinch must not regress it; Plan A: no single-finger candidate
      lock; **cover still + video mixed-pool continuous fast-swipe**
      (same Host on both surfaces); also soak Q2-A: after video pinch,
      one finger remains → pan while PageView locked — confirm users can
      still leave the page without a “stuck” feel, else revisit Q2-B;
      still keep Image Element continuity green — `W-15.5a` /
      leave `W-15.5c` + video release no-spike `T-20.A-1`)
- [ ] 20.7 Cap close-out (Cap `[x]`; PHASE_HISTORY; YOU ARE HERE next)

## Now working on (describe ONLY the in-progress item)
- Goal (one line): Cap 20.6 device acceptance (Kafka + i17; max-scale
      3×/4×; B.1 / Q2-A soak)
- Sub-steps done: 20.1–20.5; still L1↔L2 black-flash fix `3d29823`
      (debt **450**); video shrink C + release spike A `282009e`
      (Kafka C/A verified separately — PASS)
- Next step: 20.6 soak / max-scale pick on Kafka + i17
- Related decisions: ADR-043 (Decision 13 inner-content supplement
      `282009e`); debts **449** Open / **450** Closed / **451** Open
      (W-14.6c BoxFit); ADR-040 Decision 16 / Decision 20; debt **448**
      Out of Cap 20

## Contract pointers (don't memorize, go read the source)
- Domain terms (bilingual, **local only / gitignored**):
  docs/GLOSSARY.en-zh.md — not published; Cap-frozen terms also in
  DECISIONS.md (e.g. ADR-043 Display Magnification)
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/waketok_platform_apis.dart → lib/platform/generated/, ios/Runner/Platform/ (spike under pigeon/spikes/ reference only)
- l10n: lib/l10n/ (ARB + AppLocalizations; locale_resolution.dart; untranslated_messages.json)
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
  (`aa03be8` / ADR-023)
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
| 417 | Open | App Foundation |  | Localization Inventory auto-generation/report tooling (kickoff ADR-U §7–8 summary artifact) | Hardcoded-copy scan + ARB key parity closed by ADR-012; Inventory report generator still deferred | Settings and localisation completion | — (kickoff ADR-U) / ADR-012 |
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
| 431 | Closed | Main Browse Screen |  | All / Photos / Videos quick tab switch flashes one frame center Layer1Loading (“Loading item” / “正在加载此项”) | **Closed by 17.9** (`f1ffadf` / ADR-039): source-switch-only 150 ms delay hides **visible** center copy on first current page after tab change; corner spinner + VoiceOver `mainBrowseFeedLayer1Loading` semantics stay immediate. Vertical swipe / cold start unchanged. Kafka Profile owner验收 PASS (4-step). | Closed by Cap 17.9 (ADR-039) | ADR-039 |
| 432 | Open | Main Browse Screen |  | All / Photos / Videos quick tab switch may flash one frame feed-shell `mainBrowseFeedLoading` (“Loading library…” / “正在加载图库…”) | **Optional polish (retained).** Tab change starts a new Consumption Session (`browseSessionProvider` reload); cached snapshots typically ≤1–2 frames of shell loading. Semantically distinct from page Layer1 copy (17.9 closed rows above). Owner rejected blank-hold polish (empty feed color reads as bug/stutter). Alternatives (`skipLoadingOnReload`, cache-hit synchronous session swap, delayed whole-screen library chrome) unevaluated. | Unassigned | ADR-023 D8 / ADR-039 |
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
| 439 | Open | Live Photo | Cap 18.1 | Live explicit replay control | Owning Cap unassigned; ADR-019 Decision 8 narrow supplement pending that Cap. Persistent anchor for ADR-040 Decision 17 and Phase 18.1 `owning Cap TBD`. Do not delete unless an owning Cap has landed implementation and picked this up. | Unassigned | ADR-019 / ADR-040 |
| 440 | Closed | Main Browse Screen | Cap 18.3 | Seven existing spinner / preparing-chrome widget tests are red on `main` | Verified against clean baseline `9e4a04e` before Cap 18.3: W-16.4e, W-L2, L-S6, W-14.6b-L1/L4, W-15.3, and W-14.4 all fail identically before and after the 18.3 worktree changes. Failures concern missing Layer3 / Live-preparing chrome within test timing windows, except W-15.3's LIVE-badge strut height (`16.0`, expected `>16.0`). They are not Cap 18.3 playback-intent regressions. W-16.4e probe (still a2 + L1 + dwell; real arm+dwell, not debugForce; elapsed synced to FakeAsync): asserts spinner at t≈0, which conflicts with ADR-034 G (suppress &lt;150 ms); at t≥150 ms spinner paints — product chrome healthy. That assert’s timepoint is obsolete post-17.3 (stale assertion, not product regression). Does not re-prove the other six reds in this row. Widget tests reconciled to ADR-034 G/F1 clock semantics (elapsed sync + F1 timer pump); W-16.4e asserts ≥T dwell chrome; strut-height assertions removed post–Cap 17.5b layout. Seven tests green on `main` as of work commit `6682582`. | Closed before Cap 18.6 (test/chrome reconciliation) | ADR-032 / ADR-034 / ADR-039 |
| 441 | Monitoring | Main Browse Screen | Cap 18.4 | Session **video** revisit: landing settle may show one-frame full black between blur Layer 1 poster and Layer 2 play | **Known phenomenon family** — same lineage as `cap15-15.10-notes.md` §D (peek blur poster → transition empty window → L2 play). Cap 18.4 device (Kafka Profile, Optimize ON): iCloud video first-visit L2 complete → Session revisit; peek blur L1 OK; **landing settle occasional one-frame full black** then L2 plays directly. Not debt **400** (blur poster present). **15.11** closed local→local matrix only — this trigger outside that matrix. **Suspected mechanism cross-ref (not confirmed):** debt **427** Host-temp cover eviction on a4 video L2-ready revisit may worsen landing flash; **441** can also reproduce as a one-frame settle handoff without ≥T empty window or corner spinner. **Continue observation** — no Cap scheduled. | Unassigned | ADR-006 / ADR-025 / ADR-032 / ADR-034; `cap15-15.10-notes.md` §D; debt **427** |
| 442 | Accepted (phase) | Main Browse Screen | Cap 18.5 | Cap 18.5 scrub preview bubble may show async JPEG placeholder gaps (fast-drag strip, first-scrub cold start, in-flight bucket transition) | AVAssetImageGenerator + Host single-flight coalesce + 1.0s preview bucket + ADR-040 Decision 13 §2.1 borrow (max one bucket step, 350 ms wall-clock) do **not** guarantee a continuous real-frame strip at competitor parity. **Three distinct triggers, same architecture:** (1) **fast horizontal drag** — borrow cannot cover every bucket crossing; (2) **first scrub engagement** — no prior successful JPEG to borrow, bubble waits on first Host decode; (3) **mid-drag in-flight / bucket switch** — `#000000` placeholder (or bounded borrow) until async JPEG arrives; **trigger (3) is not fast-drag-specific** — every bucket switch clears the current frame and waits on async Host return; at normal scrub speed that window is often below perception (BENCH typical **14–150 ms**) but is not guaranteed to stay sub-threshold (BENCH max **388 ms** on sparse-GOP zero-tolerance decode). **Accepted for Cap 18.5 ship** (`b2ceabd` eliminated sparse-GOP drift-reject **permanent** black on hold; placeholder-then-JPEG remains by design per supplement item 8). Cap 18.6 soak: owner-acceptable, not Photos parity. Further optional tuning: scrub-touch prefetch, `maximumSize`; widening borrow is **not** a candidate (violates §2.1). | Unassigned | ADR-040 Decision 13; `docs/acceptance/cap18-18.5-notes.md`; `docs/acceptance/cap18-18.6-notes.md` |
| 443 | Accepted (phase) | Main Browse Screen | Cap 18.5 | Cap 18.5 progress scrub is **whole-second** granular (not iPhone Photos / slow-mo 0.01s edit resolution) | **Intentional Cap 18.5 scope.** Linear band maps to ratio; label + release seek use `round(ratio × duration)` to the nearest second. Sub-second scrub requires quantizer, Host seek tolerance/timeouts, and preview bucket changes — documented upgrade path in acceptance notes. Not a defect vs Photos frame-accurate trimming. | Unassigned | ADR-040; `docs/acceptance/cap18-18.5-notes.md` |
| 444 | Open | Main Browse Screen | Cap 18.6 | External Photos delete while Consumption Session still lists the asset: misleading Layer 2 fail copy; Retry ineffective | **Verified (owner device, Kafka Profile `1ed7f0b`):** delete a still in iOS Photos without quitting WakeTok → first return to the same feed item still shows the image; swipe away and back → Layer 2 fail with `Could not load. Allow wireless data, then retry.` + Retry; Overlay metadata rows still visible — **not** a connectivity defect. **Verified (code):** missing `PHAsset` → Host `assetUnavailable`; Dart maps `assetUnavailable` → `FeedFailureReason.network` → that wireless-data string (debt **435** three-bucket collapse); no production `PHPhotoLibraryChangeObserver` / session queue invalidation on external library mutation. **Inferred (architecture — not log-verified this session):** first revisit may use cached L2 (`DisplayTempFileStore` / in-page display state); second remount likely hits fresh `requestDisplayAsset` on a deleted id. **Not Cap 18.6 scope.** | **Build a Pool, Ephemeral Pool, and Source ordering** | ADR-022 / ADR-025; debt **435**; `docs/acceptance/cap18-18.6-notes.md` |
| 445 | Accepted (permanent) | Add to Album / Cap 19 | Cap 19-19.2a | WakeTok User Album uniqueness must use KV + `localIdentifier`, not title string — duplicate same-title albums possible | **Device confirmed (19.2a Kafka Debug, `cap19-19.2a-notes.md`):** iOS Photos allows multiple User Albums named `"WakeTok"`; each Limited create-only bootstrap (or KV clear + recreate) adds another album. Limited path forbids list find (ADR-021). **D1 bootstrap must treat persisted `albumIdentifier` as canonical identity** — not display-name dedup. KV loss under Limited may create a second album even when one already exists in Photos. Accepted cost of no-list-find rule; not a 19.2a blocker. | Cap 19.3 (D1 bootstrap) / D3 follow-up | ADR-021 / ADR-K; `docs/acceptance/cap19-19.2a-notes.md` |
| 446 | Accepted (phase) | Add to Album / Cap 19 | Cap 19-19.5b | Panel add-to-album is single-select only — one album per sheet open; sheet dismisses on success | MVP scope: append the same asset to multiple albums requires reopening the panel each time. A fuller product may add multi-album multi-select + confirm (sheet stays open). PhotoKit has no single public “add to N albums” call — domain primitive `AlbumMutationRepository.addAssetToAlbum` is correctly one asset+album pair; upgrade is UI orchestration (N sequential calls) or optional Host batch in one `performChanges`. Distinct from Cap 19.7 **duplicate-append** row (re-append to the **same** album). | Unassigned | ADR-040 |
| 447 | Accepted (phase) | Add to Album / Cap 19 | Cap 19.8 | Cap 19 actions half-sheet: (1) enter has no visible bottom-up slide; (2) occasional tap→open hitch — after tapping the bottom-trailing icon, the UI sometimes does not react immediately (brief blank / light stutter) before the sheet appears | **Profile-confirmed (Kafka, Cap 19.8).** **Root cause (both limbs):** on tap the main isolate must cold-build the full half-sheet (Favorites + album picker + frost) while the playing feed still contends for frame budget; when that first paint overruns the ~250ms wall-clock enter, the slide is skipped (exit still animates — warm tree); when the thread is only intermittently busy, the same cost shows as post-tap hitch then pop-in. Empty fixed shell slides (isolates content cost). Two mounting strategies tried (defer-one-frame; defer-to-completed) both rejected — neither achieves single-phase visible slide. Profile full-content with `BackdropFilter` removed still flashed (Experiment 1 / Profile full control) — first-paint content cost alone can skip enter, so deferring only frost while keeping Favorites/album sync is unlikely to restore the slide. **Not exhaustively ruled out:** reducing the loading-skeleton build cost of Favorites/Album rows themselves (near-zero-cost static placeholders before real `ConsumerWidget` loading), and/or Host pre-warm (may only marginally cut hitch frequency). Future revisit should try those before assuming architecture-level rework. Reverted defer/frost staging; keep stock sheet. Distinct from ADR-042 (current-asset actionable gating). | Unassigned | ADR-040; Cap 19.8 Profile A/B |
| 448 | Accepted (phase) | Add to Album / Cap 19 | Cap 19.8 | System interactive-pop / back-gesture vs Cap 19 full-width left-swipe (D2=B) | **P-19.6-POP note at Cap 19 close-out.** D2=B does **not** claim interactive-pop is solved (ADR-041 / Cap 19 §5). 19.8 owner acceptance did not treat this as a Cap 19 blocker; residual conflict risk remains if iOS edge-back competes with left-swipe near the screen edge. Not a product-visible Cap 19 regression — accepted residual until a later gesture Cap revisits. | Unassigned | ADR-040 Decision 2; ADR-041; Cap 19.6 notes |
| 449 | Open | App Foundation | Cap 20.5 | No machine CI that runs `flutter test` on push (agent-only architecture / scoped Cap gates) | Cap 20.4 L1 unify broke Cap 15.5 `W-15.5a` Image State identity; agent Cap20 tasks ran architecture + Cap20 files only — no GitHub Actions / other CI forces full suite. Rule docs alone re-create the same miss class. Need a real push CI job (at least full `flutter test` or continuity + architecture). | Later (tooling) | — |
| 450 | Closed | Main Browse Screen / Cap 20 | Cap 20.5 | Still photo L1↔L2 doom-scroll black flash (peek / promote) after Cap 20.4 L1 unify | **Closed by post-20.5 work `3d29823`:** single `MagnificationHostModeBinder` on still cover (no Transient/Still type fork); `W-15.5a` enter + leave continuity in `still_image_element_continuity_test.dart`; Kafka/i17 local-asset doom-scroll PASS. Video shrink (mechanism C) and release scale spike (mechanism A) fixed separately in `282009e` — see `docs/acceptance/cap20-post-20.5-blackflash-shrink-notes.md`. | Closed by post-20.5 (`3d29823`) | ADR-043 Decision 14; Cap 15.5 |
| 451 | Open | Main Browse Screen | Cap 20 | `W-14.6c` still `Image.file` uses `BoxFit.fill` but test expects `BoxFit.contain` | Pre-existing on `main` after binder unify (`3d29823` era); unrelated to black-flash / shrink C / spike A. Architecture `presentation_defaults_test` still claims contain default; feed path at still cover uses `BoxFit.fill`. Not fixed in `282009e`. | Cap 20.6 prep or separate chore before claiming 14.6c green | ADR-028; Cap 14.6c |

> Known debt ID **402 is permanently retired and must not be reused**:
> historical append-only notes used “UX-1 (402)” for debt **436**, while an
> earlier live Cap 18 draft reused 402 for debt **434**. Historical files stay
> unchanged; all new references use this table's canonical ID column.
>
> Bare Known debt ID **403** is retired as a single row (split into **403a** /
> **403b-progress** / **403b-wallclock**). Do not reuse bare 403. Logged stays
> empty on the split rows: first logged as 403 before Cap 18.
