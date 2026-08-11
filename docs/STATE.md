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
      (ADR-015…018; 8.8 notes; Location + cross-source playhead debts)
- [x] Live Photo rendering and static fallback (POC-08)
      (ADR-019; POC-08 PASS Cap 9.7; mute persist `4aa93b0`;
      UX-1/UX-2 Known debt; notes `cap9-9.7-poc08-notes.md`)
- [ ] <-- YOU ARE HERE: Asset Source and Source Pool Definition
      domain models
- [ ] Live Resolution, Asset Source Availability,
      Identity Coalescing, and Resolved Pool Snapshot
- [ ] Session Queue, Default Session Profile,
      and stable Item Ordering Semantics
- [ ] Endless Shuffle, Queue Stability, and Session Continuity
- [ ] Build a Pool, Ephemeral Pool, and Source ordering
- [ ] Saved Pool persistence, reopen, management, and capacity limits
- [ ] Auto-play Presets and Mode Eligibility Rule
- [ ] One-item Lookahead Fetch, Waiting for Media, iCloud Fallback
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
Active capability: Asset Source and Source Pool Definition domain models

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.
> Phase Roadmap is set by the owner before work begins on each capability.
> When YOU ARE HERE moves, do not generate Phase Roadmap content without
> explicit owner approval of the phases. An explicit awaiting-scope placeholder
> is allowed at Cap close-out (see state-decisions-maintenance).

- [x] 10.1 Contract freeze: owner Cap 10 review (D1–D9 / F1–F2);
      ADR-020 Proposed (no Accepted / no fake anchor); GLOSSARY cross-ref;
      Out-of-scope locked (no Live Resolve / UI / persistence / Generated
      Clip specialization types; gateway mapper untouched)
- [x] 10.2 Domain kinds + SourceReference generalization: add `album` /
      `smartAlbum` to domain `AssetSourceKind` (`other` stays wire-only);
      keep Cap 6 built-in three legal pairs; exhaustiveness-only call-site
      arms allowed; no Host/Pigeon/schema change; mapper still throws
      — work `8c99d46`
- [ ] 10.3 SourcePoolDefinition + PersistencePolicy + ADR-P capacity:
      max 30 sources/pool validated now; max 10 saved presets as constant
      only (CRUD in Saved Pool Cap); `saved` constructible, no repository
- [ ] 10.4 Invariant unit tests + architecture guards (if `lib/` touched);
      ItemOrderingPolicy.forKind slot (built-ins = creationDateDesc;
      album/smartAlbum = unspecified)
- [ ] 10.5 Cap close-out: STATE Cap `[x]` + PHASE_HISTORY + YOU ARE HERE →
      Live Resolution / Availability / Identity Coalescing / Snapshot Cap

## Now working on (describe ONLY the in-progress item)
- Goal (one line): Cap 10.2 closed; next = 10.3 SPD (design approved, await go)
- Sub-steps done: 10.2 work `8c99d46`; ADR-020 Accepted (this docs commit)
- Next step: owner OK this docs commit/push → confirm 10.3 comments +
      STATE 10.3 `[~]` → implement SourcePoolDefinition
- Related decisions: ADR-020 (Accepted, anchor `8c99d46`)

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
  transparent top + compact bar `5fb93de` / ADR-016)
- Built-in sources: lib/domain/source/, PhotoLibraryApi.listAssetSources / resolveSource (ADR-013); providers: lib/features/library_smoke/asset_source_providers.dart
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
- ADR-001 … ADR-020: docs/DECISIONS.md (ADR-019 Cap 9 Live; ADR-020 Cap 10
  Source Pool Definition models — Accepted, anchor `8c99d46`)
- Acceptance notes (Cap 5.5): docs/acceptance/cap5-5.5-notes.md
- Acceptance notes (Cap 6.5): docs/acceptance/cap6-6.5-notes.md
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
| Media Info Overlay | Same-asset playhead shared across built-in sources (All ↔ Videos) | First observed Cap 8.8: `PlaybackApiHost` keys the app-scoped player by `assetIdentifier` (ADR-006), so the same Photos id under All vs Videos reuses position / ended-on-last-frame. ADR-014 Decision 4 only resets **feed index** on tab switch — not playhead continuity. Owner preliminary (not final): likely acceptable and may help Session Continuity; **revisit when that capability is designed**. No Cap 8 fix. | Session Continuity (when scheduled) | ADR-006 / ADR-014; `docs/acceptance/cap8-8.8-notes.md` |
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
