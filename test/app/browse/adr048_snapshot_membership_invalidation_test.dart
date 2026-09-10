import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/app/browse/browse_session_providers.dart';
import 'package:waketok/app/browse/snapshot_invalidating_album_mutation_repository.dart';
import 'package:waketok/domain/library/album_mutation_repository.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/resolved_pool_snapshot.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/domain/source/source_resolve_status.dart';

ResolvedPoolSnapshot _snap(String id, List<String> assetIds) {
  return ResolvedPoolSnapshot(
    id: id,
    coalescedAssetIds: assetIds,
    sourceStatuses: [
      SourceResolveStatus(
        reference: SourceReference.all,
        availability: assetIds.isEmpty
            ? AssetSourceAvailability.empty
            : AssetSourceAvailability.available,
        rawCount: assetIds.length,
        contributedCount: assetIds.length,
      ),
    ],
  );
}

class _FakeAlbumMutations implements AlbumMutationRepository {
  int addCalls = 0;
  bool failAdd = false;

  @override
  Future<String> createAlbum(String name) async => 'new-album';

  @override
  Future<bool> albumContainsAsset(
    String albumIdentifier,
    String assetIdentifier,
  ) async =>
      false;

  @override
  Future<void> addAssetToAlbum(
    String assetIdentifier,
    String albumIdentifier,
  ) async {
    addCalls += 1;
    if (failAdd) {
      throw StateError('add failed');
    }
  }
}

void main() {
  group('ADR-048 Snapshot membership invalidation', () {
    test('U-48-1 invalidateEntriesContainingAlbum is per-album narrow', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cache = container.read(browseSnapshotCacheProvider.notifier);

      final wakeTok = SourceReference(
        kind: AssetSourceKind.album,
        id: 'waketok',
      );
      final other = SourceReference(
        kind: AssetSourceKind.album,
        id: 'other',
      );

      cache.putForRefs([SourceReference.all], _snap('all', const ['a']));
      cache.putForRefs([wakeTok], _snap('wt', const ['b']));
      cache.putForRefs([wakeTok, other], _snap('pool', const ['b', 'c']));
      cache.putForRefs([other], _snap('o', const ['c']));
      // Prefix cousin must not match needle `album:waketok`.
      cache.putForRefs(
        [
          SourceReference(kind: AssetSourceKind.album, id: 'waketok-extra'),
        ],
        _snap('cousin', const ['d']),
      );

      cache.invalidateEntriesContainingAlbum('waketok');

      final state = container.read(browseSnapshotCacheProvider);
      expect(state.containsKey(BrowseSnapshotCache.keyFor(SourceReference.all)), isTrue);
      expect(state.containsKey(BrowseSnapshotCache.keyFor(other)), isTrue);
      expect(
        state.containsKey(
          BrowseSnapshotCache.keyFor(
            SourceReference(kind: AssetSourceKind.album, id: 'waketok-extra'),
          ),
        ),
        isTrue,
      );
      expect(state.containsKey(BrowseSnapshotCache.keyFor(wakeTok)), isFalse);
      expect(
        state.containsKey(BrowseSnapshotCache.keyForRefs([wakeTok, other])),
        isFalse,
      );
    });

    test('U-48-2 wrapper notifies only after successful membership write', () async {
      final inner = _FakeAlbumMutations();
      final seen = <String>[];
      final repo = SnapshotInvalidatingAlbumMutationRepository(
        inner: inner,
        onMembershipChanged: seen.add,
      );

      await repo.createAlbum('X');
      expect(seen, isEmpty);

      await repo.albumContainsAsset('alb', 'asset');
      expect(seen, isEmpty);

      await repo.addAssetToAlbum('asset', 'alb-1');
      expect(inner.addCalls, 1);
      expect(seen, ['alb-1']);

      inner.failAdd = true;
      await expectLater(
        repo.addAssetToAlbum('asset', 'alb-2'),
        throwsStateError,
      );
      expect(seen, ['alb-1']);
    });
  });
}
