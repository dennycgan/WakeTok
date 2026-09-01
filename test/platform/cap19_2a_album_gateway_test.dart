import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart';
import 'package:waketok/platform/photo_library_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = PhotoLibraryApi.pigeonChannelCodec;

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
    for (final m in <String>['createAlbum', 'addAssetToAlbum']) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(photoChannel(m), codec),
        null,
      );
    }
  });

  test('T-19.2a-2 gateway forwards createAlbum', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(photoChannel('createAlbum'), codec),
      (message) async {
        final args = message! as List<Object?>;
        expect(args.single, 'WakeTok');
        return <Object?>['album-local-id-1'];
      },
    );

    final gateway = PhotoLibraryGateway();
    final id = await gateway.createAlbum('WakeTok');
    expect(id, 'album-local-id-1');
  });

  test('T-19.2a-2b gateway forwards addAssetToAlbum', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(photoChannel('addAssetToAlbum'), codec),
      (message) async {
        final args = message! as List<Object?>;
        expect(args[0], 'asset-a');
        expect(args[1], 'album-b');
        return <Object?>[null];
      },
    );

    final gateway = PhotoLibraryGateway();
    await gateway.addAssetToAlbum('asset-a', 'album-b');
  });
}
