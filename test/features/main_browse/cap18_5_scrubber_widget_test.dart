import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/scrubber_policy.dart';
import 'package:waketok/features/main_browse/video_progress_scrubber.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_playback_repository.dart';
import 'cap18_5_preview_jpeg.dart';

Widget _harness({
  required FakePlaybackRepository playback,
  required bool frozen,
  required VoidCallback onBegin,
  required void Function(double) onComplete,
  Future<ScrubPreviewFrame?> Function(double seconds)? requestPreview,
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
            frozen: frozen,
            runtimeEvents: playback.runtimeEvents,
            onScrubBegin: onBegin,
            onScrubComplete: onComplete,
            requestPreview:
                requestPreview ?? playback.requestScrubPreviewFrame,
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('W-18.5-1 frozen scrubber shows track without fill interaction',
      (tester) async {
    final playback = FakePlaybackRepository();
    var beginCount = 0;
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: true,
        onBegin: () => beginCount++,
        onComplete: (_) {},
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('mainBrowseVideoScrubber')), findsOneWidget);
    expect(find.byKey(const Key('mainBrowseScrubberTimestamp')), findsNothing);
    await tester.drag(
      find.byKey(const Key('mainBrowseVideoScrubber')),
      const Offset(80, 0),
    );
    await tester.pump();
    expect(beginCount, 0);
  });

  testWidgets('W-18.5-3 horizontal drag release seeks once', (tester) async {
    final playback = FakePlaybackRepository();
    var beginCount = 0;
    double? completed;
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: false,
        onBegin: () => beginCount++,
        onComplete: (s) => completed = s,
      ),
    );
    await tester.pump();
    playback.emitRuntimeEvent(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 0,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 100,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('mainBrowseScrubberTimestamp'))).data,
      '00:00 / 01:40',
    );
    await tester.drag(
      find.byKey(const Key('mainBrowseVideoScrubber')),
      const Offset(120, 0),
    );
    await tester.pump();
    expect(beginCount, 1);
    expect(completed, isNotNull);
  });

  testWidgets('W-18.5-8 drag anchors at playhead not touch X', (tester) async {
    final playback = FakePlaybackRepository();
    double? completed;
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: false,
        onBegin: () {},
        onComplete: (s) => completed = s,
      ),
    );
    await tester.pump();
    playback.emitRuntimeEvent(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 50,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 100,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<Text>(find.byKey(const Key('mainBrowseScrubberTimestamp'))).data,
      '00:50 / 01:40',
    );
    await tester.drag(
      find.byKey(const Key('mainBrowseVideoScrubber')),
      const Offset(80, 0),
    );
    await tester.pump();

    final hitWidth = tester.getSize(
      find.byKey(const Key('mainBrowseVideoScrubber')),
    ).width;
    final dragStartX = hitWidth / 2;
    final ratio = scrubberDragRatio(
      anchorRatio: 0.5,
      anchorLocalX: dragStartX,
      currentLocalX: dragStartX + 80,
      hitWidth: hitWidth,
    );
    final expected = scrubberSeekSeconds(
      ratio: ratio,
      durationSeconds: 100,
    );
    expect(completed, expected.toDouble());
  });

  testWidgets('W-18.5-E1 non-integer end requests duration-epsilon',
      (tester) async {
    final playback = FakePlaybackRepository();
    final requested = <double>[];
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: false,
        onBegin: () {},
        onComplete: (_) {},
        requestPreview: (seconds) async {
          requested.add(seconds);
          return ScrubPreviewFrame(
            jpegBytes: kCap185TestPreviewJpeg,
            actualSeconds: seconds,
          );
        },
      ),
    );
    await tester.pump();
    playback.emitRuntimeEvent(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 14.5,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 15.8,
      ),
    );
    await tester.pump();
    final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
    final trackWidth = tester.getSize(scrubber).width;
    final gesture = await tester.startGesture(tester.getCenter(scrubber));
    // From ~14.5/15.8 into the last incomplete second (≥ 15.0).
    await gesture.moveBy(Offset(trackWidth * 0.2, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();

    expect(
      requested.any(
        (s) => (s - (15.8 - kScrubPreviewEndEpsilonSeconds)).abs() < 1e-6,
      ),
      isTrue,
      reason: 'expected end-cap request among $requested',
    );
  });

  testWidgets('W-18.5-E2 end-cap nil shows placeholder without borrow Image',
      (tester) async {
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: false,
        onBegin: () {},
        onComplete: (_) {},
        requestPreview: (seconds) async {
          if (seconds >= 15) {
            return null;
          }
          return ScrubPreviewFrame(
            jpegBytes: kCap185TestPreviewJpeg,
            actualSeconds: seconds,
          );
        },
      ),
    );
    await tester.pump();
    playback.emitRuntimeEvent(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 14,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 15.8,
      ),
    );
    await tester.pump();
    final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
    final trackWidth = tester.getSize(scrubber).width;
    final gesture = await tester.startGesture(
      tester.getCenter(scrubber) - Offset(trackWidth * 0.02, 0),
    );
    await gesture.moveBy(const Offset(6, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsOneWidget);

    await gesture.moveBy(Offset(trackWidth * 0.5, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(ColoredBox), findsWidgets);
    await gesture.up();
  });

  testWidgets(
      'W-18.5-E3 integer duration mid last second requests EOS-safe ε (19.2c)',
      (tester) async {
    final playback = FakePlaybackRepository();
    final requested = <double>[];
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: false,
        onBegin: () {},
        onComplete: (_) {},
        requestPreview: (seconds) async {
          requested.add(seconds);
          return ScrubPreviewFrame(
            jpegBytes: kCap185TestPreviewJpeg,
            actualSeconds: seconds,
          );
        },
      ),
    );
    await tester.pump();
    playback.emitRuntimeEvent(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 15.5,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 16.0,
      ),
    );
    await tester.pump();
    final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
    final trackWidth = tester.getSize(scrubber).width;
    final gesture = await tester.startGesture(tester.getCenter(scrubber));
    await gesture.moveBy(Offset(trackWidth * 0.02, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(requested, isNotEmpty);
    // Cap 19.2c: round(15.5)=16 on integer duration → duration − ε, not 15.0.
    expect(
      requested.every((s) => (s - 15.95).abs() < 1e-6),
      isTrue,
      reason: 'expected EOS-safe end shot among $requested',
    );
    await gesture.up();
  });

  testWidgets('W-18.5-A1 oversized actual drift shows placeholder not Image',
      (tester) async {
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: false,
        onBegin: () {},
        onComplete: (_) {},
        requestPreview: (seconds) async => ScrubPreviewFrame(
          jpegBytes: kCap185TestPreviewJpeg,
          actualSeconds: seconds - 1.5,
        ),
      ),
    );
    await tester.pump();
    playback.emitRuntimeEvent(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 10,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 100,
      ),
    );
    await tester.pump();
    final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
    final gesture = await tester.startGesture(tester.getCenter(scrubber));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(ColoredBox), findsWidgets);
    await gesture.up();
  });

  testWidgets('W-18.5-A2 actual within 1s shows Image', (tester) async {
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: false,
        onBegin: () {},
        onComplete: (_) {},
        requestPreview: (seconds) async => ScrubPreviewFrame(
          jpegBytes: kCap185TestPreviewJpeg,
          actualSeconds: seconds - 0.5,
        ),
      ),
    );
    await tester.pump();
    playback.emitRuntimeEvent(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 10,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 100,
      ),
    );
    await tester.pump();
    final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
    final gesture = await tester.startGesture(tester.getCenter(scrubber));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsOneWidget);
    await gesture.up();
  });

  testWidgets('W-18.5-A3 drift-reject JPEG is not a borrow source',
      (tester) async {
    final playback = FakePlaybackRepository();
    var call = 0;
    await tester.pumpWidget(
      _harness(
        playback: playback,
        frozen: false,
        onBegin: () {},
        onComplete: (_) {},
        requestPreview: (seconds) async {
          call++;
          if (call == 1) {
            // First: large drift — rejected, must not become lastSuccessful.
            return ScrubPreviewFrame(
              jpegBytes: kCap185TestPreviewJpeg,
              actualSeconds: seconds - 2.0,
            );
          }
          // Second: Host nil — ordinary failure; must NOT borrow rejected JPEG.
          return null;
        },
      ),
    );
    await tester.pump();
    playback.emitRuntimeEvent(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 10,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 100,
      ),
    );
    await tester.pump();
    final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
    final trackWidth = tester.getSize(scrubber).width;
    final gesture = await tester.startGesture(tester.getCenter(scrubber));
    await gesture.moveBy(const Offset(8, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsNothing);

    await gesture.moveBy(Offset(trackWidth * 0.02, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(Image), findsNothing);
    await gesture.up();
  });
}
