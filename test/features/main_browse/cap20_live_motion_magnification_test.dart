import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/features/main_browse/browse_magnification.dart';
import 'package:waketok/features/main_browse/magnification_surface.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

ProviderContainer _containerOf(WidgetTester tester, Finder finder) {
  return ProviderScope.containerOf(tester.element(finder));
}

/// Still-armed Host (persistent path) for Cap 20.5 Live-window isolation.
Widget _stillHostHarness({FakePlaybackRepository? playback}) {
  final fake = playback ?? FakePlaybackRepository();
  return ProviderScope(
    overrides: [
      playbackRepositoryProvider.overrideWithValue(fake),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.dark),
      home: Scaffold(
        body: MagnificationPointerHost(
          child: StillMagnificationActiveBinder(
            active: true,
            child: StillMagnificationTransform(
              apply: true,
              child: const SizedBox.expand(
                child: ColoredBox(color: Color(0xFF101010)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpFeed(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets(
    'T-20.5-1 mode none: two-finger spread does not magnify or arm contact',
    (tester) async {
      await tester.pumpWidget(_stillHostHarness());
      await tester.pumpAndSettle();
      final container = _containerOf(
        tester,
        find.byKey(const Key('magnificationPointerHost')),
      );
      container
          .read(magnificationHostModeProvider.notifier)
          .setMode(MagnificationHostMode.none);
      await tester.pump();

      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await g1.moveBy(const Offset(-60, 0));
      await g2.moveBy(const Offset(60, 0));
      await tester.pump();

      expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isFalse,
      );
      expect(
        container.read(browseMagnificationProvider).transientPinchActive,
        isFalse,
      );
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isFalse,
        reason: 'mode none must not arm PageView lock from finger count alone',
      );

      await g1.up();
      await g2.up();
    },
  );

  testWidgets(
    'T-20.5-1b mode none: two fingers down still allow PageView paging',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const ['a1', 'a2']),
        ),
      );
      await _pumpFeed(tester);
      final container = _containerOf(tester, find.byType(VerticalMediaFeed));
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      // Simulate Live motion window: Host disarmed.
      container
          .read(magnificationHostModeProvider.notifier)
          .setMode(MagnificationHostMode.none);
      await tester.pump();

      final host = find.byKey(const Key('magnificationPointerHost'));
      final center = tester.getCenter(host);
      final g1 = await tester.startGesture(center + const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final g2 = await tester.startGesture(center + const Offset(30, 0));
      await tester.pump();
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isFalse,
      );
      expect(
        tester.widget<PageView>(find.byType(PageView)).physics,
        isNot(isA<NeverScrollableScrollPhysics>()),
      );

      // Vertical drag with fingers still conceptually present on host —
      // PageView itself must still accept a separate drag (lift first so
      // gesture arena is free, then page — proves physics unlocked).
      await g1.up();
      await g2.up();
      await tester.pump();
      await tester.drag(find.byType(PageView), const Offset(0, -280));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        container.read(mainBrowseFeedIndexProvider),
        1,
        reason: 'after mode-none two-finger contact, PageView must still page',
      );
    },
  );

  testWidgets(
    'T-20.5-2 mid still-pinch Live rising edge: Host forceFits via mode none',
    (tester) async {
      await tester.pumpWidget(_stillHostHarness());
      await tester.pumpAndSettle();
      final container = _containerOf(
        tester,
        find.byKey(const Key('magnificationPointerHost')),
      );
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.still,
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
      expect(
        container.read(magnificationMatrixProvider).scale,
        greaterThan(1.5),
      );
      expect(container.read(browseStillMagnifiedProvider), isTrue);

      // Live PV mount path: rising-edge notifier + Host mode none.
      container.read(browseMagnificationProvider.notifier).onLiveMotionMountedChanged(
        true,
      );
      container
          .read(magnificationHostModeProvider.notifier)
          .setMode(MagnificationHostMode.none);
      await tester.pump();

      expect(container.read(browseStillMagnifiedProvider), isFalse);
      expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isFalse,
      );
      expect(
        container.read(browseMagnificationProvider).locksVerticalPageView,
        isFalse,
      );

      // Zombie moves: fingers never lifted — must not re-arm or zoom.
      await g1.moveBy(const Offset(-40, 0));
      await g2.moveBy(const Offset(40, 0));
      await tester.pump();
      expect(container.read(magnificationMatrixProvider).scale, kCap20MinScale);
      expect(
        container.read(browseMagnificationProvider).stillPinchContact,
        isFalse,
      );
      expect(container.read(browseStillMagnifiedProvider), isFalse);

      await g1.up();
      await g2.up();
      await tester.pump();

      // Fresh down after lift can arm again only once mode is re-armed.
      container
          .read(magnificationHostModeProvider.notifier)
          .setMode(MagnificationHostMode.still);
      container
          .read(browseMagnificationProvider.notifier)
          .onLiveMotionMountedChanged(false);
      await tester.pump();
      final n1 = await tester.startGesture(center + const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final n2 = await tester.startGesture(center + const Offset(40, 0));
      await tester.pump();
      await n1.moveBy(const Offset(-60, 0));
      await n2.moveBy(const Offset(60, 0));
      await tester.pump();
      expect(
        container.read(magnificationMatrixProvider).scale,
        greaterThan(1.5),
        reason: 'after up+re-arm, new pinch must work again',
      );
      await n1.up();
      await n2.up();
    },
  );

  testWidgets(
    'T-20.5-3 falling edge re-arms still binder mode after Live unload',
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
                theme: waketokTheme(Brightness.dark),
                home: Scaffold(
                  body: MagnificationPointerHost(
                    child: _LiveWindowBinderProbe(),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(); // post-frame setMode(still)
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.still,
      );

      // Mount Live window.
      final probe = tester.state<_LiveWindowBinderProbeState>(
        find.byType(_LiveWindowBinderProbe),
      );
      probe.setLiveMounted(true);
      await tester.pump();
      await tester.pump();
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.none,
      );

      // Unload — binder active again must set still.
      probe.setLiveMounted(false);
      await tester.pump();
      await tester.pump();
      expect(
        container.read(magnificationHostModeProvider),
        MagnificationHostMode.still,
        reason: 'falling edge must re-arm StillMagnificationActiveBinder',
      );
    },
  );

  test('T-20.5-4 rising edge forceFits transient pinch flags', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final mag = container.read(browseMagnificationProvider.notifier);
    mag.setTransientPinchActive(true);
    mag.onLiveMotionMountedChanged(true);
    expect(
      container.read(browseMagnificationProvider).transientPinchActive,
      isFalse,
    );
  });
}

/// Mirrors feed wiring: binder active iff !liveMounted; mode none on rise.
class _LiveWindowBinderProbe extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LiveWindowBinderProbe> createState() =>
      _LiveWindowBinderProbeState();
}

class _LiveWindowBinderProbeState extends ConsumerState<_LiveWindowBinderProbe> {
  bool _liveMounted = false;

  void setLiveMounted(bool mounted) {
    setState(() => _liveMounted = mounted);
    if (mounted) {
      ref.read(magnificationHostModeProvider.notifier).setMode(
        MagnificationHostMode.none,
      );
      ref.read(browseMagnificationProvider.notifier).onLiveMotionMountedChanged(
        true,
      );
    } else {
      ref.read(browseMagnificationProvider.notifier).onLiveMotionMountedChanged(
        false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StillMagnificationActiveBinder(
      active: !_liveMounted,
      child: const SizedBox.expand(),
    );
  }
}
