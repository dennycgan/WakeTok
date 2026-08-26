import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/presentation/file_size_semantics.dart';
import 'package:waketok/domain/presentation/presentation_media_kind.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/photo_library_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PhotoLibraryApi.pigeonChannelCodec;

  String photoChannel(String method) =>
      'dev.flutter.pigeon.waketok.PhotoLibraryApi.$method';

  tearDown(() {
    for (final m in <String>[
      'requestPresentationMetadata',
      'requestPresentationFileSize',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(photoChannel(m), codec),
        null,
      );
    }
  });

  test('G-P1 metadata maps kind + creationDateMs', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPresentationMetadata'),
        codec,
      ),
      (message) async => <Object?>[
        pigeon.PresentationMetadataDto(
          assetIdentifier: 'img1',
          mediaKind: pigeon.MediaKind.livePhoto,
          creationDateMs: 1_700_000_000_000,
        ),
      ],
    );

    final gateway = PhotoLibraryGateway();
    final meta = await gateway.requestPresentationMetadata('img1');
    expect(meta.assetIdentifier, 'img1');
    expect(meta.mediaKind, PresentationMediaKind.livePhoto);
    expect(meta.createdAt, isNotNull);
  });

  test('G-P1 null creationDateMs stays null (no epoch)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPresentationMetadata'),
        codec,
      ),
      (message) async => <Object?>[
        pigeon.PresentationMetadataDto(
          assetIdentifier: 'img1',
          mediaKind: pigeon.MediaKind.image,
          creationDateMs: null,
        ),
      ],
    );

    final meta =
        await PhotoLibraryGateway().requestPresentationMetadata('img1');
    expect(meta.createdAt, isNull);
  });

  test('G-P1 null fileSizeBytes does not become 0', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPresentationFileSize'),
        codec,
      ),
      (message) async => <Object?>[
        pigeon.PresentationFileSizeDto(
          assetIdentifier: 'missing-local',
          fileSizeBytes: null,
          fileSizeSemantics: null,
        ),
      ],
    );

    final size =
        await PhotoLibraryGateway().requestPresentationFileSize('missing-local');
    expect(size.fileSizeBytes, isNull);
    expect(size.fileSizeSemantics, isNull);
  });

  test('G-P1 Live Photo size uses currentImageRepresentation (ADR-018)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPresentationFileSize'),
        codec,
      ),
      (message) async => <Object?>[
        pigeon.PresentationFileSizeDto(
          assetIdentifier: 'live1',
          fileSizeBytes: 2_886_627,
          fileSizeSemantics:
              pigeon.FileSizeSemantics.currentImageRepresentation,
        ),
      ],
    );

    final size =
        await PhotoLibraryGateway().requestPresentationFileSize('live1');
    expect(size.fileSizeBytes, 2_886_627);
    expect(
      size.fileSizeSemantics,
      FileSizeSemantics.currentImageRepresentation,
    );
  });

  test('G-P1 file size semantics map 1:1', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPresentationFileSize'),
        codec,
      ),
      (message) async => <Object?>[
        pigeon.PresentationFileSizeDto(
          assetIdentifier: 'vid1',
          fileSizeBytes: 9_000_000,
          fileSizeSemantics: pigeon.FileSizeSemantics.localVideoUrl,
        ),
      ],
    );

    final size =
        await PhotoLibraryGateway().requestPresentationFileSize('vid1');
    expect(size.fileSizeBytes, 9_000_000);
    expect(size.fileSizeSemantics, FileSizeSemantics.localVideoUrl);
  });

  test('G-P1 assetUnavailable propagates', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPresentationMetadata'),
        codec,
      ),
      (message) async => <Object?>['assetUnavailable', 'missing', null],
    );

    try {
      await PhotoLibraryGateway().requestPresentationMetadata('gone');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(e.code, 'assetUnavailable');
    }
  });
}
