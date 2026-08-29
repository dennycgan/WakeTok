import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/video_progress_scrubber.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_playback_repository.dart';

Widget _harness({
  required FakePlaybackRepository playback,
  required bool frozen,
  required VoidCallback onBegin,
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
            frozen: frozen,
            runtimeEvents: playback.runtimeEvents,
            onScrubBegin: onBegin,
            onScrubComplete: onComplete,
            requestPreview: playback.requestScrubPreviewFrame,
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

    await tester.drag(
      find.byKey(const Key('mainBrowseVideoScrubber')),
      const Offset(80, 0),
    );
    await tester.pump();

    final trackWidth = tester.getSize(
      find.byKey(const Key('mainBrowseVideoScrubber')),
    ).width;
    final expected = 50 + (80 / trackWidth) * 100;
    expect(completed, closeTo(expected, 0.5));
  });
}
