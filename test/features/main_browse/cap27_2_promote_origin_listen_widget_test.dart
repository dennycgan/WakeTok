import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';
import 'package:waketok/features/main_browse/vertical_media_feed.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../authorization/permission_ui_test_harness.dart';

/// Cap 27.2: widget coverage for promote (no Session reload) vs tab
/// real-boundary (loading + PageView teardown).
void main() {
  testWidgets(
    'promote keeps feed index and never shows Session loading chrome',
    (tester) async {
      final sources = FakeAssetSourceRepository(
        photosIds: const ['p1', 'p2', 'p3', 'p4'],
        videosIds: const ['v1'],
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);

      container.read(browseChromeStateProvider.notifier).startEphemeralPool(
        SourcePoolDefinition(
          id: 'eph-widget-promote',
          persistencePolicy: PersistencePolicy.ephemeral,
          orderedSourceReferences: const [
            SourceReference.photos,
            SourceReference.videos,
          ],
        ),
      );
      await container.read(browseSessionProvider.future);
      await tester.pumpAndSettle();

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
      await tester.pumpAndSettle();
      expect(container.read(mainBrowseFeedIndexProvider), 2);
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byKey(const Key('mainBrowseFeedLoading')), findsNothing);

      final at = DateTime.utc(2026, 9, 19);
      container.read(browseSessionProvider.notifier).promoteCurrentSessionToSavedPool(
        SavedPoolRecord(
          id: 'saved-widget',
          displayName: 'Widget Saved',
          createdAt: at,
          updatedAt: at,
          orderedSourceReferences: const [
            SourceReference.photos,
            SourceReference.videos,
          ],
        ),
      );

      // Same-frame + a few frames: loading must never appear.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          find.byKey(const Key('mainBrowseFeedLoading')),
          findsNothing,
          reason: 'promote must not tear down PageView via Session loading',
        );
      }
      expect(container.read(mainBrowseFeedIndexProvider), 2);
      expect(find.byType(PageView), findsOneWidget);
      expect(
        container.read(browseChromeStateProvider).activeOrigin,
        isA<BrowseOriginSavedPool>(),
      );
    },
  );

  testWidgets(
    'tab selectBuiltIn shows Session loading and resets index to 0',
    (tester) async {
      Completer<void>? gate;
      final sources = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c'],
        photosIds: const ['p1', 'p2', 'p3'],
        beforeEachResolve: (callIndex) async {
          final g = gate;
          if (g != null) {
            await g.future;
          }
        },
      );
      final repo = ControllablePhotosAuthorizationRepository(PhotosAccess.full);
      await tester.pumpWidget(
        permissionUiHarness(repo: repo, assetSources: sources),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(VerticalMediaFeed));
      final container = ProviderScope.containerOf(element);
      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(2);
      await tester.pumpAndSettle();
      expect(container.read(mainBrowseFeedIndexProvider), 2);
      expect(find.byType(PageView), findsOneWidget);

      gate = Completer<void>();
      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.photos);
      await tester.pump();

      expect(
        find.byKey(const Key('mainBrowseFeedLoading')),
        findsOneWidget,
        reason: 'real Session boundary must show loading (PageView torn down)',
      );
      expect(find.byType(PageView), findsNothing);
      expect(container.read(mainBrowseFeedIndexProvider), 0);

      gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mainBrowseFeedLoading')), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      expect(container.read(mainBrowseFeedIndexProvider), 0);
      expect(
        container.read(browseChromeStateProvider).activeOrigin,
        const BrowseOriginBuiltIn(SourceReference.photos),
      );
    },
  );
}
