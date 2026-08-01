import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/library_asset.dart';
import 'package:waketok/domain/library/library_media_kind.dart';

void main() {
  test('U1 createdAt stays nullable (no epoch fallback)', () {
    const asset = LibraryAsset(
      id: 'a',
      kind: LibraryMediaKind.image,
      availability: AssetAvailability.deviceLocal,
    );
    expect(asset.createdAt, isNull);
  });
}
