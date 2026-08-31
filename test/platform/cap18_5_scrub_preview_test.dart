import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/platform/playback_gateway.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PlaybackApi.pigeonChannelCodec;

  test('T-18.5-1 gateway forwards requestScrubPreviewFrame', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.waketok.PlaybackApi.requestScrubPreviewFrame',
        codec,
      ),
      (message) async {
        final seconds = (message! as List<Object?>)[0]! as double;
        expect(seconds, closeTo(12.0, 0.001));
        return <Object?>[
          pigeon.ScrubPreviewFrameDto(
            jpegBytes: Uint8List.fromList(<int>[1, 2, 3]),
            actualSeconds: 12.0,
          ),
        ];
      },
    );

    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    final frame = await gateway.requestScrubPreviewFrame(12.0);
    expect(frame, isNotNull);
    expect(frame!.jpegBytes, Uint8List.fromList(<int>[1, 2, 3]));
    expect(frame.actualSeconds, closeTo(12.0, 0.001));
  });

  test('T-18.5-2 gateway nulls when Host omits actualSeconds', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.waketok.PlaybackApi.requestScrubPreviewFrame',
        codec,
      ),
      (message) async => <Object?>[
            pigeon.ScrubPreviewFrameDto(
              jpegBytes: Uint8List.fromList(<int>[1, 2, 3]),
              actualSeconds: null,
            ),
          ],
    );

    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    expect(await gateway.requestScrubPreviewFrame(4.0), isNull);
  });
}
