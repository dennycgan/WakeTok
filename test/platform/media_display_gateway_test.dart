import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/playback/playback_models.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/photo_library_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PhotoLibraryApi.pigeonChannelCodec;

  String photoChannel(String method) =>
      'dev.flutter.pigeon.waketok.PhotoLibraryApi.$method';

  tearDown(() {
    for (final m in <String>['requestDisplayAsset', 'requestPlayableVideo']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(photoChannel(m), codec),
        null,
      );
    }
  });

  test('G-D1 display asset maps localFilePath', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestDisplayAsset'),
        codec,
      ),
      (message) async => <Object?>[
        pigeon.DisplayAssetDto(
          assetIdentifier: 'img1',
          mediaKind: pigeon.MediaKind.image,
          localFilePath: '/tmp/img1.jpg',
          pixelWidth: 100,
          pixelHeight: 200,
        ),
      ],
    );

    final gateway = PhotoLibraryGateway();
    final display = await gateway.requestDisplayAsset('img1');
    expect(display.localFilePath, '/tmp/img1.jpg');
    expect(display.mediaKind, PlaybackMediaKind.image);
    expect(display.pixelWidth, 100);
  });

  test('G-D1 iCloudDownloadRequired propagates as PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestDisplayAsset'),
        codec,
      ),
      (message) async => <Object?>['iCloudDownloadRequired', 'iCloud-only', null],
    );

    final gateway = PhotoLibraryGateway();
    try {
      await gateway.requestDisplayAsset('cloud');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(e.code, 'iCloudDownloadRequired');
    }
  });

  test('G-V1 playable video maps duration', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPlayableVideo'),
        codec,
      ),
      (message) async => <Object?>[
        pigeon.PlayableVideoDto(
          assetIdentifier: 'vid1',
          durationSeconds: 12.5,
        ),
      ],
    );

    final gateway = PhotoLibraryGateway();
    final video = await gateway.requestPlayableVideo('vid1');
    expect(video.durationSeconds, 12.5);
  });
}
