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

/// Minimal valid 1×1 JPEG (proves Flutter [Image.memory] path).
final Uint8List kCap185TestPreviewJpeg = Uint8List.fromList(<int>[
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
  0x4A,
  0x46,
  0x49,
  0x46,
  0x00,
  0x01,
  0x01,
  0x00,
  0x00,
  0x01,
  0x00,
  0x01,
  0x00,
  0x00,
  0xFF,
  0xDB,
  0x00,
  0x43,
  0x00,
  0x08,
  0x06,
  0x06,
  0x07,
  0x06,
  0x05,
  0x08,
  0x07,
  0x07,
  0x07,
  0x09,
  0x09,
  0x08,
  0x0A,
  0x0C,
  0x14,
  0x0D,
  0x0C,
  0x0B,
  0x0B,
  0x0C,
  0x19,
  0x12,
  0x13,
  0x0F,
  0x14,
  0x1D,
  0x1A,
  0x1F,
  0x1E,
  0x1D,
  0x1A,
  0x1C,
  0x1C,
  0x20,
  0x24,
  0x2E,
  0x27,
  0x20,
  0x22,
  0x2C,
  0x23,
  0x1C,
  0x1C,
  0x28,
  0x37,
  0x29,
  0x2C,
  0x30,
  0x31,
  0x34,
  0x34,
  0x34,
  0x1F,
  0x27,
  0x39,
  0x3D,
  0x38,
  0x32,
  0x3C,
  0x2E,
  0x33,
  0x34,
  0x32,
  0xFF,
  0xC0,
  0x00,
  0x0B,
  0x08,
  0x00,
  0x01,
  0x00,
  0x01,
  0x01,
  0x01,
  0x11,
  0x00,
  0xFF,
  0xC4,
  0x00,
  0x14,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0xFF,
  0xC4,
  0x00,
  0x14,
  0x10,
  0x01,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0xFF,
  0xDA,
  0x00,
  0x08,
  0x01,
  0x01,
  0x00,
  0x00,
  0x3F,
  0x00,
  0x7F,
  0xFF,
  0xD9,
]);

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

      final bytes = await gateway.requestScrubPreviewFrame(4.5);
      expect(bytes, isNull);
    });

    test('P-18.5-3 Host ok: gateway decodes JPEG bytes from channel', () async {
      const codec = pigeon.PlaybackApi.pigeonChannelCodec;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.waketok.PlaybackApi.requestScrubPreviewFrame',
          codec,
        ),
        (message) async => <Object?>[kCap185TestPreviewJpeg],
      );

      final gateway = PlaybackGateway();
      addTearDown(gateway.dispose);

      final bytes = await gateway.requestScrubPreviewFrame(4.5);
      expect(bytes, kCap185TestPreviewJpeg);
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
      Future<Uint8List?> requestPreview(double bucketSeconds) async {
        if (bucketSeconds >= 13) {
          return null;
        }
        return kCap185TestPreviewJpeg;
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
