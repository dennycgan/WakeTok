import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_intent.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
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
  test('C-18.4-T1 tap true→false sends intent then pause', () async {
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
    playback.intentCalls.clear();

    await coordinator.onUserTapTogglePlay(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );

    expect(coordinator.userIntentWantsPlay, isFalse);
    expect(playback.intentCalls, hasLength(1));
    expect(playback.intentCalls.single.wantsPlay, isFalse);
    expect(playback.intentCalls.single.startsNewNavigationActivation, isFalse);
    expect(playback.intentCalls.single.clearsPendingNavigationActivation, isFalse);
    final intentIdx = playback.calls.indexWhere(
      (c) => c.startsWith('setPlaybackIntent:'),
    );
    final pauseIdx = playback.calls.indexOf('pause');
    expect(intentIdx, isNonNegative);
    expect(pauseIdx, greaterThan(intentIdx));
  });

  test('C-18.4-T2 tap false→true sends intent then play; nav false', () async {
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
    playback.intentCalls.clear();

    await coordinator.onUserTapTogglePlay(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );

    expect(coordinator.userIntentWantsPlay, isTrue);
    expect(playback.intentCalls.single.wantsPlay, isTrue);
    expect(playback.intentCalls.single.startsNewNavigationActivation, isFalse);
    final intentIdx = playback.calls.indexWhere(
      (c) => c.startsWith('setPlaybackIntent:'),
    );
    final playIdx = playback.calls.indexOf('play');
    expect(intentIdx, isNonNegative);
    expect(playIdx, greaterThan(intentIdx));
  });

  test('C-18.4-T3 stale generation sends no play/pause after intent', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final staleGen = gate.begin();

    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: staleGen,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );
    playback.calls.clear();
    playback.intentCalls.clear();

    gate.begin();
    await coordinator.onUserTapTogglePlay(
      assetIdentifier: 'a',
      displayGeneration: staleGen,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );

    expect(playback.calls.where((c) => c == 'play'), isEmpty);
    expect(playback.calls.where((c) => c == 'pause'), isEmpty);
  });

  test('C-18.4-R1 resume sync after user tap pause does not play', () async {
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
    playback.intentCalls.clear();

    await coordinator.onLeaveForeground(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
    );
    await coordinator.onForegroundResumeSync(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );

    expect(coordinator.userIntentWantsPlay, isFalse);
    expect(playback.calls.where((c) => c == 'play'), isEmpty);
    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);
  });

  test('C-18.4-R2 reconcile restores play after leave raced surface-ready', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();

    await coordinator.onLeaveForeground(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
    );
    expect(coordinator.isForegroundLifecycle, isFalse);

    coordinator.reconcileAppForegroundResumed();
    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );

    expect(coordinator.isForegroundLifecycle, isTrue);
    expect(playback.calls.where((c) => c == 'play'), isNotEmpty);
  });

  group('U-18.4-A1 showCenterPlaybackAffordance', () {
    bool base({
      bool isCurrent = true,
      bool isL2ReadyOrdinaryVideo = true,
      bool isSurfaceReady = true,
      bool transitionCovering = false,
      bool hardFailure = false,
      bool isForegroundLifecycle = true,
      bool userIntentWantsPlay = false,
    }) {
      return showCenterPlaybackAffordance(
        isCurrent: isCurrent,
        isL2ReadyOrdinaryVideo: isL2ReadyOrdinaryVideo,
        isSurfaceReady: isSurfaceReady,
        transitionCovering: transitionCovering,
        hardFailure: hardFailure,
        isForegroundLifecycle: isForegroundLifecycle,
        userIntentWantsPlay: userIntentWantsPlay,
      );
    }

    test('user tap pause: all gates true + intent false → show', () {
      expect(base(), isTrue);
    });

    test('each gate alone false → hide', () {
      expect(base(isCurrent: false), isFalse);
      expect(base(isL2ReadyOrdinaryVideo: false), isFalse);
      expect(base(isSurfaceReady: false), isFalse);
      expect(base(transitionCovering: true), isFalse);
      expect(base(hardFailure: true), isFalse);
      expect(base(isForegroundLifecycle: false), isFalse);
      expect(base(userIntentWantsPlay: true), isFalse);
    });
  });
}
