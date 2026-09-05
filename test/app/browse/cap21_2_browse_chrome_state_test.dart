import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';

SourcePoolDefinition _ephemeralDef({
  required String id,
  required List<SourceReference> refs,
}) {
  return SourcePoolDefinition(
    id: id,
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: refs,
  );
}

void main() {
  group('U-21.2 BrowseChromeState / fingerprint', () {
    test('U-21.2-1 fingerprint: single ≡ legacy; order + dupes matter', () {
      expect(
        BrowseSnapshotCache.keyFor(SourceReference.all),
        'entireLibrary:all',
      );
      expect(
        BrowseSnapshotCache.keyForRefs([SourceReference.all]),
        BrowseSnapshotCache.keyFor(SourceReference.all),
      );
      final a = SourceReference(
        kind: AssetSourceKind.album,
        id: 'album-a',
      );
      final b = SourceReference(
        kind: AssetSourceKind.album,
        id: 'album-b',
      );
      expect(
        BrowseSnapshotCache.keyForRefs([a, b]),
        'album:album-a|album:album-b',
      );
      expect(
        BrowseSnapshotCache.keyForRefs([a, b]),
        isNot(BrowseSnapshotCache.keyForRefs([b, a])),
      );
      expect(
        BrowseSnapshotCache.keyForRefs([a, a]),
        'album:album-a|album:album-a',
      );
    });

    test('U-21.2-6 BrowseOrigin / BrowseChromeState equality + D6.1', () {
      expect(
        const BrowseOriginBuiltIn(SourceReference.all),
        const BrowseOriginBuiltIn(SourceReference.all),
      );
      expect(
        const BrowseOriginBuiltIn(SourceReference.all),
        isNot(const BrowseOriginBuiltIn(SourceReference.photos)),
      );
      final d1 = _ephemeralDef(
        id: 'e1',
        refs: const [SourceReference.photos],
      );
      final d1Same = _ephemeralDef(
        id: 'e1',
        refs: const [SourceReference.photos],
      );
      final d2 = _ephemeralDef(
        id: 'e2',
        refs: const [SourceReference.photos],
      );
      expect(
        BrowseOriginEphemeralPool(d1),
        BrowseOriginEphemeralPool(d1Same),
      );
      expect(
        BrowseOriginEphemeralPool(d1),
        isNot(BrowseOriginEphemeralPool(d2)),
      );
      const chrome = BrowseChromeState(
        activeOrigin: BrowseOriginBuiltIn(SourceReference.all),
        parkedEphemeralPool: null,
        lastRememberedBuiltIn: SourceReference.all,
      );
      expect(
        chrome,
        const BrowseChromeState(
          activeOrigin: BrowseOriginBuiltIn(SourceReference.all),
          parkedEphemeralPool: null,
          lastRememberedBuiltIn: SourceReference.all,
        ),
      );

      // D6.1: activeOrigin ephemeralPool(D) ⇒ parked shares D's identity.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(browseChromeStateProvider.notifier)
          .debugActivateEphemeralPool(d1);
      final activated = container.read(browseChromeStateProvider);
      expect(
        activated.activeOrigin,
        BrowseOriginEphemeralPool(d1),
      );
      expect(activated.parkedEphemeralPool, d1);
      expect(activated.parkedEphemeralPool, d1Same);
    });

    test('U-21.2-2 select Photos ⇒ builtIn Origin + new Session', () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['all-only'],
        photosIds: const ['ph-only'],
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) => () => Random(0),
          ),
          browseEmptyRetryDelaysProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      await container.read(browseSessionProvider.future);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.photos);
      final chrome = container.read(browseChromeStateProvider);
      expect(
        chrome.activeOrigin,
        const BrowseOriginBuiltIn(SourceReference.photos),
      );
      expect(
        container.read(mainBrowseSelectedSourceProvider),
        SourceReference.photos,
      );
      final photos = await container.read(browseSessionProvider.future);
      expect(photos.orderedAssetIds, ['ph-only']);
    });

    test('U-21.2-3 inject parked then select builtIn ⇒ parked preserved', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final parked = _ephemeralDef(
        id: 'parked-1',
        refs: const [SourceReference.videos],
      );
      container
          .read(browseChromeStateProvider.notifier)
          .debugSetParkedEphemeralPool(parked);
      expect(
        container.read(browseChromeStateProvider).parkedEphemeralPool,
        parked,
      );

      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.photos);
      final chrome = container.read(browseChromeStateProvider);
      expect(
        chrome.activeOrigin,
        const BrowseOriginBuiltIn(SourceReference.photos),
      );
      expect(chrome.parkedEphemeralPool, parked);
    });

    test('U-21.2-4 activeOrigin change clears L2-ready map', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(browseL2ReadySessionProvider);
      container.read(browseChromeStateProvider);

      container.read(browseL2ReadySessionProvider.notifier).record(
            const FeedL2ReadyEntry(
              assetIdentifier: 'asset-1',
              kind: FeedL2ReadyKind.stillFull,
            ),
          );
      expect(container.read(browseL2ReadySessionProvider), isNotEmpty);

      container
          .read(browseChromeStateProvider.notifier)
          .selectBuiltIn(SourceReference.videos);
      expect(container.read(browseL2ReadySessionProvider), isEmpty);
    });

    test('U-21.2-5 restartSession same Origin: reshuffle; cache hit', () async {
      final fake = FakeAssetSourceRepository(
        allIds: const ['a', 'b', 'c', 'd', 'e'],
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          browseShuffleRandomFactoryProvider.overrideWith(
            (ref) => () => Random(0),
          ),
          browseEmptyRetryDelaysProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(container.dispose);

      final first = await container.read(browseSessionProvider.future);
      expect(fake.resolveCalls, 1);
      final epoch1 = first.roundEpoch;

      await container.read(browseSessionProvider.notifier).restartSession();
      final second = container.read(browseSessionProvider).requireValue;
      expect(fake.resolveCalls, 1);
      expect(second.roundEpoch, greaterThan(epoch1));
      expect(
        container.read(browseChromeStateProvider).activeOrigin,
        const BrowseOriginBuiltIn(SourceReference.all),
      );
    });

    test('selectBuiltIn same source is no-op (no feed-index reset)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mainBrowseFeedIndexProvider.notifier).setIndex(3);
      container
          .read(mainBrowseSelectedSourceProvider.notifier)
          .select(SourceReference.all);
      expect(container.read(mainBrowseFeedIndexProvider), 3);
    });
  });
}
