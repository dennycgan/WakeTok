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
  - App Store Connect app-record creation: owner-only
  - See `release-handoff.mdc`
- iOS deployment target: iOS 18.0 (see ADR-007; ADR-005 superseded)
- Test devices: iPhone 13 (performance floor), iPhone 17 (current-device compat)
- No backend, no custom auth, no remote database, no developer-owned media server (kickoff Tech Stack)

## Capability Roadmap (project-level; top-to-bottom = execution order; YOU ARE HERE)
- [x] Project Bootstrap (flutter create scaffold, pigeon/ placeholder, docs skeleton, root commit)
- [x] POC-04: Flutter Media Feed Architecture Gate (must pass before production domain/data/feature implementation)
- [x] POC-03: Lock-screen continuous playback gate (must pass before production domain/data/feature implementation)
- [x] POC-09: Current Photos Representation Export Gate
      (must pass before production physical-clip implementation)
- [x] App Foundation
      (gen_l10n + ARB localisation infrastructure, shared error/result
      contracts, production Pigeon contract baseline)
- [ ] iOS Photos permission, Library access, iCloud asset state handling
      (phase 5.1 establishes theme token baseline; token-only styling
      from this capability onward — ADR-009)
      <-- YOU ARE HERE
- [ ] All / Photos / Videos built-in source resolution
      (production resolution must enumerate the FULL library including
      iCloud-only assets; device-local filtering is spike-only; acceptance
      includes date-distribution sampling on owner's real 40k library)
- [ ] Main Browse Screen and vertical Media Feed
      (Severe Hang debt from ADR-001: measurable acceptance criteria to be
      defined in this capability's phase design)
- [ ] Media Info Overlay, loading states, empty states,
      POC-10 file-size semantics,
      optional best-effort Location Label (not release-blocking)
- [ ] Live Photo rendering and static fallback (POC-08)
- [ ] Asset Source and Source Pool Definition domain models
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
Active capability: iOS Photos Permission, Library Access, iCloud Asset State

- [x] 5.1 Theme token baseline: lib/core/theme semantic Light/Dark tokens
      (surface / background / onSurface / accent-provisional /
      feed-background minimal set), ThemeData wired in MaterialApp,
      provisional accent; existing screens render in both modes;
      token-only styling starts here (ADR-009) — work `2e95eca`

- [x] 5.2 Photos authorization domain + gateway: implement PhotoLibraryApi
      authorization status/request in Swift PhotoLibraryService
      (converge stub ApiHost naming); Pigeon adds non-prompting
      authorizationStatus (pure PhotoKit read, never triggers the system
      prompt) and presentLimitedLibraryPicker; Dart authorization state
      model (notDetermined / denied / restricted / limited / full),
      repository interface + platform gateway; Riverpod wiring per ADR-010
      (ProviderScope at composition root; domain stays Riverpod-free —
      guard test adds riverpod import ban for lib/domain; domain
      signatures use Future/Stream only, no AsyncValue; features must not
      construct gateways or hold platform concrete types);
      Info.plist: NSPhotoLibraryUsageDescription PLACEHOLDER
      (final wording owner-only, release-handoff) +
      PHPhotoLibraryPreventAutomaticLimitedAccessAlert = YES
      — work `5ad1357`

- [x] 5.3 Permission UI flows (en / zh-Hans, tokens only):
      first-launch request; denied / restricted screen with Open Settings;
      Limited banner + manage-selection entry (kickoff ADR-K semantics);
      success landing = debug shell showing per-type totals
      (real Feed is next capability) — work `8ef8566`

- [x] 5.4 Library access + iCloud asset state model: paged gateway fetch
      of PHAsset-level metadata (id / type / creation date) — enumerates
      individual PHAssets only, no PHAssetCollection/Album enumeration;
      NO device-local filtering (full library incl. iCloud-only); domain
      asset availability vocabulary (deviceLocal / iCloudNotDownloaded /
      downloading / unavailable); unit tests; debug smoke shows
      per-type totals; non-goal: product All/Photos/Videos source
      resolution and feed (next capability) — work `690aa0d`
      (availability KVC fix `7d8f022`)

- [~] 5.5 Real-device acceptance on iPhone 13 Pro: permission flows
      (first ask / deny→Settings / limited banner + manage),
      totals on the 5.3 debug shell match Photos app counts on owner's
      ~42k library (default PHFetchOptions semantics: excludes Hidden
      and Recently Deleted), Light/Dark render, en + zh-Hans strings

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.
> Phase Roadmap is set by the owner before work begins on each capability.
> When YOU ARE HERE moves, do not generate Phase Roadmap content without
> explicit owner approval of the phases.

## Now working on (describe ONLY the in-progress item)
- Goal (one line): 5.5 Real-device acceptance on iPhone 13 Pro (permission flows + totals vs Photos ~42k)
- Sub-steps done: 5.4 closed (work `690aa0d`; device light smoke PASS; availability via resource KVC `7d8f022`)
- Next step: owner runs 5.5 acceptance checklist on iPhone 13 Pro
- Related decisions: ADR-001 … ADR-010 (see DECISIONS.md)

## Contract pointers (don't memorize, go read the source)
- Domain terms (canonical, bilingual): docs/GLOSSARY.en-zh.md
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/waketok_platform_apis.dart → lib/platform/generated/, ios/Runner/Platform/ (spike under pigeon/spikes/ reference only)
- l10n: lib/l10n/ (ARB + AppLocalizations; locale_resolution.dart; untranslated_messages.json)
- Theme: lib/core/theme/ (WakeTokTokens ThemeExtension + waketokTheme; ADR-009)
- Authorization: lib/domain/authorization/, lib/platform/photo_library_gateway.dart, lib/features/authorization/ (ADR-010)
- Library catalog: lib/domain/library/, PhotoLibraryApi.libraryTotals / fetchLibraryPage; totals shell: lib/features/library_smoke/
- Errors / Result: lib/core/errors/, lib/core/result/ (ADR-008); ErrorCode mapping in lib/platform/error_code_mapping.dart
- Architecture boundaries: ADR-009 + ADR-010 + test/architecture/ guard tests
- ADR-001 … ADR-010: docs/DECISIONS.md
- POC spike code & evidence: branch `spike/poc` — read-only archive;
  never merge; never delete
- (grows as code lands)

## Do NOT touch (unless explicitly opening a new phase)
- docs/WakeTok(App)_project_kickoff.md — owner's private spec, READ-ONLY for AI tools
- (grows as fragile areas appear)

## Known debt / intentionally deferred
| Capability | Item | Reason | Picks it up | Related ADR |
|---|---|---|---|---|
| POC-04 | Severe Hang under fast scrolling / animateToPage load | Conditional Pass accepted; must address in production feed | Production Main Browse Screen | ADR-001 |
| POC-03 | WeChat/VoIP interrupt: no auto-resume on lock screen or iOS home without opening app | Q1=B: 3.3 PASS when shouldResume + poll/foreground resumes; suspended lock/home path deferred | Production Background Audio | ADR-002 |
| POC-03 | Real physical-clip integration after POC-09 (≥3 exported clips locked queue) | Bundle WAV proved service shape only; confirm Photos-backed segments, order, Now Playing, no Dart per transition | Production Background Audio (prerequisite: Generated Clip Source available after Physical Clip Export Core + Photos import) | ADR-002 |
| POC-03 | iCloud Asset download interrupt during background audio | P2=A: out of POC-03 scope | Production Background Audio | ADR-002 |
| POC-09 | Slow-motion frame-rate / audio-pitch beyond duration gate | 9.3 passed duration only | Physical Clip Export Core | ADR-004 |
| POC-09 | Multi-audio-track selection UX | 9.4 default track only | POC-07 | ADR-004 |
| App Foundation | iOS 18 simulator smoke (no 18.x runtime installed) | Floor is 18.0 (ADR-007); day-to-day verify on 26.x only | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-007 |
| App Foundation | Localization Inventory generation/validation mechanism (kickoff ADR-U §7–8) | Only smoke keys exist during App Foundation; nothing to inventory yet. Interim inventory-of-record = ARB + Untranslated Messages Report (satisfies ADR-U §9 task checks until the formal Inventory lands) | Settings and localisation completion | — (kickoff ADR-U) |
| App Foundation | Final accent color (depends on app icon design); provisional accent in theme tokens | Icon design is owner parallel track; accent must freeze before Main Browse Screen closes | Main Browse Screen | ADR-009 |
| App Foundation | App icon asset set | Owner parallel track; required before first TestFlight build upload | TestFlight internal testing | — |
| iOS Photos permission | Typography text-style tokens (5.1 ships color tokens only; M3 default TextTheme) | Color-first keeps 5.1 small; type scale locks when heavy content UI lands | Main Browse Screen | ADR-009 |
| iOS Photos permission | NSPhotoLibraryUsageDescription is PLACEHOLDER copy | Final permission wording is owner-only (release-handoff) | TestFlight internal testing | — |
| iOS Photos permission | List-time availability via undocumented PHAssetResource KVC `locallyAvailable` | No public isLocallyAvailable on PHAsset/PHAssetResource in the iOS SDK | Final real-device performance, memory, accessibility, privacy, and error-state hardening (or when Apple exposes a public API) | — |
