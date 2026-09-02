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

String? _residentTimestamp(WidgetTester tester) {
  final finder = find.byKey(const Key('mainBrowseScrubberTimestamp'));
  if (finder.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<Text>(finder).data;
}

void main() {
  testWidgets(
    'T-19.8-A2 drag resident follows live playhead; bubble follows scrub target',
    (tester) async {
      final runtime = StreamController<PlaybackRuntimeEvent>();
      addTearDown(runtime.close);

      await tester.pumpWidget(
        _harness(
          runtimeEvents: runtime.stream,
          onComplete: (_) {},
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
      await gesture.moveBy(Offset(-trackWidth * 0.25, 0));
      await tester.pump();

      expect(_residentTimestamp(tester), '00:40 / 01:40');

      final hitWidth = trackWidth;
      final dragStartX = hitWidth / 2;
      final ratio = scrubberDragRatio(
        anchorRatio: 0.40,
        anchorLocalX: dragStartX,
        currentLocalX: dragStartX - trackWidth * 0.25,
        hitWidth: hitWidth,
      );
      final scrubTarget = scrubberSeekSeconds(
        ratio: ratio,
        durationSeconds: 100,
      );
      expect(scrubTarget, isNot(40));

      final scrubTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(const Key('mainBrowseVideoScrubber')),
              matching: find.byType(Text),
            ),
          )
          .map((w) => w.data)
          .whereType<String>()
          .toList();
      expect(scrubTexts, hasLength(2));
      expect(scrubTexts, contains('00:40 / 01:40'));
      final bubbleLabel =
          scrubTexts.firstWhere((label) => label != '00:40 / 01:40');
      expect(
        bubbleLabel,
        formatScrubTimestamp(scrubTarget.toDouble(), durationSeconds: 100),
      );

      await gesture.up();
    },
  );

  testWidgets(
    'T-19.8-A3 seek-hold keeps resident frozen at pre-release live second',
    (tester) async {
      final runtime = StreamController<PlaybackRuntimeEvent>();
      addTearDown(runtime.close);
      double? completed;

      await tester.pumpWidget(
        _harness(
          runtimeEvents: runtime.stream,
          onComplete: (s) => completed = s,
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
      final targetSecond = completed!.floor();
      expect(targetSecond, greaterThan(10));

      // Optimistic fill lands at target; resident must stay at pre-release live.
      expect(_residentTimestamp(tester), '00:10 / 01:40');
      expect(_residentTimestamp(tester), isNot(formatScrubTimestamp(
        completed!,
        durationSeconds: 100,
      )));

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
      expect(_residentTimestamp(tester), '00:10 / 01:40');

      final primary = tester.widget<FractionallySizedBox>(
        find.byKey(const Key('mainBrowseScrubberPrimaryFill')),
      );
      expect(primary.widthFactor, closeTo(completed! / 100.0, 0.03));

      runtime.add(
        PlaybackRuntimeEvent(
          planId: 'p',
          currentItemIdentifier: 'v1',
          currentIndex: 0,
          playbackPositionSeconds: completed!,
          playbackState: PlaybackRuntimeState.playing,
          durationSeconds: 100,
        ),
      );
      await tester.pump();
      expect(
        _residentTimestamp(tester),
        formatScrubTimestamp(completed!, durationSeconds: 100),
      );
    },
  );
}
