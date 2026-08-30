import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/media_info_overlay.dart';
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

  test('U-18.5-4 scrubberDragRatio anchors at playhead on inner track', () {
    expect(
      scrubberDragRatio(
        anchorRatio: 0.5,
        anchorLocalX: 40,
        currentLocalX: 120,
        hitWidth: 400,
      ),
      closeTo(0.712766, 0.001),
    );
  });

  test('U-18.5-4b scrubber inner track maps padded local X', () {
    expect(
      scrubberRatioFromLocalX(localX: 12, hitWidth: 400),
      closeTo(0, 0.001),
    );
    expect(
      scrubberRatioFromLocalX(localX: 388, hitWidth: 400),
      closeTo(1, 0.001),
    );
    expect(
      scrubberLocalXFromRatio(ratio: 0.5, hitWidth: 400),
      closeTo(200, 0.001),
    );
  });

  test('U-18.5-4c scrubberSeekSeconds rounds to match drag label and seek', () {
    expect(
      scrubberSeekSeconds(ratio: 3.71 / 18, durationSeconds: 18),
      4,
    );
    expect(
      scrubberSeekSeconds(ratio: 3.41 / 18, durationSeconds: 18),
      3,
    );
    expect(
      scrubberSeekSeconds(ratio: 0.41, durationSeconds: 12),
      5,
    );
    expect(
      scrubberSeekSeconds(ratio: 0.99, durationSeconds: 12),
      12,
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

  group('U-18.5-C scrubberChromeVisible', () {
    test('U-18.5-C1 all clear shows chrome', () {
      expect(
        scrubberChromeVisible(
          isCurrent: true,
          verticalFeedSettled: true,
          transitionCovering: false,
        ),
        isTrue,
      );
    });

    test('U-18.5-C2 !isCurrent hides chrome', () {
      expect(
        scrubberChromeVisible(
          isCurrent: false,
          verticalFeedSettled: true,
          transitionCovering: false,
        ),
        isFalse,
      );
    });

    test('U-18.5-C3 mid-swipe peek hides chrome on current page', () {
      expect(
        scrubberChromeVisible(
          isCurrent: true,
          verticalFeedSettled: false,
          transitionCovering: false,
        ),
        isFalse,
      );
    });

    test('U-18.5-C4 transition cover hides chrome', () {
      expect(
        scrubberChromeVisible(
          isCurrent: true,
          verticalFeedSettled: true,
          transitionCovering: true,
        ),
        isFalse,
      );
    });

    test('U-18.5-C5 combined triggers hide chrome', () {
      expect(
        scrubberChromeVisible(
          isCurrent: false,
          verticalFeedSettled: false,
          transitionCovering: true,
        ),
        isFalse,
      );
    });
  });

  group('U-18.5-D verticalFeedPageSettled', () {
    test('U-18.5-D1 within epsilon is settled', () {
      expect(
        verticalFeedPageSettled(pageOffset: 2.01, feedIndex: 2),
        isTrue,
      );
    });

    test('U-18.5-D2 beyond epsilon is peek', () {
      expect(
        verticalFeedPageSettled(pageOffset: 2.05, feedIndex: 2),
        isFalse,
      );
    });
  });

  group('U-18.5-E scrubberTimestampLabel', () {
    test('U-18.5-E1 frozen without duration hides label', () {
      expect(
        scrubberTimestampLabel(
          frozen: true,
          positionSeconds: 12,
          durationSeconds: null,
          displaySeconds: 12,
          dragging: false,
        ),
        isNull,
      );
    });

    test('U-18.5-E2 frozen with duration shows 00:00 / total', () {
      expect(
        scrubberTimestampLabel(
          frozen: true,
          positionSeconds: 12,
          durationSeconds: 120,
          displaySeconds: 12,
          dragging: false,
        ),
        '00:00 / 02:00',
      );
    });

    test('U-18.5-E3 idle unfrozen follows runtime position', () {
      expect(
        scrubberTimestampLabel(
          frozen: false,
          positionSeconds: 30,
          durationSeconds: 120,
          displaySeconds: 30,
          dragging: false,
        ),
        '00:30 / 02:00',
      );
    });

    test('U-18.5-E4 idle before duration hides label', () {
      expect(
        scrubberTimestampLabel(
          frozen: false,
          positionSeconds: 0,
          durationSeconds: null,
          displaySeconds: 0,
          dragging: false,
        ),
        isNull,
      );
    });
  });

  group('U-18.5-G scrubberResidentChromeVisible', () {
    test('U-18.5-G1 hidden while frozen even with duration', () {
      expect(
        scrubberResidentChromeVisible(frozen: true, durationSeconds: 120),
        isFalse,
      );
    });

    test('U-18.5-G2 hidden until duration known', () {
      expect(
        scrubberResidentChromeVisible(frozen: false, durationSeconds: null),
        isFalse,
      );
    });

    test('U-18.5-G3 visible when L2-ready and duration known', () {
      expect(
        scrubberResidentChromeVisible(frozen: false, durationSeconds: 18),
        isTrue,
      );
    });
  });

  group('U-18.5-F overlay vs scrubber timestamp geometry', () {
    test('U-18.5-F1 row 3 center matches timestamp center', () {
      final tokens = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
      final timestampCenter = mainBrowseScrubberTimestampCenterFromFeedBottom(
        tokens,
      );
      final row3Center =
          mainBrowseMediaOverlayBottomInset(tokens) +
          MediaInfoOverlay.rowHeight / 2;
      expect(row3Center, closeTo(timestampCenter, 0.001));
    });

    test('U-18.5-F2 overlay rows use uniform slot height', () {
      // Rows 1–3 are stacked 20px slots; row 3 special case is inset only.
      expect(MediaInfoOverlay.rowHeight, 20);
    });
  });
}
