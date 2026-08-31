import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/scrubber_policy.dart';
import 'package:waketok/features/main_browse/video_progress_scrubber.dart';
import 'package:waketok/l10n/app_localizations.dart';
import 'package:waketok/platform/playback_gateway.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;

import '../../library_smoke/fake_playback_repository.dart';

import 'cap18_5_preview_jpeg.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cap 18.5 preview pipeline diagnostics', () {
    test('P-18.5-1 policy: in-flight blocks duplicate even on bucket change',
        () {
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
    });

    test('P-18.5-1b policy: new bucket without in-flight starts immediately',
        () {
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

    test('P-18.5-2 Host nil: gateway surfaces null bytes from channel', () async {
      const codec = pigeon.PlaybackApi.pigeonChannelCodec;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.waketok.PlaybackApi.requestScrubPreviewFrame',
          codec,
        ),
        (message) async => <Object?>[null],
      );

      final gateway = PlaybackGateway();
      addTearDown(gateway.dispose);

      expect(await gateway.requestScrubPreviewFrame(4.5), isNull);
    });

    test('P-18.5-3 Host ok: gateway maps JPEG + actual from channel', () async {
      const codec = pigeon.PlaybackApi.pigeonChannelCodec;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.waketok.PlaybackApi.requestScrubPreviewFrame',
          codec,
        ),
        (message) async => <Object?>[
              pigeon.ScrubPreviewFrameDto(
                jpegBytes: kCap185TestPreviewJpeg,
                actualSeconds: 4.5,
              ),
            ],
      );

      final gateway = PlaybackGateway();
      addTearDown(gateway.dispose);

      final frame = await gateway.requestScrubPreviewFrame(4.5);
      expect(frame, isNotNull);
      expect(frame!.jpegBytes, kCap185TestPreviewJpeg);
      expect(frame.actualSeconds, closeTo(4.5, 0.001));
    });

    testWidgets('P-18.5-4 UI: JPEG bytes render bubble without placeholder text',
        (tester) async {
      final playback = FakePlaybackRepository()
        ..scrubPreviewBytes = kCap185TestPreviewJpeg;
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
                  runtimeEvents: playback.runtimeEvents,
                  onScrubBegin: () {},
                  onScrubComplete: (_) {},
                  requestPreview: playback.requestScrubPreviewFrame,
                ),
              ],
            ),
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
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('mainBrowseVideoScrubber'))) -
            const Offset(100, 0),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(Image), findsOneWidget);
      await gesture.up();
    });

    testWidgets('P-18.5-5 UI: null bytes keep solid placeholder without Image',
        (tester) async {
      final playback = FakePlaybackRepository();
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
                  runtimeEvents: playback.runtimeEvents,
                  onScrubBegin: () {},
                  onScrubComplete: (_) {},
                  requestPreview: playback.requestScrubPreviewFrame,
                ),
              ],
            ),
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
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('mainBrowseVideoScrubber'))) -
            const Offset(100, 0),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(Image), findsNothing);
      expect(find.byType(ColoredBox), findsWidgets);
      await gesture.up();
    });

    test('P-18.5-B9 policy: mismatch gap borrows prior bucket JPEG', () {
      expect(
        scrubPreviewDisplayBytes(
          currentBucketBytes: null,
          borrowSourceBytes: kCap185TestPreviewJpeg,
          currentBucketSeconds: 12,
          borrowSourceBucketSeconds: 11,
          nowMs: 1100,
          borrowSourceCapturedAtMs: 1000,
          scrubDirectionReversed: false,
        ),
        kCap185TestPreviewJpeg,
      );
    });

    testWidgets('W-18.5-B7 borrow window keeps prior frame Image',
        (tester) async {
      final playback = FakePlaybackRepository()
        ..scrubPreviewBytes = kCap185TestPreviewJpeg;
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
                  runtimeEvents: playback.runtimeEvents,
                  onScrubBegin: () {},
                  onScrubComplete: (_) {},
                  requestPreview: playback.requestScrubPreviewFrame,
                ),
              ],
            ),
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
      final trackWidth = tester.getSize(scrubber).width;
      final gesture = await tester.startGesture(
        tester.getCenter(scrubber) - Offset(trackWidth * 0.05, 0),
      );
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(Image), findsOneWidget);

      await gesture.moveBy(Offset(trackWidth * 0.012, 0));
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      await gesture.up();
    });

    testWidgets('W-18.5-B8 beyond borrow window keeps solid placeholder without Image',
        (tester) async {
      final playback = FakePlaybackRepository()
        ..scrubPreviewBytes = kCap185TestPreviewJpeg;
      Future<ScrubPreviewFrame?> requestPreview(double bucketSeconds) async {
        if (bucketSeconds >= 13) {
          return null;
        }
        return ScrubPreviewFrame(
          jpegBytes: kCap185TestPreviewJpeg,
          actualSeconds: bucketSeconds,
        );
      }

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
                  runtimeEvents: playback.runtimeEvents,
                  onScrubBegin: () {},
                  onScrubComplete: (_) {},
                  requestPreview: requestPreview,
                ),
              ],
            ),
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
      final trackWidth = tester.getSize(scrubber).width;
      final gesture = await tester.startGesture(
        tester.getCenter(scrubber) - Offset(trackWidth * 0.05, 0),
      );
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(Image), findsOneWidget);

      await gesture.moveBy(Offset(trackWidth * 0.025, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(Image), findsNothing);
      expect(find.byType(ColoredBox), findsWidgets);
      await gesture.up();
    });
  });
}
