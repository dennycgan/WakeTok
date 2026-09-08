import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';

void main() {
  group('U-22.3 BrowseOriginSavedPool', () {
    test('== / hashCode use poolId only, not definition', () {
      final older = SourcePoolDefinition(
        id: 'pool-1',
        displayName: 'Old name',
        persistencePolicy: PersistencePolicy.saved,
        orderedSourceReferences: const [SourceReference.photos],
      );
      final renamed = SourcePoolDefinition(
        id: 'pool-1',
        displayName: 'New name',
        persistencePolicy: PersistencePolicy.saved,
        orderedSourceReferences: const [SourceReference.photos],
      );
      expect(older, isNot(renamed));
      final a = BrowseOriginSavedPool(poolId: 'pool-1', definition: older);
      final b = BrowseOriginSavedPool(poolId: 'pool-1', definition: renamed);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(BrowseOriginSavedPool(poolId: 'pool-2', definition: older)),
      );
    });

    test('feedDataSourceId / kind / activeDefinition', () {
      final definition = SourcePoolDefinition(
        id: 'pool-1',
        displayName: 'Trip',
        persistencePolicy: PersistencePolicy.saved,
        orderedSourceReferences: const [SourceReference.photos],
      );
      final chrome = BrowseChromeState(
        activeOrigin: BrowseOriginSavedPool(
          poolId: 'pool-1',
          definition: definition,
        ),
        parkedEphemeralPool: null,
        lastRememberedBuiltIn: SourceReference.all,
      );
      expect(chrome.feedDataSourceId, 'saved:pool-1');
      expect(chrome.feedSourceKind, AssetSourceKind.entireLibrary);
      expect(
        chrome.activeDefinition(forBuiltIn: (_) => throw StateError('unused')),
        definition,
      );
    });

    test('startSavedPool activates saved origin and clears park', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final parked = SourcePoolDefinition(
        id: 'eph-1',
        persistencePolicy: PersistencePolicy.ephemeral,
        orderedSourceReferences: const [SourceReference.videos],
      );
      container
          .read(browseChromeStateProvider.notifier)
          .startEphemeralPool(parked, compositionLabels: const ['Videos']);
      expect(
        container.read(browseChromeStateProvider).parkedEphemeralPool,
        isNotNull,
      );

      final at = DateTime.utc(2026, 1, 1);
      final record = SavedPoolRecord(
        id: 'pool-1',
        displayName: 'Trip',
        createdAt: at,
        updatedAt: at,
        orderedSourceReferences: const [SourceReference.photos],
      );
      container.read(browseChromeStateProvider.notifier).startSavedPool(record);
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.activeOrigin, isA<BrowseOriginSavedPool>());
      expect((chrome.activeOrigin as BrowseOriginSavedPool).poolId, 'pool-1');
      expect(chrome.parkedEphemeralPool, isNull);
      expect(chrome.parkedCompositionLabels, isNull);
      expect(chrome.feedDataSourceId, 'saved:pool-1');
    });
  });
}
