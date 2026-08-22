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
      `0e3eec2`; Release hang Known debt separate)
- [x] Media Info Overlay, loading states, empty states,
      POC-10 file-size semantics,
      optional best-effort Location Label (not release-blocking)
      (ADR-015…018; 8.8 notes; Location Known debt remains;
      cross-source playhead Accepted ADR-023 / Cap 13.5)
- [x] Live Photo rendering and static fallback (POC-08)
      (ADR-019; POC-08 PASS Cap 9.7; mute persist `4aa93b0`;
      UX-1 Known debt; UX-2 closed 14.6b `16ed6e3`;
      notes `cap9-9.7-poc08-notes.md`)
- [x] Asset Source and Source Pool Definition
      domain models
      (ADR-020; kinds `8c99d46`; SPD `6aa35dc`; ordering `954d7e0`)
- [x] Live Resolution, Asset Source Availability,
      Identity Coalescing, and Resolved Pool Snapshot
      (ADR-021; list `95779ef`; album resolve `2cf26a6`;
      Snapshot `44b783e`; smoke `8e37b64`; notes 11.2/11.3/11.6)
- [x] Session Queue, Default Session Profile,
      and stable Item Ordering Semantics
      (ADR-022; CFG `f53d455`; derive `ba81abc`;
      Queue `77571a9`; guard `a14d748`; accept `2e167bf`)
- [x] Endless Shuffle, Queue Stability, and Session Continuity
      (Cap 13 / ADR-023 Accepted `f0187b4`; ADR-024 `1f8a240`;
      13.6 closed under ADR-030 §5 everyday availability, owner
      2026-08-19 — not an Instruments numeric Pass; FAIL tables
      frozen)
- [x] Current-item iCloud media fetch, visual
      preheating, and loading states
      (Cap 14 / ADR-025 Accepted, work `393ebc9`; **first** 13.6
      foundation paid — iCloud copy-panel unreadability)
- [ ] <-- YOU ARE HERE: Feed swipe Layer 1→2 handoff polish and
      duplicate current-item Layer 2 request (Cap 15). Scope:
      still/video swipe-in flash; iCloud video no Layer 1 poster
      (400). **15.10 closed** (`750ddd6` / `cap15-15.10-notes.md`).
      **Next 15.9** close-out (STATE + PHASE_HISTORY). **393 explore
      paused** — redefine peek+settle scope before resume; do not
      resume on pre-pause explore doc alone. 393/400 still open. Cap 15
      does **not** close until 15.9. 13.6 close does **not** mark
      remaining debts solved. ADR-031 **Accepted** (anchor `4767ec4`,
      not 15.9). Notes `docs/acceptance/cap15-15.1-notes.md`.
- [x] Cancel and dwell current-item Layer 2 fetch
      (Cap 16 / ADR-029 Accepted, work `d273358`; notes
      `docs/acceptance/cap16-16.5-notes.md`; **second** 13.6
      foundation paid on the product path; 13.6 closed under
      ADR-030 everyday availability, not an Instruments Pass)
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
- [ ] Share, Mute, Fit / Fill / 9:16 Crop, 2x gesture,
      tap-to-pause/resume (non-workspace-area tap toggles play/pause
      with a center play/pause affordance)
- [ ] Add to Album
      (Full Access only; v1.0 scope;
      the only pre-authorized downgrade-to-1.1 item)
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
Active capability: Feed swipe Layer 1→2 handoff polish and
duplicate current-item Layer 2 request (Cap 15)

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.
> Phase Roadmap is set by the owner before work begins on each capability.
> When YOU ARE HERE moves, do not generate Phase Roadmap content without
> explicit owner approval of the phases. An explicit awaiting-scope placeholder
> is allowed at Cap close-out (see state-decisions-maintenance).
>
> Owner-approved 2026-08-19; 15.2 freeze 2026-08-20 (ADR-031
> Proposed). Diagnosis before contract is a deliberate deviation
> from 14.1/16.1. Throwaway probe never committed. Do not remount
> Limited banner. Do not use “Doom Scroll” in capability names /
> ADRs / identifiers.

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
- [ ] 15.9 Cap close-out docs (STATE + PHASE_HISTORY). **After
      15.10.** Does **not** flip ADR-031 Accepted (that is the docs
      commit after 15.3)

## Now working on (describe ONLY the in-progress item)
- Goal (one line): Cap 15.9 close-out (STATE Cap `[x]` + PHASE_HISTORY)
      after 15.10
- Sub-steps done: 15.10 closed (`cap15-15.10-notes.md`; work `750ddd6`;
      §5 + core §8 PASS; 393 still open, explore paused pending scope
      redefine)
- Next step: owner OK for Cap 15 capability close-out (15.9)
- Related decisions: ADR-025 (`393ebc9`, narrow supersede 15.10);
      ADR-031 Accepted (`4767ec4`); ADR-030 Accepted (`740bd99`);
      ADR-029 Accepted (`d273358`); ADR-006

## Contract pointers (don't memorize, go read the source)
- Domain terms (canonical, bilingual): docs/GLOSSARY.en-zh.md
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/waketok_platform_apis.dart → lib/platform/generated/, ios/Runner/Platform/ (spike under pigeon/spikes/ reference only)
- l10n: lib/l10n/ (ARB + AppLocalizations; locale_resolution.dart; untranslated_messages.json)
- Localization guard: ADR-012 + test/architecture/localization_test.dart
- Theme: lib/core/theme/ (WakeTokTokens ThemeExtension + waketokTheme; ADR-009)
- Authorization: lib/domain/authorization/, lib/platform/photo_library_gateway.dart, lib/features/authorization/ (ADR-010)
- Library catalog: lib/domain/library/, PhotoLibraryApi.libraryTotals / fetchLibraryPage (ADR-011); debug totals shell: lib/features/library_smoke/
- Main Browse shell: lib/features/main_browse/ (Cap 7.4–7.6 feed;
  Cap 8.2 immersive content + always-dark bottom bar `60f3283` / ADR-017;
  transparent top + compact bar `5fb93de` / ADR-016);
  Cap 14.4c IndexedStack always wrapped in immersive Theme (`6178f9e`)
  so Settings cannot dispose VerticalMediaFeed;
  Cap 13.4 Shuffle Session wiring: `lib/app/browse/browse_session_providers.dart`
  (`10a5735` / ADR-023)
- Built-in sources: lib/domain/source/, PhotoLibraryApi.listAssetSources / resolveSource (ADR-013); providers: lib/features/library_smoke/asset_source_providers.dart
- Cap 11.2 list albums: Host `listAssetSources` Full = built-ins +
  albumRegular + smart (Hidden/RD excluded); Limited = built-ins only;
  domain `AssetSource.displayName` + nullable `estimatedCount`;
  gateway maps album/smartAlbum (`other` still throws); work `95779ef`;
  notes `docs/acceptance/cap11-11.2-notes.md`
- Cap 11.3 resolve albums: Host `resolveSource` album/smartAlbum
  (creationDateDescending, image|video); Limited → unauthorized;
  missing collection → albumUnavailable; empty list = Empty;
  `ItemOrderingPolicy.forKind` aligned; debug probe cache `2cf26a6`;
  notes `docs/acceptance/cap11-11.3-notes.md`
- Cap 11.4 resolvePool: `lib/domain/source/resolve_pool.dart`,
  `resolved_pool_snapshot.dart`, `source_resolve_attempt.dart`,
  `source_resolve_status.dart`; sequential first-appearance coalesce;
  work `44b783e`
- Cap 11.5 composition: `source_resolve_attempt_mapping.dart` +
  library_smoke Photos+All `resolvePool` probe; Main Browse unchanged;
  architecture guard `main_browse` ↛ `resolve_pool.dart`; work `8e37b64`
- Cap 11.6 device coalesce: Photos+All `C=A`, All `contrib=V`; Kafka
  Full/Limited + iPhone 17 Full PASS; notes
  `docs/acceptance/cap11-11.6-notes.md`
- Source Pool Definition (Cap 10 / ADR-020):
  `lib/domain/source/source_pool_definition.dart`,
  `persistence_policy.dart`, `pool_capacity.dart`,
  `item_ordering_policy.dart`; `SourceReference` + `AssetSourceKind`
  (album/smartAlbum); work kinds `8c99d46` / SPD `6aa35dc` / ordering `954d7e0`
- Playback / display: lib/domain/playback/, lib/platform/playback_gateway.dart;
  PhotoLibraryApi.requestPreview (Cap 14.2 `393ebc9` / ADR-025 Layer 1,
  local-only still + video poster, cancellable);
  PhotoLibraryApi.requestDisplayAsset / requestPlayableVideo (Cap 14.3
  `ce8807f` / ADR-025 Layer 2 current item: network allowed + cancel;
  never `iCloudDownloadRequired`; ADR-006 Status narrow supersede);
  Feed three-layer UI (Cap 14.4 `9cf22a5`): Layer 1 preview then
  current-item Layer 2; Layer 3 spinner Semantics; Retry overlay
  when a still remains; `mainBrowseFeedICloudOnly` retired;
  Feed ±1 neighbour `requestPreview` / `releasePreview` two-phase
  window (Cap 14.5 `fa09b00`);
  Item-load chrome bottom-right (Cap 14.6b `16ed6e3`: LIVE badge +
  Layer 2 / Live-prepare spinner; Cap 15.3 `4767ec4`: Layer 1-miss
  `_loading` uses the same `_FeedCornerChrome`; library resolve
  loading stays centered; Cap 15.4 `ce18a33`: join in-flight Layer 1
  on neighbour→current promote — L1 `_localGate`, L2
  `currentDisplayGate`);
  Cap 16 leave-cancel `cancelInFlightPrepare` (`d273358` / ADR-029)
  + one networked `load` (`df021b8`) + Dart dwell 500 ms
  (`6ca736f`); notes `docs/acceptance/cap16-16.5-notes.md`;
  PlaybackRepository.clearPlaybackPool (Cap 9.3 `afd3181` / ADR-019);
  debug probe: lib/features/library_smoke/playback_pipeline_probe.dart
- Live Photo motion: ios/Runner/Platform/LivePhotoApiHost.swift
  (viewType `waketok/live_photo_surface`); Pigeon LivePhotoApi /
  LivePhotoFlutterApi (Cap 9.2); Dart domain
  `lib/domain/live_photo/` + `LivePhotoGateway` +
  `livePhotoRepositoryProvider` (Cap 9.3 `afd3181`); Feed play-once +
  `LiveHostOpSerial` (Cap 9.4 `c86dd6e`); preparing spinner +
  `gatedFlagUpdate` (Cap 9.5 `042c59d`); 14.6b `16ed6e3` moves badge
  + preparing spinner to bottom-right (UX-2 closed); `sharedMuteProvider` + mute
  re-apply (Cap 9.6 `8c0f4ca`); video host mute persist (Cap 9.7
  `4aa93b0` / ADR-019)
- Presentation Metadata: lib/domain/presentation/,
  PhotoLibraryApi.requestPresentationMetadata /
  requestPresentationFileSize (Cap 8.3 `c0c04e1` / ADR-015; Live still
  size ADR-018); Overlay + dual-gate + session cache: Cap 8.5 `4f4c825`
  (`lib/features/main_browse/media_info_overlay.dart`,
  `feed_activation_coordinator.dart`); provider:
  lib/features/library_smoke/presentation_providers.dart
- Errors / Result: lib/core/errors/, lib/core/result/ (ADR-008); ErrorCode mapping in lib/platform/error_code_mapping.dart
- Architecture boundaries: ADR-009 + ADR-010 + ADR-012 + test/architecture/ guard tests
- Cap 12 Session Configuration: `lib/domain/session/` —
  OrderPolicy / AdvanceMode / RepeatPolicy + SessionConfiguration
  (`f53d455`); DefaultSessionProfile + classify/derive (`ba81abc`,
  DPR-1…7; Cap 12 always generalMixed); SessionQueue +
  buildSessionQueue Sequential (`77571a9`); Cap 13.2 Shuffle
  (`f0187b4`, SHUF-1…7; Cap 12 UnsupportedError removed);
  architecture guard main_browse ↛ build_session_queue (`a14d748`)
- Cap 12.1 contract: ADR-022 Accepted (D1–D6=A) — Sequential Session
  Queue + Default Profile domain; derive ≠ apply was Cap 12; Cap 13.4
  (`10a5735`) applied Mixed → Shuffle on Main Browse (ADR-023 /
  ADR-014 Decisions 2–3 superseded); segmentIndex = Generated Clip
  resolve-time (D5); OrderPolicy includes shuffle (Cap 13.2
  implements construction); D9 seam: `main_browse` still ↛
  `build_session_queue` / `resolve_pool` (wiring in `lib/app/browse/`)
- Cap 12.6 acceptance: unit-only (no device PoC); full `flutter test`
  PASS (+247) at HEAD `6127b44`; no `docs/acceptance/cap12-12.6-notes.md`
- Cap 13.1 contract: ADR-023 Accepted (D1–D9=A, anchor `f0187b4`) —
  Endless Shuffle + Queue Stability + in-session Continuity; Main
  Browse Mixed → Shuffle product apply landed 13.4 (`10a5735`); slim
  ConsumptionSession; Manual Shuffle = full Snapshot; playhead debt
  reclassified Accepted Cap 13.5 (not bug-fix; row kept); tab = new Session;
  13.6 closed under ADR-030 §5 (everyday availability, 2026-08-19),
  not Instruments V-hard
- Cap 13.2 Endless Shuffle: `buildSessionQueue` Fisher–Yates +
  injectable Random + `previousRoundLastId` first≠last retries;
  work `f0187b4`
- Cap 13.3 Continuity: `lib/domain/session/consumption_session.dart`
  — slim in-memory session; `startConsumptionSession` /
  `applySessionConfiguration` (Order rebuild + asset-id remap;
  Advance/Repeat config-only); no Checkpoint / browse history;
  work `78f6d9d`
- Cap 13.8 Browse empty / failure feed:
  `lib/app/browse/browse_session_providers.dart` (`_snapshotFor` caches
  only when there is no hard failure **and** the coalesced list is
  non-empty; Cap 14.6 `37821ec` keeps resolve-loading on successful
  empty and re-resolves 3 extra times at 500/1000/2000 ms;
  `7329081` skips resume auth invalidate while `requestAccess` is in
  flight and `restartSession` after Limited/full grant) +
  `lib/features/main_browse/vertical_media_feed.dart`
  (empty ids with `unauthorized` / `unavailable` status →
  resolve-failed panel + Retry, not empty copy); work `1f8a240` /
  ADR-024; 14.6 Kafka Profile PASS
- ADR-001 … ADR-031: docs/DECISIONS.md (ADR-031 Cap 15 Layer 1→2
  handoff polish — **Accepted**, anchor `4767ec4`; ADR-030 retires Instruments
  numeric hitch/hang gates — **Accepted**, anchor `740bd99`; ADR-029
  Cap 16 cancel and dwell current-item Layer 2 — **Accepted**,
  anchor `d273358`; ADR-028
  default Fit +
  portrait-only — **Accepted**, anchor `24debf4`; ADR-027 Cap 14.4e leave Browse
  ends Consumption Session — **Accepted**, anchor `fe660dd`; ADR-026
  Cap 14.4d foreground video item-loop + return-to-ended replay —
  Accepted, anchor `8189543`; ADR-025 Cap 14 current-item iCloud fetch
  — Accepted, anchor `393ebc9`; ADR-024 Cap 13.8 Browse Snapshot cache
  — Accepted, anchor `1f8a240`; ADR-023 Cap 13 Endless Shuffle —
  Accepted, anchor `f0187b4`; ADR-022 Cap 12 Session Queue Accepted,
  anchor `f53d455`; ADR-021 Cap 11 Live Resolution Accepted, anchor
  `95779ef`; ADR-020 Cap 10 models Accepted)
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
- Acceptance notes (Cap 15.5 closed `6c7d3de`; Round 4 PASS;
  261/354 historical only; S2≈334 pre-existing iCloud overlap):
  docs/acceptance/cap15-15.5-notes.md
- Acceptance notes (Cap 15.6 closed `52e775c`; Protocol B Full/Limited
  preview-tier model; debt 400 open):
  docs/acceptance/cap15-15.6-notes.md
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
  VerticalMediaFeed / PageController; 14.4c `6178f9e`)
- (grows as fragile areas appear)

## Known debt / intentionally deferred
| Capability | Item | Reason | Picks it up | Related ADR |
|---|---|---|---|---|
| Main Browse Screen | Release build Severe Hang / hitch on production feed (Kafka) | Accidental Release campaign V-hard FAIL (`cap7-7.7-notes.md`); **7.7a Profile PASS**. Evidence strength: **All** surface clean **3/3 FAIL (Release) → 3/3 PASS (Profile)** is a strong signal the mode divergence is real (not a one-off flip); **Videos** was already 2/3 PASS on Release (intermittent), so weaker as a divergence signal. Track for shipping; do not deep-dive cause here | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-001 / ADR-014 |
| Media Info Overlay | Location Label (reverse geocode) not implemented | Owner Cap 8 Q1=B: Overlay row 4 hidden when empty this Cap (kickoff ADR-X best-effort deferral; no geocode). Current-Item-only geocode hard rule unchanged when a later Cap picks this up | Later Cap (or reopen when Owner schedules) | kickoff ADR-X |
| Media Info Overlay | Same-asset playhead shared across built-in sources (All ↔ Videos) — **Accepted behaviour** | First observed Cap 8.8 (`cap8-8.8-notes.md`): `PlaybackApiHost` keys the app-scoped player by `assetIdentifier` (ADR-006), so the same Photos id under All vs Videos reuses position / ended-on-last-frame. **Accepted (ADR-023 D6 / Cap 13.5)** — intentional Host keying, **not** a bug fix and **not** cross-tab Continuity (D8: tab = new Session; feed index still resets). No `PlaybackApiHost` change. **Row kept** (not deleted like resolved bugs) as a permanent record of accepted behaviour to prevent re-litigation when the shared playhead is noticed again. | Closed by Cap 13.5 (ADR-023 D6) | ADR-006 / ADR-014 / ADR-023; `docs/acceptance/cap8-8.8-notes.md` |
| Media Info Overlay | File-size disclaimer copy (kickoff ADR-W §5) unset | Size is logical resource bytes — not device disk / iCloud quota / optimized-local / immediate free-on-delete. iCloud-only blank size **before** local data exists is ADR-015/018 (never download solely for size; Photos Info is not a public-SDK ground truth). Same-page refresh after Layer 2 landed `900581e`. Not an eng Decision gap; needs user-visible copy landing | Settings and localisation completion (or Cap 8.5/8.6 if a short on-media note is added) | kickoff ADR-W |
| Main Browse Screen | First cold start: All current item fails until Retry because the 无线数据 dialog appears after Layer 2 has already been issued | China-SKU app-level first-network prompt (国行 App Store vs NZ: Photo-App-A same split). Dart `HttpClient` pre-feed probe does **not** trigger it. Lifecycle auto-retry landed `eddb7c3`. Kafka first-launch retest still pending. | Later Cap / owner device confirm; native `URLSession` pre-trigger is a separate optional row | ADR-025 |
| Main Browse Screen | Optional native `URLSession` (CFNetwork) pre-feed to show 无线数据 on the loading screen instead of after first Layer 2 fail | Dart sockets do not trip the China-SKU prompt. Not required for doom-scroll once B auto-retries (`eddb7c3`). Photo-App-A 国行 still shows the prompt in the feed. | Later Cap / optional | ADR-025 |
| Main Browse Screen | **Leave-current did not stop PhotoKit iCloud video materialization; Browse continuously fills device storage; cannot reclaim from the system Photos library** | User-visible, independent of hitch. Optimize iPhone Storage **on** still loses: download rate beats system reclaim. 2026-08-18 replication: Videos V1 ~75 s, wait only first+last iCloud videos to play, flick the rest on cover → disk **200.2 → 207.38 GB (~+7 GB)**. Two watched videos ≠ +7 GB. WakeTok JPEG temps are bounded; growth is Photos library cache. **16.2** leave-cancel (`d273358`); **16.3** one networked `load` (`df021b8`; `requestPlayableVideo` is duration-only); **16.4** dwell 500 ms (`6ca736f`). **16.5** (`docs/acceptance/cap16-16.5-notes.md`): no-Instruments Videos **+0.18 GB** / All **+0.02 GB** PASS vs that leak. Instruments GB is **系统数据 / purgeable**, not Settings 照片 (idle attach ~+1.8 GB System Data; Photos 10.17→10.16 across reboot). Do **not** rewrite the 13.6 +7.18 GB as 100% Instruments (product cancel was also missing then). A late `cancel` after leave may still let A briefly enter prepare (not proven zero disk). App has **no public API** to delete Photos-library downloads (kickoff forbids an app-owned persistent media cache). Reclaim = iOS idle / reboot. **Second 13.6 gate-foundation defect** (Cap 14 was the first) — **product leak path paid by Cap 16**; 13.6 closed under ADR-030 §5 (everyday availability), not another 25 ms/s retest. | Closed by Cap 16 (ADR-029); 13.6 closed ADR-030 | ADR-025 D4 / ADR-029 / ADR-006 |
| Main Browse Screen | Tab leave does not cancel `PlaybackApiHost.prepareActive` iCloud video download | **Closed by 16.2** (`d273358`): `cancelInFlightPrepare` on leave current / dispose / leave Browse, including same-id. Dwell landed in 16.4 (`6ca736f`). 16.5 measured no-Instruments storage PASS; remaining Instruments GB is System Data (notes), not missing leave-cancel. | Closed by Cap 16.2 (ADR-029) | ADR-025 D4 / ADR-029 / ADR-006 |
| Main Browse Screen | Profile/Debug may prompt Local Network (“查找本地网络中的设备”) before Photos | Flutter observatory / mDNS, not product PhotoKit. Release expected not to show it. | Do not fix in product; observe on Release | — |
| POC-03 | WeChat/VoIP interrupt: no auto-resume on lock screen or iOS home without opening app | Q1=B: 3.3 PASS when shouldResume + poll/foreground resumes; suspended lock/home path deferred | Production Background Audio | ADR-002 |
| POC-03 | Real physical-clip integration after POC-09 (≥3 exported clips locked queue) | Bundle WAV proved service shape only; confirm Photos-backed segments, order, Now Playing, no Dart per transition | Production Background Audio (prerequisite: Generated Clip Source available after Physical Clip Export Core + Photos import) | ADR-002 |
| POC-03 | iCloud Asset download interrupt during background audio | P2=A: out of POC-03 scope | Production Background Audio | ADR-002 |
| POC-09 | Slow-motion frame-rate / audio-pitch beyond duration gate | 9.3 passed duration only | Physical Clip Export Core | ADR-004 |
| POC-09 | Multi-audio-track selection UX | 9.4 default track only | POC-07 | ADR-004 |
| App Foundation | iOS 18 simulator smoke (no 18.x runtime installed) | Floor is 18.0 (ADR-007); day-to-day verify on 26.x only | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-007 |
| App Foundation | Localization Inventory auto-generation/report tooling (kickoff ADR-U §7–8 summary artifact) | Hardcoded-copy scan + ARB key parity closed by ADR-012; Inventory report generator still deferred | Settings and localisation completion | — (kickoff ADR-U) / ADR-012 |
| App Foundation | App icon asset set | Owner parallel track; required before first TestFlight build upload | TestFlight internal testing | — |
| Portfolio | Repository visibility: Private → Public (eligibility: first demoable vertical slice — Main Browse feed scrolls real Photos library content on device) | Cap 7 closed — eligibility met. Before Private→Public, owner must complete the pre-public privacy/sensitive-history scan checklist (local release-handoff); Cursor reminds only and must not run the scan. | Owner pre-public scan (any time after Cap 7) | — |
| iOS Photos permission | NSPhotoLibraryUsageDescription is PLACEHOLDER copy | Final permission wording is owner-only (release-handoff) | TestFlight internal testing | — |
| iOS Photos permission | Limited Access product chrome unmounted from Main Browse (`eb4473f`) | Banner sat above IndexedStack (all four tabs) and the shell Column had no SafeArea (notch clipped it). **Removed the product mount, not the feature.** Final form TBD at Settings: persistent in-Settings entry + whether to remind on each launch. Until then, **Release/Profile users have no in-app button or entry** to present the Limited picker (`presentLimitedLibraryPicker`) or Open Settings after a Limited grant — changing access is only via iOS Settings, unrelated to WakeTok UI. Kickoff ADR-K §3 (explicit prompt + system path to Full) is unmet in this window; no compensatory prompt. Future designs must not block or interfere with system gestures (app switcher / Home). Debug `library_smoke` may still show the widget (`kDebugMode` only). | Settings and localisation completion | kickoff ADR-K |
| iOS Photos permission | List-time availability via undocumented PHAssetResource KVC `locallyAvailable` | No public isLocallyAvailable on PHAsset/PHAssetResource in the iOS SDK. Host uses KVC **list-time only** (`PhotoLibraryService.mapAvailability`). **Cap 15.10 v1** does **not** adopt this for feed become-current skip-L1 — product path = Session L2-ready memory on **revisit** only. Expanding KVC to feed gating requires explicit owner re-board of this row. | Final hardening (or Cap 15.10+ if re-scoped) | — |
| Cap 6 / library_smoke | Library Totals Shell error row uses raw exception string (`'${asyncTotals.error}'`), not ARB | Predates ADR-012 smoke hardening; Cap 6.4 left untouched on purpose | Settings and localisation completion | ADR-012 |
| Main Browse Screen | No architecture scan for hardcoded `TextStyle(` in `lib/features/**` (typography tokens exist; `Color(0x` still scanned) | Cap 7.2 locked type roles without a TextStyle literal guard; easy to bypass tokens while 7.4–7.7 chrome lands | Settings and localisation completion | ADR-009 / ADR-014 |
| Main Browse Screen | Video page swipe may flash the previous video — **with audio** (severity residual) | Shared 1+1 AVPlayer + single Platform View (ADR-006). **Severity raised (Kafka 2026-08-22, after 15.7):** when both pages are local / already playable, peek still shows the next poster (15.7 PASS), but on **full settle** the shared surface can continue the **previous** item’s picture **and sound** for a few frames (same progress), then snap to the correct item. **15.8:** still open (`cap15-15.8-notes.md`). **15.10 device (`750ddd6`, `cap15-15.10-notes.md`):** local→local Videos — peek poster OK, then **peek-phase black gap** (empty surface, distinct from settle wrong-A/V); settle ~0.5 s previous picture+audio (393 still open). Same ADR-006 pool family as Cap 7.7 observe-only / 13.6b ghost-frame notes. **393 explore PAUSED** — redefine scope (**peek + settle**) before resume; do not resume on pre-pause explore doc alone. Explore path: Dart mask+mute±attach-ack (`cap15-debt393-explore-scope.md` — **stale scope** until peek phase added); overturn Q3=B only if explore fails (**owner re-board**). Do not close from “not seen this run.” | 393 explore after scope redefine | ADR-006 / ADR-031 |
| Main Browse Screen | Local / L2-ready items still blur-first on revisit (Session) | **Closed by 15.10** (`750ddd6`): Session L2-ready token skips Layer 1 on revisit; still sharp / video poster-until-play. Kafka PASS (`cap15-15.10-notes.md`). **v1 revisit only** — no list-time KVC on become-current (STATE `locallyAvailable` row unchanged). | Closed by Cap 15.10 | ADR-025 |
| Main Browse Screen | Local Layer 2 completing during a swipe exposes a Layer 1→2 handoff gap (stills and video); consecutive iCloud items stay on Layer 1 and do not flash | Trigger: on-device Layer 2 returns inside the scroll animation; iCloud Layer 2 is slow so the page keeps the preheated Layer 1. **Stills:** **Closed by 15.5** (`6c7d3de`) for local still→still gapless. **Video peek-black (leave-side poster loss):** **Closed by 15.7** (`b21b9fc`) when L1 poster exists. **Revisit blur-first when L2-ready:** **Closed by 15.10** (`750ddd6`). **15.10 cross-ref:** entering-peek **black gap after blur poster** during swipe — residual under 393 / handoff-gap tracking; **does not reopen** 15.7 closed status. **Video settle wrong A/V:** debt **393** (still open; explore paused). **400** unchanged. | 393 explore after scope redefine | ADR-006 / ADR-025 / ADR-031 |
| Main Browse Screen | Swiping back to a video restarts from 0 after the next item has taken the active 1+1 slot; mid-play resume still happens while that slot is not yet taken | Pool is current + next only; no session-level playhead. Next local almost always occupies `activePlayer` immediately → return rebuilds a new player at 0. Next iCloud occupies only after `requestAVAsset` completes → return before that hits ADR-026 `playOnly` (same live player). **MVP accepts restart-from-0 once the next item has occupied the slot.** That acceptance does **not** mean “always restart on leave”, and must **not** weaken ADR-026 (`actionOnBecomeCurrent`: seek 0 only when at-end; mid-play re-enter `play()` while the player still exists). Do not add session playhead storage in Cap 14. | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-006 / ADR-026 |
| Main Browse Screen | Becoming current can bump display generation twice (`_activateCurrentItem` in the feed-index listen + `_beginCurrentItemActivation` in build), so Layer 2 may fire twice | **Closed by 15.4** (`ce18a33` / ADR-031 D8): join in-flight Layer 1 on neighbour→current promote; no second `requestPreview` on the same id (`preview_supersede`). Kafka M1+2: zero supersede on five miss `page_changed`; one `layer2_load_start` each. W-15.4 widget tests. | Closed by Cap 15.4 (ADR-031) | ADR-025 / ADR-010 / ADR-031 |
| Main Browse Screen | Browse→Settings→Browse while a video is playing flashes one poster frame | **Dissolved by 14.4e** (`fe660dd`): leave Browse ends the Session and returns at queue head, so the 14.4c keep-alive mid-queue resume path is gone. Remaining wait chrome after leave is the Layer 1 cold-start row below, not this poster flash. | Closed by Cap 14.4e (ADR-027) | ADR-006 / ADR-025 / ADR-027 |
| Main Browse Screen | Leave Browse (Settings/Clips/Auto) then return: queue-head page may show black + gold spinner with no Layer 1 still/poster | **Closed by 15.3** (`4767ec4` / ADR-031 Q2): same `_loading` miss chrome as 399, now `_FeedCornerChrome` not centered. Black wait until Layer 1 still exists (ADR-025); 14.4e remount at index 0 can still land on a miss head (Shuffle). Kafka 2026-08-20 device: miss = corner spinner; library loading still centered. | Closed by Cap 15.3 (ADR-031) | ADR-025 / ADR-027 / ADR-031 |
| Main Browse Screen | Layer 1 miss (`_loading`) still uses a **centered** brand-gold spinner (`mainBrowseFeedPageLoading`); 14.6b only moved Layer 2 / Live-prepare chrome to bottom-right when a still/poster already exists | **Closed by 15.3** (`4767ec4` / ADR-031 Q2): miss page is `feedBackground` + `_FeedCornerChrome`; no delay-before-show; new ARB `mainBrowseFeedLayer1Loading`. Library resolve `mainBrowseFeedLoading` stays centered. Kafka device PASS. UX-1 (402) not in this close. | Closed by Cap 15.3 (ADR-031) | ADR-025 / ADR-019 / ADR-031 |
| Main Browse Screen | iCloud / optimized-storage **video**: no Layer 1 poster — full-page black + spinner until Layer 2 plays; ±1 peek often stays black | **15.6 partial (`52e775c`):** Host box **512×512** (was 1080). Raises **Limited** local-hit odds when a derivative near the box exists (Session B: 13×512-edge ok). **Does not** explain Full never-black: Protocol B same 16 ids under Full → 16/16 ok all **~120**, 0 miss — **inferred** Full opportunistic fallback to a fixed small thumb tier; Limited searches by `targetSize` without that fallback (`cap15-15.6-notes.md`). Limited residual miss (3/16 in B) can still lack any deliverable local image under Limited while Full has ~120 — PhotoKit authorization behavior under ADR-025 local-only; Host cannot invent pixels. Unvalidated trial: `deliveryMode = .fastFormat`. Product miss UI = separate discussion. Original Limited 6-video set (2026-08-18) still applies as early evidence. | Cap 15.8 owner table (formal debt 400 close); optional `.fastFormat` experiment / Limited miss UI phase | ADR-025 / ADR-006 / ADR-031 |
| Main Browse Screen | Lock then unlock on Manual Browse while a video is current: same index/frame, paused, no tap-to-play — swipe is the only escape | ADR-006 Cap 7.3: background detach + pause; foreground re-adopts the layer and does **not** `play()`. Dart lifecycle retries failed Layer 2 only. Correct interim vs lock-screen **audio** continue. Missing Manual tap-to-pause/resume (center affordance) is a Browse gesture gap, **not** Auto-play / Background Audio. | Share, Mute, Fit / Fill / 9:16 Crop, 2x gesture, tap-to-pause/resume (non-workspace-area tap toggles play/pause with a center play/pause affordance) | ADR-006 |
| Live Photo (Cap 9.7) | Offline/weak-net iCloud Live: preparing spinner may be zero-duration (fail too fast) | POC-08 #5/#6 PASS with static fallback; owner wants later brief visible spin-then-fail so users see “needs network” (not progress-copy / Waiting for Media) | Live chrome / iCloud feedback polish | ADR-019; `cap9-9.7-poc08-notes.md` UX-1 |
| Live Photo (Cap 9.7) | LIVE badge + preparing spinner top-left overlaps status-bar time | **Closed by 14.6b** (`16ed6e3`). Badge + item Layer 2 / Live-prepare spinner share `_FeedCornerChrome` at bottom-right; Overlay `trailingInset` 123. Library resolve loading stays centered. Q7 play-once hide/show unchanged. Kafka Profile PASS. UX-1 untouched. | Closed by Cap 14.6b | ADR-019; `cap9-9.7-poc08-notes.md` UX-2 |
| Cap 13 (13.8) | **First launch right after granting Limited access shows an empty All tab and does not self-heal** | **Closed by 14.6** (`37821ec` + `7329081`). Bounded re-resolve on successful empty remains; Kafka showed the empty All was started by resume `currentStatus()=.limited` **before** `requestAuthorization` completed. Skip that invalidate while `requestAccess` is in flight, then `restartSession` when the grant completes. Kafka Profile: loading then selected media, not empty copy. ADR-024 empty-not-cached remains as tab-switch backup. | Closed by Cap 14.6 (ADR-025 D8 + grant-complete restart) | ADR-025 / ADR-024 / ADR-014 / ADR-021 |
