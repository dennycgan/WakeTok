import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/persistence_policy.dart';
import 'package:waketok/domain/source/pool_capacity.dart';
import 'package:waketok/domain/source/saved_pool_display_name.dart';
import 'package:waketok/domain/source/saved_pool_failure.dart';
import 'package:waketok/domain/source/saved_pool_recipe.dart';
import 'package:waketok/domain/source/saved_pool_record.dart';
import 'package:waketok/domain/source/source_reference.dart';

void main() {
  group('saved pool display name', () {
    test('trim; blank becomes null', () {
      expect(normalizeSavedPoolDisplayName('  Comedy  '), 'Comedy');
      expect(normalizeSavedPoolDisplayName(''), isNull);
      expect(normalizeSavedPoolDisplayName('   '), isNull);
      expect(normalizeSavedPoolDisplayName('A  B'), 'A  B');
    });

    test('key is case-insensitive without locale fold tables', () {
      expect(savedPoolDisplayNameKey('Foo'), savedPoolDisplayNameKey('FOO'));
      expect(savedPoolDisplayNameKey('Foo'), isNot(savedPoolDisplayNameKey('Bar')));
    });

    test('require throws InvalidName on blank', () {
      expect(requireSavedPoolDisplayName(' x '), 'x');
      expect(
        () => requireSavedPoolDisplayName(' \n '),
        throwsA(isA<SavedPoolInvalidName>()),
      );
    });
  });

  group('ensureSavedPoolRecipe', () {
    test('0 and above maxSourcesPerPool throw InvalidRecipe', () {
      expect(
        () => ensureSavedPoolRecipe(const []),
        throwsA(isA<SavedPoolInvalidRecipe>()),
      );
      final tooMany = List<SourceReference>.generate(
        PoolCapacity.maxSourcesPerPool + 1,
        (i) => SourceReference(kind: AssetSourceKind.album, id: 'a$i'),
      );
      expect(
        () => ensureSavedPoolRecipe(tooMany),
        throwsA(isA<SavedPoolInvalidRecipe>()),
      );
    });

    test('empty source id throws InvalidRecipe', () {
      expect(
        () => ensureSavedPoolRecipe([
          SourceReference(kind: AssetSourceKind.album, id: ''),
        ]),
        throwsA(isA<SavedPoolInvalidRecipe>()),
      );
    });

    test('1 and maxSourcesPerPool are accepted', () {
      expect(
        () => ensureSavedPoolRecipe(const [SourceReference.all]),
        returnsNormally,
      );
      final full = List<SourceReference>.generate(
        PoolCapacity.maxSourcesPerPool,
        (i) => SourceReference(kind: AssetSourceKind.album, id: 'a$i'),
      );
      expect(() => ensureSavedPoolRecipe(full), returnsNormally);
    });
  });

  test('SavedPoolRecord.toDefinition maps a valid record to saved SPD', () {
    final at = DateTime.utc(2026, 9, 1);
    final record = SavedPoolRecord(
      id: 'pool-1',
      displayName: 'Comedy',
      createdAt: at,
      updatedAt: at,
      orderedSourceReferences: const [
        SourceReference.photos,
        SourceReference.videos,
      ],
    );
    final definition = record.toDefinition();
    expect(definition.id, 'pool-1');
    expect(definition.displayName, 'Comedy');
    expect(definition.persistencePolicy, PersistencePolicy.saved);
    expect(definition.orderedSourceReferences, [
      SourceReference.photos,
      SourceReference.videos,
    ]);
  });
}
