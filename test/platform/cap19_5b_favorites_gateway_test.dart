import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/photo_library_gateway.dart';

/// Cap 19.5b: Favorites Pigeon wire through [PhotoLibraryGateway].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PhotoLibraryApi.pigeonChannelCodec;

  String photoChannel(String method) =>
      'dev.flutter.pigeon.waketok.PhotoLibraryApi.$method';

  void mockSuccess(String channelName, Object? result) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(channelName, codec),
      (message) async => <Object?>[result],
    );
  }

  tearDown(() {
    for (final m in <String>[
      'requestAssetFavoriteStatus',
      'setAssetFavorite',
      'requestFavoritesSmartAlbumCoverThumbnail',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(photoChannel(m), codec),
        null,
      );
    }
  });

  test('T-19.5b-1 requestAssetFavoriteStatus maps Host DTO', () async {
    mockSuccess(
      photoChannel('requestAssetFavoriteStatus'),
      pigeon.AssetFavoriteStatusDto(
        assetIdentifier: 'asset-1',
        isFavorite: true,
      ),
    );

    final gateway = PhotoLibraryGateway();
    final isFavorite = await gateway.requestFavoriteStatus('asset-1');
    expect(isFavorite, isTrue);
  });

  test('T-19.5b-2 setAssetFavorite forwards asset id and bool', () async {
    mockSuccess(photoChannel('setAssetFavorite'), null);

    final gateway = PhotoLibraryGateway();
    await gateway.setFavorite('asset-2', favorite: false);
  });

  test('T-19.5b-3 requestFavoritesSmartAlbumCoverThumbnail maps jpeg bytes',
      () async {
    mockSuccess(
      photoChannel('requestFavoritesSmartAlbumCoverThumbnail'),
      pigeon.AlbumCoverThumbnailDto(
        jpegBytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    );

    final gateway = PhotoLibraryGateway();
    final bytes = await gateway.requestFavoritesSmartAlbumCoverThumbnail(
      targetSizePx: 52,
    );
    expect(bytes, Uint8List.fromList(<int>[1, 2, 3]));
  });
}
