import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap25_share_entry_icon.dart';
import 'package:waketok/features/main_browse/center_playback_affordance.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/media_chrome_layout.dart';
import 'package:waketok/features/main_browse/pv_transition_guard.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_share_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';
import 'still_cover_test_helpers.dart';

FakeAssetSourceRepository _localSources([String id = 'a1']) {
  return FakeAssetSourceRepository(
    allIds: [id],
    availabilityById: FakeAssetSourceRepository.deviceLocalForIds([id]),
  );
}

class _SettledFalse extends MainBrowseVerticalFeedSettled {
  @override
  bool build() => false;
}

class _IdleGuard extends PvTransitionGuardNotifier {
  @override
  PvTransitionGuardState build() => const PvTransitionGuardState();
}

class _CoveringA1Guard extends PvTransitionGuardNotifier {
  @override
  PvTransitionGuardState build() {
    return const PvTransitionGuardState(
      targetAssetId: 'a1',
      coverPosterPath: '/tmp/cover.jpg',
      targetFeedIndex: 0,
    );
  }
}

Widget _isolatedShare(List overrides, {bool includeIdleGuard = true}) {
  return ProviderScope(
    overrides: [
      if (includeIdleGuard)
        pvTransitionGuardProvider.overrideWith(_IdleGuard.new),
      ...overrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.dark),
      home: const Scaffold(
        body: Stack(
          children: [
            Cap25ShareEntryIcon(),
          ],
        ),
      ),
    ),
  );
}

void main() {
  tearDown(hideCap19BrowseToast);

  testWidgets(
    'W-25.3-1 … < Share < Album geometry (indices 0/1/2)',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: _localSources()),
      );
      await tester.pumpAndSettle();

      final tokens = waketokTheme(Brightness.dark).extension<WakeTokTokens>()!;
      final lowest = mainBrowseActionColumnLowestBottomInset(tokens);
      expect(
        actionColumnBottomInsetForIndex(1, lowest) - lowest,
        closeTo(kActionColumnHitSize + kActionColumnItemSpacing, 0.01),
      );
      expect(
        actionColumnBottomInsetForIndex(2, lowest) - lowest,
        closeTo(2 * (kActionColumnHitSize + kActionColumnItemSpacing), 0.01),
      );

      final more = tester.getRect(find.byKey(const Key('cap24MoreEntryIcon')));
      final share =
          tester.getRect(find.byKey(const Key('cap25ShareEntryIcon')));
      final album = tester.getRect(find.byKey(const Key('cap19EntryIcon')));

      expect(album.bottom, lessThan(share.bottom));
      expect(share.bottom, lessThan(more.bottom));
    },
  );

  testWidgets(
    'W-25.3-2 empty session dims Share (opacity + onTap null)',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: FakeAssetSourceRepository(allIds: const []),
        ),
      );
      await tester.pumpAndSettle();

      final shareOpacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('cap25ShareEntryIcon')),
          matching: find.byType(Opacity),
        ),
      );
      expect(shareOpacity.opacity, kCap25ShareEntryIconDisabledOpacity);
      expect(
        tester
            .widget<InkWell>(find.byKey(const Key('cap25ShareEntryIcon')))
            .onTap,
        isNull,
      );
    },
  );

  testWidgets(
    'W-25.3-3a peek: Share fully gone',
    (tester) async {
      await tester.pumpWidget(
        _isolatedShare([
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
          mainBrowseVerticalFeedSettledProvider.overrideWith(
            _SettledFalse.new,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap25ShareEntryIcon')), findsNothing);
    },
  );

  testWidgets(
    'W-25.3-3b covering: Share fully gone',
    (tester) async {
      await tester.pumpWidget(
        _isolatedShare(
          [
            mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
            pvTransitionGuardProvider.overrideWith(_CoveringA1Guard.new),
          ],
          includeIdleGuard: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap25ShareEntryIcon')), findsNothing);
    },
  );

  testWidgets(
    'W-25.3-4 Cap 23 missing: dialog; presentShareSheet 0; latch clears',
    (tester) async {
      final share = FakeAssetShareRepository();
      final sources = FakeAssetSourceRepository(
        allIds: const ['a1'],
        availabilityById:
            FakeAssetSourceRepository.deviceLocalForIds(const ['a1']),
      );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: sources,
          assetShare: share,
        ),
      );
      await tester.pumpAndSettle();

      sources.availabilityById['a1'] = AssetAvailability.unavailable;

      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap25ShareEntryIcon')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsOneWidget,
      );
      expect(share.callCount, 0);
      expect(find.byKey(const Key('cap25ShareFailedToast')), findsNothing);

      await tester.tap(
        find.byKey(const Key('stillInLibraryUnavailableDialogDismiss')),
      );
      await tester.pumpAndSettle();

      // Deny path uses try/finally → latch must clear; second tap re-probes.
      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap25ShareEntryIcon')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('stillInLibraryUnavailableDialog')),
        findsOneWidget,
      );
      expect(share.callCount, 0);
    },
  );

  testWidgets(
    'W-25.3-5 success: presentShareSheet once; no fail toast',
    (tester) async {
      final share = FakeAssetShareRepository();
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetShare: share,
        ),
      );
      await tester.pumpAndSettle();

      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap25ShareEntryIcon')));
      await tester.pumpAndSettle();

      expect(share.callCount, 1);
      expect(share.lastAssetId, 'a1');
      expect(find.byKey(const Key('cap25ShareFailedToast')), findsNothing);
    },
  );

  testWidgets(
    'W-25.3-6 Host throw: fail toast',
    (tester) async {
      final share = FakeAssetShareRepository()
        ..exception = PlatformException(
          code: AppError.assetUnavailable.name,
          message: 'share failed',
        );
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetShare: share,
        ),
      );
      await tester.pumpAndSettle();

      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap25ShareEntryIcon')));
      await tester.pumpAndSettle();

      expect(share.callCount, 1);
      expect(find.byKey(const Key('cap25ShareFailedToast')), findsOneWidget);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.cap25ShareFailed), findsOneWidget);
      hideCap19BrowseToast();
    },
  );

  testWidgets(
    'W-25.3-7 latch: second tap while hold → still one call',
    (tester) async {
      final hold = Completer<void>();
      final share = FakeAssetShareRepository()..hold = hold;
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(
          repo: repo,
          assetSources: _localSources(),
          assetShare: share,
        ),
      );
      await tester.pumpAndSettle();

      await ensureShellMediaCoverVisible(tester);
      await tester.tap(find.byKey(const Key('cap25ShareEntryIcon')));
      await tester.pump();
      expect(share.callCount, 1);

      await tester.tap(find.byKey(const Key('cap25ShareEntryIcon')));
      await tester.pump();
      expect(share.callCount, 1);

      hold.complete();
      await tester.pumpAndSettle();
      expect(share.callCount, 1);
    },
  );
}
