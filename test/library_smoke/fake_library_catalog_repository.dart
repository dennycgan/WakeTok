import 'package:waketok/domain/library/library_asset.dart';
import 'package:waketok/domain/library/library_catalog_repository.dart';
import 'package:waketok/domain/library/library_page.dart';
import 'package:waketok/domain/library/library_totals.dart';

/// Test double for [LibraryCatalogRepository].
class FakeLibraryCatalogRepository implements LibraryCatalogRepository {
  FakeLibraryCatalogRepository({
    this.totalsValue = const LibraryTotals(all: 0, photos: 0, videos: 0),
    this.pages = const <LibraryPage>[],
  });

  LibraryTotals totalsValue;
  List<LibraryPage> pages;
  int totalsCalls = 0;
  int fetchCalls = 0;
  String? lastCursor;
  int? lastPageSize;

  @override
  Future<LibraryTotals> totals() async {
    totalsCalls += 1;
    return totalsValue;
  }

  @override
  Future<LibraryPage> fetchPage({String? cursor, required int pageSize}) async {
    fetchCalls += 1;
    lastCursor = cursor;
    lastPageSize = pageSize;
    if (pages.isEmpty) {
      return const LibraryPage(assets: <LibraryAsset>[]);
    }
    if (cursor == null) {
      return pages.first;
    }
    final index = int.tryParse(cursor);
    if (index == null || index < 0 || index >= pages.length) {
      return const LibraryPage(assets: <LibraryAsset>[]);
    }
    return pages[index];
  }
}
