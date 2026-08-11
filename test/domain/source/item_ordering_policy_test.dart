import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/item_ordering_policy.dart';

void main() {
  test('ORD-1 ItemOrderingPolicy names are stable', () {
    expect(
      ItemOrderingPolicy.creationDateDescending.name,
      'creationDateDescending',
    );
    expect(ItemOrderingPolicy.unspecified.name, 'unspecified');
    expect(ItemOrderingPolicy.values, hasLength(2));
  });

  test('ORD-2 built-ins map to creationDateDescending', () {
    expect(
      ItemOrderingPolicy.forKind(AssetSourceKind.entireLibrary),
      ItemOrderingPolicy.creationDateDescending,
    );
    expect(
      ItemOrderingPolicy.forKind(AssetSourceKind.mediaTypePhotos),
      ItemOrderingPolicy.creationDateDescending,
    );
    expect(
      ItemOrderingPolicy.forKind(AssetSourceKind.mediaTypeVideos),
      ItemOrderingPolicy.creationDateDescending,
    );
  });

  test('ORD-3 album/smartAlbum map to unspecified', () {
    expect(
      ItemOrderingPolicy.forKind(AssetSourceKind.album),
      ItemOrderingPolicy.unspecified,
    );
    expect(
      ItemOrderingPolicy.forKind(AssetSourceKind.smartAlbum),
      ItemOrderingPolicy.unspecified,
    );
  });

  test('ORD-4 forKind covers every AssetSourceKind', () {
    for (final kind in AssetSourceKind.values) {
      final policy = ItemOrderingPolicy.forKind(kind);
      expect(
        ItemOrderingPolicy.values,
        contains(policy),
        reason: 'forKind($kind) must return a known policy',
      );
    }
  });
}
