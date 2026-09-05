import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/waketok_album_constants.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_append_controller.dart';
import 'package:waketok/features/main_browse/magnification_arbitration.dart';
import 'package:waketok/features/main_browse/magnification_reset_button.dart';
import 'package:waketok/features/main_browse/magnification_surface.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../domain/library/fake_waketok_album_store.dart';
import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

const _wakeTokAlbumId = 'waketok-album-cap20-video';

Future<void> _pumpFrames(WidgetTester tester, {int n = 20}) async {
  await tester.pump();
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

ProviderContainer _containerOf(WidgetTester tester, Finder finder) {
  return ProviderScope.containerOf(tester.element(finder));
}

List<double> _scalesFromCalls(List<String> calls) {
  final out = <double>[];
  final re = RegExp(r'^setDisplayMagnification:([^:]+):');
  for (final c in calls) {
    final m = re.firstMatch(c);
    if (m != null) {
      out.add(double.parse(m.group(1)!));
    }
  }
  return out;
}

FakeAssetSourceRepository _videosWithWakeTokAlbum(List<String> videoIds) {
  return FakeAssetSourceRepository(
    videosIds: videoIds,
    availabilityById: {
      for (final id in videoIds) id: AssetAvailability.deviceLocal,
    },
    extraSources: [
      AssetSource(
        kind: AssetSourceKind.album,
        id: _wakeTokAlbumId,
        displayName: waketokAlbumTitle,
        estimatedCount: 1,
        availability: AssetSourceAvailability.available,
        canAddContent: true,
      ),
    ],
  );
}

FakeMediaDisplayRepository _videoDisplay(List<String> ids) {
  final display = FakeMediaDisplayRepository();
  for (final id in ids) {
    display.displayErrorById[id] = 'unsupportedMedia';
    display.previewsById[id] = DisplayAsset(
      assetIdentifier: id,
      mediaKind: PlaybackMediaKind.video,
      localFilePath: '/tmp/fake_preview_$id.jpg',
    );
  }
  return display;
}

/// Minimal host+video binder harness (no full feed / UiKitView).
Widget _videoHostHarness({FakePlaybackRepository? playback}) {
  final fake = playback ?? FakePlaybackRepository();
  return ProviderScope(
    overrides: [
      playbackRepositoryProvider.overrideWithValue(fake),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.dark),
      home: const Scaffold(
        body: MagnificationPointerHost(
          child: NativeDisplayMagnificationPushBinder(
            active: true,
            child: MagnificationHostModeBinder(persistent: false, 
              active: true,
              child: VideoMagnificationTransform(
                apply: false,
                child: SizedBox.expand(
                  child: ColoredBox(color: Color(0xFF101010)),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('T-20.4-1 release path clears transientPinchActive without still magnified', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final mag = container.read(browseMagnificationProvider.notifier);
    mag.setTransientPinchActive(true);
    expect(container.read(browseStillMagnifiedProvider), isFalse);
    mag.setTransientPinchActive(false);
    expect(container.read(browseMagnificationProvider).transientPinchActive, isFalse);
    expect(container.read(browseStillMagnifiedProvider), isFalse);
  });

  test('T-20.4-2 transientPinchActive locks PageView predicate', () {
    expect(
      verticalPageViewScrollLocked(
        isCurrentStillMagnified: false,
        transientPinchActive: true,
      ),
      isTrue,
    );
    expect(
      verticalPageViewScrollLocked(
        isCurrentStillMagnified: false,
        transientPinchActive: false,
      ),
      isFalse,
    );
  });

  testWidgets('T-20.4-5 video mode two-finger pinch then release→fit', (
    tester,
  ) async {
    final playback = FakePlaybackRepository();
    await tester.pumpWidget(_videoHostHarness(playback: playback));
    await tester.pumpAndSettle();

    final container = _containerOf(
      tester,
      find.byKey(const Key('magnificationPointerHost')),
    );
    expect(
      container.read(magnificationHostModeProvider),
      MagnificationHostMode.transient,
    );

    final host = find.byKey(const Key('magnificationPointerHost'));
    final center = tester.getCenter(host);
    final g1 = await tester.startGesture(center + const Offset(-40, 0));
    await tester.pump(const Duration(milliseconds: 16));
    final g2 = await tester.startGesture(center + const Offset(40, 0));
    await tester.pump();
    await g1.moveBy(const Offset(-60, 0));
    await g2.moveBy(const Offset(60, 0));
    await tester.pump();

    expect(container.read(browseStillMagnifiedProvider), isFalse);
    expect(container.read(browseMagnificationProvider).transientPinchActive, isTrue);
    final scaleWhilePinched = container.read(magnificationMatrixProvider).scale;
    expect(scaleWhilePinched, greaterThan(1.5));
    expect(
      playback.calls.any((c) => c.startsWith('setDisplayMagnification:')),
      isTrue,
      reason: 'video pinch must push native surface magnification',
    );
    expect(
      playback.calls.any((c) {
        final m = RegExp(r'^setDisplayMagnification:([^:]+):').firstMatch(c);
        if (m == null) {
          return false;
        }
        return double.parse(m.group(1)!) > 1.5;
      }),
      isTrue,
    );

    await g1.up();
    await g2.up();
    await tester.pump();
    // Mid-release animation: still locking via transientPinchActive.
    expect(container.read(browseMagnificationProvider).transientPinchActive, isTrue);
    expect(container.read(browseStillMagnifiedProvider), isFalse);

    await tester.pump(kCap20VideoReleaseToFitDuration + const Duration(milliseconds: 20));
    await tester.pumpAndSettle();
    expect(container.read(browseMagnificationProvider).transientPinchActive, isFalse);
    expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
    expect(container.read(browseStillMagnifiedProvider), isFalse);
    expect(
      playback.calls.last,
      'setDisplayMagnification:1.0:0.0:0.0',
      reason: 'release→fit must end at native identity',
    );
  });

  testWidgets(
    'T-20.6-Q2 after pinch lift one finger: PageView stays locked (Q2-A contract)',
    (tester) async {
      final playback = FakePlaybackRepository();
      await tester.pumpWidget(_videoHostHarness(playback: playback));
      await tester.pumpAndSettle();

      final container = _containerOf(
        tester,
        find.byKey(const Key('magnificationPointerHost')),
      );
      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(container.read(browseMagnificationProvider).transientPinchActive, isTrue);
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isTrue,
      );

      // Lift one finger — Q2-A keeps single-finger pan + PageView lock.
      await g2.up();
      await tester.pump();
      expect(
        container.read(browseMagnificationProvider).transientPinchActive,
        isTrue,
        reason: 'one finger remaining must not clear transient pinch',
      );
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isTrue,
        reason: 'PageView must stay locked while a finger remains (Q2-A)',
      );
      expect(container.read(magnificationMatrixProvider).scale, greaterThan(1.5));

      await g1.up();
      await tester.pump(kCap20VideoReleaseToFitDuration + const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(container.read(browseMagnificationProvider).transientPinchActive, isFalse);
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isFalse,
      );
    },
  );

  testWidgets(
    'T-20.A-1 release→fit must not republish peak scale after reaching fit',
    (tester) async {
      final playback = FakePlaybackRepository();
      await tester.pumpWidget(_videoHostHarness(playback: playback));
      await tester.pumpAndSettle();

      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await g1.moveBy(const Offset(-80, 0));
      await g2.moveBy(const Offset(80, 0));
      await tester.pump();

      final peak = _scalesFromCalls(playback.calls).fold<double>(
        1.0,
        (m, s) => s > m ? s : m,
      );
      expect(peak, greaterThan(1.5));

      await g1.up();
      await g2.up();
      await tester.pump();
      await tester.pump(
        kCap20VideoReleaseToFitDuration + const Duration(milliseconds: 40),
      );
      await tester.pumpAndSettle();

      final scales = _scalesFromCalls(playback.calls);
      expect(scales, isNotEmpty);
      // Restrict to the descending release tail (after peak) so earlier
      // identity publishes at arm do not false-trigger the fit→spike check.
      var peakIdx = 0;
      for (var i = 1; i < scales.length; i++) {
        if (scales[i] > scales[peakIdx]) {
          peakIdx = i;
        }
      }
      expect(scales[peakIdx], greaterThan(1.5));
      var sawFit = false;
      for (final s in scales.skip(peakIdx)) {
        if (s <= 1.02) {
          sawFit = true;
          continue;
        }
        if (sawFit) {
          fail(
            'mechanism A: scale=$s after a prior fit publish in release tail; '
            'tail=${scales.skip(peakIdx).toList()}',
          );
        }
      }
      expect(sawFit, isTrue);
      expect(scales.last, lessThanOrEqualTo(1.02));
    },
  );

  testWidgets('T-20.4-6 video pinch never shows Reset chrome', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: waketokTheme(Brightness.dark),
              home: const Scaffold(
                body: MagnificationResetButton(overlaySnapshot: null),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(browseMagnificationProvider.notifier).setTransientPinchActive(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('magnificationResetButton')), findsNothing);
  });

  testWidgets(
    'T-20.4-7 video pinch locks PageView physics via transientPinchActive',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFrames(tester);
      final container = _containerOf(tester, find.byType(VerticalMediaFeed));
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.physics, isNot(isA<NeverScrollableScrollPhysics>()));

      container.read(browseMagnificationProvider.notifier).setTransientPinchActive(true);
      await tester.pump();
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );
    },
  );

  testWidgets(
    'T-20.4-8 leave current interrupts release animation to identity',
    (tester) async {
      await tester.pumpWidget(_videoHostHarness());
      await tester.pumpAndSettle();
      final container = _containerOf(
        tester,
        find.byKey(const Key('magnificationPointerHost')),
      );
      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();
      await g1.up();
      await g2.up();
      await tester.pump();

      // Animation in progress (~halfway).
      await tester.pump(const Duration(milliseconds: 60));
      expect(container.read(browseMagnificationProvider).transientPinchActive, isTrue);
      expect(
        container.read(magnificationMatrixProvider).scale,
        greaterThan(kCap20MinScale + kCap20MagnifiedEpsilon),
      );

      container.read(browseMagnificationProvider.notifier).forceFit();
      await tester.pump();
      expect(container.read(browseMagnificationProvider).transientPinchActive, isFalse);
      expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
      expect(
        container.read(magnificationMatrixProvider).translation,
        Offset.zero,
      );

      // Further time must not resurrect a non-identity matrix.
      await tester.pump(kCap20VideoReleaseToFitDuration);
      await tester.pump();
      expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
    },
  );

  testWidgets(
    'T-20.4-9 photo L1 uses transient mode and release→fit (non-persistent)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      // Hold Layer-2 so the page stays on preview (L1) for this case.
      display.displayGates['a1'] = Completer<void>();
      display.displayGates['a2'] = Completer<void>();

      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
        ),
      );
      await _pumpFrames(tester);
      final container = _containerOf(tester, find.byType(VerticalMediaFeed));
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.transient,
        reason: 'photo L1 (preview) must arm non-persistent video mode',
      );

      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      expect(
        container.read(browseMagnificationProvider).transientPinchActive,
        isTrue,
      );
      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(
        container.read(magnificationMatrixProvider).scale,
        greaterThan(1.5),
      );
      await g1.up();
      await g2.up();
      await tester.pump();
      await tester.pump(kCap20VideoReleaseToFitDuration + const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 50));

      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(container.read(browseMagnificationProvider).transientPinchActive, isFalse);
      expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
      expect(find.byKey(const Key('magnificationResetButton')), findsNothing);
    },
  );

  testWidgets(
    'T-20.4-10 video page Cap19 left-swipe coexists with real pinch',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final mutations = FakeAlbumMutationRepository();
      final albumStore = FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId;
      final display = _videoDisplay(const ['v1', 'v2']);
      final playback = FakePlaybackRepository();

      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _videosWithWakeTokAlbum(const ['v1', 'v2']),
          albumMutations: mutations,
          wakeTokAlbumStore: albumStore,
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await _pumpFrames(tester);
      final container = _containerOf(tester, find.byType(VerticalMediaFeed));
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await _pumpFrames(tester, n: 40);

      // Wait until current video surface arms host mode.
      var armed = false;
      for (var i = 0; i < 40; i++) {
        if (container.read(magnificationHostModeProvider) ==
            MagnificationHostMode.transient) {
          armed = true;
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(
        armed,
        isTrue,
        reason: 'mounted video surface must set MagnificationHostMode.transient',
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(container.read(cap19LeftSwipeArmingProvider), isTrue);
      expect(find.byKey(const Key('cap19LeftSwipeGesture')), findsOneWidget);

      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(container.read(browseMagnificationProvider).transientPinchActive, isTrue);
      expect(mutations.addCalls, 0, reason: 'pinch must not append album');

      await g1.up();
      await g2.up();
      await tester.pump();
      await tester.pump(
        kCap20VideoReleaseToFitDuration + const Duration(milliseconds: 20),
      );
      await tester.pumpAndSettle();
      expect(container.read(browseMagnificationProvider).transientPinchActive, isFalse);
      expect(mutations.addCalls, 0, reason: 'release→fit must not append');

      final swipe = await tester.startGesture(tester.getCenter(find.byType(PageView)));
      await swipe.moveBy(const Offset(-100, 4));
      await swipe.up();
      await _pumpFrames(tester, n: 15);

      expect(
        mutations.addCalls,
        1,
        reason: 'after video pinch ends, Cap19 left-swipe must still append',
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);

      await tester.pump(kCap19BrowseToastDuration);
      resetCap19BrowseToastForTest();
    },
  );

  testWidgets(
    'T-20.4-11 mid-pinch leave Browse clears transientPinchActive and unlocks',
    (tester) async {
      // Parallel to T-20.3-6: transientPinchActive must ride the same
      // clearBecauseLeftCurrentOrBrowse path (destination listen), not only
      // forceFit() called from tests. Fingers stay down — mid-pinch, not
      // release-animation (that is T-20.4-8).
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = _videoDisplay(const ['v1', 'v2']);
      final playback = FakePlaybackRepository();

      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(
            videosIds: const ['v1', 'v2'],
            availabilityById: const {
              'v1': AssetAvailability.deviceLocal,
              'v2': AssetAvailability.deviceLocal,
            },
          ),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await _pumpFrames(tester);
      final container = _containerOf(tester, find.byType(VerticalMediaFeed));
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await _pumpFrames(tester, n: 40);

      var armed = false;
      for (var i = 0; i < 40; i++) {
        if (container.read(magnificationHostModeProvider) ==
            MagnificationHostMode.transient) {
          armed = true;
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(armed, isTrue);

      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();

      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(container.read(browseMagnificationProvider).transientPinchActive, isTrue);
      expect(
        container.read(magnificationMatrixProvider).scale,
        greaterThan(1.5),
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isA<NeverScrollableScrollPhysics>(),
      );

      // Leave Browse while fingers are still down (no g1.up / g2.up yet).
      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        container.read(browseMagnificationProvider).transientPinchActive,
        isFalse,
        reason:
            'leave Browse must clear transientPinchActive via '
            'clearBecauseLeftCurrentOrBrowse (same path as still)',
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(
        container.read(magnificationMatrixProvider).scale,
        kCap20MinScale,
        reason: 'Host interrupt must snap Transform to identity',
      );
      expect(
        container.read(magnificationMatrixProvider).translation,
        Offset.zero,
      );

      final pageViews = find.byType(PageView, skipOffstage: false);
      expect(pageViews, findsOneWidget);
      expect(
        tester.widget<PageView>(pageViews).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
        reason: 'leave Browse must unlock PageView after clearing video pinch',
      );

      // Do not g1.up()/g2.up() after leave Browse: Cap19 left-swipe Listener
      // may already be offstage/unmounted under IndexedStack and would throw
      // on ref.read during pointer-up. Host interrupt already dropped the
      // pointer map; dangling downs are fine for this assertion.
    },
  );

  testWidgets(
    'T-20.4-iso apply:false neighbour Transform stays identity',
    (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackRepositoryProvider.overrideWithValue(FakePlaybackRepository()),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      StillMagnificationTransform(
                        apply: true,
                        child: const SizedBox(
                          key: Key('isoCurrent'),
                          width: 20,
                          height: 20,
                        ),
                      ),
                      StillMagnificationTransform(
                        apply: false,
                        child: const SizedBox(
                          key: Key('isoNeighbour'),
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      container.read(magnificationMatrixProvider.notifier).setMatrix(
        scale: 2.5,
        translation: const Offset(12, 0),
      );
      await tester.pump();

      final transforms = tester
          .widgetList<Transform>(
            find.byKey(const Key('stillMagnificationTransform')),
          )
          .toList();
      expect(transforms, hasLength(2));
      expect(transforms[0].transform.getMaxScaleOnAxis(), closeTo(2.5, 0.01));
      expect(transforms[1].transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    },
  );

  testWidgets(
    'T-20.4-L1 video poster arms transient mode and non-persistent pinch',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = _videoDisplay(const ['v1']);
      // Gate L2 so the page stays on still+video poster (L1).
      final playback = FakePlaybackRepository()
        ..loadGates['v1'] = Completer<void>();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _videosWithWakeTokAlbum(const ['v1']),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await _pumpFrames(tester);
      final container = _containerOf(tester, find.byType(VerticalMediaFeed));
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await _pumpFrames(tester, n: 40);

      var armed = false;
      for (var i = 0; i < 40; i++) {
        if (container.read(magnificationHostModeProvider) ==
            MagnificationHostMode.transient) {
          armed = true;
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(armed, isTrue, reason: 'Q5-B: L1 video poster arms video mode');

      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();

      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(container.read(browseMagnificationProvider).transientPinchActive, isTrue);
      expect(
        container.read(magnificationMatrixProvider).scale,
        greaterThan(1.5),
      );

      await g1.up();
      await g2.up();
      await tester.pump(kCap20VideoReleaseToFitDuration + const Duration(milliseconds: 20));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(container.read(browseMagnificationProvider).transientPinchActive, isFalse);
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
    },
  );

  testWidgets(
    'T-20.4-mode leave Browse clears magnificationHostMode',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = _videoDisplay(const ['v1']);
      final playback = FakePlaybackRepository();
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _videosWithWakeTokAlbum(const ['v1']),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await _pumpFrames(tester);
      final container = _containerOf(tester, find.byType(VerticalMediaFeed));
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.videos);
      await _pumpFrames(tester, n: 40);

      var armed = false;
      for (var i = 0; i < 40; i++) {
        if (container.read(magnificationHostModeProvider) ==
            MagnificationHostMode.transient) {
          armed = true;
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(armed, isTrue);

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      await tester.pump();
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.none,
      );
      expect(
        playback.calls.any(
          (c) => c == 'setDisplayMagnification:1.0:0.0:0.0',
        ),
        isTrue,
        reason: 'leave Browse must reset native surface magnification',
      );
    },
  );

  testWidgets(
    'T-20.4-binder inactive neighbour does not clearIf active host mode',
    (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackRepositoryProvider.overrideWithValue(
              FakePlaybackRepository(),
            ),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      MagnificationHostModeBinder(persistent: false, 
                        active: true,
                        child: SizedBox(height: 10),
                      ),
                      MagnificationHostModeBinder(persistent: false, 
                        active: false,
                        child: SizedBox(height: 10),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.transient,
      );

      // Drop the inactive neighbour — must not wipe mode (former clearIf race).
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackRepositoryProvider.overrideWithValue(
              FakePlaybackRepository(),
            ),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(
                home: Scaffold(
                  body: MagnificationHostModeBinder(persistent: false, 
                    active: true,
                    child: SizedBox(height: 10),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.transient,
      );
    },
  );

  testWidgets(
    'T-20.4-12 mid-pinch L1→L2 promote forceFits and rebaselines from current span',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final display = FakeMediaDisplayRepository();
      display.displayGates['a1'] = Completer<void>();
      display.displayGates['a2'] = Completer<void>();
      final playback = FakePlaybackRepository();

      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
          mediaDisplay: display,
          playback: playback,
        ),
      );
      await _pumpFrames(tester);
      final container = _containerOf(tester, find.byType(VerticalMediaFeed));
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.transient,
        reason: 'gated L2 keeps photo on L1 transient mode',
      );
      expect(
        container.read(nativeDisplayMagnificationPushProvider),
        isFalse,
        reason: 'photo L1 must not arm native AVPlayer magnification push',
      );

      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      // Initial span = 80.
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      // Spread to span = 200 (ratio 2.5 from start).
      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();
      final scaleOnL1 = container.read(magnificationMatrixProvider).scale;
      expect(scaleOnL1, greaterThan(1.5));
      expect(
        playback.calls.where((c) => c.startsWith('setDisplayMagnification:')),
        isEmpty,
        reason: 'photo L1 transient pinch must not push native magnification',
      );

      // L2 arrives mid-pinch (fingers still down).
      display.displayGates['a1']!.complete();
      var promoted = false;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (container.read(magnificationHostModeProvider) ==
            MagnificationHostMode.still) {
          promoted = true;
          break;
        }
      }
      expect(promoted, isTrue, reason: 'L2 full must arm persistent still mode');
      expect(
        container.read(magnificationMatrixProvider).scale,
        kCap20MinScale,
        reason: 'promote must forceFit — not carry L1 scale into L2',
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isTrue,
        reason: 'option A: pointers kept → still contact stays armed',
      );

      // Rebaseline check: current span is 200. Grow to 300 (×1.5).
      // Scale must track the *new* baseline (~1.5), not L1_scale×1.5.
      await g1.moveBy(const Offset(-50, 0));
      await g2.moveBy(const Offset(50, 0));
      await tester.pump();
      final scaleAfter = container.read(magnificationMatrixProvider).scale;
      expect(
        scaleAfter,
        closeTo(1.5, 0.25),
        reason:
            'post-promote pinch must use current finger span as baseline, '
            'not a stale L1 baseline (would jump near ${scaleOnL1 * 1.5})',
      );
      expect(scaleAfter, isNot(closeTo(scaleOnL1 * 1.5, 0.35)));
      expect(
        container.read(browseStillMagnifiedProvider),
        isTrue,
        reason: 'continued pinch after promote uses persistent still path',
      );

      await g1.up();
      await g2.up();
      await tester.pump();
      expect(container.read(browseStillMagnifiedProvider), isTrue);
      expect(find.byKey(const Key('magnificationResetButton')), findsOneWidget);
    },
  );
}
