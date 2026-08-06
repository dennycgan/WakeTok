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
- [ ] Main Browse Screen and vertical Media Feed
      (ADR-014 Accepted; Severe Hang hard gate: Profile + full chrome;
      zero Severe Hang; fail → ADR-001 SwiftUI re-evaluation)
      <-- YOU ARE HERE
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
Active capability: Main Browse Screen and vertical Media Feed

- [x] 7.1 Contract freeze (ADR-014): Cap 7 slim feed model — ephemeral id
      queue from Cap 6 resolve only; Sequential + Manual (kickoff General/
      Mixed default Shuffle deferred until Endless Shuffle capability);
      chrome In/Out; Pools tab visible+disabled; tab switch resets to
      queue head; smoke demoted from default landing; Live Photo = static
      (+ optional LIVE badge). Freeze Severe Hang / hitch bar for 7.7:
      iPhone 13 Pro, **Instruments Profile** (same mode as ADR-001
      baselines; Release not mixed into the gate — optional Release notes
      only as a separate secondary dataset if owner later asks); mean hitch
      < 25 ms/s AND **zero** Severe Hang (hard gate; no Conditional Pass
      rewrite of ADR-001). **Retest surface must be full production chrome**
      (top All/Photos/Videos + disabled Pools tab + bottom bar shell) — not
      a bare PageView; POC-04 spike had no chrome, so hitch may regress once
      chrome is mounted. Design-freeze (no production feed code in 7.1).
      ADR-014: Accepted at Cap 7.2 work `5ef2e8a` (see DECISIONS).
      — docs `fb4bc9f`

- [x] 7.2 Theme tokens for feed chrome: typography scale tokens (ADR-009
      Known debt); feed scrim / on-media contrast tokens as needed; still
      `accentProvisional` (freeze in 7.8 only).
      — work `5ef2e8a`

- [x] 7.3 Playback + image pipeline (ADR-006): production foreground
      PlaybackApi path — PV attach/detach, bounded 1+1; image display
      request path; no Background Audio / Now Playing product scope.
      — work `29fcf2d`

- [x] 7.4 Main Browse chrome shell: top All/Photos/Videos + Pools disabled
      (ARB Coming soon on-cell; no tap SnackBar); bottom NavigationBar
      (Browse active; Clips/Auto/Settings stub; explicit indicatorColor
      token); Main Browse = default post-auth landing; library_smoke
      debug-only via Settings; Limited banner kept.
      — work `d54d9be`

- [x] 7.5 Vertical Media Feed: PageView (or equivalent) over ephemeral
      queue; Manual swipe; wire resolve(All|Photos|Videos); pool/preheat
      bounds (ADR-P.5 spirit); architecture + localization guards green.
      — work `fb82bf6`

- [x] 7.6 Source switch behavior: changing top tab rebuilds ephemeral
      queue from Cap 6 resolve and starts at queue head; no Pool model;
      no Session Continuity product rules; session-scoped successful
      resolve cache per built-in (ADR-014 Decision 5; process lifetime;
      failures uncached; “session” ≠ Consumption Session).
      — work `79f8c12`

- [x] 7.7 Real-device feed acceptance (iPhone 13 Pro, **Profile**): scroll
      real library; hitch < 25 ms/s AND no Severe Hang per 7.1 hard gate;
      notes under `docs/acceptance/`; portfolio eligibility evidence
      (feed screenshot-able). **FAIL** (V-hard; Videos+All) 2026-08-06 —
      do **not** rewrite; Fail path opened (ADR-001 re-evaluation). Hard bar
      unchanged. Notes `cap7-7.7-notes.md`; outline
      `cap7-7.7-adr001-reevaluation-outline.md`.
      — docs `b45a318`

- [~] 7.7b Severe Hang diagnosis: Time Profiler / System Trace on Kafka
      Profile + full chrome; sessions D-A-high, D-A-low, D-V-hang, D-idle;
      attribute main-thread block (no product code by default; probes only
      if stacks unreadable — owner-approved). Notes
      `cap7-7.7b-hang-diagnosis-notes.md`. Does **not** change 7.7 FAIL or
      the hard bar. ADR-015 **not** drafted here.

- [ ] 7.7c Fix concrete hang root cause(s) from 7.7b notes (product code
      only as justified by diagnosis).

- [ ] 7.7d Re-run Videos×3 + All×3 under **same** locked rules as 7.7
      (V-hard, Profile, full chrome, every Run must PASS). Then draft
      ADR-015 from closed evidence (keep Flutter+PV **or** SwiftUI path —
      follow stacks + retest, no pre-written conclusion).

- [ ] 7.8 Accent freeze (last) + Cap 7 close-out: freeze current
      `accentProvisional` as formal accent (Q6=A) or owner-supplied hex;
      Light/Dark token-only. In the **same** docs close-out commit, clear
      or mark resolved the Known debt rows that named Main Browse /
      Production Main Browse as picker-up: (1) Severe Hang ADR-001,
      (2) typography tokens ADR-009, (3) final accent color ADR-009.
      STATE + PHASE_HISTORY; portfolio Public scan remains owner-only.
      Blocked until 7.7d + ADR-015 path is settled.

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.
> Phase Roadmap is set by the owner before work begins on each capability.
> When YOU ARE HERE moves, do not generate Phase Roadmap content without
> explicit owner approval of the phases.

## Now working on (describe ONLY the in-progress item)
- Goal (one line): Cap 7.7b Severe Hang diagnosis (Time Profiler /
      System Trace)
- Sub-steps done: 7.1–7.7 (7.7 **FAIL** archived `b45a318` /
      `cap7-7.7-notes.md`; hard bar unchanged)
- Next step: owner runs D-A-high / D-A-low / D-V-hang / D-idle on Kafka;
      fill `cap7-7.7b-hang-diagnosis-notes.md` (no product code default)
- Related decisions: ADR-001 … ADR-014; ADR-015 only after 7.7d

## Contract pointers (don't memorize, go read the source)
- Domain terms (canonical, bilingual): docs/GLOSSARY.en-zh.md
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/waketok_platform_apis.dart → lib/platform/generated/, ios/Runner/Platform/ (spike under pigeon/spikes/ reference only)
- l10n: lib/l10n/ (ARB + AppLocalizations; locale_resolution.dart; untranslated_messages.json)
- Localization guard: ADR-012 + test/architecture/localization_test.dart
- Theme: lib/core/theme/ (WakeTokTokens ThemeExtension + waketokTheme; ADR-009)
- Authorization: lib/domain/authorization/, lib/platform/photo_library_gateway.dart, lib/features/authorization/ (ADR-010)
- Library catalog: lib/domain/library/, PhotoLibraryApi.libraryTotals / fetchLibraryPage (ADR-011); debug totals shell: lib/features/library_smoke/
- Main Browse shell: lib/features/main_browse/ (Cap 7.4 post-auth landing;
  Cap 7.5 VerticalMediaFeed + restoreRequests; Cap 7.6
  `mainBrowseResolveCacheProvider`)
- Built-in sources: lib/domain/source/, PhotoLibraryApi.listAssetSources / resolveSource (ADR-013); providers: lib/features/library_smoke/asset_source_providers.dart
- Playback / display: lib/domain/playback/, lib/platform/playback_gateway.dart;
  PhotoLibraryApi.requestDisplayAsset / requestPlayableVideo (ADR-006 Cap 7.3);
  debug probe: lib/features/library_smoke/playback_pipeline_probe.dart
- Errors / Result: lib/core/errors/, lib/core/result/ (ADR-008); ErrorCode mapping in lib/platform/error_code_mapping.dart
- Architecture boundaries: ADR-009 + ADR-010 + ADR-012 + test/architecture/ guard tests
- ADR-001 … ADR-014: docs/DECISIONS.md
- Acceptance notes (Cap 5.5): docs/acceptance/cap5-5.5-notes.md
- Acceptance notes (Cap 6.5): docs/acceptance/cap6-6.5-notes.md
- Acceptance notes (Cap 7.7 FAIL): docs/acceptance/cap7-7.7-notes.md
- ADR-001 re-eval outline (D1 deferred → diagnosis):
  docs/acceptance/cap7-7.7-adr001-reevaluation-outline.md
- Hang diagnosis (Cap 7.7b): docs/acceptance/cap7-7.7b-hang-diagnosis-notes.md
- POC spike code & evidence: branch `spike/poc` — read-only archive;
  never merge; never delete
- (grows as code lands)

## Do NOT touch (unless explicitly opening a new phase)
- docs/WakeTok(App)_project_kickoff.md — owner's private spec, READ-ONLY for AI tools
- (grows as fragile areas appear)

## Known debt / intentionally deferred
| Capability | Item | Reason | Picks it up | Related ADR |
|---|---|---|---|---|
| POC-04 | Severe Hang under fast scrolling / animateToPage load | Conditional Pass accepted; Cap 7.7 production Profile gate **FAIL** (`cap7-7.7-notes.md`); hard bar unchanged; diagnose before architecture fork | Cap 7.7b hang diagnosis → 7.7c fix → 7.7d retest | ADR-001 |
| POC-03 | WeChat/VoIP interrupt: no auto-resume on lock screen or iOS home without opening app | Q1=B: 3.3 PASS when shouldResume + poll/foreground resumes; suspended lock/home path deferred | Production Background Audio | ADR-002 |
| POC-03 | Real physical-clip integration after POC-09 (≥3 exported clips locked queue) | Bundle WAV proved service shape only; confirm Photos-backed segments, order, Now Playing, no Dart per transition | Production Background Audio (prerequisite: Generated Clip Source available after Physical Clip Export Core + Photos import) | ADR-002 |
| POC-03 | iCloud Asset download interrupt during background audio | P2=A: out of POC-03 scope | Production Background Audio | ADR-002 |
| POC-09 | Slow-motion frame-rate / audio-pitch beyond duration gate | 9.3 passed duration only | Physical Clip Export Core | ADR-004 |
| POC-09 | Multi-audio-track selection UX | 9.4 default track only | POC-07 | ADR-004 |
| App Foundation | iOS 18 simulator smoke (no 18.x runtime installed) | Floor is 18.0 (ADR-007); day-to-day verify on 26.x only | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-007 |
| App Foundation | Localization Inventory auto-generation/report tooling (kickoff ADR-U §7–8 summary artifact) | Hardcoded-copy scan + ARB key parity closed by ADR-012; Inventory report generator still deferred | Settings and localisation completion | — (kickoff ADR-U) / ADR-012 |
| App Foundation | Final accent color (depends on app icon design); provisional accent in theme tokens | Icon design is owner parallel track; accent must freeze before Main Browse Screen closes | Main Browse Screen | ADR-009 |
| App Foundation | App icon asset set | Owner parallel track; required before first TestFlight build upload | TestFlight internal testing | — |
| Portfolio | Repository visibility: Private → Public (eligibility: first demoable vertical slice — Main Browse feed scrolls real Photos library content on device) | Portfolio value requires something screenshot-able, not just decision records; premature public exposure shows unfinished POC/scaffold with no product surface. Eligibility alone is not enough: before Private→Public, owner must complete the pre-public privacy/sensitive-history scan checklist (local release-handoff); Cursor reminds only and must not run the scan. | Main Browse Screen (or first capability after it that ships a real feed) | — |
| iOS Photos permission | Typography text-style tokens (5.1 ships color tokens only; M3 default TextTheme) | Color-first keeps 5.1 small; type scale locks when heavy content UI lands | Main Browse Screen | ADR-009 |
| iOS Photos permission | NSPhotoLibraryUsageDescription is PLACEHOLDER copy | Final permission wording is owner-only (release-handoff) | TestFlight internal testing | — |
| iOS Photos permission | List-time availability via undocumented PHAssetResource KVC `locallyAvailable` | No public isLocallyAvailable on PHAsset/PHAssetResource in the iOS SDK | Final real-device performance, memory, accessibility, privacy, and error-state hardening (or when Apple exposes a public API) | — |
| Cap 6 / library_smoke | Library Totals Shell error row uses raw exception string (`'${asyncTotals.error}'`), not ARB | Predates ADR-012 smoke hardening; Cap 6.4 left untouched on purpose | Settings and localisation completion | ADR-012 |
| Main Browse Screen | No architecture scan for hardcoded `TextStyle(` in `lib/features/**` (typography tokens exist; `Color(0x` still scanned) | Cap 7.2 locked type roles without a TextStyle literal guard; easy to bypass tokens while 7.4–7.7 chrome lands | Settings and localisation completion | ADR-009 / ADR-014 |
| Main Browse Screen | Video page swipe may flash one frame of the previous video | Shared 1+1 AVPlayer + single Platform View (ADR-006); Cap 7.7 observe-only (always-on; orthogonal to hang — see `cap7-7.7-notes.md`) | Final real-device performance, memory, accessibility, privacy, and error-state hardening | ADR-006 |
