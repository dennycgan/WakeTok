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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('albumContainsAsset'),
        codec,
      ),
      null,
    );
  });

  test('T-19.7-1 gateway forwards albumContainsAsset', () async {
    mockSuccess(photoChannel('albumContainsAsset'), true);
    final gateway = PhotoLibraryGateway();
    expect(
      await gateway.albumContainsAsset('album-1', 'asset-1'),
      isTrue,
    );
  });
}
