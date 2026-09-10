import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/cap19_entry_icon.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/pv_transition_guard.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

Finder _entryIconOpacity() {
  return find.ancestor(
    of: find.byKey(const Key('cap19EntryIcon')),
    matching: find.byType(Opacity),
  );
}

class _SettledFalse extends MainBrowseVerticalFeedSettled {
  @override
  bool build() => false;
}

/// Idle guard — no Host subscriptions (isolated entry chrome tests).
class _IdleGuard extends PvTransitionGuardNotifier {
  @override
  PvTransitionGuardState build() => const PvTransitionGuardState();
}

/// Fixed covering state without Host ready-for-display subscriptions.
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

Widget _isolatedEntry(
  List overrides, {
  bool includeIdleGuard = true,
}) {
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
      home: Scaffold(
        body: Stack(
          children: [
            Cap19EntryIcon(access: PhotosAccess.full),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'T-19.8-entry empty session disables icon (opacity + no half-sheet)',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final sources = FakeAssetSourceRepository(allIds: const []);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();

      final inkWell = tester.widget<InkWell>(
        find.byKey(const Key('cap19EntryIcon')),
      );
      expect(inkWell.onTap, isNull);
      expect(
        tester.widget<Opacity>(_entryIconOpacity()).opacity,
        kCap19EntryIconDisabledOpacity,
      );

      await tester.tap(
        find.byKey(const Key('cap19EntryIcon')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsNothing);
    },
  );

  testWidgets(
    'T-19.8-entry actionable session enables icon and opens half-sheet',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final sources = FakeAssetSourceRepository(allIds: const ['a1'], availabilityById: FakeAssetSourceRepository.deviceLocalForIds(const ['a1']));
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();

      final inkWell = tester.widget<InkWell>(
        find.byKey(const Key('cap19EntryIcon')),
      );
      expect(inkWell.onTap, isNotNull);
      expect(tester.widget<Opacity>(_entryIconOpacity()).opacity, 1.0);

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
      expect(find.text(l10n.cap19PanelAddToAlbumTitle), findsOneWidget);
    },
  );

  testWidgets(
    'T-19.8-chrome B2 peek only: fully gone (not Decision 7 dim)',
    (tester) async {
      await tester.pumpWidget(
        _isolatedEntry([
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
          mainBrowseVerticalFeedSettledProvider.overrideWith(
            _SettledFalse.new,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19EntryIcon')), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    },
  );

  testWidgets(
    'T-19.8-chrome B3 covering only: fully gone (not Decision 7 dim)',
    (tester) async {
      await tester.pumpWidget(
        _isolatedEntry(
          [
            mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
            pvTransitionGuardProvider.overrideWith(_CoveringA1Guard.new),
          ],
          includeIdleGuard: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19EntryIcon')), findsNothing);
      expect(find.byType(Opacity), findsNothing);
    },
  );

  testWidgets(
    'T-19.8-chrome B4 not-actionable only: visible + dim (Decision 7)',
    (tester) async {
      await tester.pumpWidget(
        _isolatedEntry([
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => null),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19EntryIcon')), findsOneWidget);
      final inkWell = tester.widget<InkWell>(
        find.byKey(const Key('cap19EntryIcon')),
      );
      expect(inkWell.onTap, isNull);
      expect(
        tester.widget<Opacity>(_entryIconOpacity()).opacity,
        kCap19EntryIconDisabledOpacity,
      );
    },
  );

  test('T-19.8-chrome C settled provider edge write', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(mainBrowseVerticalFeedSettledProvider), isTrue);
    container
        .read(mainBrowseVerticalFeedSettledProvider.notifier)
        .setSettled(false);
    expect(container.read(mainBrowseVerticalFeedSettledProvider), isFalse);
    container
        .read(mainBrowseVerticalFeedSettledProvider.notifier)
        .setSettled(true);
    expect(container.read(mainBrowseVerticalFeedSettledProvider), isTrue);
  });
}
