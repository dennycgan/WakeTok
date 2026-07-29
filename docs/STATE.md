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
- iOS deployment target: iOS 16.0 (decided post-POC; see ADR-005 pending)
- Test devices: iPhone 13 (performance floor), iPhone 17 (current-device compat)
- No backend, no custom auth, no remote database, no developer-owned media server (kickoff Tech Stack)

## Capability Roadmap (project-level; top-to-bottom = execution order; YOU ARE HERE)
- [x] Project Bootstrap (flutter create scaffold, pigeon/ placeholder, docs skeleton, root commit)
- [x] POC-04: Flutter Media Feed Architecture Gate (must pass before production domain/data/feature implementation)
- [x] POC-03: Lock-screen continuous playback gate (must pass before production domain/data/feature implementation)
- [x] POC-09: Current Photos Representation Export Gate
      (must pass before production physical-clip implementation)
- [ ] App Foundation
      (gen_l10n + ARB localisation infrastructure, shared error/result
      contracts, production Pigeon contract baseline)   <-- YOU ARE HERE
- [ ] iOS Photos permission, Library access, iCloud asset state handling
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
      cancellation and recoverable partial success)
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
> - POC-06, POC-07, POC-08, and POC-10 run inside the capability
>   that consumes their result.
> Top-to-bottom = current execution order. Reorder if priorities change; never leave it unordered.

## Phase Roadmap (active capability only)
Active capability: App Foundation

- [ ] 4.1 Add flutter_localizations + intl; configure gen_l10n;
      create app_en.arb and app_zh_Hans.arb with one smoke key each;
      verify generated l10n.dart compiles

- [ ] 4.2 Define shared Result<T, AppError> type and AppError enum
      (covers media, permission, export, album error domains);
      unit tests for Result combinators;
      AppError naming must align with kickoff error codes
      (e.g. iCloudDownloadRequired / iCloudDownloadFailed), with a native
      error mapping table (PHPhotosError 3164 → ...); spike-era names
      (inCloudUnavailable) must not leak into production contracts

- [ ] 4.3 Define production Pigeon contracts baseline:
      PhotoLibraryApi, PlaybackApi, ExportApi (empty implementations);
      generated code compiles on both Dart and Swift sides;
      production baseline built from scratch in pigeon/ (spike contracts
      remain on spike/poc as reference only); contract signatures require
      owner-approved design draft before coding

- [ ] 4.4 Wire l10n into MaterialApp; smoke test English and
      Simplified Chinese strings render on device

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.
> Phase Roadmap is set by the owner before work begins on each capability.
> When YOU ARE HERE moves, do not generate Phase Roadmap content without
> explicit owner approval of the phases.
> App Foundation 4.1–4.4 approved for entry; owner may revise before coding starts.

## Now working on (describe ONLY the in-progress item)
- Goal (one line): stand up App Foundation (l10n, shared Result/AppError, production Pigeon baseline)
- Sub-steps done: Bootstrap; POC-04 Conditional Pass (ADR-001); POC-03 Conditional Pass (ADR-002); POC-09 Pass (ADR-003, ADR-004)
- Next step: phase 4.1 gen_l10n + ARB smoke keys (await owner go to code)
- Related decisions: ADR-001 (POC-04); ADR-002 (POC-03); ADR-003 (subtitle scope); ADR-004 (POC-09 Pass); ADR-005 (iOS 16.0 deployment target)

## Contract pointers (don't memorize, go read the source)
- Domain terms (canonical, bilingual): docs/GLOSSARY.en-zh.md
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/ (empty until production baseline; spike under pigeon/spikes/)
- ADR-001 … ADR-005: docs/DECISIONS.md
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
