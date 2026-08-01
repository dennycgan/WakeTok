import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('G-S1 gateway listBuiltInSources maps three built-ins', () async {
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

    final sources = await gateway.listBuiltInSources();
    expect(sources, hasLength(3));
    expect(sources[0].kind, AssetSourceKind.entireLibrary);
    expect(sources[0].id, 'all');
    expect(sources[0].estimatedCount, 3);
    expect(sources[0].availability, AssetSourceAvailability.available);
    expect(sources[0].canAddContent, isFalse);
    expect(sources[1].id, 'photos');
    expect(sources[2].availability, AssetSourceAvailability.empty);
  });

  test(
    'G-S1 assetSourceKindFromPigeon throws for non-built-in wire kinds',
    () {
      expect(
        () => assetSourceKindFromPigeon(pigeon.AssetSourceKind.album),
        throwsStateError,
      );
      expect(
        () => assetSourceKindFromPigeon(pigeon.AssetSourceKind.smartAlbum),
        throwsStateError,
      );
      expect(
        () => assetSourceKindFromPigeon(pigeon.AssetSourceKind.other),
        throwsStateError,
      );
    },
  );

  test('G-S2 gateway resolve maps ordered asset identifiers', () async {
    final gateway = PhotoLibraryGateway();
    mockSuccess(
      photoChannel('resolveSource'),
      pigeon.ResolvedSourceDto(
        sourceIdentifier: 'all',
        assetIdentifiers: <String>['a', 'b', 'c'],
      ),
    );

    final resolved = await gateway.resolve(SourceReference.all);
    expect(resolved.sourceId, 'all');
    expect(resolved.assetIdentifiers, ['a', 'b', 'c']);
  });

  test(
    'G-S3 gateway propagates assetUnavailable from resolve channel error',
    () async {
      // Only covers Dart-side error propagation through the gateway.
      // Swift-side pair validation (builtinSource(from:)) is verified in
      // Cap 6.4 negative-path smoke — this mock does not exercise the host.
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
}
