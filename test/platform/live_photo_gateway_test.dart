import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/live_photo_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.LivePhotoApi.pigeonChannelCodec;

  String channel(String method) =>
      'dev.flutter.pigeon.waketok.LivePhotoApi.$method';

  void mockVoid(String method) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(channel(method), codec),
      (message) async => <Object?>[null],
    );
  }

  void mockError(String method, String code) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(channel(method), codec),
      (message) async => <Object?>[code, 'stub', null],
    );
  }

  const hostMethods = <String>[
    'requestLivePhoto',
    'cancel',
    'startPlayback',
    'stopPlayback',
    'setMute',
    'notifyLiveSurfaceReady',
  ];

  tearDown(() {
    for (final m in hostMethods) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(channel(m), codec),
        null,
      );
    }
  });

  test('L-G1 gateway forwards host methods', () async {
    for (final m in hostMethods) {
      mockVoid(m);
    }

    final gateway = LivePhotoGateway();
    addTearDown(gateway.dispose);

    await gateway.requestLivePhoto('live-1');
    await gateway.cancel('live-1');
    await gateway.notifyLiveSurfaceReady('live-1');
    await gateway.startPlayback();
    await gateway.stopPlayback();
    await gateway.setMute(true);
  });

  test('L-G2 sync request failure throws; failedEvents stays quiet', () async {
    mockError('requestLivePhoto', 'unsupportedMedia');

    final gateway = LivePhotoGateway();
    addTearDown(gateway.dispose);

    var failedCount = 0;
    final sub = gateway.failedEvents.listen((_) => failedCount++);
    addTearDown(sub.cancel);

    try {
      await gateway.requestLivePhoto('not-live');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(e.code, 'unsupportedMedia');
    }

    await Future<void>.delayed(Duration.zero);
    expect(failedCount, 0);
  });

  test('L-G3 onLivePhotoFailed maps to AppError on failedEvents', () async {
    final gateway = LivePhotoGateway();
    addTearDown(gateway.dispose);

    final future = gateway.failedEvents.first;
    gateway.onLivePhotoFailed(
      'live-1',
      pigeon.ErrorCode.iCloudDownloadFailed,
    );
    final event = await future;
    expect(event.assetIdentifier, 'live-1');
    expect(event.error, AppError.iCloudDownloadFailed);
  });

  test('L-G4 ready and playbackEnded map into streams', () async {
    final gateway = LivePhotoGateway();
    addTearDown(gateway.dispose);

    final readyFuture = gateway.readyEvents.first;
    gateway.onLivePhotoReady('live-1');
    expect((await readyFuture).assetIdentifier, 'live-1');

    final endedFuture = gateway.playbackEndedEvents.first;
    gateway.onLivePhotoPlaybackEnded('live-1');
    expect((await endedFuture).assetIdentifier, 'live-1');
  });
}
