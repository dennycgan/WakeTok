# Cap 20 post-20.5 — still black-flash + video shrink / release spike

> Work anchors: black-flash `3d29823` (2026-09-04); shrink C + spike A
> `282009e` (2026-09-04). Docs after owner device验收.

## Still L1↔L2 black flash (debt **450** — Closed)

- **Cause:** Cap 20.4 L1 unify forked `TransientMagnificationActiveBinder` /
  `StillMagnificationActiveBinder` on L1↔L2 → Image Element rebuild.
- **Fix (`3d29823`):** one `MagnificationHostModeBinder` on the still cover
  tree (`active` gates `setMode` only).
- **Device:** local-asset doom-scroll (Kafka / i17) — black flash gone.
- **Regression guards:** `W-15.5a` enter + leave continuity in
  `test/features/main_browse/still_image_element_continuity_test.dart`
  (also feed `W-15.5a`).

## Video permanent shrink — mechanism C (`282009e`)

- **Cause:** `FlutterPlatformViewsController compositeView` called
  `setFrame` on the Platform View root while `transform ≠ identity`,
  folding scale into `bounds` (e.g. `390/scale × 762/scale`). After
  mag returned to identity, the surface stayed small.
- **Fix:** outer `PlaybackSurfaceContainer` always identity; transform
  only on inner `magnificationContent`; layout sync via bounds+center.
- **Device (Kafka, separate from A):** land on video → pinch before /
  around push arm → release→fit; revisit path — **C PASS** (no stuck
  shrink / looping small frame).

## Release→fit scale spike — mechanism A (`282009e`)

- **Cause:** `_finishTransientReleaseToFit` set
  `_releaseController.value = 0` while `_onReleaseTick` was still
  listening → one republish of `_releaseFromScale` (e.g. 1.0 → peak →
  1.0). Direction = enlarge flash; **independent** of shrink C.
- **Fix:** `_silenceReleaseControllerToZero` (removeListener → value=0 →
  addListener) on finish / resetLocal / handoff / beginPinch.
- **Device (Kafka, separate from C):** pinch magnified → release→fit —
  **A PASS** (no peak flash after fit).
- **Regression guard — `T-20.A-1`:**
  `test/features/main_browse/cap20_video_magnification_test.dart` —
  FakePlaybackRepository; after the release peak, once a
  `setDisplayMagnification` scale is ≤1.02, no later call may exceed
  1.02. Re-run PASS confirmed before docs commit.

## Related

- ADR-043 Decision 13 narrow supplement (`282009e`); Decision 14 binder
  continuity.
- STATE debts **450** Closed; **451** Open (`W-14.6c` BoxFit.fill vs
  contain — unrelated hangover).
