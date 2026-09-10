import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

import '../../library_smoke/fake_asset_source_repository.dart';

void main() {
  group('Cap 23.2 still-in-library provider seam', () {
    test('S1 deviceLocal → inLibrary / true / single Host call', () async {
      final fake = FakeAssetSourceRepository(
        availabilityById: const {
          'a1': AssetAvailability.deviceLocal,
        },
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.unknown,
      );

      final ok = await container
          .read(mainBrowseCurrentAssetStillInLibraryProvider.notifier)
          .probeCurrentAssetStillInLibrary();

      expect(ok, isTrue);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.inLibrary,
      );
      expect(fake.getAssetAvailabilitiesCalls, 1);
      expect(fake.getAssetAvailabilitiesHistory.single, ['a1']);
    });

    test('S2 unavailable / missing map → missing / false', () async {
      final fake = FakeAssetSourceRepository(
        availabilityById: const {
          'a1': AssetAvailability.unavailable,
        },
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(mainBrowseCurrentAssetStillInLibraryProvider.notifier)
          .probeCurrentAssetStillInLibrary();

      expect(ok, isFalse);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.missing,
      );
      expect(fake.getAssetAvailabilitiesCalls, 1);
    });

    test('S3 null current id → missing / false / no Host call', () async {
      final fake = FakeAssetSourceRepository(
        availabilityById: const {
          'a1': AssetAvailability.deviceLocal,
        },
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(mainBrowseCurrentAssetStillInLibraryProvider.notifier)
          .probeCurrentAssetStillInLibrary();

      expect(ok, isFalse);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.missing,
      );
      expect(fake.getAssetAvailabilitiesCalls, 0);
    });

    test('S4 second probe while in-flight → false / Host not dual-fired',
        () async {
      final gate = Completer<void>();
      final fake = FakeAssetSourceRepository(
        availabilityById: const {
          'a1': AssetAvailability.deviceLocal,
        },
      )..beforeEachGetAssetAvailabilities = (_) => gate.future;
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
        ],
      );
      addTearDown(container.dispose);

      final notifier =
          container.read(mainBrowseCurrentAssetStillInLibraryProvider.notifier);
      final first = notifier.probeCurrentAssetStillInLibrary();
      await pumpEventQueue();
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.probing,
      );
      expect(fake.getAssetAvailabilitiesCalls, 1);

      final second = await notifier.probeCurrentAssetStillInLibrary();
      expect(second, isFalse);
      expect(fake.getAssetAvailabilitiesCalls, 1);

      gate.complete();
      expect(await first, isTrue);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.inLibrary,
      );
    });

    test('S5 current id change → status resets to unknown', () async {
      var currentId = 'a1';
      final fake = FakeAssetSourceRepository(
        availabilityById: const {
          'a1': AssetAvailability.deviceLocal,
          'a2': AssetAvailability.deviceLocal,
        },
      );
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => currentId),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(mainBrowseCurrentAssetStillInLibraryProvider.notifier)
          .probeCurrentAssetStillInLibrary();
      expect(ok, isTrue);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.inLibrary,
      );

      currentId = 'a2';
      container.invalidate(mainBrowseCurrentAssetIdProvider);
      await pumpEventQueue();

      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.unknown,
      );
    });

    test(
      'S6 id changes mid-probe → stale result discarded / state not backfilled',
      () async {
        final gate = Completer<void>();
        var currentId = 'a1';
        final fake = FakeAssetSourceRepository(
          availabilityById: const {
            'a1': AssetAvailability.deviceLocal,
            'a2': AssetAvailability.iCloudNotDownloaded,
          },
        )..beforeEachGetAssetAvailabilities = (_) => gate.future;
        final container = ProviderContainer(
          overrides: [
            assetSourceRepositoryProvider.overrideWithValue(fake),
            mainBrowseCurrentAssetIdProvider.overrideWith((ref) => currentId),
          ],
        );
        addTearDown(container.dispose);

        final probe = container
            .read(mainBrowseCurrentAssetStillInLibraryProvider.notifier)
            .probeCurrentAssetStillInLibrary();
        await pumpEventQueue();
        expect(
          container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
          StillInLibraryStatus.probing,
        );

        currentId = 'a2';
        container.invalidate(mainBrowseCurrentAssetIdProvider);
        await pumpEventQueue();
        expect(
          container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
          StillInLibraryStatus.unknown,
        );

        gate.complete();
        expect(await probe, isFalse);
        expect(
          container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
          StillInLibraryStatus.unknown,
        );
        expect(fake.getAssetAvailabilitiesCalls, 1);
        expect(fake.getAssetAvailabilitiesHistory.single, ['a1']);
      },
    );

    test('Host throw → missing / false (fail-closed)', () async {
      final fake = FakeAssetSourceRepository(
        availabilityById: const {
          'a1': AssetAvailability.deviceLocal,
        },
      )..getAssetAvailabilitiesException = Exception('host down');
      final container = ProviderContainer(
        overrides: [
          assetSourceRepositoryProvider.overrideWithValue(fake),
          mainBrowseCurrentAssetIdProvider.overrideWith((ref) => 'a1'),
        ],
      );
      addTearDown(container.dispose);

      final ok = await container
          .read(mainBrowseCurrentAssetStillInLibraryProvider.notifier)
          .probeCurrentAssetStillInLibrary();

      expect(ok, isFalse);
      expect(
        container.read(mainBrowseCurrentAssetStillInLibraryProvider).status,
        StillInLibraryStatus.missing,
      );
    });
  });
}
