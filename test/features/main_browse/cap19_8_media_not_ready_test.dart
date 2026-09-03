import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/features/main_browse/cap19_favorites_controller.dart';
import 'package:waketok/features/main_browse/main_browse_providers.dart';

void main() {
  test('T-19.8-fav null asset id → mediaNotReady (not loadError)', () async {
    final container = ProviderContainer(
      overrides: [
        mainBrowseCurrentAssetIdProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(mainBrowseCurrentAssetActionableProvider), isFalse);

    await container.read(cap19FavoritesProvider.notifier).loadStatus();
    expect(
      container.read(cap19FavoritesProvider).phase,
      Cap19FavoritesPhase.mediaNotReady,
    );
  });
}
