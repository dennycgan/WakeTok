import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waketok/core/errors/app_error.dart';
import 'package:waketok/platform/error_code_mapping.dart';
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
    'clearPlaybackPool',
  };

  const expectedPlaybackFlutterMethods = <String>{
    'onPlaybackRuntimeEvent',
    'onPlaybackRestoreRequired',
    'onPlaybackPlanEnded',
  };

  const expectedLivePhotoHostMethods = <String>{
    'requestLivePhoto',
    'cancel',
    'startPlayback',
    'stopPlayback',
    'setMute',
    'notifyLiveSurfaceReady',
  };

  const expectedLivePhotoFlutterMethods = <String>{
    'onLivePhotoReady',
    'onLivePhotoFailed',
    'onLivePhotoPlaybackEnded',
  };

  const expectedPhotoLibraryHostMethods = <String>{
    'authorizationStatus',
    'requestAuthorization',
    'presentLimitedLibraryPicker',
    'libraryTotals',
    'fetchLibraryPage',
    'listAssetSources',
    'resolveSource',
    'requestDisplayAsset',
    'requestPlayableVideo',
    'requestPresentationMetadata',
    'requestPresentationFileSize',
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

  String livePhotoChannel(String method) =>
      'dev.flutter.pigeon.waketok.LivePhotoApi.$method';

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
    for (final m in expectedLivePhotoHostMethods) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
        BasicMessageChannel<Object?>(livePhotoChannel(m), codec),
        null,
      );
    }
  });

  test('T7 method-name sets cover §5.1 + ADR-006 + Cap 9 Live vocabulary', () {
    expect(
      expectedPlaybackHostMethods,
      containsAll(<String>[
        'setPlaybackPlan',
        'syncPlanPosition',
        'notifyDisplaySurfaceReady',
        'clearPlaybackPool',
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
      expectedLivePhotoHostMethods,
      containsAll(<String>[
        'requestLivePhoto',
        'notifyLiveSurfaceReady',
        'startPlayback',
      ]),
    );
    expect(
      expectedLivePhotoFlutterMethods,
      containsAll(<String>[
        'onLivePhotoReady',
        'onLivePhotoFailed',
        'onLivePhotoPlaybackEnded',
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

  test('T7 FlutterApi implementer compiles Cap 9 Live callbacks', () {
    final api = _RecordingLivePhotoFlutterApi();
    LivePhotoFlutterApi.setUp(api);
    expect(api, isA<LivePhotoFlutterApi>());
    LivePhotoFlutterApi.setUp(null);
  });

  test('T7 PhotoLibrary read/command paths succeed under mock', () async {
    final api = PhotoLibraryApi();

    mockSuccess(photoChannel('authorizationStatus'), AuthStatus.authorized);
    mockSuccess(photoChannel('requestAuthorization'), AuthStatus.notDetermined);
    mockSuccess(photoChannel('presentLimitedLibraryPicker'), null);
    mockSuccess(
      photoChannel('libraryTotals'),
      LibraryTotalsDto(all: 3, photos: 2, videos: 1),
    );
    mockSuccess(
      photoChannel('fetchLibraryPage'),
      LibraryPageDto(assets: <LibraryAssetDto>[], nextCursor: null),
    );
    mockSuccess(photoChannel('listAssetSources'), <Object?>[
      AssetSourceDto(
        sourceIdentifier: 'all',
        displayName: '',
        kind: AssetSourceKind.entireLibrary,
        estimatedCount: 3,
        availability: AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
      AssetSourceDto(
        sourceIdentifier: 'photos',
        displayName: '',
        kind: AssetSourceKind.mediaTypePhotos,
        estimatedCount: 2,
        availability: AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
      AssetSourceDto(
        sourceIdentifier: 'videos',
        displayName: '',
        kind: AssetSourceKind.mediaTypeVideos,
        estimatedCount: 1,
        availability: AssetSourceAvailabilityDto.available,
        canAddContent: false,
      ),
    ]);
    mockSuccess(
      photoChannel('resolveSource'),
      ResolvedSourceDto(
        sourceIdentifier: 'all',
        assetIdentifiers: <String>['a', 'b', 'c'],
      ),
    );
    mockSuccess(
      photoChannel('requestDisplayAsset'),
      DisplayAssetDto(
        assetIdentifier: 'a',
        mediaKind: MediaKind.unknown,
        localFilePath: '/tmp/a.jpg',
      ),
    );
    mockSuccess(
      photoChannel('requestPlayableVideo'),
      PlayableVideoDto(assetIdentifier: 'a'),
    );
    mockSuccess(
      photoChannel('requestPresentationMetadata'),
      PresentationMetadataDto(
        assetIdentifier: 'a',
        mediaKind: MediaKind.image,
        creationDateMs: 1_700_000_000_000,
      ),
    );
    mockSuccess(
      photoChannel('requestPresentationFileSize'),
      PresentationFileSizeDto(
        assetIdentifier: 'a',
        fileSizeBytes: 1024,
        fileSizeSemantics: FileSizeSemantics.currentImageRepresentation,
      ),
    );

    expect(await api.authorizationStatus(), AuthStatus.authorized);
    expect(await api.requestAuthorization(), AuthStatus.notDetermined);
    await api.presentLimitedLibraryPicker();
    expect((await api.libraryTotals()).all, 3);
    expect((await api.fetchLibraryPage(null, 50)).assets, isEmpty);
    final sources = await api.listAssetSources();
    expect(sources, hasLength(3));
    expect(sources[0].sourceIdentifier, 'all');
    expect(sources[0].kind, AssetSourceKind.entireLibrary);
    expect(sources[0].estimatedCount, 3);
    expect(sources[0].canAddContent, isFalse);
    expect(sources[0].displayName, isEmpty);
    expect(
      (await api.resolveSource(
        SourceReferenceDto(
          sourceType: 'entireLibrary',
          sourceIdentifier: 'all',
        ),
      )).assetIdentifiers,
      ['a', 'b', 'c'],
    );
    expect(
      (await api.requestDisplayAsset('a')).assetIdentifier,
      'a',
    );
    expect(
      (await api.requestPlayableVideo('a')).assetIdentifier,
      'a',
    );
    final meta = await api.requestPresentationMetadata('a');
    expect(meta.assetIdentifier, 'a');
    expect(meta.mediaKind, MediaKind.image);
    expect(meta.creationDateMs, 1_700_000_000_000);
    final size = await api.requestPresentationFileSize('a');
    expect(size.fileSizeBytes, 1024);
    expect(size.fileSizeSemantics, FileSizeSemantics.currentImageRepresentation);
  });

  test('T7 PhotoLibrary host vocabulary includes 5.2 auth + 5.4 catalog', () {
    expect(
      expectedPhotoLibraryHostMethods,
      containsAll(<String>[
        'authorizationStatus',
        'presentLimitedLibraryPicker',
        'libraryTotals',
        'fetchLibraryPage',
      ]),
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
    await api.clearPlaybackPool();
  });

  test('T7 LivePhoto Host methods succeed under mock (no-op path)', () async {
    final api = LivePhotoApi();
    for (final method in expectedLivePhotoHostMethods) {
      mockSuccess(livePhotoChannel(method), null);
    }

    await api.requestLivePhoto('live-1');
    await api.cancel('live-1');
    await api.notifyLiveSurfaceReady('live-1');
    await api.startPlayback();
    await api.stopPlayback();
    await api.setMute(false);
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

final class _RecordingLivePhotoFlutterApi implements LivePhotoFlutterApi {
  @override
  void onLivePhotoReady(String assetIdentifier) {}

  @override
  void onLivePhotoFailed(String assetIdentifier, ErrorCode errorCode) {}

  @override
  void onLivePhotoPlaybackEnded(String assetIdentifier) {}
}
