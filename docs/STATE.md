# WakeTok — Engineering State

> Current engineering state. Read this FIRST before starting work in a new chat.
> Maintenance: facts only, no history. Update = rewrite the relevant line.
> NEVER append paragraphs here.
> Conflict priority: code/git > this file > DECISIONS.md > local kickoff (if present).
> History / rationale -> DECISIONS.md. Completed capability phase snapshots -> docs/PHASE_HISTORY.md.
> Private product spec -> docs/WakeTok(App)_project_kickoff.md (local only, gitignored, READ-ONLY for AI tools).

## Project facts
- Product: WakeTok — local-first personal media Rediscovery Player (iOS; Flutter UI + Swift native media layer)
- Flutter project name: `waketok`; device display name: WakeTok
- Bundle ID: `com.dennycgan.waketok` (ASC registration = owner-only; see release-handoff.mdc)
- iOS deployment target: Flutter default (placeholder; finalize after POC-04)
- Test devices: iPhone 13 (performance floor), iPhone 17 (current-device compat)
- No backend, no custom auth, no remote database, no developer-owned media server (kickoff Tech Stack)

## Capability Roadmap (project-level; top-to-bottom = execution order; YOU ARE HERE)
- [~] Project Bootstrap (flutter create scaffold, pigeon/ placeholder, docs skeleton, root commit)   <-- YOU ARE HERE
- [ ] POC-04: Flutter Media Feed Architecture Gate (must pass before ANY business-layer code)
- [ ] POC-03: Lock-screen continuous playback gate (must pass before ANY business-layer code)
- [ ] iOS Photos permission, Library access, iCloud asset state handling
- [ ] Main Browse Screen and vertical Media Feed
- [ ] All / Photos / Videos built-in source browsing
- [ ] Media Info Overlay, loading states, empty states
- [ ] Asset Source and Source Pool Definition base models
- [ ] Build a Pool, temporary Pool, Source ordering
- [ ] Live Resolution, Identity Coalescing, Resolved Pool Snapshot
- [ ] Saved Pool save / reopen / manage / count limit
- [ ] Session Queue, default Session Profile, Ordering Semantics
- [ ] Endless Shuffle, Queue Stability, Session Continuity
- [ ] Auto-play Presets and Mode Eligibility Rule
- [ ] One-item Lookahead Fetch, Waiting for Media, iCloud Fallback
- [ ] Background Audio, lock-screen playback, system media controls
- [ ] Fixed 2-minute physical clip export pipeline
- [ ] Real Photos Album, Clip Descriptor, Generated Clip Source
- [ ] Clip task progress, failure, cancel, resume
- [ ] Share, Mute, Fit / Fill / 9:16 Crop, 2x gesture
- [ ] Settings, Chinese/English localisation
- [ ] Session Recovery, error states, real-device performance validation
- [ ] Add to Album (Full Access only; the only pre-authorized downgrade-to-1.1 item)

> Each line is a capability, not a sub-step. Completed capabilities stay one line
> (phase snapshots -> docs/PHASE_HISTORY.md). Only the ACTIVE capability is
> expanded in the Phase Roadmap below.
> Remaining POCs (POC-01/02/05–09) run inside the capability that needs them, per kickoff.
> Top-to-bottom = current execution order. Reorder if priorities change; never leave it unordered.

## Phase Roadmap (active capability only)
Active capability: Project Bootstrap
- [x] 1.1 Reset docs/STATE.md + docs/DECISIONS.md to WakeTok skeletons (owner reviews full text before write)
- [x] 1.2 Environment check: flutter --version + flutter doctor (Flutter 3.41.9 stable, Dart 3.11.5, Xcode 26.3, CocoaPods 1.16.2)
- [x] 1.3 Scaffold: flutter create --project-name waketok --org com.dennycgan . ; merge Flutter default .gitignore + keep .cursor/kickoff rules; add pigeon/.gitkeep; bundle id com.dennycgan.waketok
- [x] 1.4 Smoke check: flutter analyze ✅ (No issues found); flutter run on iPhone 17 (iOS 26.3) ✅
- [ ] 1.5 Root commit (git commit-tree, no -p) + push — two-step gates per git-commit-push.mdc

> Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline
> When the active capability changes, replace this entire Phase Roadmap with the
> new capability's phases and move YOU ARE HERE above.

## Now working on (describe ONLY the in-progress item)
- Goal (one line): stand up the Flutter/iOS scaffold so POC-04 can start
- Sub-steps done: docs skeletons; env check; flutter create; pigeon/.gitkeep; platform trim; analyze; iPhone 17 simulator launch
- Next step: phase 1.5 root commit — show diff/status for owner OK before git add/commit
- Related decisions: ADR-001 planned at Bootstrap Commit 1 (bundle ID; deployment-target deferral)

## Contract pointers (don't memorize, go read the source)
- Domain terms (canonical, bilingual): docs/GLOSSARY.en-zh.md
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/ (empty until POC-04)
- (grows as code lands)

## Do NOT touch (unless explicitly opening a new phase)
- docs/WakeTok(App)_project_kickoff.md — owner's private spec, READ-ONLY for AI tools
- (grows as fragile areas appear)

## Known debt / intentionally deferred
| Capability | Item | Reason | Picks it up | Related ADR |
|---|---|---|---|---|
| Bootstrap | iOS deployment target left at Flutter default | Kickoff Open Question: platform target TBD; decide with real-device data | POC-04 | — |
