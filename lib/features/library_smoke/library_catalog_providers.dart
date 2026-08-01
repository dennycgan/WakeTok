import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:waketok/domain/library/library_catalog_repository.dart';
import 'package:waketok/domain/library/library_totals.dart';

/// Overridden at the composition root with [PhotoLibraryGateway].
final libraryCatalogRepositoryProvider = Provider<LibraryCatalogRepository>((
  ref,
) {
  throw StateError(
    'libraryCatalogRepositoryProvider must be overridden at '
    'the composition root (lib/main.dart / lib/app)',
  );
});

final libraryTotalsProvider = FutureProvider<LibraryTotals>((ref) {
  return ref.watch(libraryCatalogRepositoryProvider).totals();
});
