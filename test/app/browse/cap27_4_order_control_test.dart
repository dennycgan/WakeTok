import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_l2_ready_session.dart';
import 'package:waketok/app/browse/browse_live_motion_watchdog.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/session/order_policy.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/order_control_half_sheet.dart';
import 'package:waketok/features/main_browse/order_control_panel_open.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../features/authorization/permission_ui_test_harness.dart';
import '../../library_smoke/fake_asset_source_repository.dart';

ProviderContainer _container({
  required FakeAssetSourceRepository fake,
}) {
  return ProviderContainer(
    overrides: [
      assetSourceRepositoryProvider.overrideWithValue(fake),
      browseShuffleRandomFactoryProvider.overrideWith((ref) => () => Random(0)),
      browseEmptyRetryDelaysProvider.overrideWithValue(const []),
      photosAuthorizationRepositoryProvider.overrideWithValue(
        ControllablePhotosAuthorizationRepository(PhotosAccess.full),
      ),
    ],
  );
}

void main() {
  group('Cap 27.4 applyConfirmedOrderPreference', () {
    test('CONFIRM-1 same-value shuffle (null pref) is no-op write', () async {
      final fake = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      final before = await container.read(browseSessionProvider.future);
      final applied = await container
          .read(browseSessionProvider.notifier)
          .applyConfirmedOrderPreference(OrderPolicy.shuffle);
      expect(applied, isFalse);
      expect(container.read(browseOrderPreferenceProvider), isNull);
      final after = container.read(browseSessionProvider).asData!.value;
      expect(after.roundEpoch, before.roundEpoch);
      expect(after.orderedAssetIds, before.orderedAssetIds);
    });

    test('CONFIRM-2 change to newest writes + rebuilds to index 0', () async {
      final fake = FakeAssetSourceRepository(allIds: const ['c', 'a', 'b']);
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      final before = await container.read(browseSessionProvider.future);
      final applied = await container
          .read(browseSessionProvider.notifier)
          .applyConfirmedOrderPreference(OrderPolicy.newestFirst);
      expect(applied, isTrue);
      expect(
        container.read(browseOrderPreferenceProvider),
        OrderPolicy.newestFirst,
      );
      final after = container.read(browseSessionProvider).asData!.value;
      expect(after.roundEpoch, greaterThan(before.roundEpoch));
      expect(after.session.queue.configuration.orderPolicy, OrderPolicy.newestFirst);
      expect(after.session.currentIndex, 0);
      expect(after.orderedAssetIds, ['c', 'a', 'b']);
    });

    test(
      'CONFIRM-3 keeps L2-ready + watchdog skip ids (not restartSession)',
      () async {
        final fake = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
        final container = _container(fake: fake);
        addTearDown(container.dispose);

        await container.read(browseSessionProvider.future);
        container.read(browseL2ReadySessionProvider.notifier).record(
              const FeedL2ReadyEntry(
                assetIdentifier: 'b',
                kind: FeedL2ReadyKind.stillFull,
              ),
            );
        container
            .read(browseLiveMotionWatchdogSkipIdsProvider.notifier)
            .add('a');

        await container
            .read(browseSessionProvider.notifier)
            .applyConfirmedOrderPreference(OrderPolicy.newestFirst);

        expect(
          container.read(browseL2ReadySessionProvider).containsKey('b'),
          isTrue,
        );
        expect(
          container
              .read(browseLiveMotionWatchdogSkipIdsProvider.notifier)
              .contains('a'),
          isTrue,
        );
      },
    );

    test('CONFIRM-4 order slot does not leave Browse / restart', () async {
      final fake = FakeAssetSourceRepository(allIds: const ['a', 'b']);
      final container = _container(fake: fake);
      addTearDown(container.dispose);

      final before = await container.read(browseSessionProvider.future);
      expect(
        container.read(mainBrowseDestinationProvider),
        MainBrowseDestination.browse,
      );
      // Opening the sheet only flips the panel flag — no select().
      container.read(orderControlPanelOpenProvider.notifier).setOpen(true);
      expect(
        container.read(mainBrowseDestinationProvider),
        MainBrowseDestination.browse,
      );
      final mid = container.read(browseSessionProvider).asData!.value;
      expect(mid.roundEpoch, before.roundEpoch);
      container.read(orderControlPanelOpenProvider.notifier).setOpen(false);
    });
  });

  group('Cap 27.4 order sheet UI', () {
    testWidgets('SHEET-1 barrier/drag cannot dismiss; Cancel closes', (
      tester,
    ) async {
      final fake = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final beforePref = container.read(browseOrderPreferenceProvider);
      final beforeEpoch =
          container.read(browseSessionProvider).asData!.value.roundEpoch;

      await tester.tap(find.byKey(const Key('mainBrowseOrderActionSlot')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('orderControlHalfSheet')), findsOneWidget);
      expect(container.read(orderControlPanelOpenProvider), isTrue);

      // Barrier tap must not dismiss (isDismissible: false).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('orderControlHalfSheet')), findsOneWidget);

      // Vertical drag on barrier must not dismiss / must not advance feed.
      final feedIndexBefore = container.read(mainBrowseFeedIndexProvider);
      await tester.dragFrom(const Offset(40, 80), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('orderControlHalfSheet')), findsOneWidget);
      expect(container.read(mainBrowseFeedIndexProvider), feedIndexBefore);

      await tester.tap(find.byKey(const Key('orderControlCancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('orderControlHalfSheet')), findsNothing);
      expect(container.read(browseOrderPreferenceProvider), beforePref);
      expect(
        container.read(browseSessionProvider).asData!.value.roundEpoch,
        beforeEpoch,
      );
    });

    testWidgets('SHEET-2 Confirm newest applies and dismisses without toast', (
      tester,
    ) async {
      final fake = FakeAssetSourceRepository(allIds: const ['c', 'a', 'b']);
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.byKey(const Key('mainBrowseOrderActionSlot')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.mainBrowseOrderSheetTitle), findsOneWidget);
      expect(find.text(l10n.mainBrowseOrderSheetNewest), findsOneWidget);
      await tester.tap(find.byKey(const Key('orderControlOption_newestFirst')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('orderControlConfirm')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('orderControlHalfSheet')), findsNothing);
      expect(find.text(l10n.mainBrowseOrderNewest), findsOneWidget);
      expect(
        container.read(browseOrderPreferenceProvider),
        OrderPolicy.newestFirst,
      );
      expect(container.read(mainBrowseFeedIndexProvider), 0);
      expect(
        container
            .read(browseSessionProvider)
            .asData!
            .value
            .session
            .queue
            .configuration
            .orderPolicy,
        OrderPolicy.newestFirst,
      );
      // No Cap 19 toast surface for Confirm.
      expect(find.text(l10n.mainBrowseNewRoundToast), findsNothing);
      expect(
        container.read(mainBrowseDestinationProvider),
        MainBrowseDestination.browse,
      );
    });

    testWidgets('COPY-1 SE width: New first + chevron has no overflow', (
      tester,
    ) async {
      final fake = FakeAssetSourceRepository(allIds: const ['a', 'b']);
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      // iPhone SE logical size (portrait).
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: fake),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container
          .read(browseOrderPreferenceProvider.notifier)
          .setPreference(OrderPolicy.newestFirst);
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.mainBrowseOrderNewest), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('COPY-2 large textScale: sheet options + buttons scrollable', (
      tester,
    ) async {
      // Isolate the sheet — full shell chrome overflows at 2× on SE (unrelated).
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(
            FakeAssetSourceRepository(allIds: const ['a', 'b']),
          ),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) => () => Random(0),
          ),
          browseEmptyRetryDelaysProvider.overrideWithValue(const []),
          photosAuthorizationRepositoryProvider.overrideWithValue(
            ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(browseSessionProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    final darkTheme = waketokTheme(Brightness.dark);
                    return Theme(
                      data: darkTheme,
                      child: const OrderControlHalfSheet(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.mainBrowseOrderSheetTitle), findsOneWidget);
      expect(find.text(l10n.mainBrowseOrderSheetNewest), findsOneWidget);
      expect(find.text(l10n.mainBrowseOrderSheetOldest), findsOneWidget);
      expect(
        find.byKey(const Key('orderControlOption_shuffle')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('orderControlConfirm')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byKey(const Key('orderControlConfirm')));
      await tester.ensureVisible(find.byKey(const Key('orderControlCancel')));
      expect(find.byKey(const Key('orderControlCancel')), findsOneWidget);
    });

    testWidgets(
        'W-31.4-S2 Confirm finishing during sheet exit keeps the page below', (
      tester,
    ) async {
      final gate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(
            FakeAssetSourceRepository(allIds: const ['a', 'b']),
          ),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) => () => Random(0),
          ),
          browseEmptyRetryDelaysProvider.overrideWithValue(const []),
          photosAuthorizationRepositoryProvider.overrideWithValue(
            ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          ),
          browseSessionProvider.overrideWith(
            () => _StallingBrowseSessionNotifier(gate),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(browseSessionProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    key: const Key('orderSheetTestOpen'),
                    onPressed: () => showOrderControlHalfSheet(context),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('orderSheetTestOpen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('orderControlOption_newestFirst')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('orderControlConfirm')));
      await tester.pump();
      // Cancel while Confirm is still applying.
      await tester.tap(find.byKey(const Key('orderControlCancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('orderControlHalfSheet')), findsNothing);
      expect(find.byKey(const Key('orderSheetTestOpen')), findsOneWidget);
    });
  });
}

class _StallingBrowseSessionNotifier extends BrowseSessionNotifier {
  _StallingBrowseSessionNotifier(this.gate);

  final Completer<void> gate;

  @override
  Future<bool> applyConfirmedOrderPreference(OrderPolicy confirmed) async {
    await gate.future;
    return super.applyConfirmedOrderPreference(confirmed);
  }
}
