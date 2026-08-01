import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
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
    for (final m in <String>[
      'authorizationStatus',
      'requestAuthorization',
      'presentLimitedLibraryPicker',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(photoChannel(m), codec),
        null,
      );
    }
  });

  test('G1 gateway currentStatus / requestAccess forward and map', () async {
    final gateway = PhotoLibraryGateway();
    mockSuccess(photoChannel('authorizationStatus'), AuthStatus.limited);
    mockSuccess(photoChannel('requestAuthorization'), AuthStatus.authorized);

    expect(await gateway.currentStatus(), PhotosAccess.limited);
    expect(await gateway.requestAccess(), PhotosAccess.full);
  });

  test('G2 gateway presentLimitedLibraryPicker forwards', () async {
    final gateway = PhotoLibraryGateway();
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(
        photoChannel('presentLimitedLibraryPicker'),
        codec,
      ),
      (message) async {
        called = true;
        return <Object?>[null];
      },
    );

    await gateway.presentLimitedLibraryPicker();
    expect(called, isTrue);
  });
}
