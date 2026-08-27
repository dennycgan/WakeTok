import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_intent.dart';

SystemPlaybackPermission _allAllowed() {
  return const SystemPlaybackPermission(
    isForegroundLifecycle: true,
    isCurrentPage: true,
    isL2ReadyVideo: true,
    isSurfaceReady: true,
    transitionBlocksPlayback: false,
    hasHardPlaybackFailure: false,
  );
}

void main() {
  test('systemPermissionAllowsPlay is true only when all gates allow', () {
    final base = _allAllowed();
    expect(systemPermissionAllowsPlay(base), isTrue);

    expect(
      systemPermissionAllowsPlay(
        SystemPlaybackPermission(
          isForegroundLifecycle: false,
          isCurrentPage: base.isCurrentPage,
          isL2ReadyVideo: base.isL2ReadyVideo,
          isSurfaceReady: base.isSurfaceReady,
          transitionBlocksPlayback: base.transitionBlocksPlayback,
          hasHardPlaybackFailure: base.hasHardPlaybackFailure,
        ),
      ),
      isFalse,
    );
    expect(
      systemPermissionAllowsPlay(
        SystemPlaybackPermission(
          isForegroundLifecycle: base.isForegroundLifecycle,
          isCurrentPage: false,
          isL2ReadyVideo: base.isL2ReadyVideo,
          isSurfaceReady: base.isSurfaceReady,
          transitionBlocksPlayback: base.transitionBlocksPlayback,
          hasHardPlaybackFailure: base.hasHardPlaybackFailure,
        ),
      ),
      isFalse,
    );
    expect(
      systemPermissionAllowsPlay(
        SystemPlaybackPermission(
          isForegroundLifecycle: base.isForegroundLifecycle,
          isCurrentPage: base.isCurrentPage,
          isL2ReadyVideo: false,
          isSurfaceReady: base.isSurfaceReady,
          transitionBlocksPlayback: base.transitionBlocksPlayback,
          hasHardPlaybackFailure: base.hasHardPlaybackFailure,
        ),
      ),
      isFalse,
    );
    expect(
      systemPermissionAllowsPlay(
        SystemPlaybackPermission(
          isForegroundLifecycle: base.isForegroundLifecycle,
          isCurrentPage: base.isCurrentPage,
          isL2ReadyVideo: base.isL2ReadyVideo,
          isSurfaceReady: false,
          transitionBlocksPlayback: base.transitionBlocksPlayback,
          hasHardPlaybackFailure: base.hasHardPlaybackFailure,
        ),
      ),
      isFalse,
    );
    expect(
      systemPermissionAllowsPlay(
        SystemPlaybackPermission(
          isForegroundLifecycle: base.isForegroundLifecycle,
          isCurrentPage: base.isCurrentPage,
          isL2ReadyVideo: base.isL2ReadyVideo,
          isSurfaceReady: base.isSurfaceReady,
          transitionBlocksPlayback: true,
          hasHardPlaybackFailure: base.hasHardPlaybackFailure,
        ),
      ),
      isFalse,
    );
    expect(
      systemPermissionAllowsPlay(
        SystemPlaybackPermission(
          isForegroundLifecycle: base.isForegroundLifecycle,
          isCurrentPage: base.isCurrentPage,
          isL2ReadyVideo: base.isL2ReadyVideo,
          isSurfaceReady: base.isSurfaceReady,
          transitionBlocksPlayback: base.transitionBlocksPlayback,
          hasHardPlaybackFailure: true,
        ),
      ),
      isFalse,
    );
  });

  test('effectiveShouldPlay requires user intent even when permission allows', () {
    expect(
      effectiveShouldPlay(
        userIntentWantsPlay: false,
        permission: _allAllowed(),
      ),
      isFalse,
    );
    expect(
      effectiveShouldPlay(
        userIntentWantsPlay: true,
        permission: _allAllowed(),
      ),
      isTrue,
    );
  });
}
