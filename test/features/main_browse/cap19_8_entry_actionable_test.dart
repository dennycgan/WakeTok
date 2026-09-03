import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/features/main_browse/cap19_entry_layout.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

Finder _entryIconOpacity() {
  return find.ancestor(
    of: find.byKey(const Key('cap19EntryIcon')),
    matching: find.byType(Opacity),
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
      final sources = FakeAssetSourceRepository(allIds: const ['a1']);
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
}
