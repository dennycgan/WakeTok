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
- iOS deployment target: Flutter default (placeholder; finalize after POC-04)
- Test devices: iPhone 13 (performance floor), iPhone 17 (current-device compat)
- No backend, no custom auth, no remote database, no developer-owned media server (kickoff Tech Stack)

## Capability Roadmap (project-level; top-to-bottom = execution order; YOU ARE HERE)
- [x] Project Bootstrap (flutter create scaffold, pigeon/ placeholder, docs skeleton, root commit)
- [x] POC-04: Flutter Media Feed Architecture Gate (must pass before production domain/data/feature implementation)
- [~] POC-03: Lock-screen continuous playback gate (must pass before production domain/data/feature implementation)   <-- YOU ARE HERE
- [ ] POC-09: Current Photos Representation Export Gate
      (must pass before production physical-clip implementation)
- [ ] App Foundation
      (gen_l10n + ARB localisation infrastructure, shared error/result
      contracts, production Pigeon contract baseline)
- [ ] iOS Photos permission, Library access, iCloud asset state handling
- [ ] All / Photos / Videos built-in source resolution
- [ ] Main Browse Screen and vertical Media Feed
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
> - POC-04, POC-03, and POC-09 are explicit project gates (listed above).
> - POC-06, POC-07, POC-08, and POC-10 run inside the capability
>   that consumes their result.
> Top-to-bottom = current execution order. Reorder if priorities change; never leave it unordered.

## Phase Roadmap (active capability only)
Active capability: POC-03 Lock-screen continuous playback gate

- [x] 3.1 Create spike harness in lib/spikes/poc_03/ +
      ios/Runner/Spikes/POC03/; minimal AVQueuePlayer + AVAudioSession(.playback)
      setup; playback must not depend on Flutter Widget being alive

- [x] 3.2 Verify clip-to-clip auto-advance on lock screen:
      pre-queue next AVPlayerItem; confirm audio gap is imperceptible
      or acceptable between segments

- [ ] 3.3 Verify audio interruption and recovery
      (phone call, Siri, other audio apps; session re-activates on return)

- [ ] 3.4 Verify Control Center metadata (Now Playing info + transport controls)
      and AirPods play/pause/next

- [ ] 3.5 Verify process termination stops playback;
      next foreground launch can attempt SessionCheckpoint recovery

- [ ] 3.6 Record go / no-go in DECISIONS.md
      (draft in chat, owner approves before append)

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.
> Phase Roadmap is set by the owner before work begins on each capability.
> When YOU ARE HERE moves, do not generate Phase Roadmap content without
> explicit owner approval of the phases.

## Now working on (describe ONLY the in-progress item)
- Goal (one line): validate lock-screen continuous playback / background audio gate (POC-03) before production domain/data/feature implementation
- Sub-steps done: Bootstrap; POC-04 Conditional Pass (ADR-001); POC-03 3.1–3.2 (M1–M3 + lock gap PASS)
- Next step: phase 3.3 audio interruption and recovery (await owner go)
- Related decisions: ADR-001 (POC-04 Flutter+PV Conditional Pass; Severe Hang = production debt)

## Contract pointers (don't memorize, go read the source)
- Domain terms (canonical, bilingual): docs/GLOSSARY.en-zh.md
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/ (empty until production baseline; spike under pigeon/spikes/)
- ADR-001: docs/DECISIONS.md
- (grows as code lands)

## Do NOT touch (unless explicitly opening a new phase)
- docs/WakeTok(App)_project_kickoff.md — owner's private spec, READ-ONLY for AI tools
- (grows as fragile areas appear)

## Known debt / intentionally deferred
| Capability | Item | Reason | Picks it up | Related ADR |
|---|---|---|---|---|
| Bootstrap | iOS deployment target left at Flutter default | Kickoff Open Question: platform target TBD; decide with real-device data | POC-04 | — |
| POC-04 | Severe Hang under fast scrolling / animateToPage load | Conditional Pass accepted; must address in production feed | Production Main Browse Screen | ADR-001 |
