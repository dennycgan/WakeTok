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

    test('weight: Latin 1, CJK/kana/Hangul/fullwidth 3', () {
      expect(savedPoolDisplayNameWeight('A'), 1);
      expect(savedPoolDisplayNameWeight('中'), 3);
      expect(savedPoolDisplayNameWeight('あ'), 3);
      expect(savedPoolDisplayNameWeight('한'), 3);
      expect(savedPoolDisplayNameWeight('Ａ'), 3); // fullwidth A
      expect(isSavedPoolWideWeightRune('中'.runes.first), isTrue);
      expect(isSavedPoolWideWeightRune('A'.runes.first), isFalse);
    });

    test('weight budget: 32 Latin / 10 CJK; require throws NameTooLong', () {
      expect(savedPoolDisplayNameWeight('a' * 32), 32);
      expect(savedPoolDisplayNameWithinWeightLimit('a' * 32), isTrue);
      expect(savedPoolDisplayNameWithinWeightLimit('a' * 33), isFalse);
      expect(savedPoolDisplayNameWeight('中' * 10), 30);
      expect(savedPoolDisplayNameWithinWeightLimit('中' * 10), isTrue);
      expect(savedPoolDisplayNameWithinWeightLimit('中' * 11), isFalse);
      expect(requireSavedPoolDisplayName('中' * 10), '中' * 10);
      expect(
        () => requireSavedPoolDisplayName('中' * 11),
        throwsA(isA<SavedPoolNameTooLong>()),
      );
      expect(
        () => requireSavedPoolDisplayName('a' * 33),
        throwsA(isA<SavedPoolNameTooLong>()),
      );
      // Mixed: 9 CJK (27) + 5 Latin (5) = 32.
      expect(
        savedPoolDisplayNameWeight('${'中' * 9}hello'),
        32,
      );
      expect(
        savedPoolDisplayNameWithinWeightLimit('${'中' * 9}hello!'),
        isFalse,
      );
    });

    test('truncate keeps longest in-budget prefix', () {
      expect(truncateSavedPoolDisplayNameToWeightLimit('中' * 10), '中' * 10);
      expect(truncateSavedPoolDisplayNameToWeightLimit('中' * 15), '中' * 10);
      expect(
        truncateSavedPoolDisplayNameToWeightLimit('a' * 40),
        'a' * 32,
      );
      expect(
        truncateSavedPoolDisplayNameToWeightLimit('${'中' * 9}hello!'),
        '${'中' * 9}hello',
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

  group('saved pool recipe equality', () {
    const a = SourceReference(kind: AssetSourceKind.album, id: 'a');
    const b = SourceReference(kind: AssetSourceKind.album, id: 'b');

    test('same order equal; reverse order not equal', () {
      expect(savedPoolRecipesEqual([a, b], [a, b]), isTrue);
      expect(savedPoolRecipesEqual([a, b], [b, a]), isFalse);
      expect(savedPoolRecipesEqual([a], [a, b]), isFalse);
    });

    test('findSavedPoolWithSameRecipe returns first match', () {
      final at = DateTime.utc(2026, 9, 1);
      final first = SavedPoolRecord(
        id: 'p1',
        displayName: 'First',
        createdAt: at,
        updatedAt: at,
        orderedSourceReferences: const [a, b],
      );
      final second = SavedPoolRecord(
        id: 'p2',
        displayName: 'Second',
        createdAt: at,
        updatedAt: at,
        orderedSourceReferences: const [a, b],
      );
      expect(
        findSavedPoolWithSameRecipe(
          candidate: const [a, b],
          existing: [first, second],
        ),
        first,
      );
      expect(
        findSavedPoolWithSameRecipe(
          candidate: const [b, a],
          existing: [first],
        ),
        isNull,
      );
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
