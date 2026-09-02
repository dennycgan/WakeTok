import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/library/writable_user_albums.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';

AssetSource _album({
  required String id,
  required String displayName,
  bool canAddContent = true,
  AssetSourceKind kind = AssetSourceKind.album,
}) {
  return AssetSource(
    kind: kind,
    id: id,
    displayName: displayName,
    estimatedCount: 1,
    availability: AssetSourceAvailability.available,
    canAddContent: canAddContent,
  );
}

void main() {
  test('T-19.5-1 keeps writable user albums only', () {
    final result = filterAndSortWritableUserAlbums([
      _album(id: 'a', displayName: 'Alpha'),
      _album(id: 'b', displayName: 'Beta', canAddContent: false),
      _album(
        id: 'smart',
        displayName: 'Smart',
        kind: AssetSourceKind.smartAlbum,
        canAddContent: false,
      ),
      AssetSource(
        kind: AssetSourceKind.entireLibrary,
        id: 'all',
        displayName: '',
        estimatedCount: 1,
        availability: AssetSourceAvailability.available,
        canAddContent: false,
      ),
    ]);

    expect(result.map((source) => source.id), ['a']);
  });

  test('T-19.5-2 sorts by displayName alphabetically', () {
    final result = filterAndSortWritableUserAlbums([
      _album(id: 'z', displayName: 'Zulu'),
      _album(id: 'a', displayName: 'Alpha'),
      _album(id: 'm', displayName: 'Mike'),
    ]);

    expect(result.map((source) => source.displayName), [
      'Alpha',
      'Mike',
      'Zulu',
    ]);
  });
}
