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
      UX-1/UX-2 Known debt; notes `cap9-9.7-poc08-notes.md`)
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
- [~] Endless Shuffle, Queue Stability, and Session Continuity
      (Cap 13; **parked / blocked at 13.6** — gate-foundation defect;
      bar not lowered; see Parked capability below)
- [ ] <-- YOU ARE HERE: Current-item iCloud media fetch, visual
      preheating, and loading states
      (Cap 14 / ADR-025 Proposed; restores 13.6 *executability*,
      does not run 13.6 Instruments)
- [ ] Build a Pool, Ephemeral Pool, and Source ordering
      (**deferred past Cap 14** — does not unblock 13.6)
- [ ] Saved Pool persistence, reopen, management, and capacity limits
      (**deferred past Cap 14** — does not unblock 13.6)
- [ ] Auto-play Presets and Mode Eligibility Rule
      (**deferred past Cap 14** — does not unblock 13.6)
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
- [ ] Add to Album
      (Full Access only; v1.0 scope;
      the only pre-authorized downgrade-to-1.1 item)
- [ ] Settings and localisation completion
      (English/zh-Hans copy, privacy/storage/about screens,
      Light/Dark layout verification)
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
Active capability: Current-item iCloud media fetch, visual
preheating, and loading states (Cap 14)

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.
> Phase Roadmap is set by the owner before work begins on each capability.
> When YOU ARE HERE moves, do not generate Phase Roadmap content without
> explicit owner approval of the phases. An explicit awaiting-scope placeholder
> is allowed at Cap close-out (see state-decisions-maintenance).
>
> **Intentional deviation (ADR-025 D5 / D11):** Cap 13 is incomplete so it
> cannot enter PHASE_HISTORY. It is **Parked** in the next section — not
> expanded here. Only Cap 14 phases are ACTIVE.

- [x] 14.1 Contract freeze: ADR-025 Proposed (no Accepted date, no
      fake anchor); Capability Roadmap reorder; Parked Cap 13;
      Known debt Picks it up → Cap 14; Auto-play lookahead row renamed
- [ ] 14.2 Host Layer 1: `requestPreview` (local still + video poster)
      + cancel
- [ ] 14.3 Host Layer 2: current-item `requestDisplayAsset` /
      `requestPlayableVideo` may use network + cancel
      (ADR-006 Status narrow supersede in the docs commit after this
      work sha)
- [ ] 14.4 Feed three-layer UI + ARB; retire/rewrite
      `mainBrowseFeedICloudOnly`
- [ ] 14.5 ±1 local-only visual preheat + cancel on leaving the window
- [ ] 14.6 Limited first-launch All: keep resolve-loading on successful
      empty + bounded re-resolve (3 extra attempts, 500/1000/2000 ms)
- [ ] 14.7 Cap 14 close-out docs: Cap 14 `[x]`; **return YOU ARE HERE
      to Cap 13**; 13.6 unblocked as executable at the **unchanged**
      V-hard bar; **do not run Instruments in 14.7**
      (ADR-025 Accepted is the docs commit **after 14.2**, not 14.7)

## Parked capability: Cap 13 (Endless Shuffle, Queue Stability, and Session Continuity)

> Not ACTIVE. Do not treat these lines as the Phase Roadmap. Do not
> rewrite 13.6 FAIL tables. Do not lower, Conditional-Pass, or split
> the hitch bar. Re-opened only when Cap 14 close-out returns YOU ARE
> HERE here (ADR-025 D6 / D12).

- [x] 13.1–13.5, 13.8 — see git / ADR-023 / ADR-024 (13.8e `7edc99c`)
- [ ] 13.6 Acceptance — **blocked** (gate-foundation defect; NOT
      "no hang found", NOT "skipped for now"): unit
      SHUF/CONT/STAB/ROUND + APP/W-SHUF/W-END + architecture green;
      Instruments Profile Hang retest on iPhone 13 Pro (Kafka, UDID
      `00008110-001114420AEA801E`) — same V-hard as ADR-014 Cap 7.7a
      (mean hitch < 25 ms/s AND zero Severe Hang on production chrome
      with Shuffle-driven feed **including Manual Endless: swipe past
      last item to start next Shuffle round**; not Conditional Pass);
      does not clear Release hang Known debt; no new PoC gate; no
      Checkpoint recovery test.
      **Why blocked:** the gate's own preconditions are broken, so the
      Instruments run is not interpretable — iCloud-only pages render
      as a copy panel whose Retry is a no-op (Host is local-only,
      ADR-006 Cap 7.3 fill-in), and Shuffle scatters those pages
      through the Queue, so a Full-library feed scroll is not a
      readable hitch surface. The bar is **not** lowered, **not**
      Conditional Pass, **not** split. Evidence:
      `docs/acceptance/cap13-13.6-notes.md` (Profile V-hard FAIL) +
      `docs/acceptance/cap13-13.6b-hang-diagnosis-notes.md` (campaign
      stopped as inexecutable; hypotheses A–D untested — no
      hang-window stack). Cap 14 restores **executability**; the
      re-run remains this 13.6 phase after YOU ARE HERE returns.
- [ ] 13.7 Cap close-out (stays last; cannot run while 13.6 is
      blocked): STATE Cap `[x]` + PHASE_HISTORY;
      Phase Roadmap → Build a Pool, Ephemeral Pool, and Source ordering
      (Cap 14 will already be `[x]`; Auto-play Presets stay later)

## Now working on (describe ONLY the in-progress item)
- Goal (one line): Cap 14.1 contract freeze (ADR-025 Proposed + Roadmap
      reorder); Cap 13 parked at 13.6
- Sub-steps done: this docs commit is 14.1
- Next step: owner OK commit/push → 14.2 Host Layer 1 `requestPreview`
      + cancel (no code until then)
- Related decisions: ADR-025 Proposed; ADR-006 Cap 7.3 local-only still
      **fully binding until 14.2 work + Accepted docs**; ADR-023 D10
      13.6 V-hard unchanged; ADR-024 empty Snapshot not cached

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
  PhotoLibraryApi.requestDisplayAsset / requestPlayableVideo (ADR-006 Cap 7.3);
  PlaybackRepository.clearPlaybackPool (Cap 9.3 `afd3181` / ADR-019);
  debug probe: lib/features/library_smoke/playback_pipeline_probe.dart
- Live Photo motion: ios/Runner/Platform/LivePhotoApiHost.swift
  (viewType `waketok/live_photo_surface`); Pigeon LivePhotoApi /
  LivePhotoFlutterApi (Cap 9.2); Dart domain
  `lib/domain/live_photo/` + `LivePhotoGateway` +
  `livePhotoRepositoryProvider` (Cap 9.3 `afd3181`); Feed play-once +
  `LiveHostOpSerial` (Cap 9.4 `c86dd6e`); preparing spinner +
  `gatedFlagUpdate` (Cap 9.5 `042c59d`); `sharedMuteProvider` + mute
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
  reclassified Accepted Cap 13.5 (not bug-fix; row kept); tab = new Session; 13.6
  Profile V-hard on iPhone 13 Pro (Kafka)
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
  non-empty) + `lib/features/main_browse/vertical_media_feed.dart`
  (empty ids with `unauthorized` / `unavailable` status →
  resolve-failed panel + Retry, not empty copy); work `1f8a240` /
  ADR-024
- ADR-001 … ADR-025: docs/DECISIONS.md (ADR-025 Cap 14 current-item
  iCloud fetch — **Proposed**, no work anchor yet; ADR-024 Cap 13.8
  Browse Snapshot cache — Accepted, anchor `1f8a240`; ADR-023 Cap 13
  Endless Shuffle — Accepted, anchor `f0187b4`; ADR-022 Cap 12 Session
  Queue Accepted, anchor `f53d455`; ADR-021 Cap 11 Live Resolution
  Accepted, anchor `95779ef`; ADR-020 Cap 10 models Accepted)
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
- ADR-001 re-eval outline (Fail path not taken — 7.7a PASS):
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
  Limited All empty draft 3 + resolution):
  docs/acceptance/cap13-13.6b-hang-diagnosis-notes.md
- POC spike code & evidence: branch `spike/poc` — read-only archive;
  never merge; never delete
- (grows as code lands)

## Do NOT touch (unless explicitly opening a new phase)
- docs/WakeTok(App)_project_kickoff.md — owner's private spec, READ-ONLY for AI tools
- (grows as fragile areas appear)

## Known debt / intentionally deferred
| Capability | Item | Reason | Picks it up | Related ADR |
|---|---|---|---|---|
| Main Browse Screen | Release build Severe Hang / hitch on production feed (Kafka) | Accidental Release campaign V-hard FAIL (`cap7-7.7-notes.md`); **7.7a Profile PASS**. Evidence strength: **All** surface clean **3/3 FAIL (Release) → 3/3 PASS (Profile)** is a strong signal the mode divergence is real (not a one-off flip); **Videos** was already 2/3 PASS on Release (intermittent), so weaker as a divergence signal. Track for shipping; do not deep-dive cause here | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-001 / ADR-014 |
| Media Info Overlay | Location Label (reverse geocode) not implemented | Owner Cap 8 Q1=B: Overlay row 4 hidden when empty this Cap (kickoff ADR-X best-effort deferral; no geocode). Current-Item-only geocode hard rule unchanged when a later Cap picks this up | Later Cap (or reopen when Owner schedules) | kickoff ADR-X |
| Media Info Overlay | Same-asset playhead shared across built-in sources (All ↔ Videos) — **Accepted behaviour** | First observed Cap 8.8 (`cap8-8.8-notes.md`): `PlaybackApiHost` keys the app-scoped player by `assetIdentifier` (ADR-006), so the same Photos id under All vs Videos reuses position / ended-on-last-frame. **Accepted (ADR-023 D6 / Cap 13.5)** — intentional Host keying, **not** a bug fix and **not** cross-tab Continuity (D8: tab = new Session; feed index still resets). No `PlaybackApiHost` change. **Row kept** (not deleted like resolved bugs) as a permanent record of accepted behaviour to prevent re-litigation when the shared playhead is noticed again. | Closed by Cap 13.5 (ADR-023 D6) | ADR-006 / ADR-014 / ADR-023; `docs/acceptance/cap8-8.8-notes.md` |
| Media Info Overlay | File-size disclaimer copy (kickoff ADR-W §5) unset | Size is logical resource bytes — not device disk / iCloud quota / optimized-local / immediate free-on-delete. Not an eng Decision gap; needs user-visible copy landing | Settings and localisation completion (or Cap 8.5/8.6 if a short on-media note is added) | kickoff ADR-W |
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
| iOS Photos permission | List-time availability via undocumented PHAssetResource KVC `locallyAvailable` | No public isLocallyAvailable on PHAsset/PHAssetResource in the iOS SDK | Final real-device performance, memory, accessibility, privacy, and error-state hardening (or when Apple exposes a public API) | — |
| Cap 6 / library_smoke | Library Totals Shell error row uses raw exception string (`'${asyncTotals.error}'`), not ARB | Predates ADR-012 smoke hardening; Cap 6.4 left untouched on purpose | Settings and localisation completion | ADR-012 |
| Main Browse Screen | No architecture scan for hardcoded `TextStyle(` in `lib/features/**` (typography tokens exist; `Color(0x` still scanned) | Cap 7.2 locked type roles without a TextStyle literal guard; easy to bypass tokens while 7.4–7.7 chrome lands | Settings and localisation completion | ADR-009 / ADR-014 |
| Main Browse Screen | Video page swipe may flash one frame of the previous video | Shared 1+1 AVPlayer + single Platform View (ADR-006); Cap 7.7 observe-only (always-on; orthogonal to hang — see `cap7-7.7-notes.md`) | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-006 |
| Live Photo (Cap 9.7) | Offline/weak-net iCloud Live: preparing spinner may be zero-duration (fail too fast) | POC-08 #5/#6 PASS with static fallback; owner wants later brief visible spin-then-fail so users see “needs network” (not progress-copy / Waiting for Media) | Live chrome / iCloud feedback polish | ADR-019; `cap9-9.7-poc08-notes.md` UX-1 |
| Live Photo (Cap 9.7) | LIVE badge + preparing spinner top-left overlaps status-bar time | Cap 9.7 layout observation; move badge+spinner to bottom-right | Main Browse / Live chrome polish | ADR-019; `cap9-9.7-poc08-notes.md` UX-2 |
| Cap 13 (13.8) | **First launch right after granting Limited access shows an empty All tab and does not self-heal** — the new user's very first screen reads "no content in this source" | Not a corner-case timing nit — this is the product's first impression for every user who grants Limited. PhotoKit has not surfaced the Limited selection yet when the default All tab resolves, so that first resolve is legitimately empty; there is **no** Photos observer and **no** automatic re-resolve, so the empty screen persists until the user happens to switch tabs on their own. Risk: the user concludes the app is broken and uninstalls before ever finding that hidden step. `1f8a240` (13.8c) removed only the *sticky* half — an empty result is no longer cached — the first-frame race itself is untouched. **Workaround: switch to Photos or Videos and back to All; force-quit is NOT needed** (device-verified 13.8d). Cap 14.6: keep resolve-loading on successful empty + bounded re-resolve (not “wait for picker”). | Current-item iCloud media fetch, visual preheating, and loading states (Cap 14 / ADR-025; phase 14.6) | ADR-025 / ADR-024 / ADR-014 / ADR-021 |
