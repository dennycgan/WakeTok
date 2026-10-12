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
- Product: WakeTok — local-first vertical rediscovery of the user's own
  photo/video library (iOS; Flutter UI + Swift native media layer).
  Internal keyword: local-first vertical rediscovery
  (= on your device · swipe · your library). Engineering term
  `vertical feed` OK in code/ADR/STATE; external copy prefers
  `vertical scrolling app` / plain “what it does” (see MVP track).
- Flutter project name: `waketok`; device display name: WakeTok
- Bundle ID: `com.dennycgan.waketok`
  - Explicit App ID registration in Certificates, Identifiers & Profiles: owner-only
  - App Store Connect app-record: created — App name `WakeTok` reserved
    (primary language English (UK)); further ASC configuration remains owner-only
  - See `release-handoff.mdc`
- iOS deployment target: iOS 18.0 (see ADR-007; ADR-005 superseded)
- Test devices: iPhone 13 (performance floor), iPhone 17 (current-device compat)
- Floor: local-first, no account, no upload — no backend, no custom auth,
  no remote database, no developer-owned media server (kickoff Tech Stack)
- Repository visibility: Public (2026-10-10; source published for review, all rights reserved)
- Repository history: rewritten **2026-09-04** to remove the local-only
  glossary from all git history. Commit SHAs before that rewrite are obsolete;
  docs anchors were batch-remapped via the filter-repo commit map.
- Owner-approved public-presentation exception (**2026-10-09**):
  selected completed PHASE_HISTORY wording was minimally rewritten before
  repository publication to remove personal and commercial context,
  private-library assertions, and unnecessary local-backup details.
  Technical evidence was retained. Git history was not rewritten;
  technical outcomes, phase status, and commit anchors were preserved.
- Re-verify Host pinch hit-test notes after Flutter SDK upgrades
  (Scrollable `DragScrollActivity.shouldIgnorePointer`).
  Same fragility family first observable symptom: debt **458**.
- Browse brief action feedback: use Cap 19 `showCap19BrowseToast` (top
  overlay under source chrome). Do **not** use Material bottom `SnackBar`
  for success/error toasts (Cap 19.5b owner §7 item 7; welded convention).
  Machine-guarded: `test/architecture/dependency_test.dart` fails on
  `SnackBar(` / `.showSnackBar(` under `lib/features/**` and `lib/app/**`
  (ADR-009 Enforcement — not owner-only post-capability audit).
  Toast top inset uses `MediaQueryData.fromView(View.of(context)).viewPadding`
  (not `MediaQuery.padding` / inherited `viewPadding`) so callers under
  top-chrome `SafeArea` — which zeroes both inherited paddings — match
  feed/left-swipe Y.
  Centered `AlertDialog` (naming / capacity / Info / delete) is orthogonal.

## Capability Roadmap (project-level; top-to-bottom = execution order; YOU ARE HERE)
> Last reviewed: 2026-10-09. This is a planning snapshot, not a release-date
> or schedule commitment. Candidate scope may change. Listed in intended
> order; the owner may reorder when a capability opens.

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
- [x] Display magnification (pinch to zoom, lightweight) (Cap 20 /
      ADR-043; L2 still persistent + Reset; L1 + video L2 transient;
      D5=4×; `docs/acceptance/cap20-*.md`; PHASE_HISTORY)
- [x] Build a Pool, Ephemeral Pool, and Source ordering (Cap 21 /
      ADR-044…045; `docs/acceptance/cap21-*.md`; PHASE_HISTORY)
- [x] Saved Pool persistence, reopen, management, and capacity limits
      (Cap 22 / ADR-046…048; `docs/acceptance/cap22-*.md`;
      PHASE_HISTORY)
- [x] Current-asset still-in-library gate for mutation chrome
      (Cap 23 / ADR-049 Accepted; `docs/acceptance/cap23-*.md`;
      PHASE_HISTORY; debt **456b** Closed at 23.4)
- [x] Soft-delete current asset to Photos Recently Deleted
      (Cap 24 / ADR-050 Accepted; App soft-delete only; kick Session
      Queue on success; fail-closed on Host failure; narrow-supersede
      kickoff Do Not Build #4 delete bans + P1–P5; after still-in-library
      gate; PHASE_HISTORY)
- [x] Share current asset from Action Column
      (Cap 25 / ADR-051 Accepted; Q1=B …=0 Share=1 Album=2;
      Cap 23 gate; system share sheet; D14 enable + D15
      saveToCameraRoll exclude; PHASE_HISTORY)
> **MVP v1 submission track** — minimal closed loop for first App Review.
> Slogan (detail page / web first line only — not App Store Subtitle):
> "Wake what you saved — A local-first vertical scrolling app for
> rediscovering your own photo and video library." App Store Subtitle:
> deferred to pre-submission metadata (plain “what it does” in a few seconds; not
> slogan rhetoric).
> V1 stack: L1 form (own-library full-screen vertical swipe / rediscover)
> > L2a (choose what: Create/Saved pools; how ordered: bottom Order —
> shuffle / newest / oldest, default shuffle) > L3 in-swipe light actions
> (WakeTok-album bookmark, Favorites, add-to-album, soft-delete, share).
> Floor: local-first, no account, no upload (privacy/description must
> state; slogan alone does not carry it). External: avoid bare
> `vertical feed`, `manage`, control-name piles. L2b (clips / background
> lock-screen / SessionCheckpoint recovery) = post-v1 only — not v1 messaging.
> V1 sells L1 + L2a + floor; L3 = organise, share or delete as you go.
> After First-launch
> vertical-swipe guidance Cap: no new product behaviour for v1 — debug /
> fix / non-behaviour polish + metadata only. Clips / dedicated Auto-play
> = post-v1 track below.

- [x] Live Photo long-press replay + "…" half-sheet size field
      and Add-to-Album second entry
      (Cap 26 / ADR-052 Accepted `cab0747`; ADR-053 / ADR-054;
      debt **439** Closed; `docs/acceptance/cap26-26.6-notes.md`;
      PHASE_HISTORY)
- [x] Auto bottom-nav slot redefinition — pull-up order-control sheet
      (Cap 27 / ADR-055–057 Accepted; Layer 1 confirm-to-apply;
      Temp peek promote keep-Session; Clips/Auto off bar; ADR-027
      leave → Settings only; `docs/acceptance/cap27-27.6-notes.md`;
      PHASE_HISTORY; debt **478** remains Open)
- [x] Leave Browse keep queue progress + Browse meta hide toggle
      (Cap 28 / ADR-058 Accepted `2c6e3b3`; Settings keep +
      `settingsResume` + A′; access-scope authority; process-only meta
      hide; `docs/acceptance/cap28-28.8-notes.md`; PHASE_HISTORY;
      debts **480** / **481** remain Open)
- [x] Debt 421 — Limited Access manage entry restored
      (Cap 29 / ADR-059 Accepted `8ac86db`+`804eb42`; Settings Photos
      Access Manage + Open Settings; D10 consume cache clear + index 0;
      `docs/acceptance/cap29-29.4-notes.md`; PHASE_HISTORY; debt **421**
      Closed; **480** / **481** remain Open)
- [x] First-launch Browse guidance
      (Cap 30 / ADR-060 Accepted `da33d41`+`524b28b`+`53860fd`+
      `21ba370`+`0897ce5`; `<1>`→`<2>` once per install; D6 vs Cap 19;
      D7 Browse↔Settings copy; per-step durations; outward `<2>` caret
      `057deb9`; notes `docs/acceptance/cap30-30.7-notes.md`;
      PHASE_HISTORY; debts **480** / **481** remain Open)
- [x] Pre-v1 bug fix and UI polish sweep
      (Cap 31 / ADR-061…ADR-071 Accepted; Settings hierarchy; Live
      album cases + share + still render; video handoff; probe cleanup;
      competitor-codename scan; light Release smoke `3482826` i17 +
      Kafka PASS; notes `docs/acceptance/cap31-31.7-notes.md`;
      PHASE_HISTORY)
- [x] MVP v1 pre-submission hardening
      (Cap 32 / ADR-072…ADR-074 Accepted; Settings About Privacy Policy
      row + `ITSAppUsesNonExemptEncryption` false; animated stills keep
      original bytes; sqlite3 privacy manifest; `waketok-site` privacy
      and support pages; device check i17 + iPhone 13 Pro; archive
      `1ae7f42`, build 1.0.0 (1); PHASE_HISTORY)
- [x] TestFlight internal testing and release-candidate validation
      (Cap 33; build 1.0.0 (1) from archive `1ae7f42` on TestFlight, no
      ITMS email; ASC forms saved; 147 regions — China mainland and the
      EU excluded; DSA status declared "not a trader" for v1; re-assess
      before adding EU availability, introducing monetisation, or after
      a relevant business-status change; no Apple silicon Mac or Vision
      Pro; five checks and the review recording (Full access) on i17; no
      code change; PHASE_HISTORY)
- [x] App Store metadata, screenshots, privacy disclosures,
      submission, and release verification
      (Cap 34; build 1.0.0 (1) submitted 2026-10-07; one Guideline 2.1
      information request answered with a new physical-device
      recording and the same binary resubmitted 2026-10-08; approved
      and live on the App Store by 2026-10-09; English-only store page;
      README App Store link; no code change; PHASE_HISTORY)
- [x] Publish the repository as source-available, all rights reserved
      (public 2026-10-10 after the pre-public checks; not an
      open-source release; debt **419** Closed; no code change;
      PHASE_HISTORY)
- [ ] v1.0.1 update (Cap 35): third-party licences page, iPhone SE
      permission-button layout, permission-page app name at large text
      sizes, app text fixed at the default text size, single-item
      vertical-feed rubber-band scrolling; build 1.0.1 (2). Changes the
      closed Cap 32 Settings page, the closed Cap 31.4 permission pages
      and text sizing on every screen. See Platform gate.
      <-- YOU ARE HERE
- [ ] V2 — album search in Add to Album and Build a Pool (candidate)
- [ ] V2 — Open the current item in the All / Oldest-first timeline
      (candidate; from the current item's "…" half-sheet, switch to
      the built-in All source, apply Oldest first, land on the same
      item in the complete timeline, and continue vertical browsing.
      Oldest first remains the process-wide preference until the user
      changes it. The normal path must locate the item; if an external
      library change makes it unavailable during the transition, keep
      the original source and order and show a top Browse toast.)
- [ ] V2 — immersive landscape browsing (candidate)
- [ ] V2 — theme choice: System, Light or Dark (candidate)
- [ ] V2 — system per-app language selection (candidate)
      (include bundle localisation declarations, the zh-Hans store
      page and screenshot captions, zh-Hans privacy and support pages,
      and localised system permission strings; requires a new ADR
      revisiting ADR-062. Undecided: whether the in-app privacy link
      opens the zh-Hans page when the app runs in zh-Hans.)
- [ ] V2 — simplified app icon (optional candidate)
- [ ] V2 — custom-domain migration for privacy and support pages
      (optional candidate; includes a new app build to update the
      in-app privacy link in `app_links.dart`; update the App Store
      Connect privacy policy and support URLs and the README links in
      the same pass, checking at that time which App Store Connect
      fields need a new app version. ADR-072's statement that
      the legacy github.io URLs redirect after cut-over was not
      confirmed in current GitHub documentation; test both live legacy
      URLs before changing any published URL. Domain `waketok.app`
      registered at Porkbun on 2026-10-10 to reserve the name only
      (expires 2027-10-10, auto-renew on, WHOIS privacy on); no
      published URL uses it yet; migration timing undecided (V2 or
      V3).)
- [ ] Android — port V2 as shipped on iOS
      (planned after V2; distribution TBD: GitHub APK or Google Play.
      Open Android-specific STATE and decision records when work
      starts, after owner-approved rule changes define authority,
      decision numbering, and conflict handling for shared domain
      behaviour.)
- [ ] V2.1 — location information for the current item
      (candidate; resumes debt **401**)
- [ ] V2.1 — Hide the current item in Photos
      (candidate; requires a new ADR narrowly overturning only the Hide
      limb of debt **469**; permanent purge remains forbidden)
- [ ] V3 and later
      (candidate umbrella; details in the unsequenced backlog below)

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

## Platform gate (outside the release sequence)
- [ ] Xcode 27 / iPhone Duo readiness
      (required before any upload or submission from April 2027 (as of
      2026-10-08: Apple, 2026-09-09: uploads from April 2027 must use
      the iOS 27 SDK; Apple, 2026-10-05: submissions from April 2027
      must include iPhone Duo screenshots). Until this gate is
      complete, releases, including v1.0.1, build with Xcode 26.3
      (iOS 26.2 SDK) and are uploaded and submitted before April
      2027. Re-check Apple's current requirements (news, App
      Store Connect release notes, screenshot specifications) before
      design starts. Apple's Tech Talk says the inner display does not
      honour supported interface orientations; verify that behaviour
      in the iPhone Duo simulator before treating it as settled for
      WakeTok. If the lock is not honoured, layouts must handle
      landscape and regular size classes. This gate is not tied to
      v1.0.1; if v1.0.1 slips past April 2027, complete this gate before
      v1.0.1.)

## V3 and later / Clips candidate backlog (unsequenced)
> Not in first Review scope.
> Big picture: same L1; V1 = L1+L2a+floor (L3 = organise, share or
> delete as you go);
> this track deepens L2b (clips / background·lock-screen /
> SessionCheckpoint recovery, …)
> — not a new product shape (not clip-editor / podcast). Distinct
> TestFlight / App Store items below are a separate release event (Clip /
> background privacy disclosures etc.), not a merge of the v1 track.

- Type filter within a pool or source (candidate)
- Auto-play Presets and Mode Eligibility Rule
  (Layer 2/3 only: autoplay on/off + autoplay-internal ordering
  e.g. single-asset replay; bottom-nav Auto destination nature is
  already decided in "Auto bottom-nav slot redefinition" above —
  this Cap owns eligibility rules and Layer 2/3 settings only.
  Those settings are **not** a second line on the bottom Order
  slot — Order stays Layer 1 only. UI is a later media-area
  indicator; see layout notes §11.4.7 item 4 and re-evaluate when
  this Cap is scoped.
  Paired with Clips v2; leave-Browse keep already satisfied by Cap 28
  (v1))
- Auto-play One-item Lookahead Fetch, Waiting for Media, and
  iCloud Fallback
  (renamed so "iCloud Fallback" is Auto-play / ADR-O, not Cap 14)
- Background Audio, lock-screen playback, system media controls
- SessionCheckpoint and Session Recovery
  (Queue, current Media Item, playback position,
  Waiting for Media, and process-termination contract)
- Physical Clip Export Core
  (fixed 120-second segments, POC-06 and POC-07,
  persistent Export Job / Segment state machine,
  cancellation and recoverable partial success;
  includes ClipExportApi Pigeon contract design,
  deferred from App Foundation)
- Photos import, backing Album, Clip Descriptor,
  and Generated Clip Source
- Clip export progress/result UI,
  failed-segment retry, cancellation, and resume UX
- Mute, Fit / Fill / 9:16 Crop, 2x gesture
  (Share already shipped Cap 25; tap-to-pause/resume Cap 18; MVP 2x
  = left or right edge hold temporary 2x, release → 1x; no
  slide-down lock; Cap 18 froze edge-hold slots only)
- Settings and localisation completion
  (remaining English / zh-Hans copy sweep; privacy / storage /
  about screens — the Privacy Policy link row already ships in v1
  (Cap 32, ADR-072), the full screens stay here; Light/Dark layout
  verification — verify against
  Cap 31 Settings hierarchy/weight layout, not the pre-31 layout;
  Limited Access manage entry already completed in the Debt 421 Cap above)
- Monetisation planning and EU availability decision
  (placeholder; decision only, no code. Decide whether to
  monetise at all. Re-assess the DSA trader status and decide EU availability in
  the same pass (see Cap 33.1). Any monetisation reopens App
  Privacy (Data Not Collected), ATT, the privacy policy, the age
  rating, ADR-072 and the store listing copy; an implementation,
  if chosen, gets its own Cap)
- Final real-device performance, memory,
  accessibility, privacy, and error-state hardening
  (full-product / post-Clips pass; distinct from MVP v1 hardening)
- TestFlight internal testing and release-candidate validation
  (post–v1 / Clips track; owner executes distribution; the agent
  prepares build and metadata)
- App Store metadata, screenshots, privacy disclosures,
  submission, and release verification
  (post–v1 full-product Review — Clip / background privacy
  disclosures etc.; owner executes submission; the agent prepares
  assets only)

## Phase Roadmap (active capability only)
Active capability: v1.0.1 update (Cap 35).
Contract: five small fixes ship as v1.0.1, build 1.0.1 (2); each
code phase is a work commit plus a docs commit. The owner uploads,
submits and releases; the agent prepares builds and notes only.
Legend: [x] done  [~] in progress  [ ] todo  (blocked) noted inline

- [x] 35.1 Third-party licences page
      (Settings About gains a "Third-party licences" row that opens
      Flutter's `LicensePage`, pushed by the app with a route-local
      en_GB override so the title reads "Licences"; header shows the
      app name only; inline `Icons.arrow_forward_ios` glyph next to the
      title, button semantics; new en / zh-Hans copy. Audit of the
      Release bundle: Dart packages, Flutter engine, plugin native code
      (CocoaPods only, no Swift packages), sqlite3 and the CupertinoIcons
      font are covered by Flutter's generated notices; the Material
      Icons font is not, so its CC BY 4.0 notice is registered at the
      composition root; app icon is owner-designed. Device check on
      iPhone 13 Pro, Release, Light and Dark, en and zh-Hans; ADR-075
      amends ADR-072 D1)
      — work `3a368e5` + `a22ad9a`
- [x] 35.2 iPhone SE permission-button layout
      (button padding 16 horizontal / 12 vertical in
      `permission_page_style.dart`, so the English request label fits
      one line on a 375 pt SE at the default text size; a wrapped label
      is centred (`textAlign` on the label in both pages) and the
      button grows. Both permission pages scroll when content is taller
      than the screen (they overflowed at accessibility text sizes);
      the scroll view is not primary, so a page that fits stays static
      with no drag or bounce. W-35.2-1 to W-35.2-5. Simulators: iPhone
      SE (3rd generation) iOS 26.3 (en and zh-Hans, default to the
      largest accessibility size) and iOS 18.0 (en); iPhone 13 Pro iOS
      26.3 regression unchanged apart from sub-pixel label
      anti-aliasing; iPhone 16 iOS 18.0 request page clears the Dynamic
      Island at large text. Overflow checked with a debugger attached
      (before: 63 px; after: none); label centring measured on
      screenshots, within 1–2 physical pixels. Device: Kafka iOS 26.6,
      Release, English, request and blocked pages: one-line centred
      label, no drag or bounce. Evidence limit: the 375 pt layout is
      proven on simulators only (no SE device), and the iOS 18.0 checks
      have no device comparison)
      — work `62ef098`
- [x] 35.2b App name word break at accessibility text sizes
      (on both permission pages the one-word app name split mid-word
      once wider than the page: from the second accessibility size on
      a 375 pt SE, from the third on 390–430 pt iPhones. Fix:
      `PermissionPageStyle.appNameFitted` measures the name at the
      current text size (Bold Text included) and, when it is wider than
      the page, scales its font size and letter spacing down to the
      page width; the name stays a plain one-line `Text` and is
      unchanged when it fits (section 16). The planned `FittedBox` with
      `LayoutBuilder` was dropped with owner OK: the 35.2 scroll shell's
      `SliverFillRemaining` asks for intrinsic heights, which
      `LayoutBuilder` cannot answer and `FittedBox` reports at the
      unscaled, wrapped size. VoiceOver reads one "WakeTok" element; its
      frame is the one-line text box across the page width. W-35.2b-1
      and W-35.2b-2. Simulators: iPhone SE (3rd generation) iOS 26.3,
      en and zh-Hans, request page at every accessibility size and
      blocked page at the largest: one line, ink inside the page edges;
      iPhone 13 Pro iOS 26.3 at the default size, request and blocked
      pages, en and zh-Hans: pixel-identical to before. Device: Kafka
      iOS 26.6, Release, English, largest accessibility size with Bold
      Text: request and blocked pages one line, VoiceOver reads the name
      once with a one-line frame, licences page header one line.
      Evidence limit: the licences page header was checked on the
      390 pt device only; on a 375 pt SE it is an estimate (fits with
      about 20 pt to spare))
      — work `2e5f566`
- [x] 35.2c App text ignores the iOS text size and Bold Text settings
      (debt **490**, closed; found 2026-10-11 during the 35.2b device
      check: at the largest accessibility text size the Browse top bar
      labels overlapped, the bottom bar labels clipped at different
      sizes, and the date and loading text overlapped; present since
      v1.0.0. Cause: every `Text` followed the system text size and
      Bold Text while the layout uses fixed point sizes. Baseline: the
      iOS default text size (Large, text scale 1.0) with Bold Text off
      (ADR-076; `media-chrome-layout-notes.md` section 18). Fix:
      `appRootBuilder` in `MaterialApp.builder` turns off text scaling
      and the framework Bold Text for every page, dialog, half sheet
      and overlay; no token or theme change; no change at the default
      size. iOS Bold Text still draws Latin letters and digits about one
      weight step heavier, and wider, at the same size and position; the
      system font is fixed when the app process starts (Flutter engine,
      flutter/flutter#162804; debt **491**). The 35.2 and 35.2b code
      stays: `appNameFitted` is inactive at runtime; the 35.2 centred
      wrapped button label still applies when Bold Text wraps it. The
      shared permission UI test harness keeps the previous builder
      unless `appTextBaseline` is set, so no closed-Cap test changed.
      Out of scope: Display Zoom, Smart Invert, colour filters and
      system screens (Photos prompt and picker, share sheet).
      W-35.2c-1, W-35.2c-2. Acceptance: at the largest accessibility
      size pixel-identical to the default size; with Bold Text added no
      overflow or overlap. Simulator: iPhone SE (3rd generation) iOS
      26.3, en and zh-Hans, real photos and a video; Browse photo with
      date text, the Order half sheet, the newest item and Settings
      pixel-identical at the largest accessibility size; the video
      differs only in playback time, progress and decode noise; with
      Bold Text no overflow or overlap (Chinese glyphs unchanged); at
      the default size pixel-identical to the previous build. Device:
      Kafka (iPhone 13 Pro, iOS 26.6), Release, English, launched with
      the largest accessibility size and Bold Text on: permission page,
      first-launch tips, Browse photo and video, top bar menus and a
      toast, half sheets, a dialog, Settings, licences page and Build a
      Pool, no overflow or overlap. Bold Text off (owner re-check
      2026-10-12): turned off while the app runs, the text stays bold;
      after a force quit and reopen it is back to regular weight. App
      Store Connect App Accessibility has never been configured (owner
      checked 2026-10-11), so v1.0.1 withdraws no Larger Text claim.
      Evidence limit: zh-Hans was checked on the simulator only; with
      Bold Text the 375 pt layout was checked on the simulator only
      (Kafka is 390 pt))
      — work `98c7e77`
- [x] 35.3 Single-item vertical-feed rubber-band scrolling
      (with one item in the queue (a one-item pool or Limited
      selection) a vertical drag did not move the feed: one page has
      no scroll extent, so the default physics refused the drag;
      present since v1.0.0. Fix: when not magnified, the feed
      `PageView` uses `AlwaysScrollableScrollPhysics` for every queue
      length (ADR-077); two or more items unchanged (page snap,
      W-35.3-6); a soft delete from two items to one keeps the same
      scroll position (W-35.3-8); magnification still locks the feed.
      Chrome stays visible during the rubber band, as on a multi-item
      first-item pull-down. Debt 458 note. W-35.3-1 to W-35.3-8.
      Device: i17 (iPhone 17, iOS 27.0.1), Profile, installed with
      Xcode 26.3. (a), (b) and the single-item gesture regressions on
      both one-item setups: a one-photo Limited selection and a
      one-item pool built with Build a Pool; (c) on a fresh install
      with a one-photo Limited selection only (`<1>` shows once, on
      the first ready Browse item, before any pool can exist).
      (a) Still, video and Live spring back to the same item
      in both directions, slow drag and fling, with no endless-round
      advance; video keeps playing; Live does not replay. (b) A
      magnified still or video does not move the feed. (c) The rubber
      band does not end Cap 30 `<1>` early; `<1>` ends on its 2 s
      timer, `<2>` follows, and the guide neither stalls nor skips a
      step. Single-item gestures, multi-item paging, Limited add and
      remove, and soft delete regressions passed. (c) was not deferred
      to 35.4)
      — work `c466f2d`
- [ ] 35.4 Release candidate and TestFlight
      (`pubspec.yaml` 1.0.1+2; archive; owner checks the used version
      and build numbers in App Store Connect Activity and uploads; RC
      checks on the TestFlight build)
- [ ] 35.5 Submission, App Review, release verification and close-out
      (owner submits and releases; after v1.0.1 is live, update README:
      the first Roadmap line says version 1.0.1 is available on the App
      Store, the planned-v1.0.1 line is removed, and the Last reviewed
      date is updated; PHASE_HISTORY snapshot)

## Now working on (describe ONLY the in-progress item)
- Goal (one line): Cap 35 — ship v1.0.1 (licences page, SE permission
      button, app name word break, fixed app text size, single-item
      rubber band)
- Sub-steps done: phases 35.1–35.5 approved (v1.0.0 is live on the
      App Store); 35.2c added 2026-10-11; 35.1 done (ADR-075); 35.2
      done (`62ef098`); 35.2b done (`2e5f566`); 35.2c done (ADR-076);
      35.3 done (ADR-077)
- Next step: 35.4 Release candidate and TestFlight
- Related decisions: ADR-077 Accepted (one feed physics type for every
      queue length, single-item rubber band);
      ADR-076 Accepted (app text at the iOS default
      text size, Bold Text off — debt **491**); ADR-075 Accepted (in-app third-party licences
      page, Material Icons notice); ADR-072 Accepted (Privacy Policy
      link, export key); ADR-073 Accepted (animated stills keep original bytes in
      the Layer 2 temp); ADR-074 Accepted (sqlite3 privacy manifest
      build phase); ADR-062 Accepted (system-only language, English
      permission prompt); ADR-064 Accepted (still share without
      location; video unchanged — debt **484**); ADR-070 Accepted
      (iPhone-only v1); ADR-028 (portrait-only); ADR-007 (iOS 18.0
      floor — debt **416**)

## Contract pointers (don't memorize, go read the source)
- **BrowseSession ↔ Origin (ADR-057 D6):** `BrowseSessionNotifier` must
  `listen` `activeOrigin` and read `browseOriginSessionDeltaProvider` —
  promote → no-op; real boundary → `restartSession`. **Do not**
  `watch(activeOrigin)` on Session (reload/`isReloading` tears down
  PageView and can jump feed index to 0 while Queue order is unchanged).
  Sticky `feedDataSourceId` is a separate switch (ADR-057 D5).
- Domain terms (bilingual, **local only / gitignored**):
  docs/GLOSSARY.en-zh.md — not published; Cap-frozen terms also in
  DECISIONS.md (e.g. ADR-043 Display Magnification)
- Completed phase snapshots: docs/PHASE_HISTORY.md (append-only)
- Pigeon contracts: pigeon/waketok_platform_apis.dart → lib/platform/generated/, ios/Runner/Platform/ (spike under pigeon/spikes/ reference only)
- l10n: lib/l10n/ (ARB + AppLocalizations; locale_resolution.dart; untranslated_messages.json)
- Photos permission pages (shared style, auth source): docs/reference/media-chrome-layout-notes.md §16
- **zh Pool product copy:** Cap 7 / Cap 21 chrome+Build zh ARB strings
  use the Cap 7 pool product-copy convention (`mainBrowsePoolsTab`,
  `mainBrowseCreatePool`, Temp chip, Saved placeholders). Kickoff /
  GLOSSARY concept term and English **Pool** are concept / EN-ARB /
  identifier vocabulary only — do not put EN “Pool” or the kickoff
  concept term into `app_zh_Hans.arb` product strings (Cap 22 Saved
  copy too). Debug `library_smoke` probe strings may still say Pool.
  (Do not paste locale glyphs into STATE — cite ARB keys.)
- **Ephemeral / Saved pool `feedSourceKind`:** any
  `BrowseOriginEphemeralPool` or `BrowseOriginSavedPool` maps to
  `AssetSourceKind.entireLibrary` (`BrowseChromeState.feedSourceKind`;
  ephemeral work `74c84e1`; Saved `saved:$poolId` feed id in `4db65ec`).
  Feed Layer 2 / Live / video fallback only know built-in
  kinds; passing `album` / `smartAlbum` hard-fails every item (L1 still
  OK). Not a product fork — restores the mixed-content probe contract.
  U-21.4-11 locks ephemeral. No separate ADR (ADR-044 already Accepted).
- **Limited / empty Build catalog:** Cap 21.4b catalog lists **user
  albums** (My Albums) + **curated system albums** (whitelist ∩
  non-empty). Limited (or any grant with zero listable user albums and
  zero visible system albums) shows the empty catalog copy — Start stays
  disabled. Cap 21.5 (`80128a3`): Create is **disabled** under Limited
  with `mainBrowseCreatePoolRequiresFullAccess` caption. Cap 21.5 ZH Full
  Access root wording follows Cap 5.3 `limitedAccessBannerMessage` (not
  Cap 19.5b). Cap 19.5b `cap19PanelAddToAlbumLimitedMessage` still uses a
  different Full Access phrasing — known drift, not fixed in the Cap 21.5
  copy-align follow-up (leave for a later localisation sweep). Expected:
  Build-a-Pool is effectively unusable until Full Access + listable
  sources; browsing All / Photos / Videos remains via top Built-in tabs.
  Built-ins stay omitted from the Build list (Accepted deviation vs
  ADR-044 §11). Boundary table:
  `docs/reference/cap21-smart-album-boundary.md`.
- **`assetSourcesProvider` list lag (Cap 21.5 / Cap 22):**
  Album-catalog data updates only when the FutureProvider is actively
  (re)read after invalidate — it does **not** auto-observe Photos library
  mutations. Cap 21.5 invalidates on Build open. Cap 22 Saved list /
  Info / chip peek also invalidate on open (ADR-046 D8) — debt **455**
  **Closed by Cap 22**. Session/Queue lag remains ADR-027 / ADR-023 D7
  (orthogonal).
- **Cap 21.4b smart-album boundary (live maintenance):** dead whitelist /
  exclude table + live emptiness / brute-enum rules —
  `docs/reference/cap21-smart-album-boundary.md`. New iOS subtypes do
  **not** auto-join; owner edits the table + ARB deliberately. Work
  `67cb08b`.
- PhotoKit implicit behaviors: multi-surface Live/Animated identity
  mismatches (`mediaSubtypes` vs `playbackStyle` vs smart-album
  membership), `PHLivePhotoView` natural-end callback not guaranteed,
  plus other implicit Host index:
  `docs/reference/ios-photokit-implicit-behavior-notes.md`
  (debt **471**; ADR-052 D11; ADR-053; ADR-063)
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
  (`aa03be8` / ADR-023);
  media-area chrome layout (Reset / LIVE / actions / MVP 3-row meta):
  `media_chrome_layout.dart` + work `81904e1`; notes
  `docs/reference/media-chrome-layout-notes.md` (not Cap 20–only; not ADR-043)
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
- ADR-046: Cap 22 Saved Pool persistence — **Accepted** (2026-09-08),
      anchor `d62e962` (Cap 22.2 work); D3/D5/(D7 clear-park clause)
      narrowly superseded by ADR-047
- ADR-047: Cap 22 Build Save & browse + entry-point recipe shells —
      **Accepted** (2026-09-09), anchor `0b68e01` (Cap 22.4
      supplemental; first chrome `0ca1198`)
- ADR-048: Browse Snapshot cache — invalidate on successful in-app
      album membership writes — **Accepted** (2026-09-10), anchor
      `fbf2e82`
- ADR-049: Cap 23 current-asset still-in-library mutation gate —
      **Accepted** (2026-09-10), anchors `32a3617` (23.3) + `4004ad1`
      (23.2) + `893c8fb` (23.4 Case B harden); Proposed `25689b0`
- ADR-050: Cap 24 soft-delete current asset to Photos Recently Deleted —
      **Accepted** (2026-09-10), anchor `32d4bd1` (24.2 Host write;
      related Cap 24 work in PHASE_HISTORY)
- ADR-051: Cap 25 Share current asset from Action Column —
      **Accepted** (2026-09-12), anchor `99c2e73` (25.2 Host present;
      related Cap 25 work in PHASE_HISTORY)
- ADR-052: Cap 26 Live long-press replay + "…" size + Add-to-Album
      second entry — **Accepted** (2026-09-15), anchor `cab0747`
      (26.2 Path R/S; related Cap 26 work in PHASE_HISTORY; 26.6 notes
      `docs/acceptance/cap26-26.6-notes.md`)
- ADR-053: Overlay row-3 Animated still label — **Accepted**
      (2026-09-15); work `fc0bfcc`; `isAnimated` via
      `playbackStyle == .imageAnimated`; Cap 26.3 closed before "…"
      size (26.4)
- Cap 26.6 device acceptance notes (Kafka + i17 C/D/I/J **PASS**):
      `docs/acceptance/cap26-26.6-notes.md`
- Cap 27.6 device acceptance notes (Kafka + i17 + SE sim **PASS**):
      `docs/acceptance/cap27-27.6-notes.md` (gate HEAD `ce05965`;
      debt **478** remains Open)
- Cap 25.2 presentShareSheet: Pigeon `PhotoLibraryApi.presentShareSheet`;
      domain `AssetShareRepository` + `PhotoLibraryGateway` +
      `assetShareRepositoryProvider`; Host in `PhotoLibraryService`
      (work `99c2e73`; Live-as-still + non-degraded still present =
      ADR-051 D12/D13); gateway tests
      `test/platform/cap25_2_share_gateway_test.dart`
- Cap 25.3 Share chrome: `cap25_share_entry_icon.dart` +
      `cap25_share_toast.dart`; `mainBrowseSharePresentInFlightProvider`;
      ARB `cap25ShareFailed` / `cap25ShareEntryIconSemantics`
      (work `c3b5a58`); widget tests
      `test/features/main_browse/cap25_3_share_entry_test.dart`
- Cap 24.5 device acceptance notes (Kafka + i17 matrix **PASS**):
      `docs/acceptance/cap24-24.5-notes.md`
      (ADR-050 D4 (a)(b) force-quit → real PhotoKit resolve;
      same-process tab switch must not be the sole gate; SYS =
      system PhotoKit consent only)
- Cap 23.4 device acceptance notes:
      `docs/acceptance/cap23-23.4-notes.md` (Kafka + i17 PASS; **456b**
      Closed)
- Cap 22 Saved Pool persistence: `lib/domain/source/saved_pool_repository.dart`
      + Drift `lib/data/local/` (work `d62e962`); Save UX 22.3
      (`4db65ec`); 22.4 chrome + ADR-047 polish (`0ca1198`, `0b68e01`);
      22.5 Misc polish (`7350f67`, `fd662c1`) + ADR-048 (`fbf2e82`);
      22.6 device acceptance notes
      `docs/acceptance/cap22-22.6-notes.md`
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
- Media chrome layout (Reset / LIVE / actions / MVP 3-row meta;
  shared browse chrome, not Cap 20–only; not ADR-043):
  docs/reference/media-chrome-layout-notes.md — work `81904e1`
- Cap 21.4b smart-album Build catalog boundary (live whitelist /
  exclude maintenance):
  docs/reference/cap21-smart-album-boundary.md — work `67cb08b`
- PhotoKit implicit multi-surface / Host notes (not ADR):
  docs/reference/ios-photokit-implicit-behavior-notes.md — debt **471**
- Acceptance notes (Cap 20.6 device acceptance — D5=4× / B.1 / Q2-A;
  debt **451** Closed / **452** Open):
  docs/acceptance/cap20-20.6-notes.md — work `bc15517`
- 13.6 measurement-gate re-evaluation protocol (campaign done;
  FAIL tables frozen; closer is ADR-030 §5):
  docs/acceptance/cap13-13.6-measurement-reeval-protocol.md
- Competitor products in committed docs: `Photo-App-A` / `Video-App-B`
  only; the real-name map stays local-only and gitignored
- POC spike code & evidence: branch `spike/poc` — read-only archive;
  never merge; never delete
- (grows as code lands)

## Do NOT touch (unless explicitly opening a new phase)
- docs/WakeTok(App)_project_kickoff.md — owner's private spec, READ-ONLY for AI tools
- Main Browse shell IndexedStack Theme wrap — do not restore a
  destination-conditional Theme around the stack (disposes
  VerticalMediaFeed / PageController; 14.4c `9eecc7e`)
- Layer 2 still temp producer (`DisplayStillRender` / `DisplayCaptureTime`
  in `PhotoLibraryService.swift`) — Cap 24 exact capture minute parses its
  EXIF/TIFF tags (debt 486); the original fetch also keeps Tier 4 file size
  local (ADR-018 / ADR-065)
- Runner build phase "Embed sqlite3 Privacy Manifest" in
  `project.pbxproj` — must stay after Thin Binary (which embeds the
  native-asset `sqlite3.framework`); it copies the manifest into the
  framework and re-signs it (ADR-074)
- (grows as fragile areas appear)

## Known debt / intentionally deferred
| ID | Status | Capability | Logged | Item | Reason | Picks it up | Related ADR |
|---|---|---|---|---|---|---|---|
| 397 | Closed | Main Browse Screen |  | Release build Severe Hang / hitch on production feed (Kafka) | Accidental Release campaign V-hard FAIL (`cap7-7.7-notes.md`); **7.7a Profile PASS**. Evidence strength: **All** surface clean **3/3 FAIL (Release) → 3/3 PASS (Profile)** is a strong signal the mode divergence is real (not a one-off flip); **Videos** was already 2/3 PASS on Release (intermittent), so weaker as a divergence signal. **Closed (Cap 31.4):** the owner has used Release builds on Kafka for a long time since Cap 7 (including the Cap 31.4 Release installs) with no hang — a long-term use observation, not a re-run of the 7.7 campaign. A hang seen again on Release opens a new row | Closed by Cap 31.4 | ADR-001 / ADR-014 |
| 401 | Open | Media Info Overlay |  | Location Label (reverse geocode) not implemented | Owner Cap 8 Q1=B: Overlay row 4 hidden when empty this Cap (kickoff ADR-X best-effort deferral; no geocode). Current-Item-only geocode hard rule unchanged when a later Cap picks this up | Unscheduled feature; owner schedules a Location Cap after v1 | kickoff ADR-X |
| 404 | Accepted (permanent) | Media Info Overlay |  | Same-asset playhead shared across built-in sources (All ↔ Videos) — **Accepted behaviour** | First observed Cap 8.8 (`cap8-8.8-notes.md`): `PlaybackApiHost` keys the app-scoped player by `assetIdentifier` (ADR-006), so the same Photos id under All vs Videos reuses position / ended-on-last-frame. **Accepted (ADR-023 D6 / Cap 13.5)** — intentional Host keying, **not** a bug fix and **not** cross-tab Continuity (D8: tab = new Session; feed index still resets). No `PlaybackApiHost` change. **Row kept** (not deleted like resolved bugs) as a permanent record of accepted behaviour to prevent re-litigation when the shared playhead is noticed again. | Unassigned | ADR-006 / ADR-014 / ADR-023; `docs/acceptance/cap8-8.8-notes.md` |
| 405 | Accepted (permanent) | Media Info Overlay |  | File-size disclaimer copy (kickoff ADR-W §5) unset | Size is logical resource bytes — not device disk / iCloud quota / optimized-local / immediate free-on-delete. iCloud-only blank size **before** local data exists is ADR-015/018 (never download solely for size; Photos Info is not a public-SDK ground truth). Same-page refresh after Layer 2 landed `43c984a`. Not an eng Decision gap; needs user-visible copy landing. Owner decision 2026-10-02: no user-visible size disclaimer is needed. The size shown matches iOS Photos Info on the Cap 8.4 / 8.8 device checks (local still, local video, Live), and no UI copy claims disk usage, iCloud quota or freed space, so the kickoff ADR-W §5 non-promise already holds. | None. A future feature whose copy implies storage or freed space must follow ADR-W §5 and opens a new row; do not reopen 405. | kickoff ADR-W |
| 406 | Closed | Main Browse Screen |  | First cold start: All current item fails until Retry because the Cellular Data system prompt appears after Layer 2 has already been issued | China-SKU app-level first-network prompt (mainland China App Store vs NZ: Photo-App-A same split). Dart `HttpClient` pre-feed probe does **not** trigger it. Lifecycle auto-retry landed `8a827e4`. **Closed (Cap 31.4):** owner device check 2026-10-02 on Kafka, fresh Release install: the Cellular Data prompt appeared on the first iCloud item and the current item recovered automatically after Allow. The fail page can stay visible for a moment before recovery (prompt fade-out, then resume auto-retry awaits cancel-before-retry, Cap 17.5b); expected timing, no new row. | Closed by Cap 31.4 | ADR-025 |
| 407 | Accepted (phase) | Main Browse Screen |  | Optional native `URLSession` (CFNetwork) pre-feed to show the Cellular Data prompt on the loading screen instead of after first Layer 2 fail | Dart sockets do not trip the China-SKU prompt. Not required for everyday feed swipe once B auto-retries (`8a827e4`). Photo-App-A on China SKU still shows the prompt in the feed. | Reopen after v1 only if China-SKU users report the in-feed prompt timing | ADR-025 |
| 408 | Closed | Main Browse Screen |  | **Leave-current did not stop PhotoKit iCloud video materialization; Browse continuously fills device storage; cannot reclaim from the system Photos library** | User-visible, independent of hitch. Optimize iPhone Storage **on** still loses: download rate beats system reclaim. 2026-08-18 replication: Videos V1 ~75 s, wait only first+last iCloud videos to play, flick the rest on cover → disk **200.2 → 207.38 GB (~+7 GB)**. Two watched videos ≠ +7 GB. WakeTok JPEG temps are bounded; growth is Photos library cache. **16.2** leave-cancel (`255656d`); **16.3** one networked `load` (`22ece57`; `requestPlayableVideo` is duration-only); **16.4** dwell 500 ms (`26294f5`). **16.5** (`docs/acceptance/cap16-16.5-notes.md`): no-Instruments Videos **+0.18 GB** / All **+0.02 GB** PASS vs that leak. Instruments GB is **System Data / purgeable**, not Settings Photos (idle attach ~+1.8 GB System Data; Photos 10.17→10.16 across reboot). Do **not** rewrite the 13.6 +7.18 GB as 100% Instruments (product cancel was also missing then). A late `cancel` after leave may still let A briefly enter prepare (not proven zero disk). App has **no public API** to delete Photos-library downloads (kickoff forbids an app-owned persistent media cache). Reclaim = iOS idle / reboot. **Second 13.6 gate-foundation defect** (Cap 14 was the first) — **product leak path paid by Cap 16**; 13.6 closed under ADR-030 §5 (everyday availability), not another 25 ms/s retest. | Closed by Cap 16 (ADR-029); 13.6 closed ADR-030 | ADR-025 D4 / ADR-029 / ADR-006 |
| 409 | Closed | Main Browse Screen |  | Tab leave does not cancel `PlaybackApiHost.prepareActive` iCloud video download | **Closed by 16.2** (`255656d`): `cancelInFlightPrepare` on leave current / dispose / leave Browse, including same-id. Dwell landed in 16.4 (`26294f5`). 16.5 measured no-Instruments storage PASS; remaining Instruments GB is System Data (notes), not missing leave-cancel. | Closed by Cap 16.2 (ADR-029) | ADR-025 D4 / ADR-029 / ADR-006 |
| 410 | Accepted (permanent) | Main Browse Screen |  | Debug/Profile builds show the iOS Local Network prompt before Photos; its body text is “Allow Flutter tools on your computer to connect and debug your application. This prompt will not appear on release builds.” | Not product code: flutter_tools `bin/xcode_backend.dart` (`addVmServiceBonjourService`) inserts `NSLocalNetworkUsageDescription` + `NSBonjourServices` into the built Info.plist for Debug/Profile only and returns early for Release; `ios/Runner/Info.plist` declares neither key. Owner device check 2026-10-01 (iPhone 13 Pro, zh system, Release build of `69f0dfc`, fresh install): cold launch shows only the Photos permission prompt; no Local Network prompt. | Unassigned | — |
| 411 | Open | POC-03 |  | WeChat/VoIP interrupt: no auto-resume on lock screen or iOS home without opening app | Q1=B: 3.3 PASS when shouldResume + poll/foreground resumes; suspended lock/home path deferred | Production Background Audio | ADR-002 |
| 412 | Open | POC-03 |  | Real physical-clip integration after POC-09 (≥3 exported clips locked queue) | Bundle WAV proved service shape only; confirm Photos-backed segments, order, Now Playing, no Dart per transition | Production Background Audio (prerequisite: Generated Clip Source available after Physical Clip Export Core + Photos import) | ADR-002 |
| 413 | Open | POC-03 |  | iCloud Asset download interrupt during background audio | P2=A: out of POC-03 scope | Production Background Audio | ADR-002 |
| 414 | Open | POC-09 |  | Slow-motion frame-rate / audio-pitch beyond duration gate | 9.3 passed duration only | Physical Clip Export Core | ADR-004 |
| 415 | Open | POC-09 |  | Multi-audio-track selection UX | 9.4 default track only | POC-07 | ADR-004 |
| 416 | Closed | App Foundation |  | iOS 18 simulator smoke (no 18.x runtime installed) | Floor is 18.0 (ADR-007); day-to-day verify on 26.x only. No iOS 18 device; the runtime is installable on the dev Mac. Runner Swift compiles against 18.0 with no `#available` branches, so unguarded newer APIs would fail the build; behaviour / layout on iOS 18 and plugin native code stay unverified. **Closed (Cap 34.2):** owner smoke 2026-10-07 on an iPhone SE (3rd generation) iOS 18.0 simulator, English (UK), debug build: launch, Photos permission (Full Access; then Limited with nothing selected → empty panel and Manage selection), Browse, Settings and Light/Dark passed; no runtime exception or layout overflow in the log. One small-screen finding (permission-page button label) goes to v1.0.1. The `native_assets` "SdkRoot" build message also appears on iOS 26.3, so it is not iOS 18 specific. A Release build on iOS 18 stays unverified (no device) | Closed by Cap 34.2 | ADR-007 |
| 417 | Open | App Foundation |  | Localization Inventory auto-generation/report tooling (kickoff ADR-U §7–8 summary artifact) | Hardcoded-copy scan + ARB key parity closed by ADR-012; Inventory report generator still deferred. **Also (logged Cap 21.5 follow-up):** `app_zh_Hans.arb` debug / probe strings under `source*` / `playbackProbe*` / `cap19*Probe*` still carry Latin product/API tokens (Photos, Videos, Pool, Limited, unauthorized, estimatedCount, PHAsset, bootstrap, L-BOOT, …). Visible only under `kDebugMode` / library_smoke — not Release product risk; systematic ZH cleanup deferred to Settings and localisation completion (same Inventory lane). Cap 21.5 follow-up only aligned `playbackProbeLoadImage` / `playbackProbeLoadVideo` with `libraryRowPhotos` / `libraryRowVideos` wording. | Settings and localisation completion | — (kickoff ADR-U) / ADR-012 |
| 418 | Closed | App Foundation |  | App icon asset set | Owner parallel track; required before first TestFlight build upload. **Closed (Cap 31.4):** iPhone slots and the 1024 marketing icon carry the WakeTok design (`5645bb1`); v1 is iPhone-only and the five iPad-only placeholder icons are removed (`9d54313`); owner device check passed 2026-10-02 (iPhone 17, iPhone 13 Pro, Release) | Closed by Cap 31.4 | ADR-070 |
| 419 | Closed | Portfolio |  | Repository visibility: Private → Public (eligibility: first demoable vertical slice — Main Browse feed scrolls real Photos library content on device) | Cap 7 closed — eligibility met. Pre-public checks (2026-10-09 to 2026-10-10), kept as distinct evidence; do not merge them into a single pass conclusion. gitleaks v8.30.1 (built-in default rules, `--redact=100`) full-history scan of all refs, with `main` at `c812f0f` and `spike/poc` at `7ce5fe3`, reported 3 findings; all reviewed manually as false positives (one test label, two local preference key names). Per the gitleaks v8.30.1 source (`sources/git.go`), its git scan checks added patch lines only; commit-message text and non-archive binary files are not scanned. A separate regex screen of the 627 commit messages present when `main` was at `5557a2b` found 0 matches. A repeat screen of the 4 commit messages added since, through `c812f0f` and `7ce5fe3`, found 0 matches. Current-file report (Cap 31.6 format) on both branch tips: no competitor names, local absolute paths or old usernames; the AI tool name remained on `spike/poc` only and was replaced in `7ce5fe3`. Owner non-text review: the historical non-text path list for `main` and `spike/poc` holds the expected icons, launch images and README images, plus the Cap 27 candidate boards and media-chrome golden PNGs (absent from both current trees since `4a2817d`; history kept) and three POC-03 WAV fixtures on `spike/poc` (kept; generated tones inferred from the POC-03 notes' "Audible tone" expectation and the file sizes, not listened to). Historical binary blobs were not opened one by one. The kickoff file appears in no commit, before or after the 2026-09-04 purge; the Cap 31.6 commit-history hit list was reviewed read-only in Cap 31.6 and left unhandled. Known and accepted by owner decision (non-secret; history is not rewritten): device UDIDs (2 devices) in acceptance notes and one ADR; Photos asset identifiers in 3 notes; pre-2026-09-04 history, including the file removed by the purge, remains reachable on GitHub by SHA and through the repository's force-push activity. For non-secret content only the current trees are cleaned. This results-only docs commit was reviewed line by line by the owner instead of rescanned. Final pre-public rescan (2026-10-10), after `e08077f` was added: gitleaks v8.30.1 (same SHA-256 three-way check, built-in default rules, `--redact=100`) full-history scan of all refs, with `main` at `e08077f` and `spike/poc` at `7ce5fe3`, scanned 629 commits and reported 3 findings with the same fingerprints as the earlier false positives; the regex screen of the 2 commit messages added since (`097c255`, `e08077f`) found 0 matches. **Closed (2026-10-10):** the owner changed repository visibility to Public. | Closed by the repository publication capability (2026-10-10) | — |
| 420 | Closed | iOS Photos permission |  | NSPhotoLibraryUsageDescription was PLACEHOLDER copy; replaced with owner-approved English wording (zh prompt gap: 483) | Final permission wording is owner-only (release-handoff) | Closed by Cap 31.4 (`7d47ef3`; owner device PASS on iPhone 13 Pro + iPhone 17) | ADR-062 |
| 421 | Closed | iOS Photos permission |  | Limited Access product chrome unmounted from Main Browse (`01a7611`) | Banner sat above IndexedStack (all four tabs) and the shell Column had no SafeArea (notch clipped it). **Removed the product mount, not the feature.** **Closed by Cap 29** (ADR-059): Settings Photos Access — Manage → `presentLimitedLibraryPicker` (every dismiss dirty via Cap 28.5 authority); Open Settings never notifies; Full status ± Open Settings; no Browse launch remind (v1). ADR-059 D10: access-scope consume clears Snapshot cache + feed index 0 before `restartSession` so Manage round-trips are product-visible. Kickoff ADR-K §3 in-app entry met for Limited manage + system path to Full. Debug `library_smoke` Limited banner remains `kDebugMode` only. | Closed by Cap 29 | kickoff ADR-K; ADR-058 D4; ADR-059 |
| 422 | Accepted (phase) | iOS Photos permission |  | List-time availability via undocumented PHAssetResource KVC `locallyAvailable` | No public isLocallyAvailable on PHAsset/PHAssetResource in the iOS SDK. Host uses KVC in `mapAvailability`. **Cap 15.12 / 15.15 (ADR-033):** become-current may call `getAssetAvailabilities` (on-demand; resolve returns empty availabilities). Same KVC helper for probed ids only. **Further expansion** of KVC beyond this gate still needs explicit owner re-board. | Re-evaluate only if App Review or TestFlight external beta review flags it | ADR-033 |
| 423 | Open | Cap 6 / library_smoke |  | Library Totals Shell error row uses raw exception string (`'${asyncTotals.error}'`), not ARB | Predates ADR-012 smoke hardening; Cap 6.4 left untouched on purpose | Settings and localisation completion | ADR-012 |
| 424 | Accepted (phase) | Main Browse Screen |  | No architecture scan for hardcoded `TextStyle(` in `lib/features/**` (typography tokens exist; `Color(0x` still scanned) | Cap 7.2 locked type roles without a TextStyle literal guard; easy to bypass tokens while 7.4–7.7 chrome lands | Reopen only if review finds a hardcoded TextStyle / font size bypassing typography tokens | ADR-009 / ADR-014 |
| 393 | Closed | Main Browse Screen |  | Video page swipe may flash the previous video — **with audio** (severity residual) | **Closed by 15.11** (`9d546f2` / ADR-032): `PvTransitionGuard` (entering-side cover + transition mute); unwrap on Host **`onPlaybackSurfaceReadyForDisplay`** (`AVPlayerLayer.isReadyForDisplay`), **not** attach-ack (attach observed `layerReady=false` in diagnosis — evidence in `cap15-15.11-notes.md`, not git). 15.11b: poster-hold + settle-on-target (cover release ≠ audio release) + stale feed-index re-arm fix. Kafka + i17 Profile PASS — `cap15-15.11-notes.md`. Peek black gap + settle wrong A/V both closed under debt **393**. ADR-006 1+1 pool unchanged. | Closed by Cap 15.11 | ADR-006 / ADR-032 / ADR-031 |
| 425 | Closed | Main Browse Screen |  | Local / L2-ready items still blur-first on revisit (Session) | **Closed by 15.10** (`62a5a2b`): Session L2-ready token skips Layer 1 on revisit; still sharp / video poster-until-play. Kafka PASS (`cap15-15.10-notes.md`). **v1 revisit only** — no list-time KVC on become-current (STATE `locallyAvailable` row unchanged). | Closed by Cap 15.10 | ADR-025 |
| 426 | Closed | Main Browse Screen |  | Session L2-ready revisit: residual corner spinner flash (&lt;T) after Host temp eviction | **Closed by Cap 17.3** (`65ea272` / ADR-034): path-class wait chrome (a4 T=150 ms) + promoted G (still a2 &lt;T) / B (a4 miss bypass) / F1(+D) (Live prepare &lt;T). Closes the **&lt;T residual corner flash** only — that flash is not remaining unfinished Cap 17.3 work. **≥T still/a4 chrome** is the intentional empty-window guard (see the ≥T row, debt 427). Device skew (Kafka clearer / i17 faint) unchanged. | Closed by Cap 17.3 | ADR-025 / ADR-029 / ADR-034; Cap 15.10/15.13; Cap 16 temps |
| 427 | Accepted (phase) | Main Browse Screen |  | Session L2-ready revisit: ≥T wait chrome / zero-spinner product choice (Host temp vs disk-resident L2-ready covers) | **MVP-acceptable product choice (not Cap 17 unfinished work).** After Cap 17.3, ≥T still/a4 wait chrome can still appear when Host temp eviction drops a cover (empty-window guard under ADR-034). Root tension remains Cap 16 tight temps vs disk-resident L2-ready covers. Solution paths (raise Preview/Display temp budgets; keep cover outside Host temp) are **unevaluated and unscheduled**; whether to optimize is a later product judgment. Closing the &lt;T flash row in Cap 17.3 does **not** decide this product limb closed or permanently declined. **Suspected mechanism cross-ref (not confirmed):** debt **441** (Session video revisit landing one-frame black) may share a4 / Host-temp cover-eviction infrastructure; **441** is a distinct symptom (≈1 frame at settle handoff, not ≥T wait-chrome policy). 441 was later Closed by Cap 31.3 (ADR-068). | Unassigned | ADR-025 / ADR-029 / ADR-034; Cap 16 temps; debt **441** |
| 428 | Accepted (phase) | Main Browse Screen |  | Cap 17.5 F1 — reduce wasted Layer-2 prepare (beyond Cap 16 leave-cancel / dwell) | Cap 17.5 scoped F1 as optional if tee showed illegal / wasted prepares. 17.1 Track B + Cap 17.5 Kafka dwell=300 dual-column session show cancels are overwhelmingly Cap 16–legitimate leave-cancel, not a bug class. F1 code may be **zero**; do not invent a phase to force a diff. Same recording pattern as the ≥T / temp-budget Unassigned row. | Reopen only if measured iCloud slowness is attributed to wasted prepare | ADR-029 / ADR-034 / ADR-035; `cap17-17.5-notes.md` |
| 394 | Closed | Main Browse Screen |  | Local Layer 2 completing during a swipe exposes a Layer 1→2 handoff gap (stills and video); consecutive iCloud items stay on Layer 1 and do not flash | Trigger: on-device Layer 2 returns inside the scroll animation; iCloud Layer 2 is slow so the page keeps the preheated Layer 1. **Stills:** **Closed by 15.5** (`2f24593`) for local still→still gapless. **Video peek-black (leave-side poster loss):** **Closed by 15.7** (`bb3d5e2`) when L1 poster exists. **Revisit blur-first when L2-ready:** **Closed by 15.10** (`62a5a2b`). **Entering-peek black gap + settle wrong A/V (debt 393):** **Closed by 15.11** (`9d546f2` / ADR-032). Debt **400** unchanged. | Closed by Cap 15.11 (debt 393 limb) | ADR-006 / ADR-025 / ADR-032 |
| 395 | Closed | Main Browse Screen |  | Navigation return to a video is not yet uniformly restart-from-0 | **Closed by Cap 18.7 — intentional product design (ADR-040).** Cap 18.3 work `84ef30c`: `PlaybackCoordinator` + Host seek-zero-before-play on every trusted new navigation activation (no pause / playing branch). Pooled-player fast A→B→A path device-verified **395-P** / **395-PP** on Kafka + i17 Green (`cap18-18.6-notes.md`; docs `688ec43`). Unit: U-18.3-P1 Host policy. Foreground resume / surface reattach are not navigation activations (ADR-026 D3 mid-play preserve unchanged). | Closed by Cap 18.7 | ADR-006 / ADR-026 / ADR-040 |
| 396 | Closed | Main Browse Screen |  | Becoming current can bump display generation twice (`_activateCurrentItem` in the feed-index listen + `_beginCurrentItemActivation` in build), so Layer 2 may fire twice | **Closed by 15.4** (`d532064` / ADR-031 D8): join in-flight Layer 1 on neighbour→current promote; no second `requestPreview` on the same id (`preview_supersede`). Kafka M1+2: zero supersede on five miss `page_changed`; one `layer2_load_start` each. W-15.4 widget tests. | Closed by Cap 15.4 (ADR-031) | ADR-025 / ADR-010 / ADR-031 |
| 429 | Closed | Main Browse Screen |  | Browse→Settings→Browse while a video is playing flashes one poster frame | **Dissolved by 14.4e** (`5658cf2`): leave Browse ends the Session and returns at queue head, so the 14.4c keep-alive mid-queue resume path is gone. Remaining wait chrome after leave is the Layer 1 cold-start row below, not this poster flash. | Closed by Cap 14.4e (ADR-027) | ADR-006 / ADR-025 / ADR-027 |
| 398 | Closed | Main Browse Screen |  | Leave Browse (Settings/Clips/Auto) then return: queue-head page may show black + gold spinner with no Layer 1 still/poster | **Closed by 15.3** (`962b6d1` / ADR-031 Q2): same `_loading` miss chrome as debt **399**, now `_FeedCornerChrome` not centered. Black wait until Layer 1 still exists (ADR-025); 14.4e remount at index 0 can still land on a miss head (Shuffle). Kafka 2026-08-20 device: miss = corner spinner; library loading still centered. | Closed by Cap 15.3 (ADR-031) | ADR-025 / ADR-027 / ADR-031 |
| 399 | Closed | Main Browse Screen |  | Layer 1 miss (`_loading`) still uses a **centered** brand-gold spinner (`mainBrowseFeedPageLoading`); 14.6b only moved Layer 2 / Live-prepare chrome to bottom-right when a still/poster already exists | **Closed by 15.3** (`962b6d1` / ADR-031 Q2): miss page is `feedBackground` + `_FeedCornerChrome`; no delay-before-show; new ARB `mainBrowseFeedLayer1Loading`. Library resolve `mainBrowseFeedLoading` stays centered. Kafka device PASS. Debt **436** not in this close. | Closed by Cap 15.3 (ADR-031) | ADR-025 / ADR-019 / ADR-031 |
| 430 | Closed | Main Browse Screen |  | **Center Layer2Waiting (`mainBrowseFeedLayer2Waiting` / “Loading…”) necessity unclear — separate from Layer1Loading and corner reassure** | **Closed by 17.9** (`f1ffadf` / ADR-039): owner option **A** — deleted runtime center copy and ARB key; coverless L2 keeps corner spinner + `mainBrowseFeedLayer3Loading` semantics; corner reassure policy unchanged (`shouldShowLayer2CornerReassure`; `W-17.5b-covered` / coverless ≥3s tests updated). Fixed coverless re-enter `_loading` before L2 in-flight arm (hold/startLoad race). Guard option B (L1-miss→L2 center copy) **not** wired. | Closed by Cap 17.9 (ADR-039) | ADR-034 / ADR-036 |
| 431 | Closed | Main Browse Screen |  | All / Photos / Videos quick tab switch flashes one frame center Layer1Loading (`mainBrowseFeedLayer1Loading`) | **Closed by 17.9** (`f1ffadf` / ADR-039): source-switch-only 150 ms delay hides **visible** center copy on first current page after tab change; corner spinner + VoiceOver `mainBrowseFeedLayer1Loading` semantics stay immediate. Vertical swipe / cold start unchanged. Kafka Profile owner acceptance PASS (4-step). | Closed by Cap 17.9 (ADR-039) | ADR-039 |
| 432 | Accepted (phase) | Main Browse Screen |  | Origin switch (All / Photos / Videos tabs, saved / ephemeral pools) may flash one frame feed-shell `mainBrowseFeedLoading` | **Optional polish (retained).** Tab change starts a new Consumption Session (`browseSessionProvider` reload); cached snapshots typically ≤1–2 frames of shell loading. Semantically distinct from page Layer1 copy (17.9 closed rows above). Owner rejected blank-hold polish (empty feed color reads as bug/stutter). Alternatives (`skipLoadingOnReload`, cache-hit synchronous session swap, delayed whole-screen library chrome) unevaluated. **Accepted (Cap 31.4):** since ADR-057 every Origin change calls `restartSession()`, which sets a fresh `AsyncLoading()` with no previous value, so `skipLoadingOnReload` does not apply; the frame reads as a normal load. | Reopen only if the loading frame on tab / pool switch is reported as disruptive; a fix would keep the old feed until the new session is ready (touches the ADR-057 restart path) | ADR-023 D8 / ADR-039 / ADR-057 |
| 400 | Accepted (permanent) | Main Browse Screen |  | iCloud / optimized-storage **video**: no Layer 1 poster — full-page black + spinner until Layer 2 plays; ±1 peek often stays black | **15.6 partial (`9eef9db`):** Host box **512×512** (was 1080). Raises **Limited** local-hit odds when a derivative near the box exists (Session B: 13×512-edge ok). **Does not** explain Full never-black: Protocol B same 16 ids under Full → 16/16 ok all **~120**, 0 miss — **inferred** Full opportunistic fallback to a fixed small thumb tier; Limited searches by `targetSize` without that fallback (`cap15-15.6-notes.md`). Limited residual miss (3/16 in B) can still lack any deliverable local image under Limited while Full has ~120 — PhotoKit authorization behavior under ADR-025 local-only; Host cannot invent pixels. Unvalidated trial: `deliveryMode = .fastFormat`. Product miss UI = separate discussion. Original Limited 6-video set (2026-08-18) still applies as early evidence. **Cap 17.4 (`c3aa2dc`):** coverless wait **visibility** improved (centered copy + corner spinner); **residual black accepted** (ADR-034 Decision 3). **Cap 17.8 close-out:** row remains on the table as accepted residual (permanent) — Host cannot invent pixels; no further fix or upgrade scheduled; not Cap 17 unfinished work. | Unassigned | ADR-025 / ADR-006 / ADR-031 / ADR-034 |
| 433 | Closed | Media Info Overlay |  | Capture time shown in Overlay (exact datetime + relative “X years Y months ago”) does not match iOS Photos for the same asset | **Closed by Cap 17.7** (`d9db8c7` / ADR-038): product goal changed from minute-level Photos wall-clock match to **honest approximate** presentation — row 2 `~ Y-M-D` and row 1 coarse short bands from `creationDate` local calendar only; ±1 calendar day vs Photos at import/timezone edges **accepted** (not a bug to chase in Overlay). Rows share honesty stance but are **not** guaranteed numerically consistent with each other or with Photos for cross-check. Minute-level Host/EXIF attempt reverted (`2c0a090`); its diagnostic archive remains local-only. Device smoke PASS iPhone13pro Kafka. Cap 19 long-press info may revisit with disclaimer. | Closed by Cap 17.7 | ADR-038; Cap 8 Overlay / ADR-014 family |
| 434 | Closed | Main Browse Screen |  | Lock then unlock on Manual Browse while a video is current: same index/frame, paused, no tap-to-play — swipe is the only escape | ADR-006 Cap 7.3: background detach + pause; foreground re-adopts the layer. **Closed by Cap 18.4** (`0df9ceb` / ADR-040 Decision 4 supplement + Decision 12): lifecycle leave is mechanical pause only (preserves intent); foreground resume auto-plays when intent preserved (respect mute). User tap-pause before interrupt stays paused with center affordance + tap resume. Supersedes the Cap 18.1 draft that required foreground stay paused until tap. No lock-aware special-case code. | Closed by Cap 18.4 (ADR-040) | ADR-006 / ADR-040 |
| 403a | Accepted (phase) | Main Browse Screen |  | Asset-source iCloud load feels much slower than Photo-App-A / iOS Photos | **Suspect clues (verify later — not closed root causes; not Cap 15.11 scope).** Owner subjective + Cap 15.11 **session** log on Kafka (`/tmp/waketok_1511b_stale_idx.log`, 2026-08-23): many items stayed blurry / non-playing while Photo-App-A in the same window eventually loaded; log skew `load-finished err=ok` ≈168 vs `operationCancelled` ≈417, **0** `iCloudDownloadFailed`. Suspect aggressive leave/remount/supersede cancel + single-flight prepare vs competitor / Photos keep-or-parallel download — **deep-dive WakeTok iCloud network + cancel policy** when scheduled; no attribution without further evidence. Debt **428** covers wasted prepare (separate row; evidence leans legitimate leave-cancel). **Accepted (Cap 31.4):** subjective, with no objective standard. ADR-034 D3 promises no parity with Photo-App-A / iOS Photos; slower background completion is the intended cost of leave-cancel + dwell (ADR-029, ADR-034 D4), which Cap 13.6 showed necessary (uncancelled fetches filled the device). | Reopen only on measurable evidence (same iCloud items clearly slower in WakeTok than in Photos) or user reports | ADR-025 / ADR-029 / ADR-034 / ADR-035 / ADR-036 |
| 403b-progress | Accepted (phase) | Main Browse Screen |  | Long iCloud Layer 2 has no progress/stall productization | Item-level `_FeedCornerChrome` spinner gives **no progress signal** during long iCloud Layer 2 (throughput, bytes, ETA). Cap **17.5b** delivered corner reassure + Retry definition (work `527baeb`); progress/stall productization was a direction only and is **not** planned for MVP. 17.5b Retry/reassure limb closed. | Unassigned | ADR-025 / ADR-029 / ADR-034 / ADR-035 / ADR-036 |
| 403b-wallclock | Accepted (phase) | Main Browse Screen |  | No blind wall-clock stall→fail timeout | Blind wall-clock timeout intentionally not adopted. Evaluated and rejected as a specific scheme; a smarter stall policy may be reconsidered later. | Unassigned | ADR-025 / ADR-029 / ADR-034 / ADR-035 / ADR-036 |
| 435 | Accepted (permanent) | Main Browse Screen |  | Layer 2 fail reason mapping collapses PhotoKit detail to three user-facing buckets (`network` / `download` / `generic`) | Cap 17.5b review confirmed: user-facing granularity **intentionally** stays at three categories (no action-path benefit from finer copy). Pre-fix Host path read `PHImageCancelledKey` + transferBegan only and **discarded** `PHImageErrorKey` / `PHImageResultIsInCloudKey` without logging. **Supplemented during 17.5b:** Host `logLayer2PhotoKitFail` in `PlaybackApiHost` (video `requestAVAsset`) and `PhotoLibraryService.handleDisplayResult` (display L2) prints cancelled / transferBegan / inCloud / phError / mapped Pigeon code to Console (Profile+Debug). Dart `feedFailureReasonFromPlatformCode` only ever sees the already-collapsed wire code. No further Cap assigned. | Unassigned | ADR-025 / ADR-036; `cap17-17.5b-notes.md` |
| 436 | Closed | Live Photo (Cap 9.7) |  | Offline/weak-net iCloud Live: preparing spinner may be zero-duration (fail too fast); long-press replay failure shows no feedback | POC-08 #5/#6 PASS with static fallback; owner wants later brief visible spin-then-fail so users see “needs network” (not progress-copy / Waiting for Media). **Reopened by owner observation 2026-10-02** (iPhone 13 Pro, offline, Live motion only in iCloud): the Cap 26 long-press replay re-requests, fails, and returns to the still with no feedback — a path that did not exist when this row was logged (pre-Cap 26). **Closed (Cap 31.4a):** the long-press limb is fixed by ADR-071 (`ee47970`); the auto-play limb degrades to the still per kickoff, and showing no failure indicator there is an owner decision (ADR-071 Decision 3) (in-progress download gap after reconnecting, see debt **488**) | Closed by Cap 31.4a | ADR-019; ADR-071; historical acceptance label: UX-1 |
| 437 | Closed | Live Photo (Cap 9.7) |  | LIVE badge + preparing spinner top-left overlaps status-bar time | **Closed by 14.6b** (`77afb23`). Badge + item Layer 2 / Live-prepare spinner share `_FeedCornerChrome` at bottom-right; Overlay `trailingInset` 123. Library resolve loading stays centered. Q7 play-once hide/show unchanged. Kafka Profile PASS. Debt **436** untouched. | Closed by 14.6b | ADR-019; historical acceptance label: UX-2 |
| 438 | Closed | Cap 13 (13.8) |  | **First launch right after granting Limited access shows an empty All tab and does not self-heal** | **Closed by 14.6** (`d32a309` + `b9c2d68`). Bounded re-resolve on successful empty remains; Kafka showed the empty All was started by resume `currentStatus()=.limited` **before** `requestAuthorization` completed. Skip that invalidate while `requestAccess` is in flight, then `restartSession` when the grant completes. Kafka Profile: loading then selected media, not empty copy. ADR-024 empty-not-cached remains as tab-switch backup. | Closed by 14.6 (ADR-025 D8 + grant-complete restart) | ADR-025 / ADR-024 / ADR-014 / ADR-021 |
| 439 | Closed | Live Photo | Cap 18.1 | Live explicit replay control | Owning Cap was unassigned; ADR-019 Decision 8 narrow supplement pending that Cap. Persistent anchor for ADR-040 Decision 17 and Phase 18.1 `owning Cap TBD`. Cap 26 / ADR-052 supersedes D17 no-long-press with App long-press as sole replay affordance (explicit button never shipped). **Closed by Cap 26** (`cab0747` + Cap 26.6 close): long-press is the sole replay control; debt row complete. | Closed by Cap 26 | ADR-019 / ADR-040 / ADR-052 |
| 440 | Closed | Main Browse Screen | Cap 18.3 | Seven existing spinner / preparing-chrome widget tests are red on `main` | Verified against clean baseline `9e4a04e` before Cap 18.3: W-16.4e, W-L2, L-S6, W-14.6b-L1/L4, W-15.3, and W-14.4 all fail identically before and after the 18.3 worktree changes. Failures concern missing Layer3 / Live-preparing chrome within test timing windows, except W-15.3's LIVE-badge strut height (`16.0`, expected `>16.0`). They are not Cap 18.3 playback-intent regressions. W-16.4e probe (still a2 + L1 + dwell; real arm+dwell, not debugForce; elapsed synced to FakeAsync): asserts spinner at t≈0, which conflicts with ADR-034 G (suppress &lt;150 ms); at t≥150 ms spinner paints — product chrome healthy. That assert's timepoint is obsolete post-17.3 (stale assertion, not product regression). Does not re-prove the other six reds in this row. Widget tests reconciled to ADR-034 G/F1 clock semantics (elapsed sync + F1 timer pump); W-16.4e asserts ≥T dwell chrome; strut-height assertions removed post–Cap 17.5b layout. Seven tests green on `main` as of work commit `6682582`. | Closed before Cap 18.6 (test/chrome reconciliation) | ADR-032 / ADR-034 / ADR-039 |
| 441 | Closed | Main Browse Screen | Cap 18.4 | Session **video** revisit: landing settle may show one-frame full black between blur Layer 1 poster and Layer 2 play | Known phenomenon family (`cap15-15.10-notes.md` §D); first seen Cap 18.4 (Kafka Profile, Optimize ON, iCloud video first-visit L2 complete → Session revisit). **Closed by Cap 31.3 (`960ac21`):** the video slot no longer paints opaque backgrounds (Flutter `feedBackground` `ColoredBox` in `_VideoPage` + native `PlaybackSurfaceContainer` `.black`) over the poster before the first frame. **Mechanism is an inference**, not a controlled experiment: knife C probe run 3 vs 0 owner-reported black frames on covered revisit promote (1 of the 3 not fully certain; small sample; runs differed in more than knife C); offline replays found no blank in either run; owner use over one evening on i17 + Kafka reported none (subjective). **Not separately verified:** iCloud + Optimise Storage video revisits (the original trigger). Residual: debt **487**. Related fixes: `a743521`, `61dcf27`, `8b6334f`, `f451166`. | Closed by Cap 31.3 (`960ac21`) | ADR-068; ADR-006 / ADR-025 / ADR-032 / ADR-034; `cap15-15.10-notes.md` §D; `cap31-31.3-notes.md`; debt **427** |
| 442 | Accepted (phase) | Main Browse Screen | Cap 18.5 | Cap 18.5 scrub preview bubble may show async JPEG placeholder gaps (fast-drag strip, first-scrub cold start, in-flight bucket transition) | AVAssetImageGenerator + Host single-flight coalesce + 1.0s preview bucket + ADR-040 Decision 13 §2.1 borrow (max one bucket step, 350 ms wall-clock) do **not** guarantee a continuous real-frame strip at competitor parity. **Three distinct triggers, same architecture:** (1) **fast horizontal drag** — borrow cannot cover every bucket crossing; (2) **first scrub engagement** — no prior successful JPEG to borrow, bubble waits on first Host decode; (3) **mid-drag in-flight / bucket switch** — `#000000` placeholder (or bounded borrow) until async JPEG arrives; **trigger (3) is not fast-drag-specific** — every bucket switch clears the current frame and waits on async Host return; at normal scrub speed that window is often below perception (BENCH typical **14–150 ms**) but is not guaranteed to stay sub-threshold (BENCH max **388 ms** on sparse-GOP zero-tolerance decode). **Accepted for Cap 18.5 ship** (`b2ceabd` eliminated sparse-GOP drift-reject **permanent** black on hold; placeholder-then-JPEG remains by design per supplement item 8). Cap 18.6 soak: owner-acceptable, not Photos parity. Further optional tuning: scrub-touch prefetch, `maximumSize`; widening borrow is **not** a candidate (violates §2.1). | Unassigned | ADR-040 Decision 13; `docs/acceptance/cap18-18.5-notes.md`; `docs/acceptance/cap18-18.6-notes.md` |
| 443 | Accepted (phase) | Main Browse Screen | Cap 18.5 | Cap 18.5 progress scrub is **whole-second** granular (not iPhone Photos / slow-mo 0.01s edit resolution) | **Intentional Cap 18.5 scope.** Linear band maps to ratio; label + release seek use `round(ratio × duration)` to the nearest second. Sub-second scrub requires quantizer, Host seek tolerance/timeouts, and preview bucket changes — documented upgrade path in acceptance notes. Not a defect vs Photos frame-accurate trimming. | Unassigned | ADR-040; `docs/acceptance/cap18-18.5-notes.md` |
| 444 | Closed | Main Browse Screen | Cap 18.6 | External Photos delete while Consumption Session still lists the asset: misleading Layer 2 fail copy; Retry ineffective | **Verified (owner device, Kafka Profile `1ed7f0b`):** delete a still in iOS Photos without quitting WakeTok → first return to the same feed item still shows the image; swipe away and back → Layer 2 fail with `Could not load. Allow wireless data, then retry.` + Retry; Overlay metadata rows still visible — **not** a connectivity defect. **Verified (code):** missing `PHAsset` → Host `assetUnavailable`; Dart maps `assetUnavailable` → `FeedFailureReason.network` → that wireless-data string (debt **435** three-bucket collapse); no production `PHPhotoLibraryChangeObserver` / session queue invalidation on external library mutation. **Inferred (architecture — not log-verified this session):** first revisit may use cached L2 (`DisplayTempFileStore` / in-page display state); second remount likely hits fresh `requestDisplayAsset` on a deleted id. **Not Cap 18.6 scope.** **Closed by Cap 21.6** (`a448989`): feed-only remap to `FeedFailureReason.assetUnavailable` + `mainBrowseFeedUnavailable`; hide Retry; hide Overlay while loading/unavailable; dim Cap 19 entry when unavailable. Residuals **456** / **457**. | Closed by Cap 21.6 (`a448989`) | ADR-044 D3; ADR-022 / ADR-025; debt **435** |
| 445 | Accepted (permanent) | Add to Album / Cap 19 | Cap 19-19.2a | WakeTok User Album uniqueness must use KV + `localIdentifier`, not title string — duplicate same-title albums possible | **Device confirmed (19.2a Kafka Debug, `cap19-19.2a-notes.md`):** iOS Photos allows multiple User Albums named `"WakeTok"`; each Limited create-only bootstrap (or KV clear + recreate) adds another album. Limited path forbids list find (ADR-021). **D1 bootstrap must treat persisted `albumIdentifier` as canonical identity** — not display-name dedup. KV loss under Limited may create a second album even when one already exists in Photos. Accepted cost of no-list-find rule; not a 19.2a blocker. | Cap 19.3 (D1 bootstrap) / D3 follow-up | ADR-021 / ADR-K; `docs/acceptance/cap19-19.2a-notes.md` |
| 446 | Accepted (phase) | Add to Album / Cap 19 | Cap 19-19.5b | Panel add-to-album is single-select only — one album per sheet open; sheet dismisses on success | MVP scope: append the same asset to multiple albums requires reopening the panel each time. A fuller product may add multi-album multi-select + confirm (sheet stays open). PhotoKit has no single public “add to N albums” call — domain primitive `AlbumMutationRepository.addAssetToAlbum` is correctly one asset+album pair; upgrade is UI orchestration (N sequential calls) or optional Host batch in one `performChanges`. Distinct from Cap 19.7 **duplicate-append** row (re-append to the **same** album). | Unassigned | ADR-040 |
| 447 | Accepted (phase) | Add to Album / Cap 19 | Cap 19.8 | Cap 19 actions half-sheet: (1) enter has no visible bottom-up slide; (2) occasional tap→open hitch — after tapping the bottom-trailing icon, the UI sometimes does not react immediately (brief blank / light stutter) before the sheet appears | **Profile-confirmed (Kafka, Cap 19.8).** **Root cause (both limbs):** on tap the main isolate must cold-build the full half-sheet (Favorites + album picker + frost) while the playing feed still contends for frame budget; when that first paint overruns the ~250ms wall-clock enter, the slide is skipped (exit still animates — warm tree); when the thread is only intermittently busy, the same cost shows as post-tap hitch then pop-in. Empty fixed shell slides (isolates content cost). Two mounting strategies tried (defer-one-frame; defer-to-completed) both rejected — neither achieves single-phase visible slide. Profile full-content with `BackdropFilter` removed still flashed (Experiment 1 / Profile full control) — first-paint content cost alone can skip enter, so deferring only frost while keeping Favorites/album sync is unlikely to restore the slide. **Not exhaustively ruled out:** reducing the loading-skeleton build cost of Favorites/Album rows themselves (near-zero-cost static placeholders before real `ConsumerWidget` loading), and/or Host pre-warm (may only marginally cut hitch frequency). Future revisit should try those before assuming architecture-level rework. Reverted defer/frost staging; keep stock sheet. Distinct from ADR-042 (current-asset actionable gating). | Unassigned | ADR-040; Cap 19.8 Profile A/B |
| 448 | Accepted (phase) | Add to Album / Cap 19 | Cap 19.8 | System interactive-pop / back-gesture vs Cap 19 full-width left-swipe (D2=B) | **P-19.6-POP note at Cap 19 close-out.** D2=B does **not** claim interactive-pop is solved (ADR-041 / Cap 19 §5). 19.8 owner acceptance did not treat this as a Cap 19 blocker; residual conflict risk remains if iOS edge-back competes with left-swipe near the screen edge. Not a product-visible Cap 19 regression — accepted residual until a later gesture Cap revisits. | Unassigned | ADR-040 Decision 2; ADR-041; Cap 19.6 notes |
| 449 | Open | App Foundation | Cap 20.5 | No machine CI that runs `flutter test` on push (agent-only architecture / scoped Cap gates) | Cap 20.4 L1 unify broke Cap 15.5 `W-15.5a` Image State identity; agent Cap20 tasks ran architecture + Cap20 files only — no GitHub Actions / other CI forces full suite. Rule docs alone re-create the same miss class. Need a real push CI job (at least full `flutter test` or continuity + architecture). | Unscheduled tooling work; owner schedules | — |
| 450 | Closed | Main Browse Screen / Cap 20 | Cap 20.5 | Still photo L1↔L2 doom-scroll black flash (peek / promote) after Cap 20.4 L1 unify | **Closed by post-20.5 work `3d29823`:** single `MagnificationHostModeBinder` on still cover (no Transient/Still type fork); `W-15.5a` enter + leave continuity in `still_image_element_continuity_test.dart`; Kafka/i17 local-asset doom-scroll PASS. Video shrink (mechanism C) and release scale spike (mechanism A) fixed separately in `282009e` — see `docs/acceptance/cap20-post-20.5-blackflash-shrink-notes.md`. | Closed by post-20.5 (`3d29823`) | ADR-043 Decision 14; Cap 15.5 |
| 451 | Closed | Main Browse Screen | Cap 20 | `W-14.6c` still `Image.file` uses `BoxFit.fill` but test expected `BoxFit.contain` | **Closed by Cap 20.6** (`bc15517`): assert rewritten for Cap 20 letterbox shell — `StillFittedMagnificationShell` sizes a contain-formula box from positive pixel dims; `Image` uses `BoxFit.fill` **only inside that box** (not viewport stretch). Architecture `presentation_defaults_test` still documents ctor default `BoxFit.contain` for fallbacks. Degenerate / missing pixel dims → viewport-sized fill stretch is debt **452**. | Closed by Cap 20.6 (`bc15517`) | ADR-028; Cap 14.6c; Cap 20 letterbox |
| 452 | Accepted (phase) | Main Browse Screen | Cap 20.6 | Missing or ≤0 `pixelWidth`/`pixelHeight` on display still → letterbox shell falls back to viewport size → `BoxFit.fill` stretches | Production Host normally writes PHAsset / decoded dims. Dart fields stay nullable (Pigeon optional). Shell treats null OR ≤0 as fitted=viewport — then fill WOULD stretch. PHAsset can report 0 / wrong dims (iCloud / incomplete metadata). Healthy-path guard is `W-14.6c` (`bc15517`); this row tracks the degenerate-dims residual. | Reopen only on a real stretched still; fix = Host L2 falls back to decoded image size like L1 (Cap 31.3) | ADR-028; Cap 20 letterbox; `cap20-20.6-notes.md` |
| 453 | Closed | Live Photo (Cap 9) | Cap 20.6 | App leave / lock mid Live motion left a mid-frame PV; pinch dead | **Lifecycle gap itself is Cap 9 legacy** (no AppLifecycle → Live unload from Cap 9 landing). **Became user-visible only after Cap 20.5** wired `_liveMotionMounted` to `MagnificationHostMode.none` (stuck mid-motion frame + pinch failure = same root cause, two faces). Pinch recovery **depends on** Live unload — not a separate debt. **Not an ADR-043 product decision** (lifecycle fix under Cap 9 / ADR-019 shape; Host-mode gate only made the gap visible). Discovered during Cap 20.6 soak; does **not** block 20.6 close-out. **Closed by** `7f43863` (2026-09-05): leave `inactive`/`paused`/`hidden` + resume heal → same unload as `playbackEnded`, then best-effort `stopPlayback`; unload claims dirty before Host stop (stacked leave idempotent). i17 Profile PASS: static cover + pinch. | Closed by Cap 20.6 soak (`7f43863`) | ADR-019 |
| 454 | Closed | Main Browse Screen | Cap 21.2 | `W-14.6b-L4` / `W-15.3` corner-chrome bottom inset assert expects ~12; product bottom is ~7.2 since media chrome layout | **Discovered during Cap 21.2; not introduced by 21.2.** Stash of all Cap 21.2 Origin/ChromeState work still failed identically on clean HEAD. Root cause: `81904e1` (2026-09-05) changed `_FeedCornerChrome` bottom from fixed inset 12 to `mainBrowseLiveStatusBottomInset` (≈7.2, aligned with Overlay; see `media-chrome-layout-notes.md`); widget asserts still used `closeTo(12, 1)` on `feed.bottom - chrome.bottom` (trailing inset 12 remained correct). Distinct from closed debt **440** (timing/strut reds, fixed `6682582`). **Closed by test-only fix:** `W-14.6b-L4` / `W-15.3` now assert trailing via `kMediaChromeTrailingInset` and bottom via `mainBrowseLiveStatusBottomInset(tokens)` — aligns asserts with the product value already shipped in `81904e1`; **no `lib/` product change**. Full `flutter test` green. | Closed by debt-454 test align | —; `81904e1`; `docs/reference/media-chrome-layout-notes.md` |
| 455 | Closed | Saved Pool persistence | Cap 21.5 | Cap 22 Saved composition/detail must plan `assetSourcesProvider` refresh; list does not auto-detect deleted albums | **Closed by Cap 22:** Saved list / Info / chip peek invalidate `assetSourcesProvider` on open (ADR-046 D8 / 22.4 `0ca1198`); Cap 22.6 matrix **P-22.6-F** owner PASS on Kafka + i17 (real Photos album-removed honesty; notes `cap22-22.6-notes.md`). Session/Queue lag remains ADR-027 / ADR-023 D7 — orthogonal. | Closed by Cap 22 (22.4 refresh + 22.6 F) | ADR-044 / ADR-045 / ADR-046 D8; Contract pointers list-lag note |
| 456a | Accepted (phase) | Main Browse Screen / Cap 19 | Cap 21.6 | L2-ready still path skips PHAsset liveness (ex-456 Part A) | **Split from bare 456 at Cap 23.1.** Session still L2-ready + on-disk temp → `FeedPageMedia.still(cover)` without `requestDisplayAsset`; external delete can keep showing the JPEG until temp eviction / origin change — Cap 21.6 feed copy never fires until Host is hit. Out of ADR-044 D3. Future: Host existence check / tighter L2-ready. Not Cap 23 (still-in-library mutation gate). | Reopen if users report it. Candidate fix: on become-current of an L2-ready still, reuse getAssetAvailabilities (ADR-033) and show assetUnavailable when missing; check feed hitch cost first. | ADR-044 D3; Cap 15.10; ADR-033 |
| 456b | Closed | Main Browse Screen / Cap 19 | Cap 21.6 | Panel / mutation still-in-library gate (ex-456 Part B) | **Split from bare 456 at Cap 23.1.** Prefer proactive “asset still in Photos” checks **before** Favorites / Cap 19.5 Add-to-Album / left-swipe / future Share. Distinct from Cap 19.8 `mainBrowseCurrentAssetActionableProvider`; **AND** — do not merge axes. Predicate: `AssetAvailability != unavailable` (iCloudNotDownloaded remains still-in-library). Cap 21.6 Overlay hide + Cap 19 entry dim reuse feed `assetUnavailable` as interim — not this probe. Cap 23 / ADR-049 implements the gate. Half-sheet Delete / delete-original → debt **464**, not this row. **Closed by Cap 23.4** device matrix PASS (Kafka + i17 P-23-A…G); work `893c8fb`; notes `cap23-23.4-notes.md`. ADR-049 Accepted at Cap 23.5. | Closed by Cap 23.4 | ADR-049; ADR-042; ADR-033; ADR-044 D3; Cap 19.5 / 19.8 |
| 457 | Accepted (phase) | Main Browse Screen | Cap 21.6 | Host `layer2Failure` collapses missing-PHAsset and pre-transfer L2 failure into the same `assetUnavailable` wire code | Cap 21.6 remaps that code to `FeedFailureReason.assetUnavailable` + hides manual Retry (ADR-044 D3 feed-display only). Pre-transfer / China-SKU wireless users therefore lose wireless-specific copy and the Retry button, but retain: (1) debt **406** lifecycle auto-retry on resume (`_retryFailedLayer2AfterResume` ignores reason); (2) swipe to another feed item and back — leave clears fail chrome, activation bumps display generation, `_startLoad` re-requests L2 because fail never minted an L2-ready token. Splitting the Host bucket needs a new Pigeon/Host capability outside D3. Mid-transfer fail remains `iCloudDownloadFailed` (download copy + Retry). | Reopen after v1 as a Host / Pigeon capability only if users report failures stuck without Retry | ADR-044 D3; debt **406** / **435**; Cap 21.6 |
| 458 | Monitoring | Main Browse Screen / Cap 20 | Cap 22.4 | Vertical feed lost page-snap (continuous slow drag; adjacent peeks L1→L2); leave-Browse does not heal — force-quit healed hit 1, more drags healed hit 3 — seen around Live (22.4, 31.2) and once on **video** (Cap 25) | **Hit 1 — Cap 22.4 i17 Profile soak (`0ca1198`).** Offline Live play-once: pinch/other gestures had **no** magnification visual (Live Host `mode == none` as designed), then vertical paging became continuous strip drag (neighbor pages half-visible; peeks still advanced L1→L2) instead of snap page-change. **Not Cap 22.4 Saved chrome.** Leave Browse / return did **not** heal (IndexedStack keep-alive retains `PageController` / `ScrollPosition`); force-quit did. **Hit 2 — Cap 25 Decision 14 Profile on Kafka (iPhone 13 Pro), owner report.** Same page-snap loss once on a **video** while an iCloud-not-downloaded item was still L2-not-ready (Share correctly dimmed); owner was repeatedly tapping the dim Share hit target to confirm no response — not a normal Share path. Share dismiss was likely swipe-down (not 100% certain). Exact timing vs dim→bright edge unclear. Same fragility **family** as Project facts Host pinch / `DragScrollActivity.shouldIgnorePointer` (Platform View + outer pinch Listener + PageView). Do **not** change PageView physics without a reliable repro. **Relation to Bug#1** (video share sheet outside-tap / intermittent pause-toggle) **unconfirmed**; Bug#1 was fixed in Cap 25 (hit-test gate) and no longer gates the 458 chase. **Hit 3 — Cap 31.2 device testing of the Live fix (date, device, build and preceding gesture not recorded).** Page-snap was lost around a Live item; dragging down a few more times restored it, no force-quit needed (unlike hit 1). Not seen since. Hits 1 and 3 were on Live items during Live-focused testing; hit 2 was on a video — treat Live as a clue, not an attribution. Cap 35.3 (owner OK): when not magnified, the feed PageView uses `AlwaysScrollableScrollPhysics` for every queue length (one expression), so a one-item queue accepts drags and rubber-bands. For two or more items runtime behaviour is unchanged: that layer only makes `shouldAcceptUserOffset` always true, and snapping, bounce and ballistics come from the same physics chain as before (W-35.3-6). | Opportunistic note if seen again (device, build, preceding gesture / item type, queue length). Primary: next Flutter SDK upgrade pinch/scroll re-verify. Cap discussion only if a clean repro appears. | ADR-043 / ADR-040 / ADR-019 / ADR-077; Project facts pinch/`DragScrollActivity` note; Cap 25 D14 device; Bug#1 |
| 459 | Closed | Main Browse Screen | Cap 22.5 | Endless round remount H0: when H1 Layer-1 seed misses, &lt;150 ms may show silent `feedBackground` (no gold spinner) before L1/L2 | **Closed:** Cap 22.5b real-bridge / soft-commit / H1–H0 remount path **reverted** to scheme A (static placeholder). Mechanism no longer exists. | Closed by Cap 22.5 scheme A revert | Cap 22.5; `cap22-22.5-endless-round-bridge-notes.md` |
| 460 | Closed | Main Browse Screen | Cap 22.5b | Soft-commit **landing==0** → post-frame+50ms epoch remount may chop a fling started inside that 50 ms window | **Closed:** soft-commit / deferred epoch remount **removed** with bridge revert (scheme A). | Closed by Cap 22.5 scheme A revert | Cap 22.5b; `cap22-22.5-endless-round-bridge-notes.md` |
| 461 | Closed | Main Browse Screen | Cap 22.5b | Fling past prepared[0] **and** prepared[1] can still hit a later last-page wall | **Closed:** prepared bridge pages **removed** with bridge revert (scheme A). | Closed by Cap 22.5 scheme A revert | Cap 22.5b; `cap22-22.5-endless-round-bridge-notes.md` |
| 462 | Closed | Main Browse Screen / Cap 19 | Cap 22.5b | Round-bridge remount disposed Cap19 left-swipe Listener while pointer still tracked → Unhandled `ref` after unmount | **Closed in Cap 22.5b follow-up:** remount clears `cap19LeftSwipeDragProvider`; gesture `mounted` guards on all `ref` / animation paths; `W-22.5b` remount with unfinished left-swipe pointer. Pattern retained on scheme A `advanceToNextRound` remount. | Closed by Cap 22.5b (pointer harden); retained on scheme A | Cap 22.5; ADR-041; `cap22-22.5-endless-round-bridge-notes.md` |
| 463 | Accepted (permanent) | Main Browse Screen | Cap 22.5 | Cross-round zero-hitch doom-scroll is impossible under finite-round table + boundary data-source swap | **Architectural floor (same Status class as debt 445).** Device soak under soft-commit bridge showed data-source identity swap overlapping in-flight `DragScrollActivity` / Ballistic on the common fast-scroll path — a discrete swap cannot be guaranteed never to collide with continuous scroll. Cap 22.5 ships scheme A (static placeholder + ScrollEnd → `advanceToNextRound` remount + jump) and **accepts** a hard cut. **Only path to a true zero floor:** scheme D (monotonic infinite index space + domain virtual mapping + product decision on cross-round back-scroll) — **independent Cap**, not misc polish. **Final product framing:** the residual pause is no longer an unpredictable defect surface — it now presents to the user as a legible, self-explanatory round boundary (placeholder page, then a brief deliberate pause before the next round starts), not as a stall or bug. This resolves the earlier concern that the pause read as broken/unexplained. It does **not** resolve, and was never intended to resolve, the original product ask for true endless zero-hitch doom-scroll continuity across round boundaries — that remains exclusively scheme D's territory. What changed across Cap 22.5's iteration was not the technical floor (still architectural, still non-zero), but the framing of the residual pause from "unexplained hitch" to "an accepted, consistent, user-legible boundary marker." Full retrospective + scheme D seed: `cap22-22.5-endless-round-bridge-notes.md` (see **Scheme D — future Cap seed**). | None. If true zero-hitch round boundaries become a product goal, open a new row (scheme D); do not reopen 463. | Cap 22.5; `cap22-22.5-endless-round-bridge-notes.md` |
| 464 | Closed | Photo Library / Cap 24 | Cap 22 ADR-048 | Soft-delete current asset to system Recently Deleted (App soft-delete intent) | **Closed by Cap 24 / ADR-050.** Original row parked informal “delete from Photos” intent against kickoff bans. Cap 24 shipped soft-delete-to-system-Recently-Deleted only (`PHAssetChangeRequest.deleteAssets` → RD; Session Queue kick; never Empty RD). That soft-delete limb is done. **Permanent Empty Recently Deleted / purge originals** never entered Cap 24 — see debt **469**. Historical intent-park wording and ADR-048 invalidation cues remain useful background; do not reopen **464** for Empty/purge. | Closed by Cap 24 | ADR-050; ADR-048; ADR-049; debt **469**; kickoff (narrow supersede for soft-delete only) |
| 465 | Closed | Main Browse Screen | Cap 24.2 | Widget tests W-16.4d / W-16.4e: after Fake `deviceLocalForIds`, `displayCalls` is `['a1','a1']` where tests expect a single `requestDisplayAsset` | **Closed as (a) at Cap 24.5.5 (test-assert only; no product change).** After Cap 23 Fake `deviceLocalForIds`, W-16.4d saw `displayCalls == ['a1','a1']` before Retry. Read-only path: single `_startLoad` → `_startLoadFromDeviceLocalFirstVisit` → L2 `requestDisplayAsset` #1 → permanent `iCloudDownloadFailed` → Cap 15.12 false-positive fallback `_runFullLayer1BecomeCurrentPath` → `requestDisplayAsset` #2 (sequential; not become-current double-fire / missing single-flight). Same contract already locked by **W-15.12d** (expects length==2) / **W-15.12i**. Assert rewrite: acknowledge two pre-Retry displays; then assert Retry adds exactly one more call on a single `pump` (bypassDwell). W-16.4e kept out of the 465 narrative (separate All-tab deviceLocal skip-L1 / cover harness). Not a product bug; no new debt opened. | Closed by Cap 24.5.5 | ADR-034 D5; Cap 15 deviceLocal path; Cap 16.4; Cap 23.4 |
| 466 | Closed | Main Browse Screen | Cap 24.2 | Widget tests W-L6 / W-O-* / W-Loc2 / S-1 / S-3 / S-5 (and kin): `mediaInfoOverlay` or size copy `Found 0` while fail/Retry chrome may already be correct | **Closed by Cap 24.5.5 (test-infra only).** Root cause: Cap 21 `_suppressStillCoverChrome` hides Overlay until still/poster decode-ready; harness `/tmp/fake_*.jpg` never cleared the gate. Fix: shared `still_cover_test_helpers.dart` (fixture PNG seed + `pumpUntilStillCoverReady`, preferring existing `debugForceStillCoverDecodeBroken(false)` under FakeAsync). Product suppress logic unchanged. Restored W-O / W-L2 / W-L6 / W-Loc2 / S-1 / S-3 / S-5 (and kin). | Closed by Cap 24.5.5 | Cap 21 Overlay/cover discipline; Cap 8 Overlay |
| 467 | Closed | Main Browse Screen | Cap 24.2 | Widget tests Cap 17.3 (W-17.3a/l) / Cap 17.6 (W-17.6-*) / Live L-S* preparing: `mainBrowseFeedLayer3Spinner` or `mainBrowseFeedLivePreparing_*` `Found 0` | **Closed by Cap 24.5.5 (test-infra only).** Root causes: (1) `debugForceLayer2WaitChrome` without `mediaKind: still` never forced cover-ready (Approach A: pass `FeedPageMediaKind.still` in W-17.3a/l); (2) Live/video wait-chrome kin hit same suppress / All-tab `deviceLocal` skip-L1 so hung L2 never painted cover — harness used `iCloudNotDownloaded` + shared cover helper + F1 `pumpPastLivePreparingSuppress` where needed. Did **not** broaden debugForce API semantics or change `_suppressStillCoverChrome`. Restored Cap 17.3/17.6 / L-S* / W-14.6b / W-14.4 video wait-chrome reds. | Closed by Cap 24.5.5 | ADR-034; Cap 17.3/17.6; Cap 14.6b Live chrome |
| 468 | Closed | Main Browse Screen / Cap 24 | Cap 24.4b | Occasional first-page Layer 1 stall (never promotes to L2); heal by swipe away + revisit | **Remount / Endless start-over / Confirm high-hit limb Closed via debt 477** (Cap 27.4 `893c296`, device-local). Original Kafka sightings: (1) Cap 24.4b after Endless start-over (`0ccc8fa`); (2) Cap 24.4c after Pool/Origin leave-return (`0b6c7c6`). **Not** attributed to `sessionWorkingAssetIds` / `processSoftDeletedAssetIds`. **Photos delete/restore side-channel** (no `PHPhotoLibraryChangeObserver`, ADR-044 D3) was a suspected co-factor, **not proven** and **not claimed fixed** by 477 — reopen a new debt if a non-remount repro appears with evidence. | Closed by Cap 27.4 (remount limb via **477**) | ADR-025 / Cap 15–17 L2; Cap 22.5; ADR-044 D3; debt **477** / **478** |
| 469 | Accepted (permanent) | Photo Library / Kickoff scope | Cap 24.6 | Permanent Empty Recently Deleted / purge originals from Photos (not soft-delete-to-RD) | **Never in product scope.** Split from debt **464** at Cap 24 Accept (ADR-050 D1 / D11). Cap 24 closed soft-delete-to-RD only; emptying Recently Deleted, permanent purge of originals, Hide, batch delete, and in-app trash UI remain forbidden. Kickoff “no delete/modify originals” permanent-purge reading stays binding. No Cap will schedule Empty RD / purge without a new ADR that overturns this row. | Never (no Cap) | ADR-050 D1/D11; debt **464**; kickoff |
| 470 | Accepted (phase) | Live Photo / Cap 26 | Cap 26.2 | Magnified Live long-press does not replay (user must Reset / return to fit first) | **Known MVP limitation — not a miss.** Cap 26.2 keeps ADR-052 D6/D10 magnified ignore and ADR-043 D1 Live rising-edge force-fit / no Flutter `Transform` on `PHLivePhotoView`. In-place magnified replay (Photos-like keep scale+pan) would require Host-side Live surface scale (same class as video L2 `setDisplayMagnification`); Flutter Platform View does not follow Flutter `Transform`, and `PHLivePhotoView` owns opaque playback/animation lifecycle so external bounds transforms are higher risk than the video L2 case already proven painful. Owner skipped MVP investment; no Cap scheduled to “fix” this. This row records the known consequence of those ADR decisions, not a newly found defect. | Unassigned (MVP accepted; no Cap scheduled) | ADR-043 D1; ADR-052 D6/D10 |
| 471 | Accepted (permanent) | Live Photo / Cap 21 source · Cap 9–26 browse | Cap 26.3 | System Album Live Photos (213) membership can diverge from WakeTok Live presentation (`.photoLive` / `mapMediaKind`) | **Observed (iPhone13pro Kafka, iOS 26.6 / 23G71; Host probe on `requestPresentationMetadata`):** two Photos Live-off assets remained browsable from a Live-oriented pool path but Browse showed no Live Overlay / LIVE badge and did not arm Live play — probe logged `mediaSubtypes` `0x200` with `photoLive=0` (`playbackStyle=1` observed only). A Live-on control in the same session logged `subtypes=0x208` (`photoLive=1`, `playbackStyle=3`). Not a WakeTok recognition bug: smart-album **213** membership and subtype-based Live identity are independent PhotoKit surfaces. **Symmetric risk (not observed on this probe):** if some iOS version / Live-off workflow keeps `.photoLive`, WakeTok would still show Live chrome and call `requestLivePhoto` while Photos presents a still — same class of accepted non-parity as ADR-052 Decision 11 ignoring `playbackStyle` for Live identity. Accumulation: `docs/reference/ios-photokit-implicit-behavior-notes.md` §2.3. | None. PhotoKit behaviour (smart album 213 membership and subtype Live identity are independent). If Live-off parity with Photos becomes a product goal, open a new row; do not reopen 471. | ADR-052 D11; Cap 9 `mapMediaKind`; Cap 21 smart album 213; PhotoKit notes §2.3 |
| 472 | Closed | Main Browse Screen / Cap 26.4a | Cap 26.4a | Video L1 poster→L2 path change: whole Meta Overlay flash **unverified** → closed | **Closed by Cap 26.4a device smoke (Kafka + i17 Profile).** Owner saw no Meta 3-row flash on video while accepting still L1→L2 keep-ready. **Not a side-effect of 26.4a:** keep-ready explicitly requires `_media?.kind == FeedPageMediaKind.still` and excludes `kind == video`. **Structural reason video usually does not flash:** on video L2 success, `_trackStillCoverPath` is called with `(layer1?.display ?? _media?.display)?.localFilePath` — the **existing L1 poster**, not a new L2 full-still file. The “path changed → clear `_stillCoverReady` → `_suppressStillCoverChrome` tears down Overlay” branch is usually **not entered** because its path-change precondition does not hold for video; it is not that video somehow bypasses that branch after entering it. **Residual:** if video poster wiring later **does** swap to a different file between L1 and L2, the **same** clear-ready tear-down can return — 26.4a does **not** structurally make video safe (and keep-ready would still not apply while `kind == video`). Reopen only with a video-scoped change if flash is seen after such a poster-source change. **Cap 31.3 cross-ref:** `f451166` (late poster for coverless remount video heads) is a video poster-source change of the kind named above; it keeps `_stillCoverReady` true when it attaches the poster, so the clear-ready tear-down is not entered — avoided by design and guarded by `W-31.3-L1`, not observed on device. | Closed by Cap 26.4a (Kafka + i17; structural note above) | Cap 26.4a; `vertical_media_feed.dart` `_trackStillCoverPath` + video `_applyLayer2Result` poster reuse; Cap 23.4 `_suppressStillCoverChrome`; Cap 15.5 gapless; layout notes §13; ADR-068 |
| 473 | Closed | Main Browse Screen | Cap 26.4b | Layer-1 miss page (`_loading` / center “Loading item”) still leaves Action Column tappable — Cap 24 soft-delete can succeed and the system delete confirm may show a Photos thumbnail while WakeTok still paints miss chrome | **Closed by Cap 26.4c (`32dd521` / ADR-054).** Orthogonal `mainBrowseCurrentAssetMediaCoverVisibleProvider` ANDed at … / Share / Album and Cap 19 left-swipe arming (Share keeps ADR-051 D14 ∧ coverVisible). Empty-source `actionable == false` remains a separate axis. System PhotoKit delete thumbnails stay outside WakeTok chrome. **Not** Cap 26.4b spinner/LIVE / watchdog. **Not** the historical `cap15-15.10-notes.md` peek-black “473” cross-ref (different symptom; ID reused). | Closed by Cap 26.4c | ADR-054; Cap 15.3 miss chrome; Cap 24 / ADR-050; Cap 25 Share; shell Action Column |
| 474 | Accepted (phase) | Live Photo / Cap 26.5a | Cap 26.5a | Do **not** re-add Flutter-layer Live user-release→still fade (≈180ms `AnimatedOpacity`) to mimic Photos press-hold stop transition | **Tried:** Path B overlay fade on Path R release (delay unload; swallow mid-fade `playbackEnded`; late-ended no-op; Share/`liveMotionMounted` held true until fade end). **Why not Photos-parity:** iOS public `PHLivePhotoView` has only parameterless `stopPlayback()`; `stopPlaybackAnimated:` is **macOS-only** (`#if TARGET_OS_OSX` in iPhoneOS 26.2 SDK header; Swift typecheck rejects `stopPlayback(animated:)`). Photos soft stop is private / gesture-owned — Flutter fade is camouflage, not a Host replay. **Cost:** extra Dart↔Host release timing state on an already race-prone Live path (Cap 9–26.2 class); device saw intermittent Action Column flicker (likely same class; not root-caused further); Action Column usable only after fade (~180ms friction) vs hard-cut immediate. **Decision:** benefit &lt; cost → **reverted** to Cap 26.5a hard cut (immediate watchdog cancel + `stopPlayback` + unload; Action Column restores immediately; work `a106484`). Do not re-open Flutter fade without a new owner decision and a **public** Host animation API (or an explicitly accepted non-parity product limb). | Unassigned (MVP accepted; reopen only with new owner decision) | ADR-052 D3/D6 (26.5a release-to-stop); iOS SDK `PHLivePhotoView.h` |
| 475 | Monitoring | Main Browse Screen / Cap 26.5a | Cap 26.5a | Intermittent UI hitch + Action Column three icons briefly dim on **single-finger hold** of a **Live Off** still (no LIVE badge; `mediaKind != livePhoto`) in a Live-collection Temp Pool | Unstable; trigger unknown. **Ruled out:** Cap 26 long-press replay (`shouldArm`/`shouldMount` false → Listener not mounted); Cap 19/20 single-finger hold writing `mediaCoverVisible`/`actionable`. **Related (fixed separately, not this row):** Live **On** long-press + micro-vertical peek could dim Action Column via off-current `_syncMediaCoverVisibleGate` writing `false` into the shared cover provider — fixed by current-only publish (see W-26.4c-10). **Open for this row:** Live Off hitch / dim without that path. **Next soak cue:** whole-UI freeze vs icons-only dim while feed still scrolls. Do **not** “fix” by expanding Live-motion Action Column mute. Related: debt **471**, **476**. | Opportunistic note if seen again (device, build, preceding gesture / item type); Cap discussion only if a clean repro appears | ADR-052 D6/D11; ADR-054 cover-visible; debt **471**; debt **476** |
| 476 | Accepted (phase) | Main Browse Screen / Live cover gates | Cap 26.6 | Live motion ↔ shell provider hygiene gaps (latent; not the neighbour-wipe root cause) | Three residual desync risks found while probing Action Column dim (debt **475** class / Live On micro-peek): (1) `BrowseMagnificationNotifier.onLiveMotionMountedChanged` publishes `mainBrowseCurrentLiveMotionMountedProvider` via **microtask**, so page `_liveMotionMounted` and the shell provider can disagree for a frame; (2) several `MediaFeedPage` paths set `_liveMotionMounted = false` **without** calling `onLiveMotionMountedChanged(false)` (provider can stay stale true); (3) `_unloadLiveMotionSurface` does not call `_syncMediaCoverVisibleGate` — cover recovery relies on a later current-page rebuild / build-alignment. None proven as a standalone product repro after the off-current sync fix; keep until a Cap revisits Live/shell gate ownership. | Reopen only on a reproducible Live cover / chrome gate bug, or when a Cap reworks Live / shell gate ownership | ADR-054; ADR-052; debt **475** |
| 477 | Closed | Main Browse Screen / Cap 27.4 | Cap 27.4 | `roundEpoch` remount head stuck on Layer 1 (Confirm / Endless `same_list_to_0` / order→shuffle, incl. never-visited shuffle head) | **Scope: device-local remount only; Browse-current remount paths only** (Confirm / Endless / in-Browse order change). Root: remount skipped Session L2-ready then All-tab still painted soft L1; Cap 26.4a keep-ready + gapless stuck the soft frame after Host `LAYER2_APPLY` (probe: SKIP+APPLY while owner still saw L1; heal via swipe Session L2-ready). Fix in `893c296`: one-shot prefer-Host (no `hadSessionToken` gate), omit Cap 22.5 L1 seed + All-tab soft preview on remount Host L2, hard-reload cover on APPLY. Kafka+i17 soak PASS; `OWNER_MARK_STUCK`=0. **Does not** cover non-`deviceLocal` / iCloud remount — see debt **478**. **Did not** cover Settings / auth / other non-Browse-current remount limbs at Cap 27.4 close — that separate arming-window gap was later found and closed as debt **479** (`8d6d7cc`); do not read this Closed row as full off-Browse coverage. | Closed by Cap 27.4 | ADR-055; Cap 15.10/15.12/22.5/26.4a; debt **468** / **478** / **479** |
| 478 | Accepted (phase) | Main Browse Screen / Cap 27.4 | Cap 27.4 | Non-`deviceLocal` (incl. iCloud) `roundEpoch` remount head may still stick soft Layer 1 | **Mechanism risk (not a confirmed iCloud product repro).** Cap 27.4 skip-L1-paint applies only on the device-local fast path; full L1→L2 still paints soft preview first. `_forceStillCoverHardReload` may be consumed on L1 `_trackStillCoverPath`, so `LAYER2_APPLY` can re-enter Cap 26.4a keep-ready + gapless soft stick. Parked until iCloud-only / non-local remount assets can soak a fix. Does not reopen debt **477**. **Probe:** Debug/Profile Settings → **L1-stall probe** (`Cap27L1StallProbeSettingsSection` / `cap27_l1_stall_probe.dart`; log `Documents/cap27_l1_stall_probe.log`); Cap 31.5 deleted the Settings entry and the implementation (`0c921fa`; owner, Cap 31.4 debt review); recover from git history if reopened. | Reopen only on a reproduced soft-L1 stick on a non-local remount head | Cap 15.12/26.4a; debt **477**; ADR-055; `cap27_l1_stall_probe*.dart` (deleted in `0c921fa`) |
| 479 | Closed | Main Browse Screen / Cap 27.6 | Cap 27.6 | Settings leave/return (and similar non-Browse-current) `roundEpoch` remount head stuck on Layer 1; newestFirst easiest | **Related 477 (stays Closed).** Cap 27.4 prefer-Host closed Browse-current remount stick; Settings / auth limbs were **not** in that soak. Root: prefer-Host armed only under `isCurrent`, and a post-frame clear dropped pending while Browse was off — remount finished off-current never armed Cap 27.4 Host path. Fix in `8d6d7cc`: sticky `_epochRemountPreferHostPending` until consume + become-current re-arm. i17 soak PASS (three orders × immediate/dwell return; Confirm/Endless unaffected). Widget: W-27.6-479. Does not reopen **477**; does not close **478**. **Cap 28 follow-up:** Settings leave remount limb **dissolved by Cap 28 keep** (no `restartSession` on Browse→Settings). Sticky prefer-Host for remaining off-Browse→Browse remount (access-scope dirty on Settings → consume on return) covered by Cap 28.7 `W-28.7-479-sticky` (`5f4977c`); mechanism retained (ADR-058 D7). | Closed by Cap 27.6 (`8d6d7cc`) | ADR-055; Cap 27.4; Cap 28.4/28.5/28.7; debt **477** / **478**; `vertical_media_feed.dart` |
| 480 | Closed | Main Browse Screen / Cap 28.3 | Cap 28.3 | Confirm / Endless (and other `roundEpoch` remount) dual visible handoff: soft-L1 present → one-frame black between L1 and L2; soft-L1 absent → one-frame Loading item | **Settings limb closed by Cap 28 keep** (28.1/28.2: remount + prefer-Host + hardReload). Remount paths: Cap 27.4 prefer-Host skips Session L2-ready, forces Host L2, and on APPLY hard-reloads cover (clear keep-ready / bump Image key). **Closed by Cap 31.2c (`08aa987`):** (B) on the remount hard-reload still APPLY the L2 cover mounts normally while a Loading shell overlay (`IgnorePointer`) stays on top until frame-ready / decode-broken; Live motion prepare is deferred until reveal; Cap 26.4b forced spinner excluded during the hold — the black / all-dim decode gap and the spinner peek are gone. (C) a born-current page with a Session L2-ready token is tagged Cap 17.3 a4 in `initState`, so the first frame no longer paints ADR-031 miss chrome (corner gold + "Loading item"). The earlier precache candidate was infeasible (`ResizeImage` cache size depends on layout box × DPR). **Coverless remount-head video (Cap 27.4 skips L1; no poster): no change** — Action Column enables at `_surfaceReady` per ADR-054 D2/D3, and "…" / Album / Share all run by asset id (i17 log: 13 coverless remount heads, 0 enabled-before-ready); the black is missing L1 or the video's own content. Widget: W-31.2c-B1/B2/B3. i17 + Kafka Release PASS. Prefer-Host mechanism (**477** / **479**) unchanged; non-`deviceLocal` stick stays debt **478**. | Closed by Cap 31.2c (`08aa987`) | Cap 27.4/27.6; debt **477** / **478** / **479**; Cap 28.1/28.2 notes; ADR-054; ADR-058 |
| 481 | Accepted (phase) | Main Browse Screen / Cap 28.4 | Cap 28.4 | Settings resume may show one poster/cover frame on video (play or pause) | **Symptom:** Browse→Settings→Browse on a completed video can flash one frame of the asset poster/cover before L2 PV is visually back — same whether the item was playing or paused. **Mechanism (Q-PV = B):** soft leave detaches the native Platform View; resume remounts PV. Cap 28.4 A′ keeps chrome gates (no Action Column staircase); the frame is the cover painted while `_surfaceReady` is briefly false (and/or Cap 15.11b poster-hold when that latch arms) — a deliberate anti-black hold, not the Cap 28 chrome cascade. **Intentional trade-off:** Q-PV = A (keep PV mounted under Settings) could remove the frame but risks off-screen PV bleed/touch steal, holding the 1+1 player slot, and power cost — rejected for this Cap. **Not a reopen of 429:** cousin symptom (poster vs L2), different mechanism (Settings PV detach/remount vs prior path). **Candidates:** (1) Q-PV = A + Host ready-for-display short-circuit; (2) latch a leave-time frame as the resume hold instead of the static poster (cost/feasibility unverified). Re-evaluate with Caps that redesign video surface lifecycle while Browse is non-visible (Background Audio / Auto-play track). Owner device check 2026-10-02: still reproduces on Settings resume, both playing and paused; accepted. | Re-evaluate with Background Audio / Auto-play surface-lifecycle Caps | ADR-058; ADR-006; ADR-032; cousin of closed **429** (do not reopen 429) |
| 482 | Accepted (phase) | App Foundation / Cap 31.1 | Cap 31.1 | Sheet titles and sheet button labels (plus two guide titles) still borrow `titleMedium` = `titleChrome`; no dedicated text-style roles yet | **Deferred, not rejected.** ADR-061 evaluated splitting sheet titles and sheet button labels into their own tokens and deferred it (touches 6+ feature files; needs a new device acceptance); Cap 31.1 shipped only the `titlePage` split. Still coupled (canonical list: `media-chrome-layout-notes.md` §14): sheet titles — Cap 19.4 actions sheet, Cap 27.4 order sheet; sheet button labels — Cap 24.3 Delete, Cap 26.5 Add to Album; guide titles — Cap 19.6 left-swipe guide (Cap 30 `<3>`), Cap 30.3 vertical coach (`<1>`) — guide titles were not evaluated by ADR-061, decide their scope when this row is picked up. **Risk:** any `titleChrome` retune moves all six; Delete heavier than Add to Album (Cap 26.5 owner lock, guard `W-26.5-8`) holds only while `titleChrome` weight stays above Add to Album's local weight override. Out of scope: the permission request / blocked pages have no AppBar since Cap 31.4 (`7d47ef3`), so ADR-061 Decision 4 has no remaining consumer. | Reopen when `titleChrome` needs a retune or a sheet title / sheet button label needs its own style | ADR-061 |
| 483 | Accepted (phase) | iOS Photos permission | Cap 31.4 | On a zh system the Photos permission prompt shows the purpose string in English | ADR-062 deliberately waived this for v1 | Reopening needs a new ADR plus device verification | ADR-062 |
| 484 | Accepted (phase) | Share / Cap 31.2b | Cap 31.2b | Video share hands over the original Photos file, which keeps its capture location; stills are shared with location removed (ADR-064) | Cap 31.2b device check: a camera-recorded `.MOV` shared from WakeTok arrived on Mac with latitude/longitude (`mdls`). Video share was out of 31.2b scope; behaviour is unchanged since Cap 25 | Checked in Cap 32.1: the privacy and support pages say stills are shared without location and videos may keep it; the App Store text makes no location claim. Reopen after v1 only if the owner wants parity between stills and video | ADR-051, ADR-064 |
| 485 | Closed | Main Browse Screen / Cap 31.2c | Cap 31.2c | `roundEpoch` remount head: shell gates (`MediaCoverVisible`, `Layer2DisplayReady`, `LiveMotionMounted`) keep the previous tree's values for the new tree's first frame — Action Column paints enabled, then dims, then re-enables | Pre-existing (reproduced 100 % on `77e3f10` and `7d3d450`, still and Live pools; i17 Profile chrome-axis logs). ADR-054 D2 publishes only from the current `MediaFeedPage` post-frame, so nothing cleared the shell between the old tree's dispose and the new page's first publish. **Closed by Cap 31.2c (`08aa987`):** `VerticalMediaFeed` listens to `roundEpoch` and writes `false` to the three gates before the new tree's first frame (false-only second writer, ADR-066). Widget: W-31.2c-A1. i17 + Kafka Release PASS. Live ↔ shell hygiene gaps stay debt **476** (untouched). | Closed by Cap 31.2c (`08aa987`) | ADR-066; ADR-054; debt **476** |
| 486 | Accepted (phase) | Main Browse Screen / Cap 24 half-sheet | Cap 31.3 | Cap 24 exact capture minute reads EXIF/TIFF tags out of the Layer 2 display temp (cross-language implicit contract) | `loadCap24MinuteLandmark` reads the Session L2-ready still temp and parses `DateTimeOriginal` / TIFF `DateTime` with a JPEG-only Dart parser; Host keeps the tags there only via `DisplayCaptureTime.merging` (ADR-065 D4). Any change to the temp producer (format, encoder, render path) silently falls back to Instant `~` — happened once in 31.2b-1, caught only by device check. Guards: RunnerTests on `DisplayStillRender` only (not in the `flutter test` gate; no CI, debt **449**); no Dart parser test; no Host→Dart contract test. **Decouple candidate:** return capture wall-clock from `requestPresentationFileSize` (it already fetches the original bytes; no extra PhotoKit round trip), then drop the L2 lookup, the Dart parser and `DisplayCaptureTime.merging`. Needs a Pigeon field + new ADR + Cap 24 device acceptance. Side benefits: exact time also when the temp was evicted or no L2-ready token exists (as long as the original is local — iCloud-only originals still fall back to `~`); HEIC / PNG originals that carry the tags are read by ImageIO directly, without re-encoding to JPEG; later changes to the Layer 2 temp producer no longer need a Cap 24 capture-time re-check (the original fetch still matters for Tier 4 file size). File size is **not** read from the temp; its dependence on the original being local (L2 original fetch) is ADR-018 by design and stays. **Guard: already added** — `test/architecture/file_content_read_test.dart` bans `dart:io` file-content reads in `lib/features/**` / `lib/app/**`; `cap24_minute_landmark.dart` is its only allowlist entry (fails once no read is left — remove the entry when this debt is paid); see ADR-067 (ADR-009 supplement). | Pick up, or re-verify the Cap 24 minute row on device, before any change to the Layer 2 still temp producer | ADR-050 D7; ADR-065 D4; ADR-018; ADR-067 |
| 487 | Accepted (phase) | Main Browse Screen / Cap 31.3 | Cap 31.3 | Video head landed after a pool switch, order change or Endless new round: on its first swipe away, the peek still shows black once if the leave comes within tens of milliseconds of the remount (late poster not back yet); assets with no local thumbnail likewise (same class as debt **400**) | Not fixed: removing it needs a Cap 27.4 change that touches the `W-27.4b` guard, and album pools would still not be covered | Reopen if someone hits it, or fold into a later Cap 27.4 clean-up | ADR-068; `f451166` |
| 488 | Accepted (phase) | Main Browse Screen / Cap 31.4a | Cap 31.4a | Live long-press right after the network comes back (auto-play had failed offline; still on the same page): the still stays static with no progress cue while the motion downloads from iCloud, and Share was seen dimmed after the long-press; it returned on release (observed). Releasing before the download finishes cancels it (code reading); holding through played it (observed). Leaving and coming back plays it via auto-prepare with the gold spinner (observed) | Path S is silent by ADR-052 D3 (inferred: Path S is normally used after the motion was loaded once); ADR-037 D4 keeps `_livePreparing` and the loading chrome for the prepare path, so a cue would add a new wait-chrome case, and keeping the download after release goes against ADR-052's immediate cancel on release. `requestLivePhoto` allows network access (`isNetworkAccessAllowed = true` since `8920120`; ADR-019 D6–D7); ADR-025 D6 (repeated in its D7 and in ADR-029 D2) still says Live motion stays local-only and is not superseded — a pre-existing wording/code mismatch this row does not resolve. Owner judged it an edge case not worth new UI (2026-10-02); behaviour unchanged. Candidate if ever fixed: show the existing gold corner spinner (beside LIVE) while the finger is held and Path S is in flight past a threshold, hidden on ready, on release, or on failure (the spinner hides and the "!" shows); drive it by its own hold-owned flag, not `_livePreparing`; set the threshold from device timing of a local Path S so a local long-press stays silent. Feasibility from code reading only | Re-evaluate if seen in normal use, or when Path S or the wait chrome is next changed; also decide whether to narrow the ADR-025 D6 / ADR-029 D2 wording (a new ADR; docs only) | ADR-019; ADR-025; ADR-037; ADR-052; ADR-071 |
| 489 | Accepted (phase) | Main Browse Screen / Cap 17.5b | Cap 31.4a | Layer 2 failed slot flashes on a retry while offline: Retry on the failed slot, or the resume auto-retry, hides the slot at once, while the still's corner spinner is suppressed for the first 150 ms of the request; offline the request fails within that window, so the slot disappears and comes back. Switching the network by hand (Control Center, Airplane Mode) takes the app out of the foreground and back (inactive or paused, then resumed), which fires the resume auto-retry (ADR-036 D6); reproduced every time by the owner (iPhone 13 Pro), and by code reading it fires whenever the failure lands before the app is back in the foreground. A manual Retry while offline flashes the same way. Possibly also seen while swiping offline; not reproduced on iPhone 13 Pro after several tries (not verified) | Owner observed it on device (2026-10-02) and judged it of no practical impact, not worth changing the closed-Cap retry and wait chrome. Candidate if ever fixed: keep the failed slot during the resume auto-retry only, until the result returns or a threshold passes, then switch to the spinner (manual Retry unchanged; its change is the tap feedback); set the threshold from the offline failure time measured on device, not the 150 ms; do not remove the resume auto-retry (it would break debt **406**). Feasibility from code reading only | Re-evaluate if seen in normal use, or when the Layer 2 retry / wait chrome is next changed | ADR-034; ADR-036; ADR-037; debt **406** |
| 490 | Closed | Main Browse Screen | Cap 35.2b | Browse chrome text follows the iOS Larger Text setting and breaks at accessibility sizes: top bar labels overlap, bottom bar labels clip at different sizes, date and loading text overlap (Action Column icons unaffected) | Every `Text` follows the system text size while the chrome geometry assumes the default size; present since v1.0.0 (a Cap 27.4 test already noted the shell overflowing at 2x text on SE). Found on device during the Cap 35.2b check (2026-10-11). Owner moved the fix into v1.0.1 on 2026-10-11 | Closed by Cap 35.2c | ADR-076 |
| 491 | Accepted (phase) | App-wide | Cap 35.2c | With iOS Bold Text on, Latin letters and digits draw about one weight step heavier, and wider, at the same size and position; Chinese glyphs are unchanged. The system font is fixed when the app process starts: turning Bold Text on or off while the app runs changes nothing until the app is force-quit and reopened (SE simulator pixel comparison and owner check on Kafka, 2026-10-12). On a 375 pt SE in English the top bar gap between "Saved pools" and "Create Pool" narrows from about 5 pt to about 2 pt, and on the permission request page the first point and the button label wrap to two lines; no overflow or overlap found (SE simulator en and zh-Hans, Kafka English) | `MediaQuery.boldText` false removes only the framework bold; the iOS engine still takes the system font with Bold Text applied (flutter/flutter#162804, open, not fixed in Flutter 3.41.9), resolves it once per process and does not reload it when Bold Text changes. Bundling an app font would change the typeface on every screen. Owner accepted the residual on 2026-10-11 | Re-evaluate when flutter/flutter#162804 is fixed | ADR-076 |

> Known debt ID **402 is permanently retired and must not be reused**:
> historical append-only notes used “UX-1 (402)” for debt **436**, while an
> earlier live Cap 18 draft reused 402 for debt **434**. Historical files stay
> unchanged; all new references use this table's canonical ID column.
>
> Bare Known debt ID **403** is retired as a single row (split into **403a** /
> **403b-progress** / **403b-wallclock**). Do not reuse bare 403. Logged stays
> empty on the split rows: first logged as 403 before Cap 18.
>
> Bare Known debt ID **456** is retired as a single row (split into **456a** /
> **456b** at Cap 23.1). Do not reuse bare 456. Logged on both split rows
> remains Cap 21.6 (original row). Historical notes may still say “456”;
> new references use **456a** / **456b**.
