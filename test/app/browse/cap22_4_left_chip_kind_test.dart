import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_chrome_state.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';

SourcePoolDefinition _eph() {
  return SourcePoolDefinition(
    id: 'eph',
    persistencePolicy: PersistencePolicy.ephemeral,
    orderedSourceReferences: const [SourceReference.photos],
  );
}

SavedPoolRecord _record({String id = 'p1', String name = 'Trip'}) {
  final at = DateTime.utc(2026, 1, 1);
  return SavedPoolRecord(
    id: id,
    displayName: name,
    createdAt: at,
    updatedAt: at,
    orderedSourceReferences: const [SourceReference.photos],
  );
}

void main() {
  group('U-22.4 leftChipKindFor', () {
    final parked = _eph();

    test('builtIn + no park → hidden', () {
      expect(
        leftChipKindFor(
          origin: const BrowseOriginBuiltIn(SourceReference.all),
          parked: null,
        ),
        BrowseLeftChipKind.hidden,
      );
    });

    test('builtIn + park → tempPool', () {
      expect(
        leftChipKindFor(
          origin: const BrowseOriginBuiltIn(SourceReference.all),
          parked: parked,
        ),
        BrowseLeftChipKind.tempPool,
      );
    });

    test('ephemeral + matching park → tempPool', () {
      expect(
        leftChipKindFor(
          origin: BrowseOriginEphemeralPool(parked),
          parked: parked,
        ),
        BrowseLeftChipKind.tempPool,
      );
    });

    test('savedPool owns chip even when park is set', () {
      final record = _record();
      expect(
        leftChipKindFor(
          origin: BrowseOriginSavedPool(
            poolId: record.id,
            definition: record.toDefinition(),
          ),
          parked: parked,
        ),
        BrowseLeftChipKind.savedPool,
      );
    });

    test('savedPool + no park → savedPool', () {
      final record = _record();
      expect(
        leftChipKindFor(
          origin: BrowseOriginSavedPool(
            poolId: record.id,
            definition: record.toDefinition(),
          ),
          parked: null,
        ),
        BrowseLeftChipKind.savedPool,
      );
    });
  });

  group('U-22.4 openSavedPool vs startSavedPool', () {
    test('openSavedPool preserves park', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final parked = _eph();
      container
          .read(browseChromeStateProvider.notifier)
          .startEphemeralPool(parked, compositionLabels: const ['Photos']);
      container
          .read(browseChromeStateProvider.notifier)
          .openSavedPool(_record());
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.activeOrigin, isA<BrowseOriginSavedPool>());
      expect(chrome.parkedEphemeralPool, parked);
      expect(chrome.parkedCompositionLabels, ['Photos']);
      expect(
        leftChipKindFor(
          origin: chrome.activeOrigin,
          parked: chrome.parkedEphemeralPool,
        ),
        BrowseLeftChipKind.savedPool,
      );
    });

    test('startSavedPool still clears park', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(browseChromeStateProvider.notifier)
          .startEphemeralPool(_eph());
      container
          .read(browseChromeStateProvider.notifier)
          .startSavedPool(_record());
      final chrome = container.read(browseChromeStateProvider);
      expect(chrome.parkedEphemeralPool, isNull);
      expect(chrome.parkedCompositionLabels, isNull);
    });
  });
}
