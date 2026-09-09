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
  test('C-18.3-C1 become-current sends nav intent then play', () async {
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

    expect(playback.intentCalls, hasLength(1));
    expect(playback.intentCalls.single.wantsPlay, isTrue);
    expect(playback.intentCalls.single.startsNewNavigationActivation, isTrue);
    expect(playback.intentCalls.single.clearsPendingNavigationActivation, isFalse);
    final intentIdx = playback.calls.indexWhere(
      (c) => c.startsWith('setPlaybackIntent:'),
    );
    final playIdx = playback.calls.indexOf('play');
    expect(intentIdx, isNonNegative);
    expect(playIdx, greaterThan(intentIdx));
  });

  test('C-18.3-C2 lifecycle leave preserves intent; resume sync plays', () async {
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

    await coordinator.onLeaveForeground(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
    );
    expect(coordinator.userIntentWantsPlay, isTrue);
    expect(playback.intentCalls.single.wantsPlay, isTrue);
    expect(playback.intentCalls.single.clearsPendingNavigationActivation, isTrue);
    expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);

    playback.calls.clear();
    playback.intentCalls.clear();

    await coordinator.onForegroundResumeSync(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );

    expect(coordinator.userIntentWantsPlay, isTrue);
    expect(playback.intentCalls.single.wantsPlay, isTrue);
    expect(playback.calls.where((c) => c == 'play'), isNotEmpty);
  });

  test('C-18.3-C3 stale generation sends no play after intent await', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final staleGen = gate.begin();
    gate.begin();

    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: staleGen,
      displayGate: gate,
      permission: _allAllowed(),
      muted: false,
    );

    expect(playback.calls.where((c) => c == 'play'), isEmpty);
    expect(playback.calls.where((c) => c == 'pause'), isEmpty);
  });

  test('C-18.3-C4 navigation activation truth table', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final genA1 = gate.begin();

    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: genA1,
      displayGate: gate,
      permission: _allAllowed(surfaceReady: false),
      muted: false,
    );
    expect(playback.intentCalls.last.startsNewNavigationActivation, isTrue);

    playback.intentCalls.clear();
    final genB = gate.begin();
    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'b',
      displayGeneration: genB,
      displayGate: gate,
      permission: _allAllowed(surfaceReady: false),
      muted: false,
    );
    expect(playback.intentCalls.last.startsNewNavigationActivation, isTrue);

    playback.intentCalls.clear();
    final genA2 = gate.begin();
    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: genA2,
      displayGate: gate,
      permission: _allAllowed(surfaceReady: false),
      muted: false,
    );
    expect(playback.intentCalls.last.startsNewNavigationActivation, isTrue);

    playback.intentCalls.clear();
    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: genA2,
      displayGate: gate,
      permission: _allAllowed(surfaceReady: true),
      muted: false,
    );
    expect(playback.intentCalls.last.startsNewNavigationActivation, isFalse);
  });

  test('C-18.3-L1 lifecycle during load preserves intent and pauses', () async {
    final playback = FakePlaybackRepository();
    final coordinator = PlaybackCoordinator(playback: playback);
    final gate = FeedMediaRequestGate();
    final generation = gate.begin();

    await coordinator.onLeaveForeground(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
    );
    playback.calls.clear();
    playback.intentCalls.clear();

    await coordinator.onVideoBecomeCurrent(
      assetIdentifier: 'a',
      displayGeneration: generation,
      displayGate: gate,
      permission: SystemPlaybackPermission(
        isForegroundLifecycle: false,
        isCurrentPage: true,
        isL2ReadyVideo: true,
        isSurfaceReady: true,
        transitionBlocksPlayback: false,
        hasHardPlaybackFailure: false,
      ),
      muted: false,
    );

    final intent = playback.intentCalls.single;
    expect(intent.wantsPlay, isTrue);
    expect(intent.startsNewNavigationActivation, isFalse);
    expect(intent.clearsPendingNavigationActivation, isTrue);
    final intentIdx = playback.calls.indexWhere(
      (c) => c.startsWith('setPlaybackIntent:'),
    );
    final pauseIdx = playback.calls.indexOf('pause');
    expect(intentIdx, isNonNegative);
    expect(pauseIdx, greaterThan(intentIdx));
    expect(playback.calls.where((c) => c == 'play'), isEmpty);
  });

  test('C-21.4b-C1 browse cover opened clears intent and pauses', () async {
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
    expect(coordinator.userIntentWantsPlay, isTrue);
    playback.calls.clear();

    await coordinator.onBrowseCoverOpened();
    expect(coordinator.userIntentWantsPlay, isFalse);
    expect(playback.calls, contains('pause'));
  });

  test(
    'C-21.4b-C2 cover-open first become-current: no nav pending; tap resume playOnly-shaped',
    () async {
      final playback = FakePlaybackRepository();
      final coordinator = PlaybackCoordinator(playback: playback);
      final gate = FeedMediaRequestGate();
      final generation = gate.begin();

      await coordinator.onBrowseCoverOpened();
      expect(coordinator.userIntentWantsPlay, isFalse);

      playback.calls.clear();
      playback.intentCalls.clear();

      await coordinator.onVideoBecomeCurrent(
        assetIdentifier: 'icloud-v',
        displayGeneration: generation,
        displayGate: gate,
        permission: _allAllowed(),
        muted: false,
        browseCoverOpen: true,
      );

      expect(coordinator.userIntentWantsPlay, isFalse);
      expect(playback.intentCalls, hasLength(1));
      expect(playback.intentCalls.single.wantsPlay, isFalse);
      expect(
        playback.intentCalls.single.startsNewNavigationActivation,
        isFalse,
      );
      expect(playback.calls.where((c) => c == 'play'), isEmpty);
      expect(playback.calls.where((c) => c == 'pause'), isNotEmpty);

      // Pop: clear cover latch only — intent stays paused (Cap 21.4b).
      playback.calls.clear();
      playback.intentCalls.clear();

      await coordinator.onUserTapTogglePlay(
        assetIdentifier: 'icloud-v',
        displayGeneration: generation,
        displayGate: gate,
        permission: _allAllowed(),
        muted: false,
      );

      expect(coordinator.userIntentWantsPlay, isTrue);
      expect(playback.intentCalls, hasLength(1));
      expect(playback.intentCalls.single.wantsPlay, isTrue);
      expect(
        playback.intentCalls.single.startsNewNavigationActivation,
        isFalse,
      );
      expect(playback.calls.where((c) => c == 'play'), isNotEmpty);
    },
  );

  test(
    'C-21.4b-C3 L2-before-cover baseline: tap resume matches C-21.4b-C2 shape',
    () async {
      final playback = FakePlaybackRepository();
      final coordinator = PlaybackCoordinator(playback: playback);
      final gate = FeedMediaRequestGate();
      final generation = gate.begin();

      await coordinator.onVideoBecomeCurrent(
        assetIdentifier: 'local-v',
        displayGeneration: generation,
        displayGate: gate,
        permission: _allAllowed(),
        muted: false,
      );
      expect(coordinator.userIntentWantsPlay, isTrue);
      expect(playback.intentCalls.last.startsNewNavigationActivation, isTrue);

      await coordinator.onBrowseCoverOpened();
      expect(coordinator.userIntentWantsPlay, isFalse);

      playback.calls.clear();
      playback.intentCalls.clear();

      await coordinator.onUserTapTogglePlay(
        assetIdentifier: 'local-v',
        displayGeneration: generation,
        displayGate: gate,
        permission: _allAllowed(),
        muted: false,
      );

      expect(coordinator.userIntentWantsPlay, isTrue);
      expect(playback.intentCalls, hasLength(1));
      expect(playback.intentCalls.single.wantsPlay, isTrue);
      expect(
        playback.intentCalls.single.startsNewNavigationActivation,
        isFalse,
      );
      expect(playback.calls.where((c) => c == 'play'), isNotEmpty);
    },
  );
}
