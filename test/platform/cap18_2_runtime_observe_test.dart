import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/playback_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('T-18.2-2 playbackRuntimeStateFromPigeon maps every enum', () {
    expect(
      playbackRuntimeStateFromPigeon(pigeon.PlaybackState.idle),
      PlaybackRuntimeState.idle,
    );
    expect(
      playbackRuntimeStateFromPigeon(pigeon.PlaybackState.loading),
      PlaybackRuntimeState.loading,
    );
    expect(
      playbackRuntimeStateFromPigeon(pigeon.PlaybackState.playing),
      PlaybackRuntimeState.playing,
    );
    expect(
      playbackRuntimeStateFromPigeon(pigeon.PlaybackState.paused),
      PlaybackRuntimeState.paused,
    );
    expect(
      playbackRuntimeStateFromPigeon(pigeon.PlaybackState.waitingForMedia),
      PlaybackRuntimeState.waitingForMedia,
    );
    expect(
      playbackRuntimeStateFromPigeon(pigeon.PlaybackState.failed),
      PlaybackRuntimeState.failed,
    );
    expect(
      playbackRuntimeStateFromPigeon(pigeon.PlaybackState.completed),
      PlaybackRuntimeState.completed,
    );
  });

  test('T-18.2-3 dispose then runtime callback does not throw', () {
    final gateway = PlaybackGateway();
    gateway.dispose();
    expect(
      () => gateway.onPlaybackRuntimeEvent(
        pigeon.PlaybackRuntimeEventDto(
          planId: 'p',
          currentItemIdentifier: 'v1',
          currentIndex: 0,
          playbackPositionSeconds: 0,
          playbackState: pigeon.PlaybackState.idle,
        ),
      ),
      returnsNormally,
    );
  });

  test('T-18.2-4 runtime stream preserves event order', () async {
    final gateway = PlaybackGateway();
    addTearDown(gateway.dispose);

    final events = <PlaybackRuntimeEvent>[];
    final sub = gateway.runtimeEvents.listen(events.add);

    gateway.onPlaybackRuntimeEvent(
      pigeon.PlaybackRuntimeEventDto(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 1,
        playbackState: pigeon.PlaybackState.playing,
      ),
    );
    gateway.onPlaybackRuntimeEvent(
      pigeon.PlaybackRuntimeEventDto(
        planId: 'p',
        currentItemIdentifier: 'v1',
        currentIndex: 0,
        playbackPositionSeconds: 2,
        playbackState: pigeon.PlaybackState.paused,
      ),
    );

    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(events, hasLength(2));
    expect(events[0].playbackPositionSeconds, 1);
    expect(events[0].playbackState, PlaybackRuntimeState.playing);
    expect(events[1].playbackPositionSeconds, 2);
    expect(events[1].playbackState, PlaybackRuntimeState.paused);
  });
}
