import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_live_motion_watchdog.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/live_photo/live_photo_repository.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/features/main_browse/cap26_live_long_press_arbitration.dart';
import 'package:waketok/features/main_browse/cap26_live_long_press_gesture.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_live_photo_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Finder _mediaFeedPage(String assetIdentifier) {
  return find.byWidgetPredicate(
    (w) => w is MediaFeedPage && w.assetIdentifier == assetIdentifier,
    skipOffstage: false,
  );
}

MediaFeedPageState _pageState(WidgetTester tester, String id) {
  return tester.state<MediaFeedPageState>(_mediaFeedPage(id));
}

Future<void> _seedLiveHarness(
  WidgetTester tester, {
  required FakeLivePhotoRepository live,
  required FakeMediaDisplayRepository display,
  String id = 'live-1',
}) async {
  seedDecodableStillPaths(
    display,
    [id],
    mediaKind: PlaybackMediaKind.livePhoto,
  );
  await tester.pumpWidget(
    permissionUiHarness(
      repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
      assetSources: FakeAssetSourceRepository(allIds: [id]),
      mediaDisplay: display,
      livePhoto: live,
    ),
  );
  await _pumpAsyncWork(tester);
}

/// Auto-play once → ended → static key frame with optional retained clear.
Future<MediaFeedPageState> _settleToStaticKeyFrame(
  WidgetTester tester,
  FakeLivePhotoRepository live, {
  required bool clearRetained,
}) async {
  final page = _pageState(tester, 'live-1');
  live.endedController.add(
    const LivePhotoPlaybackEndedEvent(assetIdentifier: 'live-1'),
  );
  await _pumpAsyncWork(tester);
  expect(page.debugLiveMotionMounted, isFalse);
  if (clearRetained) {
    page.debugLiveHostPhotoRetained = false;
  }
  live.calls.clear();
  live.autoReady = false;
  return page;
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('W-26.2 gesture Listener', () {
    testWidgets('fires after hold within slop', (tester) async {
      var fires = 0;
      var releases = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Cap26LiveLongPressGesture(
                  enabled: true,
                  onLongPressFire: () => fires += 1,
                  onLongPressRelease: () => releases += 1,
                ),
              ],
            ),
          ),
        ),
      );

      final center = tester.getCenter(
        find.byKey(const Key('cap26LiveLongPressGesture')),
      );
      final gesture = await tester.startGesture(center);
      await tester.pump(kLiveLongPressHoldDuration);
      await tester.pump();
      expect(fires, 1);
      expect(releases, 0);
      await gesture.up();
      await tester.pump();
      expect(releases, 1);
    });

    testWidgets('cancels when slop exceeded before hold', (tester) async {
      var fires = 0;
      var releases = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Cap26LiveLongPressGesture(
                  enabled: true,
                  onLongPressFire: () => fires += 1,
                  onLongPressRelease: () => releases += 1,
                ),
              ],
            ),
          ),
        ),
      );

      final center = tester.getCenter(
        find.byKey(const Key('cap26LiveLongPressGesture')),
      );
      final gesture = await tester.startGesture(center);
      await gesture.moveBy(const Offset(kLiveLongPressMaxSlopPx + 1, 0));
      await tester.pump(kLiveLongPressHoldDuration);
      await tester.pump();
      expect(fires, 0);
      await gesture.up();
      expect(releases, 0);
    });
  });

  group('Cap 26.2 risk-gate tests (U-26.2-4 / W-26.2-e / W-26.2-f)', () {
    testWidgets(
      'U-26.2-4 Path S request held: second long-press keeps requestLivePhoto count at 1',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: true,
        );

        final requestHold = Completer<void>();
        live.requestHold = requestHold;
        live.requestHoldAssetId = 'live-1';

        unawaited(page.debugUserLongPressReplay());
        await tester.pump();
        await tester.idle();
        await tester.pump();
        expect(page.debugLiveSilentReplayInFlight, isTrue);
        expect(
          live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
          1,
        );

        await page.debugUserLongPressReplay();
        await tester.pump();
        await tester.idle();
        await tester.pump();
        expect(
          live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
          1,
          reason: '_liveSilentReplayInFlight must block re-entrant Path S',
        );

        requestHold.complete();
        await _pumpAsyncWork(tester);
        expect(
          live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
          1,
        );
      },
    );

    testWidgets(
      'W-26.2-e Path R: no requestLivePhoto; only startPlayback after remount',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: false,
        );
        expect(page.debugLiveHostPhotoRetained, isTrue);

        await page.debugUserLongPressReplay();
        await _pumpAsyncWork(tester);

        expect(
          live.calls.where((c) => c.startsWith('requestLivePhoto:')),
          isEmpty,
        );
        expect(live.calls, contains('startPlayback'));
        expect(
          live.calls.where((c) => c == 'startPlayback').length,
          1,
        );
        expect(
          find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'W-26.2-e Path S: request stays behind cancel on LiveHostOpSerial '
      '(no overlap while cancel held)',
      (tester) async {
        // Same discipline as L-F8: if Path S bypassed feed-scoped serial,
        // a held cancel would not block the next requestLivePhoto.
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: true,
        );

        // First Path S starts; hold its request so lifecycle cancel queues
        // behind it on LiveHostOpSerial.
        final requestHold = Completer<void>();
        live.requestHold = requestHold;
        live.requestHoldAssetId = 'live-1';
        unawaited(page.debugUserLongPressReplay());
        await tester.pump();
        await tester.idle();
        await tester.pump();
        expect(
          live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
          1,
        );
        expect(page.debugLiveSilentReplayInFlight, isTrue);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        await tester.idle();
        await tester.pump();
        final midHold = List<String>.from(live.calls);
        expect(
          midHold.where((c) => c == 'cancel:live-1'),
          isEmpty,
          reason:
              'cancel must wait for in-flight Path S request on '
              'LiveHostOpSerial; mid=$midHold',
        );

        requestHold.complete();
        await _pumpAsyncWork(tester);
        final after = live.calls.skip(midHold.length).toList();
        expect(after, contains('cancel:live-1'));
        // No second Path S request while interrupted.
        expect(
          live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
          1,
        );
      },
    );

    testWidgets(
      'W-26.2-f after lifecycle unload+resume, long-press takes Path R '
      '(no new requestLivePhoto)',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);

        final page = _pageState(tester, 'live-1');
        expect(page.debugLiveMotionMounted, isTrue);
        expect(page.debugLiveHostPhotoRetained, isTrue);

        // Mounted path: unload+stop, pending retained (not cancel).
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await _pumpAsyncWork(tester);
        expect(page.debugLiveMotionMounted, isFalse);
        expect(page.debugLiveHostPhotoRetained, isTrue);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _pumpAsyncWork(tester);
        expect(page.debugLiveMotionMounted, isFalse);
        expect(page.debugLiveHostPhotoRetained, isTrue);

        live.calls.clear();
        await page.debugUserLongPressReplay();
        await _pumpAsyncWork(tester);

        expect(
          live.calls.where((c) => c.startsWith('requestLivePhoto:')),
          isEmpty,
          reason: 'resume leave keeps Host pending → Path R',
        );
        expect(live.calls, contains('startPlayback'));
        expect(
          find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'W-26.2-f Path S interrupted by AppLifecycle: cancel + clear inFlight, '
      'then long-press starts a new Path S',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: true,
        );

        unawaited(page.debugUserLongPressReplay());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(page.debugLiveSilentReplayInFlight, isTrue);
        expect(live.calls, contains('requestLivePhoto:live-1'));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await _pumpAsyncWork(tester);

        expect(page.debugLiveSilentReplayInFlight, isFalse);
        expect(page.debugLiveHostPhotoRetained, isFalse);
        expect(live.calls, contains('cancel:live-1'));
        expect(live.calls, contains('stopPlayback'));

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _pumpAsyncWork(tester);

        live.calls.clear();
        live.autoReady = true;
        await page.debugUserLongPressReplay();
        await _pumpAsyncWork(tester);

        expect(
          live.calls,
          contains('requestLivePhoto:live-1'),
          reason: 'after Path S cancel, next long-press must re-enter Path S',
        );
        expect(page.debugLiveSilentReplayInFlight, isFalse);
        expect(page.debugLiveHostPhotoRetained, isTrue);
      },
    );
  });

  group('Cap 26.2 supporting coverage', () {
    testWidgets(
      'Path S silent re-request — no prepare chrome; clears in-flight on ready∧mounted',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: true,
        );

        final replay = page.debugUserLongPressReplay();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(page.debugLiveSilentReplayInFlight, isTrue);
        expect(page.debugLivePreparing, isFalse);
        expect(
          find.byKey(const Key('mainBrowseFeedLivePreparing_live-1')),
          findsNothing,
        );

        live.readyController.add(
          const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
        );
        await replay;
        await _pumpAsyncWork(tester);

        expect(live.calls, contains('requestLivePhoto:live-1'));
        expect(page.debugLiveSilentReplayInFlight, isFalse);
        expect(page.debugLivePreparing, isFalse);
        expect(page.debugLiveHostPhotoRetained, isTrue);
        expect(
          find.byKey(const Key('mainBrowseFeedLiveMotion_live-1')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'user Path S bypasses watchdog skip; auto prepare still honors it',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);

        final element = tester.element(find.byType(VerticalMediaFeed));
        final container = ProviderScope.containerOf(element);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: true,
        );
        container
            .read(browseLiveMotionWatchdogSkipIdsProvider.notifier)
            .add('live-1');

        await page.debugPrepareLiveMotion();
        await _pumpAsyncWork(tester);
        expect(
          live.calls.where((c) => c.startsWith('requestLivePhoto:')),
          isEmpty,
          reason: 'auto prepare must honor skip set',
        );
        expect(page.debugLivePreparing, isFalse);

        await page.debugUserLongPressReplay();
        live.readyController.add(
          const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
        );
        await _pumpAsyncWork(tester);
        expect(live.calls, contains('requestLivePhoto:live-1'));
        expect(
          container.read(browseLiveMotionWatchdogSkipIdsProvider).contains(
                'live-1',
              ),
          isTrue,
          reason: 'successful user replay must not clear skip membership',
        );
      },
    );

    testWidgets(
      'Path R remount publishes liveMotionMounted for Share dim',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);

        final element = tester.element(find.byType(VerticalMediaFeed));
        final container = ProviderScope.containerOf(element);
        expect(
          container.read(mainBrowseCurrentLiveMotionMountedProvider),
          isTrue,
        );

        live.endedController.add(
          const LivePhotoPlaybackEndedEvent(assetIdentifier: 'live-1'),
        );
        await _pumpAsyncWork(tester);
        expect(
          container.read(mainBrowseCurrentLiveMotionMountedProvider),
          isFalse,
        );

        await _pageState(tester, 'live-1').debugUserLongPressReplay();
        await _pumpAsyncWork(tester);
        expect(
          container.read(mainBrowseCurrentLiveMotionMountedProvider),
          isTrue,
        );
      },
    );

    testWidgets(
      'watchdog timeout with startIssued=true adds skip and unloads',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);

        final element = tester.element(find.byType(VerticalMediaFeed));
        final container = ProviderScope.containerOf(element);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: false,
        );

        expect(
          container.read(browseLiveMotionWatchdogSkipIdsProvider).contains(
                'live-1',
              ),
          isFalse,
        );

        // Cap 26.4b B+C0: force arm after a hung start (startIssued true).
        page.debugSetLiveMotionMounted(true);
        page.debugLiveStartIssued = true;
        page.debugArmLiveEndedWatchdog();
        await tester.pump(kLiveMotionEndedWatchdog);
        await tester.pump(const Duration(milliseconds: 1));
        await _pumpAsyncWork(tester);

        expect(
          container.read(browseLiveMotionWatchdogSkipIdsProvider).contains(
                'live-1',
              ),
          isTrue,
          reason: 'hung play after startPlayback issued must session-skip',
        );
        expect(page.debugLiveMotionMounted, isFalse);
      },
    );

    testWidgets(
      'watchdog timeout with startIssued=false unloads without skip',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);

        final element = tester.element(find.byType(VerticalMediaFeed));
        final container = ProviderScope.containerOf(element);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: false,
        );

        expect(
          container.read(browseLiveMotionWatchdogSkipIdsProvider).contains(
                'live-1',
              ),
          isFalse,
        );

        // Cap 26.4b C0 hard gate: arm without startIssued must not ban auto.
        page.debugSetLiveMotionMounted(true);
        page.debugLiveStartIssued = false;
        page.debugArmLiveEndedWatchdog();
        await tester.pump(kLiveMotionEndedWatchdog);
        await tester.pump(const Duration(milliseconds: 1));
        await _pumpAsyncWork(tester);

        expect(
          container.read(browseLiveMotionWatchdogSkipIdsProvider).contains(
                'live-1',
              ),
          isFalse,
          reason: '¬startIssued timeout must not skip.add (C0)',
        );
        expect(page.debugLiveMotionMounted, isFalse);
      },
    );
  });

  group('Cap 26.5a release-to-stop', () {
    testWidgets(
      'W-26.5a-1 after fire, Listener stays when liveMotionMounted becomes true',
      (tester) async {
        var mayFire = true;
        var holdingAfterFire = false;
        var fires = 0;
        var releases = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Stack(
                    children: [
                      Cap26LiveLongPressGesture(
                        enabled: shouldMountLiveLongPressListener(
                          mayFire: mayFire,
                          holdingAfterFire: holdingAfterFire,
                          isCurrent: true,
                        ),
                        onLongPressFire: () {
                          fires += 1;
                          setState(() {
                            holdingAfterFire = true;
                            // Simulate Path R remount disarming mayFire.
                            mayFire = false;
                          });
                        },
                        onLongPressRelease: () {
                          releases += 1;
                          setState(() => holdingAfterFire = false);
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        final center = tester.getCenter(
          find.byKey(const Key('cap26LiveLongPressGesture')),
        );
        final gesture = await tester.startGesture(center);
        await tester.pump(kLiveLongPressHoldDuration);
        await tester.pump();
        expect(fires, 1);
        expect(mayFire, isFalse);
        expect(holdingAfterFire, isTrue);
        expect(
          find.byKey(const Key('cap26LiveLongPressGesture')),
          findsOneWidget,
          reason: 'Listener must not shrink solely because mayFire→false '
              'after Path R mount',
        );
        await gesture.up();
        await tester.pump();
        expect(releases, 1);
      },
    );

    testWidgets(
      'W-26.5a-2 release cancels watchdog and never skip.add',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);
        final element = tester.element(find.byType(VerticalMediaFeed));
        final container = ProviderScope.containerOf(element);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: false,
        );

        page.debugUserHoldReplayActive = true;
        await page.debugUserLongPressReplay();
        await _pumpAsyncWork(tester);
        expect(page.debugLiveMotionMounted, isTrue);
        expect(page.debugLiveEndedWatchdogArmed, isTrue);

        live.calls.clear();
        await page.debugUserLongPressReleaseStop();
        await _pumpAsyncWork(tester);

        expect(page.debugUserHoldReplayActive, isFalse);
        expect(page.debugLiveMotionMounted, isFalse);
        expect(page.debugLiveEndedWatchdogArmed, isFalse);
        expect(page.debugLiveHostPhotoRetained, isTrue);
        expect(live.calls, contains('stopPlayback'));
        expect(
          container.read(browseLiveMotionWatchdogSkipIdsProvider).contains(
                'live-1',
              ),
          isFalse,
          reason: 'user-release must never skip.add',
        );

        // Watchdog must stay cancelled — pumping full duration must not skip.
        await tester.pump(kLiveMotionEndedWatchdog);
        await tester.pump(const Duration(milliseconds: 1));
        await _pumpAsyncWork(tester);
        expect(
          container.read(browseLiveMotionWatchdogSkipIdsProvider).contains(
                'live-1',
              ),
          isFalse,
        );
      },
    );

    testWidgets(
      'W-26.5a-3 Path S in-flight: release cancels immediately (no wait for ready)',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: false);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: true,
        );

        final requestHold = Completer<void>();
        live.requestHold = requestHold;
        live.requestHoldAssetId = 'live-1';

        page.debugUserHoldReplayActive = true;
        unawaited(page.debugUserLongPressReplay());
        await tester.pump();
        await tester.idle();
        await tester.pump();
        expect(page.debugLiveSilentReplayInFlight, isTrue);
        expect(
          live.calls.where((c) => c == 'requestLivePhoto:live-1').length,
          1,
        );

        // Do not await releaseStop while request is held — cancel queues
        // behind LiveHostOpSerial (same discipline as W-26.2-e Path S).
        unawaited(page.debugUserLongPressReleaseStop());
        await tester.pump();
        await tester.idle();
        await tester.pump();

        expect(page.debugLiveSilentReplayInFlight, isFalse);
        expect(page.debugLiveHostPhotoRetained, isFalse);
        expect(page.debugUserHoldReplayActive, isFalse);
        requestHold.complete();
        await _pumpAsyncWork(tester);
        expect(live.calls, contains('cancel:live-1'));
        expect(live.calls, contains('stopPlayback'));
        expect(
          live.calls.where((c) => c == 'startPlayback'),
          isEmpty,
          reason: 'release must not wait for ready then play',
        );

        // Late ready must not start playback after cancel.
        live.readyController.add(
          const LivePhotoReadyEvent(assetIdentifier: 'live-1'),
        );
        await _pumpAsyncWork(tester);
        expect(
          live.calls.where((c) => c == 'startPlayback'),
          isEmpty,
        );
      },
    );

    testWidgets(
      'W-26.5a-4 natural ended while finger down: no loop / no re-fire',
      (tester) async {
        var mayFire = true;
        var holdingAfterFire = false;
        var fires = 0;
        late StateSetter treeSetState;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  treeSetState = setState;
                  return Stack(
                    children: [
                      Cap26LiveLongPressGesture(
                        enabled: shouldMountLiveLongPressListener(
                          mayFire: mayFire,
                          holdingAfterFire: holdingAfterFire,
                          isCurrent: true,
                        ),
                        onLongPressFire: () {
                          fires += 1;
                          setState(() {
                            holdingAfterFire = true;
                            mayFire = false;
                          });
                        },
                        onLongPressRelease: () {
                          setState(() {
                            holdingAfterFire = false;
                            mayFire = true;
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        final center = tester.getCenter(
          find.byKey(const Key('cap26LiveLongPressGesture')),
        );
        final gesture = await tester.startGesture(center);
        await tester.pump(kLiveLongPressHoldDuration);
        await tester.pump();
        expect(fires, 1);

        // Natural ended → static: mayFire becomes true again while same
        // finger is still down — must not start a new hold timer / fire.
        treeSetState(() => mayFire = true);
        await tester.pump();
        await tester.pump(kLiveLongPressHoldDuration);
        await tester.pump(kLiveLongPressHoldDuration);
        expect(
          fires,
          1,
          reason: 'natural end must not re-fire until a new pointer down',
        );
        await gesture.up();
        await tester.pump();
        expect(fires, 1);
      },
    );

    testWidgets(
      'W-26.5a-4b feed: natural ended unload while hold active stays still',
      (tester) async {
        final live = FakeLivePhotoRepository(autoReady: true);
        final display = FakeMediaDisplayRepository();
        await _seedLiveHarness(tester, live: live, display: display);
        final page = await _settleToStaticKeyFrame(
          tester,
          live,
          clearRetained: false,
        );

        page.debugUserHoldReplayActive = true;
        await page.debugUserLongPressReplay();
        await _pumpAsyncWork(tester);
        expect(page.debugLiveMotionMounted, isTrue);

        live.calls.clear();
        live.endedController.add(
          const LivePhotoPlaybackEndedEvent(assetIdentifier: 'live-1'),
        );
        await _pumpAsyncWork(tester);

        expect(page.debugLiveMotionMounted, isFalse);
        expect(page.debugUserHoldReplayActive, isTrue);
        expect(
          live.calls.where((c) => c == 'startPlayback'),
          isEmpty,
          reason: 'natural ended must not loop / restart while finger down',
        );

        await page.debugUserLongPressReleaseStop();
        await _pumpAsyncWork(tester);
        expect(page.debugUserHoldReplayActive, isFalse);
        expect(page.debugLiveMotionMounted, isFalse);
      },
    );
  });
}
