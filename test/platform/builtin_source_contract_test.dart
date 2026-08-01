import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart';

/// Cap 6 / ADR-013: freeze the three legal built-in (kind, id) pairs.
///
/// Host pair validation lives in Swift; this table is the Dart-side contract
/// lock so list→resolve round-trips and 6.3+ callers cannot drift spellings.
void main() {
  const legalPairs = <({AssetSourceKind kind, String id})>[
    (kind: AssetSourceKind.entireLibrary, id: 'all'),
    (kind: AssetSourceKind.mediaTypePhotos, id: 'photos'),
    (kind: AssetSourceKind.mediaTypeVideos, id: 'videos'),
  ];

  test('T-W2 three legal pairs: sourceType == kind.name and frozen ids', () {
    expect(AssetSourceKind.entireLibrary.name, 'entireLibrary');
    expect(AssetSourceKind.mediaTypePhotos.name, 'mediaTypePhotos');
    expect(AssetSourceKind.mediaTypeVideos.name, 'mediaTypeVideos');

    for (final pair in legalPairs) {
      expect(pair.kind.name, isNot(contains(':')));
      final ref = SourceReferenceDto(
        sourceType: pair.kind.name,
        sourceIdentifier: pair.id,
      );
      expect(ref.sourceType, pair.kind.name);
      expect(ref.sourceIdentifier, pair.id);
    }

    expect(
      legalPairs.map((p) => p.id).toSet(),
      {'all', 'photos', 'videos'},
    );
  });

  test('T-W2 list→resolve round-trip uses the same short id string', () {
    for (final pair in legalPairs) {
      final listed = AssetSourceDto(
        sourceIdentifier: pair.id,
        displayName: '',
        kind: pair.kind,
        estimatedCount: 0,
        availability: AssetSourceAvailabilityDto.empty,
        canAddContent: false,
      );
      final resolveRef = SourceReferenceDto(
        sourceType: listed.kind.name,
        sourceIdentifier: listed.sourceIdentifier,
      );
      expect(resolveRef.sourceIdentifier, listed.sourceIdentifier);
      expect(resolveRef.sourceType, pair.kind.name);
    }
  });

  test('T-W2 mismatched pairs are not in the legal set', () {
    const illegal = <(String, String)>[
      ('builtin', 'all'),
      ('entireLibrary', 'photos'),
      ('mediaTypePhotos', 'all'),
      ('album', 'all'),
      ('entireLibrary', 'builtin:all'),
    ];
    final legalKeys = {
      for (final p in legalPairs) '${p.kind.name}|${p.id}',
    };
    for (final (type, id) in illegal) {
      expect(legalKeys.contains('$type|$id'), isFalse);
    }
  });

  test('T-W2 userLibrary kind removed from wire enum', () {
    expect(
      AssetSourceKind.values.map((k) => k.name),
      isNot(contains('userLibrary')),
    );
    expect(
      AssetSourceKind.values,
      containsAll([
        AssetSourceKind.entireLibrary,
        AssetSourceKind.mediaTypePhotos,
        AssetSourceKind.mediaTypeVideos,
      ]),
    );
  });
}
