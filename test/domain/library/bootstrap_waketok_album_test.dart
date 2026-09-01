import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/bootstrap_waketok_album.dart';
import 'package:waketok/domain/library/waketok_album_constants.dart';
import 'package:waketok/domain/source/asset_source.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';

import '../../library_smoke/fake_album_mutation_repository.dart';
import '../../library_smoke/fake_asset_source_repository.dart';
import 'fake_waketok_album_store.dart';

AssetSource _userAlbum({
  required String id,
  String displayName = waketokAlbumTitle,
}) {
  return AssetSource(
    kind: AssetSourceKind.album,
    id: id,
    displayName: displayName,
    estimatedCount: 1,
    availability: AssetSourceAvailability.available,
    canAddContent: true,
  );
}

void main() {
  test('T-19.3-1 Full KV hit uses cached id without list or create', () async {
    final store = FakeWakeTokAlbumStore()..albumId = 'cached-album';
    final sources = FakeAssetSourceRepository();
    final mutations = FakeAlbumMutationRepository();

    final result = await bootstrapWakeTokAlbum(
      access: PhotosAccess.full,
      store: store,
      assetSources: sources,
      albumMutations: mutations,
    );

    expect(result.source, WakeTokAlbumBootstrapSource.kv);
    expect(result.albumId, 'cached-album');
    expect(sources.listCalls, 0);
    expect(mutations.createAlbumCalls, 0);
    expect(store.saveCalls, 0);
  });

  test('T-19.3-2a Full KV miss list-finds single WakeTok user album', () async {
    final store = FakeWakeTokAlbumStore();
    final sources = FakeAssetSourceRepository(
      extraSources: [_userAlbum(id: 'album-single')],
    );
    final mutations = FakeAlbumMutationRepository();

    final result = await bootstrapWakeTokAlbum(
      access: PhotosAccess.full,
      store: store,
      assetSources: sources,
      albumMutations: mutations,
    );

    expect(result.source, WakeTokAlbumBootstrapSource.listFind);
    expect(result.albumId, 'album-single');
    expect(sources.listCalls, 1);
    expect(mutations.createAlbumCalls, 0);
    expect(store.albumId, 'album-single');
    expect(store.saveCalls, 1);
  });

  test(
    'T-19.3-2b Full KV miss picks min localIdentifier among duplicate titles',
    () async {
      final store = FakeWakeTokAlbumStore();
      final sources = FakeAssetSourceRepository(
        extraSources: [
          _userAlbum(id: 'z-id'),
          _userAlbum(id: 'a-id'),
          _userAlbum(id: 'm-id'),
        ],
      );
      final mutations = FakeAlbumMutationRepository();

      final result = await bootstrapWakeTokAlbum(
        access: PhotosAccess.full,
        store: store,
        assetSources: sources,
        albumMutations: mutations,
      );

      expect(result.source, WakeTokAlbumBootstrapSource.listFind);
      expect(result.albumId, 'a-id');
      expect(mutations.createAlbumCalls, 0);
    },
  );

  test('T-19.3-2c smart album titled WakeTok does not list-find', () async {
    final store = FakeWakeTokAlbumStore();
    final sources = FakeAssetSourceRepository(
      extraSources: [
        AssetSource(
          kind: AssetSourceKind.smartAlbum,
          id: 'smart-waketok',
          displayName: waketokAlbumTitle,
          estimatedCount: 1,
          availability: AssetSourceAvailability.available,
          canAddContent: false,
        ),
      ],
    );
    final mutations = FakeAlbumMutationRepository()
      ..createdAlbumId = 'created-from-smart-miss';

    final result = await bootstrapWakeTokAlbum(
      access: PhotosAccess.full,
      store: store,
      assetSources: sources,
      albumMutations: mutations,
    );

    expect(result.source, WakeTokAlbumBootstrapSource.create);
    expect(result.albumId, 'created-from-smart-miss');
    expect(mutations.createAlbumCalls, 1);
    expect(mutations.lastCreateName, waketokAlbumTitle);
  });

  test('T-19.3-3 Full KV miss with no match creates album', () async {
    final store = FakeWakeTokAlbumStore();
    final sources = FakeAssetSourceRepository();
    final mutations = FakeAlbumMutationRepository()
      ..createdAlbumId = 'new-album-id';

    final result = await bootstrapWakeTokAlbum(
      access: PhotosAccess.full,
      store: store,
      assetSources: sources,
      albumMutations: mutations,
    );

    expect(result.source, WakeTokAlbumBootstrapSource.create);
    expect(result.albumId, 'new-album-id');
    expect(sources.listCalls, 1);
    expect(mutations.createAlbumCalls, 1);
    expect(store.albumId, 'new-album-id');
  });

  test('T-19.3-4 Limited KV hit uses cached id', () async {
    final store = FakeWakeTokAlbumStore()..albumId = 'limited-cached';
    final sources = FakeAssetSourceRepository();
    final mutations = FakeAlbumMutationRepository();

    final result = await bootstrapWakeTokAlbum(
      access: PhotosAccess.limited,
      store: store,
      assetSources: sources,
      albumMutations: mutations,
    );

    expect(result.source, WakeTokAlbumBootstrapSource.kv);
    expect(result.albumId, 'limited-cached');
    expect(sources.listCalls, 0);
    expect(mutations.createAlbumCalls, 0);
  });

  test('T-19.3-5 Limited KV miss create-only never lists', () async {
    final store = FakeWakeTokAlbumStore();
    final sources = FakeAssetSourceRepository(
      extraSources: [_userAlbum(id: 'should-not-pick')],
    );
    final mutations = FakeAlbumMutationRepository()
      ..createdAlbumId = 'limited-created';

    final result = await bootstrapWakeTokAlbum(
      access: PhotosAccess.limited,
      store: store,
      assetSources: sources,
      albumMutations: mutations,
    );

    expect(result.source, WakeTokAlbumBootstrapSource.create);
    expect(result.albumId, 'limited-created');
    expect(sources.listCalls, 0);
    expect(mutations.createAlbumCalls, 1);
    expect(store.albumId, 'limited-created');
  });
}
