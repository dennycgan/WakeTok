import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/playback_gateway.dart';
import 'package:waketok/domain/playback/playback_intent.dart';

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
      'clearPlaybackPool',
      'cancelInFlightPrepare',
      'setTransitionAudioSuppressed',
      'getPlaybackPoolEpoch',
      'setPlaybackIntent',
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
      'clearPlaybackPool',
      'cancelInFlightPrepare',
      'setTransitionAudioSuppressed',
    ]) {
      mockVoid(m);
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(channel('getPlaybackPoolEpoch'), codec),
      (message) async => <Object?>[3],
    );

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
    await gateway.clearPlaybackPool();
    await gateway.cancelInFlightPrepare('v1');
    await gateway.setTransitionAudioSuppressed(true);
    expect(await gateway.getPlaybackPoolEpoch(), 3);
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

  test('T-P5 FlutterApi surface attached maps into stream', () async {
    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    final future = gateway.surfaceAttachedEvents.first;
    gateway.onPlaybackSurfaceAttached(
      pigeon.PlaybackSurfaceAttachedDto(
        assetIdentifier: 'v2',
        feedIndex: 1,
        clearEpoch: 7,
      ),
    );
    final event = await future;
    expect(event.assetIdentifier, 'v2');
    expect(event.feedIndex, 1);
    expect(event.clearEpoch, 7);
  });

  test('T-P5b FlutterApi ready-for-display maps into stream', () async {
    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    final future = gateway.surfaceReadyForDisplayEvents.first;
    gateway.onPlaybackSurfaceReadyForDisplay(
      pigeon.PlaybackSurfaceAttachedDto(
        assetIdentifier: 'v3',
        feedIndex: 2,
        clearEpoch: 9,
      ),
    );
    final event = await future;
    expect(event.assetIdentifier, 'v3');
    expect(event.feedIndex, 2);
    expect(event.clearEpoch, 9);
  });

  test('U-18.3-G1 gateway forwards setPlaybackIntent DTO fields', () async {
    pigeon.PlaybackIntentDto? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(channel('setPlaybackIntent'), codec),
      (message) async {
        captured = (message! as List<Object?>)[0] as pigeon.PlaybackIntentDto;
        return <Object?>[null];
      },
    );
    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    await gateway.setPlaybackIntent(
      const PlaybackIntent(
        assetIdentifier: 'v-nav',
        wantsPlay: true,
        startsNewNavigationActivation: true,
        clearsPendingNavigationActivation: false,
      ),
    );

    expect(captured?.assetIdentifier, 'v-nav');
    expect(captured?.wantsPlay, isTrue);
    expect(captured?.startsNewNavigationActivation, isTrue);
    expect(captured?.clearsPendingNavigationActivation, isFalse);
  });
}
