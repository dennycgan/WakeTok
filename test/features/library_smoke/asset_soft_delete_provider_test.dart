import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show ProviderException;
import 'package:waketok/features/library_smoke/asset_soft_delete_providers.dart';

import '../../library_smoke/fake_asset_soft_delete_repository.dart';

/// Cap 24.2: composition-root override contract for soft-delete.
void main() {
  test(
      'assetSoftDeleteRepositoryProvider wraps UnimplementedError when not '
      'overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Riverpod 3 surfaces create-time throws as [ProviderException].
    expect(
      () => container.read(assetSoftDeleteRepositoryProvider),
      throwsA(
        isA<ProviderException>().having(
          (e) => e.exception,
          'exception',
          isA<UnimplementedError>(),
        ),
      ),
    );
  });

  test(
      'assetSoftDeleteRepositoryProvider override forwards softDeleteAsset id',
      () async {
    final fake = FakeAssetSoftDeleteRepository();
    final container = ProviderContainer(
      overrides: [
        assetSoftDeleteRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(assetSoftDeleteRepositoryProvider)
        .softDeleteAsset('asset-del-1');

    expect(fake.callCount, 1);
    expect(fake.lastAssetId, 'asset-del-1');
  });
}
