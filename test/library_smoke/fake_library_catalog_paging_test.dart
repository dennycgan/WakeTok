import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/library_asset.dart';
import 'package:waketok/domain/library/library_media_kind.dart';
import 'package:waketok/domain/library/library_page.dart';

import 'fake_library_catalog_repository.dart';

void main() {
  test('W3 fake catalog records pageSize and returns next cursor page', () async {
    final page0 = LibraryPage(
      assets: const [
        LibraryAsset(
          id: 'a',
          kind: LibraryMediaKind.image,
          availability: AssetAvailability.deviceLocal,
        ),
      ],
      nextCursor: '1',
    );
    final page1 = const LibraryPage(assets: <LibraryAsset>[]);
    final repo = FakeLibraryCatalogRepository(pages: [page0, page1]);

    final first = await repo.fetchPage(pageSize: 25);
    expect(repo.lastPageSize, 25);
    expect(first.nextCursor, '1');
    expect(first.assets, hasLength(1));

    final second = await repo.fetchPage(cursor: '1', pageSize: 25);
    expect(second.assets, isEmpty);
    expect(second.nextCursor, isNull);
  });
}
