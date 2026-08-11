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
      displayName: '',
      estimatedCount: 1,
      availability: AssetSourceAvailability.available,
      canAddContent: false,
    ),
    AssetSource(
      kind: AssetSourceKind.mediaTypePhotos,
      id: 'photos',
      displayName: '',
      estimatedCount: 1,
      availability: AssetSourceAvailability.available,
      canAddContent: false,
    ),
    AssetSource(
      kind: AssetSourceKind.mediaTypeVideos,
      id: 'videos',
      displayName: '',
      estimatedCount: 1,
      availability: AssetSourceAvailability.available,
      canAddContent: false,
    ),
  ];

  test('D-S1 kind.name matches wire Option A sourceType strings', () {
    expect(AssetSourceKind.entireLibrary.name, 'entireLibrary');
    expect(AssetSourceKind.mediaTypePhotos.name, 'mediaTypePhotos');
    expect(AssetSourceKind.mediaTypeVideos.name, 'mediaTypeVideos');
    expect(AssetSourceKind.album.name, 'album');
    expect(AssetSourceKind.smartAlbum.name, 'smartAlbum');
    expect(AssetSourceKind.values, hasLength(5));
    expect(
      AssetSourceKind.values,
      containsAll(<AssetSourceKind>[
        AssetSourceKind.entireLibrary,
        AssetSourceKind.mediaTypePhotos,
        AssetSourceKind.mediaTypeVideos,
        AssetSourceKind.album,
        AssetSourceKind.smartAlbum,
      ]),
    );
    expect(
      AssetSourceKind.values.map((k) => k.name),
      isNot(contains('other')),
    );
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

  test('D-S1 album/smartAlbum refs construct; never legal built-in pairs', () {
    const album = SourceReference(
      kind: AssetSourceKind.album,
      id: 'collection/local-id-1',
    );
    const smart = SourceReference(
      kind: AssetSourceKind.smartAlbum,
      id: 'smart/local-id-2',
    );
    expect(album.isLegalBuiltInPair, isFalse);
    expect(smart.isLegalBuiltInPair, isFalse);
    expect(album, isNot(smart));
    expect(
      album,
      const SourceReference(
        kind: AssetSourceKind.album,
        id: 'collection/local-id-1',
      ),
    );
    expect(
      album.hashCode,
      Object.hash(AssetSourceKind.album, 'collection/local-id-1'),
    );
  });

  test('D-11.2-1 AssetSource carries album displayName and nullable count', () {
    const album = AssetSource(
      kind: AssetSourceKind.album,
      id: 'album-local-id',
      displayName: 'Trip',
      estimatedCount: null,
      availability: AssetSourceAvailability.available,
      canAddContent: false,
    );
    expect(album.displayName, 'Trip');
    expect(album.estimatedCount, isNull);
    expect(album.availability, AssetSourceAvailability.available);
    expect(
      SourceReference.fromAssetSource(album).isLegalBuiltInPair,
      isFalse,
    );
  });
}
