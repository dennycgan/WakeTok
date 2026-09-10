import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../domain/source/fake_saved_pool_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('U-22.6 device-acceptance guards', () {
    testWidgets(
      'U-22.6-H Leave Browse via bottom nav preserves savedPool Origin+chip '
      '(ADR-044 D6.3 / Cap 22 Saved)',
      (tester) async {
        final pools = FakeSavedPoolRepository(createId: () => 'p-22-6');
        await pools.save(
          displayName: 'Trip 22.6',
          orderedSourceReferences: const [SourceReference.photos],
        );
        final fake = FakeAssetSourceRepository(photosIds: const ['p1']);
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(
            repo: repo,
            assetSources: fake,
            savedPools: pools,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('mainBrowseSavedPoolsMenu')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('mainBrowseSavedRow_p-22-6')));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final before = container.read(browseChromeStateProvider);
        expect(before.activeOrigin, isA<BrowseOriginSavedPool>());
        expect(
          (before.activeOrigin as BrowseOriginSavedPool).poolId,
          'p-22-6',
        );
        expect(before.feedDataSourceId, 'saved:p-22-6');
        expect(find.byKey(const Key('mainBrowseSavedPoolChip')), findsOneWidget);
        expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Production leave path: bottom-nav destination change (not a
        // hand-written chrome clear). IndexedStack keeps Browse mounted.
        await tester.tap(find.text(l10n.mainBrowseNavSettings));
        await tester.pumpAndSettle();
        expect(
          container.read(mainBrowseDestinationProvider),
          MainBrowseDestination.settings,
        );

        final mid = container.read(browseChromeStateProvider);
        expect(mid.activeOrigin, isA<BrowseOriginSavedPool>());
        expect((mid.activeOrigin as BrowseOriginSavedPool).poolId, 'p-22-6');
        expect(mid.feedDataSourceId, 'saved:p-22-6');

        await tester.tap(find.text(l10n.mainBrowseNavBrowse));
        await tester.pumpAndSettle();
        expect(
          container.read(mainBrowseDestinationProvider),
          MainBrowseDestination.browse,
        );

        final after = container.read(browseChromeStateProvider);
        expect(after.activeOrigin, isA<BrowseOriginSavedPool>());
        expect(
          (after.activeOrigin as BrowseOriginSavedPool).poolId,
          'p-22-6',
        );
        expect(after.feedDataSourceId, 'saved:p-22-6');
        expect(find.byKey(const Key('mainBrowseSavedPoolChip')), findsOneWidget);
        expect(find.text('Trip 22.6'), findsWidgets);
        expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsNothing);
      },
    );
  });
}
