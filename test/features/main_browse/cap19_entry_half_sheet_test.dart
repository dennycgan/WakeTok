import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

void main() {
  testWidgets('W-19.4-1 Full Browse shows cap19 entry icon', (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19EntryIcon')), findsOneWidget);
  });

  testWidgets('W-19.4-2 Limited Browse still shows cap19 entry icon',
      (tester) async {
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19EntryIcon')), findsOneWidget);
  });

  testWidgets('W-19.4-3 Settings destination hides cap19 entry icon',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.mainBrowseNavSettings));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19EntryIcon')), findsNothing);
  });

  testWidgets('W-19.4-4 tap entry icon opens cap19 actions half-sheet',
      (tester) async {
    final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
    await tester.pumpWidget(permissionUiHarness(repo: repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cap19EntryIcon')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
  });

  testWidgets(
    'W-19.4-5 Limited sheet shows D4 row without listAssetSources',
    (tester) async {
      final repo =
          ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
      final sources = FakeAssetSourceRepository(allIds: const ['a1']);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19PanelAddToAlbumLimitedRow')),
          findsOneWidget);
      expect(find.text(l10n.cap19PanelAddToAlbumLimitedMessage), findsOneWidget);
      expect(sources.listCalls, 0);

      await tester.tap(
        find.byKey(const Key('cap19PanelAddToAlbumLimitedRow')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19ActionsHalfSheet')), findsOneWidget);
      expect(sources.listCalls, 0);
    },
  );

  testWidgets(
    'W-19.4-6 Full sheet shows Add to Album placeholder without list',
    (tester) async {
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      final sources = FakeAssetSourceRepository(allIds: const ['a1']);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(sources.listCalls, 0);

      await tester.tap(find.byKey(const Key('cap19EntryIcon')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cap19PanelAddToAlbumFullRow')),
          findsOneWidget);
      expect(find.text(l10n.cap19PanelAddToAlbumFullPlaceholder),
          findsOneWidget);
      expect(sources.listCalls, 0);
    },
  );

  testWidgets('W-19.4-7 Limited Settings CTA calls openAppSettings',
      (tester) async {
    var opened = false;
    final repo =
        ControllablePhotosAuthorizationRepository(PhotosAccess.limited);
    await tester.pumpWidget(
      permissionUiHarness(
        repo: repo,
        openSettings: () async {
          opened = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cap19EntryIcon')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cap19PanelOpenSettings')));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
  });
}
