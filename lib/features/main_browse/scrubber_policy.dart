/// Cap 18.5 pure scrubber policy (unit-tested without widgets).
library;

import 'dart:typed_data';

/// Matches Host preview request coalesce (ADR-040 Decision 13 supplement).
const double kScrubPreviewBucketStepSeconds = 1.0;

/// §2.1 borrow-window wall-clock cap (ADR-040 Decision 13 supplement).
const int kScrubPreviewBorrowMaxWallClockMs = 350;

/// Max preview-bucket steps a successful JPEG may trail the current bucket.
const int kScrubPreviewBorrowMaxBucketSteps = 1;

/// Initial minimum interval between preview **requests** (not Host SLA).
const int kScrubPreviewInitialThrottleMs = 120;

const int kScrubPreviewMaxThrottleMs = 300;

/// Cap 18.5 progress track thickness (logical px). Tune on device before tokenizing.
const double kScrubProgressTrackHeight = 4;

/// PageView offset epsilon — matches [VerticalMediaFeedState] handoff scroll gate.
const double kVerticalFeedSettledPageEpsilon = 0.02;

/// True when the vertical feed PageView has settled on [feedIndex].
bool verticalFeedPageSettled({
  required double pageOffset,
  required int feedIndex,
}) {
  return (pageOffset - feedIndex).abs() < kVerticalFeedSettledPageEpsilon;
}

/// Whether scrubber chrome (track + timestamp + drag bubble) may paint.
///
/// All three hide triggers are OR'd — each covers a distinct moment:
/// neighbour page (`!isCurrent`), mid-swipe peek (`!verticalFeedSettled`),
/// or PV transition cover on this asset (`transitionCovering`).
bool scrubberChromeVisible({
  required bool isCurrent,
  required bool verticalFeedSettled,
  required bool transitionCovering,
}) {
  return isCurrent && verticalFeedSettled && !transitionCovering;
}

/// Avoid requesting exact `duration` (some PhotoKit assets fail at EOS).
const double kScrubPreviewEndEpsilonSeconds = 0.05;

/// Whole-second preview key when duration is unknown (round; Cap 19.2c).
double scrubPreviewFallbackSeconds(double seconds) {
  if (!seconds.isFinite || seconds <= 0) {
    return 0;
  }
  return seconds.round().toDouble();
}

/// True when drag display time has entered the last incomplete second
/// (or the exact integer duration). Cap 18.5 end-cap preview shot.
bool scrubPreviewIsEndCap({
  required double displaySeconds,
  required double durationSeconds,
}) {
  if (!displaySeconds.isFinite || !durationSeconds.isFinite) {
    return false;
  }
  if (durationSeconds <= 0) {
    return false;
  }
  return displaySeconds >= durationSeconds.floor().toDouble();
}

/// Host preview request time: mid-path aligned to [scrubberSeekSeconds]
/// (round), or `duration − ε` at end-cap / integer-duration EOS-safe.
///
/// Cap 19.2c: replaces Cap 18.5 mid-path floor buckets so the bubble key
/// matches label + release seek. Integer duration can round onto exact
/// `duration` — that path uses `duration − ε` so Host is not asked for EOS.
double scrubPreviewRequestSeconds({
  required double displaySeconds,
  required double durationSeconds,
}) {
  if (!durationSeconds.isFinite || durationSeconds <= 0) {
    return scrubPreviewFallbackSeconds(displaySeconds);
  }
  if (scrubPreviewIsEndCap(
    displaySeconds: displaySeconds,
    durationSeconds: durationSeconds,
  )) {
    final end = durationSeconds - kScrubPreviewEndEpsilonSeconds;
    return end < 0 ? 0.0 : end;
  }
  final ratio = (displaySeconds / durationSeconds).clamp(0.0, 1.0);
  final seekSec = scrubberSeekSeconds(
    ratio: ratio,
    durationSeconds: durationSeconds,
  );
  final maxSecond = durationSeconds.floor();
  // Integer duration: round can land on exact duration (EOS) — use end shot.
  if (seekSec >= maxSecond && (durationSeconds - maxSecond).abs() < 1e-9) {
    final end = durationSeconds - kScrubPreviewEndEpsilonSeconds;
    return end < 0 ? 0.0 : end;
  }
  return seekSec.toDouble();
}

/// True when [key] is a mid-path whole-second preview request (not end-cap ε).
bool scrubPreviewIsWholeSecondKey(double key) {
  if (!key.isFinite) {
    return false;
  }
  return key == key.roundToDouble();
}

/// ADR-040 Decision 13: visible, non-interactive until L2-ready ordinary video.
bool scrubberFrozen({
  required bool isCurrent,
  required bool isOrdinaryVideo,
  required bool layer2InFlight,
  required bool surfaceReady,
  required bool hardFailure,
  required bool transitionCovering,
}) {
  if (!isCurrent || !isOrdinaryVideo) {
    return true;
  }
  return layer2InFlight ||
      !surfaceReady ||
      hardFailure ||
      transitionCovering;
}

/// Track + resident timestamp paint together when L2-ready **and** duration known.
///
/// Avoids progress bar appearing before the paired `current / total` label (or
/// the reverse) during Layer 2 handoff while doom-scrolling.
bool scrubberResidentChromeVisible({
  required bool frozen,
  required double? durationSeconds,
}) {
  if (frozen) {
    return false;
  }
  return durationSeconds != null && durationSeconds > 0;
}

/// Progress fill ratio for track; null when duration unknown (indeterminate).
double? scrubberFillRatio({
  required double positionSeconds,
  required double? durationSeconds,
}) {
  if (durationSeconds == null || durationSeconds <= 0) {
    return null;
  }
  final clamped = positionSeconds.clamp(0, durationSeconds);
  return (clamped / durationSeconds).clamp(0.0, 1.0);
}

/// Cap 19.2d: live playhead ghost paints only while the finger is down.
bool scrubberLiveGhostVisible({required bool dragging}) => dragging;

/// Whether a post-scrub Host observe may replace the optimistic landing.
///
/// Stale ticks (still near the pre-seek playhead) must be ignored or the
/// progress fill flashes backward/forward until seek applies.
bool scrubberShouldAcceptRuntimeAfterSeekHold({
  required double incomingSeconds,
  required double seekHoldSeconds,
  double settleEpsilonSeconds = 0.75,
}) {
  return (incomingSeconds - seekHoldSeconds).abs() <= settleEpsilonSeconds;
}

/// Horizontal inset matching [VideoProgressScrubber] track [Padding].
const double kScrubberTrackHorizontalPadding = 12;

/// Inner track width inside the scrubber hit band.
double scrubberTrackInnerWidth(double hitWidth) {
  final inner = hitWidth - 2 * kScrubberTrackHorizontalPadding;
  return inner > 0 ? inner : 0;
}

/// Maps a scrubber-band local X to track ratio using inner track geometry.
double scrubberRatioFromLocalX({
  required double localX,
  required double hitWidth,
  double horizontalPadding = kScrubberTrackHorizontalPadding,
}) {
  final innerWidth = hitWidth - 2 * horizontalPadding;
  if (innerWidth <= 0) {
    return 0;
  }
  return ((localX - horizontalPadding) / innerWidth).clamp(0.0, 1.0);
}

/// Maps track ratio to scrubber-band local X (bubble / thumb anchor).
double scrubberLocalXFromRatio({
  required double ratio,
  required double hitWidth,
  double horizontalPadding = kScrubberTrackHorizontalPadding,
}) {
  final innerWidth = hitWidth - 2 * horizontalPadding;
  if (innerWidth <= 0) {
    return horizontalPadding;
  }
  return horizontalPadding + ratio.clamp(0.0, 1.0) * innerWidth;
}

/// Drag ratio anchored at the playhead when the gesture starts, not finger X.
///
/// [hitWidth] is the full scrubber band width; inner track subtracts
/// [horizontalPadding] on each side (must match UI [Padding]).
double scrubberDragRatio({
  required double anchorRatio,
  required double anchorLocalX,
  required double currentLocalX,
  required double hitWidth,
  double horizontalPadding = kScrubberTrackHorizontalPadding,
}) {
  final innerWidth = hitWidth - 2 * horizontalPadding;
  if (innerWidth <= 0) {
    return anchorRatio.clamp(0.0, 1.0);
  }
  final anchorInnerX = anchorLocalX - horizontalPadding;
  final currentInnerX = currentLocalX - horizontalPadding;
  final deltaRatio = (currentInnerX - anchorInnerX) / innerWidth;
  return (anchorRatio + deltaRatio).clamp(0.0, 1.0);
}

/// Whole-second scrub target: linear ratio × duration, rounded to nearest
/// second, clamped to [0, duration.floor()]. Display while dragging and seek
/// on release both use this quantizer so the label matches the landed playhead.
/// Cap 18.5 intentionally defers sub-second precision (iPhone slow-mo stores
/// 0.01s; Main Browse scrub is second-granular until a future cap upgrades it).
int scrubberSeekSeconds({
  required double ratio,
  required double durationSeconds,
}) {
  if (durationSeconds <= 0) {
    return 0;
  }
  final maxSecond = durationSeconds.floor();
  return (ratio.clamp(0.0, 1.0) * durationSeconds).round().clamp(0, maxSecond);
}

String formatScrubTimestamp(
  double seconds, {
  required double durationSeconds,
}) {
  final current = _formatMmSs(seconds);
  return '$current / ${_formatMmSs(durationSeconds)}';
}

/// Cap 19.8: whole seconds shown on the resident timestamp above the track.
///
/// Uses the live playhead ([positionSeconds]) unless a post-release seek-hold
/// freeze is active ([residentHoldSeconds]) — never the scrub-target seconds
/// shown in the preview bubble while dragging.
double scrubberResidentLabelSeconds({
  required double positionSeconds,
  double? residentHoldSeconds,
}) {
  return residentHoldSeconds ?? positionSeconds;
}

/// Timestamp above the scrubber track (idle, drag, or frozen-degraded).
///
/// Returns null until [durationSeconds] is known so the paired
/// `current / total` label appears in one paint (no `/--` placeholder).
///
/// Resident label follows [scrubberResidentLabelSeconds]; preview bubble
/// timestamp uses scrub-target seconds separately in the widget layer.
String? scrubberTimestampLabel({
  required bool frozen,
  required double positionSeconds,
  required double? durationSeconds,
  double? residentHoldSeconds,
}) {
  if (durationSeconds == null || durationSeconds <= 0) {
    return null;
  }
  if (frozen) {
    return '00:00 / ${_formatMmSs(durationSeconds)}';
  }
  final seconds = scrubberResidentLabelSeconds(
    positionSeconds: positionSeconds,
    residentHoldSeconds: residentHoldSeconds,
  );
  return formatScrubTimestamp(seconds, durationSeconds: durationSeconds);
}

String _formatMmSs(double seconds) {
  final total = seconds.isFinite && seconds > 0 ? seconds.floor() : 0;
  final minutes = total ~/ 60;
  final secs = total % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = secs.toString().padLeft(2, '0');
  return '$mm:$ss';
}

/// Whether a new preview request may start at [nowMs] given throttle state.
bool scrubPreviewShouldRequest({
  required int nowMs,
  required int lastRequestStartedMs,
  required int minRequestIntervalMs,
  required double bucketSeconds,
  required double? lastRequestedBucketSeconds,
  required bool hasOutstandingRequest,
}) {
  // Never stack Pigeon calls — wait for in-flight Host work to finish.
  if (hasOutstandingRequest) {
    return false;
  }
  if (lastRequestedBucketSeconds != bucketSeconds) {
    return true;
  }
  return nowMs - lastRequestStartedMs >= minRequestIntervalMs;
}

/// After consecutive slow outstanding windows, widen throttle (soft cap).
int scrubPreviewNextThrottleMs({
  required int currentMs,
  required int slowOutstandingStreak,
}) {
  if (slowOutstandingStreak < 2) {
    return currentMs;
  }
  final next = currentMs + 40;
  return next > kScrubPreviewMaxThrottleMs
      ? kScrubPreviewMaxThrottleMs
      : next;
}

/// Whether a prior successful JPEG may fill a mid-drag bucket gap (§2.1 borrow).
bool scrubPreviewMayBorrowFrame({
  required double currentBucketSeconds,
  required double? sourceBucketSeconds,
  required int nowMs,
  required int? sourceCapturedAtMs,
  required bool scrubDirectionReversed,
}) {
  if (scrubDirectionReversed) {
    return false;
  }
  if (sourceBucketSeconds == null || sourceCapturedAtMs == null) {
    return false;
  }
  final bucketGap = currentBucketSeconds - sourceBucketSeconds;
  final maxGap =
      kScrubPreviewBorrowMaxBucketSteps * kScrubPreviewBucketStepSeconds;
  if (bucketGap <= 0 || bucketGap > maxGap) {
    return false;
  }
  if (bucketGap != kScrubPreviewBucketStepSeconds) {
    return false;
  }
  return nowMs - sourceCapturedAtMs <= kScrubPreviewBorrowMaxWallClockMs;
}

/// Whether Host `actualSeconds` is close enough to the Dart request time.
///
/// Inclusive of exactly [maxDriftSeconds] (aligned with §2.1 max one bucket).
bool scrubPreviewActualAcceptable({
  required double requestedSeconds,
  required double actualSeconds,
  double maxDriftSeconds = kScrubPreviewBucketStepSeconds,
}) {
  if (!requestedSeconds.isFinite || !actualSeconds.isFinite) {
    return false;
  }
  if (!maxDriftSeconds.isFinite || maxDriftSeconds < 0) {
    return false;
  }
  return (requestedSeconds - actualSeconds).abs() <= maxDriftSeconds;
}

/// Bubble image bytes: current bucket JPEG, else bounded borrow from prior bucket.
///
/// [forbidBorrow] is true in the end-cap zone (in-flight or nil): borrowing the
/// prior second would re-legalize the "frames before the Douyin tail" bug.
Uint8List? scrubPreviewDisplayBytes({
  required Uint8List? currentBucketBytes,
  required Uint8List? borrowSourceBytes,
  required double currentBucketSeconds,
  required double? borrowSourceBucketSeconds,
  required int nowMs,
  required int? borrowSourceCapturedAtMs,
  required bool scrubDirectionReversed,
  bool forbidBorrow = false,
}) {
  if (currentBucketBytes != null) {
    return currentBucketBytes;
  }
  if (forbidBorrow || borrowSourceBytes == null) {
    return null;
  }
  if (!scrubPreviewMayBorrowFrame(
    currentBucketSeconds: currentBucketSeconds,
    sourceBucketSeconds: borrowSourceBucketSeconds,
    nowMs: nowMs,
    sourceCapturedAtMs: borrowSourceCapturedAtMs,
    scrubDirectionReversed: scrubDirectionReversed,
  )) {
    return null;
  }
  return borrowSourceBytes;
}
