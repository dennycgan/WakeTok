# PhotoKit implicit behavior notes (engineering accumulation)

This file is **not an ADR**. It does not record product decisions.
It accumulates PhotoKit / Photos.framework behaviors that are easy to
misread: multiple independent signals that often agree but are **not
guaranteed to stay in sync**, plus other undocumented or weakly
documented Host facts WakeTok has already tripped on.

**STATE.md** may point here; do not paste long matrices into STATE.

When iOS ships a major Photos / PhotoKit change, re-check entries that
matter to the active Cap before assuming last year’s probe still holds.
When a new mismatch is confirmed, **append a row here** (with device +
OS + evidence class) instead of rediscovering from zero.

---

## 1. Three classification surfaces (Live / Animated family)

WakeTok (and Photos UI) can answer “is this Live?” / “is this Animated?”
using at least three **independent** PhotoKit surfaces. They are
maintained separately and can update on different timelines.

| # | Surface | Shape | Rough role |
|---|---------|--------|------------|
| A | `PHAsset.mediaSubtypes` | `OptionSet` (bits may combine) | “Origin” / structural flags (e.g. `.photoLive`). Often tied to how the asset was captured or still classified at the subtype layer. |
| B | `PHAsset.playbackStyle` | Single enum value | **Presentation preference** for how to play/show the asset. Can change when the user edits effects in Photos (Loop / Bounce / Long Exposure / turn Live off, etc.). |
| C | Smart-album membership | `PHAssetCollection` (e.g. subtype **213** Live Photos, **214** Animated) | Separate catalog / index. May lag A/B, or use rules that are not identical to A or B. |

**Working rule for new features:** assume A/B/C can diverge. Pick the
surface that matches the product question, verify on device, and do not
treat “any one signal ≈ the others.”

WakeTok product choices that *select* a surface live in ADRs (e.g.
ADR-052 Decision 11). This file only records the **mismatch phenomena**
and evidence class.

---

## 2. Confirmed mismatch entries

Evidence classes (do not collapse these):

- **Device probe** — Host logged public API fields on a named device/OS.
- **Design + SDK** — Locked in an ADR from SDK headers / owner product
  path; **not** re-measured as rawValues in the Cap 26.3 Live-off probe
  session unless noted.

### 2.1 Loop / Bounce Live vs `playbackStyle` (identity gate)

- **Phenomenon:** A Live Photo whose Photos effect is Loop or Bounce
  typically still has `mediaSubtypes` containing `.photoLive`, while
  `playbackStyle` typically becomes `.videoLooping` (confirmed via SDK
  headers; not re-probed as a rawValue in this session). Subtype bits
  for Loop/Bounce themselves are **not** exposed on
  `PHAssetMediaSubtype`.
- **Surfaces:** A (`.photoLive`) vs B (`playbackStyle`).
- **Evidence class:** **Design + SDK** (ADR-052 Decision 11). Not
  re-probed as `subtypes` / `playbackStyle` rawValues in the Cap 26.3
  Live-off Console session.
- **Product stance (see ADR, do not re-decide here):** Cap 9 / Cap 26
  Live identity and long-press eligibility use **A only**
  (`.photoLive` → `mapMediaKind` → `livePhoto`). They **deliberately
  ignore B** for that gate. Mismatch is the *phenomenon*; Decision 11
  is the *choice of surface*.
- **Cross-ref:** ADR-052 Decision 11; Cap 9 `mapMediaKind` /
  `LivePhotoApiHost` `.photoLive` guard.

### 2.2 Smart album Animated (214) vs `.imageAnimated`

- **Phenomenon:** Membership in System Album **Animated**
  (`smartAlbumAnimated` / **214**) can include Loop/Bounce Live Photos.
  Those assets remain Live for WakeTok Browse when A has `.photoLive`;
  their `playbackStyle` is typically **not** `.imageAnimated`.
- **Surfaces:** C (214 membership) vs B (`.imageAnimated`) vs A
  (`.photoLive` for Live chrome).
- **Evidence class:** **Design + SDK / owner Build-a-Pool path**
  (ADR-053). Not measured via album-membership Host probe in the
  Cap 26.3 Live-off Console session.
- **Product stance (see ADR):** Overlay Animated label uses
  `mapMediaKind == image` **and** `playbackStyle == .imageAnimated`
  only — **never** 214 membership (avoids false Animated on Live).
- **Cross-ref:** ADR-053 Decisions 2–3; Cap 21 smart album **214**.

### 2.3 Smart album Live Photos (213) vs Live turned off

- **Phenomenon:** An asset the user turned **Live off** in Photos can
  still appear in System Album **Live Photos** (**213**) and thus in a
  Live-oriented Build-a-Pool source, while WakeTok Browse shows **no**
  Live Overlay / LIVE badge and does not arm Live play / Cap 26
  long-press — because Host `mapMediaKind` did not classify
  `livePhoto` (`mediaSubtypes` lacked `.photoLive`).
- **Surfaces:** C (213 membership) vs A (`.photoLive`).
- **Evidence class:** **Device probe** — iPhone13pro Kafka,
  iOS **26.6 (23G71)**, temporary Host log on
  `requestPresentationMetadata` (Cap 26.3 session):

  | Role | `localIdentifier` (prefix) | `mediaSubtypes.rawValue` | `photoLive` | `playbackStyle.rawValue` (observe only) |
  |------|----------------------------|---------------------------|-------------|----------------------------------------|
  | Live off #1 | `C1492781-3A89-4DA1-81C0-47333C0FD0D4` | `0x200` | 0 | 1 |
  | Live off #2 | `90FF78D0-3B15-401E-A27E-2BAEA18CB4A0` | `0x200` | 0 | 1 |
  | Live on (control) | `26B110E2-069E-4C3B-AE48-2696AC3B779B` | `0x208` | 1 | 3 |

  Reading: `.photoLive` is `0x8`; off rows lack that bit; on control
  `0x208 == 0x200 | 0x8`. `playbackStyle` logged for observation only —
  not used for Live identity (ADR-052 D11).
- **Symmetric risk (not observed on this probe):** If some iOS version
  / Live-off workflow **keeps** `.photoLive`, WakeTok would still show
  Live chrome and call `requestLivePhoto` while Photos presents a
  still — same *class* of non-parity as ignoring `playbackStyle` for
  identity (ADR-052 D11).
- **Cross-ref:** Known debt **471** (Monitoring); Cap 21 smart album
  **213**; Cap 9 / Cap 26 `mapMediaKind`.

---

## 3. Other PhotoKit implicit behaviors (index only)

Pointers only — details stay in ADRs / STATE debt, except
non-classification phenomena that need their own evidence record
(subsections below the table). Revisit on major iOS Photos changes if
the linked Cap is active.

| Topic | Why “implicit” | See |
|-------|----------------|-----|
| `PHAssetResource` KVC `locallyAvailable` | No public Swift property; list-time local vs iCloud | ADR-011 family; related Known debt |
| Undocumented smart-album subtype raw values (e.g. Recently Deleted `1000000201`) | Not all catalog IDs are public enum cases | `docs/reference/cap21-smart-album-boundary.md`; Cap 11 / 21 |
| Limited library settle race | Authorization UI can return before PhotoKit library is populated | Cap authorization / resolve ADRs |
| `PHImageManager` opportunistic double callback / cancel | Multiple resultHandler invocations; cancel best-effort | Browse load / iCloud path ADRs |
| `PHLivePhotoView` / UiKitView vs Flutter `Transform` | Platform View may not follow Flutter magnification transforms | Known debt **470**; ADR-043 |
| `PHLivePhotoView` natural-end callback not guaranteed | `didEndPlaybackWith` is the only public end signal, but it did not arrive after natural end for one asset | §3.1 below; ADR-063 |
| Animated stills animate only from original bytes | `playbackStyle == .imageAnimated` decides whether the Layer 2 temp keeps a multi-frame file; Flutter, not a player, advances frames | §3.2 below; ADR-073 |

### 3.1 `PHLivePhotoView` natural-end callback missing (Cap 31.2)

- **Phenomenon:** For one unedited, locally stored `.livePhoto` asset
  (IMG_1935), `PHLivePhotoView` reported
  `livePhotoView(_:willBeginPlaybackWith:)` and then never reported
  `livePhotoView(_:didEndPlaybackWith:)` after the motion finished, on
  auto-play and on long-press replay. In WakeTok, no play that stayed
  on screen past the motion length received it (iPhone 17: 7 of 7;
  iPhone 13 Pro: 3 of 3). The Photos app plays the same asset normally
  (owner observation).
- **Follows the file content:** an AirDropped copy on a second device
  (a new library asset; same paired video, 3,212,167 bytes, `mvhd`
  duration 1.757 s) reproduced it in WakeTok.
- **Reproduced without WakeTok:** a minimal standalone UIKit app (no
  Flutter, no WakeTok code) on iPhone 17 missed `didEndPlaybackWith` at
  natural end for this asset in 10 of 10 runs, with the default and
  with a disabled `playbackGestureRecognizer` (5 runs each). Control
  IMG_1934 delivered it in 10 of 10 runs.
- **Mid-motion end triggers:** `stopPlayback()` does not deliver
  `didEndPlaybackWith` synchronously; it arrives asynchronously about
  305–312 ms later (native repro, IMG_1934, view kept in the window).
  In WakeTok the callback was not observed after a stop (21 cases; no
  callback for 0.43–4.7 s, until the next Host event), most likely
  because the Dart side unmounts the view within 0–14 ms of the stop
  (view release time is not logged). Setting `livePhoto = nil` produced
  the callback within ~1 ms every time in WakeTok (64 cases, 3 of them
  on IMG_1935). A stop on IMG_1935 itself with the view kept alive was
  not tested.
- **Control (normal assets):** the system end arrived after
  `willBegin` + paired-video `mvhd` duration by typically ~0.47–0.51 s
  (24 of 28 natural-end samples); the other 4 samples were 0.61–0.76 s.
- **Only measured layout difference:** movie − video-track gap 0.073 s
  vs 0.000–0.035 s on controls; not a proven trigger.
- **Attribution:** treated as iOS / PhotoKit behavior specific to this
  asset's content — it reproduces without Flutter or WakeTok code and
  with either gesture configuration. The repro cannot rule out
  additional effects specific to Platform View hosting.
- **Evidence class:** **Device probe** — temporary Host log
  (Cap 31.2 acceptance build) on iPhone 17, iOS 26.6.2 (23G90), and
  iPhone13pro Kafka, iOS 26.6 (23G71); minimal native repro on
  iPhone 17, iOS 26.6.2.
- **Cross-ref:** ADR-063; `docs/acceptance/cap31-31.2-notes.md`. No
  debt row (Cap 31.2 triage mapped it to a new path, not debt 470 /
  471).

### 3.2 Animated images: the Layer 2 temp file decides whether they animate (Cap 32, ADR-073)

- **Phenomenon:** WakeTok has no player for animated stills. A GIF
  animates only because the Layer 2 temp file keeps the original
  multi-frame bytes and Flutter's image stream decodes and advances the
  frames. When the Host re-encodes the still as a single-frame JPEG
  (`DisplayStillRender.jpeg`, ADR-065, `7d3d450`), only frame 0 survives.
  ADR-073 keeps the original bytes when
  `kind == .image && playbackStyle == .imageAnimated` (the ADR-053
  condition; Live never qualifies).
- **Evidence class:**
  - **Device** — the regression and the fix only. Owner: a GIF saved
    from another app animated at Cap 26.3 (recollection), was frozen
    before ADR-073, and animates after it (Cap 32 acceptance, GIFs saved
    from other apps (sizes not controlled), on iPhone 17, iOS 26.6.2
    (23G90), and iPhone 13 Pro, iOS 26.6 (23G71)). Other animated
    formats and the largest GIFs: not specifically tested.
  - **Unit test (RunnerTests, simulator)** — `DisplayStillRender.jpeg`
    outputs one frame for a two-frame GIF
    (`testJpegRenderKeepsOnlyTheFirstFrame`); the keep-original branch
    keeps both (`testAnimatedStillKeepsOriginalFrames`). `7d3d450` is
    identified by code reading plus this test, not by a device bisect.
  - **Code reading, not device-tested** — everything below (Flutter
    3.41.9).
- **Revisit (code reading):** Flutter keys the image by
  `ResizeImage(FileImage(path))` (path plus decode size). A
  `MultiFrameImageStreamCompleter` advances frames while it has
  listeners; losing the last listener only cancels the next-frame timer,
  and a new listener resumes from the codec's next frame. `ImageCache`
  holds a keepAlive handle, so the stream survives without listeners.
  `PageView` (`allowImplicitScrolling`) keeps the ±1 pages mounted, so a
  one-page swipe never stops it (it keeps animating off screen). If the
  page unmounts but the temp file survives (`DisplayTempFileStore` keeps
  two), the `BrowseL2ReadySession` fast path reuses the same path, hits
  the image cache, and playback continues from where it stopped. If the
  file was evicted, the Host writes a new file name, Flutter treats it
  as a new image, and it restarts from frame 0. Session boundaries,
  forced Host reloads and an image cache flush under memory pressure
  also restart it.
- **Finite-loop GIFs (code reading):** a GIF can carry a finite loop
  count (`NETSCAPE2.0` extension; no extension means play once by
  convention; `Codec.repetitionCount` 0 = once, -1 = forever). After
  the last repeat the completer releases the codec and the image stays
  on its last frame until Flutter decodes it again (new file name, or
  the cached stream is dropped). Most GIFs in the wild loop forever.
  Not checked on any asset.
- **Other animated formats (code reading):** the engine registers GIF
  and WebP multi-frame decoders; animated HEIC and APNG may decode as
  one frame. Multi-frame images ignore the decode target size
  (`ImageDescriptor.instantiateCodec` uses the multi-frame codec without
  it), so each frame decodes at full size. Not checked.
- **If an animated image does not move, check in this order:** (1) is the
  temp file the original bytes — check the leading bytes (`GIF8`), not
  the name (temp files always end in `.jpg`); (2) does the keep-original
  condition hold for this asset (`playbackStyle`); (3) is the page under
  a disabled `TickerMode` (none in `lib/` today); (4) image cache /
  memory pressure.
- **Cross-ref:** ADR-043 Decision 12; ADR-053; ADR-065; ADR-073.

---

## 4. Maintenance

1. Before trusting an entry after a major iOS upgrade, re-probe or
   explicitly mark “unchecked on iOS X.Y.”
2. New mismatches: append under §2 (classification) or §3 (index), with
   **evidence class**, device/OS when probed, and ADR/debt links.
3. Do not move product decisions into this file — flip or add ADRs;
   keep this as the phenomenon / evidence log.
