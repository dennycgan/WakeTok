import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/features/library_smoke/asset_source_providers.dart';

import 'fake_asset_source_repository.dart';

void main() {
  test('resolveBuiltInSourceProvider reads repository.resolve', () async {
    final fake = FakeAssetSourceRepository(
      allIds: const ['a', 'b', 'c'],
    );
    final container = ProviderContainer(
      overrides: [
        assetSourceRepositoryProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final resolved =
        await container.read(resolveBuiltInSourceProvider(SourceReference.all).future);

    expect(fake.resolveCalls, 1);
    expect(resolved.sourceId, 'all');
    expect(resolved.assetIdentifiers, ['a', 'b', 'c']);
  });
}
