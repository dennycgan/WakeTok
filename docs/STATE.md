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
- [x] Feed swipe Layer 1→2 handoff polish and
      duplicate current-item Layer 2 request
      (Cap 15 / ADR-031…033; work through `3fe9dd9`;
      393 closed; notes `docs/acceptance/cap15-*.md`)
- [x] Cancel and dwell current-item Layer 2 fetch
      (Cap 16 / ADR-029 Accepted, work `d273358`; notes
      `docs/acceptance/cap16-16.5-notes.md`; **second** 13.6
      foundation paid on the product path; 13.6 closed under
      ADR-030 everyday availability, not an Instruments Pass)
- [ ] <-- YOU ARE HERE: Main Browse Layer 1→2 chrome and iCloud
      availability hardening (Cap 17).
      Wait-feedback by expected duration (not in-flight bool);
      revisit spinner (L2-ready vs display/preview temp budgets);
      debt 400 wait presentation (accept black, improve visibility;
      scheme after diagnosis); iCloud fetch-path audit and
      observability (explainable wait + measurable improvement;
      no promise to match competitors; must not regress Cap 16
      storage discipline). Debt-first while Cap 15 Layer1/2 +
      probe context is hot; owner accepts no pause during Cap 17
      (everyday use starts at Build a Pool).
- [ ] Main Browse playback controls and gesture arbitration
      (Cap 18). Six-gesture contract defined once
      (swipe / tap / long-press / pinch / 2x / progress-drag);
      this Cap implements swipe + tap + progress-drag only.
      Tap pause/resume; dual-signal play model (user intent ×
      system permission — Background Audio later changes only
      the permission predicate). Scrubber. Does **not** define
      lock-screen continue-audio; **does** define unlock
      return-to-foreground paused resume path (Known debt 402):
      Manual Browse leave-foreground writes user intent → pause
      so unlock matches user-tapped-pause; center affordance +
      tap-to-resume is the Cap 18 tap pause/resume deliverable
      (no Now Playing / no background keep-alive). Long-press /
      pinch / 2x reserved for Caps 19 / 20 / Share-Mute-Fit
      respectively.
- [ ] Add to Album (Full Access only) (Cap 19).
      Owner 2026-08-24 advanced before Build a Pool; no longer
      the pre-authorized downgrade-to-1.1 exit. Long-press hangs
      on Cap 18 gesture-contract slot.
- [ ] Display magnification (pinch to zoom, lightweight)
      (Cap 20). Still: persistent zoom + Reset; video: tends
      non-persistent (release → fit). Exact form refined at Cap
      kickoff; pinch slot reserved in Cap 18 gesture contract.
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
      (tap-to-pause/resume moved to Cap 18; 2x hangs on Cap 18
      gesture-contract slot — implement in this capability)
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
Active capability: Main Browse Layer 1→2 chrome and iCloud
availability hardening (Cap 17)

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.
> Phase Roadmap is set by the owner before work begins on each capability.
> When YOU ARE HERE moves, do not generate Phase Roadmap content without
> explicit owner approval of the phases. An explicit awaiting-scope placeholder
> is allowed at Cap close-out (see state-decisions-maintenance).
>
> Owner 2026-08-24: Cap 17 phases frozen (diagnosis-first; Cap 15
> probe style — probes not committed). Cap 18–20 ordered after Cap 17
> and before Build a Pool. Do not use “Doom Scroll” in capability
> names / ADRs / identifiers.

- [x] 17.1 Diagnosis (Cap 15 diagnosis-before-contract pattern).
      Wait-feedback duration (Track A); iCloud fetch observability
      (Track B Full+Limited); debt 400 derivative tiers Full/Limited
      × opportunistic/`.fastFormat` (Track C). Evidence
      `docs/acceptance/cap17-17.1-notes.md`. Probes **never
      committed**.
- [x] 17.2 Contract freeze — ADR-034 **Proposed** (no Accepted date;
      no fake anchor until first Cap 17 work commit, expected 17.3).
      Wait-feedback by path-class / duration band (a4 T chosen in 17.3
      from Full 65/108/13); debt 400 accept residual black + visibility
      (no production `.fastFormat`); iCloud bar explainable +
      observable (ok / deduped cancel / fail / prog; a2 latency proxy
      not a hard p90 gate); Cap 16 invariants hard. Inputs: 17.1 notes.
- [ ] 17.3 Layer 1→2 handoff chrome unification (local peek spinner
      residue + revisit spinner; same root / same phase: L1/L2
      handoff, L2-ready, display/preview temp eviction,
      `_layer2InFlight` chrome conditions).
- [ ] 17.4 debt 400 wait-state presentation.
- [ ] 17.5 iCloud fetch-path optimization (under 17.2 invariants).
- [ ] 17.6 Device acceptance + residual triage.
      Absorb only residuals strictly in the Main Browse foundation
      loop; do not expand to pool / clips / autoplay.
- [ ] 17.7 Cap close-out.

## Now working on (describe ONLY the in-progress item)
- Goal (one line): Cap **17.3** path-class wait chrome (ADR-034
      Proposed; Accepted after this phase’s work commit)
- Sub-steps done: Cap 17.1 notes (`73025b4`); Cap 17.2 ADR-034
      Proposed (this docs commit)
- Next step: implement path-class × duration-band chrome per ADR-034
      Decision 2 (choose a4 T from 17.1 Full distribution + Kafka/i17
      notes); land Decision 8 unit/widget tests incl. a1 regression
      lock. Do not start 17.4/17.5 until 17.3 work is accepted.
- Related decisions: ADR-025; ADR-029; ADR-031…034; Cap 16 storage
      discipline; Known debt Host-temp/L2-ready + 400 + 403 → Cap 17;
      402 → Cap 18

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
- ADR-034: Cap 17 wait chrome / debt 400 / iCloud observability —
  **Proposed** (no Accepted date; no fake anchor; expected Accepted
  after 17.3 work commit)
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
- Acceptance notes (Cap 17.1 diagnosis closed; Tracks A/B/C; probes
  never committed):
  docs/acceptance/cap17-17.1-notes.md
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
| Main Browse Screen | First cold start: All current item fails until Retry because the Cellular Data system prompt appears after Layer 2 has already been issued | China-SKU app-level first-network prompt (mainland China App Store vs NZ: Photo-App-A same split). Dart `HttpClient` pre-feed probe does **not** trigger it. Lifecycle auto-retry landed `eddb7c3`. Kafka first-launch retest still pending. | Later Cap / owner device confirm; native `URLSession` pre-trigger is a separate optional row | ADR-025 |
| Main Browse Screen | Optional native `URLSession` (CFNetwork) pre-feed to show the Cellular Data prompt on the loading screen instead of after first Layer 2 fail | Dart sockets do not trip the China-SKU prompt. Not required for everyday feed swipe once B auto-retries (`eddb7c3`). Photo-App-A on China SKU still shows the prompt in the feed. | Later Cap / optional | ADR-025 |
| Main Browse Screen | **Leave-current did not stop PhotoKit iCloud video materialization; Browse continuously fills device storage; cannot reclaim from the system Photos library** | User-visible, independent of hitch. Optimize iPhone Storage **on** still loses: download rate beats system reclaim. 2026-08-18 replication: Videos V1 ~75 s, wait only first+last iCloud videos to play, flick the rest on cover → disk **200.2 → 207.38 GB (~+7 GB)**. Two watched videos ≠ +7 GB. WakeTok JPEG temps are bounded; growth is Photos library cache. **16.2** leave-cancel (`d273358`); **16.3** one networked `load` (`df021b8`; `requestPlayableVideo` is duration-only); **16.4** dwell 500 ms (`6ca736f`). **16.5** (`docs/acceptance/cap16-16.5-notes.md`): no-Instruments Videos **+0.18 GB** / All **+0.02 GB** PASS vs that leak. Instruments GB is **System Data / purgeable**, not Settings Photos (idle attach ~+1.8 GB System Data; Photos 10.17→10.16 across reboot). Do **not** rewrite the 13.6 +7.18 GB as 100% Instruments (product cancel was also missing then). A late `cancel` after leave may still let A briefly enter prepare (not proven zero disk). App has **no public API** to delete Photos-library downloads (kickoff forbids an app-owned persistent media cache). Reclaim = iOS idle / reboot. **Second 13.6 gate-foundation defect** (Cap 14 was the first) — **product leak path paid by Cap 16**; 13.6 closed under ADR-030 §5 (everyday availability), not another 25 ms/s retest. | Closed by Cap 16 (ADR-029); 13.6 closed ADR-030 | ADR-025 D4 / ADR-029 / ADR-006 |
| Main Browse Screen | Tab leave does not cancel `PlaybackApiHost.prepareActive` iCloud video download | **Closed by 16.2** (`d273358`): `cancelInFlightPrepare` on leave current / dispose / leave Browse, including same-id. Dwell landed in 16.4 (`6ca736f`). 16.5 measured no-Instruments storage PASS; remaining Instruments GB is System Data (notes), not missing leave-cancel. | Closed by Cap 16.2 (ADR-029) | ADR-025 D4 / ADR-029 / ADR-006 |
| Main Browse Screen | Profile/Debug may prompt Local Network (“Looking for devices on the local network”) before Photos | Flutter observatory / mDNS, not product PhotoKit. Release expected not to show it. | Do not fix in product; observe on Release | — |
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
| iOS Photos permission | List-time availability via undocumented PHAssetResource KVC `locallyAvailable` | No public isLocallyAvailable on PHAsset/PHAssetResource in the iOS SDK. Host uses KVC in `mapAvailability`. **Cap 15.12 / 15.15 (ADR-033):** become-current may call `getAssetAvailabilities` (on-demand; resolve returns empty availabilities). Same KVC helper for probed ids only. **Further expansion** of KVC beyond this gate still needs explicit owner re-board. | Future Cap if expanding | ADR-033 |
| Cap 6 / library_smoke | Library Totals Shell error row uses raw exception string (`'${asyncTotals.error}'`), not ARB | Predates ADR-012 smoke hardening; Cap 6.4 left untouched on purpose | Settings and localisation completion | ADR-012 |
| Main Browse Screen | No architecture scan for hardcoded `TextStyle(` in `lib/features/**` (typography tokens exist; `Color(0x` still scanned) | Cap 7.2 locked type roles without a TextStyle literal guard; easy to bypass tokens while 7.4–7.7 chrome lands | Settings and localisation completion | ADR-009 / ADR-014 |
| Main Browse Screen | Video page swipe may flash the previous video — **with audio** (severity residual) | **Closed by 15.11** (`c8a59b3` / ADR-032): `PvTransitionGuard` (entering-side cover + transition mute); unwrap on Host **`onPlaybackSurfaceReadyForDisplay`** (`AVPlayerLayer.isReadyForDisplay`), **not** attach-ack (attach observed `layerReady=false` in diagnosis — evidence in `cap15-15.11-notes.md`, not git). 15.11b: poster-hold + settle-on-target (cover release ≠ audio release) + stale feed-index re-arm fix. Kafka + i17 Profile PASS — `cap15-15.11-notes.md`. Peek black gap + settle wrong A/V both closed under 393 family. ADR-006 1+1 pool unchanged. | Closed by Cap 15.11 | ADR-006 / ADR-032 / ADR-031 |
| Main Browse Screen | Local / L2-ready items still blur-first on revisit (Session) | **Closed by 15.10** (`750ddd6`): Session L2-ready token skips Layer 1 on revisit; still sharp / video poster-until-play. Kafka PASS (`cap15-15.10-notes.md`). **v1 revisit only** — no list-time KVC on become-current (STATE `locallyAvailable` row unchanged). | Closed by Cap 15.10 | ADR-025 |
| Main Browse Screen | Session L2-ready revisit hit-rate limited by Host temp eviction (still corner spinner; preview/display budgets) | **(1) Symptom:** Stills that already reached sharp Layer 2 (incl. former iCloud downloads) may show ~0.5s bottom-right gold spinner on revisit before sharp again. **(2) Devices:** Clear on Kafka (large library, many iCloud); faint/acceptable on i17 (small, mostly local). **(3) Mechanism:** Cap 15.10 Session token + Cap 15.13 `lookupIfCoverOnDisk` invalidate when cover file is gone → DEVICE_LOCAL re-fetch L2 → `_layer2InFlight` chrome. **Still `stillFull` covers live in display store (≤1+1); video/peek posters mostly preview store (cap 3).** Structural tension: L2-ready assumes disk-resident covers vs small Host temps — not “cap=3 only.” **(4)** Same debt as “re-evaluate Preview/Display LRU”; Kafka 2026-08-24 evidence supports reassessing **both** budgets. Not a 15.14c regression. | Cap 17 (17.3 handoff chrome / temp budgets) | ADR-025; Cap 15.10/15.13; Cap 14.2 |
| Main Browse Screen | Local Layer 2 completing during a swipe exposes a Layer 1→2 handoff gap (stills and video); consecutive iCloud items stay on Layer 1 and do not flash | Trigger: on-device Layer 2 returns inside the scroll animation; iCloud Layer 2 is slow so the page keeps the preheated Layer 1. **Stills:** **Closed by 15.5** (`6c7d3de`) for local still→still gapless. **Video peek-black (leave-side poster loss):** **Closed by 15.7** (`b21b9fc`) when L1 poster exists. **Revisit blur-first when L2-ready:** **Closed by 15.10** (`750ddd6`). **Entering-peek black gap + settle wrong A/V (393):** **Closed by 15.11** (`c8a59b3` / ADR-032). **400** unchanged. | Closed by Cap 15.11 (393 limb) | ADR-006 / ADR-025 / ADR-032 |
| Main Browse Screen | Swiping back to a video restarts from 0 after the next item has taken the active 1+1 slot; mid-play resume still happens while that slot is not yet taken | Pool is current + next only; no session-level playhead. Next local almost always occupies `activePlayer` immediately → return rebuilds a new player at 0. Next iCloud occupies only after `requestAVAsset` completes → return before that hits ADR-026 `playOnly` (same live player). **MVP accepts restart-from-0 once the next item has occupied the slot.** That acceptance does **not** mean “always restart on leave”, and must **not** weaken ADR-026 (`actionOnBecomeCurrent`: seek 0 only when at-end; mid-play re-enter `play()` while the player still exists). Do not add session playhead storage in Cap 14. | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-006 / ADR-026 |
| Main Browse Screen | Becoming current can bump display generation twice (`_activateCurrentItem` in the feed-index listen + `_beginCurrentItemActivation` in build), so Layer 2 may fire twice | **Closed by 15.4** (`ce18a33` / ADR-031 D8): join in-flight Layer 1 on neighbour→current promote; no second `requestPreview` on the same id (`preview_supersede`). Kafka M1+2: zero supersede on five miss `page_changed`; one `layer2_load_start` each. W-15.4 widget tests. | Closed by Cap 15.4 (ADR-031) | ADR-025 / ADR-010 / ADR-031 |
| Main Browse Screen | Browse→Settings→Browse while a video is playing flashes one poster frame | **Dissolved by 14.4e** (`fe660dd`): leave Browse ends the Session and returns at queue head, so the 14.4c keep-alive mid-queue resume path is gone. Remaining wait chrome after leave is the Layer 1 cold-start row below, not this poster flash. | Closed by Cap 14.4e (ADR-027) | ADR-006 / ADR-025 / ADR-027 |
| Main Browse Screen | Leave Browse (Settings/Clips/Auto) then return: queue-head page may show black + gold spinner with no Layer 1 still/poster | **Closed by 15.3** (`4767ec4` / ADR-031 Q2): same `_loading` miss chrome as 399, now `_FeedCornerChrome` not centered. Black wait until Layer 1 still exists (ADR-025); 14.4e remount at index 0 can still land on a miss head (Shuffle). Kafka 2026-08-20 device: miss = corner spinner; library loading still centered. | Closed by Cap 15.3 (ADR-031) | ADR-025 / ADR-027 / ADR-031 |
| Main Browse Screen | Layer 1 miss (`_loading`) still uses a **centered** brand-gold spinner (`mainBrowseFeedPageLoading`); 14.6b only moved Layer 2 / Live-prepare chrome to bottom-right when a still/poster already exists | **Closed by 15.3** (`4767ec4` / ADR-031 Q2): miss page is `feedBackground` + `_FeedCornerChrome`; no delay-before-show; new ARB `mainBrowseFeedLayer1Loading`. Library resolve `mainBrowseFeedLoading` stays centered. Kafka device PASS. UX-1 (402) not in this close. | Closed by Cap 15.3 (ADR-031) | ADR-025 / ADR-019 / ADR-031 |
| Main Browse Screen | iCloud / optimized-storage **video**: no Layer 1 poster — full-page black + spinner until Layer 2 plays; ±1 peek often stays black | **15.6 partial (`52e775c`):** Host box **512×512** (was 1080). Raises **Limited** local-hit odds when a derivative near the box exists (Session B: 13×512-edge ok). **Does not** explain Full never-black: Protocol B same 16 ids under Full → 16/16 ok all **~120**, 0 miss — **inferred** Full opportunistic fallback to a fixed small thumb tier; Limited searches by `targetSize` without that fallback (`cap15-15.6-notes.md`). Limited residual miss (3/16 in B) can still lack any deliverable local image under Limited while Full has ~120 — PhotoKit authorization behavior under ADR-025 local-only; Host cannot invent pixels. Unvalidated trial: `deliveryMode = .fastFormat`. Product miss UI = separate discussion. Original Limited 6-video set (2026-08-18) still applies as early evidence. | Cap 17 (17.1 diagnosis incl. `.fastFormat`; 17.4 wait presentation) | ADR-025 / ADR-006 / ADR-031 |
| Main Browse Screen | Lock then unlock on Manual Browse while a video is current: same index/frame, paused, no tap-to-play — swipe is the only escape | ADR-006 Cap 7.3: background detach + pause; foreground re-adopts the layer and does **not** `play()`. Dart lifecycle retries failed Layer 2 only. Correct interim vs lock-screen **audio** continue. Missing Manual tap-to-pause/resume (center affordance) is a Browse gesture gap, **not** Auto-play / Background Audio. | Cap 18 (tap pause/resume + unlock return-to-foreground paused path; not lock-screen continue-audio) | ADR-006 |
| Main Browse Screen | Asset-source iCloud load feels much slower than Photo-App-A / iOS Photos; bottom-right spinner is a half-dead-end wait state | **Suspect clues (verify later — not closed root causes; not Cap 15.11 scope).** **(A) Load speed:** Owner subjective + Cap 15.11 **session** log on Kafka (`/tmp/waketok_1511b_stale_idx.log`, 2026-08-23): many items stayed blurry / non-playing while Photo-App-A in the same window eventually loaded; log skew `load-finished err=ok` ≈168 vs `operationCancelled` ≈417, **0** `iCloudDownloadFailed`. Suspect aggressive leave/remount/supersede cancel + single-flight prepare vs competitor / Photos keep-or-parallel download — **deep-dive WakeTok iCloud network + cancel policy** when scheduled; no attribution without further evidence. **(B) Wait-state UX:** item-level `_FeedCornerChrome` spinner gives **no progress signal** during long iCloud Layer 2 (throughput, bytes, ETA, retry affordance beyond corner Retry chrome — **details TBD**). User can only wait or swipe away; poor even if absolute download time unchanged. Independent of 393/handoff fix (Kafka + i17 A↔B PASS `c8a59b3`). | Cap 17 (17.1/17.5 fetch-path; wait UX via 17.2/17.4 — explainable + observable, not match-competitors) | ADR-025 / ADR-029 / ADR-006 |
| Live Photo (Cap 9.7) | Offline/weak-net iCloud Live: preparing spinner may be zero-duration (fail too fast) | POC-08 #5/#6 PASS with static fallback; owner wants later brief visible spin-then-fail so users see “needs network” (not progress-copy / Waiting for Media) | Live chrome / iCloud feedback polish | ADR-019; `cap9-9.7-poc08-notes.md` UX-1 |
| Live Photo (Cap 9.7) | LIVE badge + preparing spinner top-left overlaps status-bar time | **Closed by 14.6b** (`16ed6e3`). Badge + item Layer 2 / Live-prepare spinner share `_FeedCornerChrome` at bottom-right; Overlay `trailingInset` 123. Library resolve loading stays centered. Q7 play-once hide/show unchanged. Kafka Profile PASS. UX-1 untouched. | Closed by Cap 14.6b | ADR-019; `cap9-9.7-poc08-notes.md` UX-2 |
| Cap 13 (13.8) | **First launch right after granting Limited access shows an empty All tab and does not self-heal** | **Closed by 14.6** (`37821ec` + `7329081`). Bounded re-resolve on successful empty remains; Kafka showed the empty All was started by resume `currentStatus()=.limited` **before** `requestAuthorization` completed. Skip that invalidate while `requestAccess` is in flight, then `restartSession` when the grant completes. Kafka Profile: loading then selected media, not empty copy. ADR-024 empty-not-cached remains as tab-switch backup. | Closed by Cap 14.6 (ADR-025 D8 + grant-complete restart) | ADR-025 / ADR-024 / ADR-014 / ADR-021 |
