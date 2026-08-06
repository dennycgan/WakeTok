import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/playback_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PlaybackApi.pigeonChannelCodec;

  String channel(String method) =>
      'dev.flutter.pigeon.waketok.PlaybackApi.$method';

  void mockVoid(String method) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(channel(method), codec),
      (message) async => <Object?>[null],
    );
  }

  tearDown(() {
    for (final m in <String>[
      'load',
      'play',
      'pause',
      'seek',
      'setRate',
      'setMute',
      'setPlaybackPlan',
      'syncPlanPosition',
      'notifyDisplaySurfaceReady',
      'updateNowPlayingMetadata',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(channel(m), codec),
        null,
      );
    }
  });

  test('T-P2 gateway forwards plan / load / play / pause / sync / ready',
      () async {
    for (final m in <String>[
      'load',
      'play',
      'pause',
      'setPlaybackPlan',
      'syncPlanPosition',
      'notifyDisplaySurfaceReady',
      'updateNowPlayingMetadata',
    ]) {
      mockVoid(m);
    }

    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    final item = PlaybackItem(
      assetIdentifier: 'v1',
      feedIndex: 0,
      mediaKind: PlaybackMediaKind.video,
    );
    await gateway.setPlaybackPlan(
      PlaybackPlan(
        planId: 'p',
        orderedItems: [item],
        currentIndex: 0,
      ),
    );
    await gateway.load(item);
    await gateway.play();
    await gateway.pause();
    await gateway.syncPlanPosition(assetIdentifier: 'v1', feedIndex: 0);
    await gateway.notifyDisplaySurfaceReady('v1');
    await gateway.updateNowPlayingMetadata();
  });

  test('T-P3 FlutterApi runtime event maps into stream', () async {
    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    final future = gateway.runtimeEvents.first;
    gateway.onPlaybackRuntimeEvent(
      pigeon.PlaybackRuntimeEventDto(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 1.5,
        playbackState: pigeon.PlaybackState.playing,
      ),
    );
    final event = await future;
    expect(event.planId, 'p');
    expect(event.currentItemIdentifier, 'v1');
    expect(event.playbackState, PlaybackRuntimeState.playing);
  });

  test('T-P4 FlutterApi restore maps into restoreRequests stream', () async {
    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    final future = gateway.restoreRequests.first;
    gateway.onPlaybackRestoreRequired(3, 'asset-3');
    final event = await future;
    expect(event.feedIndex, 3);
    expect(event.assetIdentifier, 'asset-3');
  });
}
