import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/platform/error_code_mapping.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/photo_library_gateway.dart';

/// Cap 19.2: canAddContent passthrough + album mutation error matrix (Dart wire).
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

  void mockError(String channelName, String code) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(channelName, codec),
      (message) async => <Object?>[code, 'stub', null],
    );
  }

  tearDown(() {
    for (final m in <String>[
      'listAssetSources',
      'createAlbum',
      'addAssetToAlbum',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(photoChannel(m), codec),
        null,
      );
    }
  });

  test('T-19.2-1 gateway listAssetSources passes through canAddContent', () async {
    final gateway = PhotoLibraryGateway();
    mockSuccess(photoChannel('listAssetSources'), <Object?>[
      pigeon.AssetSourceDto(
        sourceIdentifier: 'writable-album',
        displayName: 'WakeTok',
        kind: pigeon.AssetSourceKind.album,
        estimatedCount: 1,
        availability: pigeon.AssetSourceAvailabilityDto.available,
        canAddContent: true,
      ),
      pigeon.AssetSourceDto(
        sourceIdentifier: 'smart-fav',
        displayName: 'Favorites',
        kind: pigeon.AssetSourceKind.smartAlbum,
        estimatedCount: null,
        availability: pigeon.AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
    ]);

    final sources = await gateway.listAssetSources();
    expect(sources, hasLength(2));
    expect(sources[0].kind, AssetSourceKind.album);
    expect(sources[0].canAddContent, isTrue);
    expect(sources[1].kind, AssetSourceKind.smartAlbum);
    expect(sources[1].canAddContent, isFalse);
  });

  test('T-19.2-2 album mutation ErrorCodes map to AppError', () async {
    final cases = <MapEntry<String, AppError>>[
      const MapEntry('unauthorized', AppError.unauthorized),
      const MapEntry('albumUnavailable', AppError.albumUnavailable),
      const MapEntry('operationCancelled', AppError.operationCancelled),
      const MapEntry('insufficientStorage', AppError.insufficientStorage),
    ];

    for (final entry in cases) {
      mockError(photoChannel('createAlbum'), entry.key);
      try {
        await PhotoLibraryGateway().createAlbum('WakeTok');
        fail('expected PlatformException for createAlbum ${entry.key}');
      } on PlatformException catch (e) {
        expect(
          appErrorFromPlatformException(e),
          entry.value,
          reason: 'createAlbum ${entry.key}',
        );
      }
    }

    final addCases = <MapEntry<String, AppError>>[
      const MapEntry('unauthorized', AppError.unauthorized),
      const MapEntry('assetUnavailable', AppError.assetUnavailable),
      const MapEntry('albumUnavailable', AppError.albumUnavailable),
      const MapEntry('albumNotWritable', AppError.albumNotWritable),
      const MapEntry('operationCancelled', AppError.operationCancelled),
      const MapEntry('insufficientStorage', AppError.insufficientStorage),
    ];

    for (final entry in addCases) {
      mockError(photoChannel('addAssetToAlbum'), entry.key);
      try {
        await PhotoLibraryGateway().addAssetToAlbum('asset-a', 'album-b');
        fail('expected PlatformException for addAssetToAlbum ${entry.key}');
      } on PlatformException catch (e) {
        expect(
          appErrorFromPlatformException(e),
          entry.value,
          reason: 'addAssetToAlbum ${entry.key}',
        );
      }
    }
  });

  test('T-19.2-3 gateway create/add success paths still forward', () async {
    mockSuccess(photoChannel('createAlbum'), 'album-local-id-19.2');
    mockSuccess(photoChannel('addAssetToAlbum'), null);

    final gateway = PhotoLibraryGateway();
    final id = await gateway.createAlbum('WakeTok');
    expect(id, 'album-local-id-19.2');
    await gateway.addAssetToAlbum('asset-x', id);
  });
}
