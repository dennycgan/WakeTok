import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/source_pool_definition.dart';
import 'package:waketok/domain/source/source_reference.dart';

void main() {
  test('SPD-1 PersistencePolicy names are stable', () {
    expect(PersistencePolicy.ephemeral.name, 'ephemeral');
    expect(PersistencePolicy.saved.name, 'saved');
    expect(PersistencePolicy.values, hasLength(2));
  });

  test('SPD-2 PoolCapacity constants lock ADR-P limits', () {
    expect(PoolCapacity.maxSourcesPerPool, 30);
    expect(PoolCapacity.maxSavedPoolPresets, 10);
  });

  test('SPD-3 legal sizes 0/1/30; ephemeral and saved both constructible', () {
    final empty = SourcePoolDefinition(
      id: 'pool-empty',
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: const [],
    );
    expect(empty.orderedSourceReferences, isEmpty);
    expect(empty.displayName, isNull);
    expect(empty.persistencePolicy, PersistencePolicy.ephemeral);

    final one = SourcePoolDefinition(
      id: 'pool-one',
      displayName: 'Comedy',
      persistencePolicy: PersistencePolicy.saved,
      orderedSourceReferences: const [SourceReference.all],
    );
    expect(one.orderedSourceReferences, hasLength(1));
    expect(one.displayName, 'Comedy');
    expect(one.persistencePolicy, PersistencePolicy.saved);

    final refs = List<SourceReference>.generate(
      PoolCapacity.maxSourcesPerPool,
      (i) => SourceReference(
        kind: AssetSourceKind.album,
        id: 'album-$i',
      ),
    );
    final full = SourcePoolDefinition(
      id: 'pool-full',
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: refs,
    );
    expect(full.orderedSourceReferences, hasLength(30));
  });

  test('SPD-4 more than maxSourcesPerPool throws', () {
    final refs = List<SourceReference>.generate(
      PoolCapacity.maxSourcesPerPool + 1,
      (i) => SourceReference(
        kind: AssetSourceKind.album,
        id: 'album-$i',
      ),
    );
    expect(
      () => SourcePoolDefinition(
        id: 'too-many',
        persistencePolicy: PersistencePolicy.ephemeral,
        orderedSourceReferences: refs,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('SPD-5 orderedSourceReferences is unmodifiable', () {
    final def = SourcePoolDefinition(
      id: 'pool-imm',
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: const [SourceReference.photos],
    );
    expect(
      () => def.orderedSourceReferences.add(SourceReference.videos),
      throwsUnsupportedError,
    );
  });

  test('SPD-6 mixed built-in and album/smartAlbum refs; duplicates allowed', () {
    const album = SourceReference(
      kind: AssetSourceKind.album,
      id: 'collection/a',
    );
    const smart = SourceReference(
      kind: AssetSourceKind.smartAlbum,
      id: 'smart/b',
    );
    final def = SourcePoolDefinition(
      id: 'pool-mix',
      persistencePolicy: PersistencePolicy.ephemeral,
      orderedSourceReferences: const [
        SourceReference.all,
        album,
        smart,
        album,
      ],
    );
    expect(def.orderedSourceReferences, hasLength(4));
    expect(def.orderedSourceReferences[1], album);
    expect(def.orderedSourceReferences[3], album);
  });

  test('SPD-7 equality / hashCode; empty displayName normalizes to null', () {
    final a = SourcePoolDefinition(
      id: 'same',
      displayName: '',
      persistencePolicy: PersistencePolicy.saved,
      orderedSourceReferences: const [
        SourceReference.videos,
        SourceReference.photos,
      ],
    );
    final b = SourcePoolDefinition(
      id: 'same',
      displayName: null,
      persistencePolicy: PersistencePolicy.saved,
      orderedSourceReferences: const [
        SourceReference.videos,
        SourceReference.photos,
      ],
    );
    expect(a.displayName, isNull);
    expect(a, b);
    expect(a.hashCode, b.hashCode);

    final reordered = SourcePoolDefinition(
      id: 'same',
      persistencePolicy: PersistencePolicy.saved,
      orderedSourceReferences: const [
        SourceReference.photos,
        SourceReference.videos,
      ],
    );
    expect(a, isNot(reordered));

    expect(
      () => SourcePoolDefinition(
        id: '',
        persistencePolicy: PersistencePolicy.ephemeral,
        orderedSourceReferences: const [],
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
