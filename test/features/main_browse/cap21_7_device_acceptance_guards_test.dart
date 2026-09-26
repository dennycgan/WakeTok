import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/l10n/app_localizations.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

SourcePoolDefinition _ephemeralDef() {
  return SourcePoolDefinition(
    id: 'park-21-7',
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: const [
      SourceReference.photos,
      SourceReference(
        kind: AssetSourceKind.album,
        id: 'album-21-7',
      ),
    ],
  );
}

void main() {
  group('U-21.7 device-acceptance guards', () {
    testWidgets(
      'U-21.7-C Leave Browse via bottom nav preserves Origin+park+labels '
      '(ADR-044 D6.3)',
      (tester) async {
        final fake = FakeAssetSourceRepository(
          allIds: const ['a1'],
          photosIds: const ['p1'],
        );
        final repo =
            ControllablePhotosAuthorizationRepository(PhotosAccess.full);
        await tester.pumpWidget(
          permissionUiHarness(repo: repo, assetSources: fake),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final def = _ephemeralDef();
        const labels = <String>['Photos', 'Trip'];
        container.read(browseChromeStateProvider.notifier).startEphemeralPool(
              def,
              compositionLabels: labels,
            );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsOneWidget);
        final before = container.read(browseChromeStateProvider);
        expect(before.activeOrigin, BrowseOriginEphemeralPool(def));
        expect(before.parkedEphemeralPool, def);
        expect(before.parkedCompositionLabels, labels);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Production leave path: bottom-nav destination change (not a
        // hand-written chrome clear). Cap 28.4 keeps Session; chrome state
        // must still survive Settings round-trip (ADR-044 D6.3).
        await tester.tap(find.text(l10n.mainBrowseNavSettings));
        await tester.pumpAndSettle();
        expect(
          container.read(mainBrowseDestinationProvider),
          MainBrowseDestination.settings,
        );
        expect(find.text('${l10n.cap19SettingsGesturesSectionTitle}:'), findsOneWidget);

        // IndexedStack keeps Browse pane mounted offstage — assert chrome
        // state only while away (not chip Finder visibility).
        final mid = container.read(browseChromeStateProvider);
        expect(mid.activeOrigin, BrowseOriginEphemeralPool(def));
        expect(mid.parkedEphemeralPool, def);
        expect(mid.parkedCompositionLabels, labels);

        await tester.tap(find.text(l10n.mainBrowseNavBrowse));
        await tester.pumpAndSettle();
        expect(
          container.read(mainBrowseDestinationProvider),
          MainBrowseDestination.browse,
        );

        final after = container.read(browseChromeStateProvider);
        expect(after.activeOrigin, BrowseOriginEphemeralPool(def));
        expect(after.parkedEphemeralPool, def);
        expect(after.parkedCompositionLabels, labels);
        expect(find.byKey(const Key('mainBrowseTempPoolChip')), findsOneWidget);
      },
    );
  });
}
