import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/scrubber_policy.dart';
import 'package:waketok/features/main_browse/video_progress_scrubber.dart';
import 'package:waketok/l10n/app_localizations.dart';

import 'cap18_5_preview_jpeg.dart';

Widget _harness({
  required Stream<PlaybackRuntimeEvent> runtimeEvents,
  required void Function(double) onComplete,
}) {
  return MaterialApp(
    theme: waketokTheme(Brightness.dark),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Stack(
        children: [
          VideoProgressScrubber(
            assetIdentifier: 'v1',
            frozen: false,
            runtimeEvents: runtimeEvents,
            onScrubBegin: () {},
            onScrubComplete: onComplete,
            requestPreview: (seconds) async => ScrubPreviewFrame(
              jpegBytes: kCap185TestPreviewJpeg,
              actualSeconds: seconds,
            ),
          ),
        ],
      ),
    ),
  );
}

Offset _deltaForSeekChange({
  required double seekDeltaSeconds,
  required double durationSeconds,
  required double hitWidth,
}) {
  final inner = scrubberTrackInnerWidth(hitWidth);
  final deltaRatio = seekDeltaSeconds / durationSeconds;
  return Offset(deltaRatio * inner, 0);
}

Future<void> _seedRuntime(
  WidgetTester tester,
  StreamController<PlaybackRuntimeEvent> runtime, {
  required double positionSeconds,
  required double durationSeconds,
}) async {
  runtime.add(
    PlaybackRuntimeEvent(
      planId: 'p',
      currentItemIdentifier: 'v1',
      currentIndex: 0,
      playbackPositionSeconds: positionSeconds,
      playbackState: PlaybackRuntimeState.paused,
      durationSeconds: durationSeconds,
    ),
  );
  await tester.pump();
}

void main() {
  test('T-19.8-B-J0 scrubberReleaseCommitSeconds prefers painted', () {
    expect(
      scrubberReleaseCommitSeconds(
        paintedBubbleSeekSec: 2996,
        liveRatioSeekSec: 2956,
      ),
      2996,
    );
    expect(
      scrubberReleaseCommitSeconds(
        paintedBubbleSeekSec: null,
        liveRatioSeekSec: 2956,
      ),
      2956,
    );
  });

  testWidgets(
    'T-19.8-B-J1 unpainted lift-jitter commits painted second not live ratio',
    (tester) async {
      final runtime = StreamController<PlaybackRuntimeEvent>();
      addTearDown(runtime.close);
      double? completed;
      const duration = 9087.0;
      const paintedSec = 2996.0;
      const jitterSec = 2956.0;

      await tester.pumpWidget(
        _harness(
          runtimeEvents: runtime.stream,
          onComplete: (s) => completed = s,
        ),
      );
      await tester.pump();
      await _seedRuntime(
        tester,
        runtime,
        positionSeconds: paintedSec,
        durationSeconds: duration,
      );

      final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
      final hitWidth = tester.getSize(scrubber).width;
      final gesture = await tester.startGesture(tester.getCenter(scrubber));
      await tester.pump(); // paint drag start label
      await tester.pump(); // post-frame → painted = paintedSec

      // Lift-jitter: update ratio without pumping a frame, then end.
      await gesture.moveBy(
        _deltaForSeekChange(
          seekDeltaSeconds: jitterSec - paintedSec,
          durationSeconds: duration,
          hitWidth: hitWidth,
        ),
      );
      await gesture.up();
      await tester.pump();

      expect(completed, paintedSec);
      expect(completed, isNot(jitterSec));
    },
  );

  testWidgets(
    'T-19.8-B-J2 painted after pump commits the new second',
    (tester) async {
      final runtime = StreamController<PlaybackRuntimeEvent>();
      addTearDown(runtime.close);
      double? completed;
      const duration = 9087.0;
      const firstSec = 2996.0;
      const nextSec = 2956.0;

      await tester.pumpWidget(
        _harness(
          runtimeEvents: runtime.stream,
          onComplete: (s) => completed = s,
        ),
      );
      await tester.pump();
      await _seedRuntime(
        tester,
        runtime,
        positionSeconds: firstSec,
        durationSeconds: duration,
      );

      final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
      final hitWidth = tester.getSize(scrubber).width;
      final gesture = await tester.startGesture(tester.getCenter(scrubber));
      await tester.pump();
      await tester.pump();

      await gesture.moveBy(
        _deltaForSeekChange(
          seekDeltaSeconds: nextSec - firstSec,
          durationSeconds: duration,
          hitWidth: hitWidth,
        ),
      );
      await tester.pump(); // rebuild
      await tester.pump(); // post-frame paints nextSec
      await gesture.up();
      await tester.pump();

      expect(completed, nextSec);
    },
  );

  testWidgets(
    'T-19.8-B-J3 zero lift delta commits the stable painted second',
    (tester) async {
      final runtime = StreamController<PlaybackRuntimeEvent>();
      addTearDown(runtime.close);
      double? completed;
      const duration = 9087.0;
      const targetSec = 4967.0;

      await tester.pumpWidget(
        _harness(
          runtimeEvents: runtime.stream,
          onComplete: (s) => completed = s,
        ),
      );
      await tester.pump();
      await _seedRuntime(
        tester,
        runtime,
        positionSeconds: targetSec,
        durationSeconds: duration,
      );

      final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
      final gesture = await tester.startGesture(tester.getCenter(scrubber));
      await tester.pump();
      await tester.pump();
      // Commit the drag with a sub-second pixel nudge (same whole second).
      await gesture.moveBy(const Offset(0.01, 0));
      await tester.pump();
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(completed, targetSec);
    },
  );

  testWidgets(
    'T-19.8-B-J4 short clip unpainted jitter still uses painted commit',
    (tester) async {
      final runtime = StreamController<PlaybackRuntimeEvent>();
      addTearDown(runtime.close);
      double? completed;
      const duration = 120.0;
      const paintedSec = 40.0;

      await tester.pumpWidget(
        _harness(
          runtimeEvents: runtime.stream,
          onComplete: (s) => completed = s,
        ),
      );
      await tester.pump();
      await _seedRuntime(
        tester,
        runtime,
        positionSeconds: paintedSec,
        durationSeconds: duration,
      );

      final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
      final hitWidth = tester.getSize(scrubber).width;
      final gesture = await tester.startGesture(tester.getCenter(scrubber));
      await tester.pump();
      await tester.pump();

      await gesture.moveBy(
        _deltaForSeekChange(
          seekDeltaSeconds: -1,
          durationSeconds: duration,
          hitWidth: hitWidth,
        ),
      );
      await gesture.up();
      await tester.pump();

      expect(completed, paintedSec);
    },
  );
}
