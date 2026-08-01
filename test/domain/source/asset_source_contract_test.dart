import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';

void main() {
  const legal = <AssetSource>[
    AssetSource(
      kind: AssetSourceKind.entireLibrary,
      id: 'all',
      estimatedCount: 1,
      availability: AssetSourceAvailability.available,
      canAddContent: false,
    ),
    AssetSource(
      kind: AssetSourceKind.mediaTypePhotos,
      id: 'photos',
      estimatedCount: 1,
      availability: AssetSourceAvailability.available,
      canAddContent: false,
    ),
    AssetSource(
      kind: AssetSourceKind.mediaTypeVideos,
      id: 'videos',
      estimatedCount: 1,
      availability: AssetSourceAvailability.available,
      canAddContent: false,
    ),
  ];

  test('D-S1 kind.name matches wire Option A sourceType strings', () {
    expect(AssetSourceKind.entireLibrary.name, 'entireLibrary');
    expect(AssetSourceKind.mediaTypePhotos.name, 'mediaTypePhotos');
    expect(AssetSourceKind.mediaTypeVideos.name, 'mediaTypeVideos');
    expect(AssetSourceKind.values, hasLength(3));
  });

  test('D-S1 SourceReference.fromAssetSource round-trips frozen ids', () {
    for (final source in legal) {
      final ref = SourceReference.fromAssetSource(source);
      expect(ref.kind, source.kind);
      expect(ref.id, source.id);
      expect(ref.isLegalBuiltInPair, isTrue);
      expect(ref.kind.name, source.kind.name);
    }
  });

  test('D-S1 only three legal built-in pairs', () {
    expect(SourceReference.all.isLegalBuiltInPair, isTrue);
    expect(SourceReference.photos.isLegalBuiltInPair, isTrue);
    expect(SourceReference.videos.isLegalBuiltInPair, isTrue);
    expect(
      const SourceReference(
        kind: AssetSourceKind.entireLibrary,
        id: 'photos',
      ).isLegalBuiltInPair,
      isFalse,
    );
    expect(
      const SourceReference(
        kind: AssetSourceKind.mediaTypePhotos,
        id: 'all',
      ).isLegalBuiltInPair,
      isFalse,
    );
  });
}
