import 'package:waketok/domain/library/library_page.dart';
import 'package:waketok/domain/library/library_totals.dart';

/// Domain port for PHAsset catalog access (Cap 5.4).
///
/// Implementations live under `lib/platform/`. No Riverpod types (ADR-010).
abstract class LibraryCatalogRepository {
  Future<LibraryTotals> totals();

  Future<LibraryPage> fetchPage({String? cursor, required int pageSize});
}
