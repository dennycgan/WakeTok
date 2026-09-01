import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/video_progress_scrubber.dart';
import 'package:waketok/l10n/app_localizations.dart';

import 'cap18_5_preview_jpeg.dart';

void main() {
  testWidgets(
      'W-19.2d-1 drag primary follows finger; ghost follows live playhead',
      (tester) async {
    final runtime = StreamController<PlaybackRuntimeEvent>.broadcast();
    addTearDown(runtime.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: waketokTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              VideoProgressScrubber(
                assetIdentifier: 'v1',
                frozen: false,
                runtimeEvents: runtime.stream,
                onScrubBegin: () {},
                onScrubComplete: (_) {},
                requestPreview: (seconds) async => ScrubPreviewFrame(
                  jpegBytes: kCap185TestPreviewJpeg,
                  actualSeconds: seconds,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    runtime.add(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 40,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 100,
      ),
    );
    await tester.pump();

    final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
    final trackWidth = tester.getSize(scrubber).width;
    final gesture = await tester.startGesture(tester.getCenter(scrubber));
    // Drag backward so primary fill is behind the live ghost.
    await gesture.moveBy(Offset(-trackWidth * 0.25, 0));
    await tester.pump();

    expect(find.byKey(const Key('mainBrowseScrubberLiveGhost')), findsOneWidget);
    final ghost = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('mainBrowseScrubberLiveGhost')),
    );
    final primary = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('mainBrowseScrubberPrimaryFill')),
    );
    expect(ghost.widthFactor, closeTo(0.40, 0.03));
    expect(primary.widthFactor!, lessThan(ghost.widthFactor! - 0.05));

    // Live catch-up while dragging is covered by W-19.2d-3 (emit mid-drag,
    // then cancel — fill follows the latest live ratio).
    await gesture.up();
  });

  testWidgets(
      'W-19.2d-2 seek release paints optimistic fill (no flash to old playhead)',
      (tester) async {
    final runtime = StreamController<PlaybackRuntimeEvent>.broadcast();
    addTearDown(runtime.close);
    double? completed;

    await tester.pumpWidget(
      MaterialApp(
        theme: waketokTheme(Brightness.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Stack(
            children: [
              VideoProgressScrubber(
                assetIdentifier: 'v1',
                frozen: false,
                runtimeEvents: runtime.stream,
                onScrubBegin: () {},
                onScrubComplete: (s) => completed = s,
                requestPreview: (seconds) async => ScrubPreviewFrame(
                  jpegBytes: kCap185TestPreviewJpeg,
                  actualSeconds: seconds,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    runtime.add(
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
    await gesture.moveBy(Offset(trackWidth * 0.4, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(completed, isNotNull);
    // Stale observe still at the pre-drag playhead must not flash the bar.
    runtime.add(
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

    final primary = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('mainBrowseScrubberPrimaryFill')),
    );
    final expectedRatio = completed! / 100.0;
    expect(primary.widthFactor, closeTo(expectedRatio, 0.03));
    expect(primary.widthFactor, isNot(closeTo(0.10, 0.03)));
    expect(find.byKey(const Key('mainBrowseScrubberLiveGhost')), findsNothing);
  });

  testWidgets(
      'W-19.2d-3 cancel via freeze does not seek; fill follows live',
      (tester) async {
    final runtime = StreamController<PlaybackRuntimeEvent>.broadcast();
    addTearDown(runtime.close);
    var completed = false;
    var frozen = false;

    Widget build() {
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
                runtimeEvents: runtime.stream,
                onScrubBegin: () {},
                onScrubComplete: (_) => completed = true,
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

    await tester.pumpWidget(build());
    await tester.pump();
    runtime.add(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 20,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 100,
      ),
    );
    await tester.pump();

    final scrubber = find.byKey(const Key('mainBrowseVideoScrubber'));
    final trackWidth = tester.getSize(scrubber).width;
    final gesture = await tester.startGesture(tester.getCenter(scrubber));
    await gesture.moveBy(Offset(trackWidth * 0.3, 0));
    await tester.pump();
    runtime.add(
      const PlaybackRuntimeEvent(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 28,
        playbackState: PlaybackRuntimeState.playing,
        durationSeconds: 100,
      ),
    );
    await tester.pump();

    // Product cancel path (same as didUpdateWidget freeze): no seek write.
    frozen = true;
    await tester.pumpWidget(build());
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(completed, isFalse);
    expect(find.byKey(const Key('mainBrowseScrubberLiveGhost')), findsNothing);
    final primary = tester.widget<FractionallySizedBox>(
      find.byKey(const Key('mainBrowseScrubberPrimaryFill')),
    );
    expect(primary.widthFactor, closeTo(0.28, 0.05));
  });
}
