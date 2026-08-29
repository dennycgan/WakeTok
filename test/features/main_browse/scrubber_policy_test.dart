import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/scrubber_policy.dart';

void main() {
  test('U-18.5-1 scrubberFrozen when L2 not ready', () {
    expect(
      scrubberFrozen(
        isCurrent: true,
        isOrdinaryVideo: true,
        layer2InFlight: true,
        surfaceReady: false,
        hardFailure: false,
        transitionCovering: false,
      ),
      isTrue,
    );
    expect(
      scrubberFrozen(
        isCurrent: true,
        isOrdinaryVideo: true,
        layer2InFlight: false,
        surfaceReady: true,
        hardFailure: false,
        transitionCovering: false,
      ),
      isFalse,
    );
  });

  test('U-18.5-2 scrubberFillRatio', () {
    expect(
      scrubberFillRatio(positionSeconds: 30, durationSeconds: 120),
      closeTo(0.25, 0.001),
    );
    expect(
      scrubberFillRatio(positionSeconds: 10, durationSeconds: null),
      isNull,
    );
  });

  test('U-18.5-3 scrub preview bucket quantize', () {
    expect(scrubPreviewBucketSeconds(12.3), 12.0);
    expect(scrubPreviewBucketSeconds(12.7), 12.0);
    expect(scrubPreviewBucketSeconds(0.2), 0);
  });

  test('U-18.5-4 scrubberDragRatio anchors at playhead', () {
    expect(
      scrubberDragRatio(
        anchorRatio: 0.5,
        anchorLocalX: 40,
        currentLocalX: 120,
        trackWidth: 400,
      ),
      closeTo(0.7, 0.001),
    );
  });

  test('U-18.5-5 in-flight blocks new request even on bucket change', () {
    expect(
      scrubPreviewShouldRequest(
        nowMs: 1000,
        lastRequestStartedMs: 900,
        minRequestIntervalMs: 120,
        bucketSeconds: 12,
        lastRequestedBucketSeconds: 10,
        hasOutstandingRequest: true,
      ),
      isFalse,
    );
    expect(
      scrubPreviewShouldRequest(
        nowMs: 901,
        lastRequestStartedMs: 900,
        minRequestIntervalMs: 120,
        bucketSeconds: 12,
        lastRequestedBucketSeconds: 10,
        hasOutstandingRequest: false,
      ),
      isTrue,
    );
  });

  group('U-18.5-B borrow window', () {
    final sourceBytes = Uint8List.fromList(<int>[1, 2, 3]);
    const capturedAtMs = 1000;

    test('U-18.5-B1 within one bucket shows borrowed frame', () {
      expect(
        scrubPreviewMayBorrowFrame(
          currentBucketSeconds: 12,
          sourceBucketSeconds: 11,
          nowMs: capturedAtMs + 100,
          sourceCapturedAtMs: capturedAtMs,
          scrubDirectionReversed: false,
        ),
        isTrue,
      );
      expect(
        scrubPreviewDisplayBytes(
          currentBucketBytes: null,
          borrowSourceBytes: sourceBytes,
          currentBucketSeconds: 12,
          borrowSourceBucketSeconds: 11,
          nowMs: capturedAtMs + 100,
          borrowSourceCapturedAtMs: capturedAtMs,
          scrubDirectionReversed: false,
        ),
        sourceBytes,
      );
    });

    test('U-18.5-B2 beyond one bucket step rejects borrow', () {
      expect(
        scrubPreviewMayBorrowFrame(
          currentBucketSeconds: 12,
          sourceBucketSeconds: 10,
          nowMs: capturedAtMs + 100,
          sourceCapturedAtMs: capturedAtMs,
          scrubDirectionReversed: false,
        ),
        isFalse,
      );
    });

    test('U-18.5-B3 no prior JPEG rejects borrow', () {
      expect(
        scrubPreviewDisplayBytes(
          currentBucketBytes: null,
          borrowSourceBytes: null,
          currentBucketSeconds: 12,
          borrowSourceBucketSeconds: null,
          nowMs: capturedAtMs + 100,
          borrowSourceCapturedAtMs: null,
          scrubDirectionReversed: false,
        ),
        isNull,
      );
    });

    test('U-18.5-B4 failed Host response is not a borrow source', () {
      expect(
        scrubPreviewDisplayBytes(
          currentBucketBytes: null,
          borrowSourceBytes: null,
          currentBucketSeconds: 12,
          borrowSourceBucketSeconds: 11,
          nowMs: capturedAtMs + 100,
          borrowSourceCapturedAtMs: capturedAtMs,
          scrubDirectionReversed: false,
        ),
        isNull,
      );
    });

    test('U-18.5-B5 wall-clock window exceeded rejects borrow', () {
      expect(
        scrubPreviewMayBorrowFrame(
          currentBucketSeconds: 12,
          sourceBucketSeconds: 11,
          nowMs: capturedAtMs + kScrubPreviewBorrowMaxWallClockMs + 1,
          sourceCapturedAtMs: capturedAtMs,
          scrubDirectionReversed: false,
        ),
        isFalse,
      );
    });

    test('U-18.5-B6 scrub direction reversal rejects borrow', () {
      expect(
        scrubPreviewMayBorrowFrame(
          currentBucketSeconds: 12,
          sourceBucketSeconds: 11,
          nowMs: capturedAtMs + 100,
          sourceCapturedAtMs: capturedAtMs,
          scrubDirectionReversed: true,
        ),
        isFalse,
      );
    });
  });
}
