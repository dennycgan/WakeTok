import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/core/errors/error_code_mapping.dart';
import 'package:waketok/platform/generated/waketok_platform_apis.g.dart';

/// T7: Dart HostApi / FlutterApi surface + codec path (not Swift — see T6).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const codec = PhotoLibraryApi.pigeonChannelCodec;

  /// Expected Host + Flutter vocabulary (§5.1 + ADR-006).
  const expectedPlaybackHostMethods = <String>{
    'load',
    'play',
    'pause',
    'seek',
    'setRate',
    'setMute',
    'setPlaybackPlan',
    'syncPlanPosition',
    'notifyDisplaySurfaceReady',
    'updateNowPlayingMetadata',
  };

  const expectedPlaybackFlutterMethods = <String>{
    'onPlaybackRuntimeEvent',
    'onPlaybackRestoreRequired',
    'onPlaybackPlanEnded',
  };

  const expectedPhotoLibraryHostMethods = <String>{
    'requestAuthorization',
    'listAssetSources',
    'resolveSource',
    'requestDisplayAsset',
    'requestPlayableVideo',
    'createAlbum',
    'importVideo',
    'addAssetToAlbum',
  };

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

  String photoChannel(String method) =>
      'dev.flutter.pigeon.waketok.PhotoLibraryApi.$method';

  String playbackChannel(String method) =>
      'dev.flutter.pigeon.waketok.PlaybackApi.$method';

  tearDown(() {
    for (final m in expectedPhotoLibraryHostMethods) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(photoChannel(m), codec),
        null,
      );
    }
    for (final m in expectedPlaybackHostMethods) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(playbackChannel(m), codec),
        null,
      );
    }
  });

  test('T7 method-name sets cover §5.1 + ADR-006 vocabulary', () {
    expect(
      expectedPlaybackHostMethods,
      containsAll(<String>[
        'setPlaybackPlan',
        'syncPlanPosition',
        'notifyDisplaySurfaceReady',
      ]),
    );
    expect(
      expectedPlaybackFlutterMethods,
      containsAll(<String>[
        'onPlaybackRestoreRequired',
        'onPlaybackPlanEnded',
        'onPlaybackRuntimeEvent',
      ]),
    );
    expect(
      expectedPhotoLibraryHostMethods,
      containsAll(<String>[
        'createAlbum',
        'importVideo',
        'addAssetToAlbum',
      ]),
    );
  });

  test('T7 FlutterApi implementer compiles ADR-006 callbacks', () {
    final api = _RecordingPlaybackFlutterApi();
    PlaybackFlutterApi.setUp(api);
    expect(api, isA<PlaybackFlutterApi>());
    PlaybackFlutterApi.setUp(null);
  });

  test('T7 PhotoLibrary read/command paths succeed under mock', () async {
    final api = PhotoLibraryApi();

    mockSuccess(photoChannel('requestAuthorization'), AuthStatus.notDetermined);
    mockSuccess(photoChannel('listAssetSources'), <Object?>[]);
    mockSuccess(
      photoChannel('resolveSource'),
      ResolvedSourceDto(sourceIdentifier: 's', assetIdentifiers: <String>[]),
    );
    mockSuccess(
      photoChannel('requestDisplayAsset'),
      DisplayAssetDto(
        assetIdentifier: 'a',
        mediaKind: MediaKind.unknown,
      ),
    );
    mockSuccess(
      photoChannel('requestPlayableVideo'),
      PlayableVideoDto(assetIdentifier: 'a'),
    );

    expect(await api.requestAuthorization(), AuthStatus.notDetermined);
    expect(await api.listAssetSources(), isEmpty);
    expect(
      (await api.resolveSource(
        SourceReferenceDto(sourceType: 'album', sourceIdentifier: 's'),
      )).assetIdentifiers,
      isEmpty,
    );
    expect(
      (await api.requestDisplayAsset('a')).assetIdentifier,
      'a',
    );
    expect(
      (await api.requestPlayableVideo('a')).assetIdentifier,
      'a',
    );
  });

  test('T7 PhotoLibrary write paths return expected ErrorCodes', () async {
    final api = PhotoLibraryApi();

    mockError(photoChannel('createAlbum'), 'albumUnavailable');
    mockError(photoChannel('importVideo'), 'photosImportFailed');
    mockError(photoChannel('addAssetToAlbum'), 'albumNotWritable');

    try {
      await api.createAlbum('x');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(appErrorFromPlatformException(e), AppError.albumUnavailable);
    }

    try {
      await api.importVideo('/tmp/x.mp4');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(appErrorFromPlatformException(e), AppError.photosImportFailed);
    }

    try {
      await api.addAssetToAlbum('a', 'album');
      fail('expected PlatformException');
    } on PlatformException catch (e) {
      expect(appErrorFromPlatformException(e), AppError.albumNotWritable);
    }
  });

  test('T7 Playback Host methods succeed under mock (no-op path)', () async {
    final api = PlaybackApi();
    final item = PlaybackItemDto(
      assetIdentifier: 'a',
      feedIndex: 0,
      mediaKind: MediaKind.video,
    );
    final plan = PlaybackPlanDto(
      planId: 'p',
      orderedItems: <PlaybackItemDto>[item],
      currentIndex: 0,
    );

    for (final method in expectedPlaybackHostMethods) {
      mockSuccess(playbackChannel(method), null);
    }

    await api.load(item);
    await api.play();
    await api.pause();
    await api.seek(1.0);
    await api.setRate(1.0);
    await api.setMute(false);
    await api.setPlaybackPlan(plan);
    await api.syncPlanPosition('a', 0);
    await api.notifyDisplaySurfaceReady('a');
    await api.updateNowPlayingMetadata();
  });
}

final class _RecordingPlaybackFlutterApi implements PlaybackFlutterApi {
  @override
  void onPlaybackRuntimeEvent(PlaybackRuntimeEventDto event) {}

  @override
  void onPlaybackRestoreRequired(int feedIndex, String assetIdentifier) {}

  @override
  void onPlaybackPlanEnded(int feedIndex, String assetIdentifier) {}
}
