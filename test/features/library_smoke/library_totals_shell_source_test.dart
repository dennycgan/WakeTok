import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/theme/waketok_theme.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/library_asset.dart';
import 'package:waketok/domain/library/library_media_kind.dart';
import 'package:waketok/domain/library/library_page.dart';
import 'package:waketok/domain/library/library_totals.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/library_smoke/library_totals_shell_page.dart';
import 'package:waketok/features/library_smoke/playback_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_library_catalog_repository.dart';
import '../../library_smoke/fake_media_display_repository.dart';
import '../../library_smoke/fake_playback_repository.dart';

Widget _harness({
  required FakeAssetSourceRepository sources,
  required FakeLibraryCatalogRepository catalog,
}) {
  return ProviderScope(
    overrides: [
      assetSourceRepositoryProvider.overrideWithValue(sources),
      libraryCatalogRepositoryProvider.overrideWithValue(catalog),
      mediaDisplayRepositoryProvider.overrideWithValue(
        FakeMediaDisplayRepository(),
      ),
      playbackRepositoryProvider.overrideWithValue(FakePlaybackRepository()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: waketokTheme(Brightness.light),
      home: const LibraryTotalsShellPage(access: PhotosAccess.full),
    ),
  );
}

void main() {
  testWidgets('W-S1 segmented labels come from AppLocalizations',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1', 'a2'],
      photosIds: const ['p1'],
      videosIds: const ['v1'],
    );
    final catalog = FakeLibraryCatalogRepository(
      totalsValue: const LibraryTotals(all: 2, photos: 1, videos: 1),
    );

    await tester.pumpWidget(_harness(sources: sources, catalog: catalog));
    await tester.pumpAndSettle();

    expect(find.text(l10n.sourceSmokeSectionTitle), findsOneWidget);
    // Segmented + totals rows both use libraryRow* — at least one each.
    expect(find.text(l10n.libraryRowAll), findsWidgets);
    expect(find.text(l10n.libraryRowPhotos), findsWidgets);
    expect(find.text(l10n.libraryRowVideos), findsWidgets);

    // estimatedCount is near the top; assert before scrolling the long ListView
    // (Cap 9.6 shared-mute section + probe push off-screen items out of cache).
    await tester.tap(find.text(l10n.libraryRowPhotos).last);
    await tester.pumpAndSettle();
    expect(find.text(l10n.sourceEstimatedCount(1)), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(l10n.sourceProbeIllegalPairButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.sourceProbeIllegalPairButton), findsOneWidget);
  });

  testWidgets('W-S2 resolve shows length and match vs totals', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final sources = FakeAssetSourceRepository(
      allIds: const ['a1', 'a2', 'a3'],
      photosIds: const ['p1'],
      videosIds: const ['v1', 'v2'],
    );
    final catalog = FakeLibraryCatalogRepository(
      totalsValue: const LibraryTotals(all: 3, photos: 1, videos: 2),
    );

    await tester.pumpWidget(_harness(sources: sources, catalog: catalog));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.sourceResolveButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.sourceResolvedLength(3)), findsOneWidget);
    expect(find.text(l10n.sourceCountMatch), findsOneWidget);
    expect(sources.resolveCalls, 1);
  });

  testWidgets(
      'W-S3 illegal pair shows ARB sourcePairMismatchError, not AppError name',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final sources = FakeAssetSourceRepository();
    final catalog = FakeLibraryCatalogRepository();

    await tester.pumpWidget(_harness(sources: sources, catalog: catalog));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(l10n.sourceProbeIllegalPairButton),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.sourceProbeIllegalPairButton));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sourcePairProbeMessage')), findsOneWidget);
    expect(find.text(l10n.sourcePairMismatchError), findsOneWidget);
    expect(find.textContaining('assetUnavailable'), findsNothing);
    expect(find.textContaining('AppError'), findsNothing);
  });

  testWidgets('W-S4 All quantile shows align OK for matching fake catalog',
      (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    const ids = ['id0', 'id1', 'id2', 'id3'];
    final sources = FakeAssetSourceRepository(allIds: ids);
    final pages = <LibraryPage>[
      for (var i = 0; i < ids.length; i++)
        LibraryPage(
          assets: [
            LibraryAsset(
              id: ids[i],
              kind: LibraryMediaKind.image,
              availability: AssetAvailability.deviceLocal,
              createdAt: DateTime.utc(2020 + i),
            ),
          ],
        ),
    ];
    final catalog = FakeLibraryCatalogRepository(
      totalsValue: const LibraryTotals(all: 4, photos: 4, videos: 0),
      pages: pages,
    );

    await tester.pumpWidget(_harness(sources: sources, catalog: catalog));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.sourceQuantileRunButton));
    await tester.pumpAndSettle();

    expect(find.textContaining(l10n.sourceQuantileAlignOk), findsWidgets);
    expect(find.textContaining(l10n.sourceQuantileAlignFail), findsNothing);
  });
}
