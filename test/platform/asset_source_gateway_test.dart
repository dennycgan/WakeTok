import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/source/asset_source_availability.dart';
import 'package:waketok/domain/source/asset_source_kind.dart';
import 'package:waketok/domain/source/source_reference.dart';
import 'package:waketok/platform/error_code_mapping.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/photo_library_gateway.dart';
import 'package:waketok/core/errors/app_error.dart';

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
      'resolveSource',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(photoChannel(m), codec),
        null,
      );
    }
  });

  test('G-S1 gateway listAssetSources maps three built-ins', () async {
    final gateway = PhotoLibraryGateway();
    mockSuccess(photoChannel('listAssetSources'), <Object?>[
      pigeon.AssetSourceDto(
        sourceIdentifier: 'all',
        displayName: '',
        kind: pigeon.AssetSourceKind.entireLibrary,
        estimatedCount: 3,
        availability: pigeon.AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
      pigeon.AssetSourceDto(
        sourceIdentifier: 'photos',
        displayName: '',
        kind: pigeon.AssetSourceKind.mediaTypePhotos,
        estimatedCount: 2,
        availability: pigeon.AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
      pigeon.AssetSourceDto(
        sourceIdentifier: 'videos',
        displayName: '',
        kind: pigeon.AssetSourceKind.mediaTypeVideos,
        estimatedCount: 1,
        availability: pigeon.AssetSourceAvailabilityDto.empty,
        canAddContent: false,
      ),
    ]);

    final sources = await gateway.listAssetSources();
    expect(sources, hasLength(3));
    expect(sources[0].kind, AssetSourceKind.entireLibrary);
    expect(sources[0].id, 'all');
    expect(sources[0].displayName, '');
    expect(sources[0].estimatedCount, 3);
    expect(sources[0].availability, AssetSourceAvailability.available);
    expect(sources[0].canAddContent, isFalse);
    expect(sources[1].id, 'photos');
    expect(sources[2].availability, AssetSourceAvailability.empty);
  });

  test('G-11.2-1 assetSourceKindFromPigeon opens album/smartAlbum; other throws',
      () {
    expect(
      assetSourceKindFromPigeon(pigeon.AssetSourceKind.album),
      AssetSourceKind.album,
    );
    expect(
      assetSourceKindFromPigeon(pigeon.AssetSourceKind.smartAlbum),
      AssetSourceKind.smartAlbum,
    );
    expect(
      () => assetSourceKindFromPigeon(pigeon.AssetSourceKind.other),
      throwsStateError,
    );
  });

  test('G-11.2-2 gateway listAssetSources maps album and smartAlbum DTOs',
      () async {
    final gateway = PhotoLibraryGateway();
    mockSuccess(photoChannel('listAssetSources'), <Object?>[
      pigeon.AssetSourceDto(
        sourceIdentifier: 'all',
        displayName: '',
        kind: pigeon.AssetSourceKind.entireLibrary,
        estimatedCount: 1,
        availability: pigeon.AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
      pigeon.AssetSourceDto(
        sourceIdentifier: 'photos',
        displayName: '',
        kind: pigeon.AssetSourceKind.mediaTypePhotos,
        estimatedCount: 1,
        availability: pigeon.AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
      pigeon.AssetSourceDto(
        sourceIdentifier: 'videos',
        displayName: '',
        kind: pigeon.AssetSourceKind.mediaTypeVideos,
        estimatedCount: 0,
        availability: pigeon.AssetSourceAvailabilityDto.empty,
        canAddContent: false,
      ),
      pigeon.AssetSourceDto(
        sourceIdentifier: 'user-album-1',
        displayName: 'Trip',
        kind: pigeon.AssetSourceKind.album,
        estimatedCount: 12,
        availability: pigeon.AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
      pigeon.AssetSourceDto(
        sourceIdentifier: 'smart-1',
        displayName: 'Favorites',
        kind: pigeon.AssetSourceKind.smartAlbum,
        estimatedCount: null,
        availability: pigeon.AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
    ]);

    final sources = await gateway.listAssetSources();
    expect(sources, hasLength(5));
    expect(sources[3].kind, AssetSourceKind.album);
    expect(sources[3].id, 'user-album-1');
    expect(sources[3].displayName, 'Trip');
    expect(sources[3].estimatedCount, 12);
    expect(sources[4].kind, AssetSourceKind.smartAlbum);
    expect(sources[4].displayName, 'Favorites');
    expect(sources[4].estimatedCount, isNull);
    expect(sources[4].availability, AssetSourceAvailability.available);
  });

  test('G-S2 gateway resolve maps ordered asset identifiers', () async {
    final gateway = PhotoLibraryGateway();
    mockSuccess(
      photoChannel('resolveSource'),
      pigeon.ResolvedSourceDto(
        sourceIdentifier: 'all',
        assetIdentifiers: <String>['a', 'b', 'c'],
        assetAvailabilities: <pigeon.AssetAvailabilityDto>[
          pigeon.AssetAvailabilityDto.deviceLocal,
          pigeon.AssetAvailabilityDto.deviceLocal,
          pigeon.AssetAvailabilityDto.iCloudNotDownloaded,
        ],
      ),
    );

    final resolved = await gateway.resolve(SourceReference.all);
    expect(resolved.sourceId, 'all');
    expect(resolved.assetIdentifiers, ['a', 'b', 'c']);
    expect(resolved.assetAvailabilityById['a'], AssetAvailability.deviceLocal);
    expect(
      resolved.assetAvailabilityById['c'],
      AssetAvailability.iCloudNotDownloaded,
    );
  });

  test(
    'G-S3 gateway propagates assetUnavailable from resolve channel error',
    () async {
      final gateway = PhotoLibraryGateway();
      mockError(photoChannel('resolveSource'), 'assetUnavailable');

      try {
        await gateway.resolve(
          const SourceReference(
            kind: AssetSourceKind.entireLibrary,
            id: 'photos',
          ),
        );
        fail('expected PlatformException');
      } on PlatformException catch (e) {
        expect(appErrorFromPlatformException(e), AppError.assetUnavailable);
      }
    },
  );

  test('G-11.3-1 gateway resolve maps album asset identifiers', () async {
    final gateway = PhotoLibraryGateway();
    mockSuccess(
      photoChannel('resolveSource'),
      pigeon.ResolvedSourceDto(
        sourceIdentifier: 'user-album-1',
        assetIdentifiers: <String>['x', 'y'],
        assetAvailabilities: const <pigeon.AssetAvailabilityDto>[],
      ),
    );

    final resolved = await gateway.resolve(
      const SourceReference(kind: AssetSourceKind.album, id: 'user-album-1'),
    );
    expect(resolved.sourceId, 'user-album-1');
    expect(resolved.assetIdentifiers, ['x', 'y']);
  });

  test('G-11.3-2 gateway propagates unauthorized from album resolve', () async {
    final gateway = PhotoLibraryGateway();
    mockError(photoChannel('resolveSource'), 'unauthorized');

    try {
      await gateway.resolve(
        const SourceReference(kind: AssetSourceKind.album, id: 'stale'),
      );
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(appErrorFromPlatformException(e), AppError.unauthorized);
    }
  });

  test('G-11.3-3 gateway propagates albumUnavailable', () async {
    final gateway = PhotoLibraryGateway();
    mockError(photoChannel('resolveSource'), 'albumUnavailable');

    try {
      await gateway.resolve(
        const SourceReference(kind: AssetSourceKind.smartAlbum, id: 'gone'),
      );
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(appErrorFromPlatformException(e), AppError.albumUnavailable);
    }
  });
}
