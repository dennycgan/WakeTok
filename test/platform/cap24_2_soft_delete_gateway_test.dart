import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart'
    as pigeon;
import 'package:waketok/platform/photo_library_gateway.dart';

/// Cap 24.2: [PhotoLibraryGateway.softDeleteAsset] ↔ Pigeon wire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PhotoLibraryApi.pigeonChannelCodec;

  String photoChannel(String method) =>
      'dev.flutter.pigeon.waketok.PhotoLibraryApi.$method';

  final softDeleteChannel = photoChannel('softDeleteAsset');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(softDeleteChannel, codec),
      null,
    );
  });

  test('T-24.2-1 softDeleteAsset forwards asset id to Pigeon', () async {
    Object? capturedMessage;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(softDeleteChannel, codec),
      (message) async {
        capturedMessage = message;
        return <Object?>[null];
      },
    );

    final gateway = PhotoLibraryGateway();
    await gateway.softDeleteAsset('phasset-42');

    expect(capturedMessage, isA<List<Object?>>());
    final args = capturedMessage! as List<Object?>;
    expect(args, isNotEmpty);
    expect(args.first, 'phasset-42');
  });

  test('T-24.2-2 softDeleteAsset success completes without throw', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(softDeleteChannel, codec),
      (message) async => <Object?>[null],
    );

    final gateway = PhotoLibraryGateway();
    await gateway.softDeleteAsset('ok-id');
  });

  group('T-24.2-3 softDeleteAsset propagates PlatformException codes', () {
    for (final code in <String>[
      'assetUnavailable',
      'unauthorized',
      'operationCancelled',
      'insufficientStorage',
      'unknown',
    ]) {
      test(code, () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
          BasicMessageChannel<Object?>(softDeleteChannel, codec),
          (message) async => <Object?>[code, 'host $code', null],
        );

        final gateway = PhotoLibraryGateway();
        try {
          await gateway.softDeleteAsset('id-$code');
          fail('expected PlatformException($code)');
        } on PlatformException catch (e) {
          expect(e.code, code);
        }
      });
    }
  });
}
