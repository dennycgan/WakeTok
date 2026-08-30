import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/features/main_browse/feed_media_request_gate.dart';
import 'package:waketok/features/main_browse/playback_coordinator.dart';

import '../../library_smoke/fake_playback_repository.dart';

SystemPlaybackPermission _allAllowed({bool surfaceReady = true}) {
  return SystemPlaybackPermission(
    isForegroundLifecycle: true,
    isCurrentPage: true,
    isL2ReadyVideo: true,
    isSurfaceReady: surfaceReady,
    transitionBlocksPlayback: false,
    hasHardPlaybackFailure: false,
  );
}

void main() {
  test('C-18.5-1 scrub complete seeks once then plays when intent true', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();

    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );
    playback.calls.clear();

    await coordinator.onUserScrubBegin(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
    );
    expect(playback.calls, contains('pause'));

    await coordinator.onUserScrubComplete(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      positionSeconds: 12.5,
      permission: _allAllowed(),
      muted: false,
    );

    expect(
      playback.calls.where((c) => c.startsWith('seek:')),
      hasLength(1),
    );
    expect(playback.calls.last, 'playFromCurrentPosition');
  });

  test('C-18.5-1b scrub complete clears pending nav before seek', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();

    await coordinator.onUserScrubComplete(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      positionSeconds: 4,
      permission: _allAllowed(),
      muted: false,
    );

    expect(playback.intentCalls, isNotEmpty);
    expect(playback.intentCalls.last.clearsPendingNavigationActivation, isTrue);
    expect(
      playback.calls.indexWhere((c) => c.startsWith('seek:4')),
      lessThan(playback.calls.indexOf('playFromCurrentPosition')),
    );
  });

  test('C-18.5-2 scrub complete with intent false does not play', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();

    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );
    await coordinator.onUserTapTogglePlay(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );
    playback.calls.clear();

    await coordinator.onUserScrubComplete(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      positionSeconds: 4,
      permission: _allAllowed(),
      muted: false,
    );

    expect(playback.calls.where((c) => c.startsWith('seek:')), hasLength(1));
    expect(playback.calls.where((c) => c == 'play'), isEmpty);
    expect(playback.calls.last, 'pause');
  });

  test('C-18.5-4 scrub complete still resumes when seek fails', () async {
    final playback = FakePlaybackRepository()..seekShouldThrow = true;
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();

    await coordinator.onUserScrubComplete(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      positionSeconds: 4,
      permission: _allAllowed(),
      muted: false,
    );

    expect(playback.calls.where((c) => c.startsWith('seek:')), hasLength(2));
    expect(playback.calls, contains('playFromCurrentPosition'));
  });

  test('C-18.5-3 stale generation skips seek', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final staleGeneration = gate.begin();
    gate.begin();

    await coordinator.onUserScrubComplete(
      assetIdentifier: 'a',
      displayGeneration: staleGeneration,
      displayGate: gate,
      positionSeconds: 9,
      permission: _allAllowed(),
      muted: false,
    );

    expect(playback.calls.where((c) => c.startsWith('seek:')), isEmpty);
  });
}
