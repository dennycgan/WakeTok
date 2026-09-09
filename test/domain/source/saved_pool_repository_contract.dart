import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_repository.dart';
import 'package:waketok/domain/source/source_reference.dart';

SourceReference _album(String id) {
  return SourceReference(kind: AssetSourceKind.album, id: id);
}

List<SourceReference> _albums(int count) {
  return List<SourceReference>.generate(count, (i) => _album('album-$i'));
}

/// Shared CRUD invariants for Fake and Drift implementations.
void savedPoolRepositoryContract(
  String label,
  SavedPoolRepository Function({
    required DateTime Function() clock,
    required String Function() createId,
  }) open,
) {
  group('SavedPoolRepository contract ($label)', () {
    late DateTime now;
    late int idSeq;
    late SavedPoolRepository repo;

    setUp(() {
      now = DateTime.utc(2026, 9, 1, 12);
      idSeq = 0;
      repo = open(
        clock: () => now,
        createId: () => 'pool-${idSeq++}',
      );
    });

    test('save then loadById / loadAll round-trip refs in order', () async {
      const album = SourceReference(
        kind: AssetSourceKind.album,
        id: 'collection/a',
      );
      const smart = SourceReference(
        kind: AssetSourceKind.smartAlbum,
        id: 'smart/b',
      );
      final saved = await repo.save(
        displayName: '  Comedy  ',
        orderedSourceReferences: const [
          SourceReference.all,
          album,
          smart,
          album,
        ],
      );
      expect(saved.displayName, 'Comedy');
      expect(saved.id, 'pool-0');
      expect(saved.orderedSourceReferences, [
        SourceReference.all,
        album,
        smart,
        album,
      ]);

      final loaded = await repo.loadById(saved.id);
      expect(loaded, saved);

      final all = await repo.loadAll();
      expect(all, [saved]);
    });

    test('empty / whitespace name is InvalidName before recipe', () async {
      expect(
        () => repo.save(
          displayName: '   ',
          orderedSourceReferences: const [],
        ),
        throwsA(isA<SavedPoolInvalidName>()),
      );
      expect(await repo.loadAll(), isEmpty);
    });

    test('0 sources is InvalidRecipe, store unchanged', () async {
      expect(
        () => repo.save(
          displayName: 'Empty',
          orderedSourceReferences: const [],
        ),
        throwsA(isA<SavedPoolInvalidRecipe>()),
      );
      expect(await repo.loadAll(), isEmpty);
    });

    test('31 sources is InvalidRecipe not ArgumentError, store unchanged',
        () async {
      expect(
        () => repo.save(
          displayName: 'Too many',
          orderedSourceReferences: _albums(
            PoolCapacity.maxSourcesPerPool + 1,
          ),
        ),
        throwsA(isA<SavedPoolInvalidRecipe>()),
      );
      expect(await repo.loadAll(), isEmpty);
    });

    test('30 sources save succeeds (upper bound)', () async {
      final saved = await repo.save(
        displayName: 'Full',
        orderedSourceReferences: _albums(PoolCapacity.maxSourcesPerPool),
      );
      expect(saved.orderedSourceReferences, hasLength(30));
      expect(await repo.loadAll(), hasLength(1));
    });

    test('empty source id is InvalidRecipe', () async {
      expect(
        () => repo.save(
          displayName: 'Bad id',
          orderedSourceReferences: [
            SourceReference(kind: AssetSourceKind.album, id: ''),
          ],
        ),
        throwsA(isA<SavedPoolInvalidRecipe>()),
      );
      expect(await repo.loadAll(), isEmpty);
    });

    test('unique displayName is trim + case-insensitive', () async {
      await repo.save(
        displayName: 'Foo',
        orderedSourceReferences: [_album('a')],
      );
      expect(
        () => repo.save(
          displayName: '  foo  ',
          orderedSourceReferences: [_album('b')],
        ),
        throwsA(isA<SavedPoolDuplicateName>()),
      );
      expect(await repo.loadAll(), hasLength(1));
    });

    test('same ordered recipe different name is DuplicateRecipe', () async {
      await repo.save(
        displayName: 'Alpha',
        orderedSourceReferences: [_album('a'), _album('b')],
      );
      expect(
        () => repo.save(
          displayName: 'Beta',
          orderedSourceReferences: [_album('a'), _album('b')],
        ),
        throwsA(
          isA<SavedPoolDuplicateRecipe>().having(
            (e) => e.existingDisplayName,
            'existingDisplayName',
            'Alpha',
          ),
        ),
      );
      expect(await repo.loadAll(), hasLength(1));
    });

    test('reversed recipe order is allowed as distinct', () async {
      await repo.save(
        displayName: 'Forward',
        orderedSourceReferences: [_album('a'), _album('b')],
      );
      final second = await repo.save(
        displayName: 'Reverse',
        orderedSourceReferences: [_album('b'), _album('a')],
      );
      expect(second.displayName, 'Reverse');
      expect(await repo.loadAll(), hasLength(2));
    });

    test('rename keeps recipe; does not throw DuplicateRecipe', () async {
      final saved = await repo.save(
        displayName: 'Alpha',
        orderedSourceReferences: [_album('a'), _album('b')],
      );
      await repo.save(
        displayName: 'Other',
        orderedSourceReferences: [_album('x')],
      );
      now = now.add(const Duration(seconds: 1));
      final renamed = await repo.rename(id: saved.id, displayName: 'Alpha2');
      expect(renamed.displayName, 'Alpha2');
      expect(renamed.orderedSourceReferences, saved.orderedSourceReferences);
    });

    test('rename excludes self; case-only change is allowed', () async {
      final saved = await repo.save(
        displayName: 'Foo',
        orderedSourceReferences: [_album('a')],
      );
      now = now.add(const Duration(seconds: 1));
      final renamed = await repo.rename(id: saved.id, displayName: 'FOO');
      expect(renamed.displayName, 'FOO');
      expect(renamed.id, saved.id);
      expect(renamed.orderedSourceReferences, saved.orderedSourceReferences);
    });

    test('rename colliding with another preset is DuplicateName', () async {
      final first = await repo.save(
        displayName: 'Alpha',
        orderedSourceReferences: [_album('a')],
      );
      await repo.save(
        displayName: 'Beta',
        orderedSourceReferences: [_album('b')],
      );
      expect(
        () => repo.rename(id: first.id, displayName: 'beta'),
        throwsA(isA<SavedPoolDuplicateName>()),
      );
      expect((await repo.loadById(first.id))!.displayName, 'Alpha');
    });

    test('10th duplicate name is DuplicateName not Capacity', () async {
      for (var i = 0; i < 9; i++) {
        await repo.save(
          displayName: 'P$i',
          orderedSourceReferences: [_album('$i')],
        );
      }
      expect(
        () => repo.save(
          displayName: 'P0',
          orderedSourceReferences: [_album('x')],
        ),
        throwsA(isA<SavedPoolDuplicateName>()),
      );
      expect(await repo.loadAll(), hasLength(9));
    });

    test('11th save is CapacityExceeded even when name collides', () async {
      for (var i = 0; i < PoolCapacity.maxSavedPoolPresets; i++) {
        await repo.save(
          displayName: 'P$i',
          orderedSourceReferences: [_album('$i')],
        );
      }
      expect(
        () => repo.save(
          displayName: 'P0',
          orderedSourceReferences: [_album('x')],
        ),
        throwsA(isA<SavedPoolCapacityExceeded>()),
      );
      expect(await repo.loadAll(), hasLength(10));
    });

    test('loadAll is updatedAt DESC then id ASC', () async {
      final older = await repo.save(
        displayName: 'A',
        orderedSourceReferences: [_album('a')],
      );
      now = now.add(const Duration(seconds: 1));
      final newer = await repo.save(
        displayName: 'B',
        orderedSourceReferences: [_album('b')],
      );
      now = now.add(const Duration(seconds: 1));
      await repo.rename(id: older.id, displayName: 'A-renamed');
      final all = await repo.loadAll();
      expect(all.map((r) => r.id).toList(), [older.id, newer.id]);
      expect(all.first.displayName, 'A-renamed');
    });

    test('same updatedAt ties break by id ASC', () async {
      final first = await repo.save(
        displayName: 'Zed',
        orderedSourceReferences: [_album('z')],
      );
      final second = await repo.save(
        displayName: 'Why',
        orderedSourceReferences: [_album('y')],
      );
      expect(first.id, 'pool-0');
      expect(second.id, 'pool-1');
      final all = await repo.loadAll();
      expect(all.map((r) => r.id).toList(), ['pool-0', 'pool-1']);
    });

    test('loadById missing is null; delete missing succeeds', () async {
      expect(await repo.loadById('nope'), isNull);
      await repo.delete('nope');
    });

    test('rename missing id is NotFound; empty name is InvalidName first',
        () async {
      expect(
        () => repo.rename(id: 'missing', displayName: '   '),
        throwsA(isA<SavedPoolInvalidName>()),
      );
      expect(
        () => repo.rename(id: 'missing', displayName: 'Ok'),
        throwsA(isA<SavedPoolNotFound>()),
      );
    });

    test('delete removes the preset', () async {
      final saved = await repo.save(
        displayName: 'Gone',
        orderedSourceReferences: [_album('a'), _album('b')],
      );
      await repo.delete(saved.id);
      expect(await repo.loadById(saved.id), isNull);
      expect(await repo.loadAll(), isEmpty);
    });
  });
}
