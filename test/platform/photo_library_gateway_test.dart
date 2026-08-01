import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/domain/authorization/photos_access.dart';
import 'package:waketok/domain/library/asset_availability.dart';
import 'package:waketok/domain/library/library_media_kind.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart' as pigeon;
import 'package:waketok/platform/photo_library_gateway.dart';

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

  tearDown(() {
    for (final m in <String>[
      'authorizationStatus',
      'requestAuthorization',
      'presentLimitedLibraryPicker',
      'libraryTotals',
      'fetchLibraryPage',
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
    mockSuccess(
      photoChannel('authorizationStatus'),
      pigeon.AuthStatus.limited,
    );
    mockSuccess(
      photoChannel('requestAuthorization'),
      pigeon.AuthStatus.authorized,
    );

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

  test('G3 gateway totals and page map to domain', () async {
    final gateway = PhotoLibraryGateway();
    mockSuccess(
      photoChannel('libraryTotals'),
      pigeon.LibraryTotalsDto(all: 5, photos: 4, videos: 1),
    );
    mockSuccess(
      photoChannel('fetchLibraryPage'),
      pigeon.LibraryPageDto(
        assets: [
          pigeon.LibraryAssetDto(
            assetIdentifier: 'id-1',
            mediaKind: pigeon.MediaKind.livePhoto,
            availability: pigeon.AssetAvailabilityDto.iCloudNotDownloaded,
            creationDateMs: null,
          ),
          pigeon.LibraryAssetDto(
            assetIdentifier: 'id-2',
            mediaKind: pigeon.MediaKind.video,
            availability: pigeon.AssetAvailabilityDto.deviceLocal,
            creationDateMs: 1_700_000_000_000,
          ),
        ],
        nextCursor: '2',
      ),
    );

    final totals = await gateway.totals();
    expect(totals.all, 5);
    expect(totals.photos, 4);
    expect(totals.videos, 1);

    final page = await gateway.fetchPage(cursor: null, pageSize: 50);
    expect(page.nextCursor, '2');
    expect(page.assets, hasLength(2));
    expect(page.assets[0].id, 'id-1');
    expect(page.assets[0].kind, LibraryMediaKind.livePhoto);
    expect(page.assets[0].availability, AssetAvailability.iCloudNotDownloaded);
    expect(page.assets[0].createdAt, isNull);
    expect(page.assets[1].kind, LibraryMediaKind.video);
    expect(page.assets[1].createdAt, isNotNull);
  });
}
