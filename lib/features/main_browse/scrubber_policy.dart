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

/// Quantize [seconds] into preview buckets.
double scrubPreviewBucketSeconds(double seconds) {
  if (!seconds.isFinite || seconds <= 0) {
    return 0;
  }
  final bucket = (seconds / kScrubPreviewBucketStepSeconds).floor();
  return bucket * kScrubPreviewBucketStepSeconds;
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

/// Drag ratio anchored at the playhead when the gesture starts, not finger X.
double scrubberDragRatio({
  required double anchorRatio,
  required double anchorLocalX,
  required double currentLocalX,
  required double trackWidth,
}) {
  if (trackWidth <= 0) {
    return anchorRatio.clamp(0.0, 1.0);
  }
  final deltaRatio = (currentLocalX - anchorLocalX) / trackWidth;
  return (anchorRatio + deltaRatio).clamp(0.0, 1.0);
}

String formatScrubTimestamp(
  double seconds, {
  double? durationSeconds,
}) {
  final current = _formatMmSs(seconds);
  if (durationSeconds != null && durationSeconds > 0) {
    return '$current / ${_formatMmSs(durationSeconds)}';
  }
  return current;
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

/// Bubble image bytes: current bucket JPEG, else bounded borrow from prior bucket.
Uint8List? scrubPreviewDisplayBytes({
  required Uint8List? currentBucketBytes,
  required Uint8List? borrowSourceBytes,
  required double currentBucketSeconds,
  required double? borrowSourceBucketSeconds,
  required int nowMs,
  required int? borrowSourceCapturedAtMs,
  required bool scrubDirectionReversed,
}) {
  if (currentBucketBytes != null) {
    return currentBucketBytes;
  }
  if (borrowSourceBytes == null) {
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
