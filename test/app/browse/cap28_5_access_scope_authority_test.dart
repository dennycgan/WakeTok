import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/access_scope_authority.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/domain/library/library_totals.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';
import '../../library_smoke/fake_library_catalog_repository.dart';

class _FakePhotosAuthorizationRepository
    implements PhotosAuthorizationRepository {
  _FakePhotosAuthorizationRepository(this.status);

  PhotosAccess status;
  PhotosAccess requestResult = PhotosAccess.full;
  int presentCalls = 0;

  @override
  Future<PhotosAccess> currentStatus() async => status;

  @override
  Future<PhotosAccess> requestAccess() async {
    status = requestResult;
    return status;
  }

  @override
  Future<void> presentLimitedLibraryPicker() async {
    presentCalls += 1;
  }
}

ProviderContainer _container({
  required FakeAssetSourceRepository sources,
  PhotosAuthorizationRepository? auth,
  FakeLibraryCatalogRepository? catalog,
}) {
  return ProviderContainer(
    overrides: [
      assetSourceRepositoryProvider.overrideWithValue(sources),
      browseShuffleRandomFactoryProvider.overrideWithValue(() => Random(0)),
      browseEmptyRetryDelaysProvider.overrideWithValue(const <Duration>[]),
      if (auth != null)
        photosAuthorizationRepositoryProvider.overrideWithValue(auth),
      if (catalog != null)
        libraryCatalogRepositoryProvider.overrideWithValue(catalog),
    ],
  );
}

Future<void> _yieldUntil(bool Function() test) async {
  for (var i = 0; i < 200; i++) {
    if (test()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for condition');
}

void main() {
  test('W-28.5-1 Browse + notify → one restartSession; pending clear', () async {
    final sources = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
    final container = _container(sources: sources);
    addTearDown(container.dispose);

    final initial = await container.read(browseSessionProvider.future);
    final epochBefore = initial.roundEpoch;
    // Ensure authority listen is registered.
    expect(container.read(accessScopeAuthorityProvider), isNull);

    container
        .read(accessScopeAuthorityProvider.notifier)
        .notifyAccessScopePossiblyChanged();

    await _yieldUntil(
      () =>
          container.read(browseSessionProvider).asData?.value.roundEpoch ==
          epochBefore + 1,
    );
    expect(container.read(accessScopeAuthorityProvider), isNull);
  });

  test(
    'W-28.5-2 Settings + notify defers; select(browse) restarts once',
    () async {
      final sources = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
      final container = _container(sources: sources);
      addTearDown(container.dispose);

      final initial = await container.read(browseSessionProvider.future);
      final epochBefore = initial.roundEpoch;
      container.read(accessScopeAuthorityProvider);

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      container
          .read(accessScopeAuthorityProvider.notifier)
          .notifyAccessScopePossiblyChanged();

      await Future<void>.delayed(Duration.zero);
      expect(container.read(accessScopeAuthorityProvider), isNotNull);
      expect(
        container.read(browseSessionProvider).asData?.value.roundEpoch,
        epochBefore,
      );

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.browse);

      await _yieldUntil(
        () =>
            container.read(browseSessionProvider).asData?.value.roundEpoch ==
            epochBefore + 1,
      );
      expect(container.read(accessScopeAuthorityProvider), isNull);
    },
  );

  test(
    'W-28.5-3 Settings double notify → return Browse restarts once (coalesce)',
    () async {
      final sources = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
      final container = _container(sources: sources);
      addTearDown(container.dispose);

      final initial = await container.read(browseSessionProvider.future);
      final epochBefore = initial.roundEpoch;
      container.read(accessScopeAuthorityProvider);

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.settings);
      final authority = container.read(accessScopeAuthorityProvider.notifier);
      authority.notifyAccessScopePossiblyChanged();
      final gen = container.read(accessScopeAuthorityProvider);
      authority.notifyAccessScopePossiblyChanged();
      expect(container.read(accessScopeAuthorityProvider), gen);

      container
          .read(mainBrowseDestinationProvider.notifier)
          .select(MainBrowseDestination.browse);

      await _yieldUntil(
        () =>
            container.read(browseSessionProvider).asData?.value.roundEpoch ==
            epochBefore + 1,
      );
      expect(container.read(accessScopeAuthorityProvider), isNull);
      // No second restart queued after settle.
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(browseSessionProvider).asData?.value.roundEpoch,
        epochBefore + 1,
      );
    },
  );

  test(
    'W-28.5-4 requestAccess grant-complete via notify; session loads '
    '(cold-start first Session still works)',
    () async {
      final fake = _FakePhotosAuthorizationRepository(
        PhotosAccess.notDetermined,
      );
      fake.requestResult = PhotosAccess.limited;
      final sources = FakeAssetSourceRepository(allIds: const ['a', 'b', 'c']);
      final container = _container(sources: sources, auth: fake);
      addTearDown(container.dispose);

      await container.read(photosAuthorizationProvider.future);
      // Destination defaults to browse (PermissionRequestPage class cold start).
      expect(
        container.read(mainBrowseDestinationProvider),
        MainBrowseDestination.browse,
      );

      await container
          .read(photosAuthorizationProvider.notifier)
          .requestAccess();
      expect(
        container.read(photosAuthorizationProvider).value,
        PhotosAccess.limited,
      );

      await _yieldUntil(
        () =>
            container.read(browseSessionProvider).hasValue &&
            (container.read(browseSessionProvider).asData!.value.orderedAssetIds
                .isNotEmpty) &&
            container.read(accessScopeAuthorityProvider) == null,
      );
      final view = container.read(browseSessionProvider).asData!.value;
      expect(view.orderedAssetIds, isNotEmpty);
      expect(sources.resolveCalls, greaterThan(0));
      // First successful Session exists after grant-complete consume (epoch ≥ 1).
      expect(view.roundEpoch, greaterThanOrEqualTo(1));
    },
  );

  test(
    'W-28.5-5 presentLimitedLibraryPicker dismiss marks dirty / consumes on Browse',
    () async {
      final fake = _FakePhotosAuthorizationRepository(PhotosAccess.limited);
      final catalog = FakeLibraryCatalogRepository(
        totalsValue: const LibraryTotals(all: 1, photos: 1, videos: 0),
      );
      final sources = FakeAssetSourceRepository(allIds: const ['a', 'b']);
      final container = _container(
        sources: sources,
        auth: fake,
        catalog: catalog,
      );
      addTearDown(container.dispose);

      await container.read(photosAuthorizationProvider.future);
      final initial = await container.read(browseSessionProvider.future);
      final epochBefore = initial.roundEpoch;
      await container.read(libraryTotalsProvider.future);
      final totalsBefore = catalog.totalsCalls;

      await container
          .read(photosAuthorizationProvider.notifier)
          .presentLimitedLibraryPicker();
      expect(fake.presentCalls, 1);

      await _yieldUntil(
        () =>
            container.read(browseSessionProvider).asData?.value.roundEpoch ==
            epochBefore + 1,
      );
      expect(container.read(accessScopeAuthorityProvider), isNull);
      await container.read(libraryTotalsProvider.future);
      expect(catalog.totalsCalls, greaterThan(totalsBefore));
    },
  );

  test(
    'W-28.5-6 Browse restart in-flight + notify → second restart after (D2)',
    () async {
      final gate = Completer<void>();
      var resolveIndex = 0;
      final sources = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c'],
        beforeEachResolve: (callIndex) async {
          resolveIndex = callIndex;
          // Block the first post-clear resolve (access-scope restart).
          // callIndex is 0-based; initial build is 0.
          if (callIndex == 1 && !gate.isCompleted) {
            await gate.future;
          }
        },
      );
      final container = _container(sources: sources);
      addTearDown(container.dispose);

      final initial = await container.read(browseSessionProvider.future);
      final epochBefore = initial.roundEpoch;
      expect(sources.resolveCalls, 1);

      // Force the next restartSession off cache so beforeEachResolve can gate.
      container.read(browseSnapshotCacheProvider.notifier).clear();

      container
          .read(accessScopeAuthorityProvider.notifier)
          .notifyAccessScopePossiblyChanged();

      await _yieldUntil(() => resolveIndex >= 1);
      // restartSession has entered AsyncLoading — epoch not advanced yet.
      expect(container.read(browseSessionProvider).isLoading, isTrue);
      expect(
        container.read(browseSessionProvider).asData?.value.roundEpoch,
        isNull,
      );

      // Second notify while first restart still blocked.
      container
          .read(accessScopeAuthorityProvider.notifier)
          .notifyAccessScopePossiblyChanged();
      expect(container.read(accessScopeAuthorityProvider), isNotNull);

      gate.complete();

      await _yieldUntil(
        () =>
            container.read(browseSessionProvider).asData?.value.roundEpoch ==
            epochBefore + 2,
      );
      expect(container.read(accessScopeAuthorityProvider), isNull);
    },
  );
}
