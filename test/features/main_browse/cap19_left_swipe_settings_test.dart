import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/waketok_album_constants.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/features/main_browse/cap19_browse_toast.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_guide.dart';
import 'package:waketok/features/main_browse/cap19_left_swipe_session.dart';
import 'package:waketok/features/main_browse/main_browse_shell_page.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../domain/library/fake_waketok_album_store.dart';
import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_cap19_left_swipe_preferences.dart';
import '../authorization/permission_ui_test_harness.dart';

const _wakeTokAlbumId = 'waketok-album-1';

FakeAssetSourceRepository _sources({List<String> allIds = const ['asset-1']}) {
  return FakeAssetSourceRepository(
    allIds: allIds,
    availabilityById: FakeAssetSourceRepository.deviceLocalForIds(allIds),
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

Future<void> _openSettings(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.text(l10n.mainBrowseNavSettings));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('cap19GesturesSettingsSection')), findsOneWidget);
}

Future<void> _openBrowse(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  await tester.tap(find.text(l10n.mainBrowseNavBrowse));
  await tester.pumpAndSettle();
}

Future<void> _leftSwipe(WidgetTester tester) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(PageView)),
  );
  await gesture.moveBy(const Offset(-100, 4));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _settleToasts(WidgetTester tester) async {
  await tester.pump(kCap19BrowseToastDuration);
  resetCap19BrowseToastForTest();
}

void main() {
  setUp(Cap19LeftSwipeGuideSession.resetForTest);
  tearDown(() {
    resetCap19BrowseToastForTest();
    Cap19LeftSwipeGuideSession.resetForTest();
  });

  testWidgets('W-19.7-1 Settings master off blocks left-swipe append',
      (tester) async {
    final prefs = FakeCap19LeftSwipePreferences();
    final mutations = FakeAlbumMutationRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: _sources(),
        albumMutations: mutations,
        wakeTokAlbumStore: FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId,
        cap19LeftSwipePreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    await _openSettings(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
        matching: find.byType(CupertinoSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(prefs.leftSwipeAddEnabled, isFalse);

    await _openBrowse(tester);
    await _leftSwipe(tester);
    expect(mutations.addCalls, 0);
  });

  testWidgets('W-19.7-2 guide off still allows append when master on',
      (tester) async {
    final prefs = FakeCap19LeftSwipePreferences()
      ..leftSwipeAddEnabled = true
      ..leftSwipeGuideEnabled = false;
    final mutations = FakeAlbumMutationRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: _sources(),
        albumMutations: mutations,
        wakeTokAlbumStore: FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId,
        cap19LeftSwipePreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);

    await _leftSwipe(tester);
    expect(mutations.addCalls, 1);
    await _settleToasts(tester);
  });

  testWidgets(
    'W-19.7-3 master toggle syncs guide switch (UI + KV) and greys when off',
    (tester) async {
      final prefs = FakeCap19LeftSwipePreferences()
        ..leftSwipeAddEnabled = true
        ..leftSwipeGuideEnabled = true;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: _sources(),
          wakeTokAlbumStore: FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId,
          cap19LeftSwipePreferences: prefs,
        ),
      );
      await tester.pumpAndSettle();
      await _openSettings(tester);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
          matching: find.byType(CupertinoSwitch),
        ),
      );
      await tester.pumpAndSettle();
      expect(prefs.leftSwipeAddEnabled, isFalse);
      expect(prefs.leftSwipeGuideEnabled, isFalse);

      final guideSwitchOff = tester.widget<CupertinoSwitch>(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeGuideToggle')),
          matching: find.byType(CupertinoSwitch),
        ),
      );
      expect(guideSwitchOff.value, isFalse);
      expect(guideSwitchOff.onChanged, isNull);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
          matching: find.byType(CupertinoSwitch),
        ),
      );
      await tester.pumpAndSettle();
      expect(prefs.leftSwipeAddEnabled, isTrue);
      expect(prefs.leftSwipeGuideEnabled, isTrue);

      final guideSwitchOn = tester.widget<CupertinoSwitch>(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeGuideToggle')),
          matching: find.byType(CupertinoSwitch),
        ),
      );
      expect(guideSwitchOn.value, isTrue);
      expect(guideSwitchOn.onChanged, isNotNull);
    },
  );

  testWidgets('W-19.7-4 master off→on same session restores append',
      (tester) async {
    final prefs = FakeCap19LeftSwipePreferences()..leftSwipeAddEnabled = false;
    final mutations = FakeAlbumMutationRepository();
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: _sources(),
        albumMutations: mutations,
        wakeTokAlbumStore: FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId,
        cap19LeftSwipePreferences: prefs,
      ),
    );
    await tester.pumpAndSettle();

    await _leftSwipe(tester);
    expect(mutations.addCalls, 0);

    await _openSettings(tester);
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
        matching: find.byType(CupertinoSwitch),
      ),
    );
    await tester.pumpAndSettle();
    expect(prefs.leftSwipeAddEnabled, isTrue);

    await _openBrowse(tester);
    await _leftSwipe(tester);
    expect(mutations.addCalls, 1);
    await _settleToasts(tester);
  });

  testWidgets('W-19.7-5 already in album shows toast and skips add',
      (tester) async {
    final mutations = FakeAlbumMutationRepository()
      ..containedAssetIds.add('asset-1');
    await tester.pumpWidget(
      permissionUiHarness(
        repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
        assetSources: _sources(),
        albumMutations: mutations,
        wakeTokAlbumStore: FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId,
      ),
    );
    await tester.pumpAndSettle();

    await _leftSwipe(tester);
    expect(mutations.containsCalls, greaterThan(0));
    expect(mutations.addCalls, 0);
    expect(
      find.byKey(const Key('cap19LeftSwipeAlreadyInAlbumToast')),
      findsOneWidget,
    );
    await _settleToasts(tester);
  });

  testWidgets(
    'W-19.7-6 guide shown once does not reappear after master off→on',
    (tester) async {
      final prefs = FakeCap19LeftSwipePreferences()
        ..leftSwipeAddEnabled = true
        ..leftSwipeGuideEnabled = true;
      await tester.pumpWidget(
        permissionUiHarness(
          repo: ControllablePhotosAuthorizationRepository(PhotosAccess.full),
          assetSources: _sources(),
          wakeTokAlbumStore: FakeWakeTokAlbumStore()..albumId = _wakeTokAlbumId,
          cap19LeftSwipePreferences: prefs,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsOneWidget);
      await tester.pump(kCap19LeftSwipeGuideDuration);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
      expect(Cap19LeftSwipeGuideSession.guideShownThisLaunch, isTrue);

      await _openSettings(tester);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
          matching: find.byType(CupertinoSwitch),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('cap19SettingsLeftSwipeAddToggle')),
          matching: find.byType(CupertinoSwitch),
        ),
      );
      await tester.pumpAndSettle();
      expect(prefs.leftSwipeAddEnabled, isTrue);

      await _openBrowse(tester);
      expect(find.byKey(const Key('cap19LeftSwipeGuide')), findsNothing);
    },
  );
}
