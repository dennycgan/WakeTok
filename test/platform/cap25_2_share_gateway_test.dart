import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart'
    as pigeon;
import 'package:waketok/platform/photo_library_gateway.dart';

/// Cap 25.2: [PhotoLibraryGateway.presentShareSheet] ↔ Pigeon wire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = pigeon.PhotoLibraryApi.pigeonChannelCodec;

  String photoChannel(String method) =>
      'dev.flutter.pigeon.waketok.PhotoLibraryApi.$method';

  final shareChannel = photoChannel('presentShareSheet');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(shareChannel, codec),
      null,
    );
  });

  PhotoLibraryGateway gatewayWithMocks() {
    final gateway = PhotoLibraryGateway();
    addTearDown(gateway.dispose);
    return gateway;
  }

  test('T-25.2-1 presentShareSheet forwards asset id to Pigeon', () async {
    Object? capturedMessage;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(shareChannel, codec),
      (message) async {
        capturedMessage = message;
        return <Object?>[null];
      },
    );

    final gateway = gatewayWithMocks();
    await gateway.presentShareSheet('phasset-42');

    expect(capturedMessage, isA<List<Object?>>());
    final args = capturedMessage! as List<Object?>;
    expect(args, isNotEmpty);
    expect(args.first, 'phasset-42');
  });

  test('T-25.2-2 presentShareSheet success completes without throw', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
      BasicMessageChannel<Object?>(shareChannel, codec),
      (message) async => <Object?>[null],
    );

    final gateway = gatewayWithMocks();
    await gateway.presentShareSheet('ok-id');
  });

  group('T-25.2-3 presentShareSheet propagates PlatformException codes', () {
    for (final code in <String>[
      'assetUnavailable',
      'unauthorized',
    ]) {
      test(code, () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler<Object?>(
          BasicMessageChannel<Object?>(shareChannel, codec),
          (message) async => <Object?>[code, 'host $code', null],
        );

        final gateway = gatewayWithMocks();
        try {
          await gateway.presentShareSheet('id-$code');
          fail('expected PlatformException($code)');
        } on PlatformException catch (e) {
          expect(e.code, code);
        }
      });
    }
  });

  test(
    'T-25.2-4 onShareSheetDismissed emits shareSheetDismissedAtMs',
    () async {
      final gateway = gatewayWithMocks();
      final future = gateway.shareSheetDismissedAtMs.first;
      gateway.onShareSheetDismissed(1_700_000_000_123);
      expect(await future, 1_700_000_000_123);
    },
  );
}
