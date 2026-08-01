import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/authorization/photos_authorization_repository.dart';
import 'package:waketok/domain/library/library_totals.dart';
import 'package:waketok/features/authorization/photos_authorization_notifier.dart';
import 'package:waketok/features/library_smoke/library_catalog_providers.dart';

import '../../library_smoke/fake_library_catalog_repository.dart';

class _FakePhotosAuthorizationRepository
    implements PhotosAuthorizationRepository {
  _FakePhotosAuthorizationRepository(this.status);

  PhotosAccess status;
  int presentCalls = 0;

  @override
  Future<PhotosAccess> currentStatus() async => status;

  @override
  Future<PhotosAccess> requestAccess() async {
    status = PhotosAccess.full;
    return status;
  }

  @override
  Future<void> presentLimitedLibraryPicker() async {
    presentCalls += 1;
  }
}

void main() {
  test('R1 notifier loads and requestAccess updates state', () async {
    final fake = _FakePhotosAuthorizationRepository(PhotosAccess.notDetermined);
    final container = ProviderContainer(
      overrides: [
        photosAuthorizationRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(photosAuthorizationProvider.future),
      completion(PhotosAccess.notDetermined),
    );

    await container.read(photosAuthorizationProvider.notifier).requestAccess();
    expect(
      container.read(photosAuthorizationProvider).value,
      PhotosAccess.full,
    );
  });

  test('R2 presentLimitedLibraryPicker refreshes status and totals', () async {
    final fake = _FakePhotosAuthorizationRepository(PhotosAccess.limited);
    final catalog = FakeLibraryCatalogRepository(
      totalsValue: const LibraryTotals(all: 1, photos: 1, videos: 0),
    );
    final container = ProviderContainer(
      overrides: [
        photosAuthorizationRepositoryProvider.overrideWithValue(fake),
        libraryCatalogRepositoryProvider.overrideWithValue(catalog),
      ],
    );
    addTearDown(container.dispose);

    await container.read(photosAuthorizationProvider.future);
    await container.read(libraryTotalsProvider.future);
    final totalsBefore = catalog.totalsCalls;

    await container
        .read(photosAuthorizationProvider.notifier)
        .presentLimitedLibraryPicker();
    expect(fake.presentCalls, 1);
    expect(
      container.read(photosAuthorizationProvider).value,
      PhotosAccess.limited,
    );

    await container.read(libraryTotalsProvider.future);
    expect(catalog.totalsCalls, greaterThan(totalsBefore));
  });
}
