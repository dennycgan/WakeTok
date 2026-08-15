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
    for (final m in <String>[
      'requestDisplayAsset',
      'cancelDisplayAsset',
      'requestPlayableVideo',
      'cancelPlayableVideo',
      'requestPreview',
      'cancelPreview',
      'releasePreview',
    ]) {
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

  test('G-D1 iCloudDownloadFailed propagates as PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestDisplayAsset'),
        codec,
      ),
      (message) async => <Object?>[
        'iCloudDownloadFailed',
        'download failed',
        null,
      ],
    );

    final gateway = PhotoLibraryGateway();
    try {
      await gateway.requestDisplayAsset('cloud');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(e.code, 'iCloudDownloadFailed');
    }
  });

  test('G-D1 operationCancelled propagates as PlatformException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestDisplayAsset'),
        codec,
      ),
      (message) async => <Object?>['operationCancelled', 'replaced', null],
    );

    final gateway = PhotoLibraryGateway();
    try {
      await gateway.requestDisplayAsset('img1');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(e.code, 'operationCancelled');
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

  test('G-P1 preview maps localFilePath and video mediaKind', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPreview'),
        codec,
      ),
      (message) async => <Object?>[
        pigeon.DisplayAssetDto(
          assetIdentifier: 'vid1',
          mediaKind: pigeon.MediaKind.video,
          localFilePath: '/tmp/vid1_poster.jpg',
          pixelWidth: 1080,
          pixelHeight: 608,
        ),
      ],
    );

    final gateway = PhotoLibraryGateway();
    final preview = await gateway.requestPreview('vid1');
    expect(preview.localFilePath, '/tmp/vid1_poster.jpg');
    expect(preview.mediaKind, PlaybackMediaKind.video);
    expect(preview.pixelWidth, 1080);
  });

  test('G-P1 preview iCloudDownloadRequired propagates as PlatformException',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPreview'),
        codec,
      ),
      (message) async => <Object?>[
        'iCloudDownloadRequired',
        'no layer 1',
        null,
      ],
    );

    final gateway = PhotoLibraryGateway();
    try {
      await gateway.requestPreview('cloud');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(e.code, 'iCloudDownloadRequired');
    }
  });

  test('G-P1 preview operationCancelled propagates as PlatformException',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('requestPreview'),
        codec,
      ),
      (message) async => <Object?>['operationCancelled', 'replaced', null],
    );

    final gateway = PhotoLibraryGateway();
    try {
      await gateway.requestPreview('img1');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(e.code, 'operationCancelled');
    }
  });

  test('G-P1 cancelPreview and releasePreview hit PhotoLibrary channels',
      () async {
    final cancelled = <String>[];
    final released = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('cancelPreview'),
        codec,
      ),
      (message) async {
        final args = message! as List<Object?>;
        cancelled.add(args[0]! as String);
        return <Object?>[null];
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('releasePreview'),
        codec,
      ),
      (message) async {
        final args = message! as List<Object?>;
        released.add(args[0]! as String);
        return <Object?>[null];
      },
    );

    final gateway = PhotoLibraryGateway();
    await gateway.cancelPreview('n1');
    await gateway.releasePreview('n2');
    expect(cancelled, ['n1']);
    expect(released, ['n2']);
  });

  test('G-D1 cancelDisplayAsset and cancelPlayableVideo hit PhotoLibrary channels',
      () async {
    final displayCancelled = <String>[];
    final playableCancelled = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('cancelDisplayAsset'),
        codec,
      ),
      (message) async {
        final args = message! as List<Object?>;
        displayCancelled.add(args[0]! as String);
        return <Object?>[null];
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('cancelPlayableVideo'),
        codec,
      ),
      (message) async {
        final args = message! as List<Object?>;
        playableCancelled.add(args[0]! as String);
        return <Object?>[null];
      },
    );

    final gateway = PhotoLibraryGateway();
    await gateway.cancelDisplayAsset('d1');
    await gateway.cancelPlayableVideo('v1');
    expect(displayCancelled, ['d1']);
    expect(playableCancelled, ['v1']);
  });
}
